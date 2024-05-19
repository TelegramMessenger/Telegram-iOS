#ifndef Canvas_h
#define Canvas_h

#include <LottieCpp/LottieCpp.h>

#include <memory>
#include <vector>
#include <cassert>
#include <functional>

namespace lottieRendering {

class Image {
public:
    virtual ~Image() = default;
};

class Gradient {
public:
    Gradient(std::vector<lottie::Color> const &colors, std::vector<float> const &locations) :
    _colors(colors),
    _locations(locations) {
        assert(_colors.size() == _locations.size());
    }
    
    std::vector<lottie::Color> const &colors() const {
        return _colors;
    }
    
    std::vector<float> const &locations() const {
        return _locations;
    }
    
private:
    std::vector<lottie::Color> _colors;
    std::vector<float> _locations;
};

enum class BlendMode {
    Normal,
    DestinationIn,
    DestinationOut
};

enum class PathCommandType {
    MoveTo,
    LineTo,
    CurveTo,
    Close
};

typedef struct {
    PathCommandType type;
    CGPoint points[4];
} PathCommand;

typedef std::function<void(std::function<void(PathCommand const &)>)> CanvasPathEnumerator;

class Canvas {
public:
    virtual ~Canvas() = default;
    
    virtual int width() const = 0;
    virtual int height() const = 0;
    
    virtual std::shared_ptr<Canvas> makeLayer(int width, int height) = 0;
    
    virtual void saveState() = 0;
    virtual void restoreState() = 0;
    
    virtual void fillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, lottie::Color const &color) = 0;
    virtual void linearGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) = 0;
    virtual void radialGradientFillPath(CanvasPathEnumerator const &enumeratePath, lottie::FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) = 0;
    
    virtual void strokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, lottie::Color const &color) = 0;
    virtual void linearGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) = 0;
    virtual void radialGradientStrokePath(CanvasPathEnumerator const &enumeratePath, float lineWidth, lottie::LineJoin lineJoin, lottie::LineCap lineCap, float dashPhase, std::vector<float> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, float startRadius, lottie::Vector2D const &endCenter, float endRadius) = 0;
    
    virtual void fill(lottie::CGRect const &rect, lottie::Color const &fillColor) = 0;
    virtual void setBlendMode(BlendMode blendMode) = 0;
    
    virtual void setAlpha(float alpha) = 0;
    
    virtual void concatenate(lottie::Transform2D const &transform) = 0;
    
    virtual void draw(std::shared_ptr<Canvas> const &other, lottie::CGRect const &rect) = 0;
};

}

#endif

