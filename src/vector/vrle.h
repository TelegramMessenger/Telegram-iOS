#ifndef VRLE_H
#define VRLE_H
#include<vglobal.h>
#include<vrect.h>
#include<vpoint.h>

V_BEGIN_NAMESPACE

struct VRleData;
class VRle
{
public:
    struct Span
    {
      short  x;
      short  y;
      ushort len;
      uchar  coverage;
    };
    typedef void (*VRleSpanCb)(int count, const VRle::Span *spans, void *userData);
    ~VRle();
    VRle();
    VRle(const VRle &other);
    VRle(VRle &&other);
    VRle &operator=(const VRle &);
    VRle &operator=(VRle &&other);
    bool isEmpty()const;
    VRect boundingRect() const;
    void addSpan(const VRle::Span *span, int count);
    bool operator ==(const VRle &other) const;
    void translate(const VPoint &p);
    void translate(int x, int y);
    VRle intersected(const VRect &r) const;
    VRle intersected(const VRle &other) const;
    void intersected(const VRect &r, VRleSpanCb cb, void *userData);
    VRle &intersect(const VRect &r);
    int size() const;
    const VRle::Span* data() const;
    VRle operator~() const;
    VRle operator+(const VRle &o) const;
    VRle operator-(const VRle &o) const;
    VRle operator&(const VRle &o) const;
    static VRle toRle(const VRectF &rect);
    friend VRle operator*(const VRle &, int alpha);
    inline friend VRle operator*(int alpha, const VRle &);
    friend VDebug& operator<<(VDebug& os, const VRle& object);
private:
    VRle copy() const;
    void detach();
    void cleanUp(VRleData *x);
    VRleData *d;
};

inline void VRle::translate(int x, int y)
{
    translate(VPoint(x,y));
}

inline VRle operator*(int alpha, const VRle &rle)
{
    return (rle * alpha);
}

V_END_NAMESPACE

#endif // VRLE_H
