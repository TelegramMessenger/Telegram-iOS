/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the LGPL License, Version 2.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.gnu.org/licenses/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef VBITMAP_H
#define VBITMAP_H

#include "vrect.h"

V_BEGIN_NAMESPACE

struct VBitmapData;
typedef void (*VBitmapCleanupFunction)(void *);
class VBitmap {
public:
    enum class Format { Invalid, Alpha8, ARGB32, ARGB32_Premultiplied, Last };
    ~VBitmap();
    VBitmap();
    VBitmap(const VBitmap &other);
    VBitmap(VBitmap &&other);
    VBitmap &operator=(const VBitmap &);
    VBitmap &operator=(VBitmap &&other);

    VBitmap(int w, int h, VBitmap::Format format);
    VBitmap(uchar *data, int w, int h, int bytesPerLine, VBitmap::Format format,
            VBitmapCleanupFunction f = nullptr, void *cleanupInfo = nullptr);

    VBitmap copy(const VRect &rect = VRect()) const;
    void    fill(uint pixel);

    int             width() const;
    int             height() const;
    uchar *         bits();
    const uchar *   bits() const;
    uchar *         scanLine(int);
    const uchar *   scanLine(int) const;
    int             stride() const;
    bool            isNull() const;
    VBitmap::Format format() const;

private:
    void         detach();
    void         cleanUp(VBitmapData *x);
    VBitmapData *d{nullptr};
};

V_END_NAMESPACE

#endif  // VBITMAP_H
