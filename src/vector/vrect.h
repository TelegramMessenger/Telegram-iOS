#ifndef VRECT_H
#define VRECT_H
#include "vglobal.h"
#include "vpoint.h"

V_BEGIN_NAMESPACE

class VRect {
public:
    V_CONSTEXPR             VRect() : x1(0), y1(0), x2(-1), y2(-1) {}
    V_CONSTEXPR             VRect(int left, int top, int width, int height);
    V_CONSTEXPR inline bool isEmpty() const;
    V_CONSTEXPR inline bool isNull() const;

    V_CONSTEXPR inline int left() const;
    V_CONSTEXPR inline int top() const;
    V_CONSTEXPR inline int right() const;
    V_CONSTEXPR inline int bottom() const;
    V_CONSTEXPR inline int width() const;
    V_CONSTEXPR inline int height() const;
    V_CONSTEXPR inline int x() const;
    V_CONSTEXPR inline int y() const;
    inline void            setLeft(int l) { x1 = l; }
    inline void            setTop(int t) { y1 = t; }
    inline void            setRight(int r) { x2 = r; }
    inline void            setBottom(int b) { y2 = b; }
    inline void            setWidth(int w) { x2 = x1 + w; }
    inline void            setHeight(int h) { y2 = y1 + h; }
    inline VRect           translated(int dx, int dy) const;
    inline void            translate(int dx, int dy);
    inline bool            contains(const VRect &r, bool proper = false) const;
    inline bool            intersects(const VRect &r);
    friend V_CONSTEXPR inline bool operator==(const VRect &,
                                              const VRect &) noexcept;
    friend V_CONSTEXPR inline bool operator!=(const VRect &,
                                              const VRect &) noexcept;
    friend VDebug &                operator<<(VDebug &os, const VRect &o);

private:
    int x1;
    int y1;
    int x2;
    int y2;
};

inline bool VRect::intersects(const VRect &r)
{
    return (right() > r.left() && left() < r.right() && bottom() > r.top() &&
            top() < r.bottom());
}

inline VDebug &operator<<(VDebug &os, const VRect &o)
{
    os << "{R " << o.x() << "," << o.y() << "," << o.width() << ","
       << o.height() << "}";
    return os;
}
V_CONSTEXPR inline bool operator==(const VRect &r1, const VRect &r2) noexcept
{
    return r1.x1 == r2.x1 && r1.x2 == r2.x2 && r1.y1 == r2.y1 && r1.y2 == r2.y2;
}

V_CONSTEXPR inline bool operator!=(const VRect &r1, const VRect &r2) noexcept
{
    return r1.x1 != r2.x1 || r1.x2 != r2.x2 || r1.y1 != r2.y1 || r1.y2 != r2.y2;
}

V_CONSTEXPR inline bool VRect::isEmpty() const
{
    return x1 > x2 || y1 > y2;
}

V_CONSTEXPR inline bool VRect::isNull() const
{
    return (((x2 - x1) == 0) || ((y2 - y1) == 0));
}

V_CONSTEXPR inline int VRect::x() const
{
    return x1;
}

V_CONSTEXPR inline int VRect::y() const
{
    return y1;
}

V_CONSTEXPR inline int VRect::left() const
{
    return x1;
}

V_CONSTEXPR inline int VRect::top() const
{
    return y1;
}

V_CONSTEXPR inline int VRect::right() const
{
    return x2;
}

V_CONSTEXPR inline int VRect::bottom() const
{
    return y2;
}
V_CONSTEXPR inline int VRect::width() const
{
    return x2 - x1;
}
V_CONSTEXPR inline int VRect::height() const
{
    return y2 - y1;
}

inline VRect VRect::translated(int dx, int dy) const
{
    return VRect(x1 + dx, y1 + dy, x2 - x1, y2 - y1);
}

inline void VRect::translate(int dx, int dy)
{
    x1 += dx;
    y1 += dy;
    x2 += dx;
    y2 += dy;
}
inline bool VRect::contains(const VRect &r, bool proper) const
{
    if (!proper) {
        if ((x1 <= r.x1) && (x2 >= r.x2) && (y1 <= r.y1) && (y2 >= r.y2))
            return true;
        return false;
    } else {
        if ((x1 < r.x1) && (x2 > r.x2) && (y1 < r.y1) && (y2 > r.y2))
            return true;
        return false;
    }
}
V_CONSTEXPR inline VRect::VRect(int left, int top, int width, int height)
    : x1(left), y1(top), x2(width + left), y2(height + top)
{
}

class VRectF {
public:
    V_CONSTEXPR VRectF() : x1(0), y1(0), x2(-1), y2(-1) {}
    VRectF(float left, float top, float width, float height)
    {
        x1 = left;
        y1 = top;
        x2 = x1 + width;
        y2 = y1 + height;
    }

    V_CONSTEXPR inline bool    isEmpty() const;
    V_CONSTEXPR inline bool    isNull() const;
    V_CONSTEXPR inline float   left() const;
    V_CONSTEXPR inline float   top() const;
    V_CONSTEXPR inline float   right() const;
    V_CONSTEXPR inline float   bottom() const;
    V_CONSTEXPR inline float   width() const;
    V_CONSTEXPR inline float   height() const;
    V_CONSTEXPR inline float   x() const;
    V_CONSTEXPR inline float   y() const;
    V_CONSTEXPR inline VPointF center() const
    {
        return VPointF(x1 + (x2 - x1) / 2.f, y1 + (y2 - y1) / 2.f);
    }
    inline void setLeft(float l) { x1 = l; }
    inline void setTop(float t) { y1 = t; }
    inline void setRight(float r) { x2 = r; }
    inline void setBottom(float b) { y2 = b; }
    inline void setWidth(float w) { x2 = x1 + w; }
    inline void setHeight(float h) { y2 = y1 + h; }
    inline void translate(float dx, float dy)
    {
        x1 += dx;
        y1 += dy;
        x2 += dx;
        y2 += dy;
    }

private:
    float x1;
    float y1;
    float x2;
    float y2;
};

V_CONSTEXPR inline bool VRectF::isEmpty() const
{
    return x1 > x2 || y1 > y2;
}

V_CONSTEXPR inline bool VRectF::isNull() const
{
    return (((x2 - x1) == 0) || ((y2 - y1) == 0));
}

V_CONSTEXPR inline float VRectF::x() const
{
    return x1;
}

V_CONSTEXPR inline float VRectF::y() const
{
    return y1;
}

V_CONSTEXPR inline float VRectF::left() const
{
    return x1;
}

V_CONSTEXPR inline float VRectF::top() const
{
    return y1;
}

V_CONSTEXPR inline float VRectF::right() const
{
    return x2;
}

V_CONSTEXPR inline float VRectF::bottom() const
{
    return y2;
}
V_CONSTEXPR inline float VRectF::width() const
{
    return x2 - x1;
}
V_CONSTEXPR inline float VRectF::height() const
{
    return y2 - y1;
}

V_END_NAMESPACE

#endif  // VRECT_H
