#include "Sources/Canvas/CanvasContext2D.h"

#include <cmath>

#include "Generated/Bindings.h"
#include "Sources/Canvas/CanvasElement.h"
#include "Sources/Canvas/CanvasObjects.h"
#include "Sources/Canvas/DOMMatrix.h"
#include "Sources/Canvas/ImageElement.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/LimitStops.h"
#include "Sources/Host/Sequences.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

constexpr const char* kInterface = "CanvasRenderingContext2D";

double number(JSContext* ctx, const Value& v, const char* member, int index) {
    return convert<Unrestricted>(ctx, v.get(), ArgInfo{kInterface, member, index}).value;
}

/// [EnforceRange] long: a finite number in the long range, truncated; anything else a TypeError.
int32_t enforcedLong(JSContext* ctx, const Value& v, const char* member, int index) {
    const double d = number(ctx, v, member, index);
    if (!std::isfinite(d) || std::trunc(d) < -2147483648.0 || std::trunc(d) > 2147483647.0) {
        throw TypeError{argumentMessage(ArgInfo{kInterface, member, index}, "is not a finite long.")};
    }
    return int32_t(std::trunc(d));
}

/// The CanvasFillRule enum: "nonzero" or "evenodd", else a TypeError.
bool evenodd(JSContext* ctx, const Value& v, const char* member, int index) {
    String rule = convert<String>(ctx, v.get(), ArgInfo{kInterface, member, index});
    if (rule.equalsASCII("evenodd")) {
        return true;
    }
    if (rule.equalsASCII("nonzero")) {
        return false;
    }
    throw TypeError{argumentMessage(ArgInfo{kInterface, member, index}, "is not a valid CanvasFillRule value")};
}

Path2D* asPath(JSContext* ctx, const Value& v) { return unwrap<Path2D>(ctx, v.get(), idl::kPath2D); }

/// A gradient's data, in the JS heap with its stops (V5d final review, C3).
std::shared_ptr<canvas::GradientData> newGradient(JSContext* ctx) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    return std::allocate_shared<canvas::GradientData>(JSAllocator<canvas::GradientData>(rt), rt);
}

canvas::TextAlign alignOf(const std::string& s) {
    return s == "end" ? canvas::TextAlign::End : s == "left" ? canvas::TextAlign::Left : s == "right" ? canvas::TextAlign::Right
         : s == "center" ? canvas::TextAlign::Center : canvas::TextAlign::Start;
}

canvas::TextBaseline baselineOf(const std::string& s) {
    return s == "top" ? canvas::TextBaseline::Top : s == "hanging" ? canvas::TextBaseline::Hanging
         : s == "middle" ? canvas::TextBaseline::Middle : s == "ideographic" ? canvas::TextBaseline::Ideographic
         : s == "bottom" ? canvas::TextBaseline::Bottom : canvas::TextBaseline::Alphabetic;
}

bool isCompositeOperation(const std::string& s) {
    static const char* const kNames[] = {
        "source-over", "source-in", "source-out", "source-atop", "destination-over", "destination-in", "destination-out",
        "destination-atop", "lighter", "copy", "xor", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge",
        "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue", "saturation", "color", "luminosity",
    };
    for (const char* name : kNames) {
        if (s == name) {
            return true;
        }
    }
    return false;
}

} // namespace

CanvasImageSource canvasImageSource(JSContext* ctx, const Value& value, const char* member) {
    if (HTMLCanvasElement* canvas = unwrap<HTMLCanvasElement>(ctx, value.get(), idl::kHTMLCanvasElement)) {
        const uint32_t width = canvas->width(ctx), height = canvas->height(ctx);
        if (width == 0 || height == 0) {
            throw DOMError{"InvalidStateError", std::string(kInterface) + "." + member + ": the canvas has a side of 0."};
        }
        CanvasImageSource source;
        source.width = width;
        source.height = height;
        if (CanvasRenderingContext2D* context = canvas->context()) {
            source.image = context->snapshot();
        }
        return source;
    }
    if (HTMLImageElement* img = unwrap<HTMLImageElement>(ctx, value.get(), idl::kHTMLImageElement)) {
        // HTML's "check the usability of the image argument": broken is an InvalidStateError, not yet available (no
        // src, or pending until its load or error fires: widget-sandbox v0.2.3) draws nothing.
        CanvasImageSource source;
        if (img->pending()) {
            source.usable = false;
            return source;
        }
        std::optional<DecodedImage> decoded;
        const HTMLImageElement::State state = img->state(ctx, &decoded);
        if (state == HTMLImageElement::State::Broken) {
            throw DOMError{"InvalidStateError", std::string(kInterface) + "." + member + ": the image is broken."};
        }
        source.usable = state == HTMLImageElement::State::Available;
        if (decoded && decoded->width > 0 && decoded->height > 0) {
            source.image = decoded->image;
            source.width = decoded->width;
            source.height = decoded->height;
        }
        return source;
    }
    throw TypeError{std::string(kInterface) + "." + member + ": the image is not an HTMLCanvasElement or HTMLImageElement."};
}

CanvasRenderingContext2D::CanvasRenderingContext2D(JSContext* ctx, HTMLCanvasElement& canvas, JSValueConst canvasObject)
    : m_ctx(ctx), m_element(&canvas) {
    m_canvasObject.set(JS_GetRuntime(ctx), JS_DupValue(ctx, canvasObject));
    m_serial = canvas.serial();
    m_registry = canvas::CanvasState::of(ctx).contexts();
    m_registry->bySerial[m_serial] = this;
    m_interpreter.setSize(int(std::min<uint32_t>(canvas.width(ctx), INT32_MAX)), int(std::min<uint32_t>(canvas.height(ctx), INT32_MAX)));
}

// State.

void CanvasRenderingContext2D::copyState(JSContext* ctx, State& to, const State& from) {
    clearState(JS_GetRuntime(ctx), to);
    // The assignment copies the objects' values without a reference; each copy then takes its own.
    to = from;
    to.fill.object.value = JS_DupValue(ctx, from.fill.object.value);
    to.stroke.object.value = JS_DupValue(ctx, from.stroke.object.value);
}

void CanvasRenderingContext2D::clearState(JSRuntime* rt, State& state) {
    state.fill.object.clear(rt);
    state.stroke.object.clear(rt);
}

void CanvasRenderingContext2D::resetState(JSContext* ctx, bool clearBitmap) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    clearState(rt, m_state);
    for (State& saved : m_stack) {
        clearState(rt, saved);
    }
    m_stack.clear();
    m_overflowedSaves = 0;
    m_state = State();
    m_fontValue.reset();
    std::vector<canvas::CanvasOp> ops;
    m_interpreter.reset(clearBitmap ? &ops : nullptr);
    if (m_bitmap) {
        // A canvas with no bitmap has nothing to clear.
        run(ctx, ops);
    }
}

Value CanvasRenderingContext2D::getContextAttributes(JSContext* ctx) {
    Value out = Value::adopt(ctx, JS_NewObject(ctx));
    if (JS_IsException(out.get())) {
        throw Thrown{};
    }
    auto set = [&](const char* name, JSValue v) {
        if (JS_SetPropertyStr(ctx, out.get(), name, v) < 0) {
            throw Thrown{};
        }
    };
    set("alpha", JS_TRUE);
    set("colorSpace", JS_NewString(ctx, "srgb"));
    set("colorType", JS_NewString(ctx, "unorm8"));
    set("desynchronized", JS_FALSE);
    set("willReadFrequently", JS_FALSE);
    return out;
}

void CanvasRenderingContext2D::save(JSContext* ctx) {
    if (!this->command(ctx)) {
        return;
    }
    if (m_stack.size() >= canvas::CanvasInterpreter::kMaxStack) {
        m_overflowedSaves++;
    } else {
        // The slot first: a push refused at the memory limit then holds no reference (V5d fix-wave review, M-A).
        m_stack.emplace_back();
        copyState(ctx, m_stack.back(), m_state);
    }
    m_interpreter.save();
}

void CanvasRenderingContext2D::restore(JSContext* ctx) {
    if (!this->command(ctx)) {
        return;
    }
    m_interpreter.restore();
    if (m_overflowedSaves > 0) {
        m_overflowedSaves--;
        return;
    }
    if (m_stack.empty()) {
        return;
    }
    clearState(JS_GetRuntime(ctx), m_state);
    m_state = std::move(m_stack.back());
    m_stack.pop_back();
    m_fontValue.reset();
}

void CanvasRenderingContext2D::reset(JSContext* ctx) {
    if (!this->command(ctx)) {
        return;
    }
    resetState(ctx, true);
}

void CanvasRenderingContext2D::dimensionsChanged(JSContext* ctx) {
    // HTML: the bitmap becomes transparent at the new size and the context goes back to its defaults. The old bitmap
    // returns its pixels to the allowance at once; the new one is made on the next draw.
    const bool hadPixels = m_bitmap != nullptr;
    m_bitmap.reset();
    resetState(ctx, false);
    m_interpreter.setSize(int(std::min<uint32_t>(m_element->width(ctx), INT32_MAX)),
                          int(std::min<uint32_t>(m_element->height(ctx), INT32_MAX)));
    if (hadPixels) {
        // The published canvas is cleared too, whether or not anything is drawn after (V5d final review, M10).
        this->painted(ctx);
    }
}

std::shared_ptr<const HostImage> CanvasRenderingContext2D::snapshot() const {
    return m_bitmap ? m_bitmap->canvas->snapshot() : nullptr;
}

void CanvasRenderingContext2D::run(JSContext* ctx, std::vector<canvas::CanvasOp>& ops) {
    if (ops.empty()) {
        return;
    }
    for (const canvas::CanvasOp& op : ops) {
        if (op.dashDropped) {
            canvas::CanvasState::of(ctx).reportLimit("canvas-dashes");
        }
    }
    if (!m_bitmap) {
        m_bitmap = canvas::CanvasState::of(ctx).allocate(m_interpreter.width(), m_interpreter.height());
        if (!m_bitmap) {
            return;
        }
    }
    m_bitmap->canvas->run(ops);
    this->painted(ctx);
}

void CanvasRenderingContext2D::painted(JSContext* ctx) {
    if (HostState* state = HostState::find(ctx)) {
        if (RenderTree* render = state->render()) {
            render->canvasPainted(*m_element);
        }
    }
}

// Transforms.

void CanvasRenderingContext2D::scale(JSContext* ctx, Unrestricted x, Unrestricted y) {
    if (!this->command(ctx)) {
        return;
    }
    m_interpreter.scale(x.value, y.value);
}
void CanvasRenderingContext2D::rotate(JSContext* ctx, Unrestricted angle) {
    if (!this->command(ctx)) {
        return;
    }
    m_interpreter.rotate(angle.value);
}
void CanvasRenderingContext2D::translate(JSContext* ctx, Unrestricted x, Unrestricted y) {
    if (!this->command(ctx)) {
        return;
    }
    m_interpreter.translate(x.value, y.value);
}
void CanvasRenderingContext2D::transform(JSContext* ctx, Unrestricted a, Unrestricted b, Unrestricted c, Unrestricted d,
                                         Unrestricted e, Unrestricted f) {
    if (!this->command(ctx)) {
        return;
    }
    m_interpreter.transform(a.value, b.value, c.value, d.value, e.value, f.value);
}

Ref<DOMMatrix> CanvasRenderingContext2D::getTransform(JSContext* ctx) { return DOMMatrix::fromMatrix(ctx, m_interpreter.matrix()); }

void CanvasRenderingContext2D::setTransform(JSContext* ctx, std::vector<Value> args) {
    if (!this->command(ctx)) {
        return;
    }
    if (args.size() == 6) {
        double v[6];
        for (int i = 0; i < 6; i++) {
            v[i] = number(ctx, args[size_t(i)], "setTransform", i);
        }
        m_interpreter.setTransform(v[0], v[1], v[2], v[3], v[4], v[5]);
        return;
    }
    if (args.size() > 1) {
        throw TypeError{"CanvasRenderingContext2D.setTransform: takes 0, 1 or 6 arguments."};
    }
    const idl::DOMMatrix2DInit init = convert<idl::DOMMatrix2DInit>(ctx, args.empty() ? JS_UNDEFINED : args[0].get(),
                                                                    ArgInfo{kInterface, "setTransform", 0});
    const canvas::Matrix m = matrixFromInit(init);
    m_interpreter.setTransform(m.a, m.b, m.c, m.d, m.e, m.f);
}

void CanvasRenderingContext2D::resetTransform(JSContext* ctx) {
    if (!this->command(ctx)) {
        return;
    }
    m_interpreter.resetTransform();
}

// Compositing, smoothing, shadows, filters.

void CanvasRenderingContext2D::setGlobalAlpha(JSContext* ctx, Unrestricted alpha) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::isfinite(alpha.value) && alpha.value >= 0 && alpha.value <= 1) {
        m_state.globalAlpha = alpha.value;
        m_interpreter.setGlobalAlpha(alpha.value);
    }
}

void CanvasRenderingContext2D::setGlobalCompositeOperation(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    // Profile 1: read back, never applied.
    std::string op = value.utf8Prefix(32, nullptr);
    if (isCompositeOperation(op)) {
        m_state.composite = std::move(op);
    }
}

void CanvasRenderingContext2D::setImageSmoothingEnabled(JSContext* ctx, bool enabled) {
    if (!this->command(ctx)) {
        return;
    }
    m_state.smoothing = enabled;
    m_interpreter.setImageSmoothing(enabled);
}

void CanvasRenderingContext2D::setShadowOffsetX(JSContext* ctx, Unrestricted v) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::isfinite(v.value)) {
        m_state.shadowOffsetX = v.value;
    }
}

void CanvasRenderingContext2D::setShadowOffsetY(JSContext* ctx, Unrestricted v) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::isfinite(v.value)) {
        m_state.shadowOffsetY = v.value;
    }
}

void CanvasRenderingContext2D::setShadowBlur(JSContext* ctx, Unrestricted v) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::isfinite(v.value) && v.value >= 0) {
        m_state.shadowBlur = v.value;
    }
}

void CanvasRenderingContext2D::setShadowColor(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::optional<canvas::Color> color = canvas::parseColor(ctx, value)) {
        m_state.shadowColor = *color;
    }
}

void CanvasRenderingContext2D::setFilter(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    // Profile 1: read back, never applied. A CSS filter list is not validated here (the out feature's whole effect).
    m_state.filter = makeSharedText(JS_GetRuntime(ctx), value.utf8Prefix(1024, nullptr));
}

// Styles.

Value CanvasRenderingContext2D::styleValue(JSContext* ctx, const Style& style) const {
    if (!style.object.isUndefined()) {
        return Value::dup(ctx, style.object.value);
    }
    return Value::adopt(ctx, JS_NewString(ctx, canvas::serializeColor(style.color).c_str()));
}

void CanvasRenderingContext2D::setStyle(JSContext* ctx, const Value& value, bool fill) {
    if (!this->command(ctx)) {
        return;
    }
    Style& style = fill ? m_state.fill : m_state.stroke;
    JSRuntime* rt = JS_GetRuntime(ctx);
    if (JS_IsString(value.get())) {
        std::optional<canvas::Color> color = canvas::parseColor(ctx, String::fromJS(ctx, value.get()));
        if (!color) {
            return;
        }
        style.object.clear(rt);
        style.color = *color;
        if (fill) {
            m_interpreter.setFillColor(*color);
        } else {
            m_interpreter.setStrokeColor(*color);
        }
        return;
    }
    std::shared_ptr<const canvas::GradientData> paint;
    if (CanvasGradient* gradient = unwrap<CanvasGradient>(ctx, value.get(), idl::kCanvasGradient)) {
        paint = gradient->data();
    } else if (unwrap<CanvasPattern>(ctx, value.get(), idl::kCanvasPattern)) {
        // A pattern paints nothing in profile 1.
        paint = newGradient(ctx);
    } else {
        return;
    }
    style.object.set(rt, JS_DupValue(ctx, value.get()));
    if (fill) {
        m_interpreter.setFillGradient(std::move(paint));
    } else {
        m_interpreter.setStrokeGradient(std::move(paint));
    }
}

Ref<CanvasGradient> CanvasRenderingContext2D::createLinearGradient(JSContext* ctx, double x0, double y0, double x1, double y1) {
    this->command(ctx);
    auto data = newGradient(ctx);
    data->kind = canvas::GradientData::Kind::Linear;
    const double args[] = {x0, y0, x1, y1};
    std::copy(std::begin(args), std::end(args), data->args);
    return create<CanvasGradient>(ctx, idl::kCanvasGradient, std::move(data));
}

Ref<CanvasGradient> CanvasRenderingContext2D::createRadialGradient(JSContext* ctx, double x0, double y0, double r0, double x1,
                                                                   double y1, double r1) {
    this->command(ctx);
    if (r0 < 0 || r1 < 0) {
        throw DOMError{"IndexSizeError", "CanvasRenderingContext2D.createRadialGradient: a radius is negative."};
    }
    auto data = newGradient(ctx);
    data->kind = canvas::GradientData::Kind::Radial;
    const double args[] = {x0, y0, r0, x1, y1, r1};
    std::copy(std::begin(args), std::end(args), data->args);
    return create<CanvasGradient>(ctx, idl::kCanvasGradient, std::move(data));
}

Ref<CanvasGradient> CanvasRenderingContext2D::createConicGradient(JSContext* ctx, double, double, double) {
    this->command(ctx);
    // Profile 1: a conic gradient paints nothing.
    return create<CanvasGradient>(ctx, idl::kCanvasGradient, newGradient(ctx));
}

Value CanvasRenderingContext2D::createPattern(JSContext* ctx, Value image, String repetition) {
    this->command(ctx);
    // HTML: a bad image (not fully decodable) gives null, before the repetition is checked (v0.2.3 review, M2).
    if (!canvasImageSource(ctx, image, "createPattern").usable) {
        return Value::adopt(ctx, JS_NULL);
    }
    if (!(repetition.empty() || repetition.equalsASCII("repeat") || repetition.equalsASCII("repeat-x") ||
          repetition.equalsASCII("repeat-y") || repetition.equalsASCII("no-repeat"))) {
        throw DOMError{"SyntaxError", "CanvasRenderingContext2D.createPattern: the repetition is not one HTML defines."};
    }
    Ref<CanvasPattern> pattern = create<CanvasPattern>(ctx, idl::kCanvasPattern);
    return Value::adopt(ctx, pattern->newRef(ctx));
}

// Rects.

void CanvasRenderingContext2D::clearRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h) {
    if (!this->command(ctx)) {
        return;
    }
    std::vector<canvas::CanvasOp> ops;
    m_interpreter.clearRect(x.value, y.value, w.value, h.value, ops);
    run(ctx, ops);
}

void CanvasRenderingContext2D::fillRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h) {
    if (!this->command(ctx)) {
        return;
    }
    std::vector<canvas::CanvasOp> ops;
    m_interpreter.fillRect(x.value, y.value, w.value, h.value, ops);
    run(ctx, ops);
}

void CanvasRenderingContext2D::strokeRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h) {
    if (!this->command(ctx)) {
        return;
    }
    std::vector<canvas::CanvasOp> ops;
    m_interpreter.strokeRect(x.value, y.value, w.value, h.value, ops);
    run(ctx, ops);
}

// Paths.

std::pair<const canvas::PathData*, bool> CanvasRenderingContext2D::pathAndRule(JSContext* ctx, const std::optional<Value>& a,
                                                                               const std::optional<Value>& b, const char* member) {
    if (a) {
        if (Path2D* path = asPath(ctx, *a)) {
            return {&path->data(), b ? evenodd(ctx, *b, member, 1) : false};
        }
        if (b) {
            throw TypeError{argumentMessage(ArgInfo{kInterface, member, 0}, "is not a Path2D.")};
        }
        return {nullptr, evenodd(ctx, *a, member, 0)};
    }
    return {nullptr, false};
}

void CanvasRenderingContext2D::fill(JSContext* ctx, std::optional<Value> pathOrFillRule, std::optional<Value> fillRule) {
    if (!this->command(ctx)) {
        return;
    }
    auto [path, rule] = pathAndRule(ctx, pathOrFillRule, fillRule, "fill");
    std::vector<canvas::CanvasOp> ops;
    m_interpreter.fill(path, rule, ops);
    run(ctx, ops);
}

void CanvasRenderingContext2D::stroke(JSContext* ctx, std::optional<Value> path) {
    if (!this->command(ctx)) {
        return;
    }
    const canvas::PathData* data = nullptr;
    if (path) {
        Path2D* p = asPath(ctx, *path);
        if (!p) {
            throw TypeError{argumentMessage(ArgInfo{kInterface, "stroke", 0}, "is not a Path2D.")};
        }
        data = &p->data();
    }
    std::vector<canvas::CanvasOp> ops;
    m_interpreter.stroke(data, ops);
    run(ctx, ops);
}

void CanvasRenderingContext2D::clip(JSContext* ctx, std::optional<Value> pathOrFillRule, std::optional<Value> fillRule) {
    if (!this->command(ctx)) {
        return;
    }
    auto [path, rule] = pathAndRule(ctx, pathOrFillRule, fillRule, "clip");
    if (!m_interpreter.clip(path, rule)) {
        canvas::CanvasState::of(ctx).reportLimit("canvas-clips");
    }
}

bool CanvasRenderingContext2D::isPointInPath(JSContext* ctx, Value pathOrX, Value xOrY, std::vector<Value> rest) {
    if (Path2D* path = asPath(ctx, pathOrX)) {
        if (rest.empty()) {
            throw TypeError{"CanvasRenderingContext2D.isPointInPath: a Path2D needs x and y."};
        }
        const double x = number(ctx, xOrY, "isPointInPath", 1), y = number(ctx, rest[0], "isPointInPath", 2);
        const bool rule = rest.size() > 1 && !JS_IsUndefined(rest[1].get()) ? evenodd(ctx, rest[1], "isPointInPath", 3) : false;
        return m_interpreter.isPointInPath(&path->data(), x, y, rule);
    }
    const double x = number(ctx, pathOrX, "isPointInPath", 0), y = number(ctx, xOrY, "isPointInPath", 1);
    const bool rule = !rest.empty() && !JS_IsUndefined(rest[0].get()) ? evenodd(ctx, rest[0], "isPointInPath", 2) : false;
    return m_interpreter.isPointInPath(nullptr, x, y, rule);
}

bool CanvasRenderingContext2D::isPointInStroke(JSContext* ctx, Value pathOrX, Value xOrY, std::optional<Value> y) {
    if (Path2D* path = asPath(ctx, pathOrX)) {
        if (!y) {
            throw TypeError{"CanvasRenderingContext2D.isPointInStroke: a Path2D needs x and y."};
        }
        const double px = number(ctx, xOrY, "isPointInStroke", 1), py = number(ctx, *y, "isPointInStroke", 2);
        return m_interpreter.isPointInStroke(&path->data(), px, py);
    }
    const double px = number(ctx, pathOrX, "isPointInStroke", 0), py = number(ctx, xOrY, "isPointInStroke", 1);
    return m_interpreter.isPointInStroke(nullptr, px, py);
}

void CanvasRenderingContext2D::closePath(JSContext* ctx) {
    if (!this->command(ctx)) {
        return;
    }
    canvas::path::closePath(m_interpreter.currentPath());
}
void CanvasRenderingContext2D::moveTo(JSContext* ctx, Unrestricted x, Unrestricted y) {
    if (!this->command(ctx)) {
        return;
    }
    canvas::path::moveTo(m_interpreter.currentPath(), m_interpreter.matrix(), x.value, y.value);
}
void CanvasRenderingContext2D::lineTo(JSContext* ctx, Unrestricted x, Unrestricted y) {
    if (!this->command(ctx)) {
        return;
    }
    canvas::path::lineTo(m_interpreter.currentPath(), m_interpreter.matrix(), x.value, y.value);
}
void CanvasRenderingContext2D::quadraticCurveTo(JSContext* ctx, Unrestricted cpx, Unrestricted cpy, Unrestricted x, Unrestricted y) {
    if (!this->command(ctx)) {
        return;
    }
    canvas::path::quadraticCurveTo(m_interpreter.currentPath(), m_interpreter.matrix(), cpx.value, cpy.value, x.value, y.value);
}
void CanvasRenderingContext2D::bezierCurveTo(JSContext* ctx, Unrestricted cp1x, Unrestricted cp1y, Unrestricted cp2x,
                                             Unrestricted cp2y, Unrestricted x, Unrestricted y) {
    if (!this->command(ctx)) {
        return;
    }
    canvas::path::bezierCurveTo(m_interpreter.currentPath(), m_interpreter.matrix(), cp1x.value, cp1y.value, cp2x.value,
                                cp2y.value, x.value, y.value);
}
void CanvasRenderingContext2D::arcTo(JSContext* ctx, Unrestricted x1, Unrestricted y1, Unrestricted x2, Unrestricted y2,
                                     Unrestricted radius) {
    if (!this->command(ctx)) {
        return;
    }
    pathcalls::arcTo(m_interpreter.currentPath(), m_interpreter.matrix(), x1.value, y1.value, x2.value, y2.value, radius.value);
}
void CanvasRenderingContext2D::rect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h) {
    if (!this->command(ctx)) {
        return;
    }
    canvas::path::rect(m_interpreter.currentPath(), m_interpreter.matrix(), x.value, y.value, w.value, h.value);
}
void CanvasRenderingContext2D::roundRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h,
                                         std::optional<Value> radii) {
    if (!this->command(ctx)) {
        return;
    }
    pathcalls::roundRect(ctx, m_interpreter.currentPath(), m_interpreter.matrix(), x.value, y.value, w.value, h.value, radii);
}
void CanvasRenderingContext2D::arc(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted radius, Unrestricted start,
                                   Unrestricted end, bool counterclockwise) {
    if (!this->command(ctx)) {
        return;
    }
    pathcalls::arc(m_interpreter.currentPath(), m_interpreter.matrix(), x.value, y.value, radius.value, start.value, end.value,
                   counterclockwise);
}
void CanvasRenderingContext2D::ellipse(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted rx, Unrestricted ry,
                                       Unrestricted rotation, Unrestricted start, Unrestricted end, bool counterclockwise) {
    if (!this->command(ctx)) {
        return;
    }
    pathcalls::ellipse(m_interpreter.currentPath(), m_interpreter.matrix(), x.value, y.value, rx.value, ry.value, rotation.value,
                       start.value, end.value, counterclockwise);
}

// Line styles.

void CanvasRenderingContext2D::setLineWidth(JSContext* ctx, Unrestricted width) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::isfinite(width.value) && width.value > 0) {
        m_state.lineWidth = width.value;
        m_interpreter.setLineWidth(width.value);
    }
}

void CanvasRenderingContext2D::setLineCap(JSContext* ctx, String cap) {
    if (!this->command(ctx)) {
        return;
    }
    m_state.lineCap = cap.utf8();
    m_interpreter.setLineCap(m_state.lineCap == "round" ? 1 : m_state.lineCap == "square" ? 2 : 0);
}

void CanvasRenderingContext2D::setLineJoin(JSContext* ctx, String join) {
    if (!this->command(ctx)) {
        return;
    }
    m_state.lineJoin = join.utf8();
    m_interpreter.setLineJoin(m_state.lineJoin == "round" ? 1 : m_state.lineJoin == "bevel" ? 2 : 0);
}

void CanvasRenderingContext2D::setMiterLimit(JSContext* ctx, Unrestricted limit) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::isfinite(limit.value) && limit.value > 0) {
        m_state.miterLimit = limit.value;
        m_interpreter.setMiterLimit(limit.value);
    }
}

void CanvasRenderingContext2D::setLineDash(JSContext* ctx, Value segments) {
    if (!this->command(ctx)) {
        return;
    }
    // A sequence<unrestricted double>: read one past the cap, so a longer one is ignored without being read whole.
    std::optional<std::vector<Value>> items =
        JS_IsObject(segments.get()) ? sequenceValues(ctx, segments.get(), "CanvasRenderingContext2D.setLineDash",
                                                     canvas::CanvasInterpreter::kMaxDash + 1)
                                    : std::nullopt;
    if (!items) {
        throw TypeError{"CanvasRenderingContext2D.setLineDash: the segments are not a sequence."};
    }
    std::vector<double> values;
    for (size_t i = 0; i < items->size(); i++) {
        values.push_back(number(ctx, (*items)[i], "setLineDash", 0));
    }
    m_interpreter.setLineDash(values);
}

std::vector<Unrestricted> CanvasRenderingContext2D::getLineDash(JSContext*) const {
    std::vector<Unrestricted> out;
    for (double v : m_interpreter.lineDash()) {
        out.push_back(Unrestricted{v});
    }
    return out;
}

void CanvasRenderingContext2D::setLineDashOffset(JSContext* ctx, Unrestricted offset) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::isfinite(offset.value)) {
        m_state.lineDashOffset = offset.value;
        m_interpreter.setLineDashOffset(offset.value);
    }
}

// Text styles.

void CanvasRenderingContext2D::setFont(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    std::optional<canvas::FontValue> parsed = canvas::parseFont(ctx, value);
    if (!parsed) {
        return;
    }
    m_state.font = makeSharedText(JS_GetRuntime(ctx), parsed->serialized);
    m_interpreter.setFont(m_state.font);
    m_fontValue = std::move(parsed);
}

void CanvasRenderingContext2D::setTextAlign(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    m_state.textAlign = value.utf8();
    m_interpreter.setTextAlign(alignOf(m_state.textAlign));
}

void CanvasRenderingContext2D::setTextBaseline(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    m_state.textBaseline = value.utf8();
    m_interpreter.setTextBaseline(baselineOf(m_state.textBaseline));
}

void CanvasRenderingContext2D::setDirection(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    m_state.direction = value.utf8();
    m_interpreter.setRightToLeft(m_state.direction == "rtl");
}

void CanvasRenderingContext2D::setLetterSpacing(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    // Profile 1: read back, never applied; HTML keeps only a CSS length.
    if (std::optional<std::string> length = canvas::serializedLength(ctx, value)) {
        m_state.letterSpacing = std::move(*length);
    }
}

void CanvasRenderingContext2D::setWordSpacing(JSContext* ctx, String value) {
    if (!this->command(ctx)) {
        return;
    }
    if (std::optional<std::string> length = canvas::serializedLength(ctx, value)) {
        m_state.wordSpacing = std::move(*length);
    }
}

// Text.

std::optional<canvas::CanvasHost::Font> CanvasRenderingContext2D::font(std::string_view css) {
    if (!m_fontValue || m_fontValue->serialized != css) {
        m_fontValue = canvas::parseFont(m_ctx, String::fromUTF8(m_ctx, css));
        if (!m_fontValue) {
            return std::nullopt;
        }
    }
    return canvas::CanvasState::of(m_ctx).font(*m_fontValue);
}

bool CanvasRenderingContext2D::command(JSContext* ctx) {
    Runtime& runtime = Runtime::from(ctx);
    if (m_commandBatch != runtime.batchSerial()) {
        m_commandBatch = runtime.batchSerial();
        m_commands = 0;
        runtime.addOps(1);
    }
    const Limits& limits = runtime.limits();
    if (m_commands >= limits.canvasCommands) {
        if (limits.stops) {
            throw RangeError{"Canvas limit exceeded: more than " + std::to_string(limits.canvasCommands) +
                             " commands for one canvas in one task (max " + std::to_string(limits.canvasCommands) + ")"};
        }
        return false;
    }
    m_commands++;
    runtime.noteCanvasCommand();
    return true;
}

void CanvasRenderingContext2D::stopPastTextValue(JSContext* ctx, const String& text) {
    // limit.text-node (widget-sandbox v0.3.0): a canvas string is a text value; past the cap the widget stops.
    const Limits& limits = Runtime::from(ctx).limits();
    if (limits.stops && text.length() > limits.textValueUnits) {
        stopForTextValue(ctx, text.length());
    }
}

double CanvasRenderingContext2D::textWidth(const HostFont& font, std::string_view utf8) {
    return canvas::CanvasState::of(m_ctx).textWidth(font, utf8);
}

void CanvasRenderingContext2D::text(JSContext* ctx, const String& text, double x, double y, std::optional<Unrestricted> maxWidth,
                                    bool stroke) {
    stopPastTextValue(ctx, text);
    const std::string utf8 = text.utf8Prefix(canvas::CanvasInterpreter::kMaxTextBytes, nullptr);
    std::vector<canvas::CanvasOp> ops;
    std::optional<double> max = maxWidth ? std::optional<double>(maxWidth->value) : std::nullopt;
    if (stroke) {
        m_interpreter.strokeText(utf8, x, y, max, ops);
    } else {
        m_interpreter.fillText(utf8, x, y, max, ops);
    }
    run(ctx, ops);
}

void CanvasRenderingContext2D::fillText(JSContext* ctx, String text, Unrestricted x, Unrestricted y,
                                        std::optional<Unrestricted> maxWidth) {
    if (!this->command(ctx)) {
        return;
    }
    this->text(ctx, text, x.value, y.value, maxWidth, false);
}

void CanvasRenderingContext2D::strokeText(JSContext* ctx, String text, Unrestricted x, Unrestricted y,
                                          std::optional<Unrestricted> maxWidth) {
    if (!this->command(ctx)) {
        return;
    }
    this->text(ctx, text, x.value, y.value, maxWidth, true);
}

Ref<TextMetrics> CanvasRenderingContext2D::measureText(JSContext* ctx, String text) {
    stopPastTextValue(ctx, text);
    TextMetrics::Values v;
    std::optional<Font> font = this->font(textOr(m_state.font, canvas::kDefaultFont));
    if (font && font->font) {
        // At most kMaxMeasuredBytes, the reference's canvas string cap, converted before it is measured.
        const std::string utf8 = text.utf8Prefix(kMaxMeasuredBytes, nullptr);
        v.width = textWidth(*font->font, utf8);
        // The line the text's baseline is placed against, above the alphabetic baseline (positive up).
        const std::string& b = m_state.textBaseline;
        const double line = b == "top" ? font->ascent : b == "hanging" ? 0.8 * font->ascent
                          : b == "middle" ? (font->ascent - font->descent) / 2 : (b == "ideographic" || b == "bottom") ? -font->descent : 0;
        const std::string& align = m_state.textAlign;
        const bool rtl = m_state.direction == "rtl";
        const bool right = align == "right" || (align == "end" && !rtl) || (align == "start" && rtl);
        v.left = align == "center" ? v.width / 2 : right ? v.width : 0;
        v.right = v.width - v.left;
        v.fontAscent = v.ascent = v.emAscent = font->ascent - line;
        v.fontDescent = v.descent = v.emDescent = font->descent + line;
        v.alphabetic = -line;
        v.hanging = 0.8 * font->ascent - line;
        v.ideographic = -font->descent - line;
    }
    return create<TextMetrics>(ctx, idl::kTextMetrics, v);
}

// Images.

void CanvasRenderingContext2D::drawImage(JSContext* ctx, Value image, Value a, Value b, std::vector<Value> rest) {
    if (!this->command(ctx)) {
        return;
    }
    if (rest.size() != 0 && rest.size() != 2 && rest.size() != 6) {
        throw TypeError{"CanvasRenderingContext2D.drawImage: takes 3, 5 or 9 arguments."};
    }
    const CanvasImageSource source = canvasImageSource(ctx, image, "drawImage");
    double v[8];
    v[0] = number(ctx, a, "drawImage", 1);
    v[1] = number(ctx, b, "drawImage", 2);
    for (size_t i = 0; i < rest.size(); i++) {
        v[2 + i] = number(ctx, rest[i], "drawImage", int(3 + i));
    }
    if (!source.image) {
        return;
    }
    if (unwrap<HTMLCanvasElement>(ctx, image.get(), idl::kHTMLCanvasElement) == m_element) {
        // Onto itself: the draw writes to the bitmap its snapshot shares, so the whole bitmap is copied whatever the
        // source rect (V5d fix-wave review, I-D).
    }
    double sx = 0, sy = 0, sw = source.width, sh = source.height, dx, dy, dw = source.width, dh = source.height;
    if (rest.size() == 6) {
        sx = v[0], sy = v[1], sw = v[2], sh = v[3], dx = v[4], dy = v[5], dw = v[6], dh = v[7];
    } else {
        dx = v[0], dy = v[1];
        if (rest.size() == 2) {
            dw = v[2], dh = v[3];
        }
    }
    std::vector<canvas::CanvasOp> ops;
    m_interpreter.drawImage(source.image, source.width, source.height, sx, sy, sw, sh, dx, dy, dw, dh, ops);
    run(ctx, ops);
}

// Image data.

Ref<ImageData> CanvasRenderingContext2D::createImageData(JSContext* ctx, Value swOrImageData, std::vector<Value> rest) {
    if (ImageData* data = unwrap<ImageData>(ctx, swOrImageData.get(), idl::kImageData)) {
        return ImageData::make(ctx, data->width(ctx), data->height(ctx));
    }
    if (rest.empty()) {
        throw TypeError{"CanvasRenderingContext2D.createImageData: takes an ImageData or a width and a height."};
    }
    const int32_t sw = enforcedLong(ctx, swOrImageData, "createImageData", 0), sh = enforcedLong(ctx, rest[0], "createImageData", 1);
    return ImageData::make(ctx, uint32_t(std::abs(int64_t(sw))), uint32_t(std::abs(int64_t(sh))));
}

Ref<ImageData> CanvasRenderingContext2D::getImageData(JSContext* ctx, int32_t, int32_t, int32_t sw, int32_t sh, std::optional<Value>) {
    // Profile 1: read back as transparent pixels.
    return ImageData::make(ctx, uint32_t(std::abs(int64_t(sw))), uint32_t(std::abs(int64_t(sh))));
}

void CanvasRenderingContext2D::putImageData(JSContext* ctx, Value imageData, Value dx, Value dy, std::vector<Value> dirty) {
    if (!this->command(ctx)) {
        return;
    }
    if (!unwrap<ImageData>(ctx, imageData.get(), idl::kImageData)) {
        throw TypeError{argumentMessage(ArgInfo{kInterface, "putImageData", 0}, "is not an ImageData.")};
    }
    if (!dirty.empty() && dirty.size() != 4) {
        throw TypeError{"CanvasRenderingContext2D.putImageData: takes 3 or 7 arguments."};
    }
    (void)enforcedLong(ctx, dx, "putImageData", 1);
    (void)enforcedLong(ctx, dy, "putImageData", 2);
    for (size_t i = 0; i < dirty.size(); i++) {
        (void)enforcedLong(ctx, dirty[i], "putImageData", int(3 + i));
    }
    // Profile 1: put nowhere.
}

// Lifetime.

void CanvasRenderingContext2D::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_canvasObject.mark(rt, mark);
    m_state.fill.object.mark(rt, mark);
    m_state.stroke.object.mark(rt, mark);
    for (const State& saved : m_stack) {
        saved.fill.object.mark(rt, mark);
        saved.stroke.object.mark(rt, mark);
    }
}

void CanvasRenderingContext2D::dispose(JSRuntime* rt) {
    if (m_registry) {
        m_registry->bySerial.erase(m_serial);
        m_registry.reset();
    }
    m_canvasObject.clear(rt);
    clearState(rt, m_state);
    for (State& saved : m_stack) {
        clearState(rt, saved);
    }
    m_stack.clear();
    m_bitmap.reset();
}

} // namespace wr
