#include "platform_log.h"
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>

#define LOG_VPRINTF(priority)	printf("(" priority ") %s: ", tag); \
								va_list arg_ptr; \
								va_start(arg_ptr, fmt); \
								vprintf(fmt, arg_ptr); \
								va_end(arg_ptr); \
								printf("\n");

void _debug_log_v(const char *tag, const char *fmt, ...) {
	LOG_VPRINTF("VERBOSE");
}

void _debug_log_d(const char *tag, const char *fmt, ...) {
	LOG_VPRINTF("DEBUG");
}

void _debug_log_w(const char *tag, const char *fmt, ...) {
	LOG_VPRINTF("WARN");
}

void _debug_log_e(const char *tag, const char *fmt, ...) {
	LOG_VPRINTF("ERROR");
}
