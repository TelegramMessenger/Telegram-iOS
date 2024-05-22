#ifndef Vectors_hpp
#define Vectors_hpp

#ifdef __cplusplus

#include <stdlib.h>
#include <math.h>

#include <LottieCpp/lottiejson11.hpp>

#import <simd/simd.h>

namespace lottie {

struct Vector1D {
    enum class InternalRepresentationType {
        SingleNumber,
        Array
    };
    
    explicit Vector1D(float value_) :
    value(value_) {
    }
    
    explicit Vector1D(lottiejson11::Json const &json) noexcept(false);
    lottiejson11::Json toJson() const;
    
    float value;
    
    float distanceTo(Vector1D const &to) const {
        return abs(to.value - value);
    }
};

float interpolate(float value, float to, float amount);

Vector1D interpolate(
    Vector1D const &from,
    Vector1D const &to,
    float amount
);

struct __attribute__((packed)) Vector2D {
    static Vector2D Zero() {
        return Vector2D(0.0, 0.0);
    }
    
    Vector2D() :
    x(0.0),
    y(0.0) {
    }
    
    explicit Vector2D(float x_, float y_) :
    x(x_),
    y(y_) {
    }
    
    explicit Vector2D(lottiejson11::Json const &json) noexcept(false);
    lottiejson11::Json toJson() const;
    
    float x;
    float y;
    
    Vector2D operator+(Vector2D const &rhs) const {
        return Vector2D(x + rhs.x, y + rhs.y);
    }
    
    Vector2D operator-(Vector2D const &rhs) const {
        return Vector2D(x - rhs.x, y - rhs.y);
    }
    
    Vector2D operator*(float scalar) const {
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
    
    float distanceTo(Vector2D const &to) const {
        auto deltaX = to.x - x;
        auto deltaY = to.y - y;
        return sqrt(deltaX * deltaX + deltaY * deltaY);
    }
    
    bool colinear(Vector2D const &a, Vector2D const &b) const {
        float area = x * (a.y - b.y) + a.x * (b.y - y) + b.x * (y - a.y);
        float accuracy = 0.05;
        if (area < accuracy && area > -accuracy) {
            return true;
        }
        return false;
    }
    
    Vector2D pointOnPath(Vector2D const &to, Vector2D const &outTangent, Vector2D const &inTangent, float amount) const;
    
    Vector2D interpolate(Vector2D const &to, float amount) const;
    
    Vector2D interpolate(
        Vector2D const &to,
        Vector2D const &outTangent,
        Vector2D const &inTangent,
        float amount,
        int maxIterations = 3,
        int samples = 20,
        float accuracy = 1.0
    ) const;
};

Vector2D interpolate(
    Vector2D const &from,
    Vector2D const &to,
    float amount
);

struct Vector3D {
    explicit Vector3D(float x_, float y_, float z_) :
    x(x_),
    y(y_),
    z(z_) {
    }
    
    explicit Vector3D(lottiejson11::Json const &json) noexcept(false);
    lottiejson11::Json toJson() const;
    
    float x = 0.0;
    float y = 0.0;
    float z = 0.0;
};

Vector3D interpolate(
    Vector3D const &from,
    Vector3D const &to,
    float amount
);

inline float degreesToRadians(float value) {
    return value * M_PI / 180.0f;
}

inline float radiansToDegrees(float value) {
    return value * 180.0f / M_PI;
}

struct Transform2D {
    static Transform2D const &identity() {
        return _identity;
    }
    
    explicit Transform2D(simd_float3x3 const &rows_) :
    _rows(rows_) {
    }
    
    Transform2D operator*(Transform2D const &other) const {
        return Transform2D(simd_mul(other._rows, _rows));
    }
    
    bool isInvertible() const {
        return simd_determinant(_rows) > 0.00000001;
    }
    
    Transform2D inverted() const {
        return Transform2D(simd_inverse(_rows));
    }
    
    bool isIdentity() const {
        return (*this) == identity();
    }
    
    static Transform2D makeTranslation(float tx, float ty);
    static Transform2D makeScale(float sx, float sy);
    static Transform2D makeRotation(float radians);
    static Transform2D makeSkew(float skew, float skewAxis);
    static Transform2D makeTransform(
        Vector2D const &anchor,
        Vector2D const &position,
        Vector2D const &scale,
        float rotation,
        std::optional<float> skew,
        std::optional<float> skewAxis
    );
    
    Transform2D rotated(float degrees) const;
    Transform2D translated(Vector2D const &translation) const;
    Transform2D scaled(Vector2D const &scale) const;
    Transform2D skewed(float skew, float skewAxis) const;
    
    bool operator==(Transform2D const &rhs) const {
        return simd_equal(_rows, rhs._rows);
    }
    
    bool operator!=(Transform2D const &rhs) const {
        return !((*this) == rhs);
    }
    
    simd_float3x3 const &rows() const {
        return _rows;
    }
private:
    static Transform2D _identity;
    
    simd_float3x3 _rows;
};

struct CGRect {
    explicit CGRect(float x_, float y_, float width_, float height_) :
    x(x_), y(y_), width(width_), height(height_) {
    }
    
    float x = 0.0f;
    float y = 0.0f;
    float width = 0.0f;
    float height = 0.0f;
    
    static CGRect veryLarge() {
        return CGRect(
            -100000000.0f,
            -100000000.0f,
            200000000.0f,
            200000000.0f
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
    
    CGRect insetBy(float dx, float dy) const {
        CGRect result = *this;
        
        result.x += dx;
        result.y += dy;
        result.width -= dx * 2.0f;
        result.height -= dy * 2.0f;
        
        return result;
    }
    
    bool intersects(CGRect const &other) const;
    bool contains(CGRect const &other) const;
    
    CGRect intersection(CGRect const &other) const;
    CGRect unionWith(CGRect const &other) const;
    
    CGRect applyingTransform(Transform2D const &transform) const;
};

inline bool isInRangeOrEqual(float value, float from, float to) {
    return from <= value && value <= to;
}

inline bool isInRange(float value, float from, float to) {
    return from < value && value < to;
}

float cubicBezierInterpolate(float value, Vector2D const &P0, Vector2D const &P1, Vector2D const &P2, Vector2D const &P3);

}

#endif

#endif /* Vectors_hpp */
