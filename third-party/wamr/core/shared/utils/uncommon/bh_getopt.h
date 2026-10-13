/*
 * Copyright (C) 2020 Ant Financial Services Group. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifdef __GNUC__
#include <getopt.h>
#endif
#ifndef __GNUC__
#ifndef GETOPT_H__
#define GETOPT_H__

#ifdef __cplusplus
extern "C" {
#endif

extern char *optarg;
extern int optind;

int
getopt(int argc, char *const argv[], const char *optstring);

#ifdef __cplusplus
}
#endif

#endif /* end of GETOPT_H__ */
#endif /* end of __GNUC__ */
