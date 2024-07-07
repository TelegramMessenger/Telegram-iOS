#ifndef CoreGraphicsCoreGraphicsCanvasImpl_h
#define CoreGraphicsCoreGraphicsCanvasImpl_h

#include <LottieCpp/LottieCpp.h>

#include <QuartzCore/QuartzCore.h>

namespace lottie {

class CoreGraphicsCanvasImpl: public Canvas {
class Layer;
    
public:
    class Image {
    public:
        Image(::CGImageRef image);
        virtual ~Image();
        ::CGImageRef nativeImage() const;
        
    private:
        CGImageRef _image = nil;
    };
    
public:
    CoreGraphicsCanvasImpl(int width, int height);
    virtual ~CoreGraphicsCanvasImpl();
    
    virtual void saveState() override;
    virtual void restoreState() override;
    
    virtual void fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) override;
    virtual void linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, Vector2D const &center, float radius) override;
    
    virtual void strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) override;
    virtual void linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) override;
    
    virtual void clip(CGRect const &rect) override;
    virtual bool clipPath(CanvasPathEnumerator const &enumeratePath, FillRule fillRule, Transform2D const &transform) override;
    virtual void concatenate(lottie::Transform2D const &transform) override;
    
    virtual std::shared_ptr<Image> makeImage();
    
    virtual bool pushLayer(CGRect const &rect, float alpha, std::optional<MaskMode> maskMode) override;
    virtual void popLayer() override;
    
    std::vector<uint8_t> &backingData();
    int bytesPerRow();
    
private:
    std::shared_ptr<Layer> &currentLayer();
    
private:
    int _width = 0;
    int _height = 0;
    CGContextRef _topContext = nil;
    std::vector<std::shared_ptr<Layer>> _layerStack;
};

}

#endif
