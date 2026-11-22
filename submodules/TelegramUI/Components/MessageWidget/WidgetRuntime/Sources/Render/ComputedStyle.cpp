#include "Sources/Render/ComputedStyle.h"

#include <algorithm>
#include <unordered_map>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <memory>
#include <optional>
#include <type_traits>

#include <litehtml.h>
#include <litehtml/el_svg.h>
#include <litehtml/render_item.h>
#include <litehtml/web_color.h>

#include "Sources/Animation/CSSAnimationRules.h"

namespace wr {

namespace {

template <typename T>
double toDouble(const T& value) {
    if constexpr (std::is_arithmetic_v<T>) {
        return double(value);
    } else {
        return double(value.value());
    }
}

/// CSSOM's number: shortest that reads back closely (6 significant digits, as browsers print), no exponent, no "-0".
std::string number(double value) {
    if (!std::isfinite(value) || std::fabs(value) < 5e-7) {
        return "0";
    }
    char buffer[64];
    std::snprintf(buffer, sizeof(buffer), "%.6g", value);
    std::string text(buffer);
    if (text.find('e') != std::string::npos) {
        std::snprintf(buffer, sizeof(buffer), "%.4f", value);
        text = buffer;
        while (!text.empty() && text.back() == '0') {
            text.pop_back();
        }
        if (!text.empty() && text.back() == '.') {
            text.pop_back();
        }
    }
    return text;
}

std::string px(double value) {
    return number(value) + "px";
}

/// rgb(r, g, b), or rgba(r, g, b, a) when not opaque; the alpha with the fewest decimals that maps back to its byte.
std::string color(const litehtml::web_color& c) {
    char buffer[96];
    if (c.alpha == 255) {
        std::snprintf(buffer, sizeof(buffer), "rgb(%d, %d, %d)", int(c.red), int(c.green), int(c.blue));
        return buffer;
    }
    const double alpha = double(c.alpha) / 255.0;
    double rounded = std::round(alpha * 100.0) / 100.0;
    if (int(std::lround(rounded * 255.0)) != int(c.alpha)) {
        rounded = std::round(alpha * 1000.0) / 1000.0;
    }
    std::snprintf(buffer, sizeof(buffer), "rgba(%d, %d, %d, %s)", int(c.red), int(c.green), int(c.blue), number(rounded).c_str());
    return buffer;
}

/// A color property's value: `currentcolor` resolves to the element's color.
std::string color(const litehtml::web_color& c, const litehtml::css_properties& css) {
    return c.is_current_color ? color(css.get_color()) : color(c);
}

template <typename Strings>
std::string keyword(const Strings& strings, int index) {
    if (index < 0 || size_t(index) >= strings.size()) {
        return std::string();
    }
    return std::string(litehtml::css_values(strings).value_by_index(size_t(index)));
}

std::string calcValue(const litehtml::calc_node& node);

/// A calc tree's sum as CSS math, its terms signed: the percentage, then px (font-relative terms are px by the time a
/// length is computed, twidget edit 48, but kept in their units otherwise), then each min(), max() or clamp() times
/// its factor ("10% + 2px - 2 * min(5%, 4px)"). The first term carries a leading "-" when negative.
std::vector<std::pair<bool, std::string>> calcTerms(const litehtml::calc_node& node) {
    std::vector<std::pair<bool, std::string>> terms;
    const auto add = [&](double value, const char* unit) {
        if (std::fabs(value) >= 5e-7) {
            terms.emplace_back(value < 0, number(std::fabs(value)) + unit);
        }
    };
    add(node.terms.percent, "%");
    add(node.terms.px, "px");
    add(node.terms.em, "em");
    add(node.terms.rem, "rem");
    add(node.terms.ex, "ex");
    add(node.terms.ch, "ch");
    for (const auto& [factor, child] : node.children) {
        if (child) {
            const double size = std::fabs(factor);
            terms.emplace_back(factor < 0, (size == 1.0 ? std::string() : number(size) + " * ") + calcValue(*child.get()));
        }
    }
    return terms;
}

std::string calcSum(const std::vector<std::pair<bool, std::string>>& terms) {
    if (terms.empty()) {
        return "0px";
    }
    std::string out;
    for (size_t i = 0; i < terms.size(); i++) {
        out += i == 0 ? (terms[i].first ? "-" : "") : (terms[i].first ? " - " : " + ");
        out += terms[i].second;
    }
    return out;
}

/// One argument of a min(), max() or clamp(): a sum as its terms, another function as itself.
std::string calcArgument(const litehtml::calc_node& node) {
    return node.kind == litehtml::calc_node::sum ? calcSum(calcTerms(node)) : calcValue(node);
}

/// A calc tree as CSS writes a computed value (final review M3): min(), max() and clamp() as themselves, their
/// arguments as sums; a sum of one positive term bare, of several in calc().
std::string calcValue(const litehtml::calc_node& node) {
    if (node.kind != litehtml::calc_node::sum) {
        static const char* const names[] = {"calc", "min", "max", "clamp"};
        std::string out = std::string(names[node.kind]) + "(";
        for (size_t i = 0; i < node.children.size(); i++) {
            const auto& [factor, child] = node.children[i];
            std::string argument = child ? calcArgument(*child.get()) : std::string("0px");
            out += (i > 0 ? ", " : "") + (factor == 1.0 ? argument : number(factor) + " * (" + argument + ")");
        }
        return out + ")";
    }
    const std::vector<std::pair<bool, std::string>> terms = calcTerms(node);
    if (terms.empty()) {
        return "0px";
    }
    if (terms.size() == 1 && !terms.front().first) {
        return terms.front().second;
    }
    return "calc(" + calcSum(terms) + ")";
}

/// A computed length: `auto` (and the other keywords) when predefined, a percentage as written, a calc() as CSS writes
/// one, otherwise px.
std::string computedLength(const litehtml::css_length& length) {
    if (length.is_predefined()) {
        return "auto";
    }
    if (length.is_calc()) {
        const litehtml::calc_ref node = length.calc();
        if (!node) {
            return px(length.val());
        }
        // A length that may not be negative keeps its calc as max(0, calc) (calc_node::at_least_zero): the clamp is the
        // used value's, not part of the computed one.
        const litehtml::calc_node* value = node.get();
        if (value->kind == litehtml::calc_node::max && value->children.size() == 2 && value->children[0].second &&
            value->children[1].second && calcTerms(*value->children[0].second.get()).empty()) {
            value = value->children[1].second.get();
        }
        return calcValue(*value);
    }
    if (length.units() == litehtml::css_units_percentage) {
        return number(length.val()) + "%";
    }
    return px(length.val());
}

std::string borderWidth(const litehtml::css_border& border) {
    return px(border.width.is_predefined() ? 0.0 : double(border.width.val()));
}

/// "a b c d" to the shortest CSS writes for four sides (top, right, bottom, left).
std::string fourSides(const std::string& top, const std::string& right, const std::string& bottom, const std::string& left) {
    if (left == right) {
        if (top == bottom) {
            return top == right ? top : top + " " + right;
        }
        return top + " " + right + " " + bottom;
    }
    return top + " " + right + " " + bottom + " " + left;
}

bool isIdentifier(std::string_view name) {
    if (name.empty() || std::isdigit(static_cast<unsigned char>(name[0]))) {
        return false;
    }
    return std::all_of(name.begin(), name.end(), [](char c) {
        return std::isalnum(static_cast<unsigned char>(c)) || c == '-' || c == '_' || static_cast<unsigned char>(c) >= 0x80;
    });
}

std::string fontFamily(const std::string& families) {
    std::string out;
    size_t start = 0;
    while (start <= families.size()) {
        size_t end = families.find(',', start);
        if (end == std::string::npos) {
            end = families.size();
        }
        std::string name = families.substr(start, end - start);
        name.erase(0, name.find_first_not_of(" \t"));
        name.erase(name.find_last_not_of(" \t") + 1);
        if (!name.empty()) {
            if (!out.empty()) {
                out += ", ";
            }
            out += isIdentifier(name) ? name : "\"" + name + "\"";
        }
        start = end + 1;
    }
    return out;
}

std::string decorationLine(int bits) {
    std::string out;
    const std::pair<int, const char*> lines[] = {
        {litehtml::text_decoration_line_underline, "underline"},
        {litehtml::text_decoration_line_overline, "overline"},
        {litehtml::text_decoration_line_line_through, "line-through"},
    };
    for (const auto& line : lines) {
        if (bits & line.first) {
            out += out.empty() ? line.second : std::string(" ") + line.second;
        }
    }
    return out.empty() ? "none" : out;
}

/// The transform property's functions composed into one 2D matrix (the origin is not part of the resolved value),
/// percentages of the border box; "none" with no functions. The translate, rotate and scale properties' functions,
/// which litehtml puts first (twidget edit 34), are not transform's.
std::string transform(const litehtml::css_properties& css, double boxWidth, double boxHeight) {
    const auto& functions = css.get_transform();
    const auto own = functions.begin() + std::ptrdiff_t(std::min(functions.size(), css.get_transform_individual_count()));
    if (own == functions.end()) {
        return "none";
    }
    litehtml::transform_matrix m;
    for (auto it = functions.rbegin(); it != std::make_reverse_iterator(own); ++it) {
        litehtml::transform_matrix f;
        switch (it->kind) {
        case litehtml::transform_function::translate:
            // A percentage, or a calc() tree mixing one with a length (twidget edit 56), is a share of the border box.
            f.tx = float(it->x.calc_percent(litehtml::pixel_t(float(boxWidth))));
            f.ty = float(it->y.calc_percent(litehtml::pixel_t(float(boxHeight))));
            break;
        case litehtml::transform_function::scale:
            f.a = it->v[0];
            f.d = it->v[1];
            break;
        case litehtml::transform_function::rotate:
            f.a = std::cos(it->v[0]);
            f.b = std::sin(it->v[0]);
            f.c = -f.b;
            f.d = f.a;
            break;
        case litehtml::transform_function::skew:
            f.b = std::tan(it->v[1]);
            f.c = std::tan(it->v[0]);
            break;
        case litehtml::transform_function::matrix:
            f = {it->v[0], it->v[1], it->v[2], it->v[3], it->v[4], it->v[5]};
            break;
        case litehtml::transform_function::rotate_x:
            f.d = std::cos(it->v[0]);
            break;
        case litehtml::transform_function::rotate_y:
            f.a = std::cos(it->v[0]);
            break;
        }
        m = m.then(f);
    }
    return "matrix(" + number(m.a) + ", " + number(m.b) + ", " + number(m.c) + ", " + number(m.d) + ", " + number(m.tx) + ", " +
           number(m.ty) + ")";
}

std::string cursor(const std::string& value) {
    // litehtml re-joins the tokens with a space on both sides of a comma: the one before goes, in one pass (the
    // fix-wave review's I-3: erasing in place was quadratic in a declared value's length).
    std::string out;
    out.reserve(value.size());
    for (size_t i = 0; i < value.size(); i++) {
        if (value[i] == ' ' && i + 1 < value.size() && value[i + 1] == ',') {
            continue;
        }
        out += value[i];
    }
    return out.empty() ? "auto" : out;
}

/// What a property reads from: the element's (or its pseudo-element's) computed style and its first render box.
struct Source {
    const litehtml::css_properties& css;
    std::shared_ptr<litehtml::render_item> box;
    /// The element (or pseudo-element) styled: for what css_properties does not hold (SVG paint, raw declarations).
    litehtml::element* element = nullptr;
    bool inlineNonReplaced = false;
    PseudoElement pseudo = PseudoElement::None;
    bool pseudoMissing = false;
};

/// A render box's border box, document px: get_placement is its content box (render_item.h), and litehtml transforms
/// and positions the border box (final review I1).
struct Rect {
    double x = 0, y = 0, width = 0, height = 0;
};

Rect borderBox(const litehtml::render_item& box) {
    const litehtml::position p = box.get_placement();
    const double left = toDouble(box.padding_left()) + toDouble(box.border_left());
    const double top = toDouble(box.padding_top()) + toDouble(box.border_top());
    return Rect{toDouble(p.x) - left, toDouble(p.y) - top,
                toDouble(p.width) + left + toDouble(box.padding_right()) + toDouble(box.border_right()),
                toDouble(p.height) + top + toDouble(box.padding_bottom()) + toDouble(box.border_bottom())};
}

/// Its padding box: a containing block's, which absolutely positioned offsets are measured against.
Rect paddingBox(const litehtml::render_item& box) {
    const litehtml::position p = box.get_placement();
    const double left = toDouble(box.padding_left());
    const double top = toDouble(box.padding_top());
    return Rect{toDouble(p.x) - left, toDouble(p.y) - top, toDouble(p.width) + left + toDouble(box.padding_right()),
                toDouble(p.height) + top + toDouble(box.padding_bottom())};
}

std::string marginTopOrBottom(const Source& s, bool top) {
    const litehtml::css_length& length = top ? s.css.get_margins().top : s.css.get_margins().bottom;
    // Margin collapsing moves the used top and bottom margins between boxes: the computed px value is the element's.
    if (!length.is_predefined() && length.units() != litehtml::css_units_percentage) {
        return px(length.val());
    }
    if (s.box) {
        return px(toDouble(top ? s.box->margin_top() : s.box->margin_bottom()));
    }
    return "0px";
}

std::string marginSide(const Source& s, char side) {
    switch (side) {
    case 't':
        return marginTopOrBottom(s, true);
    case 'b':
        return marginTopOrBottom(s, false);
    case 'l':
        return s.box ? px(toDouble(s.box->margin_left())) : computedLength(s.css.get_margins().left);
    default:
        return s.box ? px(toDouble(s.box->margin_right())) : computedLength(s.css.get_margins().right);
    }
}

std::string paddingSide(const Source& s, char side) {
    if (s.box) {
        switch (side) {
        case 't':
            return px(toDouble(s.box->padding_top()));
        case 'b':
            return px(toDouble(s.box->padding_bottom()));
        case 'l':
            return px(toDouble(s.box->padding_left()));
        default:
            return px(toDouble(s.box->padding_right()));
        }
    }
    const litehtml::css_margins& padding = s.css.get_padding();
    return computedLength(side == 't' ? padding.top : side == 'b' ? padding.bottom : side == 'l' ? padding.left : padding.right);
}

const litehtml::css_border& borderSide(const litehtml::css_properties& css, char side) {
    const litehtml::css_borders& borders = css.get_borders();
    return side == 't' ? borders.top : side == 'b' ? borders.bottom : side == 'l' ? borders.left : borders.right;
}

/// "top"/"right"/"bottom"/"left" → 't'/'r'/'b'/'l'; 0 otherwise.
char sideOf(std::string_view name) {
    if (name == "top") {
        return 't';
    }
    if (name == "right") {
        return 'r';
    }
    if (name == "bottom") {
        return 'b';
    }
    if (name == "left") {
        return 'l';
    }
    return 0;
}

std::string usedSize(const Source& s, bool width) {
    if (s.box && !s.inlineNonReplaced) {
        const litehtml::position& pos = s.box->pos();
        double size = width ? toDouble(pos.width) : toDouble(pos.height);
        if (s.css.get_box_sizing() == litehtml::box_sizing_border_box) {
            size += width ? toDouble(s.box->box_sizing_width()) : toDouble(s.box->box_sizing_height());
        }
        return px(size);
    }
    return s.inlineNonReplaced ? "auto" : computedLength(width ? s.css.get_width() : s.css.get_height());
}

/// A length the renderer keeps as written: px, or a percentage as written.
std::string lengthValue(const litehtml::css_length& length) {
    if (length.units() == litehtml::css_units_percentage) {
        return number(length.val()) + "%";
    }
    return px(length.val());
}

/// CSS Filter Effects' serialization, as Chromium gives it: `none`, or the functions with their resolved arguments.
std::string filterList(const litehtml::filter_vector& filters) {
    if (filters.empty()) {
        return "none";
    }
    std::string out;
    for (const litehtml::filter_function& f : filters) {
        if (!out.empty()) {
            out += ' ';
        }
        switch (f.kind) {
        case litehtml::filter_function::blur:
            out += "blur(" + lengthValue(f.radius) + ")";
            break;
        case litehtml::filter_function::brightness:
            out += "brightness(" + number(f.amount) + ")";
            break;
        case litehtml::filter_function::contrast:
            out += "contrast(" + number(f.amount) + ")";
            break;
        case litehtml::filter_function::grayscale:
            out += "grayscale(" + number(f.amount) + ")";
            break;
        case litehtml::filter_function::hue_rotate:
            out += "hue-rotate(" + number(f.amount) + "deg)";
            break;
        case litehtml::filter_function::invert:
            out += "invert(" + number(f.amount) + ")";
            break;
        case litehtml::filter_function::opacity:
            out += "opacity(" + number(f.amount) + ")";
            break;
        case litehtml::filter_function::saturate:
            out += "saturate(" + number(f.amount) + ")";
            break;
        case litehtml::filter_function::sepia:
            out += "sepia(" + number(f.amount) + ")";
            break;
        case litehtml::filter_function::drop_shadow:
            out += "drop-shadow(" + color(f.color) + " " + lengthValue(f.x) + " " + lengthValue(f.y) + " " +
                   lengthValue(f.radius) + ")";
            break;
        }
    }
    return out;
}

/// An SVG paint (`fill`, `stroke`) as the painter resolves it (twidget edit 30.2): its initial value when nothing sets
/// it (black for fill, none for stroke), currentcolor as the element's color.
std::string paint(const Source& s, std::string_view name) {
    if (!s.element) {
        return std::string();
    }
    const litehtml::css_token_vector tokens =
        litehtml::svg_computed_property(s.element->shared_from_this(), litehtml::_id(std::string(name)));
    if (tokens.empty()) {
        return name == "fill" ? "rgb(0, 0, 0)" : "none";
    }
    litehtml::document_container* container = s.element->get_document() ? s.element->get_document()->container() : nullptr;
    for (const litehtml::css_token& token : tokens) {
        const std::string ident = litehtml::lowcase(token.ident());
        if (ident == "none") {
            return "none";
        }
        if (ident == "currentcolor") {
            return color(s.css.get_color());
        }
        if (token.type == litehtml::URL || (token.type == litehtml::CV_FUNCTION && litehtml::lowcase(token.name()) == "url")) {
            return litehtml::get_repr(tokens, 0, -1, true);
        }
        litehtml::web_color c;
        if (litehtml::parse_color(token, c, container)) {
            return color(c);
        }
    }
    return litehtml::get_repr(tokens, 0, -1, true);
}

std::string strokeWidth(const Source& s) {
    if (!s.element) {
        return std::string();
    }
    const litehtml::css_token_vector tokens =
        litehtml::svg_computed_property(s.element->shared_from_this(), litehtml::_id("stroke-width"));
    if (tokens.empty()) {
        return "1px";
    }
    const litehtml::css_token& token = tokens[0];
    if (token.type == litehtml::NUMBER) {
        return px(token.n.number);
    }
    if (token.type == litehtml::DIMENSION && litehtml::lowcase(token.unit()) == "px") {
        return px(token.n.number);
    }
    return litehtml::get_repr(tokens, 0, -1, true);
}

/// stroke-dasharray and stroke-dashoffset as the painter reads them, presentation attributes and inheritance included
/// (final review I3): numbers as px and a dash array's values comma-separated, as Chromium writes them.
std::string strokeDash(const Source& s, std::string_view name) {
    const bool array = name == "stroke-dasharray";
    if (!s.element) {
        return std::string();
    }
    const litehtml::css_token_vector tokens =
        litehtml::svg_computed_property(s.element->shared_from_this(), litehtml::_id(std::string(name)));
    std::string out;
    for (const litehtml::css_token& token : tokens) {
        if (token.type == litehtml::WHITESPACE || token.type == litehtml::COMMA) {
            continue;
        }
        if (token.type == litehtml::IDENT && litehtml::lowcase(token.ident()) == "none") {
            return "none";
        }
        const bool pixels = token.type == litehtml::NUMBER ||
                            (token.type == litehtml::DIMENSION && litehtml::lowcase(token.unit()) == "px");
        out += (out.empty() ? "" : ", ") +
               (pixels ? px(token.n.number) : litehtml::get_repr(litehtml::css_token_vector{token}, 0, -1, true));
    }
    return out.empty() ? std::string(array ? "none" : "0px") : out;
}

/// One background layer's property, comma-joined over the layers (CSS Backgrounds' lists), each list repeated to the
/// number of image layers.
template <typename Layer>
std::string layers(const litehtml::background& bg, Layer&& layer) {
    const size_t count = std::max<size_t>(1, bg.m_image.size());
    std::string out;
    for (size_t i = 0; i < count; i++) {
        if (i > 0) {
            out += ", ";
        }
        out += layer(i);
    }
    return out;
}

template <typename T>
const T* layerAt(const std::vector<T>& values, size_t i) {
    return values.empty() ? nullptr : &values[i % values.size()];
}

std::string layerImage(const litehtml::background& bg, size_t i) {
    if (i >= bg.m_image.size() || bg.m_image[i].is_empty()) {
        return "none";
    }
    const litehtml::image& image = bg.m_image[i];
    // A gradient keeps no text of its own here: it reads as none until the serializer learns gradients.
    return image.type == litehtml::image::type_url ? "url(\"" + image.url + "\")" : "none";
}

std::string backgroundImage(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) { return layerImage(bg, i); });
}

std::string layerSize(const litehtml::background& bg, size_t i) {
    const litehtml::css_size* size = layerAt(bg.m_size, i);
    if (!size) {
        return "auto";
    }
    if (size->width.is_predefined()) {
        if (size->width.predef() == litehtml::background_size_cover) {
            return "cover";
        }
        if (size->width.predef() == litehtml::background_size_contain) {
            return "contain";
        }
        return size->height.is_predefined() ? "auto" : "auto " + lengthValue(size->height);
    }
    return lengthValue(size->width) + (size->height.is_predefined() ? std::string() : " " + lengthValue(size->height));
}

std::string backgroundSize(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) { return layerSize(bg, i); });
}

std::string layerPosition(const litehtml::background& bg, size_t i) {
    const litehtml::css_length* x = layerAt(bg.m_position_x, i);
    const litehtml::css_length* y = layerAt(bg.m_position_y, i);
    return (x ? lengthValue(*x) : std::string("0%")) + " " + (y ? lengthValue(*y) : std::string("0%"));
}

std::string backgroundPosition(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) { return layerPosition(bg, i); });
}

std::string layerRepeat(const litehtml::background& bg, size_t i) {
    const int* repeat = layerAt(bg.m_repeat, i);
    return repeat ? keyword(litehtml::background_repeat_strings, *repeat) : std::string("repeat");
}

std::string backgroundRepeat(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) { return layerRepeat(bg, i); });
}

std::string layerOrigin(const litehtml::background& bg, size_t i) {
    const int* box = layerAt(bg.m_origin, i);
    return box ? keyword(litehtml::background_box_strings, *box) : std::string("padding-box");
}

/// The `background` shorthand (Computed-style plan, Task 3), canonical rather than claimed Chrome-exact, in Chrome's
/// order: each layer's image, repeat, attachment, position / size, origin and clip, the colour before the last layer's.
std::string backgroundShorthand(const litehtml::background& bg, const std::string& color) {
    const size_t count = std::max<size_t>(1, bg.m_image.size());
    return layers(bg, [&](size_t i) -> std::string {
        const int* attachment = layerAt(bg.m_attachment, i);
        const int* clip = layerAt(bg.m_clip, i);
        return (i + 1 == count ? color + " " : std::string()) + layerImage(bg, i) + " " + layerRepeat(bg, i) + " " +
               (attachment ? keyword(litehtml::background_attachment_strings, *attachment) : std::string("scroll")) + " " +
               layerPosition(bg, i) + " / " + layerSize(bg, i) + " " + layerOrigin(bg, i) + " " +
               (clip ? keyword(litehtml::background_box_strings, *clip) : std::string("border-box"));
    });
}

/// Two axes' values as their shorthand writes them: once when they agree (CSSOM).
std::string pairOf(const std::string& first, const std::string& second) {
    return first == second ? first : first + " " + second;
}

std::string trimmedText(std::string_view text) {
    const size_t first = text.find_first_not_of(" \t\n\r\f");
    const size_t last = text.find_last_not_of(" \t\n\r\f");
    return first == std::string_view::npos ? std::string() : std::string(text.substr(first, last - first + 1));
}

/// A comma-separated list's items, trimmed, commas inside parentheses kept (`cubic-bezier(…)`): at most
/// animation::kMaxCSSListEntries, as many as the runtime runs (final review C1).
std::vector<std::string> commaItems(const Source& s, std::string_view list) {
    std::vector<std::string> items;
    size_t start = 0, end = 0;
    int depth = 0;
    for (; end < list.size() && items.size() < animation::kMaxCSSListEntries; end++) {
        const char c = list[end];
        if (c == '(') {
            depth++;
        } else if (c == ')' && depth > 0) {
            depth--;
        } else if (c == ',' && depth == 0) {
            items.push_back(trimmedText(list.substr(start, end - start)));
            start = end + 1;
        }
    }
    if (items.size() < animation::kMaxCSSListEntries) {
        items.push_back(trimmedText(list.substr(start, end - start)));
    }
    return items;
}

/// A list item's whitespace-separated tokens, outside parentheses and quotes.
std::vector<std::string> itemTokens(const std::string& item) {
    std::vector<std::string> tokens;
    std::string current;
    int depth = 0;
    char quote = 0;
    for (char c : item) {
        if (quote) {
            quote = c == quote ? 0 : quote;
        } else if (c == '"' || c == '\'') {
            quote = c;
        } else if (c == '(') {
            depth++;
        } else if (c == ')' && depth > 0) {
            depth--;
        } else if (depth == 0 && (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f')) {
            if (!current.empty()) {
                tokens.push_back(std::move(current));
                current.clear();
            }
            continue;
        }
        current += c;
    }
    if (!current.empty()) {
        tokens.push_back(std::move(current));
    }
    return tokens;
}

std::string lowered(std::string text) {
    std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) { return char(std::tolower(c)); });
    return text;
}

bool isEasingText(const std::string& token) {
    const std::string t = lowered(token);
    return t == "ease" || t == "linear" || t == "ease-in" || t == "ease-out" || t == "ease-in-out" || t == "step-start" ||
           t == "step-end" || t.rfind("cubic-bezier(", 0) == 0 || t.rfind("steps(", 0) == 0 || t.rfind("linear(", 0) == 0;
}

bool isNumberText(const std::string& token) {
    if (token.empty()) {
        return false;
    }
    char* end = nullptr;
    std::strtod(token.c_str(), &end);
    return end == token.c_str() + token.size();
}

/// A time as CSSOM writes it, in seconds; anything else as written.
std::string seconds(const std::string& item) {
    if (std::optional<double> ms = animation::parseTimeMs(item)) {
        return number(*ms / 1000.0) + "s";
    }
    return item;
}

/// One entry of an `animation` or `transition` shorthand as animationSpecs and transitionSpecs read it: the first time
/// is the duration and the second the delay, an easing the timing function, the keywords their longhands', and what no
/// keyword claims the name (as written) or the property (lowercased). A longhand the entry does not mention is absent.
std::unordered_map<std::string, std::string> shorthandEntry(bool animation, const std::string& item) {
    std::unordered_map<std::string, std::string> entry;
    bool sawDuration = false;
    for (const std::string& token : itemTokens(item)) {
        const std::string t = lowered(token);
        const char* longhand;
        if (animation::parseTimeMs(t)) {
            longhand = sawDuration ? "delay" : "duration";
            sawDuration = true;
        } else if (isEasingText(t)) {
            longhand = "timing-function";
        } else if (!animation) {
            longhand = "property";
        } else if (t == "infinite" || isNumberText(t)) {
            longhand = "iteration-count";
        } else if (t == "normal" || t == "reverse" || t == "alternate" || t == "alternate-reverse") {
            longhand = "direction";
        } else if (t == "forwards" || t == "backwards" || t == "both") {
            longhand = "fill-mode";
        } else if (t == "paused" || t == "running") {
            longhand = "play-state";
        } else {
            longhand = "name";
        }
        entry[std::string(animation ? "animation-" : "transition-") + longhand] = std::string_view(longhand) == "name" ? token : t;
    }
    return entry;
}

/// A grid item's placement on one axis as its start and end lines (`auto`, a line number, or `span N`).
std::pair<std::string, std::string> gridLines(const litehtml::grid_placement& placement) {
    const std::string span = "span " + std::to_string(placement.span);
    if (placement.start == 0 && placement.end == 0) {
        return {placement.span > 0 ? span : "auto", "auto"};
    }
    const std::string start = placement.start != 0 ? std::to_string(placement.start) : std::string("auto");
    const std::string end = placement.end != 0 ? std::to_string(placement.end) : placement.span > 0 ? span : std::string("auto");
    return {start, end};
}

/// A list of grid lines as `grid-row`, `grid-column` or `grid-area` write them: trailing autos dropped, at least one.
std::string gridLineList(std::vector<std::string> lines) {
    while (lines.size() > 1 && lines.back() == "auto") {
        lines.pop_back();
    }
    std::string out;
    for (const std::string& line : lines) {
        out += (out.empty() ? "" : " / ") + line;
    }
    return out;
}

/// The initial value (computed form) of a property `value` answers from a declaration (`declaredOrInitial`,
/// `listLonghand`): those litehtml keeps no value of, and the flex and box longhands outside the containers and items
/// litehtml computes them for. nullptr for any other name (getComputedStyle then answers "", as for any name it does not
/// know).
const char* initialValue(std::string_view name) {
    static const std::unordered_map<std::string_view, const char*> initial = {
        {"align-items", "normal"}, {"flex-direction", "row"}, {"flex-wrap", "nowrap"}, {"flex-grow", "0"}, {"flex-shrink", "1"},
        {"flex-basis", "auto"}, {"row-gap", "normal"}, {"column-gap", "normal"}, {"grid-auto-columns", "auto"},
        {"grid-auto-flow", "row"}, {"grid-template-areas", "none"}, {"unicode-bidi", "normal"},
        {"pointer-events", "auto"}, {"translate", "none"}, {"rotate", "none"}, {"scale", "none"},
        {"counter-increment", "none"}, {"counter-reset", "none"}, {"font-feature-settings", "normal"},
        {"font-variant-numeric", "normal"}, {"color-scheme", "normal"}, {"animation-name", "none"},
        {"animation-duration", "0s"}, {"animation-timing-function", "ease"}, {"animation-delay", "0s"},
        {"animation-iteration-count", "1"}, {"animation-direction", "normal"}, {"animation-fill-mode", "none"},
        {"animation-play-state", "running"}, {"transition-property", "all"}, {"transition-duration", "0s"},
        {"transition-timing-function", "ease"}, {"transition-delay", "0s"}, {"transition-behavior", "normal"},
    };
    const auto it = initial.find(name);
    return it == initial.end() ? nullptr : it->second;
}

/// Inherited among those (CSS's "Inherited: yes").
bool inheritedProperty(std::string_view name) {
    return name == "pointer-events" || name == "color-scheme" || name == "font-feature-settings" ||
           name == "font-variant-numeric";
}

/// A raw declaration still holding a var() after substitution: the variable never resolved, so the declaration is
/// invalid at computed-value time (CSS Variables: as if unset).
bool unresolvedVar(const std::string& declared) {
    return lowered(declared).find("var(") != std::string::npos;
}

/// A profile 1 property `value` has no exact answer for yet: the element's own declaration as written (with var()
/// substituted), else an inherited property's nearest ancestor's, else its initial value; the CSS-wide keywords as they
/// cascade, and a declaration whose var() never resolved as unset. "" for a name that is not one. Walks at most the
/// tree's depth (256).
std::string declaredOrInitial(const Source& s, std::string_view name) {
    const char* initial = initialValue(name);
    if (!initial) {
        return std::string();
    }
    const bool inherited = inheritedProperty(name);
    for (const litehtml::element* el = s.element; el; el = el->parent().get()) {
        const auto* tag = dynamic_cast<const litehtml::html_tag*>(el);
        std::string declared = tag ? tag->raw_declaration(std::string(name)) : std::string();
        if (unresolvedVar(declared)) {
            if (!inherited) {
                return initial;
            }
            continue;
        }
        std::string keyword = declared;
        std::transform(keyword.begin(), keyword.end(), keyword.begin(), [](unsigned char c) { return char(std::tolower(c)); });
        if (keyword == "initial" || ((keyword == "unset" || keyword == "revert" || keyword == "revert-layer") && !inherited)) {
            return initial;
        }
        if (!declared.empty() && keyword != "inherit" && keyword != "unset" && keyword != "revert" && keyword != "revert-layer") {
            return declared;
        }
        if (declared.empty() && !inherited) {
            return initial;
        }
    }
    return initial;
}

/// A length that may be a keyword (`none`, `auto`, …): the keyword's own name when predefined.
std::string lengthOrKeyword(const litehtml::css_length& length, std::string_view keyword) {
    return length.is_predefined() ? std::string(keyword) : computedLength(length);
}

/// flex_align_items with its flags (align-items, align-self, justify-items).
std::string alignment(litehtml::flex_align_items value) {
    const int flags = int(value);
    std::string base = keyword(litehtml::flex_align_items_strings, flags & 0xFF);
    if (base == "baseline" && (flags & litehtml::flex_align_items_last)) {
        return "last baseline";
    }
    if (flags & litehtml::flex_align_items_safe) {
        return "safe " + base;
    }
    if (flags & litehtml::flex_align_items_unsafe) {
        return "unsafe " + base;
    }
    return base;
}

bool isBoxContainer(const litehtml::css_properties& css) {
    const litehtml::style_display display = css.get_display();
    return display == litehtml::display_flex || display == litehtml::display_inline_flex ||
           display == litehtml::display_grid || display == litehtml::display_inline_grid;
}

bool isFlexContainer(const litehtml::css_properties& css) {
    return css.get_display() == litehtml::display_flex || css.get_display() == litehtml::display_inline_flex;
}

bool isFlexItem(const Source& s) {
    auto parent = s.element ? s.element->parent() : nullptr;
    return parent && isFlexContainer(parent->css());
}

bool isGridContainer(const litehtml::css_properties& css) {
    return isBoxContainer(css) && !isFlexContainer(css);
}

bool isGridItem(const Source& s) {
    auto parent = s.element ? s.element->parent() : nullptr;
    return parent && isGridContainer(parent->css());
}

/// The element's own raw declaration of `name` ("" without one): a raw copy is kept before litehtml validates the
/// value, so its length is whatever the author wrote (final review I2).
std::string ownDeclaration(const Source& s, const char* name) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
    return tag ? tag->raw_declaration(name) : std::string();
}

/// An `animation-*` or `transition-*` longhand as the runtime runs it (animationSpecs, transitionSpecs; final review
/// I2): the element's own declaration, else its shorthand's entries (the longhand's initial value where an entry names
/// none), else the initial value. Times in seconds, as CSSOM writes them; at most kMaxCSSListEntries items.
std::string listLonghand(const Source& s, std::string_view name) {
    const bool animation = name.rfind("animation-", 0) == 0;
    const bool time = name.size() > 9 && (name.substr(name.size() - 6) == "-delay" || name.substr(name.size() - 9) == "-duration");
    std::vector<std::string> items;
    if (!ownDeclaration(s, std::string(name).c_str()).empty()) {
        items = commaItems(s, declaredOrInitial(s, name));
    } else {
        const std::string shorthand = ownDeclaration(s, animation ? "animation" : "transition");
        const std::string keyword = lowered(trimmedText(shorthand));
        if (shorthand.empty() || unresolvedVar(shorthand) || keyword == "initial" || keyword == "inherit" || keyword == "unset" || keyword == "revert" ||
            keyword == "revert-layer") {
            return initialValue(name);
        }
        for (const std::string& item : commaItems(s, shorthand)) {
            const auto entry = shorthandEntry(animation, item);
            const auto it = entry.find(std::string(name));
            items.push_back(it != entry.end() ? it->second : std::string(initialValue(name)));
        }
    }
    std::string out;
    for (size_t i = 0; i < items.size(); i++) {
        out += (i > 0 ? ", " : "") + (time ? seconds(items[i]) : items[i]);
    }
    return out;
}

/// A declared aspect-ratio as CSSOM writes it (`16 / 9`, a lone number over 1, `auto` before it when declared), or
/// nothing when the declaration is not a ratio of positive numbers.
std::optional<std::string> declaredRatio(const std::string& declared) {
    std::string text = lowered(trimmedText(declared));
    std::string prefix;
    for (const char* keyword : {"auto ", "auto"}) {
        if (text.rfind(keyword, 0) == 0 && text != "auto") {
            prefix = "auto ";
            text = trimmedText(text.substr(std::string_view(keyword).size()));
            break;
        }
    }
    if (text.size() > 5 && text.substr(text.size() - 5) == " auto") {
        prefix = "auto ";
        text = trimmedText(text.substr(0, text.size() - 5));
    }
    const size_t slash = text.find('/');
    const std::string first = trimmedText(slash == std::string::npos ? text : text.substr(0, slash));
    const std::string second = slash == std::string::npos ? std::string("1") : trimmedText(text.substr(slash + 1));
    if (!isNumberText(first) || !isNumberText(second)) {
        return std::nullopt;
    }
    const double a = std::strtod(first.c_str(), nullptr);
    const double b = std::strtod(second.c_str(), nullptr);
    if (!(a > 0) || !(b > 0)) {
        return std::nullopt;
    }
    return prefix + number(a) + " / " + number(b);
}

/// A grid axis's start and end lines as declared, from the tokens litehtml lays the axis out from: the start and end
/// longhands' own, else the shorthand's two sides (split at its `/`; a missing end is auto). Nothing when the element
/// declares neither.
std::optional<std::pair<std::string, std::string>> declaredGridLines(const Source& s, litehtml::string_id shorthand,
                                                                     litehtml::string_id start, litehtml::string_id end) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
    if (!tag) {
        return std::nullopt;
    }
    // Only what litehtml lays out (its parse_grid_placement takes it): an unresolved var() or a line name is as absent
    // (final review M5).
    const auto valid = [&](litehtml::string_id name) -> const litehtml::css_token_vector* {
        const litehtml::css_token_vector* tokens = tag->get_token_property(name);
        if (!tokens) {
            return nullptr;
        }
        litehtml::grid_placement placement;
        return litehtml::parse_grid_placement(*tokens, placement) ? tokens : nullptr;
    };
    const litehtml::css_token_vector* whole = valid(shorthand);
    const litehtml::css_token_vector* startTokens = valid(start);
    const litehtml::css_token_vector* endTokens = valid(end);
    if (!whole && !startTokens && !endTokens) {
        return std::nullopt;
    }
    std::string first, second;
    if (whole) {
        size_t slash = whole->size();
        for (size_t i = 0; i < whole->size(); i++) {
            if ((*whole)[i].ch == '/') {
                slash = i;
                break;
            }
        }
        first = trimmedText(litehtml::get_repr(*whole, 0, int(slash), true));
        if (slash < whole->size()) {
            second = trimmedText(litehtml::get_repr(*whole, int(slash + 1), -1, true));
        }
    }
    if (startTokens) {
        first = trimmedText(litehtml::get_repr(*startTokens, 0, -1, true));
    }
    if (endTokens) {
        second = trimmedText(litehtml::get_repr(*endTokens, 0, -1, true));
    }
    return std::pair{first.empty() ? std::string("auto") : first, second.empty() ? std::string("auto") : second};
}

/// Whether a declared `flex` shorthand omits its basis (one or two non-negative numbers, as litehtml's parse_flex takes
/// them), which CSS then sets to 0%.
bool flexOmitsBasis(const std::string& declared) {
    const std::vector<std::string> tokens = itemTokens(trimmedText(declared));
    if (tokens.empty() || tokens.size() > 2) {
        return false;
    }
    return std::all_of(tokens.begin(), tokens.end(), [](const std::string& token) {
        return isNumberText(token) && std::strtod(token.c_str(), nullptr) >= 0;
    });
}

/// The element's raw declaration (edit 51) of `name` as written and its place in the element's declaration order
/// (edit 54's `m_order`): nothing without one.
std::optional<std::pair<std::string, int>> rawWithOrder(const Source& s, litehtml::string_id name) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
    const litehtml::property_value* value = tag ? &tag->own_property(litehtml::raw_declaration_id(name)) : nullptr;
    if (!value || !value->is<litehtml::css_token_vector>()) {
        return std::nullopt;
    }
    std::string text = litehtml::get_repr(value->get<litehtml::css_token_vector>(), 0, -1, true);
    return std::pair{std::move(text), value->m_order};
}

/// Of raw declarations at `orders`, the one that wrote a parsed value at `parsedOrder`: each declaration's raw copy is
/// added just before its parse writes, so the latest written before the parse (one after it was refused:
/// `!important`, or invalid); else the latest (a var() substitution re-adds both, in no order).
std::optional<size_t> writerOf(const std::vector<int>& orders, int parsedOrder) {
    std::optional<size_t> best;
    for (const bool beforeTheParse : {true, false}) {
        for (size_t i = 0; i < orders.size(); i++) {
            if ((!beforeTheParse || orders[i] < parsedOrder) && (!best || orders[i] > orders[*best])) {
                best = i;
            }
        }
        if (best) {
            break;
        }
    }
    return best;
}

/// flex-basis as CSS writes it: a flex shorthand's omitted basis, which litehtml stores as 0px, as 0%, when that
/// `flex` wrote the basis litehtml applied (`writerOf`; final review M1).
std::string flexBasis(const Source& s, const litehtml::css_length& basis) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
    const litehtml::property_value* parsed = tag ? &tag->own_property(litehtml::_flex_basis_) : nullptr;
    if (!basis.is_predefined() && basis.val() == 0 && basis.units() != litehtml::css_units_percentage && parsed &&
        parsed->is<litehtml::css_length>()) {
        if (const auto flex = rawWithOrder(s, litehtml::_flex_)) {
            std::vector<int> orders = {flex->second};
            if (const auto own = rawWithOrder(s, litehtml::_flex_basis_)) {
                orders.push_back(own->second);
            }
            if (writerOf(orders, parsed->m_order) == size_t(0) && flexOmitsBasis(flex->first)) {
                return "0%";
            }
        }
    }
    return basis.is_predefined() ? keyword(litehtml::flex_basis_strings, basis.predef()) : computedLength(basis);
}

/// A longhand where litehtml computed none (`value` says where): litehtml's own parse of the element's cascaded
/// declarations (twidget edit 54), which expands `flex`, `flex-flow`, `gap` and `place-*` into their longhands, so a
/// shorthand's part and a later longhand cascade as CSS's; the parent's value for inherit; else `initial` (no
/// declaration, an invalid one, `initial`, `unset`, a var() that never resolved).
std::string parsedLonghand(const Source& s, std::string_view name, const char* initial) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
    if (!tag) {
        return initial;
    }
    const litehtml::string_id id = litehtml::_id(std::string(name));
    const litehtml::property_value& parsed = tag->own_property(id);
    if (parsed.is<litehtml::inherit>()) {
        // The nearest ancestor that does not inherit it too answers: walked, never recursed (final review I3).
        litehtml::element* ancestor = s.element->parent().get();
        while (ancestor) {
            const auto* up = dynamic_cast<const litehtml::html_tag*>(ancestor);
            if (!up || !up->own_property(id).is<litehtml::inherit>()) {
                break;
            }
            ancestor = ancestor->parent().get();
        }
        const std::string inherited = ancestor ? computedValue(*ancestor, name, PseudoElement::None) : std::string();
        return inherited.empty() ? std::string(initial) : inherited;
    }
    if (parsed.is<float>()) {
        return number(parsed.get<float>());
    }
    if (parsed.is<int>()) {
        const int index = parsed.get<int>();
        if (name == "flex-direction") {
            return keyword(litehtml::flex_direction_strings, index);
        }
        if (name == "flex-wrap") {
            return keyword(litehtml::flex_wrap_strings, index);
        }
        return alignment(litehtml::flex_align_items(index));
    }
    if (parsed.is<litehtml::css_length>()) {
        litehtml::css_length length = parsed.get<litehtml::css_length>();
        if (s.element->get_document()) {
            s.element->get_document()->cvt_units(length, s.css.get_font_metrics(), 0);
        }
        return name == "flex-basis" ? flexBasis(s, length) : lengthOrKeyword(length, "normal");
    }
    return initial;
}

/// justify-content or align-content at litehtml's default (flex-start, stretch), which an element gets from a
/// declaration of that keyword, from place-content's normal or stretch, and from an animation alike: the spelling of
/// the raw declaration (edit 51) that wrote litehtml's parse (edit 54). Of the element's own declaration and its
/// place-content, those whose spelling gives the default, the latest written before the parse (one after it was
/// refused: `!important`, or invalid), else the latest (a var() substitution re-adds both, in no order), else the
/// default's own keyword (an animation's). Nothing when litehtml parsed none: the property is undeclared.
std::optional<std::string> contentAtDefault(const Source& s, bool justify) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
    const litehtml::property_value* parsed = tag ? &tag->own_property(justify ? litehtml::_justify_content_ : litehtml::_align_content_) : nullptr;
    if (!parsed || !parsed->is<int>()) {
        return std::nullopt;
    }
    const std::string fallback = justify ? "flex-start" : "stretch";
    const litehtml::css_values justifyValues(litehtml::flex_justify_content_strings);
    const litehtml::css_values alignValues(litehtml::flex_align_content_strings);
    std::vector<std::string> spellings;
    std::vector<int> orders;
    if (const auto own = rawWithOrder(s, justify ? litehtml::_justify_content_ : litehtml::_align_content_);
        own && lowered(trimmedText(own->first)) == fallback) {
        spellings.push_back(fallback);
        orders.push_back(own->second);
    }
    if (const auto place = rawWithOrder(s, litehtml::_place_content_)) {
        const std::vector<std::string> parts = itemTokens(lowered(trimmedText(place->first)));
        // place-content's parse (style.cpp): one or two keywords, align-content's normal as stretch, justify-content's
        // normal and stretch as flex-start.
        if ((parts.size() == 1 || parts.size() == 2) &&
            alignValues.value_index(parts.front() == "normal" ? std::string("stretch") : parts.front()).has_value() &&
            justifyValues.value_index(parts.back()).has_value()) {
            const std::string part = justify ? parts.back() : parts.front();
            if (part == fallback || part == "normal" || (justify && part == "stretch")) {
                spellings.push_back(part);
                orders.push_back(place->second);
            }
        }
    }
    const std::optional<size_t> writer = writerOf(orders, parsed->m_order);
    return writer ? spellings[*writer] : fallback;
}

/// Past this an `animation` or `transition` join answers "" (final review C1): 64 entries of every longhand at honest
/// lengths stay far below it, while a long item cycled through 64 entries would not.
constexpr size_t kMaxJoinedBytes = 64 * 1024;

/// CSSOM's resolved top/right/bottom/left: a static element's computed value; a relative one's used px (a percentage of
/// its containing block, the opposite's negation for auto, else 0); an absolute or fixed one's used px: a declared length
/// itself, a percentage of its containing block's padding box, auto from the layout as the distance from its margin edge
/// to that padding box's edge.
std::string offset(const Source& s, char side) {
    const litehtml::css_offsets& offsets = s.css.get_offsets();
    const auto declared = [&](char which) -> const litehtml::css_length& {
        return which == 't' ? offsets.top : which == 'b' ? offsets.bottom : which == 'l' ? offsets.left : offsets.right;
    };
    const litehtml::element_position position = s.css.get_position();
    if (position == litehtml::element_position_static || !s.element) {
        return computedLength(declared(side));
    }
    const bool vertical = side == 't' || side == 'b';
    if (position == litehtml::element_position_relative || position == litehtml::element_position_sticky) {
        double base = 0;
        if (auto parent = s.element->parent(); parent && parent->get_render_item()) {
            const litehtml::position p = parent->get_render_item()->pos();
            base = vertical ? toDouble(p.height) : toDouble(p.width);
        }
        // A percentage, or a calc() tree mixing one with a length (twidget edit 48), is a share of the base.
        const auto resolve = [&](const litehtml::css_length& length) {
            return toDouble(length.calc_percent(litehtml::pixel_t(float(base))));
        };
        const litehtml::css_length& own = declared(side);
        if (!own.is_predefined()) {
            return px(resolve(own));
        }
        const litehtml::css_length& opposite = declared(side == 't' ? 'b' : side == 'b' ? 't' : side == 'l' ? 'r' : 'l');
        return opposite.is_predefined() ? "0px" : px(-resolve(opposite));
    }
    const litehtml::css_length& own = declared(side);
    if (!s.box || (!own.is_predefined() && own.units() != litehtml::css_units_percentage)) {
        return computedLength(own);
    }
    // The containing block: the nearest positioned ancestor (any, for fixed: the root's box stands for the viewport).
    litehtml::element* block = nullptr;
    for (auto el = s.element->parent(); el; el = el->parent()) {
        if (el->get_render_item() && (position == litehtml::element_position_fixed ? !el->parent()
                                                                                       : el->css().get_position() != litehtml::element_position_static)) {
            block = el.get();
            break;
        }
        if (!el->parent()) {
            block = el.get();
        }
    }
    if (!block || !block->get_render_item()) {
        return computedLength(own);
    }
    const Rect cb = paddingBox(*block->get_render_item());
    if (!own.is_predefined()) {
        return px((vertical ? cb.height : cb.width) * own.val() / 100.0);
    }
    const Rect me = borderBox(*s.box);
    switch (side) {
    case 'l':
        return px(me.x - toDouble(s.box->margin_left()) - cb.x);
    case 't':
        return px(me.y - toDouble(s.box->margin_top()) - cb.y);
    case 'r':
        return px(cb.x + cb.width - (me.x + me.width + toDouble(s.box->margin_right())));
    default:
        return px(cb.y + cb.height - (me.y + me.height + toDouble(s.box->margin_bottom())));
    }
}

/// transform-origin's resolved value: px of the element's border box.
std::string transformOrigin(const Source& s) {
    double width = 0, height = 0;
    if (s.box) {
        const Rect box = borderBox(*s.box);
        width = box.width;
        height = box.height;
    }
    const auto resolve = [](const litehtml::css_length& length, double size) {
        return toDouble(length.calc_percent(litehtml::pixel_t(float(size))));
    };
    return px(resolve(s.css.get_transform_origin_x(), width)) + " " + px(resolve(s.css.get_transform_origin_y(), height));
}

std::string boxShadows(const Source& s) {
    const litehtml::box_shadow_vector& shadows = s.css.get_box_shadows();
    if (shadows.empty()) {
        return "none";
    }
    std::string out;
    for (const litehtml::box_shadow& shadow : shadows) {
        if (!out.empty()) {
            out += ", ";
        }
        out += color(shadow.color, s.css) + " " + lengthValue(shadow.x) + " " + lengthValue(shadow.y) + " " +
               lengthValue(shadow.blur) + " " + lengthValue(shadow.spread) + (shadow.inset ? " inset" : "");
    }
    return out;
}

std::string radius(const litehtml::css_length& x, const litehtml::css_length& y) {
    const std::string horizontal = lengthValue(x);
    const std::string vertical = lengthValue(y);
    return horizontal == vertical ? horizontal : horizontal + " " + vertical;
}

std::string value(const Source& s, std::string_view name) {
    const litehtml::css_properties& css = s.css;
    if (name == "display") {
        const int display = int(css.get_display());
        return display == int(litehtml::display_inline_text) ? "inline" : keyword(litehtml::style_display_strings, display);
    }
    if (name == "position") {
        return keyword(litehtml::element_position_strings, int(css.get_position()));
    }
    if (name == "float" || name == "css-float") {
        return keyword(litehtml::element_float_strings, int(css.get_float()));
    }
    if (name == "box-sizing") {
        return keyword(litehtml::box_sizing_strings, int(css.get_box_sizing()));
    }
    if (name == "visibility") {
        return keyword(litehtml::visibility_strings, int(css.get_visibility()));
    }
    if (name == "white-space") {
        return keyword(litehtml::white_space_strings, int(css.get_white_space()));
    }
    // v0.1.1 plan, Task 3: the UA layer's sub/sup and tables (auto/22-ua-defaults).
    if (name == "vertical-align") {
        return keyword(litehtml::vertical_align_strings, int(css.get_vertical_align()));
    }
    if (name == "border-collapse") {
        return keyword(litehtml::border_collapse_strings, int(css.get_border_collapse()));
    }
    if (name == "list-style-type") {
        return keyword(litehtml::list_style_type_strings, int(css.get_list_style_type()));
    }
    if (name == "text-align") {
        std::string align = keyword(litehtml::text_align_strings, int(css.get_text_align()));
        return align == "-internal-th-center" ? "center" : align;
    }
    if (name == "overflow-x") {
        return keyword(litehtml::overflow_strings, int(css.get_overflow_x()));
    }
    if (name == "overflow-y") {
        return keyword(litehtml::overflow_strings, int(css.get_overflow_y()));
    }
    if (name == "overflow") {
        const std::string x = keyword(litehtml::overflow_strings, int(css.get_overflow_x()));
        const std::string y = keyword(litehtml::overflow_strings, int(css.get_overflow_y()));
        return x == y ? x : x + " " + y;
    }
    if (name == "font-size") {
        return px(toDouble(css.get_font_size()));
    }
    if (name == "font-weight") {
        return number(css.font_weight().val());
    }
    if (name == "font-style") {
        return keyword(litehtml::font_style_strings, int(css.font_style_value()));
    }
    if (name == "font-family") {
        return fontFamily(css.font_family());
    }
    if (name == "line-height") {
        const auto& lineHeight = css.line_height();
        return lineHeight.css_value.is_predefined() ? "normal" : px(toDouble(lineHeight.computed_value));
    }
    if (name == "color") {
        return color(css.get_color());
    }
    if (name == "background-color") {
        return color(css.get_bg().m_color, css);
    }
    if (name == "background-image") {
        // litehtml's initial value is one empty layer, never an empty list (V4 plan, Task 3b: css.url.remote reads none
        // for a declaration the profile dropped).
        return backgroundImage(css.get_bg());
    }
    if (name == "background-size") {
        return backgroundSize(css.get_bg());
    }
    if (name == "background-position") {
        return backgroundPosition(css.get_bg());
    }
    if (name == "background-repeat") {
        return backgroundRepeat(css.get_bg());
    }
    if (name == "filter") {
        return filterList(css.get_filter());
    }
    if (name == "backdrop-filter") {
        return filterList(css.get_backdrop_filter());
    }
    if (name == "fill" || name == "stroke") {
        return paint(s, name);
    }
    if (name == "stroke-width") {
        return strokeWidth(s);
    }
    if (name == "stroke-dasharray" || name == "stroke-dashoffset") {
        return strokeDash(s, name);
    }
    if (name == "grid-template-columns" || name == "grid-template-rows" || name == "grid-auto-rows") {
        // litehtml keeps the declaration's tokens (style.cpp) and lays a grid out from them: as written (final review I3).
        const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
        const litehtml::css_token_vector* tokens = tag ? tag->get_token_property(litehtml::_id(std::string(name))) : nullptr;
        if (tokens && !tokens->empty()) {
            return litehtml::get_repr(*tokens, 0, -1, true);
        }
        return name == "grid-auto-rows" ? "auto" : "none";
    }
    if (name == "touch-action") {
        // Not inherited: the element's own declaration (twidget edit 30.1), else auto.
        const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
        const std::string declared = tag ? tag->raw_declaration("touch-action") : std::string();
        return declared.empty() || unresolvedVar(declared) ? "auto" : declared;
    }
    if (name == "opacity") {
        return number(css.get_opacity());
    }
    if (name == "text-decoration-line") {
        return decorationLine(css.get_text_decoration_line());
    }
    if (name == "text-decoration-style") {
        return keyword(litehtml::style_text_decoration_style_strings, int(css.get_text_decoration_style()));
    }
    if (name == "text-decoration-color") {
        return color(css.get_text_decoration_color(), css);
    }
    if (name == "text-decoration") {
        return decorationLine(css.get_text_decoration_line()) + " " +
               keyword(litehtml::style_text_decoration_style_strings, int(css.get_text_decoration_style())) + " " +
               color(css.get_text_decoration_color(), css);
    }
    if (name == "width" || name == "height") {
        return usedSize(s, name == "width");
    }
    if (name == "margin") {
        return fourSides(marginSide(s, 't'), marginSide(s, 'r'), marginSide(s, 'b'), marginSide(s, 'l'));
    }
    if (name == "padding") {
        return fourSides(paddingSide(s, 't'), paddingSide(s, 'r'), paddingSide(s, 'b'), paddingSide(s, 'l'));
    }
    if (name.rfind("margin-", 0) == 0) {
        if (char side = sideOf(name.substr(7))) {
            return marginSide(s, side);
        }
    }
    if (name.rfind("padding-", 0) == 0) {
        if (char side = sideOf(name.substr(8))) {
            return paddingSide(s, side);
        }
    }
    if (name.rfind("border-", 0) == 0) {
        const std::string_view rest = name.substr(7);
        const size_t dash = rest.find('-');
        if (dash != std::string_view::npos) {
            if (char side = sideOf(rest.substr(0, dash))) {
                const litehtml::css_border& border = borderSide(css, side);
                const std::string_view part = rest.substr(dash + 1);
                if (part == "width") {
                    return borderWidth(border);
                }
                if (part == "style") {
                    return keyword(litehtml::border_style_strings, int(border.style));
                }
                if (part == "color") {
                    return color(border.color, css);
                }
            }
        }
    }
    if (name == "outline-style") {
        return keyword(litehtml::border_style_strings, int(css.get_outline().style));
    }
    if (name == "outline-width") {
        return borderWidth(css.get_outline());
    }
    if (name == "outline-color") {
        return color(css.get_outline().color, css);
    }
    if (name == "transform") {
        // Percentages of the border box, as litehtml applies them (final review I1).
        double width = 0, height = 0;
        if (s.box) {
            const Rect box = borderBox(*s.box);
            width = box.width;
            height = box.height;
        }
        return transform(css, width, height);
    }
    if (name == "cursor") {
        return cursor(css.get_cursor());
    }
    if (name == "content") {
        if (s.pseudo == PseudoElement::None) {
            return "normal";
        }
        const std::string& content = css.get_content();
        return s.pseudoMissing || content.empty() ? "none" : content;
    }
    // Not modeled by the renderer: their initial values, which nothing can change here.
    if (name == "direction") {
        // twidget edit 46: inherited; [dir] sets it (the Builder resolves dir=auto).
        return css.get_direction() == litehtml::direction_rtl ? "rtl" : "ltr";
    }
    // widget-sandbox v0.1.1 (D18): not inherited, so the element's own declaration (twidget edit 45: either name, the
    // later winning), else auto; the UA layer gives the root none. What the client selects follows selectsText.
    if (name == "user-select" || name == "-webkit-user-select") {
        switch (s.element ? ownUserSelect(*s.element) : UserSelect::Auto) {
        case UserSelect::None:
            return "none";
        case UserSelect::Text:
            return "text";
        case UserSelect::Auto:
            return "auto";
        }
    }
    if (name == "quotes") {
        // Inherited, kept as written (twidget edit 32.4); "" is auto.
        return css.get_quotes().empty() ? "auto" : css.get_quotes();
    }
    if (name == "word-spacing") {
        return css.get_word_spacing() == litehtml::pixel_t(0) ? "0px" : px(toDouble(css.get_word_spacing()));
    }
    if (name == "word-break") {
        return keyword(litehtml::word_break_strings, int(css.get_word_break()));
    }
    // Computed-style plan, Task 2: profile 1's longhands the renderer keeps, resolved as CSSOM says.
    if (char side = sideOf(name)) {
        return offset(s, side);
    }
    // litehtml computes the container's flex properties on flex or grid containers, justify-items on grid containers,
    // the item's on flex items, justify-self on grid items, and a gap's normal as 0: elsewhere, and for a gap always,
    // its own parse of the element's declarations (edit 54).
    if ((name == "flex-direction" || name == "flex-wrap") && !isFlexContainer(css)) {
        return parsedLonghand(s, name, initialValue(name));
    }
    if (name == "align-items" && !isBoxContainer(css)) {
        return parsedLonghand(s, name, initialValue(name));
    }
    if ((name == "flex-grow" || name == "flex-shrink" || name == "flex-basis") && !isFlexItem(s)) {
        return parsedLonghand(s, name, initialValue(name));
    }
    if (name == "justify-items" && !isGridContainer(css)) {
        return parsedLonghand(s, name, "normal");
    }
    if (name == "justify-self" && !isGridItem(s)) {
        return parsedLonghand(s, name, "auto");
    }
    if (name == "row-gap" || name == "column-gap") {
        return parsedLonghand(s, name, initialValue(name));
    }
    if (name == "flex-direction") {
        return keyword(litehtml::flex_direction_strings, int(css.get_flex_direction()));
    }
    if (name == "flex-wrap") {
        return keyword(litehtml::flex_wrap_strings, int(css.get_flex_wrap()));
    }
    if (name == "flex-grow") {
        return number(css.get_flex_grow());
    }
    if (name == "flex-shrink") {
        return number(css.get_flex_shrink());
    }
    if (name == "flex-basis") {
        return flexBasis(s, css.get_flex_basis());
    }
    if (name == "z-index") {
        // litehtml validates it (an integer or auto) and keeps auto apart from 0 (twidget edit 53).
        return css.get_z_index_length().is_predefined() ? std::string("auto") : std::to_string(css.get_z_index());
    }
    if (name == "order") {
        return std::to_string(css.get_order());
    }
    if (name == "align-items") {
        return alignment(css.get_flex_align_items());
    }
    if (name == "align-self") {
        return alignment(css.get_flex_align_self());
    }
    if (name == "justify-items") {
        return alignment(css.get_justify_items());
    }
    if (name == "justify-self") {
        return alignment(css.get_justify_self());
    }
    // What lays the element out (a later place-content included, final review I2): a box container's computed value,
    // elsewhere litehtml's parse of its declarations (edit 54), whose keywords litehtml's table validated. litehtml's
    // default (flex-start, stretch) also stands for CSS's undeclared normal and for place-content's normal and stretch,
    // so there the declarations (edit 51) tell which.
    if (name == "justify-content" || name == "align-content") {
        const bool justify = name == "justify-content";
        int index = 0;
        if (isBoxContainer(css)) {
            index = justify ? int(css.get_flex_justify_content()) : int(css.get_flex_align_content());
        } else {
            const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
            const litehtml::property_value* parsed = tag ? &tag->own_property(justify ? litehtml::_justify_content_ : litehtml::_align_content_) : nullptr;
            if (parsed && parsed->is<litehtml::inherit>()) {
                return parsedLonghand(s, name, "normal");
            }
            if (!parsed || !parsed->is<int>()) {
                return "normal";
            }
            index = parsed->get<int>();
        }
        const std::string value = justify ? keyword(litehtml::flex_justify_content_strings, index)
                                          : keyword(litehtml::flex_align_content_strings, index);
        const bool atDefault = justify ? index == litehtml::flex_justify_content_flex_start : index == litehtml::flex_align_content_stretch;
        if (!atDefault) {
            return value;
        }
        return contentAtDefault(s, justify).value_or("normal");
    }
    if (name == "min-width" || name == "min-height") {
        return lengthOrKeyword(name == "min-width" ? css.get_min_width() : css.get_min_height(), "auto");
    }
    if (name == "max-width" || name == "max-height") {
        return lengthOrKeyword(name == "max-width" ? css.get_max_width() : css.get_max_height(), "none");
    }
    if (name == "letter-spacing") {
        // litehtml keeps px (normal is 0).
        return css.get_letter_spacing() == litehtml::pixel_t(0) ? "normal" : px(toDouble(css.get_letter_spacing()));
    }
    if (name == "text-transform") {
        return keyword(litehtml::text_transform_strings, int(css.get_text_transform()));
    }
    if (name == "text-indent") {
        return computedLength(css.get_text_indent());
    }
    if (name == "text-overflow") {
        return keyword(litehtml::text_overflow_strings, int(css.get_text_overflow()));
    }
    if (name == "overflow-wrap" || name == "word-wrap") {
        return keyword(litehtml::overflow_wrap_strings, int(css.get_overflow_wrap()));
    }
    if (name == "clear") {
        return keyword(litehtml::element_clear_strings, int(css.get_clear()));
    }
    if (name == "list-style-position") {
        return keyword(litehtml::list_style_position_strings, int(css.get_list_style_position()));
    }
    if (name == "object-fit") {
        return keyword(litehtml::object_fit_strings, int(css.get_object_fit()));
    }
    if (name == "object-position") {
        return lengthValue(css.get_object_position_x()) + " " + lengthValue(css.get_object_position_y());
    }
    if (name == "aspect-ratio") {
        // The ratio litehtml applies, as declared (it keeps one float: 16 / 9 would read 1.77778 / 1).
        if (css.get_aspect_ratio() <= 0) {
            return "auto";
        }
        if (std::optional<std::string> ratio = declaredRatio(ownDeclaration(s, "aspect-ratio"))) {
            return *ratio;
        }
        return number(css.get_aspect_ratio()) + " / 1";
    }
    if (name == "transform-origin") {
        return transformOrigin(s);
    }
    if (name == "outline-offset") {
        return px(toDouble(css.get_outline_offset()));
    }
    if (name == "box-shadow") {
        return boxShadows(s);
    }
    if (name == "text-decoration-thickness") {
        const litehtml::css_length& thickness = css.get_text_decoration_thickness();
        return thickness.is_predefined() ? keyword(litehtml::style_text_decoration_thickness_strings, thickness.predef())
                                         : computedLength(thickness);
    }
    if (name == "background-origin") {
        const litehtml::background& bg = css.get_bg();
        return layers(bg, [&](size_t i) { return layerOrigin(bg, i); });
    }
    if (name == "-webkit-backdrop-filter") {
        return filterList(css.get_backdrop_filter());
    }
    if (name.size() > 7 && name.rfind("border-", 0) == 0 && name.substr(name.size() - 7) == "-radius") {
        const litehtml::css_border_radius& r = css.get_borders().radius;
        const std::string_view corner = name.substr(7, name.size() - 14);
        if (corner == "top-left") {
            return radius(r.top_left_x, r.top_left_y);
        }
        if (corner == "top-right") {
            return radius(r.top_right_x, r.top_right_y);
        }
        if (corner == "bottom-right") {
            return radius(r.bottom_right_x, r.bottom_right_y);
        }
        if (corner == "bottom-left") {
            return radius(r.bottom_left_x, r.bottom_left_y);
        }
    }
    // Computed-style plan, Task 3: the positional shorthands from their longhands' computed values.
    if (name == "flex") {
        return value(s, "flex-grow") + " " + value(s, "flex-shrink") + " " + value(s, "flex-basis");
    }
    if (name == "flex-flow") {
        return value(s, "flex-direction") + " " + value(s, "flex-wrap");
    }
    if (name == "gap") {
        return pairOf(value(s, "row-gap"), value(s, "column-gap"));
    }
    if (name == "inset") {
        return fourSides(value(s, "top"), value(s, "right"), value(s, "bottom"), value(s, "left"));
    }
    if (name == "place-content") {
        return pairOf(value(s, "align-content"), value(s, "justify-content"));
    }
    if (name == "place-items") {
        return pairOf(value(s, "align-items"), value(s, "justify-items"));
    }
    if (name == "place-self") {
        return pairOf(value(s, "align-self"), value(s, "justify-self"));
    }
    if (name == "border-width" || name == "border-style" || name == "border-color") {
        const std::string part(name.substr(6));
        return fourSides(value(s, "border-top" + part), value(s, "border-right" + part), value(s, "border-bottom" + part),
                         value(s, "border-left" + part));
    }
    if (name == "border-top" || name == "border-right" || name == "border-bottom" || name == "border-left") {
        const std::string side(name);
        return value(s, side + "-width") + " " + value(s, side + "-style") + " " + value(s, side + "-color");
    }
    if (name == "border") {
        // One value for four sides, so "" when they differ (CSSOM).
        const std::string top = value(s, "border-top");
        for (const char* side : {"border-right", "border-bottom", "border-left"}) {
            if (value(s, side) != top) {
                return std::string();
            }
        }
        return top;
    }
    if (name == "border-radius") {
        const litehtml::css_border_radius& r = css.get_borders().radius;
        const std::string horizontal = fourSides(lengthValue(r.top_left_x), lengthValue(r.top_right_x),
                                                 lengthValue(r.bottom_right_x), lengthValue(r.bottom_left_x));
        const std::string vertical = fourSides(lengthValue(r.top_left_y), lengthValue(r.top_right_y),
                                               lengthValue(r.bottom_right_y), lengthValue(r.bottom_left_y));
        return horizontal == vertical ? horizontal : horizontal + " / " + vertical;
    }
    if (name == "outline") {
        // Chrome's order.
        return value(s, "outline-color") + " " + value(s, "outline-style") + " " + value(s, "outline-width");
    }
    if (name == "list-style") {
        const std::string& image = css.get_list_style_image();
        return value(s, "list-style-position") + " " + (image.empty() ? std::string("none") : "url(\"" + image + "\")") +
               " " + value(s, "list-style-type");
    }
    // The complex shorthands, canonical rather than claimed Chrome-exact.
    if (name == "background") {
        return backgroundShorthand(css.get_bg(), value(s, "background-color"));
    }
    if (name == "font") {
        // Style, weight, size / line height and family, without the parts at their initial values.
        std::string out;
        if (const std::string style = value(s, "font-style"); style != "normal") {
            out += style + " ";
        }
        if (const std::string weight = value(s, "font-weight"); weight != "400") {
            out += weight + " ";
        }
        out += value(s, "font-size");
        if (const std::string lineHeight = value(s, "line-height"); lineHeight != "normal") {
            out += " / " + lineHeight;
        }
        return out + " " + value(s, "font-family");
    }
    if (name == "grid-row" || name == "grid-column" || name == "grid-area") {
        // As declared, side by side (litehtml's placement keeps a span but not its side), else what litehtml placed.
        const auto row = declaredGridLines(s, litehtml::_grid_row_, litehtml::_grid_row_start_, litehtml::_grid_row_end_)
                             .value_or(gridLines(css.get_grid_row()));
        const auto column = declaredGridLines(s, litehtml::_grid_column_, litehtml::_grid_column_start_, litehtml::_grid_column_end_)
                                .value_or(gridLines(css.get_grid_column()));
        if (name == "grid-row") {
            return gridLineList({row.first, row.second});
        }
        if (name == "grid-column") {
            return gridLineList({column.first, column.second});
        }
        return gridLineList({row.first, column.first, row.second, column.second});
    }
    if (name.rfind("animation-", 0) == 0 || name.rfind("transition-", 0) == 0) {
        if (initialValue(name)) {
            return listLonghand(s, name);
        }
    }
    if (name == "animation" || name == "transition") {
        // Its longhands' lists joined entry by entry, each cycled to the first's length (the name's, the property's), as
        // CSS repeats a shorter list; "" past kMaxJoinedBytes (final review C1).
        const bool animation = name == "animation";
        static const char* const animationLonghands[] = {"animation-name", "animation-duration", "animation-timing-function",
            "animation-delay", "animation-iteration-count", "animation-direction", "animation-fill-mode", "animation-play-state"};
        static const char* const transitionLonghands[] = {"transition-property", "transition-duration",
            "transition-timing-function", "transition-delay"};
        std::vector<std::vector<std::string>> lists;
        if (animation) {
            for (const char* longhand : animationLonghands) {
                lists.push_back(commaItems(s, value(s, longhand)));
            }
        } else {
            for (const char* longhand : transitionLonghands) {
                lists.push_back(commaItems(s, value(s, longhand)));
            }
        }
        size_t bytes = 0;
        for (size_t entry = 0; entry < lists.front().size(); entry++) {
            for (const std::vector<std::string>& list : lists) {
                bytes += list[entry % list.size()].size() + 2;
            }
        }
        if (bytes > kMaxJoinedBytes) {
            return std::string();
        }
        std::string out;
        for (size_t entry = 0; entry < lists.front().size(); entry++) {
            if (entry > 0) {
                out += ", ";
            }
            for (size_t k = 0; k < lists.size(); k++) {
                out += (k > 0 ? " " : "") + lists[k][entry % lists[k].size()];
            }
        }
        return out;
    }
    return declaredOrInitial(s, name);
}

} // namespace

const std::vector<std::string>& computedPropertyNames() {
    static const std::vector<std::string> names = {
        "backdrop-filter", "background-color", "background-image", "background-position", "background-repeat",
        "background-size", "border-bottom-color", "border-bottom-style", "border-bottom-width",
        "border-collapse", "border-left-color", "border-left-style", "border-left-width", "border-right-color", "border-right-style",
        "border-right-width", "border-top-color", "border-top-style", "border-top-width", "box-sizing", "color",
        "content", "cursor", "direction", "display", "fill", "filter", "float", "font-family", "font-size", "font-style",
        "font-weight",
        "height", "line-height", "list-style-type", "margin-bottom", "margin-left", "margin-right", "margin-top",
        "opacity", "outline-color", "outline-style", "outline-width", "overflow-x", "overflow-y", "padding-bottom",
        "padding-left", "padding-right", "padding-top", "position", "quotes", "stroke", "stroke-width", "text-align",
        "text-decoration-color",
        "text-decoration-line", "text-decoration-style", "touch-action", "transform", "user-select", "vertical-align",
        "visibility", "white-space", "width", "word-break", "word-spacing",
        // Every other profile 1 longhand (declaredOrInitial and the exact answers after it). CSSOM lists longhands only:
        // the shorthands and the legacy alias word-wrap read by name.
        "-webkit-backdrop-filter", "align-content", "align-items", "align-self", "animation-delay",
        "animation-direction", "animation-duration", "animation-fill-mode", "animation-iteration-count",
        "animation-name", "animation-play-state", "animation-timing-function", "aspect-ratio", "background-origin",
        "border-bottom-left-radius", "border-bottom-right-radius", "border-top-left-radius",
        "border-top-right-radius", "bottom", "box-shadow", "clear", "color-scheme", "column-gap", "counter-increment",
        "counter-reset", "flex-basis", "flex-direction", "flex-grow", "flex-shrink", "flex-wrap",
        "font-feature-settings", "font-variant-numeric", "grid-auto-columns", "grid-auto-flow", "grid-auto-rows",
        "grid-template-areas", "grid-template-columns", "grid-template-rows", "justify-content", "justify-items",
        "left", "letter-spacing", "list-style-position", "max-height", "max-width", "min-height", "min-width",
        "object-fit", "object-position", "order", "outline-offset", "overflow-wrap", "pointer-events", "right",
        "rotate", "row-gap", "scale", "stroke-dasharray", "stroke-dashoffset", "text-decoration-thickness",
        "text-indent", "text-overflow", "text-transform", "top", "transform-origin", "transition-behavior",
        "transition-delay", "transition-duration", "transition-property", "transition-timing-function", "translate",
        "unicode-bidi", "z-index",
    };
    return names;
}

PseudoElement pseudoElementNamed(std::string_view name) {
    std::string lower(name);
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) { return char(std::tolower(c)); });
    if (lower == "::before" || lower == ":before") {
        return PseudoElement::Before;
    }
    if (lower == "::after" || lower == ":after") {
        return PseudoElement::After;
    }
    return PseudoElement::None;
}

std::string computedValue(litehtml::element& element, std::string_view name, PseudoElement pseudo) {
    litehtml::element* styled = &element;
    bool pseudoMissing = false;
    if (pseudo != PseudoElement::None) {
        const auto& children = element.children();
        litehtml::element::ptr candidate;
        if (!children.empty()) {
            candidate = pseudo == PseudoElement::Before ? children.front() : children.back();
        }
        const litehtml::string_id tag = pseudo == PseudoElement::Before ? litehtml::__tag_before_ : litehtml::__tag_after_;
        if (candidate && candidate->tag() == tag) {
            styled = candidate.get();
        } else {
            pseudoMissing = true;
        }
    }
    if (name.size() > 2 && name[0] == '-' && name[1] == '-') {
        // A custom property: looked up without adding the name to litehtml's process-wide id table (twidget edit 23).
        auto* tag = dynamic_cast<litehtml::html_tag*>(styled);
        litehtml::string_id id;
        if (!tag || !litehtml::_find_id(std::string(name), id)) {
            return std::string();
        }
        const litehtml::css_token_vector* tokens = tag->find_custom_property(id);
        return tokens ? litehtml::get_repr(*tokens, 0, -1, true) : std::string();
    }
    Source source{styled->css(), pseudoMissing ? nullptr : styled->get_render_item()};
    source.element = styled;
    const litehtml::style_display display = styled->css().get_display();
    source.inlineNonReplaced = (display == litehtml::display_inline || display == litehtml::display_inline_text) && !styled->is_replaced();
    source.pseudo = pseudo;
    source.pseudoMissing = pseudoMissing;
    return value(source, name);
}

UserSelect ownUserSelect(const litehtml::element& element) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(&element);
    if (!tag) {
        return UserSelect::Auto;
    }
    std::string declared = tag->raw_declaration("user-select");
    std::transform(declared.begin(), declared.end(), declared.begin(), [](unsigned char c) { return char(std::tolower(c)); });
    if (declared == "text") {
        return UserSelect::Text;
    }
    if (declared == "none") {
        return UserSelect::None;
    }
    return UserSelect::Auto;
}

bool selectsText(const litehtml::element& element) {
    for (const litehtml::element* el = &element; el; el = el->parent().get()) {
        switch (ownUserSelect(*el)) {
        case UserSelect::Text:
            return true;
        case UserSelect::None:
            return false;
        case UserSelect::Auto:
            break;
        }
    }
    return false;
}

} // namespace wr
