#ifndef VRASTER_H
#define VRASTER_H
#include <future>
#include "vglobal.h"

V_BEGIN_NAMESPACE

class VPath;
class VRle;

struct VRaster {

    static std::future<VRle>
    generateFillInfo(VPath &&path, VRle &&rle,
                     FillRule fillRule = FillRule::Winding);

    static std::future<VRle>
    generateStrokeInfo(VPath &&path, VRle &&rle,
                       CapStyle cap, JoinStyle join,
                       float width, float meterLimit);
};

V_END_NAMESPACE

#endif  // VRASTER_H
