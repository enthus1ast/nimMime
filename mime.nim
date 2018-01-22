#
#
#            Nim's Runtime Library
#        (c) Copyright 2018 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Contains basic MIME parser
import tables, strutils, parseutils

type
  MimeHeaders* = ref object
    # table*: TableRef[string, seq[string]]
    table*: OrderedTableRef[string, seq[string]]

  MimeHeaderValues* = distinct seq[string]

const headerLimit* = 10_000

proc newMimeHeaders*(): MimeHeaders =
  new result
  result.table = newOrderedTable[string, seq[string]]()

proc newMimeHeaders*(keyValuePairs:
    openarray[tuple[key: string, val: string]]): MimeHeaders =
  var pairs: seq[tuple[key: string, val: seq[string]]] = @[]
  for pair in keyValuePairs:
    pairs.add((pair.key.toLowerAscii(), @[pair.val]))
  new result
  result.table = newOrderedTable[string, seq[string]](pairs)

proc `$`*(headers: MimeHeaders): string =
  return $headers.table

proc clear*(headers: MimeHeaders) =
  headers.table.clear()

proc `[]`*(headers: MimeHeaders, key: string): MimeHeaderValues =
  ## Returns the values associated with the given ``key``. If the returned
  ## values are passed to a procedure expecting a ``string``, the first
  ## value is automatically picked. If there are
  ## no values associated with the key, an exception is raised.
  ##
  ## To access multiple values of a key, use the overloaded ``[]`` below or
  ## to get all of them access the ``table`` field directly.
  return headers.table[key.toLowerAscii].MimeHeaderValues

converter toString*(values: MimeHeaderValues): string =
  return seq[string](values)[0]

proc `[]`*(headers: MimeHeaders, key: string, i: int): string =
  ## Returns the ``i``'th value associated with the given key. If there are
  ## no values associated with the key or the ``i``'th value doesn't exist,
  ## an exception is raised.
  return headers.table[key.toLowerAscii][i]

proc `[]=`*(headers: MimeHeaders, key, value: string) =
  ## Sets the header entries associated with ``key`` to the specified value.
  ## Replaces any existing values.
  headers.table[key.toLowerAscii] = @[value]

proc `[]=`*(headers: MimeHeaders, key: string, value: seq[string]) =
  ## Sets the header entries associated with ``key`` to the specified list of
  ## values.
  ## Replaces any existing values.
  headers.table[key.toLowerAscii] = value

proc add*(headers: MimeHeaders, key, value: string) =
  ## Adds the specified value to the specified key. Appends to any existing
  ## values associated with the key.
  if not headers.table.hasKey(key.toLowerAscii):
    headers.table[key.toLowerAscii] = @[value]
  else:
    headers.table[key.toLowerAscii].add(value)

proc del*(headers: MimeHeaders, key: string) =
  ## Delete the header entries associated with ``key``
  headers.table.del(key.toLowerAscii)

iterator pairs*(headers: MimeHeaders): tuple[key, value: string] =
  ## Yields each key, value pair.
  for k, v in headers.table:
    for value in v:
      yield (k, value)

proc contains*(values: MimeHeaderValues, value: string): bool =
  ## Determines if ``value`` is one of the values inside ``values``. Comparison
  ## is performed without case sensitivity.
  for val in seq[string](values):
    if val.toLowerAscii == value.toLowerAscii: return true

proc hasKey*(headers: MimeHeaders, key: string): bool =
  return headers.table.hasKey(key.toLowerAscii())

proc getOrDefault*(headers: MimeHeaders, key: string,
    default = @[""].MimeHeaderValues): MimeHeaderValues =
  ## Returns the values associated with the given ``key``. If there are no
  ## values associated with the key, then ``default`` is returned.
  if headers.hasKey(key):
    return headers[key]
  else:
    return default

proc len*(headers: MimeHeaders): int = return headers.table.len

proc parseList(line: string, list: var seq[string], start: int): int =
  var i = 0
  var current = ""
  while line[start + i] notin {'\c', '\l', '\0'}:
    i += line.skipWhitespace(start + i)
    i += line.parseUntil(current, {'\c', '\l', ','}, start + i)
    list.add(current)
    if line[start + i] == ',':
      i.inc # Skip ,
    current.setLen(0)

proc parseHeader*(line: string): tuple[key: string, value: seq[string]] =
  ## Parses a single raw header HTTP line into key value pairs.
  ##
  ## Used by ``asynchttpserver`` and ``httpclient`` internally and should not
  ## be used by you.
  result.value = @[]
  var i = 0
  i = line.parseUntil(result.key, ':')
  inc(i) # skip :
  if i < len(line):
    i += parseList(line, result.value, i)
  elif result.key.len > 0:
    result.value = @[""]
  else:
    result.value = @[]

proc addHeaders*(msg: var string, headers: MimeHeaders) =
  ## From asynchttp
  for k, v in headers:
    msg.add(k & ": " & v & "\c\L")    

# let t1 = """MIME-Version: 1.0
#  Content-Type: multipart/mixed; boundary=frontier

#  This is a message with multiple parts in MIME format.
#  --frontier
#  Content-Type: text/plain

#  This is the body of the message.
#  --frontier
#  Content-Type: text/html
#  Content-Transfer-Encoding: base64

#  PGh0bWw+CiAgPGhlYWQ+CiAgPC9oZWFkPgogIDxib2R5PgogICAgPHA+VGhpcyBpcyB0aGUg
#  Ym9keSBvZiB0aGUgbWVzc2FnZS48L3A+CiAgPC9ib2R5Pgo8L2h0bWw+Cg==
#  --frontier--"""

when isMainModule:
  var test = newMimeHeaders()
  test["Connection"] = @["Upgrade", "Close"]
  doAssert test["Connection", 0] == "Upgrade"
  doAssert test["Connection", 1] == "Close"
  test.add("Connection", "Test")
  doAssert test["Connection", 2] == "Test"
  doAssert "upgrade" in test["Connection"]

  # Bug #5344.
  doAssert parseHeader("foobar: ") == ("foobar", @[""])
  let (key, value) = parseHeader("foobar: ")
  test = newMimeHeaders()
  test[key] = value
  doAssert test["foobar"] == ""

  doAssert parseHeader("foobar:") == ("foobar", @[""])

when isMainModule and true:
  test = newMimeHeaders()
  var msg = ""
  test.add("Connection", "Test")
  msg.addHeaders(test)
  msg.add("\c\L")
  msg.add "body content"
  echo msg