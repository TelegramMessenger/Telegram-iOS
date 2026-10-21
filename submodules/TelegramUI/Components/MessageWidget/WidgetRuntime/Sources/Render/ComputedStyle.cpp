#include "Sources/Render/ComputedStyle.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <memory>
#include <type_traits>

#include <litehtml.h>
#include <litehtml/render_item.h>

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

/// The transform functions composed into one 2D matrix (the origin is not part of the resolved value), percentages of
/// the border box; "none" with no functions.
std::string transform(const litehtml::css_properties& css, double boxWidth, double boxHeight) {
    const auto& functions = css.get_transform();
    if (functions.empty()) {
        return "none";
    }
    litehtml::transform_matrix m;
    for (auto it = functions.rbegin(); it != functions.rend(); ++it) {
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
        return css.get_bg().m_image.empty() ? "none" : std::string();
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
        return "ltr";
    }
    if (name == "user-select" || name == "-webkit-user-select" || name == "touch-action" || name == "quotes") {
        return "auto";
    }
    return std::string();
}

} // namespace

const std::vector<std::string>& computedPropertyNames() {
    static const std::vector<std::string> names = {
        "background-color", "background-image", "border-bottom-color", "border-bottom-style", "border-bottom-width",
        "border-left-color", "border-left-style", "border-left-width", "border-right-color", "border-right-style",
        "border-right-width", "border-top-color", "border-top-style", "border-top-width", "box-sizing", "color",
        "content", "cursor", "direction", "display", "float", "font-family", "font-size", "font-style", "font-weight",
        "height", "line-height", "list-style-type", "margin-bottom", "margin-left", "margin-right", "margin-top",
        "opacity", "outline-color", "outline-style", "outline-width", "overflow-x", "overflow-y", "padding-bottom",
        "padding-left", "padding-right", "padding-top", "position", "quotes", "text-align", "text-decoration-color",
        "text-decoration-line", "text-decoration-style", "touch-action", "transform", "user-select", "visibility",
        "white-space", "width",
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
    const litehtml::style_display display = styled->css().get_display();
    source.inlineNonReplaced = (display == litehtml::display_inline || display == litehtml::display_inline_text) && !styled->is_replaced();
    source.pseudo = pseudo;
    source.pseudoMissing = pseudoMissing;
    return value(source, name);
}

} // namespace wr
