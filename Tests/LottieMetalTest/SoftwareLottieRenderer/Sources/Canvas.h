#ifndef Canvas_h
#define Canvas_h

#include <LottieCpp/LottieCpp.h>

#include <memory>
#include <vector>
#include <cassert>

namespace lottieRendering {

struct Color {
    double r;
    double g;
    double b;
    double a;
    
    Color(double r_, double g_, double b_, double a_) :
    r(r_), g(g_), b(b_), a(a_) {
    }
    
    bool operator==(Color const &rhs) const {
        if (r != rhs.r) {
            return false;
        }
        if (g != rhs.g) {
            return false;
        }
        if (b != rhs.b) {
            return false;
        }
        if (a != rhs.a) {
            return false;
        }
        return true;
    }
    
    bool operator!=(Color const &rhs) const {
        return !(*this == rhs);
    }
};

enum class BlendMode {
    Normal,
    DestinationIn,
    DestinationOut
};

enum class FillRule: int {
    None = 0,
    NonZeroWinding = 1,
    EvenOdd = 2
};

enum class LineCap: int {
    None = 0,
    Butt = 1,
    Round = 2,
    Square = 3
};

enum class LineJoin: int {
    None = 0,
    Miter = 1,
    Round = 2,
    Bevel = 3
};

class Image {
public:
    virtual ~Image() = default;
};

class Gradient {
public:
    Gradient(std::vector<Color> const &colors, std::vector<double> const &locations) :
    _colors(colors),
    _locations(locations) {
        assert(_colors.size() == _locations.size());
    }
    
    std::vector<Color> const &colors() const {
        return _colors;
    }
    
    std::vector<double> const &locations() const {
        return _locations;
    }
    
private:
    std::vector<Color> _colors;
    std::vector<double> _locations;
};

class Canvas {
public:
    virtual ~Canvas() = default;
    
    virtual int width() const = 0;
    virtual int height() const = 0;
    
    virtual std::shared_ptr<Canvas> makeLayer(int width, int height) = 0;
    
    virtual void saveState() = 0;
    virtual void restoreState() = 0;
    
    virtual void fillPath(std::shared_ptr<lottie::CGPath> const &path, FillRule fillRule, Color const &color) = 0;
    virtual void linearGradientFillPath(std::shared_ptr<lottie::CGPath> const &path, FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) = 0;
    virtual void radialGradientFillPath(std::shared_ptr<lottie::CGPath> const &path, FillRule fillRule, Gradient const &gradient, lottie::Vector2D const &startCenter, double startRadius, lottie::Vector2D const &endCenter, double endRadius) = 0;
    
    virtual void strokePath(std::shared_ptr<lottie::CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Color const &color) = 0;
    virtual void linearGradientStrokePath(std::shared_ptr<lottie::CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &start, lottie::Vector2D const &end) = 0;
    virtual void radialGradientStrokePath(std::shared_ptr<lottie::CGPath> const &path, double lineWidth, LineJoin lineJoin, LineCap lineCap, double dashPhase, std::vector<double> const &dashPattern, Gradient const &gradient, lottie::Vector2D const &startCenter, double startRadius, lottie::Vector2D const &endCenter, double endRadius) = 0;
    
    virtual void fill(lottie::CGRect const &rect, Color const &fillColor) = 0;
    virtual void setBlendMode(BlendMode blendMode) = 0;
    
    virtual void setAlpha(double alpha) = 0;
    
    virtual void concatenate(lottie::CATransform3D const &transform) = 0;
    
    virtual void draw(std::shared_ptr<Canvas> const &other, lottie::CGRect const &rect) = 0;
};

}

#endif

