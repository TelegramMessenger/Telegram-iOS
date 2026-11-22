#include "Sources/Render/LayerTree.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string_view>
#include <type_traits>
#include <utility>

#include <litehtml/document.h>
#include <litehtml/element.h>

namespace wr {

// Every payload's fields are listed once, in the put() functions below, and read through one of two sinks:
// - TextSink prints them for dump();
// - KeySink writes them exactly (floats by their bits, strings length-prefixed, every value tagged) into a key string,
//   and two items paint the same when their keys are equal (samePaint).
// So the dump and the diff never disagree about which fields an item has. The sinks differ only where a stable dump
// cannot show the value: identities (fonts, images), and the glyphs, which KeySink compares in full and TextSink
// summarizes; and in one place where the key must not read the value: a text item's font description, shared per font,
// which KeySink takes by identity and TextSink prints.
//
// A field litehtml adds to one of these structs must be added to its put(). The static_asserts below are the
// tripwire: they fail when a struct's size changes (sizes measured for 64-bit libc++, the host tests' and the app's).
#if defined(_LIBCPP_VERSION) && UINTPTR_MAX == UINT64_MAX
static_assert(sizeof(litehtml::position) == 16);
static_assert(sizeof(litehtml::pointF) == 8);
static_assert(sizeof(litehtml::web_color) == 5);
static_assert(sizeof(litehtml::border_radiuses) == 32);
static_assert(sizeof(litehtml::border) == 16);
static_assert(sizeof(litehtml::borders) == 96);
static_assert(sizeof(litehtml::css_length) == 16);
static_assert(sizeof(litehtml::shadow_paint) == 24);
static_assert(sizeof(litehtml::background_layer) == 92);
static_assert(sizeof(litehtml::background_layer::color_point) == 20);
static_assert(sizeof(litehtml::background_layer::gradient_base) == 32);
static_assert(sizeof(litehtml::background_layer::linear_gradient) == 48);
static_assert(sizeof(litehtml::background_layer::radial_gradient) == 48);
static_assert(sizeof(litehtml::background_layer::conic_gradient) == 48);
static_assert(sizeof(litehtml::list_marker) == 72);
static_assert(sizeof(litehtml::vector_path) == 168);
static_assert(sizeof(litehtml::svg_gradient) == 56);
static_assert(sizeof(litehtml::filter_function) == 64);
static_assert(sizeof(litehtml::paint_group) == 52);
static_assert(sizeof(litehtml::transform_matrix) == 24);
static_assert(sizeof(litehtml::font_description) == 168);
static_assert(sizeof(litehtml::font_description::text_shadow) == 20);
#endif

namespace {

class TextSink {
public:
    explicit TextSink(std::string& out) : m_out(out) {}

    void label(const char* name) {
        separate();
        m_out += name;
        m_out += '=';
        m_labelled = true;
    }
    void open() {
        separate();
        m_out += '(';
        m_first.push_back(true);
    }
    void close() {
        m_first.pop_back();
        m_out += ')';
    }
    void number(double value) {
        separate();
        appendf("%g", value);
    }
    void integer(long long value) {
        separate();
        appendf("%lld", value);
    }
    void flag(bool value) {
        separate();
        m_out += value ? '1' : '0';
    }
    void word(const char* value) {
        separate();
        m_out += value;
    }
    void absent() {
        separate();
        m_out += '-';
    }
    void string(std::string_view value) {
        separate();
        m_out += '"';
        for (char c : value) {
            if (c == '"' || c == '\\') {
                m_out += '\\';
                m_out += c;
            } else if (static_cast<unsigned char>(c) < 0x20 || c == 0x7f) {
                appendf("\\x%02x", unsigned(static_cast<unsigned char>(c)));
            } else {
                m_out += c;
            }
        }
        m_out += '"';
    }
    void color(const litehtml::web_color& value) {
        separate();
        appendf("#%02x%02x%02x%02x", unsigned(value.red), unsigned(value.green), unsigned(value.blue),
                unsigned(value.alpha));
        if (value.is_current_color) {
            m_out += "!current";
        }
    }
    void length(const litehtml::css_length& value) {
        separate();
        if (value.is_predefined()) {
            appendf("predef%d", value.predef());
            return;
        }
        // twidget edit 48: a math function kept to layout, in its canonical form.
        if (value.is_calc()) {
            m_out += value.to_string();
            return;
        }
        static const char* const units[] = {"", "%", "in", "cm", "mm", "em", "ex", "pt", "pc", "px",
                                             "vw", "vh", "vmin", "vmax", "rem", "ch"};
        const size_t unit = size_t(value.units());
        appendf("%g", double(value.val()));
        if (unit < sizeof(units) / sizeof(units[0])) {
            m_out += units[unit];
        } else {
            appendf("u%zu", unit);
        }
    }
    /// Not stable across runs: printed as nothing.
    void identity(const void*) {}
    void shaped(const ShapedText& value) {
        double advance = 0;
        for (float a : value.advances) {
            advance += a;
        }
        label("glyphs");
        integer((long long)value.glyphs.size());
        label("advance");
        number(advance);
    }

private:
    void separate() {
        if (m_labelled) {
            m_labelled = false;
        } else if (m_first.empty()) {
            m_out += ' ';
        } else if (m_first.back()) {
            m_first.back() = false;
        } else {
            m_out += ',';
        }
    }
    template <class... Args>
    void appendf(const char* format, Args... args) {
        char text[64];
        const int length = std::snprintf(text, sizeof(text), format, args...);
        if (length > 0) {
            m_out.append(text, std::min(size_t(length), sizeof(text) - 1));
        }
    }

    std::string& m_out;
    std::vector<bool> m_first;   // per open structure: whether its next value is its first
    bool m_labelled = false;     // a label was just written: its value takes no separator
};

class KeySink {
public:
    void label(const char*) {}
    void open() { m_out += '('; }
    void close() { m_out += ')'; }
    // -0 and +0 paint the same: `+ 0.0` makes -0 +0, so they share a key.
    void number(double value) { tagged('n', value + 0.0); }
    void integer(long long value) { tagged('i', value); }
    void flag(bool value) { m_out += value ? 'T' : 'F'; }
    void word(const char* value) {
        m_out += 'w';
        m_out += value;
        m_out += '\0';
    }
    void absent() { m_out += '-'; }
    void string(std::string_view value) {
        tagged('s', uint64_t(value.size()));
        m_out.append(value);
    }
    void color(const litehtml::web_color& value) {
        const unsigned char bytes[] = {'c', value.red, value.green, value.blue, value.alpha,
                                       static_cast<unsigned char>(value.is_current_color ? 1 : 0)};
        m_out.append(reinterpret_cast<const char*>(bytes), sizeof(bytes));
    }
    void length(const litehtml::css_length& value) {
        m_out += 'l';
        flag(value.is_predefined());
        integer(value.predef());
        number(value.val());
        integer(static_cast<long long>(value.units()));
        // twidget edit 48: a calc's tree, by its canonical form.
        flag(value.is_calc());
        if (value.is_calc()) {
            const std::string tree = value.to_string();
            tagged('c', uint64_t(tree.size()));
            m_out += tree;
        }
    }
    void identity(const void* value) { tagged('p', reinterpret_cast<uintptr_t>(value)); }
    void shaped(const ShapedText& value) {
        tagged('g', uint64_t(value.glyphs.size()));
        m_out.append(reinterpret_cast<const char*>(value.glyphs.data()), value.glyphs.size() * sizeof(uint32_t));
        tagged('a', uint64_t(value.advances.size()));
        m_out.append(reinterpret_cast<const char*>(value.advances.data()), value.advances.size() * sizeof(float));
    }

    const std::string& key() const { return m_out; }

private:
    template <class T>
    void tagged(char tag, T value) {
        m_out += tag;
        char bytes[sizeof(T)];
        std::memcpy(bytes, &value, sizeof(T));
        m_out.append(bytes, sizeof(T));
    }

    std::string m_out;
};

// The fields of each type. Structures are parenthesized; a labelled field is `name=value` in the dump.

template <class S>
void put(S& s, const litehtml::position& p) {
    s.open();
    s.number(p.x.value());
    s.number(p.y.value());
    s.number(p.width.value());
    s.number(p.height.value());
    s.close();
}

template <class S>
void put(S& s, const litehtml::pointF& p) {
    s.open();
    s.number(p.x);
    s.number(p.y);
    s.close();
}

template <class S>
void put(S& s, const litehtml::border_radiuses& r) {
    s.open();
    for (const litehtml::pixel_t* value : {&r.top_left_x, &r.top_left_y, &r.top_right_x, &r.top_right_y,
                                           &r.bottom_right_x, &r.bottom_right_y, &r.bottom_left_x, &r.bottom_left_y}) {
        s.number(value->value());
    }
    s.close();
}

template <class S>
void put(S& s, const litehtml::border& b) {
    s.open();
    s.number(b.width.value());
    s.integer(static_cast<long long>(b.style));
    s.color(b.color);
    s.close();
}

template <class S>
void put(S& s, const litehtml::borders& b) {
    s.open();
    s.label("left");
    put(s, b.left);
    s.label("top");
    put(s, b.top);
    s.label("right");
    put(s, b.right);
    s.label("bottom");
    put(s, b.bottom);
    s.label("radius");
    put(s, b.radius);
    s.close();
}

template <class S>
void put(S& s, const litehtml::shadow_paint& p) {
    s.open();
    s.number(p.x.value());
    s.number(p.y.value());
    s.number(p.blur.value());
    s.number(p.spread.value());
    s.color(p.color);
    s.flag(p.inset);
    s.close();
}

template <class S>
void put(S& s, const litehtml::background_layer& l) {
    s.open();
    s.label("border");
    put(s, l.border_box);
    s.label("radius");
    put(s, l.border_radius);
    s.label("clip");
    put(s, l.clip_box);
    s.label("origin");
    put(s, l.origin_box);
    s.label("attachment");
    s.integer(static_cast<long long>(l.attachment));
    s.label("repeat");
    s.integer(static_cast<long long>(l.repeat));
    s.label("root");
    s.flag(l.is_root);
    s.close();
}

template <class S>
void putGradientBase(S& s, const litehtml::background_layer::gradient_base& g) {
    s.label("points");
    s.open();
    for (const auto& point : g.color_points) {
        s.open();
        s.number(point.offset);
        s.color(point.color);
        if (point.hint) {
            s.number(*point.hint);
        } else {
            s.absent();
        }
        s.close();
    }
    s.close();
    s.label("space");
    s.integer(static_cast<long long>(g.color_space));
    s.label("hue");
    s.integer(static_cast<long long>(g.hue_interpolation));
}

template <class S>
void putPath(S& s, const litehtml::vector_path& p) {
    s.label("ops");
    s.open();
    for (auto op : p.ops) {
        s.integer(static_cast<long long>(op));
    }
    s.close();
    s.label("points");
    s.open();
    for (float value : p.points) {
        s.number(value);
    }
    s.close();
    s.label("fill");
    s.flag(p.fill);
    s.label("fill-color");
    s.color(p.fill_color);
    s.label("evenodd");
    s.flag(p.evenodd);
    s.label("stroke");
    s.flag(p.stroke);
    s.label("stroke-color");
    s.color(p.stroke_color);
    s.label("stroke-width");
    s.number(p.stroke_width);
    s.label("cap");
    s.integer(p.line_cap);
    s.label("join");
    s.integer(p.line_join);
    s.label("miter");
    s.number(p.miter_limit);
    s.label("dashes");
    s.open();
    for (float value : p.dashes) {
        s.number(value);
    }
    s.close();
    s.label("dash-offset");
    s.number(p.dash_offset);
    const litehtml::svg_gradient& g = p.fill_gradient;
    s.label("gradient");
    s.open();
    s.integer(g.type);
    for (float value : {g.x1, g.y1, g.x2, g.y2, g.r, g.fx, g.fy}) {
        s.number(value);
    }
    s.open();
    for (const auto& stop : g.stops) {
        s.open();
        s.number(stop.first);
        s.color(stop.second);
        s.close();
    }
    s.close();
    s.close();
}

const char* filterName(litehtml::filter_function::kind_t kind) {
    switch (kind) {
    case litehtml::filter_function::blur: return "blur";
    case litehtml::filter_function::brightness: return "brightness";
    case litehtml::filter_function::contrast: return "contrast";
    case litehtml::filter_function::grayscale: return "grayscale";
    case litehtml::filter_function::hue_rotate: return "hue-rotate";
    case litehtml::filter_function::invert: return "invert";
    case litehtml::filter_function::opacity: return "opacity";
    case litehtml::filter_function::saturate: return "saturate";
    case litehtml::filter_function::sepia: return "sepia";
    case litehtml::filter_function::drop_shadow: return "drop-shadow";
    }
    return nullptr;
}

template <class S>
void put(S& s, const litehtml::filter_vector& steps) {
    s.open();
    for (const auto& step : steps) {
        s.open();
        if (const char* name = filterName(step.kind)) {
            s.word(name);
        } else {
            s.integer(static_cast<long long>(step.kind));
        }
        s.label("amount");
        s.number(step.amount);
        s.label("x");
        s.length(step.x);
        s.label("y");
        s.length(step.y);
        s.label("radius");
        s.length(step.radius);
        s.label("color");
        s.color(step.color);
        s.close();
    }
    s.close();
}

template <class S>
void put(S& s, const litehtml::transform_matrix& m) {
    s.open();
    for (float value : {m.a, m.b, m.c, m.d, m.tx, m.ty}) {
        s.number(value);
    }
    s.close();
}

template <class S>
void putGroup(S& s, const litehtml::paint_group& g) {
    s.label("opacity");
    s.number(g.opacity);
    s.label("matrix");
    put(s, g.matrix);
    s.label("backface");
    s.flag(g.backface_hidden);
    s.label("bounds");
    put(s, g.bounds);
    s.label("exact");
    s.flag(g.exact_bounds);
}

template <class S>
void put(S& s, const litehtml::font_description& d) {
    s.open();
    s.label("family");
    s.string(d.family);
    s.label("size");
    s.number(d.size.value());
    s.label("style");
    s.integer(static_cast<long long>(d.style));
    s.label("weight");
    s.integer(d.weight);
    s.label("decoration");
    s.open();
    s.integer(d.decoration_line);
    s.length(d.decoration_thickness);
    s.integer(static_cast<long long>(d.decoration_style));
    s.color(d.decoration_color);
    s.close();
    s.label("emphasis");
    s.open();
    s.string(d.emphasis_style);
    s.color(d.emphasis_color);
    s.integer(d.emphasis_position);
    s.close();
    s.label("letter-spacing");
    s.number(d.letter_spacing);
    s.label("smoothing");
    s.integer(d.smoothing);
    s.label("shadow");
    s.open();
    s.number(d.shadow_x);
    s.number(d.shadow_y);
    s.number(d.shadow_blur);
    s.color(d.shadow_color);
    s.close();
    s.label("extra-shadows");
    s.open();
    for (const auto& shadow : d.extra_shadows) {
        s.open();
        s.number(shadow.x);
        s.number(shadow.y);
        s.number(shadow.blur);
        s.color(shadow.color);
        s.close();
    }
    s.close();
    s.label("tabular");
    s.flag(d.tabular_nums);
    s.close();
}

template <class S>
void putDecoded(S& s, const DecodedImage& image) {
    s.identity(image.image.get());
    s.open();
    s.number(image.width);
    s.number(image.height);
    s.close();
}

template <class S>
void putPayload(S& s, const TextItem& t) {
    s.label("pos");
    put(s, t.pos);
    s.label("color");
    s.color(t.color);
    s.label("text");
    s.string(t.text);
    // The description is shared and immutable, one per cached font (Ruling E4): the key compares it by identity, so a
    // long family is never re-read per item; the dump prints it.
    s.label("font");
    if constexpr (std::is_same_v<S, KeySink>) {
        s.identity(t.description.get());
    } else if (t.description) {
        put(s, *t.description);
    } else {
        s.absent();
    }
    s.identity(t.font.get());
    s.shaped(t.shaped);
}

template <class S>
void putPayload(S& s, const ListMarkerItem& m) {
    // baseurl, font and image are always cleared (LayerTree.h): nothing to print or compare.
    s.label("marker");
    s.open();
    s.label("type");
    s.integer(static_cast<long long>(m.marker.marker_type));
    s.label("color");
    s.color(m.marker.color);
    s.label("pos");
    put(s, m.marker.pos);
    s.label("index");
    s.integer(m.marker.index);
    s.close();
    s.label("font");
    s.flag(m.font != nullptr);
    s.identity(m.font.get());
    s.label("image");
    if (m.image) {
        putDecoded(s, *m.image);
    } else {
        s.absent();
    }
}

template <class S>
void putPayload(S& s, const ImageItem& i) {
    s.label("layer");
    put(s, i.layer);
    s.label("size");
    putDecoded(s, i.image);
}

template <class S>
void putPayload(S& s, const FillItem& f) {
    s.label("layer");
    put(s, f.layer);
    s.label("color");
    s.color(f.color);
}

template <class S>
void putPayload(S& s, const LinearGradientItem& g) {
    s.label("layer");
    put(s, g.layer);
    putGradientBase(s, g.gradient);
    s.label("start");
    put(s, g.gradient.start);
    s.label("end");
    put(s, g.gradient.end);
}

template <class S>
void putPayload(S& s, const RadialGradientItem& g) {
    s.label("layer");
    put(s, g.layer);
    putGradientBase(s, g.gradient);
    s.label("position");
    put(s, g.gradient.position);
    s.label("radius");
    put(s, g.gradient.radius);
}

template <class S>
void putPayload(S& s, const ConicGradientItem& g) {
    s.label("layer");
    put(s, g.layer);
    putGradientBase(s, g.gradient);
    s.label("position");
    put(s, g.gradient.position);
    s.label("angle");
    s.number(g.gradient.angle);
    s.label("radius");
    s.number(g.gradient.radius);
}

template <class S>
void putPayload(S& s, const BordersItem& b) {
    s.label("borders");
    put(s, b.borders);
    s.label("pos");
    put(s, b.drawPos);
    s.label("root");
    s.flag(b.root);
}

template <class S>
void putPayload(S& s, const BoxShadowItem& b) {
    s.label("box");
    put(s, b.box);
    s.label("radius");
    put(s, b.radius);
    s.label("shadow");
    put(s, b.shadow);
}

template <class S>
void putPayload(S& s, const PathItem& p) {
    putPath(s, p.path);
}

template <class S>
void putPayload(S& s, const BackdropItem& b) {
    s.label("steps");
    put(s, b.steps);
    s.label("paint-bounds");
    put(s, b.bounds);
    s.label("box");
    put(s, b.box);
    s.label("radius");
    put(s, b.radius);
}

template <class S>
void putPayload(S& s, const ClipItem& c) {
    s.label("pos");
    put(s, c.pos);
    s.label("radius");
    put(s, c.radius);
}

template <class S>
void putPayload(S& s, const ClipPathItem& c) {
    putPath(s, c.path);
}

template <class S>
void putPayload(S&, const std::monostate&) {}

template <class S>
void putItem(S& s, const PaintItem& item) {
    s.integer(static_cast<long long>(item.kind));
    s.label("bounds");
    put(s, item.bounds);
    std::visit([&s](const auto& payload) { putPayload(s, payload); }, item.payload);
}

template <class S>
void putLayer(S& s, const Layer& layer) {
    switch (layer.kind) {
    case Layer::Kind::Group:
        putGroup(s, layer.group);
        break;
    case Layer::Kind::Filter:
        s.label("steps");
        put(s, layer.filter);
        s.label("box");
        put(s, layer.box);
        break;
    case Layer::Kind::Isolated:
    case Layer::Kind::Root:
        s.label("box");
        put(s, layer.box);
        break;
    }
}

const char* itemName(PaintItem::Kind kind) {
    switch (kind) {
    case PaintItem::Kind::Text: return "text";
    case PaintItem::Kind::ListMarker: return "list-marker";
    case PaintItem::Kind::Image: return "image";
    case PaintItem::Kind::SolidFill: return "solid-fill";
    case PaintItem::Kind::LinearGradient: return "linear-gradient";
    case PaintItem::Kind::RadialGradient: return "radial-gradient";
    case PaintItem::Kind::ConicGradient: return "conic-gradient";
    case PaintItem::Kind::Borders: return "borders";
    case PaintItem::Kind::BoxShadow: return "box-shadow";
    case PaintItem::Kind::Path: return "path";
    case PaintItem::Kind::Backdrop: return "backdrop";
    case PaintItem::Kind::SetClip: return "set-clip";
    case PaintItem::Kind::DelClip: return "del-clip";
    case PaintItem::Kind::SuspendClips: return "suspend-clips";
    case PaintItem::Kind::ResumeClips: return "resume-clips";
    case PaintItem::Kind::SetClipPath: return "set-clip-path";
    }
    return "item";
}

const char* layerName(Layer::Kind kind) {
    switch (kind) {
    case Layer::Kind::Root: return "root";
    case Layer::Kind::Group: return "group";
    case Layer::Kind::Filter: return "filter";
    case Layer::Kind::Isolated: return "isolated";
    }
    return "layer";
}

template <class T, class Fields>
std::string keyOf(const T& value, Fields fields) {
    KeySink sink;
    fields(sink, value);
    return sink.key();
}

} // namespace

Layer::~Layer() {
    // Moves every descendant layer into `pending` before destroying it, so each destructor runs with no child layers
    // left and none of them descends. A moved-from Layer (LayerTree's constructor takes one by value) has whatever
    // entries the move left, empty for std::vector, and is taken apart the same way.
    std::vector<std::unique_ptr<Layer>> pending;
    auto release = [&pending](Layer& layer) {
        for (auto& entry : layer.entries) {
            if (auto* child = std::get_if<std::unique_ptr<Layer>>(&entry); child && *child) {
                pending.push_back(std::move(*child));
            }
        }
        layer.entries.clear();
    };
    release(*this);
    while (!pending.empty()) {
        std::unique_ptr<Layer> layer = std::move(pending.back());
        pending.pop_back();
        release(*layer);
    }
}

const litehtml::position& layerBounds(const Layer& layer) {
    return layer.kind == Layer::Kind::Group ? layer.group.bounds : layer.box;
}

litehtml::position entryBounds(const LayerEntry& entry) {
    if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
        return item->bounds;
    }
    const Layer* layer = std::get<std::unique_ptr<Layer>>(entry).get();
    if (!layer) {
        return {};
    }
    return layer->kind == Layer::Kind::Group ? mapRect(layer->group.matrix, layer->group.bounds) : layer->box;
}

litehtml::position mapRect(const litehtml::transform_matrix& m, const litehtml::position& rect) {
    if (m.is_identity()) {
        return rect;
    }
    const float x0 = rect.x.value();
    const float y0 = rect.y.value();
    const float x1 = x0 + rect.width.value();
    const float y1 = y0 + rect.height.value();
    float minX = 0, minY = 0, maxX = 0, maxY = 0;
    bool first = true;
    for (float x : {x0, x1}) {
        for (float y : {y0, y1}) {
            const float mx = m.a * x + m.c * y + m.tx;
            const float my = m.b * x + m.d * y + m.ty;
            if (first) {
                minX = maxX = mx;
                minY = maxY = my;
                first = false;
            } else {
                minX = std::min(minX, mx);
                maxX = std::max(maxX, mx);
                minY = std::min(minY, my);
                maxY = std::max(maxY, my);
            }
        }
    }
    return litehtml::position(minX, minY, maxX - minX, maxY - minY);
}

bool hasNoArea(const litehtml::position& rect) {
    return !(rect.width.value() > 0 && rect.height.value() > 0);
}

litehtml::position unite(const litehtml::position& a, const litehtml::position& b) {
    if (hasNoArea(b)) {
        return a;
    }
    if (hasNoArea(a)) {
        return b;
    }
    const float left = std::min(a.x.value(), b.x.value());
    const float top = std::min(a.y.value(), b.y.value());
    const float right = std::max(a.x.value() + a.width.value(), b.x.value() + b.width.value());
    const float bottom = std::max(a.y.value() + a.height.value(), b.y.value() + b.height.value());
    return litehtml::position(left, top, right - left, bottom - top);
}

bool samePaint(const PaintItem& a, const PaintItem& b) {
    if (a.kind != b.kind || a.payload.index() != b.payload.index()) {
        return false;
    }
    auto fields = [](KeySink& sink, const PaintItem& item) { putItem(sink, item); };
    return keyOf(a, fields) == keyOf(b, fields);
}

bool sameLayerProperties(const Layer& a, const Layer& b) {
    if (a.kind != b.kind) {
        return false;
    }
    switch (a.kind) {
    case Layer::Kind::Root:
        return true;
    case Layer::Kind::Group: {
        auto fields = [](KeySink& sink, const Layer& layer) { putGroup(sink, layer.group); };
        return keyOf(a, fields) == keyOf(b, fields);
    }
    case Layer::Kind::Filter: {
        auto fields = [](KeySink& sink, const Layer& layer) { put(sink, layer.filter); };
        return keyOf(a, fields) == keyOf(b, fields);
    }
    case Layer::Kind::Isolated: {
        auto fields = [](KeySink& sink, const Layer& layer) { put(sink, layer.box); };
        return keyOf(a, fields) == keyOf(b, fields);
    }
    }
    return false;
}

namespace {

size_t countItems(const Layer& root) {
    size_t count = 0;
    std::vector<const Layer*> stack{&root};
    while (!stack.empty()) {
        const Layer* layer = stack.back();
        stack.pop_back();
        for (const auto& entry : layer->entries) {
            if (std::holds_alternative<PaintItem>(entry)) {
                count++;
            } else if (const Layer* child = std::get<std::unique_ptr<Layer>>(entry).get()) {
                stack.push_back(child);
            }
        }
    }
    return count;
}

// ---- Flattening a mirror (Task 10b). ----

litehtml::position shifted(const litehtml::position& p, float dx, float dy) {
    return litehtml::position(p.x.value() + dx, p.y.value() + dy, p.width.value(), p.height.value());
}

void shift(litehtml::position& p, float dx, float dy) {
    p = shifted(p, dx, dy);
}

void shift(litehtml::pointF& p, float dx, float dy) {
    p.x += dx;
    p.y += dy;
}

void shift(litehtml::background_layer& layer, float dx, float dy) {
    shift(layer.border_box, dx, dy);
    shift(layer.clip_box, dx, dy);
    // A colour layer's origin box is unset (background::get_layer leaves it zero): not a place, so it never moves.
    if (!(layer.origin_box == litehtml::position())) {
        shift(layer.origin_box, dx, dy);
    }
}

void shift(litehtml::vector_path& path, float dx, float dy) {
    for (size_t i = 0; i < path.points.size(); i++) {
        path.points[i] += i % 2 == 0 ? dx : dy;
    }
}

// `item`'s payload moved by (dx, dy): every position it holds, in the coordinates of the layer it is drawn in.
void shiftPayload(PaintItem& item, float dx, float dy) {
    std::visit(
        [&](auto& payload) {
            using T = std::decay_t<decltype(payload)>;
            if constexpr (std::is_same_v<T, TextItem>) {
                shift(payload.pos, dx, dy);
            } else if constexpr (std::is_same_v<T, ListMarkerItem>) {
                shift(payload.marker.pos, dx, dy);
            } else if constexpr (std::is_same_v<T, ImageItem> || std::is_same_v<T, FillItem>) {
                shift(payload.layer, dx, dy);
            } else if constexpr (std::is_same_v<T, LinearGradientItem>) {
                shift(payload.layer, dx, dy);
                shift(payload.gradient.start, dx, dy);
                shift(payload.gradient.end, dx, dy);
            } else if constexpr (std::is_same_v<T, RadialGradientItem> || std::is_same_v<T, ConicGradientItem>) {
                shift(payload.layer, dx, dy);
                shift(payload.gradient.position, dx, dy);
            } else if constexpr (std::is_same_v<T, BordersItem>) {
                shift(payload.drawPos, dx, dy);
            } else if constexpr (std::is_same_v<T, BoxShadowItem>) {
                shift(payload.box, dx, dy);
            } else if constexpr (std::is_same_v<T, PathItem>) {
                shift(payload.path, dx, dy);
            } else if constexpr (std::is_same_v<T, BackdropItem>) {
                shift(payload.bounds, dx, dy);
                shift(payload.box, dx, dy);
            } else if constexpr (std::is_same_v<T, ClipItem>) {
                shift(payload.pos, dx, dy);
            } else if constexpr (std::is_same_v<T, ClipPathItem>) {
                shift(payload.path, dx, dy);
            }
        },
        item.payload);
}

std::unique_ptr<Layer> layerShell(const Layer& from) {
    auto layer = std::make_unique<Layer>();
    layer->kind = from.kind;
    layer->group = from.group;
    layer->filter = from.filter;
    layer->box = from.box;
    return layer;
}

// Appends `from`'s entries to `into`, moved by (dx, dy) where they are in `into`'s coordinates: items with their bounds
// recomputed by the recorder's rules; an Isolated or a Filter layer's contents moved with it; a Group's matrix moved
// (its contents are in its own space and stay). (0, 0) copies.
void appendShifted(const Layer& from, Layer& into, float dx, float dy) {
    struct Frame {
        const Layer* from;
        Layer* into;
        size_t next;
        bool move;
    };
    std::vector<Frame> stack{{&from, &into, 0, true}};
    while (!stack.empty()) {
        Frame& frame = stack.back();
        if (frame.next == frame.from->entries.size()) {
            Layer* done = frame.into;
            const bool moved = frame.move;
            stack.pop_back();
            // A Filter's box is the union of its entries' bounds, set when its paint returns (WidgetContainer).
            if (done->kind == Layer::Kind::Filter && moved) {
                litehtml::position bounds;
                for (const auto& entry : done->entries) {
                    bounds = unite(bounds, entryBounds(entry));
                }
                done->box = bounds;
            }
            continue;
        }
        const LayerEntry& entry = frame.from->entries[frame.next++];
        Layer* target = frame.into;
        const bool move = frame.move;
        if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
            PaintItem copy = *item;
            if (move && (dx != 0 || dy != 0)) {
                shiftPayload(copy, dx, dy);
                copy.bounds = paintBounds(copy, *target);
            }
            target->entries.emplace_back(std::move(copy));
            continue;
        }
        const Layer& child = *std::get<std::unique_ptr<Layer>>(entry);
        auto copy = layerShell(child);
        bool inner = move;
        if (move) {
            if (child.kind == Layer::Kind::Group) {
                copy->group.matrix.tx += dx;
                copy->group.matrix.ty += dy;
                inner = false;
            } else if (child.kind == Layer::Kind::Isolated) {
                shift(copy->box, dx, dy);
            }
        }
        Layer* next = copy.get();
        target->entries.emplace_back(std::move(copy));
        stack.push_back({&child, next, 0, inner});
    }
}

PaintItem clipItem(PaintItem::Kind kind) {
    return PaintItem{kind, litehtml::position(), std::monostate()};
}

} // namespace

void appendMoved(const Layer& from, Layer& into, float dx, float dy) {
    appendShifted(from, into, dx, dy);
}

LayerTree::LayerTree(double width, double height, Layer root, litehtml::web_color canvas)
    : m_width(width), m_height(height), m_canvas(canvas), m_root(std::move(root)) {
    std::call_once(m_flattened, [this] { m_itemCount = countItems(m_root); });
}

LayerTree::LayerTree(double width, double height, std::shared_ptr<const MirrorNode> root, litehtml::web_color canvas)
    : m_width(width), m_height(height), m_canvas(canvas), m_mirror(std::move(root)) {}

litehtml::web_color canvasColor(litehtml::document& document) {
    const litehtml::element::ptr root = document.root();
    if (!root) {
        return litehtml::web_color::transparent;
    }
    const litehtml::background* background = root->get_background();
    if (!background) {
        return litehtml::web_color::transparent;
    }
    litehtml::web_color color = background->m_color;
    if (color.is_current_color) {
        // The element whose background it is: the root's own, else the body's it propagates.
        litehtml::element::ptr owner = root;
        if (root->get_background(true) == nullptr) {
            for (const litehtml::element::ptr& child : root->children()) {
                if (child->is_body()) {
                    owner = child;
                    break;
                }
            }
        }
        color = owner->css().get_color();
    }
    return color;
}

const Layer& LayerTree::root() const {
    std::call_once(m_flattened, [this] { flatten(); });
    return m_root;
}

size_t LayerTree::itemCount() const {
    root();
    return m_itemCount;
}

// The flattening (the file comment): each context's children in order, each Box's or Inline's content moved to its
// absolute origin, each child's clip chain opened and closed as draw_children opens them (consecutive children of one
// pass under one clipper share a set-clip; a pass boundary closes them all), a group's parameters as draw_group's
// begin-group, set-clip-path, backdrop and filter layer, and an escaping context between suspend-clips and resume-clips.
void LayerTree::flatten() const {
    // Built into a local and moved in at the end: call_once runs this again after a throw (bad_alloc), and a partly filled
    // m_root would take the second run's entries after the first's.
    Layer root;
    root.kind = Layer::Kind::Root;
    root.box = litehtml::position(0, 0, float(m_width), float(m_height));
    if (!m_mirror) {
        m_root = std::move(root);
        return;
    }
    struct Frame {
        const MirrorNode* context;
        size_t next;
        float x, y;              // the context's absolute origin
        Layer* target;           // where its children's items go
        Layer* outer;            // where the context itself went (escapes close there)
        Layer* groupLayer;       // its group layer, or null
        Layer* filterLayer;      // its filter layer, or null
        std::vector<const MirrorClip*> open;
        bool any = false;        // a child came before: lastPass and lastZ are set
        MirrorPass lastPass = MirrorPass::Own;
        int lastZ = 0;
    };
    // Opens and closes `frame`'s clips for a child with `clips` in (pass, z).
    auto sync = [](Frame& frame, const std::vector<MirrorClip>& clips, MirrorPass pass, int z) {
        if (frame.any && (pass != frame.lastPass || z != frame.lastZ)) {
            for (size_t i = 0; i < frame.open.size(); i++) {
                frame.target->entries.emplace_back(clipItem(PaintItem::Kind::DelClip));
            }
            frame.open.clear();
        }
        size_t common = 0;
        while (common < frame.open.size() && common < clips.size() &&
               frame.open[common]->clipper == clips[common].clipper) {
            common++;
        }
        for (size_t i = common; i < frame.open.size(); i++) {
            frame.target->entries.emplace_back(clipItem(PaintItem::Kind::DelClip));
        }
        frame.open.resize(common);
        for (size_t i = common; i < clips.size(); i++) {
            const litehtml::position box = shifted(clips[i].box, frame.x, frame.y);
            frame.target->entries.emplace_back(
                PaintItem{PaintItem::Kind::SetClip, box, ClipItem{box, clips[i].radius}});
            frame.open.push_back(&clips[i]);
        }
        frame.any = true;
        frame.lastPass = pass;
        frame.lastZ = z;
    };
    // Opens `context` in `target` at the absolute origin (x, y): its escape and its group's layers and items.
    auto enter = [](const MirrorNode& context, Layer& target, float x, float y) {
        Frame frame{&context, 0, x, y, &target, &target, nullptr, nullptr, {}};
        if (context.escapes) {
            target.entries.emplace_back(clipItem(PaintItem::Kind::SuspendClips));
        }
        if (const MirrorGroup* group = context.group.get()) {
            auto layer = std::make_unique<Layer>();
            layer->kind = Layer::Kind::Group;
            layer->group = group->group;
            Layer* opened = layer.get();
            target.entries.emplace_back(std::move(layer));
            frame.groupLayer = opened;
            if (group->clipPath) {
                PaintItem item{PaintItem::Kind::SetClipPath, litehtml::position(), ClipPathItem{*group->clipPath}};
                item.bounds = paintBounds(item, *opened);
                opened->entries.emplace_back(std::move(item));
            }
            if (group->backdrop) {
                PaintItem item{PaintItem::Kind::Backdrop, litehtml::position(), *group->backdrop};
                item.bounds = paintBounds(item, *opened);
                opened->entries.emplace_back(std::move(item));
            }
            frame.target = opened;
            if (group->filtered) {
                auto filter = std::make_unique<Layer>();
                filter->kind = Layer::Kind::Filter;
                filter->filter = group->filter;
                Layer* inner = filter.get();
                opened->entries.emplace_back(std::move(filter));
                frame.filterLayer = inner;
                frame.target = inner;
            }
        }
        return frame;
    };
    auto leave = [](Frame& frame) {
        for (size_t i = 0; i < frame.open.size(); i++) {
            frame.target->entries.emplace_back(clipItem(PaintItem::Kind::DelClip));
        }
        frame.open.clear();
        if (frame.filterLayer) {
            litehtml::position bounds;
            for (const auto& entry : frame.filterLayer->entries) {
                bounds = unite(bounds, entryBounds(entry));
            }
            frame.filterLayer->box = bounds;
        }
        if (frame.groupLayer && frame.context->group->clipPath) {
            frame.groupLayer->entries.emplace_back(clipItem(PaintItem::Kind::DelClip));
        }
        if (frame.context->escapes) {
            frame.outer->entries.emplace_back(clipItem(PaintItem::Kind::ResumeClips));
        }
    };
    std::vector<Frame> stack;
    stack.push_back(enter(*m_mirror, root, m_mirror->origin.x, m_mirror->origin.y));
    while (!stack.empty()) {
        Frame& frame = stack.back();
        if (frame.next == frame.context->children.size()) {
            leave(frame);
            stack.pop_back();
            continue;
        }
        const MirrorNode& child = *frame.context->children[frame.next++];
        sync(frame, child.clips, child.pass, child.zindex);
        const float x = frame.x + child.origin.x;
        const float y = frame.y + child.origin.y;
        if (child.kind == MirrorNode::Kind::Context) {
            Layer* target = frame.target;
            stack.push_back(enter(child, *target, x, y));   // invalidates `frame`
            continue;
        }
        if (child.content) {
            appendShifted(*child.content, *frame.target, x, y);
        }
    }
    m_itemCount = countItems(root);
    m_root = std::move(root);
}

// The dump (LayerTree.h): the entries of `layer`, the first level at `depth`.
std::string dumpEntries(const Layer& layer, size_t depth) {
    std::string out;
    struct Frame {
        const Layer* layer;
        size_t next;
        size_t depth;   // of the layer's entries
    };
    std::vector<Frame> stack{{&layer, 0, depth}};
    while (!stack.empty()) {
        Frame& frame = stack.back();
        if (frame.next == frame.layer->entries.size()) {
            stack.pop_back();
            continue;
        }
        const auto& entry = frame.layer->entries[frame.next++];
        const size_t at = frame.depth;
        out.append(2 * at, ' ');
        TextSink sink(out);
        if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
            out += itemName(item->kind);
            sink.label("bounds");
            put(sink, item->bounds);
            std::visit([&sink](const auto& payload) { putPayload(sink, payload); }, item->payload);
            out += '\n';
        } else if (const Layer* child = std::get<std::unique_ptr<Layer>>(entry).get()) {
            out += layerName(child->kind);
            putLayer(sink, *child);
            out += '\n';
            stack.push_back({child, 0, at + 1});   // invalidates `frame`, which is not used again
        } else {
            out += "null\n";
        }
    }
    return out;
}

std::string LayerTree::dump() const {
    const Layer& flat = root();
    std::string out;
    {
        char header[96];
        std::snprintf(header, sizeof(header), "root %gx%g items=%zu\n", m_width, m_height, m_itemCount);
        out += header;
    }
    out += dumpEntries(flat, 1);
    return out;
}

namespace {

const char* passName(MirrorPass pass) {
    switch (pass) {
    case MirrorPass::Own: return "own";
    case MirrorPass::Negative: return "negative";
    case MirrorPass::Block: return "block";
    case MirrorPass::Floats: return "floats";
    case MirrorPass::Inlines: return "inlines";
    case MirrorPass::Zero: return "zero";
    case MirrorPass::Positive: return "positive";
    }
    return "?";
}

const char* contextName(MirrorNode::ContextKind kind) {
    switch (kind) {
    case MirrorNode::ContextKind::Root: return "root";
    case MirrorNode::ContextKind::Stacking: return "stacking";
    case MirrorNode::ContextKind::Pseudo: return "pseudo";
    case MirrorNode::ContextKind::Group: return "group";
    }
    return "?";
}

} // namespace

bool sameContent(const Layer& a, const Layer& b) {
    std::vector<std::pair<const Layer*, const Layer*>> stack{{&a, &b}};
    while (!stack.empty()) {
        auto [x, y] = stack.back();
        stack.pop_back();
        if (x == y) {
            continue;
        }
        if (x->entries.size() != y->entries.size()) {
            return false;
        }
        for (size_t i = 0; i < x->entries.size(); i++) {
            const PaintItem* p = std::get_if<PaintItem>(&x->entries[i]);
            const PaintItem* q = std::get_if<PaintItem>(&y->entries[i]);
            if (p || q) {
                if (!p || !q || !samePaint(*p, *q)) {
                    return false;
                }
                continue;
            }
            const Layer* l = std::get<std::unique_ptr<Layer>>(x->entries[i]).get();
            const Layer* m = std::get<std::unique_ptr<Layer>>(y->entries[i]).get();
            if (!l || !m || !sameLayerProperties(*l, *m)) {
                return false;
            }
            stack.emplace_back(l, m);
        }
    }
    return true;
}

bool sameMirrorGroup(const MirrorGroup* a, const MirrorGroup* b) {
    if (!a || !b) {
        return a == b;
    }
    auto fields = [](KeySink& sink, const MirrorGroup& g) {
        putGroup(sink, g.group);
        sink.flag(bool(g.clipPath));
        if (g.clipPath) {
            putPath(sink, *g.clipPath);
        }
        sink.flag(bool(g.backdrop));
        if (g.backdrop) {
            putPayload(sink, *g.backdrop);
        }
        sink.flag(g.filtered);
        if (g.filtered) {
            put(sink, g.filter);
        }
    };
    return keyOf(*a, fields) == keyOf(*b, fields);
}

std::string dumpMirror(const MirrorNode& root) {
    std::string out;
    std::vector<std::pair<const MirrorNode*, size_t>> stack{{&root, 0}};
    while (!stack.empty()) {
        auto [node, depth] = stack.back();
        stack.pop_back();
        out.append(2 * depth, ' ');
        TextSink sink(out);
        out += node->kind == MirrorNode::Kind::Context ? "context"
               : node->kind == MirrorNode::Kind::Box   ? "box"
                                                       : "inline";
        if (node->kind == MirrorNode::Kind::Context) {
            sink.word(contextName(node->context));
        }
        sink.label("key");
        sink.integer((long long)node->key);
        sink.label("origin");
        put(sink, node->origin);
        sink.label("pass");
        sink.word(passName(node->pass));
        sink.label("z");
        sink.integer(node->zindex);
        sink.label("clips");
        sink.open();
        for (const MirrorClip& clip : node->clips) {
            sink.open();
            sink.integer((long long)clip.key);
            put(sink, clip.box);
            put(sink, clip.radius);
            sink.close();
        }
        sink.close();
        if (node->kind == MirrorNode::Kind::Context) {
            sink.label("escapes");
            sink.flag(node->escapes);
            sink.label("group");
            if (const MirrorGroup* group = node->group.get()) {
                sink.open();
                putGroup(sink, group->group);
                sink.label("clipPath");
                if (group->clipPath) {
                    putPath(sink, *group->clipPath);
                } else {
                    sink.absent();
                }
                sink.label("backdrop");
                if (group->backdrop) {
                    putPayload(sink, *group->backdrop);
                } else {
                    sink.absent();
                }
                sink.label("filter");
                if (group->filtered) {
                    put(sink, group->filter);
                } else {
                    sink.absent();
                }
                sink.close();
            } else {
                sink.absent();
            }
            out += '\n';
            for (auto it = node->children.rbegin(); it != node->children.rend(); ++it) {
                stack.emplace_back(it->get(), depth + 1);
            }
            continue;
        }
        out += '\n';
        if (node->content) {
            out += dumpEntries(*node->content, depth + 1);
        }
    }
    return out;
}

} // namespace wr
