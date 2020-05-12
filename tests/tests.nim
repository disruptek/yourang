import std/os
import std/unittest

import yourang

const
  sixtyFour = Entries.e64

suite "yourang":
  test "queue":
    var
      q = newQueue(sixtyFour)
    check true
