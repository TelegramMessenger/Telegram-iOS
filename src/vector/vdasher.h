#ifndef VDASHER_H
#define VDASHER_H
#include "vpath.h"

V_BEGIN_NAMESPACE

class VDasher {
public:
    VDasher(const float *dashArray, int size);
    VPath dashed(const VPath &path);

private:
    void moveTo(const VPointF &p);
    void lineTo(const VPointF &p);
    void cubicTo(const VPointF &cp1, const VPointF &cp2, const VPointF &e);
    void close();
    void addLine(const VPointF &p);
    void addCubic(const VPointF &cp1, const VPointF &cp2, const VPointF &e);
    void updateActiveSegment();

private:
    struct Dash {
        float length;
        float gap;
    };
    const VDasher::Dash *mDashArray;
    int                  mArraySize{0};
    VPointF              mCurPt;
    int                  mIndex{0}; /* index to the dash Array */
    float                mCurrentLength;
    bool                 mDiscard;
    float                mDashOffset{0};
    VPath                mResult;
    bool                 mStartNewSegment=true;
};

V_END_NAMESPACE

#endif  // VDASHER_H
