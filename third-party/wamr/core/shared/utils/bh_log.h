/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/**
 * @file   bh_log.h
 * @date   Tue Nov  8 18:19:10 2011
 *
 * @brief This log system supports wrapping multiple outputs into one
 * log message.  This is useful for outputting variable-length logs
 * without additional memory overhead (the buffer for concatenating
 * the message), e.g. exception stack trace, which cannot be printed
 * by a single log calling without the help of an additional buffer.
 * Avoiding additional memory buffer is useful for resource-constraint
 * systems.  It can minimize the impact of log system on applications
 * and logs can be printed even when no enough memory is available.
 * Functions with prefix "_" are private functions.  Only macros that
 * are not start with "_" are exposed and can be used.
 */

#ifndef _BH_LOG_H
#define _BH_LOG_H

#include "bh_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    BH_LOG_LEVEL_FATAL = 0,
    BH_LOG_LEVEL_ERROR = 1,
    BH_LOG_LEVEL_WARNING = 2,
    BH_LOG_LEVEL_DEBUG = 3,
    BH_LOG_LEVEL_VERBOSE = 4
} LogLevel;

void
bh_log_set_verbose_level(uint32 level);

#ifndef BH_LOG
void
bh_log(LogLevel log_level, const char *file, int line, const char *fmt, ...);
#else
void
BH_LOG(uint32 log_level, const char *file, int line, const char *fmt, ...);
#define bh_log BH_LOG
#endif

#ifdef BH_PLATFORM_NUTTX

#undef LOG_FATAL
#undef LOG_ERROR
#undef LOG_WARNING
#undef LOG_VERBOSE
#undef LOG_DEBUG

#endif

#if BH_DEBUG != 0
#define LOG_FATAL(...) \
    bh_log(BH_LOG_LEVEL_FATAL, __FILE__, __LINE__, __VA_ARGS__)
#else
#define LOG_FATAL(...) \
    bh_log(BH_LOG_LEVEL_FATAL, __FUNCTION__, __LINE__, __VA_ARGS__)
#endif

#define LOG_ERROR(...) bh_log(BH_LOG_LEVEL_ERROR, NULL, 0, __VA_ARGS__)
#define LOG_WARNING(...) bh_log(BH_LOG_LEVEL_WARNING, NULL, 0, __VA_ARGS__)
#define LOG_VERBOSE(...) bh_log(BH_LOG_LEVEL_VERBOSE, NULL, 0, __VA_ARGS__)

#if BH_DEBUG != 0
#define LOG_DEBUG(...) \
    bh_log(BH_LOG_LEVEL_DEBUG, __FILE__, __LINE__, __VA_ARGS__)
#else
#define LOG_DEBUG(...) (void)0
#endif

void
bh_print_time(const char *prompt);

void
bh_print_proc_mem(const char *prompt);

void
bh_log_proc_mem(const char *function, uint32 line);

#define LOG_PROC_MEM(...) bh_log_proc_mem(__FUNCTION__, __LINE__)

#ifdef __cplusplus
}
#endif

#endif /* _BH_LOG_H */
