#include <LottieCpp/Vectors.h>
#include <LottieCpp/VectorsCocoa.h>

#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Public/Keyframes/Interpolatable.hpp"

#include <math.h>

#import <QuartzCore/QuartzCore.h>

#import <simd/simd.h>

namespace lottie {

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

CATransform3D CATransform3D::_identity = CATransform3D(
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
);

double interpolate(double value, double to, double amount) {
    return value + ((to - value) * amount);
}

Vector1D interpolate(
    Vector1D const &from,
    Vector1D const &to,
    double amount
) {
    return Vector1D(interpolate(from.value, to.value, amount));
}

Vector2D interpolate(
    Vector2D const &from,
    Vector2D const &to,
    double amount
) {
    return Vector2D(interpolate(from.x, to.x, amount), interpolate(from.y, to.y, amount));
}


Vector3D interpolate(
    Vector3D const &from,
    Vector3D const &to,
    double amount
) {
    return Vector3D(interpolate(from.x, to.x, amount), interpolate(from.y, to.y, amount), interpolate(from.z, to.z, amount));
}

static double cubicRoot(double value) {
    return pow(value, 1.0 / 3.0);
}

static double SolveQuadratic(double a, double b, double c) {
    double result = (-b + sqrt((b * b) - 4 * a * c)) / (2 * a);
    if (isInRangeOrEqual(result, 0.0, 1.0)) {
        return result;
    }
    
    result = (-b - sqrt((b * b) - 4 * a * c)) / (2 * a);
    if (isInRangeOrEqual(result, 0.0, 1.0)) {
        return result;
    }
    
    return -1.0;
}

static double SolveCubic(double a, double b, double c, double d) {
    if (a == 0.0) {
        return SolveQuadratic(b, c, d);
    }
    if (d == 0.0) {
        return 0.0;
    }
    b /= a;
    c /= a;
    d /= a;
    double q = (3.0 * c - (b * b)) / 9.0;
    double r = (-27.0 * d + b * (9.0 * c - 2.0 * (b * b))) / 54.0;
    double disc = (q * q * q) + (r * r);
    double term1 = b / 3.0;
    
    if (disc > 0.0) {
        double s = r + sqrt(disc);
        s = (s < 0) ? -cubicRoot(-s) : cubicRoot(s);
        double t = r - sqrt(disc);
        t = (t < 0) ? -cubicRoot(-t) : cubicRoot(t);
        
        double result = -term1 + s + t;
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
    } else if (disc == 0) {
        double r13 = (r < 0) ? -cubicRoot(-r) : cubicRoot(r);
        
        double result = -term1 + 2.0 * r13;
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
        
        result = -(r13 + term1);
        if (isInRangeOrEqual(result, 0.0, 1.0)) {
            return result;
        }
    } else {
        q = -q;
        double dum1 = q * q * q;
        dum1 = acos(r / sqrt(dum1));
        double r13 = 2.0 * sqrt(q);
        
        double result = -term1 + r13 * cos(dum1 / 3.0);
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
    
    return -1;
}

double cubicBezierInterpolate(double value, Vector2D const &P0, Vector2D const &P1, Vector2D const &P2, Vector2D const &P3) {
    double t = 0.0;
    if (value == P0.x) {
        // Handle corner cases explicitly to prevent rounding errors
        t = 0.0;
    } else if (value == P3.x) {
        t = 1.0;
    } else {
        // Calculate t
        double a = -P0.x + 3 * P1.x - 3 * P2.x + P3.x;
        double b = 3 * P0.x - 6 * P1.x + 3 * P2.x;
        double c = -3 * P0.x + 3 * P1.x;
        double d = P0.x - value;
        double tTemp = SolveCubic(a, b, c, d);
        if (tTemp == -1.0) {
            return -1.0;
        }
        t = tTemp;
    }
    
    // Calculate y from t
    double oneMinusT = 1.0 - t;
    return (oneMinusT * oneMinusT * oneMinusT) * P0.y + 3 * t * (oneMinusT * oneMinusT) * P1.y + 3 * (t * t) * (1 - t) * P2.y + (t * t * t) * P3.y;
}

struct InterpolationPoint2D {
    InterpolationPoint2D(Vector2D const point_, double distance_) :
    point(point_), distance(distance_) {
    }
    
    Vector2D point;
    double distance;
};

namespace {
    double interpolateDouble(double value, double to, double amount) {
        return value + ((to - value) * amount);
    }
}

Vector2D Vector2D::pointOnPath(Vector2D const &to, Vector2D const &outTangent, Vector2D const &inTangent, double amount) const {
    auto a = interpolate(outTangent, amount);
    auto b = outTangent.interpolate(inTangent, amount);
    auto c = inTangent.interpolate(to, amount);
    auto d = a.interpolate(b, amount);
    auto e = b.interpolate(c, amount);
    auto f = d.interpolate(e, amount);
    return f;
}

Vector2D Vector2D::interpolate(Vector2D const &to, double amount) const {
    return Vector2D(
        interpolateDouble(x, to.x, amount),
        interpolateDouble(y, to.y, amount)
    );
}

Vector2D Vector2D::interpolate(
    Vector2D const &to,
    Vector2D const &outTangent,
    Vector2D const &inTangent,
    double amount,
    int maxIterations,
    int samples,
    double accuracy
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
        
    double step = 1.0 / (double)samples;
    
    std::vector<InterpolationPoint2D> points;
    points.push_back(InterpolationPoint2D(*this, 0.0));
    double totalLength = 0.0;
    
    Vector2D previousPoint = *this;
    double previousAmount = 0.0;
    
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
    
    double accurateDistance = amount * totalLength;
    auto point = points[closestPoint];
    
    bool foundPoint = false;
    
    double pointAmount = ((double)closestPoint) * step;
    double nextPointAmount = pointAmount + step;
    
    int refineIterations = 0;
    while (!foundPoint) {
        refineIterations = refineIterations + 1;
        /// First see if the next point is still less than the projected length.
        auto nextPoint = points[std::min(closestPoint + 1, (int)points.size() - 1)];
        if (nextPoint.distance < accurateDistance) {
            point = nextPoint;
            closestPoint = closestPoint + 1;
            pointAmount = ((double)closestPoint) * step;
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
            pointAmount = ((double)closestPoint) * step;
            nextPointAmount = pointAmount + step;
            continue;
        }
        
        /// Now we are certain the point is the closest point under the distance
        auto pointDiff = nextPoint.distance - point.distance;
        auto proposedPointAmount = remapDouble((accurateDistance - point.distance) / pointDiff, 0.0, 1.0, pointAmount, nextPointAmount);
        
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

::CATransform3D nativeTransform(CATransform3D const &value) {
    ::CATransform3D result;
    
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

CATransform3D fromNativeTransform(::CATransform3D const &value) {
    CATransform3D result = CATransform3D::identity();
    
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

CATransform3D CATransform3D::makeRotation(double radians, double x, double y, double z) {
    return fromNativeTransform(CATransform3DMakeRotation(radians, x, y, z));
    
    /*if (x == 0.0 && y == 0.0 && z == 0.0) {
        return CATransform3D::identity();
    }
    
    float s = sin(radians);
    float c = cos(radians);
    
    float len = sqrt(x*x + y*y + z*z);
    x /= len; y /= len; z /= len;
    
    CATransform3D returnValue = CATransform3D::identity();
    
    returnValue.m11 = c + (1-c) * x*x;
    returnValue.m12 = (1-c) * x*y + s*z;
    returnValue.m13 = (1-c) * x*z - s*y;
    returnValue.m14 = 0;
    
    returnValue.m21 = (1-c) * y*x - s*z;
    returnValue.m22 = c + (1-c) * y*y;
    returnValue.m23 = (1-c) * y*z + s*x;
    returnValue.m24 = 0;
    
    returnValue.m31 = (1-c) * z*x + s*y;
    returnValue.m32 = (1-c) * y*z - s*x;
    returnValue.m33 = c + (1-c) * z*z;
    returnValue.m34 = 0;
    
    returnValue.m41 = 0;
    returnValue.m42 = 0;
    returnValue.m43 = 0;
    returnValue.m44 = 1;
    
    return returnValue;*/
}

CATransform3D CATransform3D::rotated(double degrees) const {
    return fromNativeTransform(CATransform3DRotate(nativeTransform(*this), degreesToRadians(degrees), 0.0, 0.0, 1.0));
    //return CATransform3D::makeRotation(degreesToRadians(degrees), 0.0, 0.0, 1.0) * (*this);
}

CATransform3D CATransform3D::translated(Vector2D const &translation) const {
    return fromNativeTransform(CATransform3DTranslate(nativeTransform(*this), translation.x, translation.y, 0.0));
}

CATransform3D CATransform3D::scaled(Vector2D const &scale) const {
    return fromNativeTransform(CATransform3DScale(nativeTransform(*this), scale.x, scale.y, 1.0));
    //return CATransform3D::makeScale(scale.x, scale.y, 1.0) * (*this);
}

CATransform3D CATransform3D::operator*(CATransform3D const &b) const {
    if (isIdentity()) {
        return b;
    }
    if (b.isIdentity()) {
        return *this;
    }
    
    simd_double4x4 simdLhs = {
        simd_make_double4(b.m11, b.m21, b.m31, b.m41),
        simd_make_double4(b.m12, b.m22, b.m32, b.m42),
        simd_make_double4(b.m13, b.m23, b.m33, b.m43),
        simd_make_double4(b.m14, b.m24, b.m34, b.m44)
    };
    simd_double4x4 simdRhs = {
        simd_make_double4(m11, m21, m31, m41),
        simd_make_double4(m12, m22, m32, m42),
        simd_make_double4(m13, m23, m33, m43),
        simd_make_double4(m14, m24, m34, m44)
    };
    
    simd_double4x4 simdResult = simd_mul(simdRhs, simdLhs);
    return CATransform3D(
        simdResult.columns[0][0], simdResult.columns[1][0], simdResult.columns[2][0], simdResult.columns[3][0],
        simdResult.columns[0][1], simdResult.columns[1][1], simdResult.columns[2][1], simdResult.columns[3][1],
        simdResult.columns[0][2], simdResult.columns[1][2], simdResult.columns[2][2], simdResult.columns[3][2],
        simdResult.columns[0][3], simdResult.columns[1][3], simdResult.columns[2][3], simdResult.columns[3][3]
    );
}

bool CATransform3D::isInvertible() const {
    return std::abs(m11 * m22 - m12 * m21) >= 0.00000001;
}

CATransform3D CATransform3D::inverted() const {
    simd_double4x4 matrix = {
        simd_make_double4(m11, m21, m31, m41),
        simd_make_double4(m12, m22, m32, m42),
        simd_make_double4(m13, m23, m33, m43),
        simd_make_double4(m14, m24, m34, m44)
    };
    simd_double4x4 result = simd_inverse(matrix);
    CATransform3D nativeResult = CATransform3D(
        result.columns[0][0], result.columns[1][0], result.columns[2][0], result.columns[3][0],
        result.columns[0][1], result.columns[1][1], result.columns[2][1], result.columns[3][1],
        result.columns[0][2], result.columns[1][2], result.columns[2][2], result.columns[3][2],
        result.columns[0][3], result.columns[1][3], result.columns[2][3], result.columns[3][3]
    );
    
    return nativeResult;
}

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

CGRect CGRect::applyingTransform(CATransform3D const &transform) const {
    if (transform.isIdentity()) {
        return *this;
    }
    
    simd_double3 simdRow1 = simd_make_double3(transform.m11, transform.m12, transform.m14);
    simd_double3 simdRow2 = simd_make_double3(transform.m21, transform.m22, transform.m24);
    simd_double3 simdRow3 = simd_make_double3(transform.m41, transform.m42, transform.m44);
    
    Vector2D sourceTopLeft = Vector2D(x, y);
    Vector2D sourceTopRight = Vector2D(x + width, y);
    Vector2D sourceBottomLeft = Vector2D(x, y + height);
    Vector2D sourceBottomRight = Vector2D(x + width, y + height);
    
    simd_double3 simdTopLeft = sourceTopLeft.x * simdRow1 + sourceTopLeft.y * simdRow2 + simdRow3;
    simd_double3 simdTopRight = sourceTopRight.x * simdRow1 + sourceTopRight.y * simdRow2 + simdRow3;
    simd_double3 simdBottomLeft = sourceBottomLeft.x * simdRow1 + sourceBottomLeft.y * simdRow2 + simdRow3;
    simd_double3 simdBottomRight = sourceBottomRight.x * simdRow1 + sourceBottomRight.y * simdRow2 + simdRow3;
    
    Vector2D topLeft = Vector2D(simdTopLeft[0] / simdTopLeft[2], simdTopLeft[1] / simdTopLeft[2]);
    Vector2D topRight = Vector2D(simdTopRight[0] / simdTopRight[2], simdTopRight[1] / simdTopRight[2]);
    Vector2D bottomLeft = Vector2D(simdBottomLeft[0] / simdBottomLeft[2], simdBottomLeft[1] / simdBottomLeft[2]);
    Vector2D bottomRight = Vector2D(simdBottomRight[0] / simdBottomRight[2], simdBottomRight[1] / simdBottomRight[2]);
    
    double minX = simd_reduce_min(simd_make_double4(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x));
    double minY = simd_reduce_min(simd_make_double4(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y));
    double maxX = simd_reduce_max(simd_make_double4(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x));
    double maxY = simd_reduce_max(simd_make_double4(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y));
    
    return CGRect(minX, minY, maxX - minX, maxY - minY);
}

}
