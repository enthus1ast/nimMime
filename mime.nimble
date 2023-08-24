# Package
version       = "0.0.4"
author        = "enthus1ast"
description   = "mime generator (email with attachments)"
license       = "MIT"
installDirs   = @["src"]

# Dependencies

requires "nim >= 1.2.0"

when NimMajor >= 2:
  requires "smtp >= 0.1.0"
