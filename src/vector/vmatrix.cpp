#include"vmatrix.h"
#include<cmath>
#include<cstring>
#include<cassert>
#include<vglobal.h>

V_BEGIN_NAMESPACE

/*  m11  m21  mtx
 *  m12  m22  mty
 *  m13  m23  m33
 */

struct VMatrixData {
    RefCount             ref;
    VMatrix::MatrixType type;
    VMatrix::MatrixType dirty;
    float m11, m12, m13;
    float m21, m22, m23;
    float mtx, mty, m33;
};
static const struct VMatrixData shared_empty = {RefCount(-1),
                                                 VMatrix::MatrixType::None,
                                                 VMatrix::MatrixType::None,
                                                 1, 0, 0,
                                                 0, 1, 0,
                                                 0, 0, 1};
inline float VMatrix::determinant() const
{
    return d->m11*(d->m33*d->m22 - d->mty*d->m23) -
           d->m21*(d->m33*d->m12 - d->mty*d->m13)+d->mtx*(d->m23*d->m12 - d->m22*d->m13);
}

bool VMatrix::isAffine() const
{
    return type() < MatrixType::Project;
}

bool VMatrix::isIdentity() const
{
    return type() == MatrixType::None;
}

bool VMatrix::isInvertible() const
{
    return !vIsNull(determinant());
}

bool VMatrix::isScaling() const
{
    return type() >= MatrixType::Scale;
}
bool VMatrix::isRotating() const
{
    return type() >= MatrixType::Rotate;
}

bool VMatrix::isTranslating() const
{
    return type() >= MatrixType::Translate;
}

inline void VMatrix::cleanUp(VMatrixData *d)
{
    delete d;
}

void VMatrix::detach()
{
    if (d->ref.isShared())
        *this = copy();
}

VMatrix VMatrix::copy() const
{
    VMatrix r;

    r.d = new VMatrixData;
    memcpy(r.d, d, sizeof(VMatrixData));
    r.d->ref.setOwned();
    return r;
}

VMatrix::VMatrix()
    : d(const_cast<VMatrixData*>(&shared_empty))
{
}

VMatrix::~VMatrix()
{
    if (!d->ref.deref())
        cleanUp(d);
}

VMatrix::VMatrix(bool init V_UNUSED)
{
    d = new VMatrixData;
    memcpy(d, &shared_empty, sizeof(VMatrixData));
    d->ref.setOwned();
}

VMatrix::VMatrix(float h11, float h12, float h13,
                   float h21, float h22, float h23,
                   float h31, float h32, float h33)
{
    d = new VMatrixData;
    d->ref.setOwned();
    d->m11 = h11; d->m12 = h12; d->m13 = h13;
    d->m21 = h21; d->m22 = h22; d->m23 = h23;
    d->mtx = h31; d->mty = h32; d->m33 = h33;
    d->type = MatrixType::None;
    d->dirty = MatrixType::Project;
}

VMatrix::VMatrix(const VMatrix &m)
{
    d = m.d;
    d->ref.ref();
}

VMatrix::VMatrix(VMatrix &&other): d(other.d)
{
    other.d = const_cast<VMatrixData*>(&shared_empty);
}

VMatrix &VMatrix::operator=(const VMatrix &m)
{
    m.d->ref.ref();
    if (!d->ref.deref())
        cleanUp(d);

    d = m.d;
    return *this;
}

inline VMatrix &VMatrix::operator=(VMatrix &&other)
{
    if (!d->ref.deref())
        cleanUp(d);
    d = other.d;
    other.d = const_cast<VMatrixData*>(&shared_empty);
    return *this;
}

inline VMatrix &VMatrix::operator*=(float num)
{
    if (num == 1.)
        return *this;
    detach();
    d->m11 *= num;
    d->m12 *= num;
    d->m13 *= num;
    d->m21 *= num;
    d->m22 *= num;
    d->m23 *= num;
    d->mtx *= num;
    d->mty *= num;
    d->m33 *= num;
    if (d->dirty < MatrixType::Scale)
        d->dirty = MatrixType::Scale;

    return *this;
}

inline VMatrix &VMatrix::operator/=(float div)
{
    if (div == 0)
        return *this;
    detach();
    div = 1/div;
    return operator*=(div);
}

VMatrix::MatrixType VMatrix::type() const
{
    if(d->dirty == MatrixType::None || d->dirty < d->type)
        return static_cast<MatrixType>(d->type);

    switch (static_cast<MatrixType>(d->dirty)) {
    case MatrixType::Project:
        if (!vIsNull(d->m13) || !vIsNull(d->m23) || !vIsNull(d->m33 - 1)) {
             d->type = MatrixType::Project;
             break;
        }
    case MatrixType::Shear:
    case MatrixType::Rotate:
        if (!vIsNull(d->m12) || !vIsNull(d->m21)) {
            const float dot = d->m11 * d->m12 + d->m21 * d->m22;
            if (vIsNull(dot))
                d->type = MatrixType::Rotate;
            else
                d->type = MatrixType::Shear;
            break;
        }
    case MatrixType::Scale:
        if (!vIsNull(d->m11 - 1) || !vIsNull(d->m22 - 1)) {
            d->type = MatrixType::Scale;
            break;
        }
    case MatrixType::Translate:
        if (!vIsNull(d->mtx) || !vIsNull(d->mty)) {
            d->type = MatrixType::Translate;
            break;
        }
    case MatrixType::None:
        d->type = MatrixType::None;
        break;
    }

    d->dirty = MatrixType::None;
    return static_cast<MatrixType>(d->type);
}


VMatrix &VMatrix::translate(float dx, float dy)
{
    if (dx == 0 && dy == 0)
        return *this;
    detach();
    switch(type()) {
    case MatrixType::None:
        d->mtx = dx;
        d->mty = dy;
        break;
    case MatrixType::Translate:
        d->mtx += dx;
        d->mty += dy;
        break;
    case MatrixType::Scale:
        d->mtx += dx* d->m11;
        d->mty += dy* d->m22;
        break;
    case MatrixType::Project:
        d->m33 += dx * d->m13 + dy * d->m23;
    case MatrixType::Shear:
    case MatrixType::Rotate:
        d->mtx += dx*d->m11 + dy*d->m21;
        d->mty += dy*d->m22 + dx*d->m12;
        break;
    }
    if (d->dirty < MatrixType::Translate)
        d->dirty = MatrixType::Translate;
    return *this;
}

VMatrix & VMatrix::scale(float sx, float sy)
{
    if (sx == 1 && sy == 1)
        return *this;
    detach();
    switch(type()) {
    case MatrixType::None:
    case MatrixType::Translate:
        d->m11 = sx;
        d->m22 = sy;
        break;
    case MatrixType::Project:
        d->m13 *= sx;
        d->m23 *= sy;
    case MatrixType::Rotate:
    case MatrixType::Shear:
        d->m12 *= sx;
        d->m21 *= sy;
    case MatrixType::Scale:
        d->m11 *= sx;
        d->m22 *= sy;
        break;
    }
    if (d->dirty < MatrixType::Scale)
        d->dirty =  MatrixType::Scale;
    return *this;
}

VMatrix & VMatrix::shear(float sh, float sv)
{
    if (sh == 0 && sv == 0)
        return *this;
    detach();
    switch(type()) {
    case MatrixType::None:
    case MatrixType::Translate:
        d->m12 = sv;
        d->m21 = sh;
        break;
    case MatrixType::Scale:
        d->m12 = sv*d->m22;
        d->m21 = sh*d->m11;
        break;
    case MatrixType::Project: {
        float tm13 = sv*d->m23;
        float tm23 = sh*d->m13;
        d->m13 += tm13;
        d->m23 += tm23;
    }
    case MatrixType::Rotate:
    case MatrixType::Shear: {
        float tm11 = sv*d->m21;
        float tm22 = sh*d->m12;
        float tm12 = sv*d->m22;
        float tm21 = sh*d->m11;
        d->m11 += tm11; d->m12 += tm12;
        d->m21 += tm21; d->m22 += tm22;
        break;
    }
    }
    if (d->dirty < MatrixType::Shear)
        d->dirty = MatrixType::Shear;
    return *this;
}


static const float deg2rad = float(0.017453292519943295769);  // pi/180
static const float inv_dist_to_plane = 1. / 1024.;

VMatrix & VMatrix::rotate(float a, Axis axis)
{
    if (a == 0)
        return *this;
    detach();
    float sina = 0;
    float cosa = 0;
    if (a == 90. || a == -270.)
        sina = 1.;
    else if (a == 270. || a == -90.)
        sina = -1.;
    else if (a == 180.)
        cosa = -1.;
    else{
        float b = deg2rad*a;          // convert to radians
        sina = std::sin(b);               // fast and convenient
        cosa = std::cos(b);
    }

    if (axis == Axis::Z) {
        switch(type()) {
        case MatrixType::None:
        case MatrixType::Translate:
            d->m11 = cosa;
            d->m12 = sina;
            d->m21 = -sina;
            d->m22 = cosa;
            break;
        case MatrixType::Scale: {
            float tm11 = cosa*d->m11;
            float tm12 = sina*d->m22;
            float tm21 = -sina*d->m11;
            float tm22 = cosa*d->m22;
            d->m11 = tm11; d->m12 = tm12;
            d->m21 = tm21; d->m22 = tm22;
            break;
        }
        case MatrixType::Project: {
            float tm13 = cosa*d->m13 + sina*d->m23;
            float tm23 = -sina*d->m13 + cosa*d->m23;
            d->m13 = tm13;
            d->m23 = tm23;
        }
        case MatrixType::Rotate:
        case MatrixType::Shear: {
            float tm11 = cosa*d->m11 + sina*d->m21;
            float tm12 = cosa*d->m12 + sina*d->m22;
            float tm21 = -sina*d->m11 + cosa*d->m21;
            float tm22 = -sina*d->m12 + cosa*d->m22;
            d->m11 = tm11; d->m12 = tm12;
            d->m21 = tm21; d->m22 = tm22;
            break;
        }
        }
        if (d->dirty < MatrixType::Rotate)
            d->dirty = MatrixType::Rotate;
    } else {
        VMatrix result;
        if (axis == Axis::Y) {
            result.d->m11 = cosa;
            result.d->m13 = -sina * inv_dist_to_plane;
        } else {
            result.d->m22 = cosa;
            result.d->m23 = -sina * inv_dist_to_plane;
        }
        result.d->type = MatrixType::Project;
        *this = result * *this;
    }

    return *this;
}

VMatrix VMatrix::operator*(const VMatrix &m) const
{
    const MatrixType otherType = m.type();
    if (otherType == MatrixType::None)
        return *this;

    const MatrixType thisType = type();
    if (thisType == MatrixType::None)
        return m;

    VMatrix t(true);
    MatrixType type = vMax(thisType, otherType);
    switch(type) {
    case MatrixType::None:
        break;
    case MatrixType::Translate:
        t.d->mtx = d->mtx + m.d->mtx;
        t.d->mty += d->mty + m.d->mty;
        break;
    case MatrixType::Scale:
    {
        float m11 = d->m11*m.d->m11;
        float m22 = d->m22*m.d->m22;

        float m31 = d->mtx*m.d->m11 + m.d->mtx;
        float m32 = d->mty*m.d->m22 + m.d->mty;

        t.d->m11 = m11;
        t.d->m22 = m22;
        t.d->mtx = m31; t.d->mty = m32;
        break;
    }
    case MatrixType::Rotate:
    case MatrixType::Shear:
    {
        float m11 = d->m11*m.d->m11 + d->m12*m.d->m21;
        float m12 = d->m11*m.d->m12 + d->m12*m.d->m22;

        float m21 = d->m21*m.d->m11 + d->m22*m.d->m21;
        float m22 = d->m21*m.d->m12 + d->m22*m.d->m22;

        float m31 = d->mtx*m.d->m11 + d->mty*m.d->m21 + m.d->mtx;
        float m32 = d->mtx*m.d->m12 + d->mty*m.d->m22 + m.d->mty;

        t.d->m11 = m11; t.d->m12 = m12;
        t.d->m21 = m21; t.d->m22 = m22;
        t.d->mtx = m31; t.d->mty = m32;
        break;
    }
    case MatrixType::Project:
    {
        float m11 = d->m11*m.d->m11 + d->m12*m.d->m21 + d->m13*m.d->mtx;
        float m12 = d->m11*m.d->m12 + d->m12*m.d->m22 + d->m13*m.d->mty;
        float m13 = d->m11*m.d->m13 + d->m12*m.d->m23 + d->m13*m.d->m33;

        float m21 = d->m21*m.d->m11 + d->m22*m.d->m21 + d->m23*m.d->mtx;
        float m22 = d->m21*m.d->m12 + d->m22*m.d->m22 + d->m23*m.d->mty;
        float m23 = d->m21*m.d->m13 + d->m22*m.d->m23 + d->m23*m.d->m33;

        float m31 = d->mtx*m.d->m11 + d->mty*m.d->m21 + d->m33*m.d->mtx;
        float m32 = d->mtx*m.d->m12 + d->mty*m.d->m22 + d->m33*m.d->mty;
        float m33 = d->mtx*m.d->m13 + d->mty*m.d->m23 + d->m33*m.d->m33;

        t.d->m11 = m11; t.d->m12 = m12; t.d->m13 = m13;
        t.d->m21 = m21; t.d->m22 = m22; t.d->m23 = m23;
        t.d->mtx = m31; t.d->mty = m32; t.d->m33 = m33;
    }
    }

    t.d->dirty = type;
    t.d->type = type;

    return t;
}

VMatrix & VMatrix::operator*=(const VMatrix &o)
{
    const MatrixType otherType = o.type();
    if (otherType == MatrixType::None)
        return *this;

    const MatrixType thisType = type();
    if (thisType == MatrixType::None)
        return operator=(o);
    detach();
    MatrixType t = vMax(thisType, otherType);
    switch(t) {
    case MatrixType::None:
        break;
    case MatrixType::Translate:
        d->mtx += o.d->mtx;
        d->mty += o.d->mty;
        break;
    case MatrixType::Scale:
    {
        float m11 = d->m11*o.d->m11;
        float m22 = d->m22*o.d->m22;

        float m31 = d->mtx*o.d->m11 + o.d->mtx;
        float m32 = d->mty*o.d->m22 + o.d->mty;

        d->m11 = m11;
        d->m22 = m22;
        d->mtx = m31; d->mty = m32;
        break;
    }
    case MatrixType::Rotate:
    case MatrixType::Shear:
    {
        float m11 = d->m11*o.d->m11 + d->m12*o.d->m21;
        float m12 = d->m11*o.d->m12 + d->m12*o.d->m22;

        float m21 = d->m21*o.d->m11 + d->m22*o.d->m21;
        float m22 = d->m21*o.d->m12 + d->m22*o.d->m22;

        float m31 = d->mtx*o.d->m11 + d->mty*o.d->m21 + o.d->mtx;
        float m32 = d->mtx*o.d->m12 + d->mty*o.d->m22 + o.d->mty;

        d->m11 = m11; d->m12 = m12;
        d->m21 = m21; d->m22 = m22;
        d->mtx = m31; d->mty = m32;
        break;
    }
    case MatrixType::Project:
    {
        float m11 = d->m11*o.d->m11 + d->m12*o.d->m21 + d->m13*o.d->mtx;
        float m12 = d->m11*o.d->m12 + d->m12*o.d->m22 + d->m13*o.d->mty;
        float m13 = d->m11*o.d->m13 + d->m12*o.d->m23 + d->m13*o.d->m33;

        float m21 = d->m21*o.d->m11 + d->m22*o.d->m21 + d->m23*o.d->mtx;
        float m22 = d->m21*o.d->m12 + d->m22*o.d->m22 + d->m23*o.d->mty;
        float m23 = d->m21*o.d->m13 + d->m22*o.d->m23 + d->m23*o.d->m33;

        float m31 = d->mtx*o.d->m11 + d->mty*o.d->m21 + d->m33*o.d->mtx;
        float m32 = d->mtx*o.d->m12 + d->mty*o.d->m22 + d->m33*o.d->mty;
        float m33 = d->mtx*o.d->m13 + d->mty*o.d->m23 + d->m33*o.d->m33;

        d->m11 = m11; d->m12 = m12; d->m13 = m13;
        d->m21 = m21; d->m22 = m22; d->m23 = m23;
        d->mtx = m31; d->mty = m32; d->m33 = m33;
    }
    }

    d->dirty = t;
    d->type = t;

    return *this;
}

VMatrix VMatrix::adjoint() const
{
    float h11, h12, h13,
        h21, h22, h23,
        h31, h32, h33;
    h11 = d->m22*d->m33 - d->m23*d->mty;
    h21 = d->m23*d->mtx - d->m21*d->m33;
    h31 = d->m21*d->mty - d->m22*d->mtx;
    h12 = d->m13*d->mty - d->m12*d->m33;
    h22 = d->m11*d->m33 - d->m13*d->mtx;
    h32 = d->m12*d->mtx - d->m11*d->mty;
    h13 = d->m12*d->m23 - d->m13*d->m22;
    h23 = d->m13*d->m21 - d->m11*d->m23;
    h33 = d->m11*d->m22 - d->m12*d->m21;

    return VMatrix(h11, h12, h13,
                      h21, h22, h23,
                      h31, h32, h33);
}

VMatrix VMatrix::inverted(bool *invertible) const
{
    VMatrix invert(true);
    bool inv = true;

    switch(type()) {
    case MatrixType::None:
        break;
    case MatrixType::Translate:
        invert.d->mtx = -d->mtx;
        invert.d->mty = -d->mty;
        break;
    case MatrixType::Scale:
        inv = !vIsNull(d->m11);
        inv &= !vIsNull(d->m22);
        if (inv) {
            invert.d->m11 = 1. / d->m11;
            invert.d->m22 = 1. / d->m22;
            invert.d->mtx = -d->mtx * invert.d->m11;
            invert.d->mty = -d->mty * invert.d->m22;
        }
        break;
    default:
        // general case
        float det = determinant();
        inv = !vIsNull(det);
        if (inv)
            invert = (adjoint() /= det);
        //TODO Test above line
        break;
    }

    if (invertible)
        *invertible = inv;

    if (inv) {
        // inverting doesn't change the type
        invert.d->type = d->type;
        invert.d->dirty = d->dirty;
    }

    return invert;
}

bool VMatrix::operator==(const VMatrix &o) const
{
    if (d == o.d) return true;

    return d->m11 == o.d->m11 &&
           d->m12 == o.d->m12 &&
           d->m13 == o.d->m13 &&
           d->m21 == o.d->m21 &&
           d->m22 == o.d->m22 &&
           d->m23 == o.d->m23 &&
           d->mtx == o.d->mtx &&
           d->mty == o.d->mty &&
           d->m33 == o.d->m33;
}

bool VMatrix::operator!=(const VMatrix &o) const
{
    return !operator==(o);
}

bool VMatrix::fuzzyCompare(const VMatrix& o) const
{
    if (*this == o) return true;
    return vCompare(d->m11 , o.d->m11 )
        && vCompare(d->m12 , o.d->m12)
        && vCompare(d->m21 , o.d->m21)
        && vCompare(d->m22 , o.d->m22)
        && vCompare(d->mtx , o.d->mtx)
        && vCompare(d->mty , o.d->mty);
}

#define V_NEAR_CLIP 0.000001
#ifdef MAP
#  undef MAP
#endif
#define MAP(x, y, nx, ny) \
    do { \
        float FX_ = x; \
        float FY_ = y; \
        switch(t) {   \
        case MatrixType::None:  \
            nx = FX_;   \
            ny = FY_;   \
            break;    \
        case MatrixType::Translate:    \
            nx = FX_ + d->mtx;                \
            ny = FY_ + d->mty;                \
            break;                              \
        case MatrixType::Scale:                           \
            nx = d->m11 * FX_ + d->mtx;  \
            ny = d->m22 * FY_ + d->mty;  \
            break;                              \
        case MatrixType::Rotate:                          \
        case MatrixType::Shear:                           \
        case MatrixType::Project:                                      \
            nx = d->m11 * FX_ + d->m21 * FY_ + d->mtx;        \
            ny = d->m12 * FX_ + d->m22 * FY_ + d->mty;        \
            if (t == MatrixType::Project) {                                       \
                float w = ( d->m13 * FX_ + d->m23 * FY_ + d->m33);              \
                if (w < V_NEAR_CLIP) w = V_NEAR_CLIP;     \
                w = 1./w;                                               \
                nx *= w;                                                \
                ny *= w;                                                \
            }                                                           \
        }                                                               \
    } while (0)

VRect VMatrix::map(const VRect &rect) const
{
    VMatrix::MatrixType t = type();
    if (t <= MatrixType::Translate)
        return rect.translated(std::round(d->mtx), std::round(d->mty));

    if (t <= MatrixType::Scale) {
        int x = std::round(d->m11*rect.x() + d->mtx);
        int y = std::round(d->m22*rect.y() + d->mty);
        int w = std::round(d->m11*rect.width());
        int h = std::round(d->m22*rect.height());
        if (w < 0) {
            w = -w;
            x -= w;
        }
        if (h < 0) {
            h = -h;
            y -= h;
        }
        return VRect(x, y, w, h);
    } else if (t < MatrixType::Project) {
        // see mapToPolygon for explanations of the algorithm.
        float x = 0, y = 0;
        MAP(rect.left(), rect.top(), x, y);
        float xmin = x;
        float ymin = y;
        float xmax = x;
        float ymax = y;
        MAP(rect.right() + 1, rect.top(), x, y);
        xmin = vMin(xmin, x);
        ymin = vMin(ymin, y);
        xmax = vMax(xmax, x);
        ymax = vMax(ymax, y);
        MAP(rect.right() + 1, rect.bottom() + 1, x, y);
        xmin = vMin(xmin, x);
        ymin = vMin(ymin, y);
        xmax = vMax(xmax, x);
        ymax = vMax(ymax, y);
        MAP(rect.left(), rect.bottom() + 1, x, y);
        xmin = vMin(xmin, x);
        ymin = vMin(ymin, y);
        xmax = vMax(xmax, x);
        ymax = vMax(ymax, y);
        return VRect(std::round(xmin), std::round(ymin), std::round(xmax)-std::round(xmin), std::round(ymax)-std::round(ymin));
    } else {
        // Not supported
        assert(0);
    }
}

VRegion VMatrix::map(const VRegion &r) const
{
    VMatrix::MatrixType t = type();
    if (t == MatrixType::None)
        return r;

    if (t == MatrixType::Translate) {
        VRegion copy(r);
        copy.translate(std::round(d->mtx), std::round(d->mty));
        return copy;
    }

    if (t == MatrixType::Scale && r.rectCount() == 1)
        return VRegion(map(r.boundingRect()));
    // handle mapping of region properly
    assert(0);
    return r;
}

VPointF VMatrix::map(const VPointF &p) const
{
    float fx = p.x();
    float fy = p.y();

    float x = 0, y = 0;

    VMatrix::MatrixType t = type();
    switch(t) {
    case MatrixType::None:
        x = fx;
        y = fy;
        break;
    case MatrixType::Translate:
        x = fx + d->mtx;
        y = fy + d->mty;
        break;
    case MatrixType::Scale:
        x = d->m11 * fx + d->mtx;
        y = d->m22 * fy + d->mty;
        break;
    case MatrixType::Rotate:
    case MatrixType::Shear:
    case MatrixType::Project:
        x = d->m11 * fx + d->m21 * fy + d->mtx;
        y = d->m12 * fx + d->m22 * fy + d->mty;
        if (t == MatrixType::Project) {
            float w = 1./(d->m13 * fx + d->m23 * fy + d->m33);
            x *= w;
            y *= w;
        }
    }
    return VPointF(x, y);
}
static std::string type_helper(VMatrix::MatrixType t)
{
    switch(t) {
    case VMatrix::MatrixType::None:
        return "MatrixType::None";
        break;
    case VMatrix::MatrixType::Translate:
        return "MatrixType::Translate";
        break;
    case VMatrix::MatrixType::Scale:
        return "MatrixType::Scale";
        break;
    case VMatrix::MatrixType::Rotate:
        return "MatrixType::Rotate";
        break;
    case VMatrix::MatrixType::Shear:
        return "MatrixType::Shear";
        break;
    case VMatrix::MatrixType::Project:
        return "MatrixType::Project";
        break;
    }
    return "";
}
std::ostream& operator<<(std::ostream& os, const VMatrix& o)
{
    os<<"[Matrix: [dptr = "<<o.d<<"]"<<"[ref = "<<o.d->ref.count()<<"]"<<"type ="<<type_helper(o.type())<<", Data : "<<o.d->m11<<" "<<o.d->m12<<" "<<o.d->m13<<" "<<o.d->m21<<" "<<o.d->m22<<" "<<o.d->m23<<" "<<o.d->mtx<<" "<<o.d->mty<<" "<<o.d->m33<<" "<<"]"<<std::endl;
    return os;
}

float VMatrix::m11()const
{
    return d->m11;
}
float VMatrix::m12()const
{
    return d->m12;
}
float VMatrix::m13()const
{
    return d->m13;
}
float VMatrix::m21()const
{
    return d->m21;
}
float VMatrix::m22()const
{
    return d->m22;
}
float VMatrix::m23()const
{
    return d->m23;
}
float VMatrix::m31()const
{
    return d->mtx;
}
float VMatrix::m32()const
{
    return d->mty;
}
float VMatrix::m33()const
{
    return d->m33;
}

V_END_NAMESPACE

