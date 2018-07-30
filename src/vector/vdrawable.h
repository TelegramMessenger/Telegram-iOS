#ifndef VDRAWABLE_H
#define VDRAWABLE_H
#include <future>
#include "vbrush.h"
#include "vpath.h"
#include "vrle.h"

class VDrawable {
public:
    enum class DirtyState {
        None = 0x00000000,
        Path = 0x00000001,
        Stroke = 0x00000010,
        Brush = 0x00000100,
        All = (None | Path | Stroke | Brush)
    };
    enum class Type {
        Fill,
        Stroke,
    };
    typedef vFlag<DirtyState> DirtyFlag;
    VDrawable() = default;
    void setPath(const VPath &path);
    void setFillRule(FillRule rule) { mFillRule = rule; }
    void setBrush(const VBrush &brush) { mBrush = brush; }
    void setStrokeInfo(CapStyle cap, JoinStyle join, float meterLimit,
                       float strokeWidth);
    void setDashInfo(float *array, int size);
    void preprocess();
    VRle rle();

public:
    DirtyFlag         mFlag{DirtyState::All};
    VDrawable::Type   mType{Type::Fill};
    VBrush            mBrush;
    VPath             mPath;
    FillRule          mFillRule{FillRule::Winding};
    std::future<VRle> mRleTask;
    VRle              mRle;
    struct {
        bool      enable{false};
        float     width{0.0};
        CapStyle  cap{CapStyle::Flat};
        JoinStyle join{JoinStyle::Bevel};
        float     meterLimit{10};
        float *   dashArray{nullptr};
        int       dashArraySize{0};
    } mStroke;
};

#endif  // VDRAWABLE_H
