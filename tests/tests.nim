import std/os
import std/unittest

import yourang

const
  sixtyFour: uint64 = 64

suite "yourang":
  test "queue":
    var
      q = newQueue(sixtyFour)
    check true
