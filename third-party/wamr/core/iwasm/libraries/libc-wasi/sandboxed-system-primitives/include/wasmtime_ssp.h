/*
 * Part of the Wasmtime Project, under the Apache License v2.0 with
 * LLVM Exceptions. See
 *   https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE
 * for license information.
 */

/**
 * The definitions of type, macro and structure in this file should be
 * consistent with those in wasi-libc:
 * https://github.com/WebAssembly/wasi-libc/blob/main/libc-bottom-half/headers/public/wasi/api.h
 */

#ifndef WASMTIME_SSP_H
#define WASMTIME_SSP_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "bh_platform.h"
#include "wasm_export.h"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(WASMTIME_SSP_WASI_API)
#define WASMTIME_SSP_SYSCALL_NAME(name) asm("__wasi_" #name)
#else
#define WASMTIME_SSP_SYSCALL_NAME(name)
#endif

__wasi_errno_t
wasmtime_ssp_args_get(struct argv_environ_values *arg_environ, char **argv,
                      char *argv_buf)
    WASMTIME_SSP_SYSCALL_NAME(args_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_args_sizes_get(struct argv_environ_values *arg_environ,
                            size_t *argc, size_t *argv_buf_size)
    WASMTIME_SSP_SYSCALL_NAME(args_sizes_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_environ_get(struct argv_environ_values *arg_environ,
                         char **environs, char *environ_buf)
    WASMTIME_SSP_SYSCALL_NAME(environ_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_environ_sizes_get(struct argv_environ_values *arg_environ,
                               size_t *environ_count, size_t *environ_buf_size)
    WASMTIME_SSP_SYSCALL_NAME(environ_sizes_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_prestat_get(struct fd_prestats *prestats, __wasi_fd_t fd,
                            __wasi_prestat_t *buf)
    WASMTIME_SSP_SYSCALL_NAME(fd_prestat_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_prestat_dir_name(struct fd_prestats *prestats, __wasi_fd_t fd,
                                 char *path, size_t path_len)
    WASMTIME_SSP_SYSCALL_NAME(fd_prestat_dir_name) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_close(wasm_exec_env_t exec_env, struct fd_table *curfds,
                      struct fd_prestats *prestats, __wasi_fd_t fd)
    WASMTIME_SSP_SYSCALL_NAME(fd_close) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_datasync(wasm_exec_env_t exec_env, struct fd_table *curfds,
                         __wasi_fd_t fd)
    WASMTIME_SSP_SYSCALL_NAME(fd_datasync) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_pread(wasm_exec_env_t exec_env, struct fd_table *curfds,
                      __wasi_fd_t fd, const __wasi_iovec_t *iovs,
                      size_t iovs_len, __wasi_filesize_t offset, size_t *nread)
    WASMTIME_SSP_SYSCALL_NAME(fd_pread) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_pwrite(wasm_exec_env_t exec_env, struct fd_table *curfds,
                       __wasi_fd_t fd, const __wasi_ciovec_t *iovs,
                       size_t iovs_len, __wasi_filesize_t offset,
                       size_t *nwritten)
    WASMTIME_SSP_SYSCALL_NAME(fd_pwrite) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_read(wasm_exec_env_t exec_env, struct fd_table *curfds,
                     __wasi_fd_t fd, const __wasi_iovec_t *iovs,
                     size_t iovs_len, size_t *nread)
    WASMTIME_SSP_SYSCALL_NAME(fd_read) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_renumber(wasm_exec_env_t exec_env, struct fd_table *curfds,
                         struct fd_prestats *prestats, __wasi_fd_t from,
                         __wasi_fd_t to)
    WASMTIME_SSP_SYSCALL_NAME(fd_renumber) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_seek(wasm_exec_env_t exec_env, struct fd_table *curfds,
                     __wasi_fd_t fd, __wasi_filedelta_t offset,
                     __wasi_whence_t whence, __wasi_filesize_t *newoffset)
    WASMTIME_SSP_SYSCALL_NAME(fd_seek) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_tell(wasm_exec_env_t exec_env, struct fd_table *curfds,
                     __wasi_fd_t fd, __wasi_filesize_t *newoffset)
    WASMTIME_SSP_SYSCALL_NAME(fd_tell) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_fdstat_get(wasm_exec_env_t exec_env, struct fd_table *curfds,
                           __wasi_fd_t fd, __wasi_fdstat_t *buf)
    WASMTIME_SSP_SYSCALL_NAME(fd_fdstat_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_fdstat_set_flags(wasm_exec_env_t exec_env,
                                 struct fd_table *curfds, __wasi_fd_t fd,
                                 __wasi_fdflags_t flags)
    WASMTIME_SSP_SYSCALL_NAME(fd_fdstat_set_flags) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_fdstat_set_rights(wasm_exec_env_t exec_env,
                                  struct fd_table *curfds, __wasi_fd_t fd,
                                  __wasi_rights_t fs_rights_base,
                                  __wasi_rights_t fs_rights_inheriting)
    WASMTIME_SSP_SYSCALL_NAME(fd_fdstat_set_rights) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_sync(wasm_exec_env_t exec_env, struct fd_table *curfds,
                     __wasi_fd_t fd)
    WASMTIME_SSP_SYSCALL_NAME(fd_sync) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_write(wasm_exec_env_t exec_env, struct fd_table *curfds,
                      __wasi_fd_t fd, const __wasi_ciovec_t *iovs,
                      size_t iovs_len, size_t *nwritten)
    WASMTIME_SSP_SYSCALL_NAME(fd_write) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_advise(wasm_exec_env_t exec_env, struct fd_table *curfds,
                       __wasi_fd_t fd, __wasi_filesize_t offset,
                       __wasi_filesize_t len, __wasi_advice_t advice)
    WASMTIME_SSP_SYSCALL_NAME(fd_advise) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_allocate(wasm_exec_env_t exec_env, struct fd_table *curfds,
                         __wasi_fd_t fd, __wasi_filesize_t offset,
                         __wasi_filesize_t len)
    WASMTIME_SSP_SYSCALL_NAME(fd_allocate) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_create_directory(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t fd,
                                   const char *path, size_t path_len)
    WASMTIME_SSP_SYSCALL_NAME(path_create_directory) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_link(wasm_exec_env_t exec_env, struct fd_table *curfds,
                       struct fd_prestats *prestats, __wasi_fd_t old_fd,
                       __wasi_lookupflags_t old_flags, const char *old_path,
                       size_t old_path_len, __wasi_fd_t new_fd,
                       const char *new_path, size_t new_path_len)
    WASMTIME_SSP_SYSCALL_NAME(path_link) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_open(wasm_exec_env_t exec_env, struct fd_table *curfds,
                       __wasi_fd_t dirfd, __wasi_lookupflags_t dirflags,
                       const char *path, size_t path_len,
                       __wasi_oflags_t oflags, __wasi_rights_t fs_rights_base,
                       __wasi_rights_t fs_rights_inheriting,
                       __wasi_fdflags_t fs_flags, __wasi_fd_t *fd)
    WASMTIME_SSP_SYSCALL_NAME(path_open) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_readdir(wasm_exec_env_t exec_env, struct fd_table *curfds,
                        __wasi_fd_t fd, void *buf, size_t buf_len,
                        __wasi_dircookie_t cookie, size_t *bufused)
    WASMTIME_SSP_SYSCALL_NAME(fd_readdir) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_readlink(wasm_exec_env_t exec_env, struct fd_table *curfds,
                           __wasi_fd_t fd, const char *path, size_t path_len,
                           char *buf, size_t buf_len, size_t *bufused)
    WASMTIME_SSP_SYSCALL_NAME(path_readlink) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_rename(wasm_exec_env_t exec_env, struct fd_table *curfds,
                         __wasi_fd_t old_fd, const char *old_path,
                         size_t old_path_len, __wasi_fd_t new_fd,
                         const char *new_path, size_t new_path_len)
    WASMTIME_SSP_SYSCALL_NAME(path_rename) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_filestat_get(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t fd, __wasi_filestat_t *buf)
    WASMTIME_SSP_SYSCALL_NAME(fd_filestat_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_filestat_set_times(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t fd,
                                   __wasi_timestamp_t st_atim,
                                   __wasi_timestamp_t st_mtim,
                                   __wasi_fstflags_t fstflags)
    WASMTIME_SSP_SYSCALL_NAME(fd_filestat_set_times) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_fd_filestat_set_size(wasm_exec_env_t exec_env,
                                  struct fd_table *curfds, __wasi_fd_t fd,
                                  __wasi_filesize_t st_size)
    WASMTIME_SSP_SYSCALL_NAME(fd_filestat_set_size) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_filestat_get(wasm_exec_env_t exec_env,
                               struct fd_table *curfds, __wasi_fd_t fd,
                               __wasi_lookupflags_t flags, const char *path,
                               size_t path_len, __wasi_filestat_t *buf)
    WASMTIME_SSP_SYSCALL_NAME(path_filestat_get) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_filestat_set_times(wasm_exec_env_t exec_env,
                                     struct fd_table *curfds, __wasi_fd_t fd,
                                     __wasi_lookupflags_t flags,
                                     const char *path, size_t path_len,
                                     __wasi_timestamp_t st_atim,
                                     __wasi_timestamp_t st_mtim,
                                     __wasi_fstflags_t fstflags)
    WASMTIME_SSP_SYSCALL_NAME(path_filestat_set_times) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_symlink(wasm_exec_env_t exec_env, struct fd_table *curfds,
                          struct fd_prestats *prestats, const char *old_path,
                          size_t old_path_len, __wasi_fd_t fd,
                          const char *new_path, size_t new_path_len)
    WASMTIME_SSP_SYSCALL_NAME(path_symlink) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_unlink_file(wasm_exec_env_t exec_env, struct fd_table *curfds,
                              __wasi_fd_t fd, const char *path, size_t path_len)
    WASMTIME_SSP_SYSCALL_NAME(path_unlink_file) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_path_remove_directory(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t fd,
                                   const char *path, size_t path_len)
    WASMTIME_SSP_SYSCALL_NAME(path_remove_directory) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_poll_oneoff(wasm_exec_env_t exec_env, struct fd_table *curfds,
                         const __wasi_subscription_t *in, __wasi_event_t *out,
                         size_t nsubscriptions, size_t *nevents)
    WASMTIME_SSP_SYSCALL_NAME(poll_oneoff) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_random_get(void *buf, size_t buf_len)
    WASMTIME_SSP_SYSCALL_NAME(random_get) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_accept(wasm_exec_env_t exec_env, struct fd_table *curfds,
                     __wasi_fd_t fd, __wasi_fdflags_t flags,
                     __wasi_fd_t *fd_new) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_addr_local(wasm_exec_env_t exec_env, struct fd_table *curfds,
                         __wasi_fd_t fd, __wasi_addr_t *addr) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_addr_remote(wasm_exec_env_t exec_env, struct fd_table *curfds,
                          __wasi_fd_t fd, __wasi_addr_t *addr) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_open(wasm_exec_env_t exec_env, struct fd_table *curfds,
                   __wasi_fd_t poolfd, __wasi_address_family_t af,
                   __wasi_sock_type_t socktype,
                   __wasi_fd_t *sockfd) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_bind(wasm_exec_env_t exec_env, struct fd_table *curfds,
                   struct addr_pool *addr_pool, __wasi_fd_t fd,
                   __wasi_addr_t *addr) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_addr_resolve(wasm_exec_env_t exec_env, struct fd_table *curfds,
                           char **ns_lookup_list, const char *host,
                           const char *service, __wasi_addr_info_hints_t *hints,
                           __wasi_addr_info_t *addr_info,
                           __wasi_size_t addr_info_size,
                           __wasi_size_t *max_info_size) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_connect(wasm_exec_env_t exec_env, struct fd_table *curfds,
                      struct addr_pool *addr_pool, __wasi_fd_t fd,
                      __wasi_addr_t *addr) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_get_recv_buf_size(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t fd,
                                __wasi_size_t *size) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_get_reuse_addr(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t fd, uint8_t *reuse) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_get_reuse_port(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t fd, uint8_t *reuse) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_get_send_buf_size(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t fd,
                                __wasi_size_t *size) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_set_recv_buf_size(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t fd,
                                __wasi_size_t size) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_set_reuse_addr(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t fd, uint8_t reuse) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_set_reuse_port(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t fd, uint8_t reuse) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_set_send_buf_size(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t fd,
                                __wasi_size_t size) WARN_UNUSED;

__wasi_errno_t
wasi_ssp_sock_listen(wasm_exec_env_t exec_env, struct fd_table *curfds,
                     __wasi_fd_t fd, __wasi_size_t backlog) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_recv(wasm_exec_env_t exec_env, struct fd_table *curfds,
                       __wasi_fd_t sock, void *buf, size_t buf_len,
                       size_t *recv_len)
    WASMTIME_SSP_SYSCALL_NAME(sock_recv) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_recv_from(wasm_exec_env_t exec_env, struct fd_table *curfds,
                            __wasi_fd_t sock, void *buf, size_t buf_len,
                            __wasi_riflags_t ri_flags, __wasi_addr_t *src_addr,
                            size_t *recv_len)
    WASMTIME_SSP_SYSCALL_NAME(sock_recv_from) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_send(wasm_exec_env_t exec_env, struct fd_table *curfds,
                       __wasi_fd_t sock, const void *buf, size_t buf_len,
                       size_t *sent_len)
    WASMTIME_SSP_SYSCALL_NAME(sock_send) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_send_to(wasm_exec_env_t exec_env, struct fd_table *curfds,
                          struct addr_pool *addr_pool, __wasi_fd_t sock,
                          const void *buf, size_t buf_len,
                          __wasi_siflags_t si_flags,
                          const __wasi_addr_t *dest_addr, size_t *sent_len)
    WASMTIME_SSP_SYSCALL_NAME(sock_send_to) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_shutdown(wasm_exec_env_t exec_env, struct fd_table *curfds,
                           __wasi_fd_t sock)
    WASMTIME_SSP_SYSCALL_NAME(sock_shutdown) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_recv_timeout(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t sock,
                                   uint64_t timeout_us)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_recv_timeout) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_recv_timeout(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t sock,
                                   uint64_t *timeout_us)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_recv_timeout) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_send_timeout(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t sock,
                                   uint64_t timeout_us)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_send_timeout) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_send_timeout(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t sock,
                                   uint64_t *timeout_us)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_send_timeout) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_send_buf_size(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    size_t bufsiz)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_send_buf_size) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_send_buf_size(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    size_t *bufsiz)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_send_buf_size) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_recv_buf_size(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    size_t bufsiz)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_recv_buf_size) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_recv_buf_size(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    size_t *bufsiz)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_recv_buf_size) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_keep_alive(wasm_exec_env_t exec_env,
                                 struct fd_table *curfds, __wasi_fd_t sock,
                                 bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_keep_alive) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_keep_alive(wasm_exec_env_t exec_env,
                                 struct fd_table *curfds, __wasi_fd_t sock,
                                 bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_keep_alive) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_reuse_addr(wasm_exec_env_t exec_env,
                                 struct fd_table *curfds, __wasi_fd_t sock,
                                 bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_reuse_addr) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_reuse_addr(wasm_exec_env_t exec_env,
                                 struct fd_table *curfds, __wasi_fd_t sock,
                                 bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_reuse_addr) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_reuse_port(wasm_exec_env_t exec_env,
                                 struct fd_table *curfds, __wasi_fd_t sock,
                                 bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_reuse_port) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_reuse_port(wasm_exec_env_t exec_env,
                                 struct fd_table *curfds, __wasi_fd_t sock,
                                 bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_reuse_port) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_linger(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t sock, bool is_enabled, int linger_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_linger) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_linger(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t sock, bool *is_enabled, int *linger_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_linger) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_broadcast(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t sock,
                                bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_broadcast) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_broadcast(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t sock,
                                bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_broadcast) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_tcp_no_delay(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t sock,
                                   bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_no_delay) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_tcp_no_delay(wasm_exec_env_t exec_env,
                                   struct fd_table *curfds, __wasi_fd_t sock,
                                   bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_no_delay) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_tcp_quick_ack(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_quick_ack) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_tcp_quick_ack(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_quick_ack) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_tcp_keep_idle(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    uint32_t time_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_keep_idle) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_tcp_keep_idle(wasm_exec_env_t exec_env,
                                    struct fd_table *curfds, __wasi_fd_t sock,
                                    uint32_t *time_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_keep_idle) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_tcp_keep_intvl(wasm_exec_env_t exec_env,
                                     struct fd_table *curfds, __wasi_fd_t sock,
                                     uint32_t time_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_keep_intvl) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_tcp_keep_intvl(wasm_exec_env_t exec_env,
                                     struct fd_table *curfds, __wasi_fd_t sock,
                                     uint32_t *time_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_keep_intvl) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_tcp_fastopen_connect(wasm_exec_env_t exec_env,
                                           struct fd_table *curfds,
                                           __wasi_fd_t sock, bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_fastopen_connect) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_tcp_fastopen_connect(wasm_exec_env_t exec_env,
                                           struct fd_table *curfds,
                                           __wasi_fd_t sock, bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_fastopen_connect) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_ip_multicast_loop(wasm_exec_env_t exec_env,
                                        struct fd_table *curfds,
                                        __wasi_fd_t sock, bool ipv6,
                                        bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_multicast_loop) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_ip_multicast_loop(wasm_exec_env_t exec_env,
                                        struct fd_table *curfds,
                                        __wasi_fd_t sock, bool ipv6,
                                        bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_ip_multicast_loop) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_ip_add_membership(wasm_exec_env_t exec_env,
                                        struct fd_table *curfds,
                                        __wasi_fd_t sock,
                                        __wasi_addr_ip_t *imr_multiaddr,
                                        uint32_t imr_interface)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_add_membership) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_ip_drop_membership(wasm_exec_env_t exec_env,
                                         struct fd_table *curfds,
                                         __wasi_fd_t sock,
                                         __wasi_addr_ip_t *imr_multiaddr,
                                         uint32_t imr_interface)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_drop_membership) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_ip_ttl(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t sock, uint8_t ttl_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_ttl) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_ip_ttl(wasm_exec_env_t exec_env, struct fd_table *curfds,
                             __wasi_fd_t sock, uint8_t *ttl_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_ip_ttl) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_ip_multicast_ttl(wasm_exec_env_t exec_env,
                                       struct fd_table *curfds,
                                       __wasi_fd_t sock, uint8_t ttl_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_multicast_ttl) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_ip_multicast_ttl(wasm_exec_env_t exec_env,
                                       struct fd_table *curfds,
                                       __wasi_fd_t sock, uint8_t *ttl_s)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_ip_multicast_ttl) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_set_ipv6_only(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t sock,
                                bool is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_set_ipv6_only) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sock_get_ipv6_only(wasm_exec_env_t exec_env,
                                struct fd_table *curfds, __wasi_fd_t sock,
                                bool *is_enabled)
    WASMTIME_SSP_SYSCALL_NAME(sock_get_ipv6_only) WARN_UNUSED;

__wasi_errno_t
wasmtime_ssp_sched_yield(void)
    WASMTIME_SSP_SYSCALL_NAME(sched_yield) WARN_UNUSED;

#ifdef __cplusplus
}
#endif

#undef WASMTIME_SSP_SYSCALL_NAME

#endif /* end of WASMTIME_SSP_H */
