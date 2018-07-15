#ifndef VRASTER_H
#define VRASTER_H
#include"vrle.h"
#include<future>

V_BEGIN_NAMESPACE

struct FTOutline;
class VPath;

struct VRasterPrivate;
class VRaster
{
public:
    ~VRaster();
    static VRaster &instance()
    {
        static VRaster Singleton;
        return Singleton;
    }
    VRaster(const VRaster &other) = delete;
    VRaster(VRaster&&) = delete;
    VRaster& operator=(VRaster const&) = delete;
    VRaster& operator=(VRaster &&) = delete;

    static FTOutline *toFTOutline(const VPath &path);
    static void deleteFTOutline(FTOutline *);
    VRle generateFillInfo(const FTOutline *, FillRule fillRule = FillRule::Winding);
    VRle generateStrokeInfo(const FTOutline *, CapStyle cap, JoinStyle join,
                            float width, float meterLimit);
private:
    VRaster();
    VRasterPrivate *d;
};

V_END_NAMESPACE

#endif // VRASTER_H
