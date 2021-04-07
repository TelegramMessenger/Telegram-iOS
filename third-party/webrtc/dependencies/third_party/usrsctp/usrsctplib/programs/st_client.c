/*
 * Copyright (C) 2011-2013 Michael Tuexen
 * Copyright (C) 2011-2015 Colin Caughie
 * Copyright (C) 2011-2019 Felix Weinrank
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.	IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Usage: st_client local_addr local_port remote_addr remote_port remote_sctp_port
 */

#ifdef _WIN32
#define _CRT_SECURE_NO_WARNINGS
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <sys/types.h>
#ifndef _WIN32
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <pthread.h>
#include <unistd.h>
#else
#include <winsock2.h>
#include <ws2tcpip.h>
#endif
#include <usrsctp.h>
#include "programs_helper.h"

#define MAX_PACKET_SIZE (1<<16)
#define BUFFER_SIZE 80
#define DISCARD_PPID 39
#define HTTP_PPID 63

#define TIMER_INTERVAL_MSECS 10

static int connecting = 0;
static int finish = 0;

static unsigned int
get_tick_count(void)
{
#ifdef _WIN32
	return GetTickCount();
#else
	struct timeval tv;
	unsigned int milliseconds;

	gettimeofday(&tv, NULL); /* get current time */
	milliseconds = tv.tv_sec*1000LL + tv.tv_usec/1000; /* calculate milliseconds */
	return (milliseconds);
#endif
}

static void
handle_events(int sock, struct socket* s, void* sconn_addr)
{
	char *dump_buf;
	ssize_t length;
	char buf[MAX_PACKET_SIZE];

	fd_set rfds;
	struct timeval tv;

	unsigned next_fire_time = get_tick_count();
	unsigned last_fire_time = next_fire_time;
	unsigned now = get_tick_count();
	int wait_time;

	while (!finish) {
		if ((int) (now - next_fire_time) > 0) {
			usrsctp_handle_timers(now - last_fire_time);
			last_fire_time = now;
			next_fire_time = now + TIMER_INTERVAL_MSECS;
		}

		wait_time = next_fire_time - now;
		tv.tv_sec = wait_time / 1000;
		tv.tv_usec = (wait_time % 1000) * 1000;

		FD_ZERO(&rfds);
		FD_SET(sock, &rfds);

		select(sock + 1, &rfds, NULL, NULL, &tv);

		if (FD_ISSET(sock, &rfds)) {
			length = recv(sock, buf, MAX_PACKET_SIZE, 0);

			if (length > 0) {
				if ((dump_buf = usrsctp_dumppacket(buf, (size_t)length, SCTP_DUMP_INBOUND)) != NULL) {
					fprintf(stderr, "%s", dump_buf);
					usrsctp_freedumpbuffer(dump_buf);
				}
				usrsctp_conninput(sconn_addr, buf, (size_t)length, 0);
			}
		}
	}
}

static void
on_connect(struct socket* s)
{
	struct sctp_sndinfo sndinfo;
	char buffer[BUFFER_SIZE];
	int bufferlen;

	/* memset(buffer, 'A', BUFFER_SIZE); */
	/* bufferlen = BUFFER_SIZE; */
	bufferlen = snprintf(buffer, BUFFER_SIZE, "GET / HTTP/1.0\r\nUser-agent: libusrsctp\r\nConnection: close\r\n\r\n");
	sndinfo.snd_sid = 0;
	sndinfo.snd_flags = 0;
	sndinfo.snd_ppid = htonl(DISCARD_PPID);
	sndinfo.snd_context = 0;
	sndinfo.snd_assoc_id = 0;
	if (usrsctp_sendv(s, buffer, bufferlen, NULL, 0, (void *)&sndinfo,
	                  (socklen_t)sizeof(struct sctp_sndinfo), SCTP_SENDV_SNDINFO, 0) < 0) {
		perror("usrsctp_sendv");
	}
}

static void
on_socket_readable(struct socket* s) {
	char buffer[BUFFER_SIZE];
	union sctp_sockstore addr;
	socklen_t fromlen = sizeof(addr);
	struct sctp_rcvinfo rcv_info;
	socklen_t infolen = sizeof(rcv_info);
	unsigned int infotype = 0;
	int flags = 0;
	ssize_t retval;

	/* Keep reading until there is no more data */
	for (;;) {
		retval = usrsctp_recvv(s, buffer, sizeof(buffer), (struct sockaddr*) &addr,
		                       &fromlen, &rcv_info, &infolen, &infotype, &flags);

		if (retval < 0) {
			if (errno != EWOULDBLOCK) {
				perror("usrsctp_recvv");
				finish = 1;
			}
			return;
		} else if (retval == 0) {
			printf("socket was disconnected\n");
			finish = 1;
			return;
		}

		if (flags & MSG_NOTIFICATION) {
			printf("Notification of length %d received.\n", (int)retval);
		} else {
			printf("Msg of length %d received via %p:%u on stream %d with SSN %u and TSN %u, PPID %d, context %u.\n",
			       (int)retval,
			       addr.sconn.sconn_addr,
			       ntohs(addr.sconn.sconn_port),
			       rcv_info.rcv_sid,
			       rcv_info.rcv_ssn,
			       rcv_info.rcv_tsn,
			       ntohl(rcv_info.rcv_ppid),
			       rcv_info.rcv_context);
		}
	}
}

static void
handle_upcall(struct socket *s, void *arg, int flags)
{
	int events = usrsctp_get_events(s);

	if (connecting) {
		if (events & SCTP_EVENT_ERROR) {
			connecting = 0;
			finish = 1;
		} else if (events & SCTP_EVENT_WRITE) {
			connecting = 0;
			on_connect(s);
		}

		return;
	}

	if (events & SCTP_EVENT_READ) {
		on_socket_readable(s);
	}
}

static int
conn_output(void *addr, void *buf, size_t length, uint8_t tos, uint8_t set_df)
{
	char *dump_buf;
#ifdef _WIN32
	SOCKET *fdp;
#else
	int *fdp;
#endif

#ifdef _WIN32
	fdp = (SOCKET *)addr;
#else
	fdp = (int *)addr;
#endif
	if ((dump_buf = usrsctp_dumppacket(buf, length, SCTP_DUMP_OUTBOUND)) != NULL) {
		fprintf(stderr, "%s", dump_buf);
		usrsctp_freedumpbuffer(dump_buf);
	}
#ifdef _WIN32
	if (send(*fdp, buf, (int)length, 0) == SOCKET_ERROR) {
		return (WSAGetLastError());
#else
	if (send(*fdp, buf, length, 0) < 0) {
		return (errno);
#endif
	} else {
		return (0);
	}
}

/* Usage: st_client local_addr local_port remote_addr remote_port remote_sctp_port */
int
main(int argc, char *argv[])
{
	struct sockaddr_in sin;
	struct sockaddr_conn sconn;
#ifdef _WIN32
	SOCKET fd;
#else
	int fd;
#endif
	struct socket *s;
	int retval;
#ifdef _WIN32
	WSADATA wsaData;
#endif
	const int on = 1;

	if (argc < 6) {
		printf("Usage: st_client local_addr local_port remote_addr remote_port remote_sctp_port\n");
		return (-1);
	}

#ifdef _WIN32
	if (WSAStartup(MAKEWORD(2,2), &wsaData) != 0) {
		printf("WSAStartup failed\n");
		return (-1);
	}
#endif
	usrsctp_init_nothreads(0, conn_output, debug_printf_stack);
	/* set up a connected UDP socket */
#ifdef _WIN32
	if ((fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == INVALID_SOCKET) {
		printf("socket() failed with error: %ld\n", WSAGetLastError());
		return (-1);
	}
#else
	if ((fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0) {
		perror("socket");
		return (-1);
	}
#endif
	memset(&sin, 0, sizeof(struct sockaddr_in));
	sin.sin_family = AF_INET;
#ifdef HAVE_SIN_LEN
	sin.sin_len = sizeof(struct sockaddr_in);
#endif
	sin.sin_port = htons(atoi(argv[2]));
	if (!inet_pton(AF_INET, argv[1], &sin.sin_addr.s_addr)){
		printf("error: invalid address\n");
		return (-1);
	}
#ifdef _WIN32
	if (bind(fd, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) == SOCKET_ERROR) {
		printf("bind() failed with error: %ld\n", WSAGetLastError());
		return (-1);
	}
#else
	if (bind(fd, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) < 0) {
		perror("bind");
		return (-1);
	}
#endif
	memset(&sin, 0, sizeof(struct sockaddr_in));
	sin.sin_family = AF_INET;
#ifdef HAVE_SIN_LEN
	sin.sin_len = sizeof(struct sockaddr_in);
#endif
	sin.sin_port = htons(atoi(argv[4]));
	if (!inet_pton(AF_INET, argv[3], &sin.sin_addr.s_addr)){
		printf("error: invalid address\n");
		return (-1);
	}
#ifdef _WIN32
	if (connect(fd, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) == SOCKET_ERROR) {
		printf("connect() failed with error: %ld\n", WSAGetLastError());
		return (-1);
	}
#else
	if (connect(fd, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) < 0) {
		perror("connect");
		return (-1);
	}
#endif
#ifdef SCTP_DEBUG
	usrsctp_sysctl_set_sctp_debug_on(SCTP_DEBUG_NONE);
#endif
	usrsctp_sysctl_set_sctp_ecn_enable(0);
	usrsctp_register_address((void *)&fd);

	if ((s = usrsctp_socket(AF_CONN, SOCK_STREAM, IPPROTO_SCTP, NULL, NULL, 0, NULL)) == NULL) {
		perror("usrsctp_socket");
		return (-1);
	}

	usrsctp_setsockopt(s, IPPROTO_SCTP, SCTP_RECVRCVINFO, &on, sizeof(int));
	usrsctp_set_non_blocking(s, 1);
	usrsctp_set_upcall(s, handle_upcall, NULL);

	memset(&sconn, 0, sizeof(struct sockaddr_conn));
	sconn.sconn_family = AF_CONN;
#ifdef HAVE_SCONN_LEN
	sconn.sconn_len = sizeof(struct sockaddr_conn);
#endif
	sconn.sconn_port = htons(0);
	sconn.sconn_addr = NULL;
	if (usrsctp_bind(s, (struct sockaddr *)&sconn, sizeof(struct sockaddr_conn)) < 0) {
		perror("usrsctp_bind");
		return (-1);
	}

	memset(&sconn, 0, sizeof(struct sockaddr_conn));
	sconn.sconn_family = AF_CONN;
#ifdef HAVE_SCONN_LEN
	sconn.sconn_len = sizeof(struct sockaddr_conn);
#endif
	sconn.sconn_port = htons(atoi(argv[5]));
	sconn.sconn_addr = &fd;

	retval = usrsctp_connect(s, (struct sockaddr *)&sconn, sizeof(struct sockaddr_conn));

	if (retval < 0 && errno != EWOULDBLOCK && errno != EINPROGRESS) {
		perror("usrsctp_connect");
		return (-1);
	}

	connecting = 1;

	handle_events(fd, s, sconn.sconn_addr);

	return (0);
}
