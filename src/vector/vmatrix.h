#ifndef VMATRIX_H
#define VMATRIX_H
#include"vpoint.h"
#include "vregion.h"
#include "vglobal.h"

V_BEGIN_NAMESPACE

struct VMatrixData;
class  VMatrix
{
public:
    enum class Axis {
        X,
        Y,
        Z
    };
    enum class MatrixType {
        None      = 0x00,
        Translate = 0x01,
        Scale     = 0x02,
        Rotate    = 0x04,
        Shear     = 0x08,
        Project   = 0x10
    };

    bool isAffine() const;
    bool isIdentity() const;
    bool isInvertible() const;
    bool isScaling() const;
    bool isRotating() const;
    bool isTranslating() const;
    MatrixType type() const;
    inline float determinant() const;

    VMatrix &translate(VPointF pos) { return translate(pos.x(), pos.y());};
    VMatrix &translate(float dx, float dy);
    VMatrix &scale(VPointF s){ return scale(s.x(), s.y());};
    VMatrix &scale(float sx, float sy);
    VMatrix &shear(float sh, float sv);
    VMatrix &rotate(float a, Axis axis = VMatrix::Axis::Z);
    VMatrix &rotateRadians(float a, Axis axis = VMatrix::Axis::Z);

    VPointF map(const VPointF &p) const;
    inline VPointF map(float x, float y) const;
    VRect map(const VRect &r) const;
    VRegion map(const VRegion &r) const;

    V_REQUIRED_RESULT VMatrix inverted(bool *invertible = nullptr) const;
    V_REQUIRED_RESULT VMatrix adjoint() const;

    VMatrix operator*(const VMatrix &o) const;
    VMatrix &operator*=(const VMatrix &);
    VMatrix &operator*=(float mul);
    VMatrix &operator/=(float div);
    bool operator==(const VMatrix &) const;
    bool operator!=(const VMatrix &) const;
    bool fuzzyCompare(const VMatrix &) const;
    friend std::ostream& operator<<(std::ostream& os, const VMatrix& o);
private:
    friend struct VSpanData;
    mutable MatrixType mType{MatrixType::None};
    mutable MatrixType dirty{MatrixType::None};
    float m11{1}, m12{0}, m13{0};
    float m21{0}, m22{1}, m23{0};
    float mtx{0}, mty{0}, m33{1};
};

inline VPointF VMatrix::map(float x, float y) const
{
    return map(VPointF(x, y));
}

V_END_NAMESPACE

#endif // VMATRIX_H
