#include "vdrawable.h"
#include "vdasher.h"
#include "vraster.h"

void VDrawable::preprocess(const VRect &clip)
{
    if (mFlag & (DirtyState::Path)) {
        if (mStroke.enable) {
            if (mStroke.mDash.size()) {
                VDasher dasher(mStroke.mDash.data(), mStroke.mDash.size());
                mPath = dasher.dashed(mPath);
            }
            mRleTask = VRaster::generateStrokeInfo(
                std::move(mPath), std::move(mRle), mStroke.cap, mStroke.join,
                mStroke.width, mStroke.meterLimit, clip);
        } else {
            mRleTask = VRaster::generateFillInfo(
                std::move(mPath), std::move(mRle), mFillRule, clip);
        }
        mRle = VRle();
        mFlag &= ~DirtyFlag(DirtyState::Path);
    }
}

VRle VDrawable::rle()
{
    if (mRleTask.valid()) {
        mRle = mRleTask.get();
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
