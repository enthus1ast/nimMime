import unittest, mime
import quotedPrintables
import strutils

suite "attachements":

  test "string needs encoding":
    assert "foo".needsEncoding() == false
    assert "föö".needsEncoding() == true

  #[test "parseList":
    # This is a private proc
    discard parseList(@["foo","baa"].mimeList(), lst, 0)  # TODO "new string"
    assert lst == @["foo","baa"]
    ]#

  test "multipart test":
    var multi = newMimeMessage()
    multi.body = "In multipart messages the body is just a comment for incompatible clients"
    multi.header["to"] = @["foo@nim.org", "baa@nim.org"].mimeList
    multi.header["subject"] = "multiparted US-ASCII for you"

    var first = newMimeMessage()
    first.header["Content-Type"] = "text/plain"
    first.body = "i show up in email readers! i do not end with a linebreak!"
    assert first.needsEncoding() == false
    multi.parts.add first

    var second = newMimeMessage()
    second.header["Content-Type"] = "text/plain"
    second.body = "i am another multipart 42924863215779480875955470471231252136"
    assert second.needsEncoding() == false
    multi.parts.add second

    var third = newMimeMessage()
    third.header["Content-Type"] = "text/plain"
    third.header["Content-Disposition"] = """attachment; filename="test.txt""""
    third.body = "i am manually attached öäü AND i end with a explicit line break\n"
    assert third.needsEncoding() == true
    if third.needsEncoding():
      third.encodeQuotedPrintables()
    multi.parts.add third

    var attachment = newAttachment("i am the filecontent", "filename.png")
    attachment.encodeBase64()
    multi.parts.add attachment

    assert ($multi.finalize()).mimeEncoder(QUOTED_PRINTABLES) == "to: foo=40nim.org, baa=40nim.org=0D=0Asubject: multiparted US-ASCII for you=0D=0Acontent-type: multipart/mixed=3B boundary=3D=226148999798729464813=22=3B charset=3DUTF-8=0D=0A=0D=0AIn multipart messages the body is just a comment for incompatible clients=0D=0A--6148999798729464813=0D=0Acontent-type: text/plain=0D=0A=0D=0Ai show up in email readers! i do not end with a linebreak!=0D=0A--6148999798729464813=0D=0Acontent-type: text/plain=0D=0A=0D=0Ai am another multipart 42924863215779480875955470471231252136=0D=0A--6148999798729464813=0D=0Acontent-type: text/plain=0D=0Acontent-disposition: attachment=3B filename=3D=22test.txt=22=0D=0Acontent-transfer-encoding: QUOTED-PRINTABLE=0D=0A=0D=0Ai am manually attached =3DC3=3DB6=3DC3=3DA4=3DC3=3DBC AND i end with a explicit line break=3D0A=0D=0A--6148999798729464813=0D=0Acontent-disposition: attachment=3B filename=3D=22filename.png=22=0D=0Acontent-type: image/png=3B name=3D=22filename.png=22=0D=0Acontent-transfer-encoding: BASE64=0D=0A=0D=0AaSBhbSB0aGUgZmlsZWNvbnRlbnQ=3D=0D=0A--6148999798729464813--=0D=0A"

  test "concentrate 3 MimeMessages into 1":
    var multi = newMimeMessage()
    multi.header["foo"] = "in multi 1"
    multi.body = "in multi 1"

    assert $multi.header == """{"foo": @["in multi 1"]}"""
    assert $multi.body == "in multi 1"

    var multi2 = newMimeMessage()
    multi2.header["foo"] = "in multi 2"
    multi2.body = "in multi 2"

    assert $multi2.header == """{"foo": @["in multi 2"]}"""
    assert $multi2.body == "in multi 2"

    var normal = newMimeMessage()
    normal.header["foo"] = "in normal--4292486321577948087--"
      # TODO test must use parents boundary!
      # Why?
    normal.body = "in normal"
    multi2.parts.add normal

    multi.parts.add multi2
    multi.parts.add normal
    multi.encodeQuotedPrintables

    assert $multi.header == "{\"foo\": @[\"in multi 1\"]}"
    assert $multi.body == "in multi 1"
    assert ($multi.parts).mimeEncoder(QUOTED_PRINTABLES) == "=40=5Bfoo: in multi 2=0D=0A=0D=0Ain multi 2=0D=0A--=0D=0Afoo: in normal--4292486321577948087--=0D=0A=0D=0Ain normal=0D=0A----=0D=0A, foo: in normal--4292486321577948087--=0D=0A=0D=0Ain normal=5D"

  test "connection in headers":
    var test = newMimeHeaders()
    test["Connection"] = @["Upgrade", "Close"]
    assert test["Connection", 0] == "Upgrade"
    assert test["Connection", 1] == "Close"
    test.add("Connection", "Test")
    assert test["Connection", 2] == "Test"
    assert "upgrade" in test["Connection"]

  #[test "bug 5344":
    # Bug #5344. # TODO
    echo "start"
    echo $parseHeader("foobar: ")
    #assert parseHeader("foobar: ") == ("foobar", @[""])
    echo "mid"
    let (key, value) = parseHeader("foobar: ")
    echo key
    echo value
    var test = newMimeHeaders()
    test[key] = value
    assert test["foobar"] == ""
    assert parseHeader("foobar:") == ("foobar", @[""])]#

  test "mime headers and encoding":
    var test = newMimeHeaders()
    var msg = ""

    test.add("Connection", "Test")
    assert $test == "{\"connection\": @[\"Test\"]}"

    msg.addHeaders(test)
    assert msg.countLines() == 2
    assert msg.mimeEncoder(QUOTED_PRINTABLES) == "connection: Test=0D=0A"

    msg.add(mimeNewline)
    assert msg.countLines() == 3
    assert msg.mimeEncoder(QUOTED_PRINTABLES) == "connection: Test=0D=0A=0D=0A"

    msg.add "body content"
    assert msg.mimeEncoder(QUOTED_PRINTABLES)  == "connection: Test=0D=0A=0D=0Abody content"
    assert msg.mimeEncoder(BASE64) == "Y29ubmVjdGlvbjogVGVzdA0KDQpib2R5IGNvbnRlbnQ="


  test "attachment":
    var
      file = newAttachment("<i am the file content>", "filename.txt", QUOTED_PRINTABLES)
      file2 = newAttachment("<i am another file content>", "filename2.txt", BASE64)
    var email = newEmail("Hello friend", "Iñtërnâtiônàlizætiøn☃💩", "sender@example.org", @["to@example.org"], attachments = @[file,file2])

    assert ($email.finalize()).mimeEncoder(QUOTED_PRINTABLES) == "from: sender=40example.org=0D=0Ato: to=40example.org=0D=0Asubject: =3D=3Futf-8=3FQ=3FHello friend=3F=3D=0D=0Acontent-type: multipart/mixed=3B boundary=3D=229029610844028912693=22=3B charset=3Dutf-8=0D=0A=0D=0AI=C3=B1t=C3=ABrn=C3=A2ti=C3=B4n=C3=A0liz=C3=A6ti=C3=B8n=E2=98=83=F0=9F=92=A9=0D=0A--9029610844028912693=0D=0Acontent-disposition: attachment=3B filename=3D=22filename.txt=22=0D=0Acontent-type: text/plain=3B name=3D=22filename.txt=22=0D=0A=0D=0A=3Ci am the file content=3E=0D=0A--9029610844028912693=0D=0Acontent-disposition: attachment=3B filename=3D=22filename2.txt=22=0D=0Acontent-type: text/plain=3B name=3D=22filename2.txt=22=0D=0A=0D=0A=3Ci am another file content=3E=0D=0A--9029610844028912693--=0D=0A"

  test "multiple to":
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
