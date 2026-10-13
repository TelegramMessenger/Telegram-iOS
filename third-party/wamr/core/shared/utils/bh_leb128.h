/*
 * Copyright (C) 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_LEB128_H
#define _BH_LEB128_H

#include "bh_platform.h"

typedef enum {
    BH_LEB_READ_SUCCESS,
    BH_LEB_READ_TOO_LONG,
    BH_LEB_READ_OVERFLOW,
    BH_LEB_READ_UNEXPECTED_END,
} bh_leb_read_status_t;

#ifdef __cplusplus
extern "C" {
#endif

bh_leb_read_status_t
bh_leb_read(const uint8 *buf, const uint8 *buf_end, uint32 maxbits, bool sign,
            uint64 *p_result, size_t *p_offset);

#ifdef __cplusplus
}
#endif

#endif