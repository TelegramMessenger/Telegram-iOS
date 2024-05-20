#include <LottieCpp/Vectors.h>
#include <LottieCpp/VectorsCocoa.h>

#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Public/Keyframes/Interpolatable.hpp"

#include <math.h>

#import <QuartzCore/QuartzCore.h>

namespace lottie {

/*explicit Transform2D(Transform3D const &t) {
    CGAffineTransform at = CATransform3DGetAffineTransform(nativeTransform(t));
    _rows.columns[0] = simd_make_float3(at.a, at.b, 0.0);
    _rows.columns[1] = simd_make_float3(at.c, at.d, 0.0);
    _rows.columns[2] = simd_make_float3(at.tx, at.ty, 1.0);
}
 
 Transform3D transform3D() {
     CGAffineTransform at = CGAffineTransformMake(
         _rows.columns[0][0], _rows.columns[0][1],
         _rows.columns[1][0], _rows.columns[1][1],
         _rows.columns[2][0], _rows.columns[2][1]
     );
     return fromNativeTransform(CATransform3DMakeAffineTransform(at));
 }*/

/*struct Transform3D {
    float m11, m12, m13, m14;
    float m21, m22, m23, m24;
    float m31, m32, m33, m34;
    float m41, m42, m43, m44;
    
    Transform3D(
        float m11_, float m12_, float m13_, float m14_,
        float m21_, float m22_, float m23_, float m24_,
        float m31_, float m32_, float m33_, float m34_,
        float m41_, float m42_, float m43_, float m44_
    ) :
    m11(m11_), m12(m12_), m13(m13_), m14(m14_),
    m21(m21_), m22(m22_), m23(m23_), m24(m24_),
    m31(m31_), m32(m32_), m33(m33_), m34(m34_),
    m41(m41_), m42(m42_), m43(m43_), m44(m44_) {
    }
    
    bool operator==(Transform3D const &rhs) const {
        return m11 == rhs.m11 && m12 == rhs.m12 && m13 == rhs.m13 && m14 == rhs.m14 &&
        m21 == rhs.m21 && m22 == rhs.m22 && m23 == rhs.m23 && m24 == rhs.m24 &&
        m31 == rhs.m31 && m32 == rhs.m32 && m33 == rhs.m33 && m34 == rhs.m34 &&
        m41 == rhs.m41 && m42 == rhs.m42 && m43 == rhs.m43 && m44 == rhs.m44;
    }
    
    bool operator!=(Transform3D const &rhs) const {
        return !(*this == rhs);
    }
    
    inline bool isIdentity() const {
        return m11 == 1.0 && m12 == 0.0 && m13 == 0.0 && m14 == 0.0 &&
            m21 == 0.0 && m22 == 1.0 && m23 == 0.0 && m24 == 0.0 &&
            m31 == 0.0 && m32 == 0.0 && m33 == 1.0 && m34 == 0.0 &&
            m41 == 0.0 && m42 == 0.0 && m43 == 0.0 && m44 == 1.0;
    }
    
    static Transform3D makeTranslation(float tx, float ty, float tz) {
        return Transform3D(
            1,  0,  0,  0,
            0,  1,  0,  0,
            0,  0,  1,  0,
            tx, ty, tz, 1
        );
    }
    
    static Transform3D makeScale(float sx, float sy, float sz) {
        return Transform3D(
            sx, 0, 0, 0,
            0, sy, 0, 0,
            0, 0, sz, 0,
            0, 0, 0, 1
        );
    }
    
    static Transform3D makeRotation(float radians);
    
    static Transform3D makeSkew(float skew, float skewAxis) {
        float mCos = cos(degreesToRadians(skewAxis));
        float mSin = sin(degreesToRadians(skewAxis));
        float aTan = tan(degreesToRadians(skew));
        
        Transform3D transform1(
            mCos,
            mSin,
            0.0,
            0.0,
            -mSin,
            mCos,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0
        );
        
        Transform3D transform2(
            1.0,
            0.0,
            0.0,
            0.0,
            aTan,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0
        );
        
        Transform3D transform3(
            mCos,
            -mSin,
            0.0,
            0.0,
            mSin,
            mCos,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0
        );
        
        return transform3 * transform2 * transform1;
    }

    static Transform3D makeTransform(
        Vector2D const &anchor,
        Vector2D const &position,
        Vector2D const &scale,
        float rotation,
        std::optional<float> skew,
        std::optional<float> skewAxis
    ) {
        Transform3D result = Transform3D::identity();
        if (skew.has_value() && skewAxis.has_value()) {
            result = Transform3D::identity().translated(position).rotated(rotation).skewed(-skew.value(), skewAxis.value()).scaled(Vector2D(scale.x * 0.01, scale.y * 0.01)).translated(Vector2D(-anchor.x, -anchor.y));
        } else {
            result = Transform3D::identity().translated(position).rotated(rotation).scaled(Vector2D(scale.x * 0.01, scale.y * 0.01)).translated(Vector2D(-anchor.x, -anchor.y));
        }
        
        return result;
    }
    
    Transform3D rotated(float degrees) const;
    
    Transform3D translated(Vector2D const &translation) const;
    
    Transform3D scaled(Vector2D const &scale) const;
    
    Transform3D skewed(float skew, float skewAxis) const {
        return Transform3D::makeSkew(skew, skewAxis) * (*this);
    }
    
    static Transform3D identity() {
        return Transform3D(
            1.0f, 0.0f, 0.0f, 0.0f,
            0.0f, 1.0f, 0.0f, 0.0f,
            0.0f, 0.0f, 1.0f, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f
        );
    }
    
    Transform3D operator*(Transform3D const &b) const;
};*/

/*Transform2D t2d(Transform3D const &testMatrix) {
    ::CATransform3D nativeTest;
    
    nativeTest.m11 = testMatrix.m11;
    nativeTest.m12 = testMatrix.m12;
    nativeTest.m13 = testMatrix.m13;
    nativeTest.m14 = testMatrix.m14;
    
    nativeTest.m21 = testMatrix.m21;
    nativeTest.m22 = testMatrix.m22;
    nativeTest.m23 = testMatrix.m23;
    nativeTest.m24 = testMatrix.m24;
    
    nativeTest.m31 = testMatrix.m31;
    nativeTest.m32 = testMatrix.m32;
    nativeTest.m33 = testMatrix.m33;
    nativeTest.m34 = testMatrix.m34;
    
    nativeTest.m41 = testMatrix.m41;
    nativeTest.m42 = testMatrix.m42;
    nativeTest.m43 = testMatrix.m43;
    nativeTest.m44 = testMatrix.m44;
    
    CGAffineTransform at = CATransform3DGetAffineTransform(nativeTest);
    Transform2D result = Transform2D::identity();
    simd_float3x3 *rows = (simd_float3x3 *)&result.rows();
    rows->columns[0] = simd_make_float3(at.a, at.b, 0.0);
    rows->columns[1] = simd_make_float3(at.c, at.d, 0.0);
    rows->columns[2] = simd_make_float3(at.tx, at.ty, 1.0);
    
    return result;
}

Transform3D t3d(Transform2D const &t) {
    CGAffineTransform at = CGAffineTransformMake(
        t.rows().columns[0][0], t.rows().columns[0][1],
        t.rows().columns[1][0], t.rows().columns[1][1],
        t.rows().columns[2][0], t.rows().columns[2][1]
    );
    ::CATransform3D value = CATransform3DMakeAffineTransform(at);
    
    Transform3D result = Transform3D::identity();
    result.m11 = value.m11;
    result.m12 = value.m12;
    result.m13 = value.m13;
    result.m14 = value.m14;
    
    result.m21 = value.m21;
    result.m22 = value.m22;
    result.m23 = value.m23;
    result.m24 = value.m24;
    
    result.m31 = value.m31;
    result.m32 = value.m32;
    result.m33 = value.m33;
    result.m34 = value.m34;
    
    result.m41 = value.m41;
    result.m42 = value.m42;
    result.m43 = value.m43;
    result.m44 = value.m44;
    
    return result;
}

Transform3D Transform3D::operator*(Transform3D const &b) const {
    if (isIdentity()) {
        return b;
    }
    if (b.isIdentity()) {
        return *this;
    }
    
    return t3d((t2d(*this) * t2d(b)));
}*/

Vector1D::Vector1D(lottiejson11::Json const &json) noexcept(false) {
    if (json.is_number()) {
        value = json.number_value();
    } else if (json.is_array()) {
        if (json.array_items().empty()) {
            throw LottieParsingException();
        }
        if (!json.array_items()[0].is_number()) {
            throw LottieParsingException();
        }
        value = json.array_items()[0].number_value();
    } else {
        throw LottieParsingException();
    }
}

lottiejson11::Json Vector1D::toJson() const {
    return lottiejson11::Json(value);
}

Vector2D::Vector2D(lottiejson11::Json const &json) noexcept(false) {
    x = 0.0;
    y = 0.0;
    
    if (json.is_array()) {
        int index = 0;
        
        if (json.array_items().size() > index) {
            if (!json.array_items()[index].is_number()) {
                throw LottieParsingException();
            }
            x = json.array_items()[index].number_value();
            index++;
        }
        
        if (json.array_items().size() > index) {
            if (!json.array_items()[index].is_number()) {
                throw LottieParsingException();
            }
            y = json.array_items()[index].number_value();
            index++;
        }
    } else if (json.is_object()) {
        auto xAny = getAny(json.object_items(), "x");
        if (xAny.is_number()) {
            x = xAny.number_value();
        } else if (xAny.is_array()) {
            if (xAny.array_items().empty()) {
                throw LottieParsingException();
            }
            if (!xAny.array_items()[0].is_number()) {
                throw LottieParsingException();
            }
            x = xAny.array_items()[0].number_value();
        }
        
        auto yAny = getAny(json.object_items(), "y");
        if (yAny.is_number()) {
            y = yAny.number_value();
        } else if (yAny.is_array()) {
            if (yAny.array_items().empty()) {
                throw LottieParsingException();
            }
            if (!yAny.array_items()[0].is_number()) {
                throw LottieParsingException();
            }
            y = yAny.array_items()[0].number_value();
        }
    } else {
        throw LottieParsingException();
    }
}

lottiejson11::Json Vector2D::toJson() const {
    lottiejson11::Json::object result;
    
    result.insert(std::make_pair("x", x));
    result.insert(std::make_pair("y", y));
    
    return lottiejson11::Json(result);
}

Vector3D::Vector3D(lottiejson11::Json const &json) noexcept(false) {
    if (!json.is_array()) {
        throw LottieParsingException();
    }
    
    int index = 0;
    
    x = 0.0;
    y = 0.0;
    z = 0.0;
    
    if (json.array_items().size() > index) {
        if (!json.array_items()[index].is_number()) {
            throw LottieParsingException();
        }
        x = json.array_items()[index].number_value();
        index++;
    }
    
    if (json.array_items().size() > index) {
        if (!json.array_items()[index].is_number()) {
            throw LottieParsingException();
        }
        y = json.array_items()[index].number_value();
        index++;
    }
    
    if (json.array_items().size() > index) {
        if (!json.array_items()[index].is_number()) {
            throw LottieParsingException();
        }
        z = json.array_items()[index].number_value();
        index++;
    }
}

lottiejson11::Json Vector3D::toJson() const {
    lottiejson11::Json::array result;
    
    result.push_back(lottiejson11::Json(x));
    result.push_back(lottiejson11::Json(y));
    result.push_back(lottiejson11::Json(z));
    
    return lottiejson11::Json(result);
}

Transform2D Transform2D::_identity = Transform2D(
    simd_float3x3({
        simd_make_float3(1.0f, 0.0f, 0.0f),
        simd_make_float3(0.0f, 1.0f, 0.0f),
        simd_make_float3(0.0f, 0.0f, 1.0f)
    })
);

Transform2D Transform2D::makeTranslation(float tx, float ty) {
    return Transform2D(simd_float3x3({
        simd_make_float3(1.0f, 0.0f, 0.0f),
        simd_make_float3(0.0f, 1.0f, 0.0f),
        simd_make_float3(tx, ty, 1.0f)
    }));
}

Transform2D Transform2D::makeScale(float sx, float sy) {
    return Transform2D(simd_float3x3({
        simd_make_float3(sx, 0.0f, 0.0f),
        simd_make_float3(0.0f, sy, 0.0f),
        simd_make_float3(0.0f, 0.0f, 1.0f)
    }));
}

Transform2D Transform2D::makeRotation(float radians) {
    float c = cos(radians);
    float s = sin(radians);
    
    return Transform2D(simd_float3x3({
        simd_make_float3(c, s, 0.0f),
        simd_make_float3(-s, c, 0.0f),
        simd_make_float3(0.0f, 0.0f, 1.0f)
    }));
}

Transform2D Transform2D::makeSkew(float skew, float skewAxis) {
    if (std::abs(skew) <= FLT_EPSILON && std::abs(skewAxis) <= FLT_EPSILON) {
        return Transform2D::identity();
    }
    
    float mCos = cos(degreesToRadians(skewAxis));
    float mSin = sin(degreesToRadians(skewAxis));
    float aTan = tan(degreesToRadians(skew));
    
    simd_float3x3 simd1 = simd_float3x3({
        simd_make_float3(mCos, -mSin, 0.0),
        simd_make_float3(mSin, mCos, 0.0),
        simd_make_float3(0.0, 0.0, 1.0)
    });
    
    simd_float3x3 simd2 = simd_float3x3({
        simd_make_float3(1.0, 0.0, 0.0),
        simd_make_float3(aTan, 1.0, 0.0),
        simd_make_float3(0.0, 0.0, 1.0)
    });
    
    simd_float3x3 simd3 = simd_float3x3({
        simd_make_float3(mCos, mSin, 0.0),
        simd_make_float3(-mSin, mCos, 0.0),
        simd_make_float3(0.0, 0.0, 1.0)
    });
    
    simd_float3x3 result = simd_mul(simd_mul(simd3, simd2), simd1);
    Transform2D resultTransform(result);
    
    return resultTransform;
}

Transform2D Transform2D::makeTransform(
    Vector2D const &anchor,
    Vector2D const &position,
    Vector2D const &scale,
    float rotation,
    std::optional<float> skew,
    std::optional<float> skewAxis
) {
    Transform2D result = Transform2D::identity();
    if (skew.has_value() && skewAxis.has_value()) {
        result = Transform2D::identity().translated(position).rotated(rotation).skewed(-skew.value(), skewAxis.value()).scaled(Vector2D(scale.x * 0.01, scale.y * 0.01)).translated(Vector2D(-anchor.x, -anchor.y));
    } else {
        result = Transform2D::identity().translated(position).rotated(rotation).scaled(Vector2D(scale.x * 0.01, scale.y * 0.01)).translated(Vector2D(-anchor.x, -anchor.y));
    }
    
    return result;
}

Transform2D Transform2D::rotated(float degrees) const {
    return Transform2D::makeRotation(degreesToRadians(degrees)) * (*this);
}

Transform2D Transform2D::translated(Vector2D const &translation) const {
    return Transform2D::makeTranslation(translation.x, translation.y) * (*this);
}

Transform2D Transform2D::scaled(Vector2D const &scale) const {
    return Transform2D::makeScale(scale.x, scale.y) * (*this);
}

Transform2D Transform2D::skewed(float skew, float skewAxis) const {
    return Transform2D::makeSkew(skew, skewAxis) * (*this);
}

float interpolate(float value, float to, float amount) {
    return value + ((to - value) * amount);
}

Vector1D interpolate(
    Vector1D const &from,
    Vector1D const &to,
    float amount
) {
    return Vector1D(interpolate(from.value, to.value, amount));
}

Vector2D interpolate(
    Vector2D const &from,
    Vector2D const &to,
    float amount
) {
    return Vector2D(interpolate(from.x, to.x, amount), interpolate(from.y, to.y, amount));
}


Vector3D interpolate(
    Vector3D const &from,
    Vector3D const &to,
    float amount
) {
    return Vector3D(interpolate(from.x, to.x, amount), interpolate(from.y, to.y, amount), interpolate(from.z, to.z, amount));
}

static float cubicRoot(float value) {
    return pow(value, 1.0 / 3.0);
}

static float SolveQuadratic(float a, float b, float c) {
    float result = (-b + sqrt((b * b) - 4 * a * c)) / (2 * a);
    if (isInRangeOrEqual(result, 0.0, 1.0)) {
        return result;
    }
    
    result = (-b - sqrt((b * b) - 4 * a * c)) / (2 * a);
    if (isInRangeOrEqual(result, 0.0, 1.0)) {
        return result;
    }
    
    return -1.0;
}

inline bool isApproximatelyEqual(float value, float other) {
    return std::abs(value - other) <= FLT_EPSILON;
}

static float SolveCubic(float a, float b, float c, float d) {
    if (isApproximatelyEqual(a, 0.0f)) {
        return SolveQuadratic(b, c, d);
    }
    if (isApproximatelyEqual(d, 0.0f)) {
        return 0.0;
    }
    b /= a;
    c /= a;
    d /= a;
    float q = (3.0 * c - (b * b)) / 9.0;
    float r = (-27.0 * d + b * (9.0 * c - 2.0 * (b * b))) / 54.0;
    float disc = (q * q * q) + (r * r);
    float term1 = b / 3.0;
    
    if (disc > 0.0) {
        float s = r + sqrt(disc);
        s = (s < 0) ? -cubicRoot(-s) : cubicRoot(s);
        float t = r - sqrt(disc);
        t = (t < 0) ? -cubicRoot(-t) : cubicRoot(t);
        
        float result = -term1 + s + t;
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
    } else if (isApproximatelyEqual(disc, 0.0f)) {
        float r13 = (r < 0) ? -cubicRoot(-r) : cubicRoot(r);
        
        float result = -term1 + 2.0 * r13;
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
        
        result = -(r13 + term1);
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
    } else {
        q = -q;
        float dum1 = q * q * q;
        dum1 = acos(r / sqrt(dum1));
        float r13 = 2.0 * sqrt(q);
        
        float result = -term1 + r13 * cos(dum1 / 3.0);
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
        result = -term1 + r13 * cos((dum1 + 2.0 * M_PI) / 3.0);
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
        result = -term1 + r13 * cos((dum1 + 4.0 * M_PI) / 3.0);
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
    }
    
    return -1.0;
}

float cubicBezierInterpolate(float value, Vector2D const &P0, Vector2D const &P1, Vector2D const &P2, Vector2D const &P3) {
    float t = 0.0;
    if (isApproximatelyEqual(value, P0.x)) {
        // Handle corner cases explicitly to prevent rounding errors
        t = 0.0;
    } else if (isApproximatelyEqual(value, P3.x)) {
        t = 1.0;
    } else {
        // Calculate t
        float a = -P0.x + 3 * P1.x - 3 * P2.x + P3.x;
        float b = 3 * P0.x - 6 * P1.x + 3 * P2.x;
        float c = -3 * P0.x + 3 * P1.x;
        float d = P0.x - value;
        float tTemp = SolveCubic(a, b, c, d);
        if (isApproximatelyEqual(tTemp, -1.0f)) {
            return -1.0;
        }
        t = tTemp;
    }
    
    // Calculate y from t
    float oneMinusT = 1.0 - t;
    return (oneMinusT * oneMinusT * oneMinusT) * P0.y + 3 * t * (oneMinusT * oneMinusT) * P1.y + 3 * (t * t) * (1 - t) * P2.y + (t * t * t) * P3.y;
}

struct InterpolationPoint2D {
    InterpolationPoint2D(Vector2D const point_, float distance_) :
    point(point_), distance(distance_) {
    }
    
    Vector2D point;
    float distance;
};

namespace {
    float interpolateFloat(float value, float to, float amount) {
        return value + ((to - value) * amount);
    }
}

Vector2D Vector2D::pointOnPath(Vector2D const &to, Vector2D const &outTangent, Vector2D const &inTangent, float amount) const {
    auto a = interpolate(outTangent, amount);
    auto b = outTangent.interpolate(inTangent, amount);
    auto c = inTangent.interpolate(to, amount);
    auto d = a.interpolate(b, amount);
    auto e = b.interpolate(c, amount);
    auto f = d.interpolate(e, amount);
    return f;
}

Vector2D Vector2D::interpolate(Vector2D const &to, float amount) const {
    return Vector2D(
        interpolateFloat(x, to.x, amount),
        interpolateFloat(y, to.y, amount)
    );
}

Vector2D Vector2D::interpolate(
    Vector2D const &to,
    Vector2D const &outTangent,
    Vector2D const &inTangent,
    float amount,
    int maxIterations,
    int samples,
    float accuracy
) const {
    if (amount == 0.0) {
        return *this;
    }
    if (amount == 1.0) {
        return to;
    }
        
    if (colinear(outTangent, inTangent) && outTangent.colinear(inTangent, to)) {
        return interpolate(to, amount);
    }
        
    float step = 1.0 / (float)samples;
    
    std::vector<InterpolationPoint2D> points;
    points.push_back(InterpolationPoint2D(*this, 0.0));
    float totalLength = 0.0;
    
    Vector2D previousPoint = *this;
    float previousAmount = 0.0;
    
    int closestPoint = 0;
    
    while (previousAmount < 1.0) {
        previousAmount = previousAmount + step;
        
        if (previousAmount < amount) {
            closestPoint = closestPoint + 1;
        }
        
        auto newPoint = pointOnPath(to, outTangent, inTangent, previousAmount);
        auto distance = previousPoint.distanceTo(newPoint);
        totalLength = totalLength + distance;
        points.push_back(InterpolationPoint2D(newPoint, totalLength));
        previousPoint = newPoint;
    }
    
    float accurateDistance = amount * totalLength;
    auto point = points[closestPoint];
    
    bool foundPoint = false;
    
    float pointAmount = ((float)closestPoint) * step;
    float nextPointAmount = pointAmount + step;
    
    int refineIterations = 0;
    while (!foundPoint) {
        refineIterations = refineIterations + 1;
        /// First see if the next point is still less than the projected length.
        auto nextPoint = points[std::min(closestPoint + 1, (int)points.size() - 1)];
        if (nextPoint.distance < accurateDistance) {
            point = nextPoint;
            closestPoint = closestPoint + 1;
            pointAmount = ((float)closestPoint) * step;
            nextPointAmount = pointAmount + step;
            if (closestPoint == (int)points.size()) {
                foundPoint = true;
            }
            continue;
        }
        if (accurateDistance < point.distance) {
            closestPoint = closestPoint - 1;
            if (closestPoint < 0) {
                foundPoint = true;
                continue;
            }
            point = points[closestPoint];
            pointAmount = ((float)closestPoint) * step;
            nextPointAmount = pointAmount + step;
            continue;
        }
        
        /// Now we are certain the point is the closest point under the distance
        auto pointDiff = nextPoint.distance - point.distance;
        auto proposedPointAmount = remapFloat((accurateDistance - point.distance) / pointDiff, 0.0, 1.0, pointAmount, nextPointAmount);
        
        auto newPoint = pointOnPath(to, outTangent, inTangent, proposedPointAmount);
        auto newDistance = point.distance + point.point.distanceTo(newPoint);
        pointAmount = proposedPointAmount;
        point = InterpolationPoint2D(newPoint, newDistance);
        if (accurateDistance - newDistance <= accuracy ||
            newDistance - accurateDistance <= accuracy) {
            foundPoint = true;
        }
        
        if (refineIterations == maxIterations) {
            foundPoint = true;
        }
    }
    return point.point;
}

::CATransform3D nativeTransform(Transform2D const &value) {
    CGAffineTransform at = CGAffineTransformMake(
        value.rows().columns[0][0], value.rows().columns[0][1],
        value.rows().columns[1][0], value.rows().columns[1][1],
        value.rows().columns[2][0], value.rows().columns[2][1]
    );
    return CATransform3DMakeAffineTransform(at);
    
    /*::CATransform3D result;
    
    result.m11 = value.m11;
    result.m12 = value.m12;
    result.m13 = value.m13;
    result.m14 = value.m14;
    
    result.m21 = value.m21;
    result.m22 = value.m22;
    result.m23 = value.m23;
    result.m24 = value.m24;
    
    result.m31 = value.m31;
    result.m32 = value.m32;
    result.m33 = value.m33;
    result.m34 = value.m34;
    
    result.m41 = value.m41;
    result.m42 = value.m42;
    result.m43 = value.m43;
    result.m44 = value.m44;
    
    return result;*/
}

Transform2D fromNativeTransform(::CATransform3D const &value) {
    CGAffineTransform at = CATransform3DGetAffineTransform(value);
    return Transform2D(
        simd_float3x3({
            simd_make_float3(at.a, at.b, 0.0),
            simd_make_float3(at.c, at.d, 0.0),
            simd_make_float3(at.tx, at.ty, 1.0)
        })
    );
    
    /*Transform2D result = Transform2D::identity();
    
    result.m11 = value.m11;
    result.m12 = value.m12;
    result.m13 = value.m13;
    result.m14 = value.m14;
    
    result.m21 = value.m21;
    result.m22 = value.m22;
    result.m23 = value.m23;
    result.m24 = value.m24;
    
    result.m31 = value.m31;
    result.m32 = value.m32;
    result.m33 = value.m33;
    result.m34 = value.m34;
    
    result.m41 = value.m41;
    result.m42 = value.m42;
    result.m43 = value.m43;
    result.m44 = value.m44;
    
    return result;*/
}

/*Transform3D Transform3D::makeRotation(float radians) {
    if (std::abs(radians) <= FLT_EPSILON) {
        return Transform3D::identity();
    }
    
    float s = sin(radians);
    float c = cos(radians);
    
    ::CGAffineTransform t = CGAffineTransformMake(c, s, -s, c, 0.0f, 0.0f);
    return fromNativeTransform(CATransform3DMakeAffineTransform(t));
}

Transform3D Transform3D::rotated(float degrees) const {
    return Transform3D::makeRotation(degreesToRadians(degrees)) * (*this);
}

Transform3D Transform3D::translated(Vector2D const &translation) const {
    return Transform3D::makeTranslation(translation.x, translation.y, 0.0f) * (*this);
}

Transform3D Transform3D::scaled(Vector2D const &scale) const {
    return Transform3D::makeScale(scale.x, scale.y, 1.0) * (*this);
}

bool Transform3D::isInvertible() const {
    return Transform2D(*this).isInvertible();
    //return std::abs(m11 * m22 - m12 * m21) >= 0.00000001;
}

Transform3D Transform3D::inverted() const {
    return Transform2D(*this).inverted().transform3D();
}*/

bool CGRect::intersects(CGRect const &other) const {
    return CGRectIntersectsRect(CGRectMake(x, y, width, height), CGRectMake(other.x, other.y, other.width, other.height));
}

bool CGRect::contains(CGRect const &other) const {
    return CGRectContainsRect(CGRectMake(x, y, width, height), CGRectMake(other.x, other.y, other.width, other.height));
}

CGRect CGRect::intersection(CGRect const &other) const {
    auto result = CGRectIntersection(CGRectMake(x, y, width, height), CGRectMake(other.x, other.y, other.width, other.height));
    return CGRect(result.origin.x, result.origin.y, result.size.width, result.size.height);
}

CGRect CGRect::unionWith(CGRect const &other) const {
    auto result = CGRectUnion(CGRectMake(x, y, width, height), CGRectMake(other.x, other.y, other.width, other.height));
    return CGRect(result.origin.x, result.origin.y, result.size.width, result.size.height);
}

CGRect CGRect::applyingTransform(Transform2D const &transform) const {
    if (transform.isIdentity()) {
        return *this;
    }
    
    Vector2D sourceTopLeft = Vector2D(x, y);
    Vector2D sourceTopRight = Vector2D(x + width, y);
    Vector2D sourceBottomLeft = Vector2D(x, y + height);
    Vector2D sourceBottomRight = Vector2D(x + width, y + height);
    
    simd_float4 xs = simd_make_float4(sourceTopLeft.x, sourceTopRight.x, sourceBottomLeft.x, sourceBottomRight.x);
    simd_float4 ys = simd_make_float4(sourceTopLeft.y, sourceTopRight.y, sourceBottomLeft.y, sourceBottomRight.y);
    
    simd_float4 rx = xs * transform.rows().columns[0][0] + ys * transform.rows().columns[1][0] + transform.rows().columns[2][0];
    simd_float4 ry = xs * transform.rows().columns[0][1] + ys * transform.rows().columns[1][1] + transform.rows().columns[2][1];
    
    Vector2D topLeft = Vector2D(rx[0], ry[0]);
    Vector2D topRight = Vector2D(rx[1], ry[1]);
    Vector2D bottomLeft = Vector2D(rx[2], ry[2]);
    Vector2D bottomRight = Vector2D(rx[3], ry[3]);
    
    float minX = simd_reduce_min(simd_make_float4(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x));
    float minY = simd_reduce_min(simd_make_float4(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y));
    float maxX = simd_reduce_max(simd_make_float4(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x));
    float maxY = simd_reduce_max(simd_make_float4(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y));
    
    return CGRect(minX, minY, maxX - minX, maxY - minY);
}

}
