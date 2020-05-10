import std/os

import yourang/io_uring

type
  Queue* = object
    ring: ptr ring

  Flag* = enum
    One
    Two

const
  defaultFlags: set[Flag] = {}

converter toFlags*(flags: set[Flag]): uint =
  for flag in flags.items:
    result = result and flag.ord.uint

template okay(body: untyped): bool =
  let code = body
  if code < 0:
    raiseOsError(OsErrorCode(code.abs))
  true

proc newParams(): ptr params =
  result = cast[ptr params](allocShared(sizeof params))

proc newRing(): ptr ring =
  result = cast[ptr ring](allocShared(sizeof ring))

proc newQueue*(entries: uint64; flags = defaultFlags): Queue =
  result.ring = newRing()
  discard okay queueInit(entries, result.ring, flags.toFlags)

proc `=destroy`*(queue: var Queue) =
  queue_exit(queue.ring)
  when defined(yourangDebug):
    echo "destroyed queue"
