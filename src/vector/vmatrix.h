#ifndef VMATRIX_H
#define VMATRIX_H
#include"vpoint.h"
#include "vregion.h"
#include "vglobal.h"

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

    VMatrix();
    ~VMatrix();
    VMatrix(const VMatrix &matrix);
    VMatrix(VMatrix &&other);
    VMatrix &operator=(const VMatrix &);
    VMatrix &operator=(VMatrix &&other);

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

    float m11()const;
    float m12()const;
    float m13()const;
    float m21()const;
    float m22()const;
    float m23()const;
    float m31()const;
    float m32()const;
    float m33()const;
private:
    explicit VMatrix(bool init);
    explicit VMatrix(float m11, float m12, float m13,
                      float m21, float m22, float m23,
                      float m31, float m32, float m33);
    VMatrix copy() const;
    void detach();
    void cleanUp(VMatrixData *x);

    VMatrixData *d;
};

inline VPointF VMatrix::map(float x, float y) const
{
    return map(VPointF(x, y));
}

#endif // VMATRIX_H
