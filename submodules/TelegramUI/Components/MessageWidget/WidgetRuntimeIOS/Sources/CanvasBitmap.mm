#include "CanvasBitmap.h"

#include <CoreText/CoreText.h>

#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

#include "CoreTextRenderHost.h"
#include "Sources/Canvas/CanvasOps.h"

namespace wr::ios {

namespace {

using canvas::CanvasOp;
using canvas::Color;
using canvas::GeometryView;
using canvas::Paint;
using canvas::PathVerb;

/// A geometry as a CGPath (twidget's vector_path).
CGPathRef pathOf(GeometryView g) {
    CGMutablePathRef p = CGPathCreateMutable();
    const float* v = g.points.data();
    const size_t n = g.points.size();
    size_t i = 0;
    for (PathVerb verb : g.verbs) {
        const size_t need = verb == PathVerb::Cubic ? 6 : verb == PathVerb::Quad ? 4 : verb == PathVerb::Close ? 0 : 2;
        if (i + need > n) {
            break;
        }
        switch (verb) {
        case PathVerb::Move:
            CGPathMoveToPoint(p, nullptr, v[i], v[i + 1]);
            break;
        case PathVerb::Line:
            CGPathAddLineToPoint(p, nullptr, v[i], v[i + 1]);
            break;
        case PathVerb::Quad:
            CGPathAddQuadCurveToPoint(p, nullptr, v[i], v[i + 1], v[i + 2], v[i + 3]);
            break;
        case PathVerb::Cubic:
            CGPathAddCurveToPoint(p, nullptr, v[i], v[i + 1], v[i + 2], v[i + 3], v[i + 4], v[i + 5]);
            break;
        case PathVerb::Close:
            CGPathCloseSubpath(p);
            break;
        }
        i += need;
    }
    return p;
}

/// Clips to the context's path; an empty path clips everything away (CGContextClip would do nothing).
void clipToPath(CGContextRef ctx, bool evenodd) {
    if (CGContextIsPathEmpty(ctx)) {
        CGContextClipToRect(ctx, CGRectZero);
        return;
    }
    if (evenodd) {
        CGContextEOClip(ctx);
    } else {
        CGContextClip(ctx);
    }
}

void setLineStyle(CGContextRef ctx, const CanvasOp& op) {
    CGContextSetLineWidth(ctx, op.lineWidth);
    CGContextSetLineCap(ctx, op.lineCap == 1 ? kCGLineCapRound : op.lineCap == 2 ? kCGLineCapSquare : kCGLineCapButt);
    CGContextSetLineJoin(ctx, op.lineJoin == 1 ? kCGLineJoinRound : op.lineJoin == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
    CGContextSetMiterLimit(ctx, op.miterLimit);
    bool dashed = false;
    for (float d : op.dashes) {
        dashed = dashed || d > 0;
    }
    if (dashed) {
        std::vector<CGFloat> lengths(op.dashes.begin(), op.dashes.end());
        CGContextSetLineDash(ctx, op.dashOffset, lengths.data(), lengths.size());
    } else {
        CGContextSetLineDash(ctx, 0, nullptr, 0);
    }
}

CGColorRef colorOf(CGColorSpaceRef space, const Color& c) {
    const CGFloat components[] = {c.r / 255.0, c.g / 255.0, c.b / 255.0, c.a / 255.0};
    return CGColorCreate(space, components);
}

CGGradientRef gradientOf(CGColorSpaceRef space, const std::vector<canvas::Stop>& stops) {
    std::vector<CGFloat> components, locations;
    for (const canvas::Stop& s : stops) {
        components.insert(components.end(), {s.color.r / 255.0, s.color.g / 255.0, s.color.b / 255.0, s.color.a / 255.0});
        locations.push_back(std::clamp(double(s.offset), 0.0, 1.0));
    }
    return CGGradientCreateWithColorComponents(space, components.data(), locations.data(), stops.size());
}

CGAffineTransform matrixOf(const CanvasOp& op) {
    return CGAffineTransformMake(op.matrix[0], op.matrix[1], op.matrix[2], op.matrix[3], op.matrix[4], op.matrix[5]);
}

bool invertible(const CGAffineTransform& m) { return std::fabs(m.a * m.d - m.b * m.c) >= 1e-12; }

} // namespace

std::unique_ptr<IOSCanvasBitmap> IOSCanvasBitmap::create(int width, int height) {
    if (width <= 0 || height <= 0) {
        return nullptr;
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    // No buffer: CoreGraphics allocates it zeroed, the transparent bitmap a new canvas starts as.
    CGContextRef context = CGBitmapContextCreate(nullptr, size_t(width), size_t(height), 8, 0, space,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    if (!context) {
        return nullptr;
    }
    // y down, as the ops are.
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1, -1);
    CGContextSetShouldAntialias(context, true);
    return std::unique_ptr<IOSCanvasBitmap>(new IOSCanvasBitmap(context, width, height));
}

IOSCanvasBitmap::IOSCanvasBitmap(CGContextRef context, int width, int height)
    : m_context(context), m_space(CGColorSpaceCreateDeviceRGB()), m_width(width), m_height(height) {}

IOSCanvasBitmap::~IOSCanvasBitmap() {
    CGContextRelease(m_context);
    CGColorSpaceRelease(m_space);
}

void IOSCanvasBitmap::run(std::span<const CanvasOp> ops) {
    if (ops.empty()) {
        return;
    }
    m_snapshot = nullptr;
    for (const CanvasOp& o : ops) {
        op(o);
    }
}

std::shared_ptr<const HostImage> IOSCanvasBitmap::snapshot() {
    if (!m_snapshot) {
        CGImageRef image = CGBitmapContextCreateImage(m_context);
        if (!image) {
            return nullptr;
        }
        m_snapshot = std::make_shared<IOSHostImage>(image, m_uncounted, 0);
    }
    return m_snapshot;
}

void IOSCanvasBitmap::op(const CanvasOp& o) {
    CGContextRef ctx = m_context;
    if (o.kind == CanvasOp::Kind::Reset) {
        CGContextClearRect(ctx, CGRectMake(0, 0, m_width, m_height));
        return;
    }
    CGContextSaveGState(ctx);
    // Every clip of the chain intersects, in any order.
    for (const canvas::ClipNode* clip = o.clip.get(); clip; clip = clip->parent.get()) {
        CGPathRef shape = pathOf(clip->path.view());
        CGContextAddPath(ctx, shape);
        clipToPath(ctx, clip->evenodd);
        CGPathRelease(shape);
    }
    if (o.kind == CanvasOp::Kind::Clear) {
        CGPathRef shape = pathOf(o.path.view());
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        CGContextAddPath(ctx, shape);
        CGContextFillPath(ctx);
        CGPathRelease(shape);
        CGContextRestoreGState(ctx);
        return;
    }
    CGContextSetAlpha(ctx, std::clamp(o.alpha, 0.0f, 1.0f));
    paint(o);
    CGContextRestoreGState(ctx);
}

// One op's content, under the clips and alpha op() set.
void IOSCanvasBitmap::paint(const CanvasOp& o) {
    CGContextRef ctx = m_context;
    const CGAffineTransform m = matrixOf(o);
    // Fills what the context is clipped to with the paint, whose geometry is in user space.
    auto paintArea = [&] {
        const Paint& p = o.paint;
        if (p.kind == Paint::Kind::Solid || p.stops.empty()) {
            const Color c = p.kind == Paint::Kind::Solid || p.stops.empty() ? p.color : p.stops.front().color;
            if (c.a == 0) {
                return;
            }
            CGColorRef color = colorOf(m_space, c);
            CGContextSetFillColorWithColor(ctx, color);
            CGContextFillRect(ctx, CGRectInfinite);
            CGColorRelease(color);
            return;
        }
        CGGradientRef g = gradientOf(m_space, p.stops);
        if (!g) {
            return;
        }
        CGContextConcatCTM(ctx, m);
        const auto extend = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
        const float* a = p.args;
        if (p.kind == Paint::Kind::Linear) {
            CGContextDrawLinearGradient(ctx, g, CGPointMake(a[0], a[1]), CGPointMake(a[2], a[3]), extend);
        } else {
            CGContextDrawRadialGradient(ctx, g, CGPointMake(a[0], a[1]), a[2], CGPointMake(a[3], a[4]), a[5], extend);
        }
        CGGradientRelease(g);
    };
    switch (o.kind) {
    case CanvasOp::Kind::Fill: {
        CGPathRef shape = pathOf(o.path.view());
        CGContextAddPath(ctx, shape);
        clipToPath(ctx, o.evenodd);
        paintArea();
        CGPathRelease(shape);
        return;
    }
    case CanvasOp::Kind::Stroke: {
        // The path is in canvas px but the line style in user space: stroke it back in user space.
        if (!invertible(m)) {
            return;
        }
        const CGAffineTransform inverse = CGAffineTransformInvert(m);
        CGPathRef device = pathOf(o.path.view());
        CGPathRef user = CGPathCreateCopyByTransformingPath(device, &inverse);
        CGPathRelease(device);
        if (!user) {
            return;
        }
        CGContextConcatCTM(ctx, m);
        setLineStyle(ctx, o);
        CGContextAddPath(ctx, user);
        CGContextReplacePathWithStrokedPath(ctx);
        clipToPath(ctx, false);
        CGContextConcatCTM(ctx, inverse);
        paintArea();
        CGPathRelease(user);
        return;
    }
    case CanvasOp::Kind::Text: {
        const auto* font = dynamic_cast<const IOSHostFont*>(o.font.get());
        CTFontRef ctFont = font ? font->font() : nullptr;
        if (!ctFont || o.scaleX == 0 || !invertible(m) || o.text.empty()) {
            return;
        }
        CFStringRef string = CFStringCreateWithBytes(nullptr, reinterpret_cast<const UInt8*>(o.text.data()),
                                                     CFIndex(o.text.size()), kCFStringEncodingUTF8, false);
        if (!string) {
            return;
        }
        // The glyphs take the context's fill colour, so a solid fill is CoreText's own drawing.
        const void* keys[] = {kCTFontAttributeName, kCTForegroundColorFromContextAttributeName};
        const void* values[] = {ctFont, kCFBooleanTrue};
        CFDictionaryRef attributes = CFDictionaryCreate(nullptr, keys, values, 2, &kCFTypeDictionaryKeyCallBacks,
                                                        &kCFTypeDictionaryValueCallBacks);
        CFAttributedStringRef attributed = CFAttributedStringCreate(nullptr, string, attributes);
        CTLineRef line = CTLineCreateWithAttributedString(attributed);
        CFRelease(attributed);
        CFRelease(attributes);
        CFRelease(string);
        if (!line) {
            return;
        }
        const Paint& p = o.paint;
        if (!o.strokeText && (p.kind == Paint::Kind::Solid || p.stops.empty())) {
            // A solid fill draws the line itself (V5d final review, I5): CoreText then draws colour glyphs (emoji),
            // which have no outline to clip to.
            const Color c = p.kind == Paint::Kind::Solid || p.stops.empty() ? p.color : p.stops.front().color;
            if (c.a != 0) {
                // The colour's alpha goes into the context's, which colour glyphs take too (V5d fix-wave review, M-F).
                CGContextSetAlpha(ctx, std::clamp(o.alpha, 0.0f, 1.0f) * (c.a / 255.0));
                CGColorRef color = colorOf(m_space, Color{c.r, c.g, c.b, 255});
                CGContextSetFillColorWithColor(ctx, color);
                CGColorRelease(color);
                CGContextConcatCTM(ctx, m);
                CGContextTranslateCTM(ctx, o.x, o.y);
                // y up from the baseline and an identity text matrix, the configuration CTLineDraw documents; a font
                // with a matrix changes the text matrix as it draws, so it is set before every line (fix-wave review,
                // I-B).
                CGContextScaleCTM(ctx, o.scaleX, -1);
                CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
                CGContextSetTextDrawingMode(ctx, kCGTextFill);
                CGContextSetTextPosition(ctx, o.textDx, 0);
                CTLineDraw(line, ctx);
            }
            CFRelease(line);
            return;
        }
        // The glyphs' outlines are the clip (CoreText's kCGTextClip through CTLineDraw clips nothing here), then the
        // paint fills them in canvas px.
        CGMutablePathRef glyphs = CGPathCreateMutable();
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (CFIndex r = 0; r < CFArrayGetCount(runs); r++) {
            CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, r));
            CTFontRef runFont = static_cast<CTFontRef>(CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName));
            const CFIndex count = CTRunGetGlyphCount(run);
            std::vector<CGGlyph> ids(static_cast<size_t>(count));
            std::vector<CGPoint> positions(static_cast<size_t>(count));
            CTRunGetGlyphs(run, CFRangeMake(0, 0), ids.data());
            CTRunGetPositions(run, CFRangeMake(0, 0), positions.data());
            for (CFIndex i = 0; i < count; i++) {
                // Glyph outlines are y-up from the baseline; the line here is y-down.
                CGAffineTransform place = CGAffineTransformMake(1, 0, 0, -1, o.textDx + positions[size_t(i)].x, -positions[size_t(i)].y);
                CGPathRef outline = CTFontCreatePathForGlyph(runFont ? runFont : ctFont, ids[size_t(i)], &place);
                if (outline) {
                    CGPathAddPath(glyphs, nullptr, outline);
                    CGPathRelease(outline);
                }
            }
        }
        CFRelease(line);
        CGContextConcatCTM(ctx, m);
        CGContextTranslateCTM(ctx, o.x, o.y);
        CGContextScaleCTM(ctx, o.scaleX, 1);
        CGContextAddPath(ctx, glyphs);
        CGPathRelease(glyphs);
        if (o.strokeText) {
            setLineStyle(ctx, o);
            CGContextReplacePathWithStrokedPath(ctx);
        }
        clipToPath(ctx, false);
        CGContextScaleCTM(ctx, 1 / o.scaleX, 1);
        CGContextTranslateCTM(ctx, -o.x, -o.y);
        CGContextConcatCTM(ctx, CGAffineTransformInvert(m));
        paintArea();
        return;
    }
    case CanvasOp::Kind::Image: {
        const auto* source = dynamic_cast<const IOSHostImage*>(o.source.get());
        if (!source || !source->image || o.sw <= 0 || o.sh <= 0) {
            return;
        }
        // The source rect is in the source's own units; its pixels may be more (an image decoded at a scale).
        const double px = double(CGImageGetWidth(source->image)) / o.sourceWidth;
        const double py = double(CGImageGetHeight(source->image)) / o.sourceHeight;
        const CGRect crop = CGRectMake(o.sx * px, o.sy * py, o.sw * px, o.sh * py);
        CGImageRef part = CGImageCreateWithImageInRect(source->image, CGRectIntegral(crop));
        if (!part) {
            return;
        }
        CGContextConcatCTM(ctx, m);
        CGContextSetInterpolationQuality(ctx, o.smoothing ? kCGInterpolationHigh : kCGInterpolationNone);
        // CGContextDrawImage draws y-up: flip about the destination.
        CGContextTranslateCTM(ctx, 0, o.dy + o.dh);
        CGContextScaleCTM(ctx, 1, -1);
        CGContextDrawImage(ctx, CGRectMake(o.dx, 0, o.dw, o.dh), part);
        CGImageRelease(part);
        return;
    }
    case CanvasOp::Kind::Reset:
    case CanvasOp::Kind::Clear:
        return;
    }
}

} // namespace wr::ios
