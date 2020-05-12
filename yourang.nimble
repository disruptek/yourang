# Package

version       = "0.0.3"
author        = "Andy Davidoff"
description   = "thread-safe performant async io for Linux"
license       = "MIT"
srcDir        = "src"

backend = "c"

# Dependencies

requires "nim >= 1.0.6"
requires "https://github.com/def-/nim-syscall"
