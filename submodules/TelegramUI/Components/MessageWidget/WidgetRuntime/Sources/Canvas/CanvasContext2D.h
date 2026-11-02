// CanvasRenderingContext2D (V5d plan, Task 3; HTML "The 2D rendering context"): the IDL members over the interpreter
// (CanvasInterpreter.h), whose ops run at once into the canvas's bitmap (CanvasState's, allocated on the first op).
// The interpreter holds what draws; this object also holds what the IDL reads back, profile 1's out attributes
// included, and saves and restores it with the interpreter's state.
#pragma once

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "Sources/Canvas/CanvasInterpreter.h"
#include "Sources/Canvas/CanvasState.h"
#include "Sources/Canvas/CanvasStyle.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class HTMLCanvasElement;
class DOMMatrix;
class CanvasGradient;
class TextMetrics;
class ImageData;

class CanvasRenderingContext2D : public PlatformObject, public canvas::CanvasHost {
public:
    /// measureText reads at most this much of its text (widget-sandbox v0.1.0's `maxCanvasString`; V5d final review, C1).
    static constexpr size_t kMaxMeasuredBytes = 65536;
    CanvasRenderingContext2D(JSContext* ctx, HTMLCanvasElement& canvas, JSValueConst canvasObject);

    HTMLCanvasElement* canvas(JSContext*) const { return m_element; }

    // CanvasSettings and CanvasState.
    Value getContextAttributes(JSContext* ctx);
    void save(JSContext* ctx);
    void restore(JSContext* ctx);
    void reset(JSContext* ctx);
    bool isContextLost(JSContext*) const { return false; }

    // CanvasTransform.
    void scale(JSContext* ctx, Unrestricted x, Unrestricted y);
    void rotate(JSContext* ctx, Unrestricted angle);
    void translate(JSContext* ctx, Unrestricted x, Unrestricted y);
    void transform(JSContext* ctx, Unrestricted a, Unrestricted b, Unrestricted c, Unrestricted d, Unrestricted e, Unrestricted f);
    Ref<DOMMatrix> getTransform(JSContext* ctx);
    /// (a, b, c, d, e, f) or (optional DOMMatrix2DInit): 0 or 1 arguments are the dictionary, 6 the numbers, any other
    /// count a TypeError.
    void setTransform(JSContext* ctx, std::vector<Value> args);
    void resetTransform(JSContext* ctx);

    // CanvasCompositing, CanvasImageSmoothing, CanvasShadowStyles, CanvasFilters.
    Unrestricted globalAlpha(JSContext*) const { return {m_state.globalAlpha}; }
    void setGlobalAlpha(JSContext* ctx, Unrestricted alpha);
    String globalCompositeOperation(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.composite); }
    void setGlobalCompositeOperation(JSContext* ctx, String value);
    bool imageSmoothingEnabled(JSContext*) const { return m_state.smoothing; }
    void setImageSmoothingEnabled(JSContext* ctx, bool enabled);
    String imageSmoothingQuality(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.smoothingQuality); }
    void setImageSmoothingQuality(JSContext* ctx, String value) {
        if (this->command(ctx)) {
            m_state.smoothingQuality = value.utf8();
        }
    }
    Unrestricted shadowOffsetX(JSContext*) const { return {m_state.shadowOffsetX}; }
    Unrestricted shadowOffsetY(JSContext*) const { return {m_state.shadowOffsetY}; }
    Unrestricted shadowBlur(JSContext*) const { return {m_state.shadowBlur}; }
    void setShadowOffsetX(JSContext*, Unrestricted v);
    void setShadowOffsetY(JSContext*, Unrestricted v);
    void setShadowBlur(JSContext*, Unrestricted v);
    String shadowColor(JSContext* ctx) const { return String::fromUTF8(ctx, canvas::serializeColor(m_state.shadowColor)); }
    void setShadowColor(JSContext* ctx, String value);
    String filter(JSContext* ctx) const { return String::fromUTF8(ctx, textOr(m_state.filter, "none")); }
    void setFilter(JSContext* ctx, String value);

    // CanvasFillStrokeStyles.
    Value fillStyle(JSContext* ctx) const { return styleValue(ctx, m_state.fill); }
    Value strokeStyle(JSContext* ctx) const { return styleValue(ctx, m_state.stroke); }
    void setFillStyle(JSContext* ctx, Value value) { setStyle(ctx, value, true); }
    void setStrokeStyle(JSContext* ctx, Value value) { setStyle(ctx, value, false); }
    Ref<CanvasGradient> createLinearGradient(JSContext* ctx, double x0, double y0, double x1, double y1);
    Ref<CanvasGradient> createRadialGradient(JSContext* ctx, double x0, double y0, double r0, double x1, double y1, double r1);
    Ref<CanvasGradient> createConicGradient(JSContext* ctx, double startAngle, double x, double y);
    Value createPattern(JSContext* ctx, Value image, String repetition);

    // CanvasRect.
    void clearRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h);
    void fillRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h);
    void strokeRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h);

    // CanvasDrawPath.
    void beginPath(JSContext* ctx) {
        if (this->command(ctx)) {
            m_interpreter.beginPath();
        }
    }
    void fill(JSContext* ctx, std::optional<Value> pathOrFillRule, std::optional<Value> fillRule);
    void stroke(JSContext* ctx, std::optional<Value> path);
    void clip(JSContext* ctx, std::optional<Value> pathOrFillRule, std::optional<Value> fillRule);
    bool isPointInPath(JSContext* ctx, Value pathOrX, Value xOrY, std::vector<Value> rest);
    bool isPointInStroke(JSContext* ctx, Value pathOrX, Value xOrY, std::optional<Value> y);
    void drawFocusIfNeeded(JSContext*, Value, std::optional<Value>) {}

    // CanvasText.
    void fillText(JSContext* ctx, String text, Unrestricted x, Unrestricted y, std::optional<Unrestricted> maxWidth);
    void strokeText(JSContext* ctx, String text, Unrestricted x, Unrestricted y, std::optional<Unrestricted> maxWidth);
    Ref<TextMetrics> measureText(JSContext* ctx, String text);

    // CanvasDrawImage: (image, dx, dy), (image, dx, dy, dw, dh) or (image, sx, sy, sw, sh, dx, dy, dw, dh).
    void drawImage(JSContext* ctx, Value image, Value a, Value b, std::vector<Value> rest);

    // CanvasImageData (profile 1: out): transparent pixels, put nowhere.
    Ref<ImageData> createImageData(JSContext* ctx, Value swOrImageData, std::vector<Value> rest);
    Ref<ImageData> getImageData(JSContext* ctx, int32_t sx, int32_t sy, int32_t sw, int32_t sh, std::optional<Value> settings);
    void putImageData(JSContext* ctx, Value imageData, Value dx, Value dy, std::vector<Value> dirty);

    // CanvasPathDrawingStyles.
    Unrestricted lineWidth(JSContext*) const { return {m_state.lineWidth}; }
    void setLineWidth(JSContext* ctx, Unrestricted width);
    String lineCap(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.lineCap); }
    void setLineCap(JSContext* ctx, String cap);
    String lineJoin(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.lineJoin); }
    void setLineJoin(JSContext* ctx, String join);
    Unrestricted miterLimit(JSContext*) const { return {m_state.miterLimit}; }
    void setMiterLimit(JSContext* ctx, Unrestricted limit);
    void setLineDash(JSContext* ctx, Value segments);
    std::vector<Unrestricted> getLineDash(JSContext* ctx) const;
    Unrestricted lineDashOffset(JSContext*) const { return {m_state.lineDashOffset}; }
    void setLineDashOffset(JSContext* ctx, Unrestricted offset);

    // CanvasTextDrawingStyles.
    String lang(JSContext* ctx) const { return String::fromUTF8(ctx, textOr(m_state.lang, "inherit")); }
    /// Capped at 256 bytes (a BCP 47 tag is far shorter), so a saved state stays small (V5d final review, C4).
    void setLang(JSContext* ctx, String value) {
        if (this->command(ctx)) {
            m_state.lang = makeSharedText(JS_GetRuntime(ctx), value.utf8Prefix(256, nullptr));
        }
    }
    String font(JSContext* ctx) const { return String::fromUTF8(ctx, textOr(m_state.font, canvas::kDefaultFont)); }
    void setFont(JSContext* ctx, String value);
    String textAlign(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.textAlign); }
    void setTextAlign(JSContext* ctx, String value);
    String textBaseline(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.textBaseline); }
    void setTextBaseline(JSContext* ctx, String value);
    String direction(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.direction); }
    void setDirection(JSContext* ctx, String value);
    String letterSpacing(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.letterSpacing); }
    void setLetterSpacing(JSContext* ctx, String value);
    String wordSpacing(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.wordSpacing); }
    void setWordSpacing(JSContext* ctx, String value);
    String fontKerning(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.fontKerning); }
    void setFontKerning(JSContext* ctx, String value) {
        if (this->command(ctx)) {
            m_state.fontKerning = value.utf8();
        }
    }
    String fontStretch(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.fontStretch); }
    void setFontStretch(JSContext* ctx, String value) {
        if (this->command(ctx)) {
            m_state.fontStretch = value.utf8();
        }
    }
    String fontVariantCaps(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.fontVariantCaps); }
    void setFontVariantCaps(JSContext* ctx, String value) {
        if (this->command(ctx)) {
            m_state.fontVariantCaps = value.utf8();
        }
    }
    String textRendering(JSContext* ctx) const { return String::fromUTF8(ctx, m_state.textRendering); }
    void setTextRendering(JSContext* ctx, String value) {
        if (this->command(ctx)) {
            m_state.textRendering = value.utf8();
        }
    }

    // CanvasPath, on the current path through the current transform.
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

    /// The canvas's width or height was set: a new transparent bitmap of the new size (made on the next draw) and the
    /// context's default state.
    void dimensionsChanged(JSContext* ctx);
    /// The bitmap's current pixels; nullptr when it has none (it never drew, or its size is past the allowance).
    std::shared_ptr<const HostImage> snapshot() const;
    /// The bitmap's size: the canvas's width and height when the size last changed.
    std::pair<int, int> bitmapSize() const { return {m_interpreter.width(), m_interpreter.height()}; }

    // CanvasHost.
    std::optional<Font> font(std::string_view css) override;
    double textWidth(const HostFont& font, std::string_view utf8) override;

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    /// limit.canvas-commands (widget-sandbox v0.3.0): one command to this canvas, as upstream's shim counts them (a
    /// drawing or path method, a state change, a gradient or pattern made; never a query). Past Limits::canvasCommands in
    /// one batch, strict throws RangeError and compat drops it (false). A canvas's first command of a batch is one
    /// operation of it (limit.batch: upstream's `canvas` operation).
    bool command(JSContext* ctx);
    /// Stops the widget when `text` passes the text-value cap (strict): a canvas string is a text value.
    static void stopPastTextValue(JSContext* ctx, const String& text);
    /// The batch (Runtime::batchSerial) the command count is of, and the count.
    uint64_t m_commandBatch = ~uint64_t(0);
    size_t m_commands = 0;
    /// A fill or stroke style: a colour, or the gradient or pattern object a script set.
    struct Style {
        canvas::Color color{0, 0, 0, 255};
        Held object;
    };
    /// What the IDL reads back, saved and restored with the interpreter's state.
    struct State {
        Style fill, stroke;
        double globalAlpha = 1;
        std::string composite = "source-over";
        bool smoothing = true;
        std::string smoothingQuality = "low";
        double shadowOffsetX = 0, shadowOffsetY = 0, shadowBlur = 0;
        canvas::Color shadowColor{0, 0, 0, 0};
        // The long strings are shared with the states saved from this one (V5d fix-wave review, I-C); none is the
        // default ("none", "inherit", canvas::kDefaultFont).
        SharedText filter;
        double lineWidth = 1;
        std::string lineCap = "butt", lineJoin = "miter";
        double miterLimit = 10, lineDashOffset = 0;
        SharedText lang, font;
        std::string textAlign = "start", textBaseline = "alphabetic",
                    direction = "inherit", letterSpacing = "0px", wordSpacing = "0px", fontKerning = "auto",
                    fontStretch = "normal", fontVariantCaps = "normal", textRendering = "auto";
    };

    Value styleValue(JSContext* ctx, const Style& style) const;
    void setStyle(JSContext* ctx, const Value& value, bool fill);
    /// Copies `from` into `to`, the objects with a reference each (`to` released first).
    void copyState(JSContext* ctx, State& to, const State& from);
    void clearState(JSRuntime* rt, State& state);
    /// Back to the defaults: the readback state, its stack and the interpreter.
    void resetState(JSContext* ctx, bool clearBitmap);
    /// Reports a dash list an op dropped (`canvas-dashes`), allocates the bitmap on the first op, and runs the ops.
    void run(JSContext* ctx, std::vector<canvas::CanvasOp>& ops);
    /// The bitmap changed: the render tree republishes the canvas when it is rendered (RenderTree::canvasPainted).
    void painted(JSContext* ctx);
    /// fill/clip's arguments: the Path2D (or null) and the fill rule.
    std::pair<const canvas::PathData*, bool> pathAndRule(JSContext* ctx, const std::optional<Value>& a,
                                                         const std::optional<Value>& b, const char* member);
    void text(JSContext* ctx, const String& text, double x, double y, std::optional<Unrestricted> maxWidth, bool stroke);

    JSContext* m_ctx;
    HTMLCanvasElement* m_element;
    /// The canvas element's object, which keeps m_element alive.
    Held m_canvasObject;
    canvas::CanvasInterpreter m_interpreter{*this, JS_GetRuntime(m_ctx)};
    std::unique_ptr<canvas::Bitmap> m_bitmap;
    State m_state;
    /// In the JS heap (V5d final review, C2); its strings are capped.
    Vector<State> m_stack{JSAllocator<State>(JS_GetRuntime(m_ctx))};
    /// Saves past the interpreter's stack: each pops nothing (CanvasInterpreter::save).
    size_t m_overflowedSaves = 0;
    /// The current font's parse, for measureText and the interpreter's font lookups.
    std::optional<canvas::FontValue> m_fontValue;
    /// Where this context is registered by its canvas's serial; it takes itself out in dispose.
    std::shared_ptr<canvas::CanvasState::Contexts> m_registry;
    uint64_t m_serial = 0;
};

/// The pixels a drawImage or createPattern source holds, and its size: an HTMLCanvasElement (Task 3; an <img> in Task
/// 5). A canvas with a 0 side is an InvalidStateError, anything else a TypeError. `image` null: nothing to draw yet.
struct CanvasImageSource {
    std::shared_ptr<const HostImage> image;
    double width = 0, height = 0;
    /// False for an image that is not fully decodable (no src, or pending until its load or error fires): HTML's
    /// "bad" usability, for which drawImage draws nothing and createPattern returns null. A canvas is always usable.
    bool usable = true;
};
CanvasImageSource canvasImageSource(JSContext* ctx, const Value& value, const char* member);

} // namespace wr
