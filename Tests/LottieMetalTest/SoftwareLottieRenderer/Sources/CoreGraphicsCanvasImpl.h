#ifndef CoreGraphicsCanvasImpl_h
#define CoreGraphicsCanvasImpl_h

#include "Canvas.h"

namespace lottieRendering {

class ImageImpl: public Image {
public:
    ImageImpl(::CGImageRef image);
    virtual ~ImageImpl();
    ::CGImageRef nativeImage() const;
    
private:
    CGImageRef _image = nil;
};

class CanvasImpl: public Canvas {
public:
    CanvasImpl(int width, int height);
    CanvasImpl(CGContextRef context, int width, int height);
    virtual ~CanvasImpl();
    
    virtual int width() const override;
    virtual int height() const override;
    
    std::shared_ptr<Canvas> makeLayer(int width, int height) override;
    
    virtual void saveState() override;
    virtual void restoreState() override;
    
    virtual void fillPath(std::shared_ptr<lottie::CGPath> const &path, FillRule fillRule, Color const &color) override;
    virtual void linearGradientFillPath(std::shared_ptr<lottie::CGPath> const &path, FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientFillPath(std::shared_ptr<lottie::CGPath> const &path, FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, double startRadius, lottie::Vector2D const &endCenter, double endRadius) override;
    
    virtual void strokePath(std::shared_ptr<lottie::CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Color const &color) override;
    virtual void linearGradientStrokePath(std::shared_ptr<lottie::CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientStrokePath(std::shared_ptr<lottie::CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, double startRadius, lottie::Vector2D const &endCenter, double endRadius) override;
    
    virtual void fill(lottie::CGRect const &rect, Color const &fillColor) override;
    virtual void setBlendMode(BlendMode blendMode) override;
    virtual void setAlpha(double alpha) override;
    virtual void concatenate(lottie::CATransform3D const &transform) override;
    
    virtual std::shared_ptr<Image> makeImage() const;
    virtual void draw(std::shared_ptr<Canvas> const &other, lottie::CGRect const &rect) override;
    
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

#endif
