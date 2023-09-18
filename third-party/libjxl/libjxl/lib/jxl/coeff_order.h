// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_COEFF_ORDER_H_
#define LIB_JXL_COEFF_ORDER_H_

#include <stddef.h>
#include <stdint.h>

#include "lib/jxl/ac_strategy.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/coeff_order_fwd.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dct_util.h"

namespace jxl {

class BitReader;

// Those offsets get multiplied by kDCTBlockSize.
static constexpr size_t kCoeffOrderOffset[] = {
    0,    1,    2,    3,    4,    5,    6,    10,   14,   18,
    34,   50,   66,   68,   70,   72,   76,   80,   84,   92,
    100,  108,  172,  236,  300,  332,  364,  396,  652,  908,
    1164, 1292, 1420, 1548, 2572, 3596, 4620, 5132, 5644, 6156,
};
static_assert(3 * kNumOrders + 1 ==
                  sizeof(kCoeffOrderOffset) / sizeof(*kCoeffOrderOffset),
              "Update this array when adding or removing order types.");

static constexpr size_t CoeffOrderOffset(size_t order, size_t c) {
  return kCoeffOrderOffset[3 * order + c] * kDCTBlockSize;
}

static constexpr size_t kCoeffOrderMaxSize =
    kCoeffOrderOffset[3 * kNumOrders] * kDCTBlockSize;

// Mapping from AC strategy to order bucket. Strategies with different natural
// orders must have different buckets.
constexpr uint8_t kStrategyOrder[] = {
    0, 1, 1, 1, 2, 3, 4, 4, 5,  5,  6,  6,  1,  1,
    1, 1, 1, 1, 7, 8, 8, 9, 10, 10, 11, 12, 12,
};

static_assert(AcStrategy::kNumValidStrategies ==
                  sizeof(kStrategyOrder) / sizeof(*kStrategyOrder),
              "Update this array when adding or removing AC strategies.");

constexpr uint32_t kPermutationContexts = 8;

uint32_t CoeffOrderContext(uint32_t val);

Status DecodeCoeffOrders(uint16_t used_orders, uint32_t used_acs,
                         coeff_order_t* order, BitReader* br);

Status DecodePermutation(size_t skip, size_t size, coeff_order_t* order,
                         BitReader* br);

}  // namespace jxl

#endif  // LIB_JXL_COEFF_ORDER_H_
