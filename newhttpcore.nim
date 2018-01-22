#
#
#            Nim's Runtime Library
#        (c) Copyright 2016 Dominik Picheta
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Contains functionality shared between the ``httpclient`` and
## ``asynchttpserver`` modules.

import tables, strutils, parseutils

import mime
export mime

type
  HttpHeaders* = MimeHeaders

  HttpHeaderValues* = MimeHeaderValues

  # The range starts at '0' so that we don't have to explicitly initialise
  # it. See: http://irclogs.nim-lang.org/19-09-2016.html#19:48:27 for context.
  HttpCode* = distinct range[0 .. 599]

  HttpVersion* = enum
    HttpVer11,
    HttpVer10

  HttpMethod* = enum  ## the requested HttpMethod
    HttpHead,         ## Asks for the response identical to the one that would
                      ## correspond to a GET request, but without the response
                      ## body.
    HttpGet,          ## Retrieves the specified resource.
    HttpPost,         ## Submits data to be processed to the identified
                      ## resource. The data is included in the body of the
                      ## request.
    HttpPut,          ## Uploads a representation of the specified resource.
    HttpDelete,       ## Deletes the specified resource.
    HttpTrace,        ## Echoes back the received request, so that a client
                      ## can see what intermediate servers are adding or
                      ## changing in the request.
    HttpOptions,      ## Returns the HTTP methods that the server supports
                      ## for specified address.
    HttpConnect,      ## Converts the request connection to a transparent
                      ## TCP/IP tunnel, usually used for proxies.
    HttpPatch         ## Applies partial modifications to a resource.

{.deprecated: [httpGet: HttpGet, httpHead: HttpHead, httpPost: HttpPost,
               httpPut: HttpPut, httpDelete: HttpDelete, httpTrace: HttpTrace,
               httpOptions: HttpOptions, httpConnect: HttpConnect].}


const
  Http100* = HttpCode(100)
  Http101* = HttpCode(101)
  Http200* = HttpCode(200)
  Http201* = HttpCode(201)
  Http202* = HttpCode(202)
  Http203* = HttpCode(203)
  Http204* = HttpCode(204)
  Http205* = HttpCode(205)
  Http206* = HttpCode(206)
  Http300* = HttpCode(300)
  Http301* = HttpCode(301)
  Http302* = HttpCode(302)
  Http303* = HttpCode(303)
  Http304* = HttpCode(304)
  Http305* = HttpCode(305)
  Http307* = HttpCode(307)
  Http400* = HttpCode(400)
  Http401* = HttpCode(401)
  Http403* = HttpCode(403)
  Http404* = HttpCode(404)
  Http405* = HttpCode(405)
  Http406* = HttpCode(406)
  Http407* = HttpCode(407)
  Http408* = HttpCode(408)
  Http409* = HttpCode(409)
  Http410* = HttpCode(410)
  Http411* = HttpCode(411)
  Http412* = HttpCode(412)
  Http413* = HttpCode(413)
  Http414* = HttpCode(414)
  Http415* = HttpCode(415)
  Http416* = HttpCode(416)
  Http417* = HttpCode(417)
  Http418* = HttpCode(418)
  Http421* = HttpCode(421)
  Http422* = HttpCode(422)
  Http426* = HttpCode(426)
  Http428* = HttpCode(428)
  Http429* = HttpCode(429)
  Http431* = HttpCode(431)
  Http451* = HttpCode(451)
  Http500* = HttpCode(500)
  Http501* = HttpCode(501)
  Http502* = HttpCode(502)
  Http503* = HttpCode(503)
  Http504* = HttpCode(504)
  Http505* = HttpCode(505)

proc newHttpHeaders*(): HttpHeaders = 
  return newMimeHeaders()

proc newHttpHeaders*(keyValuePairs:
    openarray[tuple[key: string, val: string]]): HttpHeaders = 
  return newMimeHeaders(keyValuePairs)

proc `==`*(protocol: tuple[orig: string, major, minor: int],
           ver: HttpVersion): bool =
  let major =
    case ver
    of HttpVer11, HttpVer10: 1
  let minor =
    case ver
    of HttpVer11: 1
    of HttpVer10: 0
  result = protocol.major == major and protocol.minor == minor

proc contains*(methods: set[HttpMethod], x: string): bool =
  return parseEnum[HttpMethod](x) in methods

proc `$`*(code: HttpCode): string =
  ## Converts the specified ``HttpCode`` into a HTTP status.
  ##
  ## For example:
  ##
  ##   .. code-block:: nim
  ##       doAssert($Http404 == "404 Not Found")
  case code.int
  of 100: "100 Continue"
  of 101: "101 Switching Protocols"
  of 200: "200 OK"
  of 201: "201 Created"
  of 202: "202 Accepted"
  of 203: "203 Non-Authoritative Information"
  of 204: "204 No Content"
  of 205: "205 Reset Content"
  of 206: "206 Partial Content"
  of 300: "300 Multiple Choices"
  of 301: "301 Moved Permanently"
  of 302: "302 Found"
  of 303: "303 See Other"
  of 304: "304 Not Modified"
  of 305: "305 Use Proxy"
  of 307: "307 Temporary Redirect"
  of 400: "400 Bad Request"
  of 401: "401 Unauthorized"
  of 403: "403 Forbidden"
  of 404: "404 Not Found"
  of 405: "405 Method Not Allowed"
  of 406: "406 Not Acceptable"
  of 407: "407 Proxy Authentication Required"
  of 408: "408 Request Timeout"
  of 409: "409 Conflict"
  of 410: "410 Gone"
  of 411: "411 Length Required"
  of 412: "412 Precondition Failed"
  of 413: "413 Request Entity Too Large"
  of 414: "414 Request-URI Too Long"
  of 415: "415 Unsupported Media Type"
  of 416: "416 Requested Range Not Satisfiable"
  of 417: "417 Expectation Failed"
  of 418: "418 I'm a teapot"
  of 421: "421 Misdirected Request"
  of 422: "422 Unprocessable Entity"
  of 426: "426 Upgrade Required"
  of 428: "428 Precondition Required"
  of 429: "429 Too Many Requests"
  of 431: "431 Request Header Fields Too Large"
  of 451: "451 Unavailable For Legal Reasons"
  of 500: "500 Internal Server Error"
  of 501: "501 Not Implemented"
  of 502: "502 Bad Gateway"
  of 503: "503 Service Unavailable"
  of 504: "504 Gateway Timeout"
  of 505: "505 HTTP Version Not Supported"
  else: $(int(code))

proc `==`*(a, b: HttpCode): bool {.borrow.}

proc `==`*(rawCode: string, code: HttpCode): bool =
  return cmpIgnoreCase(rawCode, $code) == 0

proc is2xx*(code: HttpCode): bool =
  ## Determines whether ``code`` is a 2xx HTTP status code.
  return code.int in {200 .. 299}

proc is3xx*(code: HttpCode): bool =
  ## Determines whether ``code`` is a 3xx HTTP status code.
  return code.int in {300 .. 399}

proc is4xx*(code: HttpCode): bool =
  ## Determines whether ``code`` is a 4xx HTTP status code.
  return code.int in {400 .. 499}

proc is5xx*(code: HttpCode): bool =
  ## Determines whether ``code`` is a 5xx HTTP status code.
  return code.int in {500 .. 599}

proc `$`*(httpMethod: HttpMethod): string =
  return (system.`$`(httpMethod))[4 .. ^1].toUpperAscii()

when isMainModule:
  var test = newHttpHeaders()
  test["Connection"] = @["Upgrade", "Close"]
  doAssert test["Connection", 0] == "Upgrade"
  doAssert test["Connection", 1] == "Close"
  test.add("Connection", "Test")
  doAssert test["Connection", 2] == "Test"
  doAssert "upgrade" in test["Connection"]

  # Bug #5344.
  doAssert parseHeader("foobar: ") == ("foobar", @[""])
  let (key, value) = parseHeader("foobar: ")
  test = newHttpHeaders()
  test[key] = value
  doAssert test["foobar"] == ""

  doAssert parseHeader("foobar:") == ("foobar", @[""])