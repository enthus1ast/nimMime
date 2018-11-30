#
#
#            Nim's Runtime Library
#        (c) Copyright 2018 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Contains basic MIME parser/generator
## Usage example:



import tables, strutils, parseutils, random
import encodings, quotedPrintables, base64
import mimetypes, ospaths
type
  ContentTransferEncoders* = enum 
    NO_ENCODING = ""
    BASE64 = "BASE64"
    QUOTED_PRINTABLES = "QUOTED-PRINTABLE"
  MimeMessage* = ref object of RootObj
    version*: string
    header*: MimeHeaders
    charset*: string # like utf-8, iso-8859-1, koi8-r
    contentType*: string # like text
    subtype*: string # like Mixed,Alternative ,Digest/plain etc    
    contentTransferEncoding: ContentTransferEncoders
    boundary*: string
    body*: string    
    parts*: seq[MimeMessage] # fill this for multipart.
  MimeHeaders* = ref object
    table*: OrderedTableRef[string, seq[string]]
  MimeHeaderValues* = distinct seq[string]

const 
  headerLimit* = 10_000
  maxLine = 10_000
  mimeNewline* = "\c\L"
  sep = "--"
  CONTENT_TRANSFER_ENCODING = "Content-Transfer-Encoding"
  CONTENT_DISPOSITION = "Content-Disposition"
  CONTENT_TYPE = "Content-Type"

proc mimeList*(elems: seq[string]): string =
  # TODO: should be setter?
  return elems.join(", ")

## 
# proc mimeTable*(table: OrderedTable[string,string]): string = 
#   result = ""
#   for key, val in table.pairs:
#     result.add key #"$#=$#" % @[key,val]
#     if val.len != 0:
#       result.add '='
#       result.add val

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
  ## FIXME broken by new string rules
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
  ## FIXME broken by new string rules?
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
  ## returns the string representation of the MimeMessage
  result = ""
  if msg.version.len > 0: 
    result.add msg.version & mimeNewline
  result.addHeaders(msg.header)
  result.add mimeNewline
  result.add msg.body
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

proc finalize*(msg: MimeMessage): MimeMessage = 
  ## TODO: good idea at all? 
  ## TODO: Should `$` do this? Or return a new MimeMessage?
  ## TODO: anyhow here is it for now
  ## Computes and sets a unique multipart boundary, 
  ## after this call the multipart message is ready
  ## to serialize with `$`.
  result = msg
  if not result.header.hasKey(CONTENT_TYPE):
    var contentType = ""
    if result.isMultipart:
      result.boundary = result.uniqueBoundary()
      contentType = """multipart/mixed; boundary="$#"""" % @[result.boundary]
      # contentType = """multipart/$#; boundary="$#"""" % @[result.subtype, result.boundary]
      # contentType = """multipart; boundary="$#"""" % @[result.boundary]
    else:
      contentType = """$#/$#""" % @[result.contentType, result.subtype]
    if result.charset != "":
      contentType.add "; charset=$#" % @[result.charset] 
    result.header[CONTENT_TYPE] = contentType
  
  if not result.header.hasKey(CONTENT_TRANSFER_ENCODING):
    if result.contentTransferEncoding != NO_ENCODING:
      result.header[CONTENT_TRANSFER_ENCODING] = $result.contentTransferEncoding
  
  if result.isMultipart:
    for idx, part in msg.parts:
      result.parts[idx] = part.finalize()

proc mimeEncoder*(txt: string, encoder: ContentTransferEncoders, 
    forHeader = false, srcEncoding = "utf-8", maxLine = maxLine): string = 
  ## encodes `txt` with given encoder, 
  ## from the given `srcEncoding` into a mailsafe(?) representation. 
  ## The encoded string breaks at `maxline`.
  ## If `forHeader` is true, the result is encoded for use by the MIME header
  var txtbuf = ""
  case encoder
  of NO_ENCODING: return txt
  of QUOTED_PRINTABLES: txtbuf = txt.quoted(srcEncoding, newlineAt = maxLine)
  of BASE64: txtbuf = txt.encode(lineLen = maxLine)
  if forHeader: 
    let shortname = ($encoder)[0] # since 'Q'uoted.. / 'B'ase64. 
    return "=?$#?$#?$#?=" % @[srcEncoding, $shortname, txtbuf]
  return txtbuf

proc encodeWith*(msg: var MimeMessage, encoder: ContentTransferEncoders, srcEncoding = "utf-8") =
  # TODO better return a new message?
  ## encodes `msg` with given encoder, 
  ## from the given `srcEncoding` into a mailsafe(?) representation. 
  ## The encoded string breaks at `maxline`.
  msg.charset = srcEncoding
  msg.contentTransferEncoding = encoder
  msg.body = msg.body.mimeEncoder(encoder, forHeader = false, srcEncoding = srcEncoding)  

proc encodeQuotedPrintables*(msg: var MimeMessage, srcEncoding = "utf-8") =
  ## TODO: should this maybe return a new message?
  ## TODO: better handling on header params/already encoded messages.
  ## sets transfer encoding header and encodes the message body with `quoted printables`
  msg.encodeWith(QUOTED_PRINTABLES)

proc encodeBase64*(msg: var MimeMessage, srcEncoding = "utf-8") =
  ## TODO: should this maybe return a new message?
  ## TODO: better handling on header params/already encoded messages.
  ## sets transfer encoding header and encodes the message body with `base64`
  msg.encodeWith(BASE64)

proc needsEncoding*(str: string): bool =
  ## Returns true if the str contains mail unsafe characters.
  for ch in str:
    if ch notin MAIL_SAFE:
      return true
  return false

proc needsEncoding*(msg: MimeMessage): bool =
  ## returns true if the given message needs encoding
  # TODO: also check the headers or not?
  if msg.body.needsEncoding: return true
  for key, val in msg.header.pairs:
    if val.needsEncoding: return true
  if msg.isMultipart:
    for part in msg.parts:
      if part.needsEncoding: return true
  return false

proc newAttachment*(content, filename: string, encoder = BASE64, mimeTypeOverride = ""): MimeMessage =
  ## generates a new email attachement
  ## if the message needs encoding the specified encoder is used automatically.
  ## if `mimeType` is an empty string the mimetype gets autodetected by the file extension
  var mimeType: string
  if mimeTypeOverride.len == 0:
    var mimeDb = newMimetypes() # TODO better do this once module wide?
    mimeType = mimeDb.getMimetype(splitFile(filename).ext)
  else:
    mimeType = mimeTypeOverride
  result = newMimeMessage()
  result.header[CONTENT_DISPOSITION] = """attachment; filename="$#"""" % @[filename]
  result.header[CONTENT_TYPE] = """$#; name="$#"""" % @[mimeType, filename]
  if result.body.needsEncoding():
    result.header[CONTENT_TRANSFER_ENCODING] = $encoder
    result.body = content.mimeEncoder(encoder)
  else:
    result.body = content

proc newEmail*(subject, body: string, sender: string, to:seq[string], cc: seq[string] = @[], 
  bcc: seq[string] = @[], attachments: seq[MimeMessage], sourceEncoding = "utf-8"): MimeMessage =
  ## convenient proc to generate a new email with attachments.
  ## call `finalize()` on it, then send it via smtp # TODO 
  result = newMimeMessage(charset = sourceEncoding) # envelope
  result.header["from"] = sender
  result.header["to"] = to.mimeList
  if cc.len > 0: result.header["cc"] = cc.mimeList
  if bcc.len > 0: result.header["bcc"] = bcc.mimeList
  result.header["subject"] = subject.mimeEncoder(QUOTED_PRINTABLES, forHeader = true)
  if attachments.len == 0:
    result.body = body
    return
  
  result.body = "Warning to old clients: This is a multipart MIME message!"
  # for attachement in attachments:
  result.parts = attachments
  
  # var first = newMimeMessage()
  # first.body = "i show up in email readers! i do not end with a linebreak!"
  # multi.parts.add first

  # var second = newAttachment("i am a file", filename = "second.txt")
  # multi.parts.add second

  # var third = newMimeMessage()
  # third.header["Content-Disposition"] = """attachment; filename="third.txt""""
  # third.body = "i am a manually attached AND i end with a explicit line break\n"
  # multi.parts.add third  

  # var image = newAttachment(readFile("./tests/logo.png"), filename = "logo.png")
  # # image.encodeBase64()
  # image.encodeQuotedPrintables()
  # # image.finalize()
  # multi.parts.add(image)
  # multi.finalize()
  # let msg = $multi
  # echo msg

# # import tables
# block: 
#   var m = newMimeMessage()
#   m.header["to"] = @["foo", "baa", "baz"]
#   m.body = "test"
#   m.finalize()
#   echo m
#   # echo msg

when isMainModule:
  var test = newMimeHeaders()
  test["Connection"] = @["Upgrade", "Close"]
  doAssert test["Connection", 0] == "Upgrade"
  doAssert test["Connection", 1] == "Close"
  test.add("Connection", "Test")
  doAssert test["Connection", 2] == "Test"
  doAssert "upgrade" in test["Connection"]

  # # Bug #5344. # TODO
  # doAssert parseHeader("foobar: ") == ("foobar", @[""])
  # let (key, value) = parseHeader("foobar: ")
  # test = newMimeHeaders()
  # test[key] = value
  # doAssert test["foobar"] == ""
  # doAssert parseHeader("foobar:") == ("foobar", @[""])

when isMainModule and true:
  test = newMimeHeaders()
  var msg = ""
  test.add("Connection", "Test")
  msg.addHeaders(test)
  msg.add(mimeNewline)
  msg.add "body content"

when isMainModule and false: # multipart test
  var multi = newMimeMessage()
  multi.body = "In multipart messages the body is just a comment for incompatible clients"
  multi.header["to"] = @["foo@nim.org", "baa@nim.org"].mimeList
  multi.header["subject"] = "multiparted US-ASCII for you"
  
  var first = newMimeMessage()
  first.header[CONTENT_TYPE] = "text/plain"
  first.body = "i show up in email readers! i do not end with a linebreak!"
  assert first.needsEncoding() == false
  multi.parts.add first

  var second = newMimeMessage()
  second.header[CONTENT_TYPE] = "text/plain"
  second.body = "i am another multipart 42924863215779480875955470471231252136"
  assert second.needsEncoding() == false
  multi.parts.add second

  var third = newMimeMessage()
  third.header[CONTENT_TYPE] = "text/plain"
  third.header["Content-Disposition"] = """attachment; filename="test.txt""""
  third.body = "i am manually attached öäü AND i end with a explicit line break\n"
  if third.needsEncoding():
    third.encodeQuotedPrintables()
  multi.parts.add third  

  var attachment = newAttachment("i am the filecontent", "filename.png")
  attachment.encodeBase64() 
  multi.parts.add attachment
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
  normal.header["foo"] = "in normal--4292486321577948087--" # TODO test must use parents boundary!
  normal.body = "in normal"
  multi2.parts.add normal
  multi.parts.add multi2
  multi.parts.add normal
  multi.encodeQuotedPrintables
  echo multi.finalize

when isMainModule and true:
  assert "foo".needsEncoding() == false
  assert "föö".needsEncoding() == true

  var lst = newSeq[string]()
  # discard parseList(@["foo","baa"].mimeList(), lst, 0)  # TODO "new string"
  # assert lst == @["foo","baa"]

# when isMainModule and true:
#   var mail = newMimeMessage()
#   for foo in @["hans", "peter"]:
#     mail.header["to"] = foo & "@example.org"
#     mail.body = "Dear $#" % @[foo]
#     if foo == "hans":
#       var forhans = newAttachment("HI HANS!", "readme.png")
#       mail.parts.add forhans
#     mail.finalize()
#     echo $mail
#     echo "===================================================="

when isMainModule and true:
  for name in @["hans", "peter"]:
    var envelope = newMimeMessage()
    envelope.header["to"] = name & "@example.org"
    envelope.header["subject"] = mimeEncoder("Iñtërnâtiônàlizætiøn☃💩", QUOTED_PRINTABLES, forHeader = true)
    envelope.body = "Warning to old clients: This is a multipart MIME message! "

    var msg = newMimeMessage()
    msg.body = "Dear $# ..." % @[name]
    envelope.parts.add msg
    if name == "hans": # only hans gets an attachment
      var forhans = newAttachment("<content of image.png>", "image.png", BASE64)
      envelope.parts.add forhans

      var anotherforhans = newAttachment("<content of image.png>", "image.png", QUOTED_PRINTABLES)
      envelope.parts.add anotherforhans      
    echo envelope.finalize()
    echo "===================================================="

when isMainModule and true:
  var 
    file = newAttachment("<i am the file content>", "filename.txt", QUOTED_PRINTABLES)
    file2 = newAttachment("<i am another file content>", "filename2.txt", BASE64)
  var email = newEmail("Hello friend", "Iñtërnâtiônàlizætiøn☃💩", "sender@example.org", @["to@example.org"], attachments = @[file,file2])
  # email.finalize()
  echo email.finalize()
### TODO: The parser is not ready yet...
### FIXME if you like!
# proc parseMime(str: string): MimeMessage =
#   ## Read header
#   ## Read body
#   echo parseHeader("foo: baa, baz\nbaa: baaa, baaaaa")
#   return MimeMessage()

# echo parseMime("foo: baa, baz")
# proc encoderImpl(txt: string, encoder: ContentTransferEncoders, 
#     line: bool, srcEncoding = "utf-8" ): string = 

# proc parseHeaders(str: string, maxLine = maxLine, headerLimit = headerLimit): MimeHeaders =
#   result = newMimeHeaders()
#   for line in str.splitLines:
#     if line == "":
#       return
#     if line.len > maxLine:
#       raise newException(ValueError, "Exceeding maxLine")
#     if line == "\c\L": break
#     let (key, value) = parseHeader(line)
#     result[key] = value
#     if result.len > headerLimit:
#       raise newException(ValueError, "Exceeding headerLimit")

# # if request.reqMethod == HttpPost:
# #   # Check for Expect header
# #   if request.headers.hasKey("Expect"):
# #     if "100-continue" in request.headers["Expect"]:
# #       await client.sendStatus("100 Continue")
# #     else:
# #       await client.sendStatus("417 Expectation Failed")

# # Read the body
# # - Check for Content-length header
# if request.headers.hasKey("Content-Length"):
#   var contentLength = 0
#   if parseSaturatedNatural(request.headers["Content-Length"], contentLength) == 0:
#     await request.respond(Http400, "Bad Request. Invalid Content-Length.")
#     return
#   else:
#     if contentLength > server.maxBody:
#       await request.respondError(Http413)
#       return
#     request.body = await client.recv(contentLength)
#     if request.body.len != contentLength:
#       await request.respond(Http400, "Bad Request. Content-Length does not match actual.")
#       return
# elif request.reqMethod == HttpPost:
#   await request.respond(Http411, "Content-Length required.")
#   return

# # Call the user's callback.
# await callback(request)

# if "upgrade" in request.headers.getOrDefault("connection"):
#   return

# # Persistent connections
# if (request.protocol == HttpVer11 and
#     cmpIgnoreCase(request.headers.getOrDefault("connection"), "close") != 0) or
#     (request.protocol == HttpVer10 and
#     cmpIgnoreCase(request.headers.getOrDefault("connection"), "keep-alive") == 0):
#   # In HTTP 1.1 we assume that connection is persistent. Unless connection
#   # header states otherwise.
#   # In HTTP 1.0 we assume that the connection should not be persistent.
#   # Unless the connection header states otherwise.
#   discard
# else:
#   request.client.close()
#   return

# let a = """to: peter@example.org
# subject: =?utf-8?Q?I=C3=B1t=C3=ABrn=C3=A2ti=C3=B4n=C3=A0liz=C3=A6ti=C3=B8n=E2=98=83=F0=9F=92=A9?=
# content-type: multipart/mixed; boundary="5955470471231252136"; charset=UTF-8

# Dear peter
# --5955470471231252136
# content-type: text/plain; charset=UTF-8


# --5955470471231252136--
# """
# echo parseHeaders(a)


#import mime

