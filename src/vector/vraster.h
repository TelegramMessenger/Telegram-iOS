#ifndef VRASTER_H
#define VRASTER_H
#include <future>
#include "vglobal.h"
#include "vrect.h"

V_BEGIN_NAMESPACE

class VPath;
class VRle;

struct VRaster {

    static std::future<VRle>
    generateFillInfo(VPath &&path, VRle &&rle,
                     FillRule fillRule = FillRule::Winding, const VRect &clip = VRect());

    static std::future<VRle>
    generateStrokeInfo(VPath &&path, VRle &&rle,
                       CapStyle cap, JoinStyle join,
                       float width, float meterLimit, const VRect &clip = VRect());
};

V_END_NAMESPACE

#endif  // VRASTER_H
