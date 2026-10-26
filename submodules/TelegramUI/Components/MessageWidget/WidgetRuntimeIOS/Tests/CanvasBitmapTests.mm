// The iOS canvas bitmap (V5d plan, Task 2): CanvasOps run on a CoreGraphics bitmap, read back through snapshots.
#import <XCTest/XCTest.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <vector>

#include "../Sources/CoreTextRenderHost.h"
#include "Sources/Canvas/CanvasInterpreter.h"
#include "quickjs.h"

using namespace wr::canvas;

namespace {

/// The snapshot's pixels as straight RGBA, row 0 at the top.
std::vector<uint8_t> pixelsOf(const wr::HostImage& image) {
    CGImageRef cg = static_cast<const wr::ios::IOSHostImage&>(image).image;
    const size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    std::vector<uint8_t> out(w * h * 4, 0);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(out.data(), w, h, 8, w * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    CGContextRelease(ctx);
    return out;
}

struct Pixel {
    int r, g, b, a;
};

Pixel at(const std::vector<uint8_t>& pixels, int width, int x, int y) {
    const uint8_t* p = pixels.data() + (size_t(y) * width + x) * 4;
    return Pixel{p[0], p[1], p[2], p[3]};
}

CanvasOp fillOf(float x0, float y0, float x1, float y1, Color color) {
    CanvasOp op;
    op.kind = CanvasOp::Kind::Fill;
    op.path.verbs = {PathVerb::Move, PathVerb::Line, PathVerb::Line, PathVerb::Line, PathVerb::Close};
    op.path.points = {x0, y0, x1, y0, x1, y1, x0, y1};
    op.paint.color = color;
    return op;
}

/// A JS heap for the retained paths and clips; declared first, so it goes last.
struct Heap {
    JSRuntime* rt = JS_NewRuntime();
    ~Heap() { JS_FreeRuntime(rt); }
};

class Fonts final : public CanvasHost {
public:
    explicit Fonts(wr::ios::CoreTextRenderHost& host) : m_host(host) {}
    /// 16px bold sans-serif, or for a value naming italic, 20px italic fantasy (no italic face on iOS: a skewed one).
    std::optional<Font> font(std::string_view css) override {
        const bool italic = css.find("italic") != std::string_view::npos;
        litehtml::font_description d;
        d.family = italic ? "fantasy" : "sans-serif";
        d.size = litehtml::pixel_t(italic ? 20 : 16);
        d.weight = italic ? 400 : 700;
        d.style = italic ? litehtml::font_style_italic : litehtml::font_style_normal;
        litehtml::font_metrics metrics;
        auto font = m_host.createFont(d, metrics);
        return Font{font, double(metrics.ascent.value()), double(metrics.descent.value())};
    }
    double textWidth(const wr::HostFont& font, std::string_view utf8) override { return m_host.textWidth(font, utf8); }

private:
    wr::ios::CoreTextRenderHost& m_host;
};

} // namespace

@interface CanvasBitmapTests : XCTestCase
@end

@implementation CanvasBitmapTests

- (void)testAFillIsDrawn {
    wr::ios::CoreTextRenderHost host;
    std::unique_ptr<wr::HostCanvas> canvas = host.createCanvas(20, 10);
    XCTAssertTrue(canvas != nullptr);
    const CanvasOp op = fillOf(2, 2, 8, 8, Color{255, 0, 0, 255});
    canvas->run(std::span(&op, 1));
    std::shared_ptr<const wr::HostImage> snapshot = canvas->snapshot();
    XCTAssertTrue(snapshot != nullptr);
    std::vector<uint8_t> px = pixelsOf(*snapshot);
    Pixel inside = at(px, 20, 4, 4), outside = at(px, 20, 12, 4);
    XCTAssertEqual(inside.r, 255);
    XCTAssertEqual(inside.a, 255);
    XCTAssertEqual(outside.a, 0);
    // y-down: the fill's top rows are the bitmap's top rows.
    XCTAssertEqual(at(px, 20, 4, 1).a, 0);
    XCTAssertEqual(at(px, 20, 4, 2).a, 255);
}

- (void)testClearMakesTransparent {
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(10, 10);
    std::vector<CanvasOp> ops = {fillOf(0, 0, 10, 10, Color{0, 0, 255, 255})};
    CanvasOp clear = fillOf(2, 2, 5, 5, Color{});
    clear.kind = CanvasOp::Kind::Clear;
    ops.push_back(clear);
    canvas->run(ops);
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    XCTAssertEqual(at(px, 10, 3, 3).a, 0);
    XCTAssertEqual(at(px, 10, 7, 7).b, 255);
    CanvasOp reset;
    reset.kind = CanvasOp::Kind::Reset;
    canvas->run(std::span(&reset, 1));
    XCTAssertEqual(at(pixelsOf(*canvas->snapshot()), 10, 7, 7).a, 0);
}

- (void)testClipLimitsAFill {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(10, 10);
    CanvasOp op = fillOf(0, 0, 10, 10, Color{0, 255, 0, 255});
    const CanvasOp half = fillOf(0, 0, 5, 10, Color{});
    RetainedGeometry clipPath(heap.rt);
    clipPath.verbs.assign(half.path.verbs.begin(), half.path.verbs.end());
    clipPath.points.assign(half.path.points.begin(), half.path.points.end());
    op.clip = std::make_shared<ClipNode>(std::move(clipPath), false, nullptr);
    canvas->run(std::span(&op, 1));
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    XCTAssertEqual(at(px, 10, 2, 5).g, 255);
    XCTAssertEqual(at(px, 10, 7, 5).a, 0);
}

- (void)testAlphaApplies {
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(4, 4);
    CanvasOp op = fillOf(0, 0, 4, 4, Color{0, 0, 0, 255});
    op.alpha = 0.5f;
    canvas->run(std::span(&op, 1));
    const int a = at(pixelsOf(*canvas->snapshot()), 4, 1, 1).a;
    XCTAssertTrue(a > 120 && a < 136, @"%d", a);
}

- (void)testAStrokeIsDrawn {
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(20, 20);
    CanvasOp op;
    op.kind = CanvasOp::Kind::Stroke;
    op.path.verbs = {PathVerb::Move, PathVerb::Line};
    op.path.points = {2, 10, 18, 10};
    op.lineWidth = 4;
    op.paint.color = Color{255, 0, 255, 255};
    canvas->run(std::span(&op, 1));
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    XCTAssertEqual(at(px, 20, 10, 9).a, 255);
    XCTAssertEqual(at(px, 20, 10, 4).a, 0);
}

- (void)testTextHasInk {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    Fonts fonts(host);
    CanvasInterpreter interpreter(fonts, heap.rt);
    interpreter.setSize(60, 30);
    std::vector<CanvasOp> ops;
    interpreter.setTextBaseline(TextBaseline::Top);
    interpreter.fillText("Ag", 4, 4, std::nullopt, ops);
    XCTAssertEqual(ops.size(), size_t(1));
    auto canvas = host.createCanvas(60, 30);
    canvas->run(ops);
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    int ink = 0;
    for (int y = 0; y < 30; y++) {
        for (int x = 0; x < 60; x++) {
            ink += at(px, 60, x, y).a > 128 ? 1 : 0;
        }
    }
    XCTAssertTrue(ink > 20, @"%d", ink);
    // Nothing above the top baseline's line box.
    for (int x = 0; x < 60; x++) {
        XCTAssertEqual(at(px, 60, x, 1).a, 0);
    }
}

- (void)testStrokedTextInksLessThanFilledText {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    Fonts fonts(host);
    CanvasInterpreter interpreter(fonts, heap.rt);
    interpreter.setSize(60, 30);
    interpreter.setTextBaseline(TextBaseline::Top);
    auto inkOf = [&](bool stroke) {
        std::vector<CanvasOp> ops;
        if (stroke) {
            interpreter.strokeText("OO", 4, 4, std::nullopt, ops);
        } else {
            interpreter.fillText("OO", 4, 4, std::nullopt, ops);
        }
        auto canvas = host.createCanvas(60, 30);
        canvas->run(ops);
        std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
        int ink = 0;
        for (size_t i = 3; i < px.size(); i += 4) {
            ink += px[i] > 128 ? 1 : 0;
        }
        return ink;
    };
    const int filled = inkOf(false), stroked = inkOf(true);
    XCTAssertTrue(stroked > 10 && stroked < filled, @"%d %d", stroked, filled);
}

// V5d final review, I5: a colour glyph (emoji) has no outline; a solid fill draws it as CoreText does.
- (void)testEmojiHasInk {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    Fonts fonts(host);
    CanvasInterpreter interpreter(fonts, heap.rt);
    interpreter.setSize(60, 30);
    interpreter.setTextBaseline(TextBaseline::Top);
    std::vector<CanvasOp> ops;
    interpreter.fillText("\xF0\x9F\x94\xA5", 4, 4, std::nullopt, ops);
    auto canvas = host.createCanvas(60, 30);
    canvas->run(ops);
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    int coloured = 0;
    for (size_t i = 0; i + 3 < px.size(); i += 4) {
        coloured += px[i + 3] > 128 && (px[i] > 120 || px[i + 1] > 120) ? 1 : 0;
    }
    XCTAssertTrue(coloured > 10, @"%d", coloured);
}

// V5d fix-wave review, I-B: a solid fillText places a raised or lowered mark where the outline path does. CTLineDraw
// expects a y-up text matrix; under a y-down one a mark's y offset goes the wrong way.
- (void)testSolidTextPlacesMarksAsOutlinesDo {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    Fonts fonts(host);
    CanvasInterpreter interpreter(fonts, heap.rt);
    interpreter.setSize(120, 60);
    interpreter.setTextBaseline(TextBaseline::Top);
    CTFontRef ctFont = static_cast<const wr::ios::IOSHostFont&>(*fonts.font("16px sans-serif")->font).font();
    // Arabic with fatha and shadda, Thai with a tone mark, E with two combining marks, Devanagari with a vowel below.
    const char* const candidates[] = {"\xD8\xA8\xD9\x8E\xD9\x91", "\xE0\xB8\x97\xE0\xB8\xB5\xE0\xB9\x88",
                                      "E\xCC\x81\xCC\xA3", "\xE0\xA4\x95\xE0\xA5\x83"};
    // Whether a run of `text` positions a glyph off the baseline.
    auto hasRaisedGlyph = [&](const char* text) {
        CFStringRef string = CFStringCreateWithCString(nullptr, text, kCFStringEncodingUTF8);
        CFAttributedStringRef attributed = CFAttributedStringCreate(nullptr, string, (__bridge CFDictionaryRef)@{
            (__bridge id)kCTFontAttributeName : (__bridge id)ctFont
        });
        CTLineRef line = CTLineCreateWithAttributedString(attributed);
        bool raised = false;
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (CFIndex r = 0; r < CFArrayGetCount(runs); r++) {
            CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, r));
            std::vector<CGPoint> positions(static_cast<size_t>(CTRunGetGlyphCount(run)));
            CTRunGetPositions(run, CFRangeMake(0, 0), positions.data());
            for (const CGPoint& p : positions) {
                raised = raised || std::fabs(p.y) > 0.5;
            }
        }
        CFRelease(line);
        CFRelease(attributed);
        CFRelease(string);
        return raised;
    };
    // The first and last rows with ink (alpha > 64).
    auto inkRows = [&](const std::vector<CanvasOp>& ops) {
        auto canvas = host.createCanvas(120, 60);
        canvas->run(ops);
        std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
        int top = -1, bottom = -1;
        for (int y = 0; y < 60; y++) {
            for (int x = 0; x < 120; x++) {
                if (at(px, 120, x, y).a > 64) {
                    top = top < 0 ? y : top;
                    bottom = y;
                }
            }
        }
        return std::pair<int, int>(top, bottom);
    };
    int tested = 0;
    for (const char* text : candidates) {
        if (!hasRaisedGlyph(text)) {
            continue;
        }
        tested++;
        std::vector<CanvasOp> solid;
        interpreter.fillText(text, 10, 10, std::nullopt, solid);
        XCTAssertEqual(solid.size(), size_t(1));
        // A gradient of two equal stops paints the same colour through the glyphs' outlines.
        std::vector<CanvasOp> outlined = solid;
        outlined[0].paint.kind = Paint::Kind::Linear;
        outlined[0].paint.args[0] = 0, outlined[0].paint.args[1] = 0, outlined[0].paint.args[2] = 120, outlined[0].paint.args[3] = 0;
        outlined[0].paint.stops = {Stop{0, solid[0].paint.color}, Stop{1, solid[0].paint.color}};
        const auto a = inkRows(solid), b = inkRows(outlined);
        XCTAssertTrue(a.first >= 0 && b.first >= 0, @"%s", text);
        XCTAssertTrue(std::abs(a.first - b.first) <= 1 && std::abs(a.second - b.second) <= 1, @"%s: solid rows %d-%d, outlines %d-%d",
                      text, a.first, a.second, b.first, b.second);
    }
    XCTAssertTrue(tested > 0, @"no candidate positions a glyph off the baseline");
}

// V5d fix-wave review, I-B: a font with a matrix (a synthesized italic's skew) changes the context's text matrix as it
// draws; the next solid fillText draws as it does on a fresh bitmap.
- (void)testAFontWithAMatrixLeavesNothingBehind {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    Fonts fonts(host);
    CTFontRef italic = static_cast<const wr::ios::IOSHostFont&>(*fonts.font("italic 20px fantasy")->font).font();
    XCTAssertFalse(CGAffineTransformIsIdentity(CTFontGetMatrix(italic)), @"the italic is not synthesized");
    CanvasInterpreter interpreter(fonts, heap.rt);
    interpreter.setSize(100, 60);
    interpreter.setTextBaseline(TextBaseline::Top);
    std::vector<CanvasOp> first, second;
    interpreter.setFont("italic 20px fantasy");
    interpreter.fillText("Ag", 4, 2, std::nullopt, first);
    interpreter.setFont("16px sans-serif");
    interpreter.fillText("Ag", 4, 34, std::nullopt, second);
    auto used = host.createCanvas(100, 60);
    used->run(first);
    used->run(second);
    auto fresh = host.createCanvas(100, 60);
    fresh->run(second);
    std::vector<uint8_t> a = pixelsOf(*used->snapshot()), b = pixelsOf(*fresh->snapshot());
    int ink = 0, differing = 0;
    for (int y = 30; y < 60; y++) {
        for (int x = 0; x < 100; x++) {
            ink += at(b, 100, x, y).a > 128 ? 1 : 0;
            differing += std::abs(at(a, 100, x, y).a - at(b, 100, x, y).a) > 8 ? 1 : 0;
        }
    }
    XCTAssertTrue(ink > 20, @"%d", ink);
    XCTAssertEqual(differing, 0);
    // The italic itself is upright: its ink rows are its outlines'.
    auto rows = [&](const std::vector<CanvasOp>& ops) {
        auto canvas = host.createCanvas(100, 60);
        canvas->run(ops);
        std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
        int top = -1, bottom = -1;
        for (int y = 0; y < 60; y++) {
            for (int x = 0; x < 100; x++) {
                if (at(px, 100, x, y).a > 64) {
                    top = top < 0 ? y : top;
                    bottom = y;
                }
            }
        }
        return std::pair<int, int>(top, bottom);
    };
    std::vector<CanvasOp> outlined = first;
    outlined[0].paint.kind = Paint::Kind::Linear;
    outlined[0].paint.args[0] = 0, outlined[0].paint.args[1] = 0, outlined[0].paint.args[2] = 100, outlined[0].paint.args[3] = 0;
    outlined[0].paint.stops = {Stop{0, first[0].paint.color}, Stop{1, first[0].paint.color}};
    const auto s = rows(first), o = rows(outlined);
    XCTAssertTrue(s.first >= 0 && std::abs(s.first - o.first) <= 1 && std::abs(s.second - o.second) <= 1, @"solid %d-%d, outlines %d-%d",
                  s.first, s.second, o.first, o.second);
}

// V5d fix-wave review, M-F: a colour glyph takes the fill colour's alpha, as outline glyphs do (Chromium modulates
// colour glyphs by the paint's alpha).
- (void)testEmojiTakeTheFillAlpha {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    Fonts fonts(host);
    CanvasInterpreter interpreter(fonts, heap.rt);
    interpreter.setSize(60, 30);
    interpreter.setTextBaseline(TextBaseline::Top);
    std::vector<CanvasOp> ops;
    interpreter.fillText("\xF0\x9F\x94\xA5", 4, 4, std::nullopt, ops);
    XCTAssertEqual(ops.size(), size_t(1));
    ops[0].paint.color = Color{0, 0, 0, 77};
    auto canvas = host.createCanvas(60, 30);
    canvas->run(ops);
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    int most = 0;
    for (size_t i = 3; i < px.size(); i += 4) {
        most = std::max(most, int(px[i]));
    }
    XCTAssertTrue(most > 50 && most < 90, @"%d", most);
}

/// V5d fix-wave 2 review, m-3: solid text sets the context alpha itself, so it multiplies in globalAlpha as well as the
/// fill colour's alpha: half of a half-transparent fill is about a quarter.
- (void)testSolidTextTakesTheGlobalAlpha {
    Heap heap;
    wr::ios::CoreTextRenderHost host;
    Fonts fonts(host);
    CanvasInterpreter interpreter(fonts, heap.rt);
    interpreter.setSize(60, 30);
    interpreter.setTextBaseline(TextBaseline::Top);
    interpreter.setGlobalAlpha(0.5);
    std::vector<CanvasOp> ops;
    interpreter.fillText("\xF0\x9F\x94\xA5", 4, 4, std::nullopt, ops);
    XCTAssertEqual(ops.size(), size_t(1));
    ops[0].paint.color = Color{0, 0, 0, 128};
    auto canvas = host.createCanvas(60, 30);
    canvas->run(ops);
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    int most = 0;
    for (size_t i = 3; i < px.size(); i += 4) {
        most = std::max(most, int(px[i]));
    }
    XCTAssertTrue(most > 50 && most < 80, @"%d", most);
}

- (void)testDrawingACanvasOntoItself {
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(10, 10);
    const CanvasOp red = fillOf(0, 0, 5, 10, Color{255, 0, 0, 255});
    canvas->run(std::span(&red, 1));
    CanvasOp copy;
    copy.kind = CanvasOp::Kind::Image;
    copy.source = canvas->snapshot();
    copy.sourceWidth = copy.sourceHeight = 10;
    copy.sx = 0, copy.sy = 0, copy.sw = 5, copy.sh = 10;
    copy.dx = 5, copy.dy = 0, copy.dw = 5, copy.dh = 10;
    canvas->run(std::span(&copy, 1));
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    XCTAssertEqual(at(px, 10, 7, 5).r, 255);
    XCTAssertEqual(at(px, 10, 2, 5).r, 255);
}

- (void)testAnImageDrawsUprightIntoItsRect {
    wr::ios::CoreTextRenderHost host;
    auto source = host.createCanvas(4, 4);
    const CanvasOp top = fillOf(0, 0, 4, 2, Color{0, 0, 255, 255});
    source->run(std::span(&top, 1));
    auto canvas = host.createCanvas(8, 8);
    CanvasOp draw;
    draw.kind = CanvasOp::Kind::Image;
    draw.source = source->snapshot();
    draw.sourceWidth = draw.sourceHeight = 4;
    draw.sw = draw.sh = 4;
    draw.dx = 0, draw.dy = 0, draw.dw = 8, draw.dh = 8;
    canvas->run(std::span(&draw, 1));
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    XCTAssertEqual(at(px, 8, 4, 1).b, 255);
    XCTAssertEqual(at(px, 8, 4, 6).a, 0);
}

- (void)testSnapshotsAreStable {
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(4, 4);
    auto a = canvas->snapshot(), b = canvas->snapshot();
    XCTAssertTrue(a.get() == b.get());
    const CanvasOp op = fillOf(0, 0, 1, 1, Color{1, 2, 3, 255});
    canvas->run(std::span(&op, 1));
    auto c = canvas->snapshot();
    XCTAssertTrue(c.get() != a.get());
    XCTAssertTrue(static_cast<const wr::ios::IOSHostImage&>(*c).serial != static_cast<const wr::ios::IOSHostImage&>(*a).serial);
    // A snapshot outlives its canvas and its host.
    canvas.reset();
    XCTAssertEqual(at(pixelsOf(*c), 4, 0, 0).a, 255);
}

- (void)testAGradientFill {
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(20, 4);
    CanvasOp op = fillOf(0, 0, 20, 4, Color{});
    op.paint.kind = Paint::Kind::Linear;
    op.paint.args[0] = 0, op.paint.args[1] = 0, op.paint.args[2] = 20, op.paint.args[3] = 0;
    op.paint.stops = {Stop{0, Color{255, 0, 0, 255}}, Stop{1, Color{0, 0, 255, 255}}};
    canvas->run(std::span(&op, 1));
    std::vector<uint8_t> px = pixelsOf(*canvas->snapshot());
    Pixel left = at(px, 20, 1, 2), right = at(px, 20, 18, 2);
    XCTAssertTrue(left.r > 200 && left.b < 60, @"%d %d", left.r, left.b);
    XCTAssertTrue(right.b > 200 && right.r < 60, @"%d %d", right.r, right.b);
}

- (void)testATransparentPaintDrawsNothing {
    wr::ios::CoreTextRenderHost host;
    auto canvas = host.createCanvas(4, 4);
    const CanvasOp op = fillOf(0, 0, 4, 4, Color{0, 0, 0, 0});
    canvas->run(std::span(&op, 1));
    XCTAssertEqual(at(pixelsOf(*canvas->snapshot()), 4, 1, 1).a, 0);
}

@end
