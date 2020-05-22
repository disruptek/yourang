import std/locks
import std/os

import yourang/io_uring

type

  SqRingFlags {.pure.} = enum
    Invalid
    NeedWakeup = 1

  ## the queue holds the pointer to the ring and some other details
  ## about the state of the queue that we hold on to as a convenience
  Queue* = object
    lock: Lock
    read: Lock
    write: Lock
    flags: uint32
    fd: int32
    cq: Ring
    sq: Ring
    sqes: pointer
    params: ptr io_uring_params
    teardown: proc (q: var Queue)

  RingKind = enum
    Sq
    Cq

  ## holds a pointer to the ring and variable admin addresses according to
  ## which kind of ring we're working with
  Ring = object
    head: pointer
    tail: pointer
    ring_mask: pointer
    ring_entries: pointer
    size: Entries
    ring: pointer
    case kind: RingKind
    of Sq:
      flags: uint32
      dropped: pointer
      array: pointer
    of Cq:
      overflow: pointer
      cqes: pointer

  Flag = enum
    One
    Two

  ## number of entries in a given ring
  Entries* {.pure.} = enum
    e1 = 1
    e2 = 2
    e4 = 4
    e8 = 8
    e16 = 16
    e32 = 32
    e64 = 64
    e128 = 128
    e256 = 256
    e512 = 512
    e1024 = 1024
    e2048 = 2048
    e4096 = 4096

  # convenience typeclass
  Offsets = io_sqring_offsets or io_cqring_offsets

const
  defaultFlags: set[Flag] = {}
  validEntries = {Entries.low.cint .. Entries.high.cint}

when false:
  converter toFlags(flags: set[Flag]): uint =
    for flag in flags.items:
      result = result and flag.ord.uint

template raisin(body: untyped): bool =
  ## try to run the body and raise an OSError if necessary
  let code = body
  if code < 0:
    raiseOsError(OsErrorCode(code.abs))
  code >= 0

# implicitly generic via the typeclass
proc init(ring: var Ring; offset: ptr Offsets) =
  ## setup common properties of a Ring given a struct of Offsets
  ring.head = ring.ring + offset.head
  ring.tail = ring.ring + offset.tail
  ring.ring_mask = ring.ring + offset.ring_mask
  ring.ring_entries = ring.ring + offset.ring_entries
  assert offset.ring_entries > 0
  assert offset.ring_entries in validEntries

proc newRing(fd: int32; offset: ptr io_cqring_offsets; size: uint32): Ring =
  ## mmap a Cq ring from the given file-descriptor, using the size spec'd
  assert size in validEntries
  result = Ring(kind: Cq, size: size.Entries)
  let
    ring = IoRingOffCqRing.uringMap(fd, offset.cqes, size, io_uring_cqe)
  result.ring = ring
  result.cqes = ring + offset.cqes
  result.overflow = ring + offset.overflow
  result.init offset

proc newRing(fd: int32; offset: ptr io_sqring_offsets; size: uint32): Ring =
  ## mmap a Sq ring from the given file-descriptor, using the size spec'd
  assert size in validEntries
  result = Ring(kind: Sq, size: size.Entries)
  let
    ring = IoRingOffSqRing.uringMap(fd, offset.array, size, pointer)
  result.ring = ring
  result.array = ring + offset.array
  result.dropped = ring + offset.dropped
  result.init offset

when false:
  proc submit*(queue: var Queue; wait: uint64 = 0) =
    ## submit some events
    if wait == 0:
      discard raisin io_uring_submit(queue.sq.ring)
    else:
      discard raisin io_uring_submit_and_wait(queue.sq.ring, wait)

proc teardown(ring: Ring; size: int) =
  ## tear down a ring
  case ring.kind
  of Sq:
    uringUnmap(ring.ring, size * sizeof(pointer))
  of Cq:
    uringUnmap(ring.ring, size * sizeof(io_uring_cqe))

proc `=destroy`(queue: var Queue) =
  ## tear down the queue
  acquire queue.lock
  acquire queue.read
  acquire queue.write

  if queue.teardown != nil:
    uringUnmap(queue.sqes, queue.params.sq_entries.int)
    teardown(queue.cq, queue.params.cq_entries.int)
    teardown(queue.sq, queue.params.sq_entries.int)
    #io_uring_queue_exit(queue.cq.ring)
    #io_uring_queue_exit(queue.sq.ring)

  # these do not work outside of arc
  deinitLock queue.lock
  deinitLock queue.read
  deinitLock queue.write

  when defined(yourangDebug):
    echo "destroyed queue"

proc newQueue*(entries: Entries; flags = defaultFlags): Queue =
  var
    params = cast[ptr io_uring_params](allocShared(sizeof io_uring_params))
  initLock result.lock
  initLock result.read
  initLock result.write

  # ask the kernel for the file-descriptor to a ring pair of the spec'd size
  # this also populates the contents of the params object
  result.fd = io_uring_setup(entries.uint64, params)

  # save that
  result.params = params
  # also save the flags that the kernel came back with
  result.flags = params.flags

  # setup the two rings
  result.cq = newRing(result.fd, addr params.cq_off, size = params.cq_entries)
  result.sq = newRing(result.fd, addr params.sq_off, size = params.sq_entries)

  # setup sqe array
  result.sqes = IORingOffSqes.uringMap(result.fd, params.sq_off.array,
                                       params.sq_entries, uint32)

  # set the teardown proc if we make it this far
  result.teardown = `=destroy`

proc read_barrier() =
  {.warning: "tbd".}
  discard

proc write_barrier() =
  {.warning: "tbd".}
  discard

template consume*(queue: var Queue; body: untyped): untyped =
  ## consume Completion Queue Event

  var
    head = queue.cq.head
  read_barrier()
  if head != queue.cq.tail:
    let
      index = head and queue.cq.mask
    var
      event {.inject.} = queue.cq.cqes[index]
    body
    inc head
    queue.cq.head = head
    write_barrier()

template produce*(queue: var Queue; body: untyped): untyped =
  ## produce Submission Queue Event
  var
    tail = queue.sq.tail
  let
    index = tail and queue.sq.ring_mask
  var
    event {.inject.} = queue.sqes[index]
  body
  # fill the sqe index into the SQ ring array
  queue.sq.`array`[index] = index
  inc tail
  write_barrier()
  queue.sq.tail = tail
  write_barrier()
