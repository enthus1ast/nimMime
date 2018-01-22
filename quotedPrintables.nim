## cc David Krause
## Quoted printables encoder/decoder
## https://tools.ietf.org/html/rfc2045#page-19
from unicode import runes, `$`
import encodings, strutils

proc quoted(str: string, destEncoding: string, srcEncoding = "utf-8"): string =
  ## encodes into Quoted Printables encoding 
  result = ""
  for ch in str.runes:
    case ch.int
    of 33..60, 62..126: #9, 32
      result.add $ch
    else: 
      let encoded = convert($ch, destEncoding, srcEncoding)
      result.add "="
      result.add encoded[0].ord().toHex(2).toUpper()

proc unQuoted(str: string, destEncoding: string, srcEncoding = "utf-8"): string =
  ## decodes into dest encoding from quoted printables
  result = ""
  var 
    pos = 0
    buf = newStringOfCap(2)
    ch: char
  while pos < str.len:
    buf.setLen 0
    ch = str[pos]
    # if ch == '=' and 
    if ch == '=':
      # if str[pos+1] not in 
      buf.add str[pos+1] & str[pos+2]
      pos.inc 2 # skip 
      let num = buf.parseHexInt.char
      let decoded = convert($num, destEncoding, srcEncoding)
      result.add decoded
    else:
      result.add ch
    pos.inc


    # case ch.int
    # of 33..60, 62..126: #9, 32
    #   result.add $ch
    # else: 
    #   let encoded = convert($ch, destEncoding, srcEncoding)
    #   result.add "="
    #   result.add encoded[0].ord().toHex(2).toUpper()



when isMainModule and true:
  assert unQuoted("=E4", "utf-8", "iso-8859-1") == "ä"
  assert unQuoted("=E4=E4", "utf-8", "iso-8859-1") == "ää"
  assert unQuoted("a=E4", "utf-8", "iso-8859-1") == "aä"
  
when isMainModule and false:
  assert quoted("a", "iso-8859-1") == "a"
  assert quoted("ä", "iso-8859-1") == "=E4"
  assert quoted("ää", "iso-8859-1") == "=E4=E4"
  assert quoted("aä", "iso-8859-1") == "a=E4"
  assert quoted("aä", "iso-8859-1") == "a=E4"
  assert quoted("\c\l", "iso-8859-1") == "=0D=0A"

# """
# Now's the time =
#  for all folk to come=
#  to the aid of their country."""
# "Now's the time for all folk to come to the aid of their country."

# import dbg

# timeIt "foo":
#   discard quoted("a", "iso-8859-1") == "a"

# let tst1 = """Hätten Hüte ein ß im Namen, wären sie möglicherweise keine Hüte mehr,
# sondern Hüße."""

# let sol1 = """H=E4tten H=FCte ein =DF im Namen, w=E4ren sie m=F6glicherweise keine H=FCte=
#  mehr, 
# sondern H=FC=DFe."""