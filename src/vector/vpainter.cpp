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
