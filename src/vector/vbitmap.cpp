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

#include "vbitmap.h"
#include <string.h>
#include "vglobal.h"

V_BEGIN_NAMESPACE

struct VBitmap::Impl {
    uchar *             mData{nullptr};
    uint                mWidth{0};
    uint                mHeight{0};
    uint                mStride{0};
    uint                mBytes{0};
    uint                mDepth{0};
    VBitmap::Format     mFormat{VBitmap::Format::Invalid};
    bool                mOwnData;
    bool                mRoData;

    Impl() = delete ;

    Impl(uint width, uint height, VBitmap::Format format):
        mOwnData(true),
        mRoData(false)
    {
        mDepth = depth(format);
        uint stride = ((width * mDepth + 31) >> 5) << 2; // bytes per scanline (must be multiple of 4)

        mWidth = width;
        mHeight = height;
        mFormat = format;
        mStride = stride;
        mBytes = mStride * mHeight;
        mData = reinterpret_cast<uchar *>(::operator new(mBytes));

        if (!mData) {
            // handle malloc failure
            ;
        }
    }

    Impl(uchar *data, uint w, uint h, uint bytesPerLine, VBitmap::Format format):
        mOwnData(false),
        mRoData(false)
    {
        mWidth = w;
        mHeight = h;
        mFormat = format;
        mStride = bytesPerLine;
        mBytes = mStride * mHeight;
        mData = data;
        mDepth = depth(format);
    }

    ~Impl()
    {
        if (mOwnData && mData) ::operator delete(mData);
    }

    uint stride() const {return mStride;}
    uint width() const {return mWidth;}
    uint height() const {return mHeight;}
    VBitmap::Format format() const {return mFormat;}
    uchar* data() { return mData;}

    static uint depth(VBitmap::Format format)
    {
        uint depth = 1;
        switch (format) {
        case VBitmap::Format::Alpha8:
            depth = 8;
            break;
        case VBitmap::Format::ARGB32:
        case VBitmap::Format::ARGB32_Premultiplied:
            depth = 32;
            break;
        default:
            break;
        }
        return depth;
    }
    void fill(uint /*pixel*/)
    {
        //@TODO
    }
};

VBitmap::VBitmap(uint width, uint height, VBitmap::Format format)
{
    if (width <=0 || height <=0 || format == Format::Invalid) return;

    mImpl = std::make_shared<Impl>(width, height, format);

}

VBitmap::VBitmap(uchar *data, uint width, uint height, uint bytesPerLine,
                 VBitmap::Format format)
{
    if (!data ||
        width <=0 || height <=0 ||
        bytesPerLine <=0 ||
        format == Format::Invalid) return;

    mImpl = std::make_shared<Impl>(data, width, height, bytesPerLine, format);
}

uint VBitmap::stride() const
{
    return mImpl ? mImpl->stride() : 0;
}

uint VBitmap::width() const
{
    return mImpl ? mImpl->width() : 0;
}

uint VBitmap::height() const
{
    return mImpl ? mImpl->height() : 0;
}

uint VBitmap::depth() const
{
    return mImpl ? mImpl->mDepth : 0;
}

uchar *VBitmap::data()
{
    return mImpl ? mImpl->data() : nullptr;
}

uchar *VBitmap::data() const
{
    return mImpl ? mImpl->data() : nullptr;
}

bool VBitmap::valid() const
{
    return mImpl ? true : false;
}

VBitmap::Format VBitmap::format() const
{
    return mImpl ? mImpl->format() : VBitmap::Format::Invalid;
}

void VBitmap::fill(uint pixel)
{
    if (mImpl) mImpl->fill(pixel);
}

V_END_NAMESPACE
