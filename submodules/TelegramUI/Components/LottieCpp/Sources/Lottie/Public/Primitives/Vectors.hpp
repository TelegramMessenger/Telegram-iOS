#ifndef Vectors_hpp
#define Vectors_hpp

#include "Lottie/Private/Parsing/JsonParsing.hpp"

#include <stdlib.h>
#include <math.h>

namespace lottie {

struct Vector1D {
    enum class InternalRepresentationType {
        SingleNumber,
        Array
    };
    
    explicit Vector1D(double value_) :
    value(value_) {
    }
    
    explicit Vector1D(json11::Json const &json) noexcept(false) {
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
    
    json11::Json toJson() const {
            return json11::Json(value);
    }
    
    double value;
    
    double distanceTo(Vector1D const &to) const {
        return abs(to.value - value);
    }
};

double interpolate(double value, double to, double amount);

Vector1D interpolate(
    Vector1D const &from,
    Vector1D const &to,
    double amount
);

struct Vector2D {
    static Vector2D Zero() {
        return Vector2D(0.0, 0.0);
    }
    
    Vector2D() :
    x(0.0),
    y(0.0) {
    }
    
    explicit Vector2D(double x_, double y_) :
    x(x_),
    y(y_) {
    }
    
    explicit Vector2D(json11::Json const &json) noexcept(false) {
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
    
    json11::Json toJson() const {
        json11::Json::object result;
        
        result.insert(std::make_pair("x", x));
        result.insert(std::make_pair("y", y));
        
        return json11::Json(result);
    }
    
    double x;
    double y;
    
    Vector2D operator+(Vector2D const &rhs) const {
        return Vector2D(x + rhs.x, y + rhs.y);
    }
    
    Vector2D operator-(Vector2D const &rhs) const {
        return Vector2D(x - rhs.x, y - rhs.y);
    }
    
    Vector2D operator*(double scalar) const {
        return Vector2D(x * scalar, y * scalar);
    }
    
    bool operator==(Vector2D const &rhs) const {
        return x == rhs.x && y == rhs.y;
    }
    
    bool operator!=(Vector2D const &rhs) const {
        return !(*this == rhs);
    }
    
    bool isZero() const {
        return x == 0.0 && y == 0.0;
    }
    
    double distanceTo(Vector2D const &to) const {
        auto deltaX = to.x - x;
        auto deltaY = to.y - y;
        return sqrt(deltaX * deltaX + deltaY * deltaY);
    }
    
    bool colinear(Vector2D const &a, Vector2D const &b) const {
        double area = x * (a.y - b.y) + a.x * (b.y - y) + b.x * (y - a.y);
        double accuracy = 0.05;
        if (area < accuracy && area > -accuracy) {
            return true;
        }
        return false;
    }
    
    Vector2D pointOnPath(Vector2D const &to, Vector2D const &outTangent, Vector2D const &inTangent, double amount) const;
    
    Vector2D interpolate(Vector2D const &to, double amount) const;
    
    Vector2D interpolate(
        Vector2D const &to,
        Vector2D const &outTangent,
        Vector2D const &inTangent,
        double amount,
        int maxIterations = 3,
        int samples = 20,
        double accuracy = 1.0
    ) const;
};

Vector2D interpolate(
    Vector2D const &from,
    Vector2D const &to,
    double amount
);

struct Vector3D {
    explicit Vector3D(double x_, double y_, double z_) :
    x(x_),
    y(y_),
    z(z_) {
    }
    
    explicit Vector3D(json11::Json const &json) noexcept(false) {
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
    
    json11::Json toJson() const {
        json11::Json::array result;
        
        result.push_back(json11::Json(x));
        result.push_back(json11::Json(y));
        result.push_back(json11::Json(z));
        
        return json11::Json(result);
    }
    
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
};

Vector3D interpolate(
    Vector3D const &from,
    Vector3D const &to,
    double amount
);

inline double degreesToRadians(double value) {
    return value * M_PI / 180.0;
}

inline double radiansToDegrees(double value) {
    return value * 180.0 / M_PI;
}

struct CATransform3D {
    double m11, m12, m13, m14;
    double m21, m22, m23, m24;
    double m31, m32, m33, m34;
    double m41, m42, m43, m44;
    
    CATransform3D(
        double m11_, double m12_, double m13_, double m14_,
        double m21_, double m22_, double m23_, double m24_,
        double m31_, double m32_, double m33_, double m34_,
        double m41_, double m42_, double m43_, double m44_
    ) :
    m11(m11_), m12(m12_), m13(m13_), m14(m14_),
    m21(m21_), m22(m22_), m23(m23_), m24(m24_),
    m31(m31_), m32(m32_), m33(m33_), m34(m34_),
    m41(m41_), m42(m42_), m43(m43_), m44(m44_) {
    }
    
    bool operator==(CATransform3D const &rhs) const {
        return m11 == rhs.m11 && m12 == rhs.m12 && m13 == rhs.m13 && m14 == rhs.m14 &&
        m21 == rhs.m21 && m22 == rhs.m22 && m23 == rhs.m23 && m24 == rhs.m24 &&
        m31 == rhs.m31 && m32 == rhs.m32 && m33 == rhs.m33 && m34 == rhs.m34 &&
        m41 == rhs.m41 && m42 == rhs.m42 && m43 == rhs.m43 && m44 == rhs.m44;
    }
    
    bool operator!=(CATransform3D const &rhs) const {
        return !(*this == rhs);
    }
    
    inline bool isIdentity() const {
        return m11 == 1.0 && m12 == 0.0 && m13 == 0.0 && m14 == 0.0 &&
            m21 == 0.0 && m22 == 1.0 && m23 == 0.0 && m24 == 0.0 &&
            m31 == 0.0 && m32 == 0.0 && m33 == 1.0 && m34 == 0.0 &&
            m41 == 0.0 && m42 == 0.0 && m43 == 0.0 && m44 == 1.0;
    }
    
    static CATransform3D makeTranslation(double tx, double ty, double tz) {
        return CATransform3D(
            1,  0,  0,  0,
            0,  1,  0,  0,
            0,  0,  1,  0,
            tx, ty, tz, 1
        );
    }
    
    static CATransform3D makeScale(double sx, double sy, double sz) {
        return CATransform3D(
            sx, 0, 0, 0,
            0, sy, 0, 0,
            0, 0, sz, 0,
            0, 0, 0, 1
        );
    }
    
    static CATransform3D makeRotation(double radians, double x, double y, double z);
    
    static CATransform3D makeSkew(double skew, double skewAxis) {
        double mCos = cos(degreesToRadians(skewAxis));
        double mSin = sin(degreesToRadians(skewAxis));
        double aTan = tan(degreesToRadians(skew));
        
        CATransform3D transform1(
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
        
        CATransform3D transform2(
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
        
        CATransform3D transform3(
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

    static CATransform3D makeTransform(
        Vector2D const &anchor,
        Vector2D const &position,
        Vector2D const &scale,
        double rotation,
        std::optional<double> skew,
        std::optional<double> skewAxis
    ) {
        CATransform3D result = CATransform3D::identity();
        if (skew.has_value() && skewAxis.has_value()) {
            result = CATransform3D::identity().translated(position).rotated(rotation).skewed(-skew.value(), skewAxis.value()).scaled(Vector2D(scale.x * 0.01, scale.y * 0.01)).translated(Vector2D(-anchor.x, -anchor.y));
        } else {
            result = CATransform3D::identity().translated(position).rotated(rotation).scaled(Vector2D(scale.x * 0.01, scale.y * 0.01)).translated(Vector2D(-anchor.x, -anchor.y));
        }
        
        return result;
    }
    
    CATransform3D rotated(double degrees) const;
    
    CATransform3D translated(Vector2D const &translation) const;
    
    CATransform3D scaled(Vector2D const &scale) const;
    
    CATransform3D skewed(double skew, double skewAxis) const {
        return CATransform3D::makeSkew(skew, skewAxis) * (*this);
    }
    
    static CATransform3D const &identity() {
        return _identity;
    }
    
    CATransform3D operator*(CATransform3D const &b) const;
    
    bool isInvertible() const;
    
    CATransform3D inverted() const;
    
private:
    static CATransform3D _identity;
};

struct CGRect {
    explicit CGRect(double x_, double y_, double width_, double height_) :
    x(x_), y(y_), width(width_), height(height_) {
    }
    
    double x = 0.0;
    double y = 0.0;
    double width = 0.0;
    double height = 0.0;
    
    static CGRect veryLarge() {
        return CGRect(
            -100000000.0,
            -100000000.0,
            200000000.0,
            200000000.0
        );
    }
    
    bool operator==(CGRect const &rhs) const {
        return x == rhs.x && y == rhs.y && width == rhs.width && height == rhs.height;
    }
    
    bool operator!=(CGRect const &rhs) const {
        return !(*this == rhs);
    }
    
    bool empty() const {
        return width <= 0.0 || height <= 0.0;
    }
    
    CGRect insetBy(double dx, double dy) const {
        CGRect result = *this;
        
        result.x += dx;
        result.y += dy;
        result.width -= dx * 2.0;
        result.height -= dy * 2.0;
        
        return result;
    }
    
    bool intersects(CGRect const &other) const;
    bool contains(CGRect const &other) const;
    
    CGRect intersection(CGRect const &other) const;
    CGRect unionWith(CGRect const &other) const;
    
    CGRect applyingTransform(CATransform3D const &transform) const;
};

inline bool isInRangeOrEqual(double value, double from, double to) {
    return from <= value && value <= to;
}

inline bool isInRange(double value, double from, double to) {
    return from < value && value < to;
}

double cubicBezierInterpolate(double value, Vector2D const &P0, Vector2D const &P1, Vector2D const &P2, Vector2D const &P3);

}

#endif /* Vectors_hpp */
