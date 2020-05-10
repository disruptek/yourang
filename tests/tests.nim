import std/os
import std/unittest

import yourang/io_uring

template okay(body: untyped): bool =
  let code = body
  if code < 0:
    raiseOsError(OsErrorCode(code.abs))
  true

const
  sixtyFour: uint64 = 64

suite "yourang":
  test "queueInit":
    var
      r = newRing()
      flags: set[Flag] = {}
    try:
      check okay queueInit(sixtyFour, r, flags)
      queueExit(r)
    finally:
      dealloc r

  test "queueInitParams":
    var
      r = newRing()
      p = newParams()
    try:
      check okay queueInitParams(sixtyFour, r, p)
      queueExit(r)
    finally:
      dealloc r
      dealloc p
