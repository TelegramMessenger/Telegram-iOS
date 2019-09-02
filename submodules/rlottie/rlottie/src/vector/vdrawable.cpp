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

#include "vdrawable.h"
#include "vdasher.h"
#include "vraster.h"

void VDrawable::preprocess(const VRect &clip)
{
    if (mFlag & (DirtyState::Path)) {
        if (mStroke.enable) {
            if (mStroke.mDash.size()) {
                VDasher dasher(mStroke.mDash.data(), mStroke.mDash.size());
                mPath.clone(dasher.dashed(mPath));
            }
            mRasterizer.rasterize(std::move(mPath), mStroke.cap, mStroke.join,
                                  mStroke.width, mStroke.miterLimit, clip);
        } else {
            mRasterizer.rasterize(std::move(mPath), mFillRule, clip);
        }
        mPath = {};
        mFlag &= ~DirtyFlag(DirtyState::Path);
    }
}

VRle VDrawable::rle()
{
    return mRasterizer.rle();
}

void VDrawable::setStrokeInfo(CapStyle cap, JoinStyle join, float miterLimit,
                              float strokeWidth)
{
    if ((mStroke.cap == cap) && (mStroke.join == join) &&
        vCompare(mStroke.miterLimit, miterLimit) &&
        vCompare(mStroke.width, strokeWidth))
        return;

    mStroke.enable = true;
    mStroke.cap = cap;
    mStroke.join = join;
    mStroke.miterLimit = miterLimit;
    mStroke.width = strokeWidth;
    mFlag |= DirtyState::Path;
}

void VDrawable::setDashInfo(std::vector<float> &dashInfo)
{
    bool hasChanged = false;

    if (mStroke.mDash.size() == dashInfo.size()) {
        for (uint i = 0; i < dashInfo.size(); i++) {
            if (!vCompare(mStroke.mDash[i], dashInfo[i])) {
                hasChanged = true;
                break;
            }
        }
    } else {
        hasChanged = true;
    }

    if (!hasChanged) return;

    mStroke.mDash = dashInfo;

    mFlag |= DirtyState::Path;
}

void VDrawable::setPath(const VPath &path)
{
    mPath = path;
    mFlag |= DirtyState::Path;
}
