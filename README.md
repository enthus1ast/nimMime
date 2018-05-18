1. Please note that this is a work in process.
2. Please give feedback how you would like to use a "mime.nim"

mime.nim is MIME related code mostly copy pasted from
- httpcore.nim
- smtp.nim
- asynchttpserver

it implements "quoted printables" https://en.wikipedia.org/wiki/Quoted-printable
and also introduces a MimeMessage object.

this repository contains a few sdtlib modules, patched to use MimeMessage.


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

  
example sending email with attachment:

```nim
  import mime, smtp

  ## Compose your mime message
  var 
    file = newAttachment("<i am the file content>", "filename.txt", QUOTED_PRINTABLES)
    file2 = newAttachment("<i am another file content>", "filename2.txt", BASE64)
  var email = newEmail("Hello friend", "Iñtërnâtiônàlizætiøn☃💩", "sender@example.org", @["to@example.org"], attachments = @[file,file2])

  ## Send it useing smtp.nim
  var smtpConn = newSmtp(
    conf["use_tls"].parseBool,
    debug=true
  )
  smtpConn.connect("myemailserver.loc", 587.Port)
  smtpConn.auth("sender@example.loc", "mypassword")
  smtpConn.sendMail("sender@example.org",  @["to@example.org"] , $email.finalize())
  smtpConn.close()  
```

