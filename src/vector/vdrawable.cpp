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

#include "vdrawable.h"
#include "vdasher.h"
#include "vraster.h"

void VDrawable::preprocess(const VRect &clip)
{
    if (mFlag & (DirtyState::Path)) {

        if (!mRleFuture) mRleFuture = std::make_shared<VSharedState<VRle>>();

        mRleFuture->reuse();

        if (mStroke.enable) {
            if (mStroke.mDash.size()) {
                VDasher dasher(mStroke.mDash.data(), mStroke.mDash.size());
                mPath = dasher.dashed(mPath);
            }
            VRaster::generateStrokeInfo(mRleFuture,
                std::move(mPath), std::move(mRle), mStroke.cap, mStroke.join,
                mStroke.width, mStroke.meterLimit, clip);
        } else {
            VRaster::generateFillInfo(mRleFuture,
                std::move(mPath), std::move(mRle), mFillRule, clip);
        }
        mRle = VRle();
        mFlag &= ~DirtyFlag(DirtyState::Path);
    }
}

VRle VDrawable::rle()
{
    if (mRleFuture && mRleFuture->valid()) {
        mRle = mRleFuture->get();
    }
    return mRle;
}

void VDrawable::setStrokeInfo(CapStyle cap, JoinStyle join, float meterLimit,
                              float strokeWidth)
{
    if ((mStroke.cap == cap) && (mStroke.join == join) &&
        vCompare(mStroke.meterLimit, meterLimit) &&
        vCompare(mStroke.width, strokeWidth))
        return;

    mStroke.enable = true;
    mStroke.cap = cap;
    mStroke.join = join;
    mStroke.meterLimit = meterLimit;
    mStroke.width = strokeWidth;
    mFlag |= DirtyState::Path;
}

void VDrawable::setDashInfo(float *array, uint size)
{
    bool hasChanged = false;

    if (mStroke.mDash.size() == size) {
        for (uint i = 0; i < size; i++) {
            if (!vCompare(mStroke.mDash[i], array[i])) {
                hasChanged = true;
                break;
            }
        }
    } else {
        hasChanged = true;
    }

    if (!hasChanged) return;

    mStroke.mDash.clear();

    for (uint i = 0; i < size; i++) {
        mStroke.mDash.push_back(array[i]);
    }
    mFlag |= DirtyState::Path;
}

void VDrawable::setPath(const VPath &path)
{
    mPath = path;
    mFlag |= DirtyState::Path;
}
