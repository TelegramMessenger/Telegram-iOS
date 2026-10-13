/*
 * Copyright (C) 2023 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "platform_api_extension.h"
#include "libc_errno.h"
#include <unistd.h>

#if !defined(__APPLE__) && !defined(ESP_PLATFORM)
#define CONFIG_HAS_PWRITEV 1
#define CONFIG_HAS_PREADV 1
#else
#define CONFIG_HAS_PWRITEV 0
#define CONFIG_HAS_PREADV 0
#endif

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(ESP_PLATFORM)
#define CONFIG_HAS_FDATASYNC 1
#else
#define CONFIG_HAS_FDATASYNC 0
#endif

/*
 * For NuttX, CONFIG_HAS_ISATTY is provided by its platform header.
 * (platform_internal.h)
 */
#if !defined(CONFIG_HAS_D_INO)
#if !defined(__NuttX__) && !defined(__RTTHREAD__)
#define CONFIG_HAS_D_INO 1
#define CONFIG_HAS_ISATTY 1
#else
#define CONFIG_HAS_D_INO 0
#endif
#endif

#if !defined(__APPLE__) && !defined(ESP_PLATFORM) && !defined(__COSMOPOLITAN__)
#define CONFIG_HAS_POSIX_FALLOCATE 1
#else
#define CONFIG_HAS_POSIX_FALLOCATE 0
#endif

#if defined(O_DSYNC)
#define CONFIG_HAS_O_DSYNC
#endif

// POSIX requires O_RSYNC to be defined, but Linux explicitly doesn't support
// it.
#if defined(O_RSYNC) && !defined(__linux__)
#define CONFIG_HAS_O_RSYNC
#endif

#if defined(O_SYNC)
#define CONFIG_HAS_O_SYNC
#endif

#ifndef STDIN_FILENO
#define STDIN_FILENO 0
#endif

#ifndef STDOUT_FILENO
#define STDOUT_FILENO 1
#endif

#ifndef STDERR_FILENO
#define STDERR_FILENO 2
#endif

// Converts a POSIX timespec to a WASI timestamp.
static __wasi_timestamp_t
convert_timespec(const struct timespec *ts)
{
    if (ts->tv_sec < 0)
        return 0;
    if ((__wasi_timestamp_t)ts->tv_sec >= UINT64_MAX / 1000000000)
        return UINT64_MAX;
    return (__wasi_timestamp_t)ts->tv_sec * 1000000000
           + (__wasi_timestamp_t)ts->tv_nsec;
}

// Converts a POSIX stat structure to a WASI filestat structure
static void
convert_stat(os_file_handle handle, const struct stat *in,
             __wasi_filestat_t *out)
{
    out->st_dev = in->st_dev;
    out->st_ino = in->st_ino;
    out->st_nlink = (__wasi_linkcount_t)in->st_nlink;
    out->st_size = (__wasi_filesize_t)in->st_size;
#ifdef __APPLE__
    out->st_atim = convert_timespec(&in->st_atimespec);
    out->st_mtim = convert_timespec(&in->st_mtimespec);
    out->st_ctim = convert_timespec(&in->st_ctimespec);
#else
    out->st_atim = convert_timespec(&in->st_atim);
    out->st_mtim = convert_timespec(&in->st_mtim);
    out->st_ctim = convert_timespec(&in->st_ctim);
#endif

    // Convert the file type. In the case of sockets there is no way we
    // can easily determine the exact socket type.
    if (S_ISBLK(in->st_mode)) {
        out->st_filetype = __WASI_FILETYPE_BLOCK_DEVICE;
    }
    else if (S_ISCHR(in->st_mode)) {
        out->st_filetype = __WASI_FILETYPE_CHARACTER_DEVICE;
    }
    else if (S_ISDIR(in->st_mode)) {
        out->st_filetype = __WASI_FILETYPE_DIRECTORY;
    }
    else if (S_ISFIFO(in->st_mode)) {
        out->st_filetype = __WASI_FILETYPE_SOCKET_STREAM;
    }
    else if (S_ISLNK(in->st_mode)) {
        out->st_filetype = __WASI_FILETYPE_SYMBOLIC_LINK;
    }
    else if (S_ISREG(in->st_mode)) {
        out->st_filetype = __WASI_FILETYPE_REGULAR_FILE;
    }
    else if (S_ISSOCK(in->st_mode)) {
        int socktype;
        socklen_t socktypelen = sizeof(socktype);

        if (getsockopt(handle, SOL_SOCKET, SO_TYPE, &socktype, &socktypelen)
            < 0) {
            out->st_filetype = __WASI_FILETYPE_UNKNOWN;
            return;
        }

        switch (socktype) {
            case SOCK_DGRAM:
                out->st_filetype = __WASI_FILETYPE_SOCKET_DGRAM;
                break;
            case SOCK_STREAM:
                out->st_filetype = __WASI_FILETYPE_SOCKET_STREAM;
                break;
            default:
                out->st_filetype = __WASI_FILETYPE_UNKNOWN;
                return;
        }
    }
    else {
        out->st_filetype = __WASI_FILETYPE_UNKNOWN;
    }
}

static void
convert_timestamp(__wasi_timestamp_t in, struct timespec *out)
{
    // Store sub-second remainder.
#if defined(__SYSCALL_SLONG_TYPE)
    out->tv_nsec = (__SYSCALL_SLONG_TYPE)(in % 1000000000);
#else
    out->tv_nsec = (long)(in % 1000000000);
#endif
    in /= 1000000000;

    // Clamp to the maximum in case it would overflow our system's time_t.
    out->tv_sec = (time_t)in < BH_TIME_T_MAX ? (time_t)in : BH_TIME_T_MAX;
}

// Converts the provided timestamps and flags to a set of arguments for
// futimens() and utimensat().
static void
convert_utimens_arguments(__wasi_timestamp_t st_atim,
                          __wasi_timestamp_t st_mtim,
                          __wasi_fstflags_t fstflags, struct timespec *ts)
{
    if ((fstflags & __WASI_FILESTAT_SET_ATIM_NOW) != 0) {
        ts[0].tv_nsec = UTIME_NOW;
    }
    else if ((fstflags & __WASI_FILESTAT_SET_ATIM) != 0) {
        convert_timestamp(st_atim, &ts[0]);
    }
    else {
        ts[0].tv_nsec = UTIME_OMIT;
    }

    if ((fstflags & __WASI_FILESTAT_SET_MTIM_NOW) != 0) {
        ts[1].tv_nsec = UTIME_NOW;
    }
    else if ((fstflags & __WASI_FILESTAT_SET_MTIM) != 0) {
        convert_timestamp(st_mtim, &ts[1]);
    }
    else {
        ts[1].tv_nsec = UTIME_OMIT;
    }
}

__wasi_errno_t
os_fstat(os_file_handle handle, struct __wasi_filestat_t *buf)
{
    struct stat stat_buf;
    int ret = fstat(handle, &stat_buf);

    if (ret < 0)
        return convert_errno(errno);

    convert_stat(handle, &stat_buf, buf);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_fstatat(os_file_handle handle, const char *path,
           struct __wasi_filestat_t *buf, __wasi_lookupflags_t lookup_flags)
{
    struct stat stat_buf;
    int ret = fstatat(handle, path, &stat_buf,
                      (lookup_flags & __WASI_LOOKUP_SYMLINK_FOLLOW)
                          ? AT_SYMLINK_FOLLOW
                          : AT_SYMLINK_NOFOLLOW);

    if (ret < 0)
        return convert_errno(errno);

    convert_stat(handle, &stat_buf, buf);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_file_get_fdflags(os_file_handle handle, __wasi_fdflags_t *flags)
{
    int ret = fcntl(handle, F_GETFL);

    if (ret < 0)
        return convert_errno(errno);

    *flags = 0;

    if ((ret & O_APPEND) != 0)
        *flags |= __WASI_FDFLAG_APPEND;
#ifdef CONFIG_HAS_O_DSYNC
    if ((ret & O_DSYNC) != 0)
        *flags |= __WASI_FDFLAG_DSYNC;
#endif
    if ((ret & O_NONBLOCK) != 0)
        *flags |= __WASI_FDFLAG_NONBLOCK;
#ifdef CONFIG_HAS_O_RSYNC
    if ((ret & O_RSYNC) != 0)
        *flags |= __WASI_FDFLAG_RSYNC;
#endif
#ifdef CONFIG_HAS_O_SYNC
    if ((ret & O_SYNC) != 0)
        *flags |= __WASI_FDFLAG_SYNC;
#endif

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_file_set_fdflags(os_file_handle handle, __wasi_fdflags_t flags)
{
    int fcntl_flags = 0;

    if ((flags & __WASI_FDFLAG_APPEND) != 0)
        fcntl_flags |= O_APPEND;
    if ((flags & __WASI_FDFLAG_DSYNC) != 0)
#ifdef CONFIG_HAS_O_DSYNC
        fcntl_flags |= O_DSYNC;
#else
        return __WASI_ENOTSUP;
#endif
    if ((flags & __WASI_FDFLAG_NONBLOCK) != 0)
        fcntl_flags |= O_NONBLOCK;
    if ((flags & __WASI_FDFLAG_RSYNC) != 0)
#ifdef CONFIG_HAS_O_RSYNC
        fcntl_flags |= O_RSYNC;
#else
        return __WASI_ENOTSUP;
#endif
    if ((flags & __WASI_FDFLAG_SYNC) != 0)
#ifdef CONFIG_HAS_O_SYNC
        fcntl_flags |= O_SYNC;
#else
        return __WASI_ENOTSUP;
#endif

    int ret = fcntl(handle, F_SETFL, fcntl_flags);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_fdatasync(os_file_handle handle)
{
#if CONFIG_HAS_FDATASYNC
    int ret = fdatasync(handle);
#else
    int ret = fsync(handle);
#endif

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_fsync(os_file_handle handle)
{
    int ret = fsync(handle);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_open_preopendir(const char *path, os_file_handle *out)
{

    int fd = open(path, O_RDONLY | O_DIRECTORY, 0);

    if (fd < 0)
        return convert_errno(errno);

    *out = fd;

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_openat(os_file_handle handle, const char *path, __wasi_oflags_t oflags,
          __wasi_fdflags_t fs_flags, __wasi_lookupflags_t lookup_flags,
          wasi_libc_file_access_mode read_write_mode, os_file_handle *out)
{
    int open_flags = 0;

    // Convert open flags.
    if ((oflags & __WASI_O_CREAT) != 0) {
        open_flags |= O_CREAT;
    }
    if ((oflags & __WASI_O_DIRECTORY) != 0)
        open_flags |= O_DIRECTORY;
    if ((oflags & __WASI_O_EXCL) != 0)
        open_flags |= O_EXCL;
    if ((oflags & __WASI_O_TRUNC) != 0) {
        open_flags |= O_TRUNC;
    }

    // Convert file descriptor flags.
    if ((fs_flags & __WASI_FDFLAG_APPEND) != 0)
        open_flags |= O_APPEND;
    if ((fs_flags & __WASI_FDFLAG_DSYNC) != 0) {
#ifdef CONFIG_HAS_O_DSYNC
        open_flags |= O_DSYNC;
#else
        return __WASI_ENOTSUP;
#endif
    }
    if ((fs_flags & __WASI_FDFLAG_NONBLOCK) != 0)
        open_flags |= O_NONBLOCK;
    if ((fs_flags & __WASI_FDFLAG_RSYNC) != 0) {
#ifdef CONFIG_HAS_O_RSYNC
        open_flags |= O_RSYNC;
#else
        return __WASI_ENOTSUP;
#endif
    }
    if ((fs_flags & __WASI_FDFLAG_SYNC) != 0) {
#ifdef CONFIG_HAS_O_SYNC
        open_flags |= O_SYNC;
#else
        return __WASI_ENOTSUP;
#endif
    }

    if ((lookup_flags & __WASI_LOOKUP_SYMLINK_FOLLOW) == 0) {
        open_flags |= O_NOFOLLOW;
    }

    switch (read_write_mode) {
        case WASI_LIBC_ACCESS_MODE_READ_WRITE:
            open_flags |= O_RDWR;
            break;
        case WASI_LIBC_ACCESS_MODE_READ_ONLY:
            open_flags |= O_RDONLY;
            break;
        case WASI_LIBC_ACCESS_MODE_WRITE_ONLY:
            open_flags |= O_WRONLY;
            break;
        default:
            return __WASI_EINVAL;
    }

    int fd = openat(handle, path, open_flags, 0666);

    if (fd < 0) {
        int openat_errno = errno;
        // Linux returns ENXIO instead of EOPNOTSUPP when opening a socket.
        if (openat_errno == ENXIO) {
            struct stat sb;
            int ret = fstatat(handle, path, &sb,
                              (lookup_flags & __WASI_LOOKUP_SYMLINK_FOLLOW)
                                  ? 0
                                  : AT_SYMLINK_NOFOLLOW);
            return ret == 0 && S_ISSOCK(sb.st_mode) ? __WASI_ENOTSUP
                                                    : __WASI_ENXIO;
        }
        // Linux returns ENOTDIR instead of ELOOP when using
        // O_NOFOLLOW|O_DIRECTORY on a symlink.
        if (openat_errno == ENOTDIR
            && (open_flags & (O_NOFOLLOW | O_DIRECTORY)) != 0) {
            struct stat sb;
            int ret = fstatat(handle, path, &sb, AT_SYMLINK_NOFOLLOW);
            if (S_ISLNK(sb.st_mode)) {
                return __WASI_ELOOP;
            }
            (void)ret;
        }
        // FreeBSD returns EMLINK instead of ELOOP when using O_NOFOLLOW on
        // a symlink.
        if ((lookup_flags & __WASI_LOOKUP_SYMLINK_FOLLOW) == 0
            && openat_errno == EMLINK)
            return __WASI_ELOOP;

        return convert_errno(openat_errno);
    }

    *out = fd;

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_file_get_access_mode(os_file_handle handle,
                        wasi_libc_file_access_mode *access_mode)
{
    int ret = fcntl(handle, F_GETFL, 0);

    if (ret < 0)
        return convert_errno(errno);

    switch (ret & O_ACCMODE) {
        case O_RDONLY:
            *access_mode = WASI_LIBC_ACCESS_MODE_READ_ONLY;
            break;
        case O_WRONLY:
            *access_mode = WASI_LIBC_ACCESS_MODE_WRITE_ONLY;
            break;
        case O_RDWR:
            *access_mode = WASI_LIBC_ACCESS_MODE_READ_WRITE;
            break;
        default:
            return __WASI_EINVAL;
    }

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_close(os_file_handle handle, bool is_stdio)
{
    if (is_stdio)
        return __WASI_ESUCCESS;

    int ret = close(handle);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_preadv(os_file_handle handle, const struct __wasi_iovec_t *iov, int iovcnt,
          __wasi_filesize_t offset, size_t *nread)
{
#if CONFIG_HAS_PREADV
    ssize_t len =
        preadv(handle, (const struct iovec *)iov, (int)iovcnt, (off_t)offset);
    if (len < 0)
        return convert_errno(errno);

    *nread = (size_t)len;
    return __WASI_ESUCCESS;
#else
    if (iovcnt == 1) {
        ssize_t len = pread(handle, iov->buf, iov->buf_len, offset);

        if (len < 0)
            return convert_errno(errno);

        *nread = len;
        return __WASI_ESUCCESS;
    }

    // Allocate a single buffer to fit all data.
    size_t totalsize = 0;
    for (int i = 0; i < iovcnt; ++i)
        totalsize += iov[i].buf_len;

    char *buf = BH_MALLOC(totalsize);

    if (buf == NULL) {
        return __WASI_ENOMEM;
    }

    // Perform a single read operation.
    ssize_t len = pread(handle, buf, totalsize, offset);

    if (len < 0) {
        BH_FREE(buf);
        return convert_errno(errno);
    }

    // Copy data back to vectors.
    size_t bufoff = 0;
    for (int i = 0; i < iovcnt; ++i) {
        if (bufoff + iov[i].buf_len < (size_t)len) {
            memcpy(iov[i].buf, buf + bufoff, iov[i].buf_len);
            bufoff += iov[i].buf_len;
        }
        else {
            memcpy(iov[i].buf, buf + bufoff, len - bufoff);
            break;
        }
    }
    BH_FREE(buf);
    *nread = len;

    return __WASI_ESUCCESS;
#endif
}

__wasi_errno_t
os_pwritev(os_file_handle handle, const struct __wasi_ciovec_t *iov, int iovcnt,
           __wasi_filesize_t offset, size_t *nwritten)
{
    if (iovcnt == 0)
        return __WASI_EINVAL;

    ssize_t len = 0;
#if CONFIG_HAS_PWRITEV
    len =
        pwritev(handle, (const struct iovec *)iov, (int)iovcnt, (off_t)offset);
#else
    if (iovcnt == 1) {
        len = pwrite(handle, iov->buf, iov->buf_len, offset);
    }
    else {
        // Allocate a single buffer to fit all data.
        size_t totalsize = 0;
        for (int i = 0; i < iovcnt; ++i)
            totalsize += iov[i].buf_len;
        char *buf = BH_MALLOC(totalsize);
        if (buf == NULL) {
            return __WASI_ENOMEM;
        }
        size_t bufoff = 0;
        for (int i = 0; i < iovcnt; ++i) {
            memcpy(buf + bufoff, iov[i].buf, iov[i].buf_len);
            bufoff += iov[i].buf_len;
        }

        // Perform a single write operation.
        len = pwrite(handle, buf, totalsize, offset);
        BH_FREE(buf);
    }
#endif
    if (len < 0)
        return convert_errno(errno);

    *nwritten = (size_t)len;
    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_readv(os_file_handle handle, const struct __wasi_iovec_t *iov, int iovcnt,
         size_t *nread)
{
    ssize_t len = readv(handle, (const struct iovec *)iov, (int)iovcnt);

    if (len < 0)
        return convert_errno(errno);

    *nread = (size_t)len;

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_writev(os_file_handle handle, const struct __wasi_ciovec_t *iov, int iovcnt,
          size_t *nwritten)
{
    ssize_t len = writev(handle, (const struct iovec *)iov, (int)iovcnt);

    if (len < 0)
        return convert_errno(errno);

    *nwritten = (size_t)len;

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_fallocate(os_file_handle handle, __wasi_filesize_t offset,
             __wasi_filesize_t length)
{
#if CONFIG_HAS_POSIX_FALLOCATE
    int ret = posix_fallocate(handle, (off_t)offset, (off_t)length);
#else
    // At least ensure that the file is grown to the right size.
    // TODO(ed): See if this can somehow be implemented without any race
    // conditions. We may end up shrinking the file right now.
    struct stat sb;
    int ret = fstat(handle, &sb);
    off_t newsize = (off_t)(offset + length);

    if (ret == 0 && sb.st_size < newsize)
        ret = ftruncate(handle, newsize);
#endif

    if (ret != 0)
        return convert_errno(ret);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_ftruncate(os_file_handle handle, __wasi_filesize_t size)
{
    int ret = ftruncate(handle, (off_t)size);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_futimens(os_file_handle handle, __wasi_timestamp_t access_time,
            __wasi_timestamp_t modification_time, __wasi_fstflags_t fstflags)
{
    struct timespec ts[2];
    convert_utimens_arguments(access_time, modification_time, fstflags, ts);

    int ret = futimens(handle, ts);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_utimensat(os_file_handle handle, const char *path,
             __wasi_timestamp_t access_time,
             __wasi_timestamp_t modification_time, __wasi_fstflags_t fstflags,
             __wasi_lookupflags_t lookup_flags)
{
    struct timespec ts[2];
    convert_utimens_arguments(access_time, modification_time, fstflags, ts);

    int ret = utimensat(handle, path, ts,
                        (lookup_flags & __WASI_LOOKUP_SYMLINK_FOLLOW)
                            ? 0
                            : AT_SYMLINK_NOFOLLOW);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_readlinkat(os_file_handle handle, const char *path, char *buf,
              size_t bufsize, size_t *nread)
{
    // Linux requires that the buffer size is positive. whereas POSIX does
    // not. Use a fake buffer to store the results if the size is zero.
    char fakebuf[1];
    ssize_t len = readlinkat(handle, path, bufsize == 0 ? fakebuf : buf,
                             bufsize == 0 ? sizeof(fakebuf) : bufsize);

    if (len < 0)
        return convert_errno(errno);

    *nread = (size_t)len < bufsize ? (size_t)len : bufsize;

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_linkat(os_file_handle from_handle, const char *from_path,
          os_file_handle to_handle, const char *to_path,
          __wasi_lookupflags_t lookup_flags)
{
    int ret = linkat(
        from_handle, from_path, to_handle, to_path,
        (lookup_flags & __WASI_LOOKUP_SYMLINK_FOLLOW) ? AT_SYMLINK_FOLLOW : 0);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_symlinkat(const char *old_path, os_file_handle handle, const char *new_path)
{
    int ret = symlinkat(old_path, handle, new_path);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_mkdirat(os_file_handle handle, const char *path)
{
    int ret = mkdirat(handle, path, 0777);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_renameat(os_file_handle old_handle, const char *old_path,
            os_file_handle new_handle, const char *new_path)
{

    int ret = renameat(old_handle, old_path, new_handle, new_path);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_unlinkat(os_file_handle handle, const char *path, bool is_dir)
{
    int ret = unlinkat(handle, path, is_dir ? AT_REMOVEDIR : 0);

#ifndef __linux__
    if (ret < 0) {
        // Non-Linux implementations may return EPERM when attempting to remove
        // a directory without REMOVEDIR. While that's what POSIX specifies,
        // it's less useful. Adjust this to EISDIR. It doesn't matter that this
        // is not atomic with the unlinkat, because if the file is removed and a
        // directory is created before fstatat sees it, we're racing with that
        // change anyway and unlinkat could have legitimately seen the directory
        // if the race had turned out differently.
        if (errno == EPERM) {
            struct stat statbuf;
            if (fstatat(handle, path, &statbuf, AT_SYMLINK_NOFOLLOW) == 0
                && S_ISDIR(statbuf.st_mode)) {
                errno = EISDIR;
            }
        }
        // POSIX permits either EEXIST or ENOTEMPTY when the directory is not
        // empty. Map it to ENOTEMPTY.
        else if (errno == EEXIST) {
            errno = ENOTEMPTY;
        }

        return convert_errno(errno);
    }
#endif

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_lseek(os_file_handle handle, __wasi_filedelta_t offset,
         __wasi_whence_t whence, __wasi_filesize_t *new_offset)
{
    int nwhence;

    switch (whence) {
        case __WASI_WHENCE_CUR:
            nwhence = SEEK_CUR;
            break;
        case __WASI_WHENCE_END:
            nwhence = SEEK_END;
            break;
        case __WASI_WHENCE_SET:
            nwhence = SEEK_SET;
            break;
        default:
            return __WASI_EINVAL;
    }

    off_t ret = lseek(handle, offset, nwhence);

    if (ret < 0)
        return convert_errno(errno);

    *new_offset = (__wasi_filesize_t)ret;

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_fadvise(os_file_handle handle, __wasi_filesize_t offset,
           __wasi_filesize_t length, __wasi_advice_t advice)
{
#ifdef POSIX_FADV_NORMAL
    int nadvice;
    switch (advice) {
        case __WASI_ADVICE_DONTNEED:
            nadvice = POSIX_FADV_DONTNEED;
            break;
        case __WASI_ADVICE_NOREUSE:
            nadvice = POSIX_FADV_NOREUSE;
            break;
        case __WASI_ADVICE_NORMAL:
            nadvice = POSIX_FADV_NORMAL;
            break;
        case __WASI_ADVICE_RANDOM:
            nadvice = POSIX_FADV_RANDOM;
            break;
        case __WASI_ADVICE_SEQUENTIAL:
            nadvice = POSIX_FADV_SEQUENTIAL;
            break;
        case __WASI_ADVICE_WILLNEED:
            nadvice = POSIX_FADV_WILLNEED;
            break;
        default:
            return __WASI_EINVAL;
    }

    int ret = posix_fadvise(handle, (off_t)offset, (off_t)length, nadvice);

    if (ret != 0)
        return convert_errno(ret);

    return __WASI_ESUCCESS;
#else
    // Advisory information can be safely ignored if not supported
    switch (advice) {
        case __WASI_ADVICE_DONTNEED:
        case __WASI_ADVICE_NOREUSE:
        case __WASI_ADVICE_NORMAL:
        case __WASI_ADVICE_RANDOM:
        case __WASI_ADVICE_SEQUENTIAL:
        case __WASI_ADVICE_WILLNEED:
            return __WASI_ESUCCESS;
        default:
            return __WASI_EINVAL;
    }
#endif
}

__wasi_errno_t
os_isatty(os_file_handle handle)
{
#if CONFIG_HAS_ISATTY
    int ret = isatty(handle);

    if (ret == 1)
        return __WASI_ESUCCESS;

    return __WASI_ENOTTY;
#else
    return __WASI_ENOTSUP;
#endif
}

bool
os_is_stdin_handle(os_file_handle fd)
{
    return fd == STDIN_FILENO;
}

bool
os_is_stdout_handle(os_file_handle fd)
{
    return fd == STDOUT_FILENO;
}

bool
os_is_stderr_handle(os_file_handle fd)
{
    return fd == STDERR_FILENO;
}

os_file_handle
os_convert_stdin_handle(os_raw_file_handle raw_stdin)
{
    return raw_stdin >= 0 ? raw_stdin : STDIN_FILENO;
}

os_file_handle
os_convert_stdout_handle(os_raw_file_handle raw_stdout)
{
    return raw_stdout >= 0 ? raw_stdout : STDOUT_FILENO;
}

os_file_handle
os_convert_stderr_handle(os_raw_file_handle raw_stderr)
{
    return raw_stderr >= 0 ? raw_stderr : STDERR_FILENO;
}

__wasi_errno_t
os_fdopendir(os_file_handle handle, os_dir_stream *dir_stream)
{
    *dir_stream = fdopendir(handle);

    if (*dir_stream == NULL)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_rewinddir(os_dir_stream dir_stream)
{
    rewinddir(dir_stream);
    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_seekdir(os_dir_stream dir_stream, __wasi_dircookie_t position)
{
    seekdir(dir_stream, (long)position);
    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_readdir(os_dir_stream dir_stream, __wasi_dirent_t *entry,
           const char **d_name)
{
    errno = 0;

    struct dirent *dent = readdir(dir_stream);

    if (dent == NULL) {
        *d_name = NULL;
        if (errno != 0) {
            return convert_errno(errno);
        }
        else {
            return 0;
        }
    }

    long offset = (__wasi_dircookie_t)telldir(dir_stream);

    size_t namlen = strlen(dent->d_name);

    *d_name = dent->d_name;
    entry->d_next = offset;
    entry->d_namlen = (__wasi_dirnamlen_t)namlen;
#if CONFIG_HAS_D_INO
    entry->d_ino = dent->d_ino;
#else
    entry->d_ino = 0;
#endif

    switch (dent->d_type) {
        case DT_BLK:
            entry->d_type = __WASI_FILETYPE_BLOCK_DEVICE;
            break;
        case DT_CHR:
            entry->d_type = __WASI_FILETYPE_CHARACTER_DEVICE;
            break;
        case DT_DIR:
            entry->d_type = __WASI_FILETYPE_DIRECTORY;
            break;
        case DT_FIFO:
            entry->d_type = __WASI_FILETYPE_SOCKET_STREAM;
            break;
        case DT_LNK:
            entry->d_type = __WASI_FILETYPE_SYMBOLIC_LINK;
            break;
        case DT_REG:
            entry->d_type = __WASI_FILETYPE_REGULAR_FILE;
            break;
#ifdef DT_SOCK
        case DT_SOCK:
            // Technically not correct, but good enough.
            entry->d_type = __WASI_FILETYPE_SOCKET_STREAM;
            break;
#endif
        default:
            entry->d_type = __WASI_FILETYPE_UNKNOWN;
            break;
    }

    return __WASI_ESUCCESS;
}

__wasi_errno_t
os_closedir(os_dir_stream dir_stream)
{
    int ret = closedir(dir_stream);

    if (ret < 0)
        return convert_errno(errno);

    return __WASI_ESUCCESS;
}

os_dir_stream
os_get_invalid_dir_stream()
{
    return NULL;
}

bool
os_is_dir_stream_valid(os_dir_stream *dir_stream)
{
    assert(dir_stream != NULL);

    return *dir_stream != NULL;
}

bool
os_is_handle_valid(os_file_handle *handle)
{
    assert(handle != NULL);

    return *handle > -1;
}

char *
os_realpath(const char *path, char *resolved_path)
{
    return realpath(path, resolved_path);
}

os_raw_file_handle
os_invalid_raw_handle(void)
{
    return -1;
}
