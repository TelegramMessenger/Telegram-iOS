/*
 * Copyright (C) 2023 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/*
 * This file declares the WASI interface. The definitions of types, macros and
 * structures in this file should be consistent with those in wasi-libc:
 * https://github.com/WebAssembly/wasi-libc/blob/main/libc-bottom-half/headers/public/wasi/api.h
 */

#ifndef _PLATFORM_WASI_TYPES_H
#define _PLATFORM_WASI_TYPES_H

#include "../../../config.h"

#include <stdint.h>
#include <stddef.h>

/* clang-format off */

#ifdef __cplusplus
#ifndef _Static_assert
#define _Static_assert static_assert
#endif /* _Static_assert */

#ifndef _Alignof
#define _Alignof alignof
#endif /* _Alignof */

extern "C" {
#endif

/* There is no need to check the WASI layout if we're using uvwasi or libc-wasi
 * is not enabled at all. */
#if WASM_ENABLE_UVWASI != 0 || WASM_ENABLE_LIBC_WASI == 0
#define assert_wasi_layout(expr, message) /* nothing */
#else
#define assert_wasi_layout(expr, message) _Static_assert(expr, message)
#endif

assert_wasi_layout(_Alignof(int8_t) == 1, "non-wasi data layout");
assert_wasi_layout(_Alignof(uint8_t) == 1, "non-wasi data layout");
assert_wasi_layout(_Alignof(int16_t) == 2, "non-wasi data layout");
assert_wasi_layout(_Alignof(uint16_t) == 2, "non-wasi data layout");
assert_wasi_layout(_Alignof(int32_t) == 4, "non-wasi data layout");
assert_wasi_layout(_Alignof(uint32_t) == 4, "non-wasi data layout");
#if 0
assert_wasi_layout(_Alignof(int64_t) == 8, "non-wasi data layout");
assert_wasi_layout(_Alignof(uint64_t) == 8, "non-wasi data layout");
#endif

typedef uint32_t __wasi_size_t;
assert_wasi_layout(_Alignof(__wasi_size_t) == 4, "non-wasi data layout");

typedef uint8_t __wasi_advice_t;
#define __WASI_ADVICE_NORMAL     (0)
#define __WASI_ADVICE_SEQUENTIAL (1)
#define __WASI_ADVICE_RANDOM     (2)
#define __WASI_ADVICE_WILLNEED   (3)
#define __WASI_ADVICE_DONTNEED   (4)
#define __WASI_ADVICE_NOREUSE    (5)

typedef uint32_t __wasi_clockid_t;
#define __WASI_CLOCK_REALTIME           (0)
#define __WASI_CLOCK_MONOTONIC          (1)
#define __WASI_CLOCK_PROCESS_CPUTIME_ID (2)
#define __WASI_CLOCK_THREAD_CPUTIME_ID  (3)

typedef uint64_t __wasi_device_t;

typedef uint64_t __wasi_dircookie_t;
#define __WASI_DIRCOOKIE_START (0)

typedef uint32_t __wasi_dirnamlen_t;

typedef uint16_t __wasi_errno_t;
#define __WASI_ESUCCESS        (0)
#define __WASI_E2BIG           (1)
#define __WASI_EACCES          (2)
#define __WASI_EADDRINUSE      (3)
#define __WASI_EADDRNOTAVAIL   (4)
#define __WASI_EAFNOSUPPORT    (5)
#define __WASI_EAGAIN          (6)
#define __WASI_EALREADY        (7)
#define __WASI_EBADF           (8)
#define __WASI_EBADMSG         (9)
#define __WASI_EBUSY           (10)
#define __WASI_ECANCELED       (11)
#define __WASI_ECHILD          (12)
#define __WASI_ECONNABORTED    (13)
#define __WASI_ECONNREFUSED    (14)
#define __WASI_ECONNRESET      (15)
#define __WASI_EDEADLK         (16)
#define __WASI_EDESTADDRREQ    (17)
#define __WASI_EDOM            (18)
#define __WASI_EDQUOT          (19)
#define __WASI_EEXIST          (20)
#define __WASI_EFAULT          (21)
#define __WASI_EFBIG           (22)
#define __WASI_EHOSTUNREACH    (23)
#define __WASI_EIDRM           (24)
#define __WASI_EILSEQ          (25)
#define __WASI_EINPROGRESS     (26)
#define __WASI_EINTR           (27)
#define __WASI_EINVAL          (28)
#define __WASI_EIO             (29)
#define __WASI_EISCONN         (30)
#define __WASI_EISDIR          (31)
#define __WASI_ELOOP           (32)
#define __WASI_EMFILE          (33)
#define __WASI_EMLINK          (34)
#define __WASI_EMSGSIZE        (35)
#define __WASI_EMULTIHOP       (36)
#define __WASI_ENAMETOOLONG    (37)
#define __WASI_ENETDOWN        (38)
#define __WASI_ENETRESET       (39)
#define __WASI_ENETUNREACH     (40)
#define __WASI_ENFILE          (41)
#define __WASI_ENOBUFS         (42)
#define __WASI_ENODEV          (43)
#define __WASI_ENOENT          (44)
#define __WASI_ENOEXEC         (45)
#define __WASI_ENOLCK          (46)
#define __WASI_ENOLINK         (47)
#define __WASI_ENOMEM          (48)
#define __WASI_ENOMSG          (49)
#define __WASI_ENOPROTOOPT     (50)
#define __WASI_ENOSPC          (51)
#define __WASI_ENOSYS          (52)
#define __WASI_ENOTCONN        (53)
#define __WASI_ENOTDIR         (54)
#define __WASI_ENOTEMPTY       (55)
#define __WASI_ENOTRECOVERABLE (56)
#define __WASI_ENOTSOCK        (57)
#define __WASI_ENOTSUP         (58)
#define __WASI_ENOTTY          (59)
#define __WASI_ENXIO           (60)
#define __WASI_EOVERFLOW       (61)
#define __WASI_EOWNERDEAD      (62)
#define __WASI_EPERM           (63)
#define __WASI_EPIPE           (64)
#define __WASI_EPROTO          (65)
#define __WASI_EPROTONOSUPPORT (66)
#define __WASI_EPROTOTYPE      (67)
#define __WASI_ERANGE          (68)
#define __WASI_EROFS           (69)
#define __WASI_ESPIPE          (70)
#define __WASI_ESRCH           (71)
#define __WASI_ESTALE          (72)
#define __WASI_ETIMEDOUT       (73)
#define __WASI_ETXTBSY         (74)
#define __WASI_EXDEV           (75)
#define __WASI_ENOTCAPABLE     (76)

#if defined(_MSC_VER)
#define ALIGNED_(x) __declspec(align(x))
#define WARN_UNUSED _Check_return_
#elif defined(__GNUC__)
#define ALIGNED_(x) __attribute__ ((aligned(x)))
#define WARN_UNUSED __attribute__((__warn_unused_result__))
#endif

#define ALIGNED_TYPE(t,x) typedef t ALIGNED_(x)

typedef uint16_t __wasi_eventrwflags_t;
#define __WASI_EVENT_FD_READWRITE_HANGUP (0x0001)

typedef uint8_t __wasi_eventtype_t;
#define __WASI_EVENTTYPE_CLOCK          (0)
#define __WASI_EVENTTYPE_FD_READ        (1)
#define __WASI_EVENTTYPE_FD_WRITE       (2)

typedef uint32_t __wasi_exitcode_t;

typedef uint32_t __wasi_fd_t;

typedef uint16_t __wasi_fdflags_t;
#define __WASI_FDFLAG_APPEND   (0x0001)
#define __WASI_FDFLAG_DSYNC    (0x0002)
#define __WASI_FDFLAG_NONBLOCK (0x0004)
#define __WASI_FDFLAG_RSYNC    (0x0008)
#define __WASI_FDFLAG_SYNC     (0x0010)

typedef int64_t __wasi_filedelta_t;

typedef uint64_t __wasi_filesize_t;

typedef uint8_t __wasi_filetype_t;
#define __WASI_FILETYPE_UNKNOWN          (0)
#define __WASI_FILETYPE_BLOCK_DEVICE     (1)
#define __WASI_FILETYPE_CHARACTER_DEVICE (2)
#define __WASI_FILETYPE_DIRECTORY        (3)
#define __WASI_FILETYPE_REGULAR_FILE     (4)
#define __WASI_FILETYPE_SOCKET_DGRAM     (5)
#define __WASI_FILETYPE_SOCKET_STREAM    (6)
#define __WASI_FILETYPE_SYMBOLIC_LINK    (7)

typedef uint16_t __wasi_fstflags_t;
#define __WASI_FILESTAT_SET_ATIM     (0x0001)
#define __WASI_FILESTAT_SET_ATIM_NOW (0x0002)
#define __WASI_FILESTAT_SET_MTIM     (0x0004)
#define __WASI_FILESTAT_SET_MTIM_NOW (0x0008)

typedef uint64_t __wasi_inode_t;

ALIGNED_TYPE(uint64_t, 8) __wasi_linkcount_t;

typedef uint32_t __wasi_lookupflags_t;
#define __WASI_LOOKUP_SYMLINK_FOLLOW (0x00000001)

typedef uint16_t __wasi_oflags_t;
#define __WASI_O_CREAT     (0x0001)
#define __WASI_O_DIRECTORY (0x0002)
#define __WASI_O_EXCL      (0x0004)
#define __WASI_O_TRUNC     (0x0008)

typedef uint16_t __wasi_riflags_t;
#define __WASI_SOCK_RECV_PEEK    (0x0001)
#define __WASI_SOCK_RECV_WAITALL (0x0002)

typedef uint64_t __wasi_rights_t;

/**
 * Observe that WASI defines rights in the plural form
 * TODO: refactor to use RIGHTS instead of RIGHT
 */
#define __WASI_RIGHT_FD_DATASYNC ((__wasi_rights_t)(UINT64_C(1) << 0))
#define __WASI_RIGHT_FD_READ ((__wasi_rights_t)(UINT64_C(1) << 1))
#define __WASI_RIGHT_FD_SEEK ((__wasi_rights_t)(UINT64_C(1) << 2))
#define __WASI_RIGHT_FD_FDSTAT_SET_FLAGS ((__wasi_rights_t)(UINT64_C(1) << 3))
#define __WASI_RIGHT_FD_SYNC ((__wasi_rights_t)(UINT64_C(1) << 4))
#define __WASI_RIGHT_FD_TELL ((__wasi_rights_t)(UINT64_C(1) << 5))
#define __WASI_RIGHT_FD_WRITE ((__wasi_rights_t)(UINT64_C(1) << 6))
#define __WASI_RIGHT_FD_ADVISE ((__wasi_rights_t)(UINT64_C(1) << 7))
#define __WASI_RIGHT_FD_ALLOCATE ((__wasi_rights_t)(UINT64_C(1) << 8))
#define __WASI_RIGHT_PATH_CREATE_DIRECTORY ((__wasi_rights_t)(UINT64_C(1) << 9))
#define __WASI_RIGHT_PATH_CREATE_FILE ((__wasi_rights_t)(UINT64_C(1) << 10))
#define __WASI_RIGHT_PATH_LINK_SOURCE ((__wasi_rights_t)(UINT64_C(1) << 11))
#define __WASI_RIGHT_PATH_LINK_TARGET ((__wasi_rights_t)(UINT64_C(1) << 12))
#define __WASI_RIGHT_PATH_OPEN ((__wasi_rights_t)(UINT64_C(1) << 13))
#define __WASI_RIGHT_FD_READDIR ((__wasi_rights_t)(UINT64_C(1) << 14))
#define __WASI_RIGHT_PATH_READLINK ((__wasi_rights_t)(UINT64_C(1) << 15))
#define __WASI_RIGHT_PATH_RENAME_SOURCE ((__wasi_rights_t)(UINT64_C(1) << 16))
#define __WASI_RIGHT_PATH_RENAME_TARGET ((__wasi_rights_t)(UINT64_C(1) << 17))
#define __WASI_RIGHT_PATH_FILESTAT_GET ((__wasi_rights_t)(UINT64_C(1) << 18))
#define __WASI_RIGHT_PATH_FILESTAT_SET_SIZE ((__wasi_rights_t)(UINT64_C(1) << 19))
#define __WASI_RIGHT_PATH_FILESTAT_SET_TIMES ((__wasi_rights_t)(UINT64_C(1) << 20))
#define __WASI_RIGHT_FD_FILESTAT_GET ((__wasi_rights_t)(UINT64_C(1) << 21))
#define __WASI_RIGHT_FD_FILESTAT_SET_SIZE ((__wasi_rights_t)(UINT64_C(1) << 22))
#define __WASI_RIGHT_FD_FILESTAT_SET_TIMES ((__wasi_rights_t)(UINT64_C(1) << 23))
#define __WASI_RIGHT_PATH_SYMLINK ((__wasi_rights_t)(UINT64_C(1) << 24))
#define __WASI_RIGHT_PATH_REMOVE_DIRECTORY ((__wasi_rights_t)(UINT64_C(1) << 25))
#define __WASI_RIGHT_PATH_UNLINK_FILE ((__wasi_rights_t)(UINT64_C(1) << 26))
#define __WASI_RIGHT_POLL_FD_READWRITE ((__wasi_rights_t)(UINT64_C(1) << 27))
#define __WASI_RIGHT_SOCK_CONNECT ((__wasi_rights_t)(UINT64_C(1) << 28))
#define __WASI_RIGHT_SOCK_LISTEN ((__wasi_rights_t)(UINT64_C(1) << 29))
#define __WASI_RIGHT_SOCK_BIND ((__wasi_rights_t)(UINT64_C(1) << 30))
#define __WASI_RIGHT_SOCK_ACCEPT ((__wasi_rights_t)(UINT64_C(1) << 31))
#define __WASI_RIGHT_SOCK_RECV ((__wasi_rights_t)(UINT64_C(1) << 32))
#define __WASI_RIGHT_SOCK_SEND ((__wasi_rights_t)(UINT64_C(1) << 33))
#define __WASI_RIGHT_SOCK_ADDR_LOCAL ((__wasi_rights_t)(UINT64_C(1) << 34))
#define __WASI_RIGHT_SOCK_ADDR_REMOTE ((__wasi_rights_t)(UINT64_C(1) << 35))
#define __WASI_RIGHT_SOCK_RECV_FROM ((__wasi_rights_t)(UINT64_C(1) << 36))
#define __WASI_RIGHT_SOCK_SEND_TO ((__wasi_rights_t)(UINT64_C(1) << 37))

typedef uint16_t __wasi_roflags_t;
#define __WASI_SOCK_RECV_DATA_TRUNCATED (0x0001)

typedef uint8_t __wasi_sdflags_t;
#define __WASI_SHUT_RD (0x01)
#define __WASI_SHUT_WR (0x02)

typedef uint16_t __wasi_siflags_t;

typedef uint8_t __wasi_signal_t;

typedef uint16_t __wasi_subclockflags_t;
#define __WASI_SUBSCRIPTION_CLOCK_ABSTIME (0x0001)

typedef uint64_t __wasi_timestamp_t;

typedef uint64_t __wasi_userdata_t;

typedef uint8_t __wasi_whence_t;
#define __WASI_WHENCE_SET (0)
#define __WASI_WHENCE_CUR (1)
#define __WASI_WHENCE_END (2)

typedef uint8_t __wasi_preopentype_t;
#define __WASI_PREOPENTYPE_DIR              (0)

struct fd_table;
struct fd_prestats;
struct argv_environ_values;
struct addr_pool;

typedef struct ALIGNED_(8) __wasi_dirent_t {
    __wasi_dircookie_t d_next;
    __wasi_inode_t d_ino;
    __wasi_dirnamlen_t d_namlen;
    __wasi_filetype_t d_type;
} __wasi_dirent_t;
assert_wasi_layout(offsetof(__wasi_dirent_t, d_next) == 0, "non-wasi data layout");
assert_wasi_layout(offsetof(__wasi_dirent_t, d_ino) == 8, "non-wasi data layout");
assert_wasi_layout(offsetof(__wasi_dirent_t, d_namlen) == 16, "non-wasi data layout");
assert_wasi_layout(offsetof(__wasi_dirent_t, d_type) == 20, "non-wasi data layout");
assert_wasi_layout(sizeof(__wasi_dirent_t) == 24, "non-wasi data layout");
assert_wasi_layout(_Alignof(__wasi_dirent_t) == 8, "non-wasi data layout");

typedef struct ALIGNED_(8) __wasi_event_t {
    __wasi_userdata_t userdata;
    __wasi_errno_t error;
    __wasi_eventtype_t type;
    uint8_t __paddings[5];
    union __wasi_event_u {
        struct __wasi_event_u_fd_readwrite_t {
            __wasi_filesize_t nbytes;
            __wasi_eventrwflags_t flags;
            uint8_t __paddings[6];
        } fd_readwrite;
    } u;
} __wasi_event_t;
assert_wasi_layout(offsetof(__wasi_event_t, userdata) == 0, "non-wasi data layout");
assert_wasi_layout(offsetof(__wasi_event_t, error) == 8, "non-wasi data layout");
assert_wasi_layout(offsetof(__wasi_event_t, type) == 10, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_event_t, u.fd_readwrite.nbytes) == 16, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_event_t, u.fd_readwrite.flags) == 24, "non-wasi data layout");
assert_wasi_layout(sizeof(__wasi_event_t) == 32, "non-wasi data layout");
assert_wasi_layout(_Alignof(__wasi_event_t) == 8, "non-wasi data layout");

typedef struct __wasi_prestat_t {
    __wasi_preopentype_t pr_type;
    union __wasi_prestat_u {
        struct __wasi_prestat_u_dir_t {
            size_t pr_name_len;
        } dir;
    } u;
} __wasi_prestat_t;
assert_wasi_layout(offsetof(__wasi_prestat_t, pr_type) == 0, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    offsetof(__wasi_prestat_t, u.dir.pr_name_len) == 4, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    offsetof(__wasi_prestat_t, u.dir.pr_name_len) == 8, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    sizeof(__wasi_prestat_t) == 8, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    sizeof(__wasi_prestat_t) == 16, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    _Alignof(__wasi_prestat_t) == 4, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    _Alignof(__wasi_prestat_t) == 8, "non-wasi data layout");

typedef struct ALIGNED_(8) __wasi_fdstat_t {
    __wasi_filetype_t fs_filetype;
    __wasi_fdflags_t fs_flags;
    uint8_t __paddings[4];
    __wasi_rights_t fs_rights_base;
    __wasi_rights_t fs_rights_inheriting;
} __wasi_fdstat_t;
assert_wasi_layout(
    offsetof(__wasi_fdstat_t, fs_filetype) == 0, "non-wasi data layout");
assert_wasi_layout(offsetof(__wasi_fdstat_t, fs_flags) == 2, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_fdstat_t, fs_rights_base) == 8, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_fdstat_t, fs_rights_inheriting) == 16,
    "non-wasi data layout");
assert_wasi_layout(sizeof(__wasi_fdstat_t) == 24, "non-wasi data layout");
assert_wasi_layout(_Alignof(__wasi_fdstat_t) == 8, "non-wasi data layout");

typedef struct ALIGNED_(8) __wasi_filestat_t {
    __wasi_device_t st_dev;
    __wasi_inode_t st_ino;
    __wasi_filetype_t st_filetype;
    __wasi_linkcount_t st_nlink;
    __wasi_filesize_t st_size;
    __wasi_timestamp_t st_atim;
    __wasi_timestamp_t st_mtim;
    __wasi_timestamp_t st_ctim;
} __wasi_filestat_t;
assert_wasi_layout(offsetof(__wasi_filestat_t, st_dev) == 0, "non-wasi data layout");
assert_wasi_layout(offsetof(__wasi_filestat_t, st_ino) == 8, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_filestat_t, st_filetype) == 16, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_filestat_t, st_nlink) == 24, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_filestat_t, st_size) == 32, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_filestat_t, st_atim) == 40, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_filestat_t, st_mtim) == 48, "non-wasi data layout");
assert_wasi_layout(
    offsetof(__wasi_filestat_t, st_ctim) == 56, "non-wasi data layout");
assert_wasi_layout(sizeof(__wasi_filestat_t) == 64, "non-wasi data layout");
assert_wasi_layout(_Alignof(__wasi_filestat_t) == 8, "non-wasi data layout");

typedef struct __wasi_ciovec_t {
    const void *buf;
    size_t buf_len;
} __wasi_ciovec_t;
assert_wasi_layout(offsetof(__wasi_ciovec_t, buf) == 0, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    offsetof(__wasi_ciovec_t, buf_len) == 4, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    offsetof(__wasi_ciovec_t, buf_len) == 8, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    sizeof(__wasi_ciovec_t) == 8, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    sizeof(__wasi_ciovec_t) == 16, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    _Alignof(__wasi_ciovec_t) == 4, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    _Alignof(__wasi_ciovec_t) == 8, "non-wasi data layout");

typedef struct __wasi_iovec_t {
    void *buf;
    size_t buf_len;
} __wasi_iovec_t;
assert_wasi_layout(offsetof(__wasi_iovec_t, buf) == 0, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    offsetof(__wasi_iovec_t, buf_len) == 4, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    offsetof(__wasi_iovec_t, buf_len) == 8, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    sizeof(__wasi_iovec_t) == 8, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    sizeof(__wasi_iovec_t) == 16, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 4 ||
    _Alignof(__wasi_iovec_t) == 4, "non-wasi data layout");
assert_wasi_layout(sizeof(void *) != 8 ||
    _Alignof(__wasi_iovec_t) == 8, "non-wasi data layout");

/**
 * The contents of a `subscription` when type is `eventtype::clock`.
 */
typedef struct ALIGNED_(8) __wasi_subscription_clock_t {
    /**
     * The clock against which to compare the timestamp.
     */
    __wasi_clockid_t clock_id;

    uint8_t __paddings1[4];

    /**
     * The absolute or relative timestamp.
     */
    __wasi_timestamp_t timeout;

    /**
     * The amount of time that the implementation may wait additionally
     * to coalesce with other events.
     */
    __wasi_timestamp_t precision;

    /**
     * Flags specifying whether the timeout is absolute or relative
     */
    __wasi_subclockflags_t flags;

    uint8_t __paddings2[4];

} __wasi_subscription_clock_t;

assert_wasi_layout(sizeof(__wasi_subscription_clock_t) == 32, "witx calculated size");
assert_wasi_layout(_Alignof(__wasi_subscription_clock_t) == 8, "witx calculated align");
assert_wasi_layout(offsetof(__wasi_subscription_clock_t, clock_id) == 0, "witx calculated offset");
assert_wasi_layout(offsetof(__wasi_subscription_clock_t, timeout) == 8, "witx calculated offset");
assert_wasi_layout(offsetof(__wasi_subscription_clock_t, precision) == 16, "witx calculated offset");
assert_wasi_layout(offsetof(__wasi_subscription_clock_t, flags) == 24, "witx calculated offset");

/**
 * The contents of a `subscription` when type is type is
 * `eventtype::fd_read` or `eventtype::fd_write`.
 */
typedef struct __wasi_subscription_fd_readwrite_t {
    /**
     * The file descriptor on which to wait for it to become ready for reading or writing.
     */
    __wasi_fd_t fd;

} __wasi_subscription_fd_readwrite_t;

assert_wasi_layout(sizeof(__wasi_subscription_fd_readwrite_t) == 4, "witx calculated size");
assert_wasi_layout(_Alignof(__wasi_subscription_fd_readwrite_t) == 4, "witx calculated align");
assert_wasi_layout(offsetof(__wasi_subscription_fd_readwrite_t, fd) == 0, "witx calculated offset");

/**
 * The contents of a `subscription`.
 */
typedef union __wasi_subscription_u_u_t {
    __wasi_subscription_clock_t clock;
    __wasi_subscription_fd_readwrite_t fd_readwrite;
} __wasi_subscription_u_u_t ;

typedef struct ALIGNED_(8) __wasi_subscription_u_t {
    __wasi_eventtype_t type;
    __wasi_subscription_u_u_t u;
} __wasi_subscription_u_t;

assert_wasi_layout(sizeof(__wasi_subscription_u_t) == 40, "witx calculated size");
assert_wasi_layout(_Alignof(__wasi_subscription_u_t) == 8, "witx calculated align");
assert_wasi_layout(offsetof(__wasi_subscription_u_t, u) == 8, "witx calculated union offset");
assert_wasi_layout(sizeof(__wasi_subscription_u_u_t) == 32, "witx calculated union size");
assert_wasi_layout(_Alignof(__wasi_subscription_u_u_t) == 8, "witx calculated union align");

/**
 * Subscription to an event.
 */
typedef struct __wasi_subscription_t {
    /**
     * User-provided value that is attached to the subscription in the
     * implementation and returned through `event::userdata`.
     */
    __wasi_userdata_t userdata;

    /**
     * The type of the event to which to subscribe, and its contents
     */
    __wasi_subscription_u_t u;

} __wasi_subscription_t;

assert_wasi_layout(sizeof(__wasi_subscription_t) == 48, "witx calculated size");
assert_wasi_layout(_Alignof(__wasi_subscription_t) == 8, "witx calculated align");
assert_wasi_layout(offsetof(__wasi_subscription_t, userdata) == 0, "witx calculated offset");
assert_wasi_layout(offsetof(__wasi_subscription_t, u) == 8, "witx calculated offset");

/* keep syncing with wasi_socket_ext.h */
typedef enum {
    /* Used only for sock_addr_resolve hints */
    SOCKET_ANY = -1,
    SOCKET_DGRAM = 0,
    SOCKET_STREAM,
} __wasi_sock_type_t;

typedef uint16_t __wasi_ip_port_t;

typedef enum { IPv4 = 0, IPv6 } __wasi_addr_type_t;

/* n0.n1.n2.n3 */
typedef struct __wasi_addr_ip4_t {
    uint8_t n0;
    uint8_t n1;
    uint8_t n2;
    uint8_t n3;
} __wasi_addr_ip4_t;

typedef struct __wasi_addr_ip4_port_t {
    __wasi_addr_ip4_t addr;
    __wasi_ip_port_t port;
} __wasi_addr_ip4_port_t;

typedef struct __wasi_addr_ip6_t {
    uint16_t n0;
    uint16_t n1;
    uint16_t n2;
    uint16_t n3;
    uint16_t h0;
    uint16_t h1;
    uint16_t h2;
    uint16_t h3;
} __wasi_addr_ip6_t;

typedef struct __wasi_addr_ip6_port_t {
    __wasi_addr_ip6_t addr;
    __wasi_ip_port_t port;
} __wasi_addr_ip6_port_t;

typedef struct __wasi_addr_ip_t {
    __wasi_addr_type_t kind;
    union {
        __wasi_addr_ip4_t ip4;
        __wasi_addr_ip6_t ip6;
    } addr;
} __wasi_addr_ip_t;

typedef struct __wasi_addr_t {
    __wasi_addr_type_t kind;
    union {
        __wasi_addr_ip4_port_t ip4;
        __wasi_addr_ip6_port_t ip6;
    } addr;
} __wasi_addr_t;

typedef enum { INET4 = 0, INET6, INET_UNSPEC } __wasi_address_family_t;

typedef struct __wasi_addr_info_t {
    __wasi_addr_t addr;
    __wasi_sock_type_t type;
} __wasi_addr_info_t;

typedef struct __wasi_addr_info_hints_t {
   __wasi_sock_type_t type;
   __wasi_address_family_t family;
   // this is to workaround lack of optional parameters
   uint8_t hints_enabled;
} __wasi_addr_info_hints_t;

#undef assert_wasi_layout

/* clang-format on */
#ifdef __cplusplus
}
#endif

#endif /* end of _PLATFORM_WASI_TYPES_H */