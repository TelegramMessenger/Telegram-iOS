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

#include "vpainter.h"
#include "vdrawhelper.h"

V_BEGIN_NAMESPACE

class VPainterImpl {
public:
    void drawRle(const VPoint &pos, const VRle &rle);
    void drawRle(const VRle &rle, const VRle &clip);

public:
    VRasterBuffer mBuffer;
    VSpanData     mSpanData;
};

void VPainterImpl::drawRle(const VPoint &pos, const VRle &rle)
{
    if (rle.empty()) return;
    // mSpanData.updateSpanFunc();

    if (!mSpanData.mUnclippedBlendFunc) return;

    mSpanData.setPos(pos);

    // do draw after applying clip.
    rle.intersect(mSpanData.clipRect(), mSpanData.mUnclippedBlendFunc,
                  &mSpanData);
}

void VPainterImpl::drawRle(const VRle &rle, const VRle &clip)
{
    if (rle.empty() || clip.empty()) return;

    if (!mSpanData.mUnclippedBlendFunc) return;

    rle.intersect(clip, mSpanData.mUnclippedBlendFunc,
                  &mSpanData);
}


VPainter::~VPainter()
{
    delete mImpl;
}

VPainter::VPainter()
{
    mImpl = new VPainterImpl;
}

VPainter::VPainter(VBitmap *buffer)
{
    mImpl = new VPainterImpl;
    begin(buffer);
}
bool VPainter::begin(VBitmap *buffer)
{
    mImpl->mBuffer.prepare(buffer);
    mImpl->mSpanData.init(&mImpl->mBuffer);
    // TODO find a better api to clear the surface
    mImpl->mBuffer.clear();
    return true;
}
void VPainter::end() {}

void VPainter::setBrush(const VBrush &brush)
{
    mImpl->mSpanData.setup(brush);
}

void VPainter::drawRle(const VPoint &pos, const VRle &rle)
{
    mImpl->drawRle(pos, rle);
}

void VPainter::drawRle(const VRle &rle, const VRle &clip)
{
    mImpl->drawRle(rle, clip);
}


VRect VPainter::clipBoundingRect() const
{
    return mImpl->mSpanData.mSystemClip;
}

V_END_NAMESPACE
