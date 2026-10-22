#include "Sources/Render/ComputedStyle.h"

#include <algorithm>
#include <unordered_map>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <memory>
#include <type_traits>

#include <litehtml.h>
#include <litehtml/el_svg.h>
#include <litehtml/render_item.h>
#include <litehtml/web_color.h>

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

/// A computed length: `auto` (and the other keywords) when predefined, a percentage as written, otherwise px.
std::string computedLength(const litehtml::css_length& length) {
    if (length.is_predefined()) {
        return "auto";
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
            f.tx = it->x.units() == litehtml::css_units_percentage ? float(it->x.val() * boxWidth / 100.0) : it->x.val();
            f.ty = it->y.units() == litehtml::css_units_percentage ? float(it->y.val() * boxHeight / 100.0) : it->y.val();
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

std::string backgroundImage(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) -> std::string {
        if (i >= bg.m_image.size() || bg.m_image[i].is_empty()) {
            return "none";
        }
        const litehtml::image& image = bg.m_image[i];
        // A gradient keeps no text of its own here: it reads as none until the serializer learns gradients.
        return image.type == litehtml::image::type_url ? "url(\"" + image.url + "\")" : "none";
    });
}

std::string backgroundSize(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) -> std::string {
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
    });
}

std::string backgroundPosition(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) -> std::string {
        const litehtml::css_length* x = layerAt(bg.m_position_x, i);
        const litehtml::css_length* y = layerAt(bg.m_position_y, i);
        return (x ? lengthValue(*x) : std::string("0%")) + " " + (y ? lengthValue(*y) : std::string("0%"));
    });
}

std::string backgroundRepeat(const litehtml::background& bg) {
    return layers(bg, [&](size_t i) -> std::string {
        const int* repeat = layerAt(bg.m_repeat, i);
        return repeat ? keyword(litehtml::background_repeat_strings, *repeat) : std::string("repeat");
    });
}

/// The initial value (computed form) of a profile 1 property `value` has no exact answer for, or nullptr when `name` is
/// not one (getComputedStyle then answers "", as for any name it does not know).
const char* initialValue(std::string_view name) {
    static const std::unordered_map<std::string_view, const char*> initial = {
        {"align-content", "normal"}, {"align-items", "normal"}, {"align-self", "auto"}, {"justify-content", "normal"},
        {"justify-items", "normal"}, {"place-content", "normal"}, {"place-items", "normal"}, {"place-self", "auto"},
        {"flex-direction", "row"}, {"flex-wrap", "nowrap"}, {"flex-flow", "row nowrap"}, {"flex-grow", "0"},
        {"flex-shrink", "1"}, {"flex-basis", "auto"}, {"flex", "0 1 auto"}, {"order", "0"}, {"row-gap", "normal"},
        {"column-gap", "normal"}, {"gap", "normal"}, {"grid-auto-columns", "auto"}, {"grid-auto-rows", "auto"},
        {"grid-auto-flow", "row"}, {"grid-template-columns", "none"}, {"grid-template-rows", "none"},
        {"grid-template-areas", "none"}, {"grid-row", "auto"}, {"grid-column", "auto"}, {"grid-area", "auto"},
        {"top", "auto"}, {"right", "auto"}, {"bottom", "auto"}, {"left", "auto"}, {"inset", "auto"},
        {"min-width", "auto"}, {"min-height", "auto"}, {"max-width", "none"}, {"max-height", "none"}, {"z-index", "auto"},
        {"letter-spacing", "normal"}, {"text-transform", "none"}, {"text-indent", "0px"}, {"text-overflow", "clip"},
        {"overflow-wrap", "normal"}, {"word-wrap", "normal"}, {"unicode-bidi", "normal"}, {"pointer-events", "auto"},
        {"clear", "none"}, {"list-style-position", "outside"}, {"list-style", "outside none disc"},
        {"object-fit", "fill"}, {"object-position", "50% 50%"}, {"aspect-ratio", "auto"},
        {"transform-origin", "50% 50%"}, {"translate", "none"}, {"rotate", "none"}, {"scale", "none"},
        {"box-shadow", "none"}, {"background-origin", "padding-box"}, {"border-radius", "0px"},
        {"border-top-left-radius", "0px"}, {"border-top-right-radius", "0px"}, {"border-bottom-right-radius", "0px"},
        {"border-bottom-left-radius", "0px"}, {"outline-offset", "0px"}, {"counter-increment", "none"},
        {"counter-reset", "none"}, {"font-feature-settings", "normal"}, {"font-variant-numeric", "normal"},
        {"stroke-dasharray", "none"}, {"stroke-dashoffset", "0px"}, {"text-decoration-thickness", "auto"},
        {"color-scheme", "normal"}, {"animation-name", "none"}, {"animation-duration", "0s"},
        {"animation-timing-function", "ease"}, {"animation-delay", "0s"}, {"animation-iteration-count", "1"},
        {"animation-direction", "normal"}, {"animation-fill-mode", "none"}, {"animation-play-state", "running"},
        {"animation", "none 0s ease 0s 1 normal none running"}, {"transition-property", "all"},
        {"transition-duration", "0s"}, {"transition-timing-function", "ease"}, {"transition-delay", "0s"},
        {"transition-behavior", "normal"}, {"transition", "all 0s ease 0s"}, {"background", "rgba(0, 0, 0, 0) none"},
        {"font", "16px sans-serif"}, {"border", "0px none rgb(0, 0, 0)"}, {"border-top", "0px none rgb(0, 0, 0)"},
        {"border-right", "0px none rgb(0, 0, 0)"}, {"border-bottom", "0px none rgb(0, 0, 0)"},
        {"border-left", "0px none rgb(0, 0, 0)"}, {"border-width", "0px"}, {"border-style", "none"},
        {"border-color", "rgb(0, 0, 0)"}, {"outline", "rgb(0, 0, 0) none 0px"},
        {"-webkit-backdrop-filter", "none"},
    };
    const auto it = initial.find(name);
    return it == initial.end() ? nullptr : it->second;
}

/// Inherited among those (CSS's "Inherited: yes").
bool inheritedProperty(std::string_view name) {
    return name == "letter-spacing" || name == "text-transform" || name == "text-indent" || name == "pointer-events" ||
           name == "list-style-position" || name == "list-style" || name == "overflow-wrap" || name == "word-wrap" ||
           name == "color-scheme" || name == "font-feature-settings" || name == "font-variant-numeric" || name == "font" ||
           name == "stroke-dasharray" || name == "stroke-dashoffset";
}

/// A profile 1 property `value` has no exact answer for yet: the element's own declaration as written (with var()
/// substituted), else an inherited property's nearest ancestor's, else its initial value; the CSS-wide keywords as they
/// cascade. "" for a name that is not one. Walks at most the tree's depth (256).
std::string declaredOrInitial(const Source& s, std::string_view name) {
    const char* initial = initialValue(name);
    if (!initial) {
        return std::string();
    }
    const bool inherited = inheritedProperty(name);
    for (const litehtml::element* el = s.element; el; el = el->parent().get()) {
        const auto* tag = dynamic_cast<const litehtml::html_tag*>(el);
        std::string declared = tag ? tag->raw_declaration(std::string(name)) : std::string();
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

/// The element's own raw declaration of `name` ("" without one).
std::string ownDeclaration(const Source& s, const char* name) {
    const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
    return tag ? tag->raw_declaration(name) : std::string();
}

/// CSSOM's resolved top/right/bottom/left: a static element's computed value; a relative one's used px (a percentage of
/// its containing block, the opposite's negation for auto, else 0); an absolute or fixed one's used px from the layout,
/// against its containing block's padding box.
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
        const auto resolve = [&](const litehtml::css_length& length) {
            return length.units() == litehtml::css_units_percentage ? base * length.val() / 100.0 : double(length.val());
        };
        const litehtml::css_length& own = declared(side);
        if (!own.is_predefined()) {
            return px(resolve(own));
        }
        const litehtml::css_length& opposite = declared(side == 't' ? 'b' : side == 'b' ? 't' : side == 'l' ? 'r' : 'l');
        return opposite.is_predefined() ? "0px" : px(-resolve(opposite));
    }
    if (!s.box) {
        return computedLength(declared(side));
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
        return computedLength(declared(side));
    }
    const auto box = block->get_render_item();
    const litehtml::position cb = box->get_placement();
    const double cbLeft = toDouble(cb.x) + toDouble(box->border_left());
    const double cbTop = toDouble(cb.y) + toDouble(box->border_top());
    const double cbRight = toDouble(cb.x) + toDouble(cb.width) - toDouble(box->border_right());
    const double cbBottom = toDouble(cb.y) + toDouble(cb.height) - toDouble(box->border_bottom());
    const litehtml::position me = s.box->get_placement();
    switch (side) {
    case 'l':
        return px(toDouble(me.x) - toDouble(s.box->margin_left()) - cbLeft);
    case 't':
        return px(toDouble(me.y) - toDouble(s.box->margin_top()) - cbTop);
    case 'r':
        return px(cbRight - (toDouble(me.x) + toDouble(me.width) + toDouble(s.box->margin_right())));
    default:
        return px(cbBottom - (toDouble(me.y) + toDouble(me.height) + toDouble(s.box->margin_bottom())));
    }
}

/// transform-origin's resolved value: px of the element's border box.
std::string transformOrigin(const Source& s) {
    double width = 0, height = 0;
    if (s.box) {
        const litehtml::position placement = s.box->get_placement();
        width = toDouble(placement.width);
        height = toDouble(placement.height);
    }
    const auto resolve = [](const litehtml::css_length& length, double size) {
        return length.units() == litehtml::css_units_percentage ? size * length.val() / 100.0 : double(length.val());
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
    if (name == "touch-action") {
        // Not inherited: the element's own declaration (twidget edit 30.1), else auto.
        const auto* tag = dynamic_cast<const litehtml::html_tag*>(s.element);
        const std::string declared = tag ? tag->raw_declaration("touch-action") : std::string();
        return declared.empty() ? "auto" : declared;
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
        double width = 0, height = 0;
        if (s.box) {
            const litehtml::position placement = s.box->get_placement();
            width = toDouble(placement.width);
            height = toDouble(placement.height);
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
    // litehtml computes the container's flex properties on flex or grid containers and the item's on flex items only;
    // elsewhere the declaration as written, else the initial value (edit 51).
    if ((name == "flex-direction" || name == "flex-wrap") && !isFlexContainer(css)) {
        return declaredOrInitial(s, name);
    }
    if ((name == "align-items" || name == "row-gap" || name == "column-gap") && !isBoxContainer(css)) {
        return declaredOrInitial(s, name);
    }
    if ((name == "flex-grow" || name == "flex-shrink" || name == "flex-basis") && !isFlexItem(s)) {
        return declaredOrInitial(s, name);
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
        const litehtml::css_length& basis = css.get_flex_basis();
        return basis.is_predefined() ? keyword(litehtml::flex_basis_strings, basis.predef()) : computedLength(basis);
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
    // litehtml's value cannot tell an undeclared one (CSS's normal) from its default: the declaration first (edit 51).
    if (name == "justify-content" || name == "align-content") {
        const bool justify = name == "justify-content";
        const std::string declared = ownDeclaration(s, justify ? "justify-content" : "align-content");
        if (!declared.empty() || !isBoxContainer(css)) {
            return declaredOrInitial(s, name);
        }
        if (justify) {
            const int value = int(css.get_flex_justify_content());
            return value == litehtml::flex_justify_content_flex_start ? "normal" : keyword(litehtml::flex_justify_content_strings, value);
        }
        const int value = int(css.get_flex_align_content());
        return value == litehtml::flex_align_content_stretch ? "normal" : keyword(litehtml::flex_align_content_strings, value);
    }
    if (name == "row-gap" || name == "column-gap") {
        return lengthOrKeyword(name == "row-gap" ? css.get_row_gap() : css.get_column_gap(), "normal");
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
        return css.get_aspect_ratio() > 0 ? number(css.get_aspect_ratio()) + " / 1" : "auto";
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
        return layers(bg, [&](size_t i) -> std::string {
            const int* box = layerAt(bg.m_origin, i);
            return box ? keyword(litehtml::background_box_strings, *box) : std::string("padding-box");
        });
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
        // Every other profile 1 property (2026-10-22, declaredOrInitial and the exact answers after it).
        "-webkit-backdrop-filter", "align-content", "align-items", "align-self", "animation", "animation-delay",
        "animation-direction", "animation-duration", "animation-fill-mode", "animation-iteration-count", "animation-name",
        "animation-play-state", "animation-timing-function", "aspect-ratio", "background", "background-origin", "border",
        "border-bottom", "border-bottom-left-radius", "border-bottom-right-radius", "border-color", "border-left",
        "border-radius", "border-right", "border-style", "border-top", "border-top-left-radius", "border-top-right-radius",
        "border-width", "bottom", "box-shadow", "clear", "color-scheme", "column-gap", "counter-increment",
        "counter-reset", "flex", "flex-basis", "flex-direction", "flex-flow", "flex-grow", "flex-shrink", "flex-wrap",
        "font", "font-feature-settings", "font-variant-numeric", "gap", "grid-area", "grid-auto-columns",
        "grid-auto-flow", "grid-auto-rows", "grid-column", "grid-row", "grid-template-areas", "grid-template-columns",
        "grid-template-rows", "inset", "justify-content", "justify-items", "left", "letter-spacing", "list-style",
        "list-style-position", "max-height", "max-width", "min-height", "min-width", "object-fit", "object-position",
        "order", "outline", "outline-offset", "overflow-wrap", "place-content", "place-items", "place-self",
        "pointer-events", "right", "rotate", "row-gap", "scale", "stroke-dasharray", "stroke-dashoffset",
        "text-decoration-thickness", "text-indent", "text-overflow", "text-transform", "top", "transform-origin",
        "transition", "transition-behavior", "transition-delay", "transition-duration", "transition-property",
        "transition-timing-function", "translate", "unicode-bidi", "word-wrap", "z-index",
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

bool selectsText(const litehtml::element& element, uint64_t* visited) {
    for (const litehtml::element* el = &element; el; el = el->parent().get()) {
        if (visited) {
            (*visited)++;
        }
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
