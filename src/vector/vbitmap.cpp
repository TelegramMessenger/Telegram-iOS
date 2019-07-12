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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include "vbitmap.h"
#include <string>
#include "vdrawhelper.h"
#include "vglobal.h"

V_BEGIN_NAMESPACE

struct VBitmap::Impl {
    uchar *         mData{nullptr};
    uint            mWidth{0};
    uint            mHeight{0};
    uint            mStride{0};
    uchar           mDepth{0};
    VBitmap::Format mFormat{VBitmap::Format::Invalid};
    bool            mOwnData;
    bool            mRoData;

    Impl() = delete;
    Impl(Impl&&) = delete;
    Impl(const Impl&) = delete;
    Impl& operator=(Impl&&) = delete;
    Impl& operator=(Impl&) = delete;

    VRect rect() const
    {
        return VRect(0, 0, mWidth, mHeight);
    }

    VSize size() const
    {
        return VSize(mWidth, mHeight);
    }

    explicit Impl(size_t width, size_t height, VBitmap::Format format)
        : mOwnData(true), mRoData(false)
    {
        reset(width, height, format);
    }

    void reset(size_t width, size_t height, VBitmap::Format format)
    {
        if (mOwnData && mData) delete[] mData;

        mWidth = uint(width);
        mHeight = uint(height);
        mFormat = format;

        mDepth = depth(format);
        mStride = ((mWidth * mDepth + 31) >> 5)
                      << 2;  // bytes per scanline (must be multiple of 4)
        mData = new uchar[mStride * mHeight];
    }

    explicit Impl(uchar *data, size_t w, size_t h, size_t bytesPerLine, VBitmap::Format format)
        : mData(data), mWidth(uint(w)), mHeight(uint(h)), mStride(uint(bytesPerLine)),
          mDepth(depth(format)), mFormat(format), mOwnData(false), mRoData(false){}

    ~Impl()
    {
        if (mOwnData && mData) delete[] mData;
    }

    size_t            stride() const { return mStride; }
    size_t            width() const { return mWidth; }
    size_t            height() const { return mHeight; }
    VBitmap::Format format() const { return mFormat; }
    uchar *         data() { return mData; }

    static uchar depth(VBitmap::Format format)
    {
        uchar depth = 1;
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

    void updateLuma()
    {
        if (mFormat != VBitmap::Format::ARGB32_Premultiplied) return;

        for (uint col = 0; col < mHeight; col++) {
            uint *pixel = (uint *)(mData + mStride * col);
            for (uint row = 0; row < mWidth; row++) {
                int alpha = vAlpha(*pixel);
                if (alpha == 0) {
                    pixel++;
                    continue;
                }

                int red = vRed(*pixel);
                int green = vGreen(*pixel);
                int blue = vBlue(*pixel);

                if (alpha != 255) {
                    // un multiply
                    red = (red * 255) / alpha;
                    green = (green * 255) / alpha;
                    blue = (blue * 255) / alpha;
                }
                int luminosity = int(0.299f * red + 0.587f * green + 0.114f * blue);
                *pixel = luminosity << 24;
                pixel++;
            }
        }
    }
};

VBitmap::VBitmap(size_t width, size_t height, VBitmap::Format format)
{
    if (width <= 0 || height <= 0 || format == Format::Invalid) return;

    mImpl = std::make_shared<Impl>(width, height, format);
}

VBitmap::VBitmap(uchar *data, size_t width, size_t height, size_t bytesPerLine,
                 VBitmap::Format format)
{
    if (!data || width <= 0 || height <= 0 || bytesPerLine <= 0 ||
        format == Format::Invalid)
        return;

    mImpl = std::make_shared<Impl>(data, width, height, bytesPerLine, format);
}

void VBitmap::reset(size_t w, size_t h, VBitmap::Format format)
{
    if (mImpl) {
        if (w == mImpl->width() && h == mImpl->height() &&
            format == mImpl->format()) {
            return;
        }
        mImpl->reset(w, h, format);
    } else {
        mImpl = std::make_shared<Impl>(w, h, format);
    }
}

size_t VBitmap::stride() const
{
    return mImpl ? mImpl->stride() : 0;
}

size_t VBitmap::width() const
{
    return mImpl ? mImpl->width() : 0;
}

size_t VBitmap::height() const
{
    return mImpl ? mImpl->height() : 0;
}

size_t VBitmap::depth() const
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

VRect VBitmap::rect() const
{
    return mImpl ? mImpl->rect() : VRect();
}

VSize VBitmap::size() const
{
    return mImpl ? mImpl->size() : VSize();
}

bool VBitmap::valid() const
{
    return (mImpl != nullptr);
}

VBitmap::Format VBitmap::format() const
{
    return mImpl ? mImpl->format() : VBitmap::Format::Invalid;
}

void VBitmap::fill(uint pixel)
{
    if (mImpl) mImpl->fill(pixel);
}

/*
 * This is special function which converts
 * RGB value to Luminosity and stores it in
 * the Alpha component of the pixel.
 * After this conversion the bitmap data is no more
 * in RGB space. but the Alpha component contains the
 *  Luminosity value of the pixel in HSL color space.
 * NOTE: this api has its own special usecase
 * make sure you know what you are doing before using
 * this api.
 */
void VBitmap::updateLuma()
{
    if (mImpl) mImpl->updateLuma();
}

V_END_NAMESPACE
