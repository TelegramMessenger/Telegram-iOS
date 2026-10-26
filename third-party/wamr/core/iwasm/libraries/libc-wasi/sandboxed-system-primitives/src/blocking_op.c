/*
 * Copyright (C) 2023 Midokura Japan KK.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include <errno.h>

#include "ssp_config.h"
#include "blocking_op.h"
#include "libc_errno.h"

__wasi_errno_t
blocking_op_close(wasm_exec_env_t exec_env, os_file_handle handle,
                  bool is_stdio)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        return __WASI_EINTR;
    }
    __wasi_errno_t error = os_close(handle, is_stdio);
    wasm_runtime_end_blocking_op(exec_env);
    return error;
}

__wasi_errno_t
blocking_op_readv(wasm_exec_env_t exec_env, os_file_handle handle,
                  const struct __wasi_iovec_t *iov, int iovcnt, size_t *nread)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        return __WASI_EINTR;
    }
    __wasi_errno_t error = os_readv(handle, iov, iovcnt, nread);
    wasm_runtime_end_blocking_op(exec_env);
    return error;
}

__wasi_errno_t
blocking_op_preadv(wasm_exec_env_t exec_env, os_file_handle handle,
                   const struct __wasi_iovec_t *iov, int iovcnt,
                   __wasi_filesize_t offset, size_t *nread)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        return __WASI_EINTR;
    }
    __wasi_errno_t ret = os_preadv(handle, iov, iovcnt, offset, nread);
    wasm_runtime_end_blocking_op(exec_env);
    return ret;
}

__wasi_errno_t
blocking_op_writev(wasm_exec_env_t exec_env, os_file_handle handle,
                   const struct __wasi_ciovec_t *iov, int iovcnt,
                   size_t *nwritten)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        return __WASI_EINTR;
    }
    __wasi_errno_t error = os_writev(handle, iov, iovcnt, nwritten);
    wasm_runtime_end_blocking_op(exec_env);
    return error;
}

__wasi_errno_t
blocking_op_pwritev(wasm_exec_env_t exec_env, os_file_handle handle,
                    const struct __wasi_ciovec_t *iov, int iovcnt,
                    __wasi_filesize_t offset, size_t *nwritten)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        return __WASI_EINTR;
    }
    __wasi_errno_t error = os_pwritev(handle, iov, iovcnt, offset, nwritten);
    wasm_runtime_end_blocking_op(exec_env);
    return error;
}

int
blocking_op_socket_accept(wasm_exec_env_t exec_env, bh_socket_t server_sock,
                          bh_socket_t *sockp, void *addr,
                          unsigned int *addrlenp)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        errno = EINTR;
        return -1;
    }
    int ret = os_socket_accept(server_sock, sockp, addr, addrlenp);
    wasm_runtime_end_blocking_op(exec_env);
    return ret;
}

int
blocking_op_socket_connect(wasm_exec_env_t exec_env, bh_socket_t sock,
                           const char *addr, int port)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        errno = EINTR;
        return -1;
    }
    int ret = os_socket_connect(sock, addr, port);
    wasm_runtime_end_blocking_op(exec_env);
    return ret;
}

int
blocking_op_socket_recv_from(wasm_exec_env_t exec_env, bh_socket_t sock,
                             void *buf, unsigned int len, int flags,
                             bh_sockaddr_t *src_addr)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        errno = EINTR;
        return -1;
    }
    int ret = os_socket_recv_from(sock, buf, len, flags, src_addr);
    wasm_runtime_end_blocking_op(exec_env);
    return ret;
}

int
blocking_op_socket_send_to(wasm_exec_env_t exec_env, bh_socket_t sock,
                           const void *buf, unsigned int len, int flags,
                           const bh_sockaddr_t *dest_addr)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        errno = EINTR;
        return -1;
    }
    int ret = os_socket_send_to(sock, buf, len, flags, dest_addr);
    wasm_runtime_end_blocking_op(exec_env);
    return ret;
}

int
blocking_op_socket_addr_resolve(wasm_exec_env_t exec_env, const char *host,
                                const char *service, uint8_t *hint_is_tcp,
                                uint8_t *hint_is_ipv4,
                                bh_addr_info_t *addr_info,
                                size_t addr_info_size, size_t *max_info_size)
{
    /*
     * Note: Unlike others, os_socket_addr_resolve() is not a simple system
     * call. It's likely backed by a complex libc function, getaddrinfo().
     * Depending on the implementation of getaddrinfo() and underlying
     * DNS resolver, it might or might not be possible to make it return
     * with os_wakeup_blocking_op().
     *
     * Unfortunately, many of ISC/bind based resolvers just keep going on
     * interrupted system calls. It includes macOS and glibc.
     *
     * On the other hand, NuttX as of writing this returns EAI_AGAIN
     * on EINTR.
     */
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        errno = EINTR;
        return -1;
    }
    int ret = os_socket_addr_resolve(host, service, hint_is_tcp, hint_is_ipv4,
                                     addr_info, addr_info_size, max_info_size);
    wasm_runtime_end_blocking_op(exec_env);
    return ret;
}

__wasi_errno_t
blocking_op_openat(wasm_exec_env_t exec_env, os_file_handle handle,
                   const char *path, __wasi_oflags_t oflags,
                   __wasi_fdflags_t fd_flags, __wasi_lookupflags_t lookup_flags,
                   wasi_libc_file_access_mode access_mode, os_file_handle *out)
{
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        return __WASI_EINTR;
    }
    __wasi_errno_t error = os_openat(handle, path, oflags, fd_flags,
                                     lookup_flags, access_mode, out);
    wasm_runtime_end_blocking_op(exec_env);
    return error;
}

#ifndef BH_PLATFORM_WINDOWS
/* REVISIT: apply the os_file_handle style abstraction for pollfd? */
__wasi_errno_t
blocking_op_poll(wasm_exec_env_t exec_env, struct pollfd *pfds, nfds_t nfds,
                 int timeout_ms, int *retp)
{
    int ret;
    if (!wasm_runtime_begin_blocking_op(exec_env)) {
        return __WASI_EINTR;
    }
    ret = poll(pfds, nfds, timeout_ms);
    wasm_runtime_end_blocking_op(exec_env);
    if (ret == -1) {
        return convert_errno(errno);
    }
    *retp = ret;
    return 0;
}
#endif
