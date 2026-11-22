// The 2D canvas state machine (V5d plan, Task 1; HTML "The canvas element", the 2D context): the transform, the state
// stack, the styles, the current path and the clips, turning each drawing call into the CanvasOps a HostCanvas runs.
// Ported from twidget's portable interpreter (canvas.{h,cpp}, PROVENANCE.md), its JSON entry points replaced by one
// typed method per call. The bindings convert arguments (WebIDL) and throw what HTML throws (a negative radius, a
// zero-sized canvas source); everything here returns quietly, as HTML's drawing steps do: a non-finite argument makes
// a call do nothing.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "Sources/Canvas/CanvasOps.h"

namespace wr::canvas {

/// A 2D affine map: x' = a·x + c·y + e, y' = b·x + d·y + f.
struct Matrix {
    double a = 1, b = 0, c = 0, d = 1, e = 0, f = 0;
    /// This map, then `m`.
    Matrix then(const Matrix& m) const;
    bool invert(Matrix& out) const;
    void apply(double x, double y, double& ox, double& oy) const {
        ox = a * x + c * y + e;
        oy = b * x + d * y + f;
    }
};

/// What the interpreter asks of the runtime.
class CanvasHost {
public:
    virtual ~CanvasHost() = default;
    struct Font {
        std::shared_ptr<const HostFont> font;
        double ascent = 0, descent = 0;
    };
    /// The font a CSS `font` value stands for (the canvas's `font` attribute, already accepted); nullopt for none.
    virtual std::optional<Font> font(std::string_view css) = 0;
    virtual double textWidth(const HostFont& font, std::string_view utf8) = 0;
};

/// What a CanvasGradient holds. Its stops grow after it was made a fill or stroke style, and later draws use them, as
/// in browsers: the state keeps the object, not a copy. `None` paints nothing (a conic gradient or a pattern).
struct GradientData {
    explicit GradientData(JSRuntime* rt) : stops(JSAllocator<Stop>(rt)) {}
    enum class Kind : uint8_t { Linear, Radial, None } kind = Kind::None;
    double args[6] = {};
    /// In the JS heap (V5d final review, C3).
    Vector<Stop> stops;
    /// HTML's addColorStop after the binding checked the offset (0 to 1) and parsed the colour; at most kMaxStops,
    /// later ones ignored. Equal offsets keep their order.
    void addStop(double offset, Color color);
    static constexpr size_t kMaxStops = 256;
};

/// A path being built: the current path (points in canvas px) or a Path2D (in its own space). Its geometry is in the
/// JS heap.
struct PathData {
    explicit PathData(JSRuntime* rt) : geometry(rt) {}
    RetainedGeometry geometry;
    bool open = false;     // a subpath is open: segments append to it
    bool hasPoint = false; // there is a current point; after closePath it is the closed subpath's start
    float sx = 0, sy = 0, cx = 0, cy = 0; // the subpath's start and the current point, as stored
};

/// HTML's CanvasPath methods on `path`, each point mapped through `m` (the current transform for the current path, the
/// identity for a Path2D). A non-finite argument does nothing; the binding has refused negative radii. A path holds at
/// most kMaxPathPoints points: a segment that would pass it is dropped.
namespace path {
inline constexpr size_t kMaxPathPoints = 1'000'000;
void moveTo(PathData& p, const Matrix& m, double x, double y);
void lineTo(PathData& p, const Matrix& m, double x, double y);
void closePath(PathData& p);
void quadraticCurveTo(PathData& p, const Matrix& m, double cpx, double cpy, double x, double y);
void bezierCurveTo(PathData& p, const Matrix& m, double cp1x, double cp1y, double cp2x, double cp2y, double x, double y);
void arcTo(PathData& p, const Matrix& m, double x1, double y1, double x2, double y2, double radius);
void rect(PathData& p, const Matrix& m, double x, double y, double w, double h);
/// `radii`: HTML's normalized corner radii, upper-left, upper-right, lower-right, lower-left, each (x, y).
void roundRect(PathData& p, const Matrix& m, double x, double y, double w, double h, const std::array<double, 8>& radii);
void arc(PathData& p, const Matrix& m, double x, double y, double radius, double start, double end, bool counterclockwise);
void ellipse(PathData& p, const Matrix& m, double x, double y, double rx, double ry, double rotation, double start,
             double end, bool counterclockwise);
/// Path2D's addPath: `from`'s subpaths through `transform`, appended.
void addPath(PathData& to, const PathData& from, const Matrix& transform);
/// SVG path data (`Path2D(d)`), arcs as cubic Béziers; it stops at the first error, as SVG says.
void appendSVG(PathData& p, std::string_view d);
/// Whether (x, y) lies inside `g`, curves flattened, nonzero or even-odd.
bool contains(GeometryView g, double x, double y, bool evenodd);
} // namespace path

enum class TextAlign : uint8_t { Start, End, Left, Right, Center };
enum class TextBaseline : uint8_t { Top, Hanging, Middle, Alphabetic, Ideographic, Bottom };

/// A context's font before a script sets one.
inline constexpr std::string_view kDefaultFont = "10px sans-serif";

class CanvasInterpreter {
public:
    static constexpr size_t kMaxStack = 512;
    static constexpr size_t kMaxTextBytes = 4096;
    static constexpr size_t kMaxDash = 64;
    /// A state's clips nest at most this deep (V5d final review, C2): a clip() past it is ignored.
    static constexpr size_t kMaxClipDepth = 64;
    /// A dashed stroke makes at most this many dashes and gaps (V5d fix-wave review, C-B); past it, it is solid.
    static constexpr uint64_t kMaxDashSegments = 100000;

    /// `rt`: the JS heap the retained paths, clips and saved states live in.
    CanvasInterpreter(CanvasHost& host, JSRuntime* rt) : m_host(host), m_rt(rt), m_stack(JSAllocator<State>(rt)), m_path(rt) {}

    /// The bitmap's size; a canvas with a 0 side draws nothing.
    void setSize(int width, int height);
    int width() const { return m_width; }
    int height() const { return m_height; }
    /// HTML's "reset the rendering context to its default state": the state, the stack and the path; with `out`, also
    /// a Reset op (reset(); a resize gives the canvas a new bitmap instead).
    void reset(std::vector<CanvasOp>* out);

    // CanvasState.
    void save();
    void restore();

    // CanvasTransform.
    void scale(double x, double y);
    void rotate(double angle);
    void translate(double x, double y);
    void transform(double a, double b, double c, double d, double e, double f);
    void setTransform(double a, double b, double c, double d, double e, double f);
    void resetTransform();
    const Matrix& matrix() const { return m_state.matrix; }

    // Styles. The bindings keep what the IDL reads back; these are what draws.
    void setFillColor(Color color);
    void setStrokeColor(Color color);
    void setFillGradient(std::shared_ptr<const GradientData> gradient);
    void setStrokeGradient(std::shared_ptr<const GradientData> gradient);
    void setLineWidth(double width);
    void setLineCap(uint8_t cap);
    void setLineJoin(uint8_t join);
    void setMiterLimit(double limit);
    /// HTML's setLineDash: false (unchanged) when a value is negative or not finite, or there are more than kMaxDash.
    bool setLineDash(std::span<const double> segments);
    std::vector<double> lineDash() const;
    void setLineDashOffset(double offset);
    void setFont(SharedText css) { m_state.font = std::move(css); }
    void setFont(std::string_view css) { m_state.font = makeSharedText(m_rt, css); }
    void setTextAlign(TextAlign align) { m_state.align = align; }
    void setTextBaseline(TextBaseline baseline) { m_state.baseline = baseline; }
    void setRightToLeft(bool rtl) { m_state.rtl = rtl; }
    void setGlobalAlpha(double alpha);
    void setImageSmoothing(bool enabled) { m_state.smoothing = enabled; }

    // CanvasRect.
    void clearRect(double x, double y, double w, double h, std::vector<CanvasOp>& out);
    void fillRect(double x, double y, double w, double h, std::vector<CanvasOp>& out);
    void strokeRect(double x, double y, double w, double h, std::vector<CanvasOp>& out);

    // CanvasDrawPath. `p` null: the current path; else a Path2D, through the current transform.
    void beginPath() { m_path = PathData(m_rt); }
    PathData& currentPath() { return m_path; }
    void fill(const PathData* p, bool evenodd, std::vector<CanvasOp>& out);
    void stroke(const PathData* p, std::vector<CanvasOp>& out);
    /// False, clipping nothing, when the chain is kMaxClipDepth deep already.
    bool clip(const PathData* p, bool evenodd);
    bool isPointInPath(const PathData* p, double x, double y, bool evenodd) const;
    bool isPointInStroke(const PathData* p, double x, double y) const;

    // CanvasText. `maxWidth` as given (absent: nullopt).
    void fillText(std::string_view text, double x, double y, std::optional<double> maxWidth, std::vector<CanvasOp>& out);
    void strokeText(std::string_view text, double x, double y, std::optional<double> maxWidth, std::vector<CanvasOp>& out);

    // CanvasDrawImage: `source` of `sourceWidth` × `sourceHeight` (its intrinsic size), the source rect (sx, sy, sw,
    // sh) into the destination rect; the 3- and 5-argument forms pass the whole source.
    void drawImage(std::shared_ptr<const HostImage> source, double sourceWidth, double sourceHeight, double sx, double sy,
                   double sw, double sh, double dx, double dy, double dw, double dh, std::vector<CanvasOp>& out);

private:
    struct Style {
        bool gradient = false;
        Color color{0, 0, 0, 255};
        std::shared_ptr<const GradientData> data;
    };
    struct State {
        Matrix matrix;
        Style fill, stroke;
        // Shared with the states saved from this one (V5d fix-wave review, I-C); none is the default, kDefaultFont.
        SharedText font;
        TextAlign align = TextAlign::Start;
        TextBaseline baseline = TextBaseline::Alphabetic;
        bool rtl = false;
        std::shared_ptr<const Vector<float>> dash;
        float dashOffset = 0;
        float lineWidth = 1;
        uint8_t lineCap = 0, lineJoin = 0;
        float miterLimit = 10;
        float alpha = 1;
        bool smoothing = true;
        std::shared_ptr<const ClipNode> clip;
    };

    bool drawable() const { return m_width > 0 && m_height > 0; }
    std::span<const float> dash() const { return m_state.dash ? std::span<const float>(*m_state.dash) : std::span<const float>(); }
    CanvasOp op(CanvasOp::Kind kind) const;
    static Paint paintOf(const Style& style);
    void fillGeometry(Geometry path, bool evenodd, std::vector<CanvasOp>& out);
    void strokeGeometry(Geometry path, std::vector<CanvasOp>& out);
    void text(std::string_view text, double x, double y, std::optional<double> maxWidth, bool stroke,
              std::vector<CanvasOp>& out);
    Geometry rectGeometry(double x, double y, double w, double h) const;
    void concat(const Matrix& m);

    CanvasHost& m_host;
    JSRuntime* m_rt;
    int m_width = 300, m_height = 150;
    State m_state;
    /// In the JS heap (V5d final review, C2); a state's strings and dash are capped.
    Vector<State> m_stack;
    /// Saves past kMaxStack: each pops nothing, so restores stay balanced.
    size_t m_overflowedSaves = 0;
    PathData m_path;
};

} // namespace wr::canvas
