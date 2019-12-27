# mime - attach files to emails

Nim's standard library does not support attaching files to emails. This library provides you with the tools to do it.

____

1. Please note that this is a work in process.
2. Please give feedback how you would like to use a "mime.nim"

It implements "quoted printables" https://en.wikipedia.org/wiki/Quoted-printable
and also introduces a MimeMessage object.


## Example sending email with attachment:

```nim
import mime, smtp

## Compose your mime message
var
  file = newAttachment("<i am the file content>", "filename.txt", QUOTED_PRINTABLES)
  file2 = newAttachment("<i am another file content>", "filename2.txt", BASE64)
  pdf = newAttachment(readFile("important.pdf"), filename = "important.pdf")

pdf.encodeQuotedPrintables()

var email = newEmail("Hello friend", "Iñtërnâtiônàlizætiøn☃💩", "sender@example.org", @["to@example.org"], attachments = @[file,file2,pdf])

## Send it using smtp.nim
var smtpConn = newSmtp(
  useSsl=true,
  debug=true
)
smtpConn.connect("myemailserver.loc", 587.Port)
smtpConn.auth("sender@example.loc", "mypassword")
smtpConn.sendMail("sender@example.org",  @["to@example.org"] , $email.finalize())
smtpConn.close()
```


## Example sending email with body and attachment:

```nim
import mime, smtp

const smtpAddress = "mailserver.com"
const smtpPort = 465
const smtpUser  = "123456"
const smtpPassword = "pass"
const smtpFrom = "test@maildomain.com"

var multi = newMimeMessage()

# Main data
multi.body = "In multipart messages this is just a comment for incompatible clients"
multi.header["to"] = @["to@domain.com"].mimeList
multi.header["subject"] = "Email subject"

# Add text to email body
var first = newMimeMessage()
first.header["Content-Type"] = "text/plain"
first.body = "I show up in the email!"
multi.parts.add first

# Add attachement
var image = newAttachment(readFile("tests/logo.png"), filename = "logo.png")
image.encodeQuotedPrintables()
multi.parts.add image

# Send it using smtp.nim
var smtpConn = newSmtp(
  useSsl=true,
  debug=true
)
smtpConn.connect(smtpAddress, smtpPort.Port)
smtpConn.auth(smtpUser, smtpPassword)
smtpConn.sendMail(smtpFrom,  @["to@domain.com"], $multi.finalize())
smtpConn.close()
```


## A multipart example of an email could look like:

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
