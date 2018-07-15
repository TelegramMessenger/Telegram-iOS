#ifndef VPATH_H
#define VPATH_H
#include "vpoint.h"
#include "vrect.h"
#include "vmatrix.h"
#include<vector>

V_BEGIN_NAMESPACE

struct VPathData;
class VPath
{
public:
    enum class Direction {
        CCW,
        CW
    };

    enum class Element : uchar {
        MoveTo,
        LineTo,
        CubicTo,
        Close
    };
    ~VPath();
    VPath();
    VPath(const VPath &path);
    VPath(VPath &&other);
    VPath &operator=(const VPath &);
    VPath &operator=(VPath &&other);
    bool isEmpty()const;
    void moveTo(const VPointF &p);
    inline void moveTo(float x, float y);
    void lineTo(const VPointF &p);
    inline void lineTo(float x, float y);
    void cubicTo(const VPointF &c1, const VPointF &c2, const VPointF &e);
    inline void cubicTo(float c1x, float c1y, float c2x, float c2y, float ex, float ey);
    void arcTo(const VRectF &rect, float startAngle, float sweepLength, bool forceMoveTo);
    void close();
    void reset();
    void reserve(int num_elm);

    void addCircle(float cx, float cy, float radius, VPath::Direction dir = Direction::CW);
    void addOval(const VRectF &rect, VPath::Direction dir = Direction::CW);
    void addRoundRect(const VRectF &rect, float rx, float ry, VPath::Direction dir = Direction::CW);
    void addRect(const VRectF &rect, VPath::Direction dir = Direction::CW);
    void addPolystarStar(float startAngle, float cx, float cy, float points,
                         float innerRadius, float outerRadius,
                         float innerRoundness, float outerRoundness,
                         VPath::Direction dir = Direction::CW);
    void addPolystarPolygon(float startAngle, float cx, float cy, float points,
                            float radius, float roundness,
                            VPath::Direction dir = Direction::CW);

    void transform(const VMatrix &m);
    const std::vector<VPath::Element> &elements() const;
    const std::vector<VPointF> &points() const;
private:
    friend class VRaster;
    int segments() const;
    VPath copy() const;
    void detach();
    void cleanUp(VPathData *x);
    VPathData *d;
};

inline void VPath::lineTo(float x, float y)
{
    lineTo(VPointF(x,y));
}

inline void VPath::moveTo(float x, float y)
{
    moveTo(VPointF(x,y));
}

inline void VPath::cubicTo(float c1x, float c1y, float c2x, float c2y, float ex, float ey)
{
      cubicTo(VPointF(c1x, c1y), VPointF(c2x, c2y), VPointF(ex, ey));
}

V_END_NAMESPACE

#endif // VPATH_H
