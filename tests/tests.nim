import std/os
import std/unittest

import yourang/io_uring

template okay(body: untyped): bool =
  let code = body
  if code < 0:
    raiseOsError(OsErrorCode(code.abs))
  true

suite "yourang":
  test "queueInit":
    var
      z = 64'u64
      p = cast[ptr params](allocShared(sizeof(params)))
      r = cast[ptr ring](allocShared(sizeof(ring)))
    check okay queueInit(z, r, p)
