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
#include <memory>

V_BEGIN_NAMESPACE

class VBitmap {
public:
    enum class Format: uchar {
        Invalid,
        Alpha8,
        ARGB32,
        ARGB32_Premultiplied
    };

    VBitmap() = default;
    VBitmap(size_t w, size_t h, VBitmap::Format format);
    VBitmap(uchar *data, size_t w, size_t h, size_t bytesPerLine, VBitmap::Format format);

    void reset(size_t w, size_t h, VBitmap::Format format=Format::ARGB32_Premultiplied);
    size_t          stride() const;
    size_t          width() const;
    size_t          height() const;
    size_t          depth() const;
    VBitmap::Format format() const;
    bool            valid() const;
    uchar *         data();
    uchar *         data() const;
    VRect           rect() const;
    VSize           size() const;
    void    fill(uint pixel);
    void    updateLuma();
private:
    struct Impl;
    std::shared_ptr<Impl> mImpl;
};

V_END_NAMESPACE

#endif  // VBITMAP_H
