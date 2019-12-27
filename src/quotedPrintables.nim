## cc David Krause
## Quoted printables encoder/decoder
## https://tools.ietf.org/html/rfc2045#page-19

# https://tools.ietf.org/html/rfc2049
# In particular, the only characters that are
#           known to be consistent across all gateways are the 73
#           characters that correspond to the upper and lower case
#           letters A-Z and a-z, the 10 digits 0-9, and the
#           following eleven special characters:

#             "'"  (US-ASCII decimal value 39)
#             "("  (US-ASCII decimal value 40)
#             ")"  (US-ASCII decimal value 41)
#             "+"  (US-ASCII decimal value 43)
#             ","  (US-ASCII decimal value 44)
#             "-"  (US-ASCII decimal value 45)
#             "."  (US-ASCII decimal value 46)
#             "/"  (US-ASCII decimal value 47)
#             ":"  (US-ASCII decimal value 58)
#             "="  (US-ASCII decimal value 61)
#             "?"  (US-ASCII decimal value 63)
# A maximally portable mail representation will confine
#           itself to relatively short lines of text in which the
#           only meaningful characters are taken from this set of
#           73 characters.  The base64 encoding follows this rule.

import encodings, strutils

# const MAIL_SAFE = Letters + Digits + {'\'', '(',')','+',',','-','.','/',':','=','?'}
const MAIL_SAFE* = Letters + Digits + {'\'', '(',')','+',',','-','.','/',':', ' ', '!'}

template addCL() = 
  result.add "=\c\l"
  lineChars = 0  

proc quoted*(str: string, destEncoding: string, srcEncoding = "utf-8", newlineAt = 76): string =
  ## encodes into Quoted Printables encoding 
  result = ""
  var lineChars = 0
  let enc = convert(str,destEncoding, srcEncoding) # TODO maybe iterate on runes (or so)?
  for ch in enc:
    case ch.char
    of MAIL_SAFE:
      if lineChars >= newlineAt - 2: # ch + '='
        addCl
      result.add $ch
      lineChars.inc
    else: 
      if lineChars >= newlineAt - 4: # "=FF" + '='
        addCl
      result.add "="
      result.add ch.ord().toHex(2)
      lineChars.inc 3 # encoding look like "=ff"

proc unQuoted*(str: string, srcEncoding: string, destEncoding = "utf-8"): string =
  ## decodes into dest encoding from quoted printables
  result = ""
  var 
    pos:int
    ch: char
  for line in str.splitLines():
    let mline = strip(line, leading = false, trailing = true, chars = {'='})
    pos = 0
    while pos < mline.len:
      ch = mline[pos]
      if ch == '=':
        let buf = mline[pos+1] & mline[pos+2]
        pos.inc 2 #  skip hex chars
        var hexNum: char
        try:
          hexNum = buf.parseHexInt.char
          result.add convert($hexNum, destEncoding, srcEncoding)
        except:
          # we be robust and do not fail here
          echo "could not parse char:", buf , " at idx ", pos
      else:
        result.add ch
      pos.inc

const testing = true
when isMainModule and testing:
  assert unQuoted("=E4", "iso-8859-1") == "ä"
  assert unQuoted("=E4=E4", "iso-8859-1") == "ää"
  assert unQuoted("a=E4", "iso-8859-1") == "aä"
  
when isMainModule and testing:
  assert quoted("=", "iso-8859-1") == "=3D"
  assert quoted("a", "iso-8859-1") == "a"
  assert quoted("ä", "iso-8859-1") == "=E4"
  assert quoted("ää", "iso-8859-1") == "=E4=E4"
  assert quoted("aä", "iso-8859-1") == "a=E4"
  assert quoted("aä", "iso-8859-1") == "a=E4"
  assert quoted("\c\l", "iso-8859-1") == "=0D=0A"

  let tst1 = "Hätten Hüte ein ß im Namen, wären sie möglicherweise keine Hüte mehr,\nsondern Hüße."
  let tst1_quoted = tst1.quoted("iso-8859-1")
  assert tst1_quoted.unQuoted("iso-8859-1") == tst1

  let tst2 = """Здравствуйте"""
  let tst2_quoted = tst2.quoted("koi8-r")
  assert tst2_quoted == "=FA=C4=D2=C1=D7=D3=D4=D7=D5=CA=D4=C5"
  assert tst2_quoted.unQuoted("koi8-r") == tst2
  assert tst2_quoted.quoted("koi8-r").unQuoted("koi8-r").unQuoted("koi8-r") == tst2
  
  assert "=E4=\c\l=E4".unQuoted("iso-8859-1") == "ää"

  let internat = "Iñtërnâtiônàlizætiøn☃💩"
  let internatTst = "I=C3=B1t=C3=ABrn=C3=A2ti=C3=B4n=C3=A0liz=C3=A6ti=C3=B8n=E2=98=83=F0=9F=92=\r\n=A9"
  assert internat.quoted("utf-8") == internatTst
  assert internatTst.unQuoted("utf-8") == internat
  
when isMainModule and testing:
  # binary test
  import os
  let f = readFile(getAppFilename())
  var s = f.quoted("utf-8")
  assert s.unQuoted("utf-8") == f

when isMainModule: #mime kit tests
  let input = "This is an ordinary text message in which my name (=ED=E5=EC=F9 =EF=E1 =E9=EC=E8=F4=F0)\nis in Hebrew (=FA=E9=F8=E1=F2).";
  echo input.unQuoted("iso-8859-8", "utf-8") # do we fail here? TODO
  # const string expected = "This is an ordinary text message in which my name (םולש ןב ילטפנ)\nis in Hebrew (תירבע).";
  # var encoding = Encoding.GetEncoding ("iso-8859-8");
