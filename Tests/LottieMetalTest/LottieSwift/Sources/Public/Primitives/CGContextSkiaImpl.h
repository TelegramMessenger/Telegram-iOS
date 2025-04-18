#ifndef CGContextSkiaImpl_h
#define CGContextSkiaImpl_h

#include "Lottie/Public/Primitives/CALayer.hpp"

#include "include/core/SkCanvas.h"
#include "include/core/SkSurface.h"

namespace lottie {

class CGContextSkiaImpl: public CGContext {
public:
    CGContextSkiaImpl(int width, int height);
    virtual ~CGContextSkiaImpl();
    
    virtual int width() const override;
    virtual int height() const override;
    
    virtual std::shared_ptr<CGContext> makeLayer(int width, int height) override;
    
    virtual void saveState() override;
    virtual void restoreState() override;
    
    virtual void fillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, Color const &color) override;
    virtual void linearGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &start, Vector2D const &end) override;
    virtual void radialGradientFillPath(std::shared_ptr<CGPath> const &path, FillRule fillRule, CGGradient const &gradient, Vector2D const &startCenter, double startRadius, Vector2D const &endCenter, double endRadius) override;
    virtual void strokePath(std::shared_ptr<CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Color const &color) override;
    virtual void fill(CGRect const &rect, Color const &fillColor) override;
    
    virtual void setBlendMode(CGBlendMode blendMode) override;
    
    virtual void setAlpha(double alpha) override;
    
    virtual void concatenate(CATransform3D const &transform) override;
    
    virtual void draw(std::shared_ptr<CGContext> const &other, CGRect const &rect) override;
    
    sk_sp<SkSurface> surface() const;
    
private:
    int _width = 0;
    int _height = 0;
    sk_sp<SkSurface> _surface;
    SkCanvas *_canvas = nullptr;
    SkBlendMode _blendMode = SkBlendMode::kSrcOver;
    double _alpha = 1.0;
};

}

#endif
