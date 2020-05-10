#[

struct io_uring_cqe {
  __u64 user_data;
  __s32 res;
  __u32 flags;
};

struct io_uring_sqe {
  __u8 opcode;
  __u8 flags;
  __u16 ioprio;
  __s32 fd;
  __u64 off;
  __u64 addr;
  __u32 len;
  union {
    __kernel_rwf_t rw_flags;
    __u32 fsync_flags;
    __u16 poll_events;
    __u32 sync_range_flags;
    __u32 msg_flags;
  };
  __u64 user_data;
  union {
    __u16 buf_index;
    __u64 __pad2[3];
  };
};

]#

{.passL: "-luring".}
{.pragma: iou, header: "<liburing.h>".}
{.pragma: iou_type, iou, importcpp: "io_uring_$1".}
{.pragma: iou_proc, iou, importcpp: "io_uring_$1(@)".}
{.push callConv: cdecl, dynlib: "liburing.so(|.1|.0)".}

type
  params* {.iou_type.} = object
  ring* {.iou, importcpp: "io_uring".} = object

proc queue_init_params(entries: uint64; ring: ptr ring;
                       params: ptr params): cint {.iou_proc.}
proc queue_init*(entries: uint64; ring: ptr ring;
                 flags: uint): cint {.iou_proc.}
proc queue_exit*(ring: ptr ring) {.iou_proc.}
