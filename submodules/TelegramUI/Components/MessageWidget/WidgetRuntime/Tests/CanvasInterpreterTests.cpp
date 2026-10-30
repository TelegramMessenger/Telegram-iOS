// The canvas interpreter (V5d plan, Task 1): the transform, the state stack, path building, hit tests, line dashes,
// gradients, text placement, the caps, and the ops each call becomes. No JS: a fake host answers fonts and colours.
#include <cmath>
#include <cstdlib>
#include <string>

#include "Sources/Canvas/CanvasInterpreter.h"
#include "quickjs.h"
#include "Sources/Render/RenderHost.h"
#include "Tests/wr_test.h"

using namespace wr::canvas;

namespace {

class FakeFont final : public wr::HostFont {};

/// Fonts ascent 12, descent 4, 8 px per byte.
class FakeCanvasHost final : public CanvasHost {
public:
    std::optional<Font> font(std::string_view) override { return Font{std::make_shared<FakeFont>(), 12, 4}; }
    double textWidth(const wr::HostFont&, std::string_view utf8) override { return 8.0 * double(utf8.size()); }
};

bool near(double a, double b) { return std::fabs(a - b) < 1e-4; }

/// A JS heap for the retained paths, clips and saved states; declared before the interpreter, so it goes after it.
struct Heap {
    JSRuntime* rt = JS_NewRuntime();
    ~Heap() { JS_FreeRuntime(rt); }
};

std::string verbs(GeometryView g) {
    std::string s;
    for (PathVerb v : g.verbs) {
        s += "MLQCZ"[int(v)];
    }
    return s;
}

/// The bounds of a geometry's points.
struct Bounds {
    double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
};
Bounds bounds(GeometryView g) {
    Bounds b;
    for (size_t i = 0; i + 1 < g.points.size(); i += 2) {
        b.minX = std::min(b.minX, double(g.points[i]));
        b.maxX = std::max(b.maxX, double(g.points[i]));
        b.minY = std::min(b.minY, double(g.points[i + 1]));
        b.maxY = std::max(b.maxY, double(g.points[i + 1]));
    }
    return b;
}

} // namespace

WR_TEST(testTransformsCompose) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    c.scale(2, 2);
    c.translate(10, 0);
    c.rotate(M_PI / 2);
    const Matrix& m = c.matrix();
    CHECK(near(m.a, 0) && near(m.b, 2) && near(m.c, -2) && near(m.d, 0) && near(m.e, 20) && near(m.f, 0));
    c.save();
    c.scale(3, 3);
    c.restore();
    CHECK(near(c.matrix().b, 2));
    c.setTransform(1, 0, 0, 1, 5, 5);
    CHECK(near(c.matrix().a, 1) && near(c.matrix().e, 5) && near(c.matrix().f, 5));
    c.resetTransform();
    CHECK(near(c.matrix().e, 0) && near(c.matrix().b, 0));
    // HTML: a non-finite argument makes the call do nothing.
    c.translate(NAN, 1);
    c.scale(INFINITY, 1);
    c.setTransform(1, 0, 0, 1, NAN, 0);
    CHECK(near(c.matrix().a, 1) && near(c.matrix().e, 0) && near(c.matrix().f, 0));
}

WR_TEST(testRectsBecomeOps) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    c.setSize(160, 120);
    c.scale(2, 2);
    std::vector<CanvasOp> out;
    c.fillRect(8, 8, 40, 30, out);
    CHECK_EQ(out.size(), size_t(1));
    CHECK(out[0].kind == CanvasOp::Kind::Fill);
    CHECK(out[0].paint.kind == Paint::Kind::Solid && out[0].paint.color == (Color{0, 0, 0, 255}));
    Bounds b = bounds(out[0].path.view());
    CHECK(near(b.minX, 16) && near(b.minY, 16) && near(b.maxX, 96) && near(b.maxY, 76));
    c.clearRect(0, 0, 10, 10, out);
    CHECK(out.back().kind == CanvasOp::Kind::Clear);
    c.setLineWidth(4);
    c.strokeRect(30, 20, 40, 30, out);
    CHECK(out.back().kind == CanvasOp::Kind::Stroke && near(out.back().lineWidth, 4) && near(out.back().matrix[0], 2));
    c.fillRect(NAN, 0, 1, 1, out);
    CHECK_EQ(out.size(), size_t(3));
    // globalAlpha reaches the next op; an out-of-range one is ignored.
    c.setGlobalAlpha(0.5);
    c.setGlobalAlpha(2);
    c.fillRect(0, 0, 1, 1, out);
    CHECK(near(out.back().alpha, 0.5));
}

WR_TEST(testPathsAndArcs) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    std::vector<CanvasOp> out;
    path::arc(c.currentPath(), c.matrix(), 20, 20, 14, 0, M_PI * 1.5, false);
    path::lineTo(c.currentPath(), c.matrix(), 20, 20);
    path::closePath(c.currentPath());
    c.fill(nullptr, false, out);
    CHECK_EQ(verbs(out.back().path.view()), std::string("MCCCLZ"));
    c.beginPath();
    path::moveTo(c.currentPath(), c.matrix(), 40, 50);
    path::bezierCurveTo(c.currentPath(), c.matrix(), 50, 10, 70, 10, 76, 50);
    path::quadraticCurveTo(c.currentPath(), c.matrix(), 60, 58, 40, 50);
    c.stroke(nullptr, out);
    CHECK_EQ(verbs(out.back().path.view()), std::string("MCQ"));
    c.beginPath();
    path::ellipse(c.currentPath(), c.matrix(), 20, 46, 14, 8, 0.3, 0, M_PI * 2, false);
    CHECK_EQ(verbs(c.currentPath().geometry.view()), std::string("MCCCC"));
    c.beginPath();
    path::moveTo(c.currentPath(), c.matrix(), 0, 0);
    path::arcTo(c.currentPath(), c.matrix(), 10, 0, 10, 10, 5);
    CHECK_EQ(verbs(c.currentPath().geometry.view()), std::string("MLC"));
    c.beginPath();
    path::roundRect(c.currentPath(), c.matrix(), 0, 0, 20, 10, {4, 4, 4, 4, 4, 4, 4, 4});
    CHECK_EQ(verbs(c.currentPath().geometry.view()), std::string("MLCLCLCLCZ"));
    // A segment with no current point starts its subpath at its own first point.
    c.beginPath();
    path::lineTo(c.currentPath(), c.matrix(), 5, 5);
    CHECK_EQ(verbs(c.currentPath().geometry.view()), std::string("ML"));
    // SVG path data, as Path2D(d) takes it.
    PathData svg(heap.rt);
    path::appendSVG(svg, "M10 50 L40 8 L70 50 Z");
    CHECK_EQ(verbs(svg.geometry.view()), std::string("MLLZ"));
    PathData relative(heap.rt);
    path::appendSVG(relative, "m10,10 h5 v5 a2 2 0 0 1 4 0 x 9");
    CHECK_EQ(verbs(relative.geometry.view()).substr(0, 3), std::string("MLL"));
}

WR_TEST(testHitTests) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    path::rect(c.currentPath(), c.matrix(), 5, 5, 10, 10);
    CHECK(c.isPointInPath(nullptr, 10, 10, false));
    CHECK(!c.isPointInPath(nullptr, 30, 10, false));
    c.setLineWidth(4);
    CHECK(c.isPointInStroke(nullptr, 5, 10));
    CHECK(!c.isPointInStroke(nullptr, 10, 10));
    CHECK(!c.isPointInPath(nullptr, NAN, 10, false));
    // A donut: two squares the same way round are inside by nonzero and outside by even-odd in the middle.
    PathData donut(heap.rt);
    path::rect(donut, Matrix(), 0, 0, 30, 30);
    path::rect(donut, Matrix(), 10, 10, 10, 10);
    CHECK(c.isPointInPath(&donut, 15, 15, false));
    CHECK(!c.isPointInPath(&donut, 15, 15, true));
    CHECK(c.isPointInPath(&donut, 5, 5, true));
    // A Path2D is tested through the current transform.
    c.translate(100, 0);
    CHECK(c.isPointInPath(&donut, 105, 5, false));
}

WR_TEST(testLineDash) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    const double odd[] = {1, 2, 3};
    CHECK(c.setLineDash(odd));
    CHECK_EQ(c.lineDash().size(), size_t(6));
    CHECK(near(c.lineDash()[3], 1) && near(c.lineDash()[5], 3));
    const double negative[] = {1, -1};
    const double nonFinite[] = {1, NAN};
    CHECK(!c.setLineDash(negative));
    CHECK(!c.setLineDash(nonFinite));
    std::vector<double> many(65, 1);
    CHECK(!c.setLineDash(many));
    CHECK_EQ(c.lineDash().size(), size_t(6));
    std::vector<CanvasOp> out;
    path::moveTo(c.currentPath(), c.matrix(), 0, 0);
    path::lineTo(c.currentPath(), c.matrix(), 10, 0);
    c.stroke(nullptr, out);
    CHECK_EQ(out.back().dashes.size(), size_t(6));
}

WR_TEST(testGradients) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    std::vector<CanvasOp> out;
    auto g = std::make_shared<GradientData>(heap.rt);
    g->kind = GradientData::Kind::Linear;
    g->args[2] = 80;
    c.setFillGradient(g);
    c.fillRect(0, 0, 10, 10, out);
    // No stops: nothing is painted.
    CHECK(out.back().paint.kind == Paint::Kind::Solid && out.back().paint.color.a == 0);
    g->addStop(1, Color{0, 0, 255, 255});
    g->addStop(0, Color{255, 0, 0, 255});
    c.fillRect(0, 0, 10, 10, out);
    CHECK(out.back().paint.kind == Paint::Kind::Linear);
    CHECK_EQ(out.back().paint.stops.size(), size_t(2));
    CHECK(out.back().paint.stops[0].color.r == 255 && near(out.back().paint.args[2], 80));
    // No length: nothing.
    auto flat = std::make_shared<GradientData>(heap.rt);
    flat->kind = GradientData::Kind::Linear;
    flat->addStop(0, Color{255, 0, 0, 255});
    c.setFillGradient(flat);
    c.fillRect(0, 0, 10, 10, out);
    CHECK(out.back().paint.color.a == 0 && out.back().paint.kind == Paint::Kind::Solid);
    // A conic gradient or a pattern (profile 1: out) paints nothing.
    auto conic = std::make_shared<GradientData>(heap.rt);
    conic->addStop(0, Color{255, 0, 0, 255});
    c.setFillGradient(conic);
    c.fillRect(0, 0, 10, 10, out);
    CHECK(out.back().paint.color.a == 0);
    // Radial.
    auto radial = std::make_shared<GradientData>(heap.rt);
    radial->kind = GradientData::Kind::Radial;
    const double args[] = {40, 44, 2, 40, 44, 16};
    std::copy(std::begin(args), std::end(args), radial->args);
    radial->addStop(0, Color{1, 2, 3, 255});
    c.setFillGradient(radial);
    c.fillRect(0, 0, 10, 10, out);
    CHECK(out.back().paint.kind == Paint::Kind::Radial && near(out.back().paint.args[5], 16));
}

WR_TEST(testText) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    std::vector<CanvasOp> out;
    c.setTextAlign(TextAlign::Center);
    c.fillText("Ag", 40, 30, std::nullopt, out);
    CHECK(out.back().kind == CanvasOp::Kind::Text && near(out.back().textDx, -8) && near(out.back().y, 30));
    c.setTextAlign(TextAlign::Left);
    c.setTextBaseline(TextBaseline::Top);
    c.fillText("Ag", 6, 6, std::nullopt, out);
    CHECK(near(out.back().textDx, 0) && near(out.back().y, 18));
    c.setTextAlign(TextAlign::Right);
    c.setTextBaseline(TextBaseline::Alphabetic);
    c.strokeText("Wz", 74, 54, 8.0, out);
    CHECK(out.back().strokeText && near(out.back().textDx, -16) && near(out.back().scaleX, 0.5));
    // End is right in a left-to-right canvas, left in a right-to-left one.
    c.setTextAlign(TextAlign::End);
    c.fillText("ab", 0, 0, std::nullopt, out);
    CHECK(near(out.back().textDx, -16));
    c.setRightToLeft(true);
    c.fillText("ab", 0, 0, std::nullopt, out);
    CHECK(near(out.back().textDx, 0));
    const size_t before = out.size();
    c.fillText("ab", 0, 0, 0.0, out);
    c.fillText("ab", NAN, 0, std::nullopt, out);
    CHECK_EQ(out.size(), before);
    // Cut at a UTF-8 boundary.
    std::string longText(CanvasInterpreter::kMaxTextBytes - 1, 'a');
    longText += "\xC3\xA9tail";
    c.fillText(longText, 0, 0, std::nullopt, out);
    CHECK_EQ(out.back().text.size(), CanvasInterpreter::kMaxTextBytes - 1);
}

WR_TEST(testDrawImageClipsTheSourceRect) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    std::vector<CanvasOp> out;
    // The source rect half outside a 20×20 source: clipped, and the destination with it.
    c.drawImage(nullptr, 20, 20, 10, 0, 20, 20, 0, 0, 40, 40, out);
    CHECK_EQ(out.size(), size_t(1));
    CHECK(near(out[0].sw, 10) && near(out[0].sh, 20) && near(out[0].dw, 20) && near(out[0].dh, 40));
    // Negative sizes are flipped; an empty source rect draws nothing.
    c.drawImage(nullptr, 20, 20, 20, 20, -10, -10, 0, 0, 10, 10, out);
    CHECK(near(out.back().sx, 10) && near(out.back().sw, 10));
    const size_t before = out.size();
    c.drawImage(nullptr, 20, 20, 30, 30, 5, 5, 0, 0, 10, 10, out);
    c.drawImage(nullptr, 20, 20, 0, 0, 20, 20, 0, 0, 0, 10, out);
    CHECK_EQ(out.size(), before);
}

WR_TEST(testThePathPointCap) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    path::moveTo(c.currentPath(), c.matrix(), 0, 0);
    for (size_t i = 0; i < path::kMaxPathPoints + 10; i++) {
        path::lineTo(c.currentPath(), c.matrix(), double(i % 7), 1);
    }
    CHECK_EQ(c.currentPath().geometry.points.size(), 2 * path::kMaxPathPoints);
    CHECK_EQ(c.currentPath().geometry.verbs.size(), path::kMaxPathPoints);
}

WR_TEST(testTheStackIsCapped) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    for (int i = 0; i < 100000; i++) {
        c.save();
    }
    c.translate(5, 0);
    for (int i = 0; i < 100000; i++) {
        c.restore();
    }
    CHECK(near(c.matrix().e, 0));
}

WR_TEST(testAZeroSizedCanvasDrawsNothing) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    c.setSize(0, 10);
    std::vector<CanvasOp> out;
    c.fillRect(0, 0, 10, 10, out);
    c.fillText("a", 0, 0, std::nullopt, out);
    c.drawImage(nullptr, 10, 10, 0, 0, 10, 10, 0, 0, 10, 10, out);
    CHECK(out.empty());
    c.reset(&out);
    CHECK_EQ(out.size(), size_t(0));
    c.setSize(10, 10);
    c.reset(&out);
    CHECK(out.size() == 1 && out[0].kind == CanvasOp::Kind::Reset);
}

WR_TEST(testClipsAccumulate) {
    FakeCanvasHost host;
    Heap heap;
    CanvasInterpreter c(host, heap.rt);
    std::vector<CanvasOp> out;
    path::arc(c.currentPath(), c.matrix(), 40, 30, 22, 0, M_PI * 2, false);
    c.clip(nullptr, false);
    c.save();
    c.beginPath();
    path::rect(c.currentPath(), c.matrix(), 0, 0, 10, 10);
    c.clip(nullptr, true);
    c.fillRect(0, 0, 80, 60, out);
    CHECK(out.back().clip && out.back().clip->depth == 2 && out.back().clip->evenodd);
    c.restore();
    c.fillRect(0, 0, 80, 60, out);
    CHECK(out.back().clip && out.back().clip->depth == 1 && !out.back().clip->evenodd);
}
