#ifndef CALayerCocoa_h
#define CALayerCocoa_h

#import <QuartzCore/QuartzCore.h>

#include "Lottie/Public/Primitives/CALayer.hpp"

namespace lottie {

class CGImageImpl: public CGImage {
public:
    CGImageImpl(::CGImageRef image);
    virtual ~CGImageImpl();
    ::CGImageRef nativeImage() const;
    
private:
    CGImageRef _image = nil;
};

class CGContextImpl: public CGContext {
public:
    CGContextImpl(int width, int height);
    CGContextImpl(CGContextRef context, int width, int height);
    virtual ~CGContextImpl();
    
    virtual int width() const override;
    virtual int height() const override;
    
    std::shared_ptr<CGContext> makeLayer(int width, int height) override;
    
    virtual void saveState() override;
    virtual void restoreState() override;
    
    virtual void fillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, Color const &color) override;
    virtual void linearGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) override;
    virtual void radialGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) override;
    
    virtual void strokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Color const &color) override;
    virtual void linearGradientStrokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) override;
    virtual void radialGradientStrokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) override;
    
    virtual void fill(CGRect const &rect, Color const &fillColor) override;
    virtual void setBlendMode(CGBlendMode blendMode) override;
    virtual void setAlpha(double alpha) override;
    virtual void concatenate(CATransform3D const &transform) override;
    
    virtual std::shared_ptr<CGImage> makeImage() const;
    virtual void draw(std::shared_ptr<CGContext> const &other, CGRect const &rect) override;
    
    CGContextRef nativeContext() const {
        return _context;
    }
    
    std::vector<uint8_t> &backingData() {
        return _backingData;
    }
    
    int bytesPerRow() {
        return _bytesPerRow;
    }
    
private:
    int _width = 0;
    int _height = 0;
    int _bytesPerRow = 0;
    std::vector<uint8_t> _backingData;
    CGContextRef _context = nil;
    CGContextRef _topContext = nil;
    CGLayerRef _layer = nil;
};

}

#endif /* CALayerCocoa_h */
