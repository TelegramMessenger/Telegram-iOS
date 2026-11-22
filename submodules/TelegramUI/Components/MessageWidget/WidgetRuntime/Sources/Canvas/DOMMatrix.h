// geometry-1's DOMMatrix, its attributes only (V5d plan, Task 3): what getTransform() returns and setTransform(matrix)
// reads. No DOMMatrixReadOnly and no methods (IDL/README.md).
#pragma once

#include <array>
#include <optional>

#include "Sources/Canvas/CanvasInterpreter.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class DOMMatrix : public PlatformObject {
public:
    /// The identity, a sequence of 6 numbers (a 2D matrix) or 16 (column-major m11 … m44); any other length, or a
    /// non-sequence, is a TypeError.
    static Ref<DOMMatrix> construct(JSContext* ctx, std::optional<Value> init);
    static Ref<DOMMatrix> fromMatrix(JSContext* ctx, const canvas::Matrix& m);
    DOMMatrix() = default;

    Unrestricted a(JSContext*) const { return {m[0]}; }
    Unrestricted b(JSContext*) const { return {m[1]}; }
    Unrestricted c(JSContext*) const { return {m[4]}; }
    Unrestricted d(JSContext*) const { return {m[5]}; }
    Unrestricted e(JSContext*) const { return {m[12]}; }
    Unrestricted f(JSContext*) const { return {m[13]}; }
    void setA(JSContext*, Unrestricted v) { m[0] = v.value; }
    void setB(JSContext*, Unrestricted v) { m[1] = v.value; }
    void setC(JSContext*, Unrestricted v) { m[4] = v.value; }
    void setD(JSContext*, Unrestricted v) { m[5] = v.value; }
    void setE(JSContext*, Unrestricted v) { m[12] = v.value; }
    void setF(JSContext*, Unrestricted v) { m[13] = v.value; }

#define WR_DOMMATRIX_MEMBER(name, index, threeD)                                                                       \
    Unrestricted name(JSContext*) const { return {m[index]}; }                                                         \
    void set_##name(double v) {                                                                                        \
        m[index] = v;                                                                                                  \
        if (threeD) {                                                                                                  \
            is2DFlag = is2DFlag && v == (index % 5 == 0 ? 1.0 : 0.0);                                                  \
        }                                                                                                              \
    }
    WR_DOMMATRIX_MEMBER(m11, 0, false)
    WR_DOMMATRIX_MEMBER(m12, 1, false)
    WR_DOMMATRIX_MEMBER(m13, 2, true)
    WR_DOMMATRIX_MEMBER(m14, 3, true)
    WR_DOMMATRIX_MEMBER(m21, 4, false)
    WR_DOMMATRIX_MEMBER(m22, 5, false)
    WR_DOMMATRIX_MEMBER(m23, 6, true)
    WR_DOMMATRIX_MEMBER(m24, 7, true)
    WR_DOMMATRIX_MEMBER(m31, 8, true)
    WR_DOMMATRIX_MEMBER(m32, 9, true)
    WR_DOMMATRIX_MEMBER(m33, 10, true)
    WR_DOMMATRIX_MEMBER(m34, 11, true)
    WR_DOMMATRIX_MEMBER(m41, 12, false)
    WR_DOMMATRIX_MEMBER(m42, 13, false)
    WR_DOMMATRIX_MEMBER(m43, 14, true)
    WR_DOMMATRIX_MEMBER(m44, 15, true)
#undef WR_DOMMATRIX_MEMBER
    void setM11(JSContext*, Unrestricted v) { set_m11(v.value); }
    void setM12(JSContext*, Unrestricted v) { set_m12(v.value); }
    void setM13(JSContext*, Unrestricted v) { set_m13(v.value); }
    void setM14(JSContext*, Unrestricted v) { set_m14(v.value); }
    void setM21(JSContext*, Unrestricted v) { set_m21(v.value); }
    void setM22(JSContext*, Unrestricted v) { set_m22(v.value); }
    void setM23(JSContext*, Unrestricted v) { set_m23(v.value); }
    void setM24(JSContext*, Unrestricted v) { set_m24(v.value); }
    void setM31(JSContext*, Unrestricted v) { set_m31(v.value); }
    void setM32(JSContext*, Unrestricted v) { set_m32(v.value); }
    void setM33(JSContext*, Unrestricted v) { set_m33(v.value); }
    void setM34(JSContext*, Unrestricted v) { set_m34(v.value); }
    void setM41(JSContext*, Unrestricted v) { set_m41(v.value); }
    void setM42(JSContext*, Unrestricted v) { set_m42(v.value); }
    void setM43(JSContext*, Unrestricted v) { set_m43(v.value); }
    void setM44(JSContext*, Unrestricted v) { set_m44(v.value); }

    bool is2D(JSContext*) const { return is2DFlag; }
    bool isIdentity(JSContext*) const;
    canvas::Matrix matrix2D() const { return canvas::Matrix{m[0], m[1], m[4], m[5], m[12], m[13]}; }

    /// Column-major, as geometry-1 numbers them: m11 m12 m13 m14 m21 … m44.
    std::array<double, 16> m{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
    bool is2DFlag = true;
};

} // namespace wr
