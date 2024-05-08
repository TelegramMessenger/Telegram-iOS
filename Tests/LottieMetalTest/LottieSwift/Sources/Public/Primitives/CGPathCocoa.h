#ifndef CGPathCocoa_h
#define CGPathCocoa_h

#include "Lottie/Public/Primitives/CGPath.hpp"

#include <QuartzCore/QuartzCore.h>

CGRect calculatePathBoundingBox(CGPathRef path);

namespace lottie {

class CGPathCocoaImpl: public CGPath {
public:
    CGPathCocoaImpl();
    explicit CGPathCocoaImpl(CGMutablePathRef path);
    virtual ~CGPathCocoaImpl();
    
    virtual CGRect boundingBox() const override;
    
    virtual bool empty() const override;
    
    virtual std::shared_ptr<CGPath> copyUsingTransform(CATransform3D const &transform) const override;
    
    virtual void addLineTo(Vector2D const &point) override;
    virtual void addCurveTo(Vector2D const &point, Vector2D const &control1, Vector2D const &control2) override;
    virtual void moveTo(Vector2D const &point) override;
    virtual void closeSubpath() override;
    virtual void addRect(CGRect const &rect) override;
    virtual void addPath(std::shared_ptr<CGPath> const &path) override;
    virtual CGPathRef nativePath() const;
    virtual bool isEqual(CGPath *other) const override;
    virtual void enumerate(std::function<void(CGPathItem const &)>) override;
    
    static void withNativePath(std::shared_ptr<CGPath> const &path, std::function<void(CGPathRef)> f);
    
private:
    ::CGMutablePathRef _path = nil;
};

}

#endif /* CGPathCocoa_h */
