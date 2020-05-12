import std/os

from posix import munmap, mmap, Off,
     ProtRead, ProtWrite, MapFailed, MapShared, MapPopulate

import syscall

#{.passL: "-luring".}
{.pragma: liou, header: "<linux/io_uring.h>", importc.}
{.pragma: liou_t, header: "<linux/io_uring.h>", importc: "struct $1".}
#{.pragma: iou, header: "<liburing.h>", importc.}
#{.pragma: barrier, header: "<liburing/barrier.h>", importc.}
#{.push callConv: cdecl, dynlib: "liburing.so(|.1|.0)".}
{.push callConv: cdecl.}

type
  kernel_rwf {.importc: "__kernel_rwf_t", header: "<linux/fs.h>".} = int
  io_uring_params* {.liou_t, completeStruct.} = object
    sq_entries*: uint32
    cq_entries*: uint32
    flags*: uint32
    sq_thread_cpu: uint32
    sq_thread_idle: uint32
    features: uint32
    wq_fd: uint32
    resv: array[3, uint32]
    sq_off*: io_sqring_offsets
    cq_off*: io_cqring_offsets

  io_uring_cqe* {.liou_t, completeStruct.} = object
    user_data*: pointer
    res*: int32
    flags*: uint32

  sqe_offset {.union.} = object
      off: uint64
      addr2: uint64

  sqe_kflags {.union.} = object
    rw_flags: kernel_rwf
    fsync_flags: uint32
    poll_events: uint16
    sync_range_flags: uint32
    msg_flags: uint32
    timeout_flags: uint32
    accept_flags: uint32
    cancel_flags: uint32
    open_flags: uint32
    statx_flags: uint32
    fadvise_advice: uint32

  sqe_index_person = object
    buf_index: uint16
    personality: uint16

  sqe_extension {.union.} = object
    ip: sqe_index_person
    pad2: array[3, uint64]

  io_uring_sqe* {.liou_t, completeStruct.} = object
    opcode: uint8           # type of operation for this sqe
    flags: uint8            # IOSQE_ flags
    ioprio: uint16          # ioprio for the request
    fd: int32               # file descriptor to do IO on
    offset: sqe_offset
    `addr`: uint64          # pointer to buffer or iovecs
    len: uint32             # buffer size or number of iovecs
    kflags: sqe_kflags
    user_data: uint64       # data to be passed back at completion time
    ext: sqe_extension

  io_sqring_offsets* {.liou_t, completeStruct.} = object
    head*: uint32
    tail*: uint32
    ring_mask*: uint32
    ring_entries*: uint32

    flags*: uint32
    dropped*: uint32
    array*: uint32
    resv1: uint32
    resv2: uint64

  io_cqring_offsets* {.liou_t, completeStruct.} = object
    head*: uint32
    tail*: uint32
    ring_mask*: uint32
    ring_entries*: uint32

    overflow*: uint32
    cqes*: uint32

const
  IoRingOffSqRing*: Off = 0x0
  IoRingOffCqRing*: Off = 0x8000000
  IoRingOffSqes*: Off   = 0x10000000

proc `+`*(p: pointer; i: SomeInteger): pointer =
  result = cast[pointer](cast[uint](p) + i.uint)

proc uringMap*(offset: Off; fd: int32; begin: uint32;
               count: uint32; typ: typedesc): pointer =
  result = mmap(nil, int (begin + count * sizeof(typ).uint32),
                ProtRead or ProtWrite, MapShared or MapPopulate,
                fd.cint, offset)
  if result == MapFailed:
    result = nil
    raise newOsError osLastError()

proc uringUnmap*(p: pointer; size: int) =
  ## interface to tear down some memory (probably mmap'd)
  let
    code = munmap(p, size)
  if code < 0:
    raise newOsError osLastError()

#proc io_uring_queue_init_params*(entries: uint64; ring: ptr io_uring_ring;
#                                 params: ptr io_uring_params): cint {.iou.}
#proc io_uring_queue_init*(entries: uint64; ring: ptr io_uring_ring;
#                          flags: uint): cint {.iou.}
#proc io_uring_queue_exit*(ring: ptr io_uring_ring) {.liou.}
#proc io_uring_submit*(ring: ptr io_uring_ring): cint {.liou.}
#proc io_uring_submit_and_wait*(ring: ptr io_uring_ring;
#                               wait_nr: uint64): cint {.iou.}

proc io_uring_setup*(entries: uint64;
                     params: ptr io_uring_params): int32 =
  result = syscall(IO_URING_SETUP, entries, params).int32
  if result < 0:
    raise newOsError osLastError()
