/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_FILE_H
#define _BH_FILE_H

#include "bh_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

char *
bh_read_file_to_buffer(const char *filename, uint32 *ret_size);

#ifdef __cplusplus
}
#endif

#endif /* end of _BH_FILE_H */
