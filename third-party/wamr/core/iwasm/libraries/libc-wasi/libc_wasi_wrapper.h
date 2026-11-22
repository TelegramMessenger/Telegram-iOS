/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _LIBC_WASI_WRAPPER_H
#define _LIBC_WASI_WRAPPER_H

#include "posix.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef __wasi_address_family_t wasi_address_family_t;
typedef __wasi_addr_t wasi_addr_t;
typedef __wasi_advice_t wasi_advice_t;
typedef __wasi_ciovec_t wasi_ciovec_t;
typedef __wasi_clockid_t wasi_clockid_t;
typedef __wasi_dircookie_t wasi_dircookie_t;
// __wasi_errno_t is typedef'd to uint16 which is correct according to the ABI
// specification. However, in WASM, the smallest integer type is int32. If we
// return uint16, we would rely on language SDKs to implement the correct
// behaviour of casting to uint16 before checking the value or using it any way.
// Failure to do so can cause tricky bugs as the upper 16 bits of the error
// result are not guaranteed to be zero'ed by us so the result essentially
// contains garbage from the WASM app perspective. To prevent this, we return
// uint32 directly instead so as not to be reliant on the correct behaviour of
// any current/future WASI SDK implementations.
typedef uint32_t wasi_errno_t;
typedef __wasi_event_t wasi_event_t;
typedef __wasi_exitcode_t wasi_exitcode_t;
typedef __wasi_fdflags_t wasi_fdflags_t;
typedef __wasi_fdstat_t wasi_fdstat_t;
typedef __wasi_fd_t wasi_fd_t;
typedef __wasi_filedelta_t wasi_filedelta_t;
typedef __wasi_filesize_t wasi_filesize_t;
typedef __wasi_filestat_t wasi_filestat_t;
typedef __wasi_filetype_t wasi_filetype_t;
typedef __wasi_fstflags_t wasi_fstflags_t;
typedef __wasi_iovec_t wasi_iovec_t;
typedef __wasi_ip_port_t wasi_ip_port_t;
typedef __wasi_lookupflags_t wasi_lookupflags_t;
typedef __wasi_oflags_t wasi_oflags_t;
typedef __wasi_preopentype_t wasi_preopentype_t;
typedef __wasi_prestat_t wasi_prestat_t;
typedef __wasi_riflags_t wasi_riflags_t;
typedef __wasi_rights_t wasi_rights_t;
typedef __wasi_roflags_t wasi_roflags_t;
typedef __wasi_sdflags_t wasi_sdflags_t;
typedef __wasi_siflags_t wasi_siflags_t;
typedef __wasi_signal_t wasi_signal_t;
typedef __wasi_size_t wasi_size_t;
typedef __wasi_sock_type_t wasi_sock_type_t;
typedef __wasi_subscription_t wasi_subscription_t;
typedef __wasi_timestamp_t wasi_timestamp_t;
typedef __wasi_whence_t wasi_whence_t;

#ifdef __cplusplus
}
#endif

#endif /* end of _LIBC_WASI_WRAPPER_H */