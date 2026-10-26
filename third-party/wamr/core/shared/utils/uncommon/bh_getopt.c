/*
 * Copyright (C) 2020 Ant Financial Services Group. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef __GNUC__

#include "bh_getopt.h"
#include <stdio.h>
#include <string.h>

char *optarg = NULL;
int optind = 1;

int
getopt(int argc, char *const argv[], const char *optstring)
{
    static int sp = 1;
    int opt;
    char *p;

    if (sp == 1) {
        if ((optind >= argc) || (argv[optind][0] != '-')
            || (argv[optind][1] == 0)) {
            return -1;
        }
        else if (!strcmp(argv[optind], "--")) {
            optind++;
            return -1;
        }
    }

    opt = argv[optind][sp];
    p = strchr(optstring, opt);
    if (opt == ':' || p == NULL) {
        printf("illegal option : '-%c'\n", opt);
        if (argv[optind][++sp] == '\0') {
            optind++;
            sp = 1;
        }
        return ('?');
    }
    if (p[1] == ':') {
        if (argv[optind][sp + 1] != '\0')
            optarg = &argv[optind++][sp + 1];
        else if (++optind >= argc) {
            printf("option '-%c' requires an argument :\n", opt);
            sp = 1;
            return ('?');
        }
        else {
            optarg = argv[optind++];
        }
        sp = 1;
    }
    else {
        if (argv[optind][++sp] == '\0') {
            sp = 1;
            optind++;
        }
        optarg = NULL;
    }
    return (opt);
}
#endif
