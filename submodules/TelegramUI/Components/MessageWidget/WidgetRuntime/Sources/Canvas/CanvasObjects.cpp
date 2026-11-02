#include "Sources/Canvas/CanvasObjects.h"

#include <array>
#include <cmath>

#include "Generated/Bindings.h"
#include "Sources/Canvas/CanvasStyle.h"
#include "Sources/Host/Sequences.h"
#include "Sources/Runtime/LimitStops.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

bool finite(std::initializer_list<double> values) {
    for (double v : values) {
        if (!std::isfinite(v)) {
            return false;
        }
    }
    return true;
}

/// One of roundRect's radii: a number (x = y) or a DOMPointInit's x and y. nullopt: a non-finite value (the call does
/// nothing); a negative one is a RangeError.
std::optional<std::pair<double, double>> radiusOf(JSContext* ctx, JSValueConst v) {
    double x = 0, y = 0;
    if (JS_IsObject(v)) {
        // DOMPointInit: x and y, default 0, in that order.
        for (const char* member : {"x", "y"}) {
            Value m = Value::adopt(ctx, JS_GetPropertyStr(ctx, v, member));
            if (JS_IsException(m.get())) {
                throw Thrown{};
            }
            double& out = member[0] == 'x' ? x : y;
            if (!JS_IsUndefined(m.get())) {
                out = convert<Unrestricted>(ctx, m.get(), ArgInfo{"CanvasRenderingContext2D", "roundRect", 4}).value;
            }
        }
    } else {
        x = y = convert<Unrestricted>(ctx, v, ArgInfo{"CanvasRenderingContext2D", "roundRect", 4}).value;
    }
    if (!finite({x, y})) {
        return std::nullopt;
    }
    if (x < 0 || y < 0) {
        throw RangeError{"CanvasRenderingContext2D.roundRect: a radius is negative."};
    }
    return std::pair{x, y};
}

} // namespace

void CanvasGradient::addColorStop(JSContext* ctx, double offset, String color) {
    if (offset < 0 || offset > 1) {
        throw DOMError{"IndexSizeError", "CanvasGradient.addColorStop: the offset is outside 0 to 1."};
    }
    std::optional<canvas::Color> parsed = canvas::parseColor(ctx, color);
    if (!parsed) {
        throw DOMError{"SyntaxError", "CanvasGradient.addColorStop: the colour does not parse."};
    }
    m_data->addStop(offset, *parsed);
}

void CanvasPattern::setTransform(JSContext*, const idl::DOMMatrix2DInit& transform) {
    // Validated as HTML says, then ignored: a pattern draws nothing in profile 1.
    (void)matrixFromInit(transform);
}

canvas::Matrix matrixFromInit(const idl::DOMMatrix2DInit& init) {
    // geometry-1's "validate and fixup (2D)": a and m11 (and the rest) must agree when both are given.
    auto pick = [](const std::optional<Unrestricted>& short_, const std::optional<Unrestricted>& long_, double identity) {
        if (short_ && long_ && !(short_->value == long_->value || (std::isnan(short_->value) && std::isnan(long_->value)))) {
            throw TypeError{"DOMMatrix2DInit: a member and its long name differ."};
        }
        return long_ ? long_->value : short_ ? short_->value : identity;
    };
    return canvas::Matrix{pick(init.a, init.m11, 1), pick(init.b, init.m12, 0), pick(init.c, init.m21, 0),
                          pick(init.d, init.m22, 1), pick(init.e, init.m41, 0), pick(init.f, init.m42, 0)};
}

// Path2D.

Ref<Path2D> Path2D::construct(JSContext* ctx, std::optional<std::variant<Path2D*, String>> path) {
    Ref<Path2D> made = create<Path2D>(ctx, idl::kPath2D, JS_GetRuntime(ctx));
    if (path) {
        if (Path2D* const* other = std::get_if<Path2D*>(&*path)) {
            made->m_data = (*other)->m_data;
        } else {
            // Read up to the reference's 64 K (V5d final review, I2): a longer string makes an empty path, as the
            // reference's validator refuses its path data.
            const String& d = std::get<String>(*path);
            // limit.text-node (widget-sandbox v0.3.0): path data is a text value; past the cap the widget stops.
            const Limits& limits = Runtime::from(ctx).limits();
            if (limits.stops && d.length() > limits.textValueUnits) {
                stopForTextValue(ctx, d.length());
            }
            if (d.length() <= kMaxPathData) {
                canvas::path::appendSVG(made->m_data, d.utf8());
            }
        }
    }
    return made;
}

void Path2D::addPath(JSContext*, Path2D* path, const idl::DOMMatrix2DInit& transform) {
    const canvas::Matrix m = matrixFromInit(transform);
    if (!finite({m.a, m.b, m.c, m.d, m.e, m.f})) {
        return;
    }
    canvas::path::addPath(m_data, path->m_data, m);
}

void Path2D::closePath(JSContext*) { canvas::path::closePath(m_data); }
void Path2D::moveTo(JSContext*, Unrestricted x, Unrestricted y) { canvas::path::moveTo(m_data, canvas::Matrix(), x.value, y.value); }
void Path2D::lineTo(JSContext*, Unrestricted x, Unrestricted y) { canvas::path::lineTo(m_data, canvas::Matrix(), x.value, y.value); }
void Path2D::quadraticCurveTo(JSContext*, Unrestricted cpx, Unrestricted cpy, Unrestricted x, Unrestricted y) {
    canvas::path::quadraticCurveTo(m_data, canvas::Matrix(), cpx.value, cpy.value, x.value, y.value);
}
void Path2D::bezierCurveTo(JSContext*, Unrestricted cp1x, Unrestricted cp1y, Unrestricted cp2x, Unrestricted cp2y,
                           Unrestricted x, Unrestricted y) {
    canvas::path::bezierCurveTo(m_data, canvas::Matrix(), cp1x.value, cp1y.value, cp2x.value, cp2y.value, x.value, y.value);
}
void Path2D::arcTo(JSContext*, Unrestricted x1, Unrestricted y1, Unrestricted x2, Unrestricted y2, Unrestricted radius) {
    pathcalls::arcTo(m_data, canvas::Matrix(), x1.value, y1.value, x2.value, y2.value, radius.value);
}
void Path2D::rect(JSContext*, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h) {
    canvas::path::rect(m_data, canvas::Matrix(), x.value, y.value, w.value, h.value);
}
void Path2D::roundRect(JSContext* ctx, Unrestricted x, Unrestricted y, Unrestricted w, Unrestricted h, std::optional<Value> radii) {
    pathcalls::roundRect(ctx, m_data, canvas::Matrix(), x.value, y.value, w.value, h.value, radii);
}
void Path2D::arc(JSContext*, Unrestricted x, Unrestricted y, Unrestricted radius, Unrestricted start, Unrestricted end,
                 bool counterclockwise) {
    pathcalls::arc(m_data, canvas::Matrix(), x.value, y.value, radius.value, start.value, end.value, counterclockwise);
}
void Path2D::ellipse(JSContext*, Unrestricted x, Unrestricted y, Unrestricted rx, Unrestricted ry, Unrestricted rotation,
                     Unrestricted start, Unrestricted end, bool counterclockwise) {
    pathcalls::ellipse(m_data, canvas::Matrix(), x.value, y.value, rx.value, ry.value, rotation.value, start.value, end.value,
                       counterclockwise);
}

namespace pathcalls {

void arcTo(canvas::PathData& p, const canvas::Matrix& m, double x1, double y1, double x2, double y2, double radius) {
    if (finite({x1, y1, x2, y2, radius}) && radius < 0) {
        throw DOMError{"IndexSizeError", "arcTo: the radius is negative."};
    }
    canvas::path::arcTo(p, m, x1, y1, x2, y2, radius);
}

void arc(canvas::PathData& p, const canvas::Matrix& m, double x, double y, double radius, double start, double end, bool ccw) {
    if (finite({x, y, radius, start, end}) && radius < 0) {
        throw DOMError{"IndexSizeError", "arc: the radius is negative."};
    }
    canvas::path::arc(p, m, x, y, radius, start, end, ccw);
}

void ellipse(canvas::PathData& p, const canvas::Matrix& m, double x, double y, double rx, double ry, double rotation,
             double start, double end, bool ccw) {
    if (finite({x, y, rx, ry, rotation, start, end}) && (rx < 0 || ry < 0)) {
        throw DOMError{"IndexSizeError", "ellipse: a radius is negative."};
    }
    canvas::path::ellipse(p, m, x, y, rx, ry, rotation, start, end, ccw);
}

void roundRect(JSContext* ctx, canvas::PathData& p, const canvas::Matrix& m, double x, double y, double w, double h,
               const std::optional<Value>& radii) {
    // HTML: the radii are a number, a DOMPointInit, or a list of one to four of them (default 0).
    std::vector<std::pair<double, double>> list;
    bool skip = !finite({x, y, w, h});
    if (!radii) {
        list.push_back({0, 0});
    } else if (JS_IsObject(radii->get()) && !JS_IsFunction(ctx, radii->get())) {
        std::optional<std::vector<Value>> items = sequenceValues(ctx, radii->get(), "roundRect", 5);
        if (!items) {
            // A DOMPointInit on its own.
            std::optional<std::pair<double, double>> r = radiusOf(ctx, radii->get());
            if (!r) {
                skip = true;
            } else {
                list.push_back(*r);
            }
        } else {
            if (items->empty() || items->size() > 4) {
                throw RangeError{"CanvasRenderingContext2D.roundRect: radii has " + std::to_string(items->size()) +
                                 " entries, not one to four."};
            }
            for (const Value& item : *items) {
                std::optional<std::pair<double, double>> r = radiusOf(ctx, item.get());
                if (!r) {
                    skip = true;
                } else {
                    list.push_back(*r);
                }
            }
        }
    } else {
        std::optional<std::pair<double, double>> r = radiusOf(ctx, radii->get());
        if (!r) {
            skip = true;
        } else {
            list.push_back(*r);
        }
    }
    if (skip) {
        return;
    }
    // Upper-left, upper-right, lower-right, lower-left.
    std::array<std::pair<double, double>, 4> corners;
    switch (list.size()) {
    case 1:
        corners = {list[0], list[0], list[0], list[0]};
        break;
    case 2:
        corners = {list[0], list[1], list[0], list[1]};
        break;
    case 3:
        corners = {list[0], list[1], list[2], list[1]};
        break;
    default:
        corners = {list[0], list[1], list[2], list[3]};
        break;
    }
    std::array<double, 8> flat;
    for (size_t i = 0; i < 4; i++) {
        flat[2 * i] = corners[i].first;
        flat[2 * i + 1] = corners[i].second;
    }
    canvas::path::roundRect(p, m, x, y, w, h, flat);
}

} // namespace pathcalls

// ImageData.

Ref<ImageData> ImageData::make(JSContext* ctx, uint32_t width, uint32_t height) {
    if (width == 0 || height == 0) {
        throw DOMError{"IndexSizeError", "ImageData: a side is 0."};
    }
    if (uint64_t(width) * height > kMaxPixels) {
        throw RangeError{"ImageData: more than 3,500,000 pixels."};
    }
    Ref<ImageData> made = create<ImageData>(ctx, idl::kImageData, width, height);
    JSValue length = JS_NewInt64(ctx, int64_t(width) * height * 4);
    JSValue array = JS_NewTypedArray(ctx, 1, &length, JS_TYPED_ARRAY_UINT8C);
    if (JS_IsException(array)) {
        throw Thrown{};
    }
    made->m_data.set(JS_GetRuntime(ctx), array);
    return made;
}

Ref<ImageData> ImageData::construct(JSContext* ctx, Value a, Value b, std::optional<Value> c, std::optional<Value> d) {
    (void)d;
    const ArgInfo info{"ImageData", "constructor", 0};
    if (JS_IsObject(a.get())) {
        // (data, sw[, sh]): a Uint8ClampedArray whose length is a non-zero multiple of 4 × sw.
        if (JS_GetTypedArrayType(a.get()) != JS_TYPED_ARRAY_UINT8C) {
            throw TypeError{"ImageData: the data is not a Uint8ClampedArray."};
        }
        size_t bytes = 0;
        Value length = Value::adopt(ctx, JS_GetPropertyStr(ctx, a.get(), "length"));
        bytes = size_t(convert<uint32_t>(ctx, length.get(), info));
        const uint32_t sw = convert<uint32_t>(ctx, b.get(), info);
        if (bytes == 0 || bytes % 4 != 0 || sw == 0 || (bytes / 4) % sw != 0) {
            throw DOMError{"IndexSizeError", "ImageData: the data's length does not fit the width."};
        }
        const uint32_t sh = uint32_t(bytes / 4 / sw);
        if (c && convert<uint32_t>(ctx, c->get(), info) != sh) {
            throw DOMError{"IndexSizeError", "ImageData: the height does not fit the data."};
        }
        if (uint64_t(sw) * sh > kMaxPixels) {
            throw RangeError{"ImageData: more than 3,500,000 pixels."};
        }
        Ref<ImageData> made = create<ImageData>(ctx, idl::kImageData, sw, sh);
        made->m_data.set(JS_GetRuntime(ctx), JS_DupValue(ctx, a.get()));
        return made;
    }
    return make(ctx, convert<uint32_t>(ctx, a.get(), info), convert<uint32_t>(ctx, b.get(), info));
}

} // namespace wr
