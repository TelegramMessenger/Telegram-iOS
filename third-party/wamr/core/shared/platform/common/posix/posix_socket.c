/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "platform_api_vmcore.h"
#include "platform_api_extension.h"
#include "libc_errno.h"

#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <netinet/in.h>

static bool
textual_addr_to_sockaddr(const char *textual, int port, struct sockaddr *out,
                         socklen_t *out_len)
{
    struct sockaddr_in *v4;
#ifdef IPPROTO_IPV6
    struct sockaddr_in6 *v6;
#endif

    assert(textual);

    v4 = (struct sockaddr_in *)out;
    if (inet_pton(AF_INET, textual, &v4->sin_addr.s_addr) == 1) {
        v4->sin_family = AF_INET;
        v4->sin_port = htons(port);
        *out_len = sizeof(struct sockaddr_in);
        return true;
    }

#ifdef IPPROTO_IPV6
    v6 = (struct sockaddr_in6 *)out;
    if (inet_pton(AF_INET6, textual, &v6->sin6_addr.s6_addr) == 1) {
        v6->sin6_family = AF_INET6;
        v6->sin6_port = htons(port);
        *out_len = sizeof(struct sockaddr_in6);
        return true;
    }
#endif

    return false;
}

static int
sockaddr_to_bh_sockaddr(const struct sockaddr *sockaddr,
                        bh_sockaddr_t *bh_sockaddr)
{
    switch (sockaddr->sa_family) {
        case AF_INET:
        {
            struct sockaddr_in *addr = (struct sockaddr_in *)sockaddr;

            bh_sockaddr->port = ntohs(addr->sin_port);
            bh_sockaddr->addr_buffer.ipv4 = ntohl(addr->sin_addr.s_addr);
            bh_sockaddr->is_ipv4 = true;
            return BHT_OK;
        }
#ifdef IPPROTO_IPV6
        case AF_INET6:
        {
            struct sockaddr_in6 *addr = (struct sockaddr_in6 *)sockaddr;
            size_t i;

            bh_sockaddr->port = ntohs(addr->sin6_port);

            for (i = 0; i < sizeof(bh_sockaddr->addr_buffer.ipv6)
                                / sizeof(bh_sockaddr->addr_buffer.ipv6[0]);
                 i++) {
                uint16 part_addr = addr->sin6_addr.s6_addr[i * 2]
                                   | (addr->sin6_addr.s6_addr[i * 2 + 1] << 8);
                bh_sockaddr->addr_buffer.ipv6[i] = ntohs(part_addr);
            }

            bh_sockaddr->is_ipv4 = false;
            return BHT_OK;
        }
#endif
        default:
            errno = EAFNOSUPPORT;
            return BHT_ERROR;
    }
}

static void
bh_sockaddr_to_sockaddr(const bh_sockaddr_t *bh_sockaddr,
                        struct sockaddr_storage *sockaddr, socklen_t *socklen)
{
    if (bh_sockaddr->is_ipv4) {
        struct sockaddr_in *addr = (struct sockaddr_in *)sockaddr;
        addr->sin_port = htons(bh_sockaddr->port);
        addr->sin_family = AF_INET;
        addr->sin_addr.s_addr = htonl(bh_sockaddr->addr_buffer.ipv4);
        *socklen = sizeof(*addr);
    }
#ifdef IPPROTO_IPV6
    else {
        struct sockaddr_in6 *addr = (struct sockaddr_in6 *)sockaddr;
        size_t i;
        addr->sin6_port = htons(bh_sockaddr->port);
        addr->sin6_family = AF_INET6;

        for (i = 0; i < sizeof(bh_sockaddr->addr_buffer.ipv6)
                            / sizeof(bh_sockaddr->addr_buffer.ipv6[0]);
             i++) {
            uint16 part_addr = htons(bh_sockaddr->addr_buffer.ipv6[i]);
            addr->sin6_addr.s6_addr[i * 2] = 0xff & part_addr;
            addr->sin6_addr.s6_addr[i * 2 + 1] = (0xff00 & part_addr) >> 8;
        }

        *socklen = sizeof(*addr);
    }
#endif
}

int
os_socket_create(bh_socket_t *sock, bool is_ipv4, bool is_tcp)
{
    int af = is_ipv4 ? AF_INET : AF_INET6;

    if (!sock) {
        return BHT_ERROR;
    }

    if (is_tcp) {
        *sock = socket(af, SOCK_STREAM, IPPROTO_TCP);
    }
    else {
        *sock = socket(af, SOCK_DGRAM, 0);
    }

    return (*sock == -1) ? BHT_ERROR : BHT_OK;
}

int
os_socket_bind(bh_socket_t socket, const char *host, int *port)
{
    struct sockaddr_storage addr = { 0 };
    struct linger ling;
    socklen_t socklen;
    int ret;

    assert(host);
    assert(port);

    ling.l_onoff = 1;
    ling.l_linger = 0;

    if (!textual_addr_to_sockaddr(host, *port, (struct sockaddr *)&addr,
                                  &socklen)) {
        goto fail;
    }

    ret = fcntl(socket, F_SETFD, FD_CLOEXEC);
    if (ret < 0) {
        goto fail;
    }

    ret = setsockopt(socket, SOL_SOCKET, SO_LINGER, &ling, sizeof(ling));
    if (ret < 0) {
        goto fail;
    }

    ret = bind(socket, (struct sockaddr *)&addr, socklen);
    if (ret < 0) {
        goto fail;
    }

    socklen = sizeof(addr);
    if (getsockname(socket, (void *)&addr, &socklen) == -1) {
        goto fail;
    }

    if (addr.ss_family == AF_INET) {
        *port = ntohs(((struct sockaddr_in *)&addr)->sin_port);
    }
    else {
#ifdef IPPROTO_IPV6
        *port = ntohs(((struct sockaddr_in6 *)&addr)->sin6_port);
#else
        goto fail;
#endif
    }

    return BHT_OK;

fail:
    return BHT_ERROR;
}

int
os_socket_settimeout(bh_socket_t socket, uint64 timeout_us)
{
    struct timeval tv;
    tv.tv_sec = timeout_us / 1000000UL;
    tv.tv_usec = timeout_us % 1000000UL;

    if (setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, (const char *)&tv,
                   sizeof(tv))
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_listen(bh_socket_t socket, int max_client)
{
    if (listen(socket, max_client) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_accept(bh_socket_t server_sock, bh_socket_t *sock, void *addr,
                 unsigned int *addrlen)
{
    if (addr == NULL) {
        *sock = accept(server_sock, NULL, NULL);
    }
    else {
        socklen_t len = *addrlen;
        *sock = accept(server_sock, addr, &len);
        *addrlen = len;
    }
    if (*sock < 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
}

int
os_socket_connect(bh_socket_t socket, const char *addr, int port)
{
    struct sockaddr_storage addr_in = { 0 };
    socklen_t addr_len;
    int ret = 0;

    if (!textual_addr_to_sockaddr(addr, port, (struct sockaddr *)&addr_in,
                                  &addr_len)) {
        return BHT_ERROR;
    }

    ret = connect(socket, (struct sockaddr *)&addr_in, addr_len);
    if (ret == -1) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_recv(bh_socket_t socket, void *buf, unsigned int len)
{
    return recv(socket, buf, len, 0);
}

int
os_socket_recv_from(bh_socket_t socket, void *buf, unsigned int len, int flags,
                    bh_sockaddr_t *src_addr)
{
    struct sockaddr_storage sock_addr = { 0 };
    socklen_t socklen = sizeof(sock_addr);
    int ret;

    ret = recvfrom(socket, buf, len, flags, (struct sockaddr *)&sock_addr,
                   &socklen);

    if (ret < 0) {
        return ret;
    }

    if (src_addr && socklen > 0) {
        if (sockaddr_to_bh_sockaddr((struct sockaddr *)&sock_addr, src_addr)
            == BHT_ERROR) {
            return -1;
        }
    }
    else if (src_addr) {
        memset(src_addr, 0, sizeof(*src_addr));
    }

    return ret;
}

int
os_socket_send(bh_socket_t socket, const void *buf, unsigned int len)
{
    return send(socket, buf, len, 0);
}

int
os_socket_send_to(bh_socket_t socket, const void *buf, unsigned int len,
                  int flags, const bh_sockaddr_t *dest_addr)
{
    struct sockaddr_storage sock_addr = { 0 };
    socklen_t socklen = 0;

    bh_sockaddr_to_sockaddr(dest_addr, &sock_addr, &socklen);

    return sendto(socket, buf, len, flags, (const struct sockaddr *)&sock_addr,
                  socklen);
}

int
os_socket_close(bh_socket_t socket)
{
    close(socket);
    return BHT_OK;
}

__wasi_errno_t
os_socket_shutdown(bh_socket_t socket)
{
    if (shutdown(socket, O_RDWR) != 0) {
        return convert_errno(errno);
    }
    return __WASI_ESUCCESS;
}

int
os_socket_inet_network(bool is_ipv4, const char *cp, bh_ip_addr_buffer_t *out)
{
    if (!cp)
        return BHT_ERROR;

    if (is_ipv4) {
        if (inet_pton(AF_INET, cp, &out->ipv4) != 1) {
            return BHT_ERROR;
        }
        /* Note: ntohl(INADDR_NONE) == INADDR_NONE */
        out->ipv4 = ntohl(out->ipv4);
    }
    else {
#ifdef IPPROTO_IPV6
        if (inet_pton(AF_INET6, cp, out->ipv6) != 1) {
            return BHT_ERROR;
        }
        for (int i = 0; i < 8; i++) {
            out->ipv6[i] = ntohs(out->ipv6[i]);
        }
#else
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
#endif
    }

    return BHT_OK;
}

static int
getaddrinfo_error_to_errno(int error)
{
    switch (error) {
        case EAI_AGAIN:
            return EAGAIN;
        case EAI_FAIL:
            return EFAULT;
        case EAI_MEMORY:
            return ENOMEM;
        case EAI_SYSTEM:
            return errno;
        default:
            return EINVAL;
    }
}

static int
is_addrinfo_supported(struct addrinfo *info)
{
    return
        // Allow only IPv4 and IPv6
        (info->ai_family == AF_INET || info->ai_family == AF_INET6)
        // Allow only UDP and TCP
        && (info->ai_socktype == SOCK_DGRAM || info->ai_socktype == SOCK_STREAM)
        && (info->ai_protocol == IPPROTO_TCP || info->ai_protocol == IPPROTO_UDP
            || info->ai_protocol == 0);
}

int
os_socket_addr_resolve(const char *host, const char *service,
                       uint8_t *hint_is_tcp, uint8_t *hint_is_ipv4,
                       bh_addr_info_t *addr_info, size_t addr_info_size,
                       size_t *max_info_size)
{
    struct addrinfo hints = { 0 }, *res, *result;
    int hints_enabled = hint_is_tcp || hint_is_ipv4;
    int ret;
    size_t pos = 0;

    if (hints_enabled) {
        if (hint_is_ipv4) {
            hints.ai_family = *hint_is_ipv4 ? AF_INET : AF_INET6;
        }
        if (hint_is_tcp) {
            hints.ai_socktype = *hint_is_tcp ? SOCK_STREAM : SOCK_DGRAM;
        }
    }

    ret = getaddrinfo(host, strlen(service) == 0 ? NULL : service,
                      hints_enabled ? &hints : NULL, &result);
    if (ret != BHT_OK) {
        errno = getaddrinfo_error_to_errno(ret);
        return BHT_ERROR;
    }

    res = result;
    while (res) {
        if (!is_addrinfo_supported(res)) {
            res = res->ai_next;
            continue;
        }
        if (addr_info_size > pos) {
            ret =
                sockaddr_to_bh_sockaddr(res->ai_addr, &addr_info[pos].sockaddr);

            if (ret == BHT_ERROR) {
                freeaddrinfo(result);
                return BHT_ERROR;
            }

            addr_info[pos].is_tcp = res->ai_socktype == SOCK_STREAM;
        }

        pos++;
        res = res->ai_next;
    }

    *max_info_size = pos;
    freeaddrinfo(result);

    return BHT_OK;
}

static int
os_socket_setbooloption(bh_socket_t socket, int level, int optname,
                        bool is_enabled)
{
    int option = (int)is_enabled;
    if (setsockopt(socket, level, optname, &option, sizeof(option)) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

static int
os_socket_getbooloption(bh_socket_t socket, int level, int optname,
                        bool *is_enabled)
{
    assert(is_enabled);

    int optval;
    socklen_t optval_size = sizeof(optval);
    if (getsockopt(socket, level, optname, &optval, &optval_size) != 0) {
        return BHT_ERROR;
    }
    *is_enabled = (bool)optval;
    return BHT_OK;
}

int
os_socket_set_send_buf_size(bh_socket_t socket, size_t bufsiz)
{
    int buf_size_int = (int)bufsiz;
    if (setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &buf_size_int,
                   sizeof(buf_size_int))
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_get_send_buf_size(bh_socket_t socket, size_t *bufsiz)
{
    assert(bufsiz);

    int buf_size_int;
    socklen_t bufsiz_len = sizeof(buf_size_int);
    if (getsockopt(socket, SOL_SOCKET, SO_SNDBUF, &buf_size_int, &bufsiz_len)
        != 0) {
        return BHT_ERROR;
    }
    *bufsiz = (size_t)buf_size_int;

    return BHT_OK;
}

int
os_socket_set_recv_buf_size(bh_socket_t socket, size_t bufsiz)
{
    int buf_size_int = (int)bufsiz;
    if (setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &buf_size_int,
                   sizeof(buf_size_int))
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_get_recv_buf_size(bh_socket_t socket, size_t *bufsiz)
{
    assert(bufsiz);

    int buf_size_int;
    socklen_t bufsiz_len = sizeof(buf_size_int);
    if (getsockopt(socket, SOL_SOCKET, SO_RCVBUF, &buf_size_int, &bufsiz_len)
        != 0) {
        return BHT_ERROR;
    }
    *bufsiz = (size_t)buf_size_int;

    return BHT_OK;
}

int
os_socket_set_keep_alive(bh_socket_t socket, bool is_enabled)
{
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_KEEPALIVE,
                                   is_enabled);
}

int
os_socket_get_keep_alive(bh_socket_t socket, bool *is_enabled)
{
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_KEEPALIVE,
                                   is_enabled);
}

int
os_socket_set_reuse_addr(bh_socket_t socket, bool is_enabled)
{
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_REUSEADDR,
                                   is_enabled);
}

int
os_socket_get_reuse_addr(bh_socket_t socket, bool *is_enabled)
{
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_REUSEADDR,
                                   is_enabled);
}

int
os_socket_set_reuse_port(bh_socket_t socket, bool is_enabled)
{
#if defined(SO_REUSEPORT) /* NuttX doesn't have SO_REUSEPORT */
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_REUSEPORT,
                                   is_enabled);
#else
    errno = ENOTSUP;
    return BHT_ERROR;
#endif /* defined(SO_REUSEPORT) */
}

int
os_socket_get_reuse_port(bh_socket_t socket, bool *is_enabled)
{
#if defined(SO_REUSEPORT) /* NuttX doesn't have SO_REUSEPORT */
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_REUSEPORT,
                                   is_enabled);
#else
    errno = ENOTSUP;
    return BHT_ERROR;
#endif /* defined(SO_REUSEPORT) */
}

int
os_socket_set_linger(bh_socket_t socket, bool is_enabled, int linger_s)
{
    struct linger linger_opts = { .l_onoff = (int)is_enabled,
                                  .l_linger = linger_s };
    if (setsockopt(socket, SOL_SOCKET, SO_LINGER, &linger_opts,
                   sizeof(linger_opts))
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_get_linger(bh_socket_t socket, bool *is_enabled, int *linger_s)
{
    assert(is_enabled);
    assert(linger_s);

    struct linger linger_opts;
    socklen_t linger_opts_len = sizeof(linger_opts);
    if (getsockopt(socket, SOL_SOCKET, SO_LINGER, &linger_opts,
                   &linger_opts_len)
        != 0) {
        return BHT_ERROR;
    }
    *linger_s = linger_opts.l_linger;
    *is_enabled = (bool)linger_opts.l_onoff;
    return BHT_OK;
}

int
os_socket_set_tcp_no_delay(bh_socket_t socket, bool is_enabled)
{
    return os_socket_setbooloption(socket, IPPROTO_TCP, TCP_NODELAY,
                                   is_enabled);
}

int
os_socket_get_tcp_no_delay(bh_socket_t socket, bool *is_enabled)
{
    return os_socket_getbooloption(socket, IPPROTO_TCP, TCP_NODELAY,
                                   is_enabled);
}

int
os_socket_set_tcp_quick_ack(bh_socket_t socket, bool is_enabled)
{
#ifdef TCP_QUICKACK
    return os_socket_setbooloption(socket, IPPROTO_TCP, TCP_QUICKACK,
                                   is_enabled);
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_get_tcp_quick_ack(bh_socket_t socket, bool *is_enabled)
{
#ifdef TCP_QUICKACK
    return os_socket_getbooloption(socket, IPPROTO_TCP, TCP_QUICKACK,
                                   is_enabled);
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_set_tcp_keep_idle(bh_socket_t socket, uint32 time_s)
{
    int time_s_int = (int)time_s;
#ifdef TCP_KEEPIDLE
    if (setsockopt(socket, IPPROTO_TCP, TCP_KEEPIDLE, &time_s_int,
                   sizeof(time_s_int))
        != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
#elif defined(TCP_KEEPALIVE)
    if (setsockopt(socket, IPPROTO_TCP, TCP_KEEPALIVE, &time_s_int,
                   sizeof(time_s_int))
        != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_get_tcp_keep_idle(bh_socket_t socket, uint32 *time_s)
{
    assert(time_s);
    int time_s_int;
    socklen_t time_s_len = sizeof(time_s_int);
#ifdef TCP_KEEPIDLE
    if (getsockopt(socket, IPPROTO_TCP, TCP_KEEPIDLE, &time_s_int, &time_s_len)
        != 0) {
        return BHT_ERROR;
    }
    *time_s = (uint32)time_s_int;
    return BHT_OK;
#elif defined(TCP_KEEPALIVE)
    if (getsockopt(socket, IPPROTO_TCP, TCP_KEEPALIVE, &time_s_int, &time_s_len)
        != 0) {
        return BHT_ERROR;
    }
    *time_s = (uint32)time_s_int;
    return BHT_OK;
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_set_tcp_keep_intvl(bh_socket_t socket, uint32 time_s)
{
    int time_s_int = (int)time_s;
#ifdef TCP_KEEPINTVL
    if (setsockopt(socket, IPPROTO_TCP, TCP_KEEPINTVL, &time_s_int,
                   sizeof(time_s_int))
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_get_tcp_keep_intvl(bh_socket_t socket, uint32 *time_s)
{
#ifdef TCP_KEEPINTVL
    assert(time_s);
    int time_s_int;
    socklen_t time_s_len = sizeof(time_s_int);
    if (getsockopt(socket, IPPROTO_TCP, TCP_KEEPINTVL, &time_s_int, &time_s_len)
        != 0) {
        return BHT_ERROR;
    }
    *time_s = (uint32)time_s_int;
    return BHT_OK;
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_set_tcp_fastopen_connect(bh_socket_t socket, bool is_enabled)
{
#ifdef TCP_FASTOPEN_CONNECT
    return os_socket_setbooloption(socket, IPPROTO_TCP, TCP_FASTOPEN_CONNECT,
                                   is_enabled);
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_get_tcp_fastopen_connect(bh_socket_t socket, bool *is_enabled)
{
#ifdef TCP_FASTOPEN_CONNECT
    return os_socket_getbooloption(socket, IPPROTO_TCP, TCP_FASTOPEN_CONNECT,
                                   is_enabled);
#else
    errno = ENOSYS;

    return BHT_ERROR;
#endif
}

int
os_socket_set_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool is_enabled)
{
    if (ipv6) {
#ifdef IPPROTO_IPV6
        return os_socket_setbooloption(socket, IPPROTO_IPV6,
                                       IPV6_MULTICAST_LOOP, is_enabled);
#else
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
#endif
    }
    else {
        return os_socket_setbooloption(socket, IPPROTO_IP, IP_MULTICAST_LOOP,
                                       is_enabled);
    }
}

int
os_socket_get_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool *is_enabled)
{
    if (ipv6) {
#ifdef IPPROTO_IPV6
        return os_socket_getbooloption(socket, IPPROTO_IPV6,
                                       IPV6_MULTICAST_LOOP, is_enabled);
#else
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
#endif
    }
    else {
        return os_socket_getbooloption(socket, IPPROTO_IP, IP_MULTICAST_LOOP,
                                       is_enabled);
    }
}

int
os_socket_set_ip_add_membership(bh_socket_t socket,
                                bh_ip_addr_buffer_t *imr_multiaddr,
                                uint32_t imr_interface, bool is_ipv6)
{
    assert(imr_multiaddr);
    if (is_ipv6) {
#if defined(IPPROTO_IPV6) && !defined(BH_PLATFORM_COSMOPOLITAN)
        struct ipv6_mreq mreq;
        for (int i = 0; i < 8; i++) {
            ((uint16_t *)mreq.ipv6mr_multiaddr.s6_addr)[i] =
                imr_multiaddr->ipv6[i];
        }
        mreq.ipv6mr_interface = imr_interface;
        if (setsockopt(socket, IPPROTO_IPV6, IPV6_JOIN_GROUP, &mreq,
                       sizeof(mreq))
            != 0) {
            return BHT_ERROR;
        }
#else
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
#endif
    }
    else {
        struct ip_mreq mreq;
        mreq.imr_multiaddr.s_addr = imr_multiaddr->ipv4;
        mreq.imr_interface.s_addr = imr_interface;
        if (setsockopt(socket, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq,
                       sizeof(mreq))
            != 0) {
            return BHT_ERROR;
        }
    }

    return BHT_OK;
}

int
os_socket_set_ip_drop_membership(bh_socket_t socket,
                                 bh_ip_addr_buffer_t *imr_multiaddr,
                                 uint32_t imr_interface, bool is_ipv6)
{
    assert(imr_multiaddr);
    if (is_ipv6) {
#if defined(IPPROTO_IPV6) && !defined(BH_PLATFORM_COSMOPOLITAN)
        struct ipv6_mreq mreq;
        for (int i = 0; i < 8; i++) {
            ((uint16_t *)mreq.ipv6mr_multiaddr.s6_addr)[i] =
                imr_multiaddr->ipv6[i];
        }
        mreq.ipv6mr_interface = imr_interface;
        if (setsockopt(socket, IPPROTO_IPV6, IPV6_LEAVE_GROUP, &mreq,
                       sizeof(mreq))
            != 0) {
            return BHT_ERROR;
        }
#else
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
#endif
    }
    else {
        struct ip_mreq mreq;
        mreq.imr_multiaddr.s_addr = imr_multiaddr->ipv4;
        mreq.imr_interface.s_addr = imr_interface;
        if (setsockopt(socket, IPPROTO_IP, IP_DROP_MEMBERSHIP, &mreq,
                       sizeof(mreq))
            != 0) {
            return BHT_ERROR;
        }
    }

    return BHT_OK;
}

int
os_socket_set_ip_ttl(bh_socket_t socket, uint8_t ttl_s)
{
    if (setsockopt(socket, IPPROTO_IP, IP_TTL, &ttl_s, sizeof(ttl_s)) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_get_ip_ttl(bh_socket_t socket, uint8_t *ttl_s)
{
    socklen_t opt_len = sizeof(*ttl_s);
    if (getsockopt(socket, IPPROTO_IP, IP_TTL, ttl_s, &opt_len) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_set_ip_multicast_ttl(bh_socket_t socket, uint8_t ttl_s)
{
    if (setsockopt(socket, IPPROTO_IP, IP_MULTICAST_TTL, &ttl_s, sizeof(ttl_s))
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_get_ip_multicast_ttl(bh_socket_t socket, uint8_t *ttl_s)
{
    socklen_t opt_len = sizeof(*ttl_s);
    if (getsockopt(socket, IPPROTO_IP, IP_MULTICAST_TTL, ttl_s, &opt_len)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int
os_socket_set_ipv6_only(bh_socket_t socket, bool is_enabled)
{
#ifdef IPPROTO_IPV6
    return os_socket_setbooloption(socket, IPPROTO_IPV6, IPV6_V6ONLY,
                                   is_enabled);
#else
    errno = EAFNOSUPPORT;
    return BHT_ERROR;
#endif
}

int
os_socket_get_ipv6_only(bh_socket_t socket, bool *is_enabled)
{
#ifdef IPPROTO_IPV6
    return os_socket_getbooloption(socket, IPPROTO_IPV6, IPV6_V6ONLY,
                                   is_enabled);
#else
    errno = EAFNOSUPPORT;
    return BHT_ERROR;
#endif
}

int
os_socket_set_broadcast(bh_socket_t socket, bool is_enabled)
{
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_BROADCAST,
                                   is_enabled);
}

int
os_socket_get_broadcast(bh_socket_t socket, bool *is_enabled)
{
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_BROADCAST,
                                   is_enabled);
}

int
os_socket_set_send_timeout(bh_socket_t socket, uint64 timeout_us)
{
    struct timeval tv;
    tv.tv_sec = timeout_us / 1000000UL;
    tv.tv_usec = timeout_us % 1000000UL;
    if (setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv)) != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
}

int
os_socket_get_send_timeout(bh_socket_t socket, uint64 *timeout_us)
{
    struct timeval tv;
    socklen_t tv_len = sizeof(tv);
    if (getsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &tv, &tv_len) != 0) {
        return BHT_ERROR;
    }
    *timeout_us = (tv.tv_sec * 1000000UL) + tv.tv_usec;
    return BHT_OK;
}

int
os_socket_set_recv_timeout(bh_socket_t socket, uint64 timeout_us)
{
    struct timeval tv;
    tv.tv_sec = timeout_us / 1000000UL;
    tv.tv_usec = timeout_us % 1000000UL;
    if (setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
}

int
os_socket_get_recv_timeout(bh_socket_t socket, uint64 *timeout_us)
{
    struct timeval tv;
    socklen_t tv_len = sizeof(tv);
    if (getsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, &tv_len) != 0) {
        return BHT_ERROR;
    }
    *timeout_us = (tv.tv_sec * 1000000UL) + tv.tv_usec;
    return BHT_OK;
}

int
os_socket_addr_local(bh_socket_t socket, bh_sockaddr_t *sockaddr)
{
    struct sockaddr_storage addr_storage = { 0 };
    socklen_t addr_len = sizeof(addr_storage);
    int ret;

    ret = getsockname(socket, (struct sockaddr *)&addr_storage, &addr_len);

    if (ret != BHT_OK) {
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr((struct sockaddr *)&addr_storage, sockaddr);
}

int
os_socket_addr_remote(bh_socket_t socket, bh_sockaddr_t *sockaddr)
{
    struct sockaddr_storage addr_storage = { 0 };
    socklen_t addr_len = sizeof(addr_storage);
    int ret;

    ret = getpeername(socket, (struct sockaddr *)&addr_storage, &addr_len);

    if (ret != BHT_OK) {
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr((struct sockaddr *)&addr_storage, sockaddr);
}
