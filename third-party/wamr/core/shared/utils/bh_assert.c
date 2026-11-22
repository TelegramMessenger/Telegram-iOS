/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_assert.h"

void
bh_assert_internal(int64 v, const char *file_name, int line_number,
                   const char *expr_string)
{
    if (v)
        return;

    if (!file_name)
        file_name = "NULL FILENAME";

    if (!expr_string)
        expr_string = "NULL EXPR_STRING";

    LOG_ERROR("\nASSERTION FAILED: %s, at file %s, line %d\n", expr_string,
              file_name, line_number);

    abort();
}
