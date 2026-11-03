/*
 * Copyright (C) 2023 Midokura Japan KK.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BLOCKING_OP_H_
#define _BLOCKING_OP_H_

#include "bh_platform.h"
#include "wasm_export.h"

__wasi_errno_t
blocking_op_close(wasm_exec_env_t exec_env, os_file_handle handle,
                  bool is_stdio);
__wasi_errno_t
blocking_op_readv(wasm_exec_env_t exec_env, os_file_handle handle,
                  const struct __wasi_iovec_t *iov, int iovcnt, size_t *nread);
__wasi_errno_t
blocking_op_preadv(wasm_exec_env_t exec_env, os_file_handle handle,
                   const struct __wasi_iovec_t *iov, int iovcnt,
                   __wasi_filesize_t offset, size_t *nread);
__wasi_errno_t
blocking_op_writev(wasm_exec_env_t exec_env, os_file_handle handle,
                   const struct __wasi_ciovec_t *iov, int iovcnt,
                   size_t *nwritten);
__wasi_errno_t
blocking_op_pwritev(wasm_exec_env_t exec_env, os_file_handle handle,
                    const struct __wasi_ciovec_t *iov, int iovcnt,
                    __wasi_filesize_t offset, size_t *nwritten);
int
blocking_op_socket_accept(wasm_exec_env_t exec_env, bh_socket_t server_sock,
                          bh_socket_t *sockp, void *addr,
                          unsigned int *addrlenp);
int
blocking_op_socket_connect(wasm_exec_env_t exec_env, bh_socket_t sock,
                           const char *addr, int port);
int
blocking_op_socket_recv_from(wasm_exec_env_t exec_env, bh_socket_t sock,
                             void *buf, unsigned int len, int flags,
                             bh_sockaddr_t *src_addr);
int
blocking_op_socket_send_to(wasm_exec_env_t exec_env, bh_socket_t sock,
                           const void *buf, unsigned int len, int flags,
                           const bh_sockaddr_t *dest_addr);
int
blocking_op_socket_addr_resolve(wasm_exec_env_t exec_env, const char *host,
                                const char *service, uint8_t *hint_is_tcp,
                                uint8_t *hint_is_ipv4,
                                bh_addr_info_t *addr_info,
                                size_t addr_info_size, size_t *max_info_size);

__wasi_errno_t
blocking_op_openat(wasm_exec_env_t exec_env, os_file_handle handle,
                   const char *path, __wasi_oflags_t oflags,
                   __wasi_fdflags_t fd_flags, __wasi_lookupflags_t lookup_flags,
                   wasi_libc_file_access_mode access_mode, os_file_handle *out);

#ifndef BH_PLATFORM_WINDOWS
__wasi_errno_t
blocking_op_poll(wasm_exec_env_t exec_env, struct pollfd *pfds, nfds_t nfds,
                 int timeout, int *retp);
#endif

#endif /* end of _BLOCKING_OP_H_ */
