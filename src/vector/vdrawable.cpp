#include "vdrawable.h"
#include "vdasher.h"
#include "vraster.h"

void VDrawable::preprocess()
{
    if (mFlag & (DirtyState::Path)) {
        if (mStroke.enable) {
            VPath newPath = mPath;
            if (mStroke.dashArraySize) {
                VDasher dasher(mStroke.dashArray, mStroke.dashArraySize);
                newPath = dasher.dashed(mPath);
            }
            mRleTask = VRaster::instance().generateStrokeInfo(
                newPath, mStroke.cap, mStroke.join, mStroke.width,
                mStroke.meterLimit);
        } else {
            mRleTask = VRaster::instance().generateFillInfo(mPath, mFillRule);
        }
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
    mStroke.enable = true;
    mStroke.cap = cap;
    mStroke.join = join;
    mStroke.meterLimit = meterLimit;
    mStroke.width = strokeWidth;
    mFlag |= DirtyState::Path;
}

void VDrawable::setDashInfo(float *array, int size)
{
    mStroke.dashArray = array;
    mStroke.dashArraySize = size;
    mFlag |= DirtyState::Path;
}
