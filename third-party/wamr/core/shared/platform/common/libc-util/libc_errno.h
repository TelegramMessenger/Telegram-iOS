/*
 * Copyright (C) 2023 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef WASI_ERRNO_H
#define WASI_ERRNO_H

#include "platform_wasi_types.h"

// Converts an errno error code to a WASI error code.
__wasi_errno_t
convert_errno(int error);

#endif /* end of WASI_ERRNO_H */