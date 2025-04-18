#ifndef SkiaCanvasImpl_h
#define SkiaCanvasImpl_h

#include <LottieCpp/LottieCpp.h>

#include "include/core/SkCanvas.h"
#include "include/core/SkSurface.h"

namespace lottie {

class SkiaCanvasImpl: public Canvas {
public:
    SkiaCanvasImpl(int width, int height);
    SkiaCanvasImpl(int width, int height, int bytesPerRow, void *pixelData);
    virtual ~SkiaCanvasImpl();
    
    virtual void saveState() override;
    virtual void restoreState() override;
    
    virtual void fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) override;
    virtual void linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Gradient const &gradient, Vector2D const &center, float radius) override;
    virtual void strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) override;
    virtual void linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) override;
    virtual void radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) override;
    
    virtual void clip(CGRect const &rect) override;
    virtual bool clipPath(CanvasPathEnumerator const &enumeratePath, FillRule fillRule, Transform2D const &transform) override;
    virtual void concatenate(lottie::Transform2D const &transform) override;
    
    virtual bool pushLayer(CGRect const &rect, float alpha, std::optional<MaskMode> maskMode) override;
    virtual void popLayer() override;
    
    void flush();
    sk_sp<SkSurface> surface() const;
    
private:
    void *_pixelData = nullptr;
    bool _ownsPixelData = false;
    sk_sp<SkSurface> _surface;
    SkCanvas *_canvas = nullptr;
};

}

#endif
