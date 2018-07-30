#ifndef VRASTER_H
#define VRASTER_H
#include <future>
#include "vrle.h"

V_BEGIN_NAMESPACE

struct FTOutline;
class VPath;

struct VRasterPrivate;
class VRaster {
public:
    ~VRaster();
    static VRaster &instance()
    {
        static VRaster Singleton;
        return Singleton;
    }
    VRaster(const VRaster &other) = delete;
    VRaster(VRaster &&) = delete;
    VRaster &operator=(VRaster const &) = delete;
    VRaster &operator=(VRaster &&) = delete;

    std::future<VRle> generateFillInfo(const VPath &path,
                                       FillRule fillRule = FillRule::Winding);
    std::future<VRle> generateStrokeInfo(const VPath &path, CapStyle cap,
                                         JoinStyle join, float width,
                                         float meterLimit);

private:
    VRaster();
};

V_END_NAMESPACE

#endif  // VRASTER_H
