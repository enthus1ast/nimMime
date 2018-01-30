#
#
#            Nim's Runtime Library
#        (c) Copyright 2018 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Contains basic MIME parser/generator
import tables, strutils, parseutils, random

type
  ContentTransferEncoders = enum 
    NO_ENCODING = ""
    BASE64 = "BASE64"
    QUOTED_PRINTABLES = "QUOTED-PRINTABLE"
  MimeMessage* = ref object of RootObj
    version*: string
    header*: MimeHeaders
    charset*: string # like utf-8, iso-8859-1, koi8-r
    contentType*: string # like text
    contentTransferEncoding: ContentTransferEncoders
    subtype*: string # like Mixed,Alternative,Digest etc
    boundary*: string
    body*: string    
    parts*: seq[MimeMessage] # fill this for multipart.
  # MimeMessageMultipart* = ref object of MimeMessage
    # parts*: seq[MimeMessage | MimeMessageMultipart]  
  # MimeMessageMultipart* = distinct MimeMessage 
  MimeHeaders* = ref object
    table*: OrderedTableRef[string, seq[string]]
  MimeHeaderValues* = distinct seq[string]
  MimeEncoding* = enum
    noEncoding
    base64Encoding
    quotedPrintablesEncoding

const 
  headerLimit* = 10_000
  mimeNewline* = "\c\L"
  sep = "--"

proc mimeList*(elems: seq[string]): string =
  return elems.join(", ")

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

# proc init(msg: MimeMessage, contentType, subtype,  charset: string) =


proc newMimeMessage*(contentType = "text", subtype="plain", charset = "UTF-8"): MimeMessage = 
  result = MimeMessage()
  result.version = ""
  result.header = newMimeHeaders()
  result.contentType = contentType
  result.charset = charset
  result.subtype = subtype
  result.body = ""
  result.boundary = ""
  result.parts = @[]
# proc newMimeMessageMultipart*(contentType = "multipart", subtype="mixed", charset = "UTF-8"): MimeMessageMultipart = 
  # result = MimeMessageMultipart()
  # result.init(contentType, subtype,  charset)
  # result.parts = @[]

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
  if headers.len == 0:
    msg.add mimeNewline
    return # if no header present we still need newline!
  for k, v in headers:
    msg.add(k & ": " & v & mimeNewline)  

proc isMultipart*(msg: MimeMessage): bool = 
  return msg.parts.len != 0

proc `$`*(msg: MimeMessage): string =
  ## returns the string representation of the msgpart message
  result = ""
  if msg.version.len > 0: 
    result.add msg.version & mimeNewline
  result.addHeaders(msg.header)
  result.add mimeNewline
  result.add msg.body
  # when msg.type is MimeMessage:
  if msg.isMultipart:
    let boundaryLine = mimeNewline & sep & msg.boundary & mimeNewline
    let boundaryLineLast = mimeNewline & sep & msg.boundary & sep & mimeNewline
    for idx, part in msg.parts:
      result.add boundaryLine
      result.add $part
      if idx == msg.parts.len-1:
        result.add boundaryLineLast # last boundary must be also suffixed by "--"

proc isUniqueBoundary(msgs: seq[MimeMessage], boundary: string): bool =
  ## returns true if the given boundary is unique in the msgs
  for msg in msgs:
    if boundary in $msg:
      return false
  return true

proc uniqueBoundary*(multi: MimeMessage): string =
  ## returns a message wide unique string to use as a multipart boundary
  while true:
    result = $rand(1_000..int.high)
    if multi.parts.isUniqueBoundary(result): 
      break


# proc finalize*(msg: var MimeMessage) =
  # msg.

proc finalize*(msg: var MimeMessage) = 
  ## Computes and sets a unique multipart boundary, 
  ## after this call the multipart message is ready
  ## to serialize with `$`.
  var contentType = ""
  if msg.isMultipart:
    msg.boundary = msg.uniqueBoundary()
    contentType = """$#/$#; boundary="$#"""" % @[msg.contentType, msg.subtype, msg.boundary]
  else:
    contentType = """$#/$#""" % @[msg.contentType, msg.subtype]
  
  if msg.charset != "":
    contentType.add "; charset=$#" % @[msg.charset] 
  
  msg.header["Content-Type"] = contentType
  if msg.contentTransferEncoding != NO_ENCODING:
    msg.header["Content-Transfer-Encoding"] = $msg.contentTransferEncoding

  if msg.isMultipart:
    for idx, part in msg.parts.mpairs:
      part.finalize()



import encodings, quotedPrintables, base64
proc encodeQuotedPrintables*(msg: var MimeMessage, srcEncoding = "utf-8") =
  ## TODO should this maybe return a new message?
  ## TODO better handling on header params/already encoded messages.
  ## sets transfer encoding header and encodes the message body.
  #  Content-Type: text/plain; charset=ISO-8859-1 
  #  Content-transfer-encoding: base64
  # if msg.header; charset=ISO-8859-1
  # msg.header["content-type"] &= " ; charset=$#" % [srcEncoding]
  # msg.header["Content-transfer-encoding"] = "QUOTED-PRINTABLE"
  msg.charset = srcEncoding
  msg.contentTransferEncoding = QUOTED_PRINTABLES
  msg.body = msg.body.quoted(srcEncoding)

proc encodeBase64*(msg: var MimeMessage, srcEncoding = "utf-8") =
  ## TODO should this maybe return a new message?
  ## TODO better handling on header params/already encoded messages.
  ## sets transfer encoding header and encodes the message body.
  #  Content-Type: text/plain; charset=ISO-8859-1 
  #  Content-transfer-encoding: base64
  # if msg.header; charset=ISO-8859-1
  # msg.header["content-type"] &= " ; charset=$#" % [srcEncoding]
  # msg.header["Content-transfer-encoding"] = "QUOTED-PRINTABLE"
  msg.charset = srcEncoding
  msg.contentTransferEncoding = BASE64
  msg.body = msg.body.encode()

proc needsEncoding*(str: string): bool = 
  for ch in str:
    if ch notin MAIL_SAFE:
      return true
  return false

proc needsEncoding*(msg: MimeMessage): bool =
  ## checks if the given message needs encoding
  # TODO also check the headers or not?
  if msg.body.needsEncoding: return true
  for key, val in msg.header.pairs:
    if val.needsEncoding: return true
  if msg.isMultipart:
    for part in msg.parts:
      if part.needsEncoding: return true
  return false

# proc needsEncoding*(multi: MimeMessageMultipart): bool =
#   if msg.needsEncoding: return true

  ## If the str is not US-ASCII (or not mailsafe!) it needs to be encoded.

  # try:
    # echo convert(str, "us-ascii", getCurrentEncoding())
    
  #   result = false
  #   discard
  # except:
  #   echo getCurrentExceptionMsg()
  #   result = true

proc newAttachment*(content, filename: string, encoder = BASE64): MimeMessage = 
  ## 
  ## TODO encode if not US-ASCII
  result = newMimeMessage()
  result.header["Content-Disposition"] = """attachment; filename="$#"""" % @[filename]
  result.body = content

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
  msg.add(mimeNewline)
  msg.add "body content"
  # echo msg

when isMainModule and false: # multipart test
  var multi = newMimeMessage()
  multi.body = "In multipart messages the body is just a comment for incompatible clients"
  multi.header["to"] = @["foo@nim.org", "baa@nim.org"].mimeList
  multi.header["subject"] = "multiparted US-ASCII for you"
  
  var first = newMimeMessage()
  first.header["content-type"] = "text/plain"
  first.body = "i show up in email readers! i do not end with a linebreak!"
  assert first.needsEncoding() == false
  multi.parts.add first

  var second = newMimeMessage()
  second.header["content-type"] = "text/plain"
  second.body = "i am another multipart 42924863215779480875955470471231252136"
  assert second.needsEncoding() == false
  multi.parts.add second

  var third = newMimeMessage()
  third.header["content-type"] = "text/plain"
  third.header["Content-Disposition"] = """attachment; filename="test.txt""""
  third.body = "i am manually attached öäü AND i end with a explicit line break\n"
  if third.needsEncoding():
    third.encodeQuotedPrintables()
  multi.parts.add third  

  var attachment = newAttachment("i am the filecontent", "filename.txt")
  attachment.encodeBase64() 
  multi.parts.add attachment
  # echo "==="
  # multi.boundary = multi.uniqueBoundary()
  # assert multi.needsEncoding() == false
  multi.finalize()
  echo $multi

when isMainModule and true: # multipart in multipart
  var multi = newMimeMessage()
  multi.header["foo"] = "in multi 1"
  multi.body = "in multi 1"
  
  var multi2 = newMimeMessage()
  multi2.header["foo"] = "in multi2"
  multi2.body = "in multi 2"
  
  var normal = newMimeMessage()
  normal.header["foo"] = "in normal"
  normal.body = "in normal"
  # echo repr normal.type
  multi2.parts.add normal
  multi.parts.add multi2
  multi.parts.add normal
  # echo "lol"
  multi.finalize()
  echo $multi

when isMainModule and true:
  assert "foo".needsEncoding() == false
  assert "föö".needsEncoding() == true
  # echo "föö".needsEncoding()


  # var msg = ""
  # test.add("Connection", "Test")
  # msg.addHeaders(test)
  # msg.add(mimeNewline)
  # msg.add "body content"
  # echo msg


# when isMainModule and true:
#   test = newMimeHeaders()
#   var msg = ""
#   test.add("Connection", "Test")
#   msg.addHeaders(test)
#   msg.add(mimeNewline)
#   msg.add "body content"
#   echo msg  