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
    
    virtual void fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) override;
    virtual void linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) override;
    
    virtual void strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) override;
    virtual void linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) override;
    
    virtual void fill(lottie::CGRect const &rect, lottie::Color const &fillColor) override;
    virtual void setBlendMode(BlendMode blendMode) override;
    virtual void setAlpha(float alpha) override;
    virtual void concatenate(lottie::Transform2D const &transform) override;
    
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
