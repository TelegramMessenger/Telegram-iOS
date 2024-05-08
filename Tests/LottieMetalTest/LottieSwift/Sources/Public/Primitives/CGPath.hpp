#ifndef CGPath_hpp
#define CGPath_hpp

#include "Lottie/Public/Primitives/Vectors.hpp"

#include <memory>

namespace lottie {

struct CGPathItem {
    enum class Type {
        MoveTo,
        LineTo,
        CurveTo,
        Close
    };
    
    Type type;
    Vector2D points[3] = { Vector2D(0.0, 0.0), Vector2D(0.0, 0.0), Vector2D(0.0, 0.0) };
    
    explicit CGPathItem(Type type_) :
    type(type_) {
    }
    
    bool operator==(const CGPathItem &rhs) const {
        if (type != rhs.type) {
            return false;
        }
        if (points[0] != rhs.points[0]) {
            return false;
        }
        if (points[1] != rhs.points[1]) {
            return false;
        }
        if (points[2] != rhs.points[2]) {
            return false;
        }
        
        return true;
    }

    bool operator!=(const CGPathItem &rhs) const {
        return !(*this == rhs);
    }
};

class CGPath {
public:
    static std::shared_ptr<CGPath> makePath();
    
    virtual ~CGPath() = default;
    
    virtual CGRect boundingBox() const = 0;
    
    virtual bool empty() const = 0;
    
    virtual std::shared_ptr<CGPath> copyUsingTransform(CATransform3D const &transform) const = 0;
    
    virtual void addLineTo(Vector2D const &point) = 0;
    virtual void addCurveTo(Vector2D const &point, Vector2D const &control1, Vector2D const &control2) = 0;
    virtual void moveTo(Vector2D const &point) = 0;
    virtual void closeSubpath() = 0;
    virtual void addRect(CGRect const &rect) = 0;
    virtual void addPath(std::shared_ptr<CGPath> const &path) = 0;
    
    virtual void enumerate(std::function<void(CGPathItem const &)>) = 0;
    
    virtual bool isEqual(CGPath *other) const = 0;
};

Vector2D transformVector(Vector2D const &v, CATransform3D const &m);

}

#endif /* CGPath_hpp */
