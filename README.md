1. Please note that this is a work in process.
2. Please give feedback how you would like to use a "mime.nim"

mime.nim is MIME related code mostly copy pasted from
- httpcore.nim
- smtp.nim
- asynchttpserver

it also implements "quoted printables" https://en.wikipedia.org/wiki/Quoted-printable
and also introduces a MimeMessage object.

A multipart example of an email could look like:

```nim
  for name in @["hans", "peter"]:
    var envelope = newMimeMessage()
    envelope.header["to"] = name & "@example.org"
    envelope.header["cc"] = @["boss1@example.org", "boss2@example.org"].mimeList()
    envelope.header["subject"] = mimeEncoder("Iñtërnâtiônàlizætiøn☃💩", QUOTED_PRINTABLES, true)

    # in multipart the body just contains a warning
    envelope.body = "Warning to old clients: This is a multipart MIME message! "

    var msg = newMimeMessage()
    # in multipart first part is normally displayed by mail agents.
    msg.body = "Dear $# ..." % @[name] 
    envelope.parts.add msg # adding to parts turns the message into multipart.

    # newAttachement returns a prefilled MimeMessage
    if name == "hans": # only hans gets an attachment
      var forhans = newAttachment("<content of image.png>", "image.png", BASE64)
      envelope.parts.add forhans

      var anotherforhans = newAttachment("<content of image.png>", "image.png", QUOTED_PRINTABLES)
      envelope.parts.add anotherforhans      
    envelope.finalize() # computes boundary etc...
    echo $envelope
    echo "===================================================="
```

