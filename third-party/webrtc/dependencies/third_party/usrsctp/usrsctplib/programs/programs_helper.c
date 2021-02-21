
#ifdef _WIN32
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <usrsctp.h>

#ifndef _WIN32
#include <sys/time.h>
#include <arpa/inet.h>
#else
#include <sys/types.h>
#include <sys/timeb.h>
#include <io.h>
#endif

#include "programs_helper.h"

#ifdef _WIN32
static void
gettimeofday(struct timeval *tv, void *ignore)
{
	struct timeb tb;

	ftime(&tb);
	tv->tv_sec = (long)tb.time;
	tv->tv_usec = (long)(tb.millitm) * 1000L;
}
#endif

void
debug_printf_runtime(void) {
	static struct timeval time_main;
	struct timeval time_now;
	struct timeval time_delta;

	if (time_main.tv_sec == 0  && time_main.tv_usec == 0) {
		gettimeofday(&time_main, NULL);
	}

	gettimeofday(&time_now, NULL);
	timersub(&time_now, &time_main, &time_delta);

	fprintf(stderr, "[%u.%03u] ", (unsigned int) time_delta.tv_sec, (unsigned int) time_delta.tv_usec / 1000);
}


void
debug_printf_stack(const char *format, ...)
{
	va_list ap;

	va_start(ap, format);
	vprintf(format, ap);
	va_end(ap);
}

static void
handle_association_change_event(struct sctp_assoc_change *sac)
{
	unsigned int i, n;

	fprintf(stderr, "Association change ");
	switch (sac->sac_state) {
	case SCTP_COMM_UP:
		fprintf(stderr, "SCTP_COMM_UP");
		break;
	case SCTP_COMM_LOST:
		fprintf(stderr, "SCTP_COMM_LOST");
		break;
	case SCTP_RESTART:
		fprintf(stderr, "SCTP_RESTART");
		break;
	case SCTP_SHUTDOWN_COMP:
		fprintf(stderr, "SCTP_SHUTDOWN_COMP");
		break;
	case SCTP_CANT_STR_ASSOC:
		fprintf(stderr, "SCTP_CANT_STR_ASSOC");
		break;
	default:
		fprintf(stderr, "UNKNOWN");
		break;
	}
	fprintf(stderr, ", streams (in/out) = (%u/%u)",
	       sac->sac_inbound_streams, sac->sac_outbound_streams);
	n = sac->sac_length - sizeof(struct sctp_assoc_change);
	if (((sac->sac_state == SCTP_COMM_UP) ||
	     (sac->sac_state == SCTP_RESTART)) && (n > 0)) {
		fprintf(stderr, ", supports");
		for (i = 0; i < n; i++) {
			switch (sac->sac_info[i]) {
			case SCTP_ASSOC_SUPPORTS_PR:
				fprintf(stderr, " PR");
				break;
			case SCTP_ASSOC_SUPPORTS_AUTH:
				fprintf(stderr, " AUTH");
				break;
			case SCTP_ASSOC_SUPPORTS_ASCONF:
				fprintf(stderr, " ASCONF");
				break;
			case SCTP_ASSOC_SUPPORTS_MULTIBUF:
				fprintf(stderr, " MULTIBUF");
				break;
			case SCTP_ASSOC_SUPPORTS_RE_CONFIG:
				fprintf(stderr, " RE-CONFIG");
				break;
			default:
				fprintf(stderr, " UNKNOWN(0x%02x)", sac->sac_info[i]);
				break;
			}
		}
	} else if (((sac->sac_state == SCTP_COMM_LOST) ||
	            (sac->sac_state == SCTP_CANT_STR_ASSOC)) && (n > 0)) {
		fprintf(stderr, ", ABORT =");
		for (i = 0; i < n; i++) {
			fprintf(stderr, " 0x%02x", sac->sac_info[i]);
		}
	}
	fprintf(stderr, ".\n");
	return;
}

static void
handle_peer_address_change_event(struct sctp_paddr_change *spc)
{
	char addr_buf[INET6_ADDRSTRLEN];
	const char *addr;
	struct sockaddr_in *sin;
	struct sockaddr_in6 *sin6;
	struct sockaddr_conn *sconn;

	switch (spc->spc_aaddr.ss_family) {
	case AF_INET:
		sin = (struct sockaddr_in *)&spc->spc_aaddr;
		addr = inet_ntop(AF_INET, &sin->sin_addr, addr_buf, INET_ADDRSTRLEN);
		break;
	case AF_INET6:
		sin6 = (struct sockaddr_in6 *)&spc->spc_aaddr;
		addr = inet_ntop(AF_INET6, &sin6->sin6_addr, addr_buf, INET6_ADDRSTRLEN);
		break;
	case AF_CONN:
		sconn = (struct sockaddr_conn *)&spc->spc_aaddr;
#ifdef _WIN32
		_snprintf(addr_buf, INET6_ADDRSTRLEN, "%p", sconn->sconn_addr);
#else
		snprintf(addr_buf, INET6_ADDRSTRLEN, "%p", sconn->sconn_addr);
#endif
		addr = addr_buf;
		break;
	default:
#ifdef _WIN32
		_snprintf(addr_buf, INET6_ADDRSTRLEN, "Unknown family %d", spc->spc_aaddr.ss_family);
#else
		snprintf(addr_buf, INET6_ADDRSTRLEN, "Unknown family %d", spc->spc_aaddr.ss_family);
#endif
		addr = addr_buf;
		break;
	}
	fprintf(stderr, "Peer address %s is now ", addr);
	switch (spc->spc_state) {
	case SCTP_ADDR_AVAILABLE:
		fprintf(stderr, "SCTP_ADDR_AVAILABLE");
		break;
	case SCTP_ADDR_UNREACHABLE:
		fprintf(stderr, "SCTP_ADDR_UNREACHABLE");
		break;
	case SCTP_ADDR_REMOVED:
		fprintf(stderr, "SCTP_ADDR_REMOVED");
		break;
	case SCTP_ADDR_ADDED:
		fprintf(stderr, "SCTP_ADDR_ADDED");
		break;
	case SCTP_ADDR_MADE_PRIM:
		fprintf(stderr, "SCTP_ADDR_MADE_PRIM");
		break;
	case SCTP_ADDR_CONFIRMED:
		fprintf(stderr, "SCTP_ADDR_CONFIRMED");
		break;
	default:
		fprintf(stderr, "UNKNOWN");
		break;
	}
	fprintf(stderr, " (error = 0x%08x).\n", spc->spc_error);
	return;
}

static void
handle_send_failed_event(struct sctp_send_failed_event *ssfe)
{
	size_t i, n;

	if (ssfe->ssfe_flags & SCTP_DATA_UNSENT) {
		fprintf(stderr, "Unsent ");
	}
	if (ssfe->ssfe_flags & SCTP_DATA_SENT) {
		fprintf(stderr, "Sent ");
	}
	if (ssfe->ssfe_flags & ~(SCTP_DATA_SENT | SCTP_DATA_UNSENT)) {
		fprintf(stderr, "(flags = %x) ", ssfe->ssfe_flags);
	}
	fprintf(stderr, "message with PPID = %u, SID = %u, flags: 0x%04x due to error = 0x%08x",
	       ntohl(ssfe->ssfe_info.snd_ppid), ssfe->ssfe_info.snd_sid,
	       ssfe->ssfe_info.snd_flags, ssfe->ssfe_error);
	n = ssfe->ssfe_length - sizeof(struct sctp_send_failed_event);
	for (i = 0; i < n; i++) {
		fprintf(stderr, " 0x%02x", ssfe->ssfe_data[i]);
	}
	fprintf(stderr, ".\n");
	return;
}

static void
handle_adaptation_indication(struct sctp_adaptation_event *sai)
{
	fprintf(stderr, "Adaptation indication: %x.\n", sai-> sai_adaptation_ind);
	return;
}

static void
handle_shutdown_event(struct sctp_shutdown_event *sse)
{
	fprintf(stderr, "Shutdown event.\n");
	/* XXX: notify all channels. */
	return;
}

static void
handle_stream_reset_event(struct sctp_stream_reset_event *strrst)
{
	uint32_t n, i;

	n = (strrst->strreset_length - sizeof(struct sctp_stream_reset_event)) / sizeof(uint16_t);
	fprintf(stderr, "Stream reset event: flags = %x, ", strrst->strreset_flags);
	if (strrst->strreset_flags & SCTP_STREAM_RESET_INCOMING_SSN) {
		if (strrst->strreset_flags & SCTP_STREAM_RESET_OUTGOING_SSN) {
			fprintf(stderr, "incoming/");
		}
		fprintf(stderr, "incoming ");
	}
	if (strrst->strreset_flags & SCTP_STREAM_RESET_OUTGOING_SSN) {
		fprintf(stderr, "outgoing ");
	}
	fprintf(stderr, "stream ids = ");
	for (i = 0; i < n; i++) {
		if (i > 0) {
			fprintf(stderr, ", ");
		}
		fprintf(stderr, "%d", strrst->strreset_stream_list[i]);
	}
	fprintf(stderr, ".\n");
	return;
}

static void
handle_stream_change_event(struct sctp_stream_change_event *strchg)
{
	fprintf(stderr, "Stream change event: streams (in/out) = (%u/%u), flags = %x.\n",
	       strchg->strchange_instrms, strchg->strchange_outstrms, strchg->strchange_flags);
	return;
}

static void
handle_remote_error_event(struct sctp_remote_error *sre)
{
	size_t i, n;

	n = sre->sre_length - sizeof(struct sctp_remote_error);
	fprintf(stderr, "Remote Error (error = 0x%04x): ", sre->sre_error);
	for (i = 0; i < n; i++) {
		fprintf(stderr, " 0x%02x", sre-> sre_data[i]);
	}
	fprintf(stderr, ".\n");
	return;
}

void
handle_notification(union sctp_notification *notif, size_t n)
{
	if (notif->sn_header.sn_length != (uint32_t)n) {
		return;
	}

	fprintf(stderr, "handle_notification : ");

	switch (notif->sn_header.sn_type) {
	case SCTP_ASSOC_CHANGE:
		fprintf(stderr, "SCTP_ASSOC_CHANGE\n");
		handle_association_change_event(&(notif->sn_assoc_change));
		break;
	case SCTP_PEER_ADDR_CHANGE:
		fprintf(stderr, "SCTP_PEER_ADDR_CHANGE\n");
		handle_peer_address_change_event(&(notif->sn_paddr_change));
		break;
	case SCTP_REMOTE_ERROR:
		fprintf(stderr, "SCTP_REMOTE_ERROR\n");
		handle_remote_error_event(&(notif->sn_remote_error));
		break;
	case SCTP_SHUTDOWN_EVENT:
		fprintf(stderr, "SCTP_SHUTDOWN_EVENT\n");
		handle_shutdown_event(&(notif->sn_shutdown_event));
		break;
	case SCTP_ADAPTATION_INDICATION:
		fprintf(stderr, "SCTP_ADAPTATION_INDICATION\n");
		handle_adaptation_indication(&(notif->sn_adaptation_event));
		break;
	case SCTP_PARTIAL_DELIVERY_EVENT:
		fprintf(stderr, "SCTP_PARTIAL_DELIVERY_EVENT\n");
		break;
	case SCTP_AUTHENTICATION_EVENT:
		fprintf(stderr, "SCTP_AUTHENTICATION_EVENT\n");
		break;
	case SCTP_SENDER_DRY_EVENT:
		fprintf(stderr, "SCTP_SENDER_DRY_EVENT\n");
		break;
	case SCTP_NOTIFICATIONS_STOPPED_EVENT:
		fprintf(stderr, "SCTP_NOTIFICATIONS_STOPPED_EVENT\n");
		break;
	case SCTP_SEND_FAILED_EVENT:
		fprintf(stderr, "SCTP_SEND_FAILED_EVENT\n");
		handle_send_failed_event(&(notif->sn_send_failed_event));
		break;
	case SCTP_STREAM_RESET_EVENT:
		fprintf(stderr, "SCTP_STREAM_RESET_EVENT\n");
		handle_stream_reset_event(&(notif->sn_strreset_event));
		break;
	case SCTP_ASSOC_RESET_EVENT:
		fprintf(stderr, "SCTP_ASSOC_RESET_EVENT\n");
		break;
	case SCTP_STREAM_CHANGE_EVENT:
		fprintf(stderr, "SCTP_STREAM_CHANGE_EVENT\n");
		handle_stream_change_event(&(notif->sn_strchange_event));
		break;
	default:
		break;
	}
}
