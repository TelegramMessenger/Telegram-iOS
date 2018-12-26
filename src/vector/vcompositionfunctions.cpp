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

#include "vdrawhelper.h"

/*
  result = s
  dest = s * ca + d * cia
*/
void comp_func_solid_Source(uint32_t *dest, int length, uint32_t color,
                            uint32_t const_alpha)
{
    int ialpha, i;

    if (const_alpha == 255) {
        memfill32(dest, color, length);
    } else {
        ialpha = 255 - const_alpha;
        color = BYTE_MUL(color, const_alpha);
        for (i = 0; i < length; ++i)
            dest[i] = color + BYTE_MUL(dest[i], ialpha);
    }
}

/*
  r = s + d * sia
  dest = r * ca + d * cia
       =  (s + d * sia) * ca + d * cia
       = s * ca + d * (sia * ca + cia)
       = s * ca + d * (1 - sa*ca)
       = s' + d ( 1 - s'a)
*/
void comp_func_solid_SourceOver(uint32_t *dest, int length, uint32_t color,
                                uint32_t const_alpha)
{
    int ialpha, i;

    if (const_alpha != 255) color = BYTE_MUL(color, const_alpha);
    ialpha = 255 - vAlpha(color);
    for (i = 0; i < length; ++i) dest[i] = color + BYTE_MUL(dest[i], ialpha);
}

void comp_func_Source(uint32_t *dest, const uint32_t *src, int length,
                      uint32_t const_alpha)
{
    if (const_alpha == 255) {
        memcpy(dest, src, size_t(length) * sizeof(uint));
    } else {
        uint ialpha = 255 - const_alpha;
        for (int i = 0; i < length; ++i) {
            dest[i] =
                INTERPOLATE_PIXEL_255(src[i], const_alpha, dest[i], ialpha);
        }
    }
}

/* s' = s * ca
 * d' = s' + d (1 - s'a)
 */
void comp_func_SourceOver(uint32_t *dest, const uint32_t *src, int length,
                          uint32_t const_alpha)
{
    uint s, sia;

    if (const_alpha == 255) {
        for (int i = 0; i < length; ++i) {
            s = src[i];
            if (s >= 0xff000000)
                dest[i] = s;
            else if (s != 0) {
                sia = vAlpha(~s);
                dest[i] = s + BYTE_MUL(dest[i], sia);
            }
        }
    } else {
        /* source' = source * const_alpha
         * dest = source' + dest ( 1- source'a)
         */
        for (int i = 0; i < length; ++i) {
            uint s = BYTE_MUL(src[i], const_alpha);
            sia = vAlpha(~s);
            dest[i] = s + BYTE_MUL(dest[i], sia);
        }
    }
}

CompositionFunctionSolid COMP_functionForModeSolid_C[] = {
    comp_func_solid_Source, comp_func_solid_SourceOver};

CompositionFunction COMP_functionForMode_C[] = {comp_func_Source,
                                                comp_func_SourceOver};

void vInitBlendFunctions() {}
