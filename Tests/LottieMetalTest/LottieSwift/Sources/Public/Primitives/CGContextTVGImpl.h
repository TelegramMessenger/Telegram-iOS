#ifndef CGContextTVGImpl_h
#define CGContextTVGImpl_h

#include "Lottie/Public/Primitives/CALayer.hpp"

#include "thorvg.h"

namespace lottie {

class CGContextTVGImpl: public CGContext {
public:
    CGContextTVGImpl(int width, int height);
    virtual ~CGContextTVGImpl();
    
    virtual int width() const override;
    virtual int height() const override;
    
    virtual std::shared_ptr<CGContext> makeLayer(int width, int height) override;
    
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
    
    virtual void draw(std::shared_ptr<CGContext> const &other, CGRect const &rect) override;
    
    uint32_t *backingData() {
        return _backingData;
    }
    
    int bytesPerRow() const {
        return _bytesPerRow;
    }
    
    void flush();
    
private:
    int _width = 0;
    int _height = 0;
    std::unique_ptr<tvg::SwCanvas> _canvas;

    //SkBlendMode _blendMode = SkBlendMode::kSrcOver;
    double _alpha = 1.0;
    CATransform3D _transform;
    std::vector<CATransform3D> _stateStack;
    int _bytesPerRow = 0;
    uint32_t *_backingData = nullptr;
    int _statsNumStrokes = 0;
};

}

#endif
