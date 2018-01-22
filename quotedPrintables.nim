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

const MAIL_SAFE = Letters + Digits + {'\'', '(',')','+',',','-','.','/',':','=','?'}

proc quoted(str: string, destEncoding: string, srcEncoding = "utf-8"): string =
  ## encodes into Quoted Printables encoding 
  result = ""
  let enc = convert(str,destEncoding, srcEncoding)
  for ch in enc:
    case ch.char
    # of 33..60, 62..126: #9, 32
    of MAIL_SAFE:
      result.add $ch
    else: 
      result.add "="
      result.add ch.ord().toHex(2).toUpper()

proc unQuoted(str: string, srcEncoding: string, destEncoding = "utf-8"): string =
  ## decodes into dest encoding from quoted printables
  result = ""
  var 
    pos = 0
    buf = newStringOfCap(2)
    ch: char
  while pos < str.len:
    buf.setLen 0
    ch = str[pos]
    if ch == '=':
      buf.add str[pos+1] & str[pos+2]
      pos.inc 2 # skip hex chars
      let num = buf.parseHexInt.char
      result.add convert($num, destEncoding, srcEncoding)
    else:
      result.add ch
    pos.inc


when isMainModule and true:
  assert unQuoted("=E4", "iso-8859-1") == "ä"
  assert unQuoted("=E4=E4", "iso-8859-1") == "ää"
  assert unQuoted("a=E4", "iso-8859-1") == "aä"
  
when isMainModule and true:
  assert quoted("a", "iso-8859-1") == "a"
  assert quoted("ä", "iso-8859-1") == "=E4"
  assert quoted("ää", "iso-8859-1") == "=E4=E4"
  assert quoted("aä", "iso-8859-1") == "a=E4"
  assert quoted("aä", "iso-8859-1") == "a=E4"
  assert quoted("\c\l", "iso-8859-1") == "=0D=0A"

  let tst1 = """Hätten Hüte ein ß im Namen, wären sie möglicherweise keine Hüte mehr,
  sondern Hüße."""
  let tst1_quoted = tst1.quoted("iso-8859-1")
  assert tst1_quoted.unQuoted("iso-8859-1") == tst1

  let tst2 = """Здравствуйте"""
  let tst2_quoted = tst2.quoted("koi8-r")
  assert tst2_quoted == "=FA=C4=D2=C1=D7=D3=D4=D7=D5=CA=D4=C5"
  assert tst2_quoted.unQuoted("koi8-r") == tst2
  



# """
# Now's the time =
#  for all folk to come=
#  to the aid of their country."""
# "Now's the time for all folk to come to the aid of their country."

# import dbg

# timeIt "foo":
#   discard quoted("a", "iso-8859-1") == "a"

# echo tst1_quoted.unQuoted("iso-8859-1") 
# echo tst1.quoted("iso-8859-1")
# let sol1 = """H=E4tten H=FCte ein =DF im Namen, w=E4ren sie m=F6glicherweise keine H=FCte=
#  mehr, 
# sondern H=FC=DFe."""