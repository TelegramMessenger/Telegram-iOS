/*
 * Copyright (C) 2023 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "errno.h"
#include "libc_errno.h"

__wasi_errno_t
convert_errno(int error)
{
    // The C standard library only requires EDOM, EILSEQ and ERANGE to be
    // defined. Other error codes are POSIX-specific and hence may or may
    // not be available on non-POSIX platforms.
    __wasi_errno_t code = __WASI_ENOSYS;
#define X(v)               \
    case v:                \
        code = __WASI_##v; \
        break;
    switch (error) {
        X(EDOM)
        X(EILSEQ)
        X(ERANGE)
#ifdef E2BIG
        X(E2BIG)
#endif
#ifdef EACCES
        X(EACCES)
#endif
#ifdef EADDRINUSE
        X(EADDRINUSE)
#endif
#ifdef EADDRNOTAVAIL
        X(EADDRNOTAVAIL)
#endif
#ifdef EAFNOSUPPORT
        X(EAFNOSUPPORT)
#endif
#ifdef EAGAIN
        X(EAGAIN)
#endif
#ifdef EALREADY
        X(EALREADY)
#endif
#ifdef EBADF
        X(EBADF)
#endif
#ifdef EBADMSG
        X(EBADMSG)
#endif
#ifdef EBUSY
        X(EBUSY)
#endif
#ifdef ECANCELED
        X(ECANCELED)
#endif
#ifdef ECHILD
        X(ECHILD)
#endif
#ifdef ECONNABORTED
        X(ECONNABORTED)
#endif
#ifdef ECONNREFUSED
        X(ECONNREFUSED)
#endif
#ifdef ECONNRESET
        X(ECONNRESET)
#endif
#ifdef EDEADLK
        X(EDEADLK)
#endif
#ifdef EDESTADDRREQ
        X(EDESTADDRREQ)
#endif
#ifdef EDQUOT
        X(EDQUOT)
#endif
#ifdef EEXIST
        X(EEXIST)
#endif
#ifdef EFAULT
        X(EFAULT)
#endif
#ifdef EFBIG
        X(EFBIG)
#endif
#ifdef EHOSTUNREACH
        X(EHOSTUNREACH)
#endif
#ifdef EIDRM
        X(EIDRM)
#endif
#ifdef EINPROGRESS
        X(EINPROGRESS)
#endif
#ifdef EINTR
        X(EINTR)
#endif
#ifdef EINVAL
        X(EINVAL)
#endif
#ifdef EIO
        X(EIO)
#endif
#ifdef EISCONN
        X(EISCONN)
#endif
#ifdef EISDIR
        X(EISDIR)
#endif
#ifdef ELOOP
        X(ELOOP)
#endif
#ifdef EMFILE
        X(EMFILE)
#endif
#ifdef EMLINK
        X(EMLINK)
#endif
#ifdef EMSGSIZE
        X(EMSGSIZE)
#endif
#ifdef EMULTIHOP
        X(EMULTIHOP)
#endif
#ifdef ENAMETOOLONG
        X(ENAMETOOLONG)
#endif
#ifdef ENETDOWN
        X(ENETDOWN)
#endif
#ifdef ENETRESET
        X(ENETRESET)
#endif
#ifdef ENETUNREACH
        X(ENETUNREACH)
#endif
#ifdef ENFILE
        X(ENFILE)
#endif
#ifdef ENOBUFS
        X(ENOBUFS)
#endif
#ifdef ENODEV
        X(ENODEV)
#endif
#ifdef ENOENT
        X(ENOENT)
#endif
#ifdef ENOEXEC
        X(ENOEXEC)
#endif
#ifdef ENOLCK
        X(ENOLCK)
#endif
#ifdef ENOLINK
        X(ENOLINK)
#endif
#ifdef ENOMEM
        X(ENOMEM)
#endif
#ifdef ENOMSG
        X(ENOMSG)
#endif
#ifdef ENOPROTOOPT
        X(ENOPROTOOPT)
#endif
#ifdef ENOSPC
        X(ENOSPC)
#endif
#ifdef ENOSYS
        X(ENOSYS)
#endif
#ifdef ENOTCAPABLE
        X(ENOTCAPABLE)
#endif
#ifdef ENOTCONN
        X(ENOTCONN)
#endif
#ifdef ENOTDIR
        X(ENOTDIR)
#endif
#ifdef ENOTEMPTY
        X(ENOTEMPTY)
#endif
#ifdef ENOTRECOVERABLE
        X(ENOTRECOVERABLE)
#endif
#ifdef ENOTSOCK
        X(ENOTSOCK)
#endif
#ifdef ENOTSUP
        X(ENOTSUP)
#endif
#ifdef ENOTTY
        X(ENOTTY)
#endif
#ifdef ENXIO
        X(ENXIO)
#endif
#ifdef EOVERFLOW
        X(EOVERFLOW)
#endif
#ifdef EOWNERDEAD
        X(EOWNERDEAD)
#endif
#ifdef EPERM
        X(EPERM)
#endif
#ifdef EPIPE
        X(EPIPE)
#endif
#ifdef EPROTO
        X(EPROTO)
#endif
#ifdef EPROTONOSUPPORT
        X(EPROTONOSUPPORT)
#endif
#ifdef EPROTOTYPE
        X(EPROTOTYPE)
#endif
#ifdef EROFS
        X(EROFS)
#endif
#ifdef ESPIPE
        X(ESPIPE)
#endif
#ifdef ESRCH
        X(ESRCH)
#endif
#ifdef ESTALE
        X(ESTALE)
#endif
#ifdef ETIMEDOUT
        X(ETIMEDOUT)
#endif
#ifdef ETXTBSY
        X(ETXTBSY)
#endif
#ifdef EXDEV
        X(EXDEV)
#endif
        default:
#ifdef EOPNOTSUPP
            if (error == EOPNOTSUPP)
                code = __WASI_ENOTSUP;
#endif
#ifdef EWOULDBLOCK
            if (error == EWOULDBLOCK)
                code = __WASI_EAGAIN;
#endif
            break;
    }
#undef X
    return code;
}