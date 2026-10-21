// The 2D context's objects (V5d plan, Task 3): CanvasGradient, CanvasPattern, Path2D, TextMetrics and ImageData.
#pragma once

#include <memory>
#include <optional>
#include <variant>

#include "Sources/Canvas/CanvasInterpreter.h"
#include "Sources/Support/Bindings.h"

namespace wr {

namespace idl {
struct DOMMatrix2DInit;
} // namespace idl

/// A gradient: its data is shared with every state that uses it as a style, so stops added later reach later draws. A
/// conic gradient (profile 1: out) is GradientData::Kind::None and paints nothing.
class CanvasGradient : public PlatformObject {
public:
    explicit CanvasGradient(std::shared_ptr<canvas::GradientData> data) : m_data(std::move(data)) {}
    void dispose(JSRuntime*) override { m_data.reset(); }
    /// HTML: an offset outside 0…1 is an IndexSizeError, a colour that does not parse a SyntaxError.
    void addColorStop(JSContext* ctx, double offset, String color);
    const std::shared_ptr<canvas::GradientData>& data() const { return m_data; }

private:
    std::shared_ptr<canvas::GradientData> m_data;
};

/// A pattern (profile 1: out): it paints nothing, and its transform is accepted and ignored.
class CanvasPattern : public PlatformObject {
public:
    void setTransform(JSContext* ctx, const idl::DOMMatrix2DInit& transform);
};

/// HTML's DOMMatrix2DInit "validate and fixup": m11 … m42 from a … f where only one is given, a TypeError where both are
/// given and differ; absent members are the identity's. Out: a, b, c, d, e, f.
canvas::Matrix matrixFromInit(const idl::DOMMatrix2DInit& init);

class Path2D : public PlatformObject {
public:
    explicit Path2D(JSRuntime* rt) : m_data(rt) {}
    /// Path data (`new Path2D(d)`) longer than this, in UTF-16 units, makes an empty path (widget-sandbox v0.1.0's limit).
    static constexpr uint32_t kMaxPathData = 65536;
    static Ref<Path2D> construct(JSContext* ctx, std::optional<std::variant<Path2D*, String>> path);
    void addPath(JSContext* ctx, Path2D* path, const idl::DOMMatrix2DInit& transform);

    // CanvasPath, in the path's own space.
    void closePath(JSContext* ctx);
    void moveTo(JSContext* ctx, Unrestricted x, Unrestricted y);
    void lineTo(JSContext* ctx, Unrestricted x, Unrestricted y);
    void quadraticCurveTo(JSContext* ctx, Unrestricted cpx, Unrestricted cpy, Unrestricted x, Unrestricted y);
    void bezierCurveTo(JSContext* ctx, Unrestricted cp1x, Unrestricted cp1y, Unrestricted cp2x, Unrestricted cp2y, Unrestricted x,
                       Unrestricted y);
    void arcTo(JSContext* ctx, Unrestricted x1, Unrestricted y1, Unrestricted x2, Unrestricted y2, Unrestricted radius);
    void rect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h);
    void roundRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h, std::optional<Value> radii);
    void arc(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted radius, Unrestricted start, Unrestricted end,
             bool counterclockwise);
    void ellipse(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted rx, Unrestricted ry, Unrestricted rotation,
                 Unrestricted start, Unrestricted end, bool counterclockwise);

    const canvas::PathData& data() const { return m_data; }
    canvas::PathData& data() { return m_data; }

private:
    canvas::PathData m_data;
};

/// The CanvasPath operations both a context and a Path2D give, with HTML's argument checks: a non-finite argument does
/// nothing, a negative radius is an IndexSizeError (roundRect's, a RangeError), roundRect's radii are normalized to its
/// four corners. `m` maps the arguments into the path's space.
namespace pathcalls {
void arcTo(canvas::PathData& p, const canvas::Matrix& m, double x1, double y1, double x2, double y2, double radius);
void roundRect(JSContext* ctx, canvas::PathData& p, const canvas::Matrix& m, double x, double y, double w, double h,
               const std::optional<Value>& radii);
void arc(canvas::PathData& p, const canvas::Matrix& m, double x, double y, double radius, double start, double end, bool ccw);
void ellipse(canvas::PathData& p, const canvas::Matrix& m, double x, double y, double rx, double ry, double rotation,
             double start, double end, bool ccw);
} // namespace pathcalls

class TextMetrics : public PlatformObject {
public:
    struct Values {
        double width = 0, left = 0, right = 0, fontAscent = 0, fontDescent = 0, ascent = 0, descent = 0, emAscent = 0,
               emDescent = 0, hanging = 0, alphabetic = 0, ideographic = 0;
    };
    explicit TextMetrics(const Values& v) : m_v(v) {}
    double width(JSContext*) const { return m_v.width; }
    double actualBoundingBoxLeft(JSContext*) const { return m_v.left; }
    double actualBoundingBoxRight(JSContext*) const { return m_v.right; }
    double fontBoundingBoxAscent(JSContext*) const { return m_v.fontAscent; }
    double fontBoundingBoxDescent(JSContext*) const { return m_v.fontDescent; }
    double actualBoundingBoxAscent(JSContext*) const { return m_v.ascent; }
    double actualBoundingBoxDescent(JSContext*) const { return m_v.descent; }
    double emHeightAscent(JSContext*) const { return m_v.emAscent; }
    double emHeightDescent(JSContext*) const { return m_v.emDescent; }
    double hangingBaseline(JSContext*) const { return m_v.hanging; }
    double alphabeticBaseline(JSContext*) const { return m_v.alphabetic; }
    double ideographicBaseline(JSContext*) const { return m_v.ideographic; }

private:
    Values m_v;
};

/// Pixels a script holds (profile 1: read back as transparent, and put nowhere). At most kMaxPixels, a RangeError beyond.
class ImageData : public PlatformObject {
public:
    static constexpr uint64_t kMaxPixels = 3'500'000;
    /// (sw, sh[, settings]) or (data, sw[, sh][, settings]).
    static Ref<ImageData> construct(JSContext* ctx, Value a, Value b, std::optional<Value> c, std::optional<Value> d);
    /// A transparent w × h ImageData; a 0 side is an IndexSizeError, more than kMaxPixels a RangeError.
    static Ref<ImageData> make(JSContext* ctx, uint32_t width, uint32_t height);
    uint32_t width(JSContext*) const { return m_width; }
    uint32_t height(JSContext*) const { return m_height; }
    Value data(JSContext* ctx) const { return Value::dup(ctx, m_data.value); }
    String colorSpace(JSContext* ctx) const { return String::fromUTF8(ctx, "srgb"); }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override { m_data.mark(rt, mark); }
    void dispose(JSRuntime* rt) override { m_data.clear(rt); }

    ImageData(uint32_t width, uint32_t height) : m_width(width), m_height(height) {}
    Held m_data;

private:
    uint32_t m_width, m_height;
};

} // namespace wr
