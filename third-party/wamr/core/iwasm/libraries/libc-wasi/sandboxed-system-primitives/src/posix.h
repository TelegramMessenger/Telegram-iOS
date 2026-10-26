// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016-2018 Nuxi, https://nuxi.nl/

#ifndef POSIX_H
#define POSIX_H

#include "bh_platform.h"
#include "locking.h"

struct fd_entry;
struct fd_prestat;
struct syscalls;

struct fd_table {
    struct rwlock lock;
    struct fd_entry *entries;
    size_t size;
    size_t used;
};

struct fd_prestats {
    struct rwlock lock;
    struct fd_prestat *prestats;
    size_t size;
    size_t used;
};

struct argv_environ_values {
    const char *argv_buf;
    size_t argv_buf_size;
    char **argv_list;
    size_t argc;
    char *environ_buf;
    size_t environ_buf_size;
    char **environ_list;
    size_t environ_count;
};

struct addr_pool {
    /* addr and mask in host order */
    union {
        uint32 ip4;
        uint16 ip6[8];
    } addr;
    struct addr_pool *next;
    __wasi_addr_type_t type;
    uint8 mask;
};

bool
fd_table_init(struct fd_table *);
bool
fd_table_insert_existing(struct fd_table *, __wasi_fd_t, os_file_handle,
                         bool is_stdio);
bool
fd_prestats_init(struct fd_prestats *);
bool
fd_prestats_insert(struct fd_prestats *, const char *, __wasi_fd_t);
bool
argv_environ_init(struct argv_environ_values *argv_environ, char *argv_buf,
                  size_t argv_buf_size, char **argv_list, size_t argc,
                  char *environ_buf, size_t environ_buf_size,
                  char **environ_list, size_t environ_count);
void
argv_environ_destroy(struct argv_environ_values *argv_environ);
void
fd_table_destroy(struct fd_table *ft);
void
fd_prestats_destroy(struct fd_prestats *pt);

bool
addr_pool_init(struct addr_pool *);
bool
addr_pool_insert(struct addr_pool *, const char *, uint8 mask);
bool
addr_pool_search(struct addr_pool *, const char *);
void
addr_pool_destroy(struct addr_pool *);

#endif
