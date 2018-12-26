/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the Flora License, Version 1.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://floralicense.org/license/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if defined(__ARM_NEON__)

#include "vdrawhelper.h"

extern "C" void
pixman_composite_src_n_8888_asm_neon (int32_t   w,
                                      int32_t   h,
                                      uint32_t *dst,
                                      int32_t   dst_stride,
                                      uint32_t  src);

extern "C" void
pixman_composite_over_n_8888_asm_neon(int32_t   w,
                                      int32_t   h,
                                      uint32_t *dst,
                                      int32_t   dst_stride,
                                      uint32_t  src);

void memfill32(uint32_t *dest, uint32_t value, int length)
{
    pixman_composite_src_n_8888_asm_neon(length,
                                         1,
                                         dest,
                                         length,
                                         value);
}

void
comp_func_solid_SourceOver_neon(uint32_t *dest, int length, uint32_t color,
                                uint32_t const_alpha)
{
    if (const_alpha != 255) color = BYTE_MUL(color, const_alpha);

    pixman_composite_over_n_8888_asm_neon(length,
                                          1,
                                          dest,
                                          length,
                                          color);
}
#endif
