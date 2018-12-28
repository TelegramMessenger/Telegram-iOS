/* 
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
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
