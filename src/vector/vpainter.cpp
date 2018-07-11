#include"vpainter.h"
#include"vdrawhelper.h"

class VPainterImpl
{
public:
    void drawRle(const VPoint &pos, const VRle &rle);
public:
    VRasterBuffer mBuffer;
    VSpanData     mSpanData;
};

void VPainterImpl::drawRle(const VPoint &pos, const VRle &rle)
{
    if (rle.isEmpty()) return;
    //mSpanData.updateSpanFunc();

    if (!mSpanData.mUnclippedBlendFunc) return;

    // apply clip if any
    VRle final = rle.intersected(mSpanData.mSystemClip);

    if (final.isEmpty()) return;

    mSpanData.mUnclippedBlendFunc(final.size(), final.data(), &mSpanData);
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
    //TODO find a better api to clear the surface
    mImpl->mBuffer.clear();
    return true;
}
void VPainter::end()
{

}

void VPainter::setBrush(const VBrush &brush)
{
    mImpl->mSpanData.setup(brush);
}

void VPainter::drawRle(const VPoint &pos, const VRle &rle)
{
    mImpl->drawRle(pos, rle);
}
