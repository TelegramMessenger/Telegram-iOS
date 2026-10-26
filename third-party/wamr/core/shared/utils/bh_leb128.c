/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_leb128.h"

bh_leb_read_status_t
bh_leb_read(const uint8 *buf, const uint8 *buf_end, uint32 maxbits, bool sign,
            uint64 *p_result, size_t *p_offset)
{
    uint64 result = 0;
    uint32 shift = 0;
    uint32 offset = 0, bcnt = 0;
    uint64 byte;

    while (true) {
        /* uN or SN must not exceed ceil(N/7) bytes */
        if (bcnt + 1 > (maxbits + 6) / 7) {
            return BH_LEB_READ_TOO_LONG;
        }

        if ((uintptr_t)buf + offset + 1 < (uintptr_t)buf
            || (uintptr_t)buf + offset + 1 > (uintptr_t)buf_end) {
            return BH_LEB_READ_UNEXPECTED_END;
        }
        byte = buf[offset];
        offset += 1;
        result |= ((byte & 0x7f) << shift);
        shift += 7;
        bcnt += 1;
        if ((byte & 0x80) == 0) {
            break;
        }
    }

    if (!sign && maxbits == 32 && shift >= maxbits) {
        /* The top bits set represent values > 32 bits */
        if (((uint8)byte) & 0xf0)
            return BH_LEB_READ_OVERFLOW;
    }
    else if (sign && maxbits == 32) {
        if (shift < maxbits) {
            /* Sign extend, second-highest bit is the sign bit */
            if ((uint8)byte & 0x40)
                result |= (~((uint64)0)) << shift;
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = ((uint8)byte) & 0x8;
            int top_bits = ((uint8)byte) & 0xf0;
            if ((sign_bit_set && top_bits != 0x70)
                || (!sign_bit_set && top_bits != 0))
                return BH_LEB_READ_OVERFLOW;
        }
    }
    else if (sign && maxbits == 64) {
        if (shift < maxbits) {
            /* Sign extend, second-highest bit is the sign bit */
            if ((uint8)byte & 0x40)
                result |= (~((uint64)0)) << shift;
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = ((uint8)byte) & 0x1;
            int top_bits = ((uint8)byte) & 0xfe;

            if ((sign_bit_set && top_bits != 0x7e)
                || (!sign_bit_set && top_bits != 0))
                return BH_LEB_READ_OVERFLOW;
        }
    }

    *p_offset = offset;
    *p_result = result;
    return BH_LEB_READ_SUCCESS;
}