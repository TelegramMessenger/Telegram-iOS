#ifndef VPAINTER_H
#define VPAINTER_H

#include"vpoint.h"
#include"vrle.h"
#include"vbrush.h"

class VBitmap;
class VPainterImpl;
class VPainter {
public:
    enum CompositionMode{
        CompModeSrc,
        CompModeSrcOver
    };
    ~VPainter();
    VPainter();
    VPainter(VBitmap *buffer);
    bool begin(VBitmap *buffer);
    void end();
    void setBrush(const VBrush &brush);
    void drawRle(const VPoint &pos, const VRle &rle);
private:
    VPainterImpl  *mImpl;
};

#endif //VPAINTER_H
