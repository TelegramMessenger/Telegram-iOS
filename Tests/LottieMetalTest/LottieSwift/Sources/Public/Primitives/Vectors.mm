#include "Vectors.hpp"

#include "VectorsCocoa.h"

#include "Lottie/Public/Keyframes/Interpolatable.hpp"

#include <math.h>

#import <QuartzCore/QuartzCore.h>

#import <simd/simd.h>

namespace lottie {

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
        auto nextPoint = points[closestPoint + 1];
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
    
    const CATransform3D lhs = b;
    const CATransform3D &rhs = *this;
    CATransform3D result = CATransform3D::identity();
    
    result.m11  = (lhs.m11*rhs.m11)+(lhs.m21*rhs.m12)+(lhs.m31*rhs.m13)+(lhs.m41*rhs.m14);
    result.m12  = (lhs.m12*rhs.m11)+(lhs.m22*rhs.m12)+(lhs.m32*rhs.m13)+(lhs.m42*rhs.m14);
    result.m13  = (lhs.m13*rhs.m11)+(lhs.m23*rhs.m12)+(lhs.m33*rhs.m13)+(lhs.m43*rhs.m14);
    result.m14  = (lhs.m14*rhs.m11)+(lhs.m24*rhs.m12)+(lhs.m34*rhs.m13)+(lhs.m44*rhs.m14);
    
    result.m21  = (lhs.m11*rhs.m21)+(lhs.m21*rhs.m22)+(lhs.m31*rhs.m23)+(lhs.m41*rhs.m24);
    result.m22  = (lhs.m12*rhs.m21)+(lhs.m22*rhs.m22)+(lhs.m32*rhs.m23)+(lhs.m42*rhs.m24);
    result.m23  = (lhs.m13*rhs.m21)+(lhs.m23*rhs.m22)+(lhs.m33*rhs.m23)+(lhs.m43*rhs.m24);
    result.m24  = (lhs.m14*rhs.m21)+(lhs.m24*rhs.m22)+(lhs.m34*rhs.m23)+(lhs.m44*rhs.m24);
    
    result.m31  = (lhs.m11*rhs.m31)+(lhs.m21*rhs.m32)+(lhs.m31*rhs.m33)+(lhs.m41*rhs.m34);
    result.m32  = (lhs.m12*rhs.m31)+(lhs.m22*rhs.m32)+(lhs.m32*rhs.m33)+(lhs.m42*rhs.m34);
    result.m33 = (lhs.m13*rhs.m31)+(lhs.m23*rhs.m32)+(lhs.m33*rhs.m33)+(lhs.m43*rhs.m34);
    result.m34 = (lhs.m14*rhs.m31)+(lhs.m24*rhs.m32)+(lhs.m34*rhs.m33)+(lhs.m44*rhs.m34);
    
    result.m41 = (lhs.m11*rhs.m41)+(lhs.m21*rhs.m42)+(lhs.m31*rhs.m43)+(lhs.m41*rhs.m44);
    result.m42 = (lhs.m12*rhs.m41)+(lhs.m22*rhs.m42)+(lhs.m32*rhs.m43)+(lhs.m42*rhs.m44);
    result.m43 = (lhs.m13*rhs.m41)+(lhs.m23*rhs.m42)+(lhs.m33*rhs.m43)+(lhs.m43*rhs.m44);
    result.m44 = (lhs.m14*rhs.m41)+(lhs.m24*rhs.m42)+(lhs.m34*rhs.m43)+(lhs.m44*rhs.m44);
    
    return result;
}

bool CATransform3D::isInvertible() const {
    return std::abs(m11 * m22 - m12 * m21) >= 0.00000001;
}

CATransform3D CATransform3D::inverted() const {
    return fromNativeTransform(CATransform3DMakeAffineTransform(CGAffineTransformInvert(CATransform3DGetAffineTransform(nativeTransform(*this)))));
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

static inline Vector2D applyingTransformToPoint(CATransform3D const &transform, Vector2D const &point) {
    double newX = point.x * transform.m11 + point.y * transform.m21 + transform.m41;
    double newY = point.x * transform.m12 + point.y * transform.m22 + transform.m42;
    double newW = point.x * transform.m14 + point.y * transform.m24 + transform.m44;
    
    return Vector2D(newX / newW, newY / newW);
}

CGRect CGRect::applyingTransform(CATransform3D const &transform) const {
    if (transform.isIdentity()) {
        return *this;
    }
    
    Vector2D topLeft = applyingTransformToPoint(transform, Vector2D(x, y));
    Vector2D topRight = applyingTransformToPoint(transform, Vector2D(x + width, y));
    Vector2D bottomLeft = applyingTransformToPoint(transform, Vector2D(x, y + height));
    Vector2D bottomRight = applyingTransformToPoint(transform, Vector2D(x + width, y + height));
    
    double minX = topLeft.x;
    if (topRight.x < minX) {
        minX = topRight.x;
    }
    if (bottomLeft.x < minX) {
        minX = bottomLeft.x;
    }
    if (bottomRight.x < minX) {
        minX = bottomRight.x;
    }
    
    double minY = topLeft.y;
    if (topRight.y < minY) {
        minY = topRight.y;
    }
    if (bottomLeft.y < minY) {
        minY = bottomLeft.y;
    }
    if (bottomRight.y < minY) {
        minY = bottomRight.y;
    }
    
    double maxX = topLeft.x;
    if (topRight.x > maxX) {
        maxX = topRight.x;
    }
    if (bottomLeft.x > maxX) {
        maxX = bottomLeft.x;
    }
    if (bottomRight.x > maxX) {
        maxX = bottomRight.x;
    }
    
    double maxY = topLeft.y;
    if (topRight.y > maxY) {
        maxY = topRight.y;
    }
    if (bottomLeft.y > maxY) {
        maxY = bottomLeft.y;
    }
    if (bottomRight.y > maxY) {
        maxY = bottomRight.y;
    }
    
    CGRect result(minX, minY, maxX - minX, maxY - minY);
    
    return result;
}

}
