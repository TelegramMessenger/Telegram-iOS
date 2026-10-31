// Canvas 2D's resolved drawing operations (V5d plan, Task 1): what the interpreter (CanvasInterpreter.h) makes of the
// widget's calls and a HostCanvas executes. Geometry is in canvas pixels with the current transform applied, so a
// bitmap only fills, strokes, clips and blits. Ported from twidget's canvas_ops.h (PROVENANCE.md), without what profile
// 1 never draws: compositing, shadows and putImageData.
#pragma once

#include <cstdint>
#include <memory>
#include <span>
#include <string>
#include <vector>

#include "Sources/Support/Allocator.h"

namespace wr {
class HostFont;
class HostImage;
} // namespace wr

namespace wr::canvas {

struct Color {
    uint8_t r = 0, g = 0, b = 0, a = 255;
    friend bool operator==(const Color&, const Color&) = default;
};

struct Stop {
    float offset = 0;
    Color color;
};

enum class PathVerb : uint8_t { Move, Line, Quad, Cubic, Close };

/// A path's verbs and points, whichever container holds them: Move and Line take one point, Quad two, Cubic three,
/// Close none.
struct GeometryView {
    std::span<const PathVerb> verbs;
    std::span<const float> points;
    bool empty() const { return verbs.empty(); }
};

/// A path an op carries: transient, made and dropped within one call.
struct Geometry {
    std::vector<PathVerb> verbs;
    std::vector<float> points;
    bool empty() const { return verbs.empty(); }
    GeometryView view() const { return {verbs, points}; }
};

/// A path a canvas keeps between calls (a Path2D, the current path, a clip; V5d final review, C2 and C3): in the JS
/// heap, so the widget's memory limit bounds it.
struct RetainedGeometry {
    explicit RetainedGeometry(JSRuntime* rt) : verbs(JSAllocator<PathVerb>(rt)), points(JSAllocator<float>(rt)) {}
    Vector<PathVerb> verbs;
    Vector<float> points;
    bool empty() const { return verbs.empty(); }
    GeometryView view() const { return {std::span<const PathVerb>(verbs.data(), verbs.size()), std::span<const float>(points.data(), points.size())}; }
};

/// What a fill or stroke paints. Linear: x0, y0, x1, y1; radial: x0, y0, r0, x1, y1, r1; both in user space (under the
/// op's matrix). Stops are sorted by offset. A gradient that paints nothing (no stops, no length, a conic gradient or a
/// pattern, which profile 1 leaves out) is a transparent solid.
struct Paint {
    enum class Kind : uint8_t { Solid, Linear, Radial } kind = Kind::Solid;
    Color color;
    float args[6] = {};
    std::vector<Stop> stops;
};

/// One clip of a state's chain, in canvas pixels; a clip intersects every one above it. A clip() adds one node and a
/// save() shares the chain, so neither copies the clips before it.
struct ClipNode {
    ClipNode(RetainedGeometry path, bool evenodd, std::shared_ptr<const ClipNode> parent)
        : path(std::move(path)), evenodd(evenodd), parent(std::move(parent)), depth(this->parent ? this->parent->depth + 1 : 1) {}
    RetainedGeometry path;
    bool evenodd;
    std::shared_ptr<const ClipNode> parent;
    /// The chain's length up to and including this node.
    size_t depth;
};

struct CanvasOp {
    enum class Kind : uint8_t {
        Reset,  // the whole bitmap to transparent
        Fill,   // `path` (canvas px) with `paint`, nonzero or `evenodd`
        Stroke, // `path` (canvas px) with `paint` and the line style; the width is in user space, under `matrix`
        Clear,  // `path`: the area to make transparent (canvas px)
        Text,   // `text` in `font`, its baseline origin at (x, y) user space: drawn at `textDx` from there, under
                // a horizontal scale of `scaleX` about (x, y), so the alignment offset scales with the text
        Image,  // `source` (sx, sy, sw, sh of its sourceWidth × sourceHeight) into (dx, dy, dw, dh) user space
    } kind = Kind::Fill;

    Geometry path;
    bool evenodd = false;
    Paint paint;
    /// User space to canvas px: a, b, c, d, e, f.
    float matrix[6] = {1, 0, 0, 1, 0, 0};
    float alpha = 1;
    /// The innermost clip of the chain (it and its parents intersect); null: no clip.
    std::shared_ptr<const ClipNode> clip;

    // Stroke, and strokeText.
    float lineWidth = 1;
    uint8_t lineCap = 0;  // 0 butt, 1 round, 2 square
    uint8_t lineJoin = 0; // 0 miter, 1 round, 2 bevel
    float miterLimit = 10;
    std::vector<float> dashes;
    float dashOffset = 0;
    /// The dash was dropped: more than CanvasInterpreter::kMaxDashSegments, so the stroke is solid.
    bool dashDropped = false;

    // Text.
    std::shared_ptr<const HostFont> font;
    std::string text;
    float x = 0, y = 0, scaleX = 1, textDx = 0;
    bool strokeText = false;

    // Image. The source rect lies inside the source (the interpreter clipped it, as HTML says).
    std::shared_ptr<const HostImage> source;
    float sourceWidth = 0, sourceHeight = 0;
    float sx = 0, sy = 0, sw = 0, sh = 0;
    float dx = 0, dy = 0, dw = 0, dh = 0;
    bool smoothing = true;
};

} // namespace wr::canvas
