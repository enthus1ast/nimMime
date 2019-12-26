# Copyright 2019 - Thomas T. Jarløv

import mime, smtp
import unittest

const smtpAddress = "mailserver.com"
const smtpPort = 465
const smtpUser  = "username"
const smtpPassword = "password"
const smtpFrom = "from@from.com"
const smtpTo = "to@to.com"

suite "testmails":

  test "config the sending details":
    assert smtpAddress != "mailserver.com"


  test "mail 1 using newEmail()":
    ## Compose your mime message
    var image = newAttachment(readFile("logo.png"), filename = "logo.png")
    image.encodeQuotedPrintables()

    var email = newEmail("Hello friend", "Hey buddy", smtpFrom, @[smtpTo], attachments = @[image])

    ## Send it useing smtp.nim
    var smtpConn = newSmtp(
      useSsl=true,
      debug=true
    )
    smtpConn.connect(smtpAddress, smtpPort.Port)
    smtpConn.auth(smtpUser, smtpPassword)
    smtpConn.sendMail(smtpFrom,  @[smtpTo], $email.finalize())
    smtpConn.close()


  test "mail 2 using manually prepping":
    ## Compose your mime message

    var multi = newMimeMessage()
    multi.body = "In multipart messages the body is just a comment for incompatible clients"
    multi.header["to"] = @[smtpTo].mimeList
    multi.header["subject"] = "multiparted US-ASCII for you"

    var first = newMimeMessage()
    first.header["Content-Type"] = "text/plain"
    first.body = "i show up in email readers! i do not end with a linebreak! påæ"
    if first.needsEncoding():
      first.encodeQuotedPrintables()
    multi.parts.add first

    var image = newAttachment(readFile("logo.png"), filename = "logo.png")
    image.encodeQuotedPrintables()

    multi.parts.add image

    ## Send it useing smtp.nim
    var smtpConn = newSmtp(
      useSsl=true,
      debug=true
    )
    smtpConn.connect(smtpAddress, smtpPort.Port)
    smtpConn.auth(smtpUser, smtpPassword)
    smtpConn.sendMail(smtpFrom,  @[smtpFrom], $multi.finalize())
    smtpConn.close()
