#include "Sources/Canvas/CanvasStyle.h"

#include <cmath>
#include <cstdio>
#include <string_view>
#include <vector>

#include <litehtml/web_color.h>

#include "Sources/DOM/CSSComponents.h"
#include "Sources/Host/Profile.h"

namespace wr::canvas {

namespace {

using litehtml::css_token;

/// The component values that are not whitespace.
std::vector<const css_token*> items(const litehtml::css_token_vector& tokens) {
    std::vector<const css_token*> out;
    for (const css_token& t : tokens) {
        if (t.type != litehtml::WHITESPACE) {
            out.push_back(&t);
        }
    }
    return out;
}

std::string lowered(std::string s) {
    for (char& c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c - 'A' + 'a');
        }
    }
    return s;
}

std::string number(double v) {
    char buffer[32];
    std::snprintf(buffer, sizeof buffer, "%.6g", v);
    return buffer;
}

bool isDelim(const css_token& t, char c) { return t.type == c || (t.type > 0 && t.ch == c); }

/// A font-size keyword's px, relative to the canvas default of 10px for larger and smaller.
std::optional<double> sizeKeyword(const std::string& ident) {
    static const std::pair<const char*, double> kSizes[] = {
        {"xx-small", 9}, {"x-small", 10}, {"small", 13},   {"medium", 16},  {"large", 18},
        {"x-large", 24}, {"xx-large", 32}, {"xxx-large", 48}, {"larger", 12}, {"smaller", 10 / 1.2},
    };
    for (const auto& [name, px] : kSizes) {
        if (ident == name) {
            return px;
        }
    }
    return std::nullopt;
}

/// A <length-percentage> font size in px (em, rem and % of the canvas default 10px).
std::optional<double> sizeOf(const css_token& t) {
    if (t.type == litehtml::PERCENTAGE) {
        return t.n.number >= 0 ? std::optional<double>(10.0 * t.n.number / 100) : std::nullopt;
    }
    if (t.type == litehtml::NUMBER) {
        return t.n.number == 0 ? std::optional<double>(0) : std::nullopt;
    }
    if (t.type != litehtml::DIMENSION || t.n.number < 0) {
        return std::nullopt;
    }
    static const std::pair<const char*, double> kUnits[] = {
        {"px", 1}, {"pt", 4.0 / 3}, {"pc", 16}, {"in", 96}, {"cm", 96 / 2.54}, {"mm", 96 / 25.4}, {"q", 96 / 101.6},
        {"em", 10}, {"rem", 10}, {"ex", 5}, {"ch", 5},
    };
    const std::string unit = lowered(t.unit());
    for (const auto& [name, px] : kUnits) {
        if (unit == name) {
            return double(t.n.number) * px;
        }
    }
    return std::nullopt;
}

bool isStretch(const std::string& ident) {
    static const char* const kStretches[] = {"ultra-condensed", "extra-condensed", "condensed", "semi-condensed",
                                             "semi-expanded",   "expanded",        "extra-expanded", "ultra-expanded"};
    for (const char* s : kStretches) {
        if (ident == s) {
            return true;
        }
    }
    return false;
}

} // namespace

std::optional<Color> parseColor(JSContext* ctx, const String& text) {
    std::optional<litehtml::css_token_vector> tokens = css::componentValues(ctx, text);
    if (!tokens) {
        return std::nullopt;
    }
    const std::vector<const css_token*> values = items(*tokens);
    if (values.size() != 1) {
        return std::nullopt;
    }
    litehtml::web_color color;
    if (!litehtml::parse_color(*values[0], color, nullptr)) {
        return std::nullopt;
    }
    if (color.is_current_color) {
        return Color{0, 0, 0, 255};
    }
    return Color{color.red, color.green, color.blue, color.alpha};
}

std::string serializeColor(const Color& c) {
    char buffer[64];
    if (c.a == 255) {
        std::snprintf(buffer, sizeof buffer, "#%02x%02x%02x", c.r, c.g, c.b);
        return buffer;
    }
    // The shortest decimal (to three places) that maps back to the same byte.
    std::string alpha;
    for (int places = 1; places <= 3; places++) {
        const double scale = std::pow(10.0, places);
        const double v = std::round(c.a / 255.0 * scale) / scale;
        if (std::lround(v * 255) == c.a || places == 3) {
            alpha = number(v);
            break;
        }
    }
    std::snprintf(buffer, sizeof buffer, "rgba(%d, %d, %d, %s)", c.r, c.g, c.b, alpha.c_str());
    return buffer;
}

std::optional<std::string> serializedLength(JSContext* ctx, const String& text) {
    std::optional<litehtml::css_token_vector> tokens = css::componentValues(ctx, text);
    if (!tokens) {
        return std::nullopt;
    }
    const std::vector<const css_token*> values = items(*tokens);
    if (values.size() != 1) {
        return std::nullopt;
    }
    const css_token& t = *values[0];
    if (t.type == litehtml::NUMBER && t.n.number == 0) {
        return std::string("0px");
    }
    static const char* const kUnits[] = {"px", "pt", "pc", "in", "cm", "mm", "q", "em", "rem", "ex", "ch", "vw", "vh", "vmin", "vmax"};
    if (t.type == litehtml::DIMENSION) {
        const std::string unit = lowered(t.unit());
        for (const char* u : kUnits) {
            if (unit == u) {
                return number(t.n.number) + unit;
            }
        }
    }
    return std::nullopt;
}

std::optional<FontValue> parseFont(JSContext* ctx, const String& text) {
    std::optional<litehtml::css_token_vector> tokens = css::componentValues(ctx, text);
    if (!tokens) {
        return std::nullopt;
    }
    const std::vector<const css_token*> values = items(*tokens);
    size_t i = 0;
    bool italic = false, oblique = false, smallCaps = false;
    int weight = 400;
    std::string stretch;
    std::optional<double> size;
    // Up to four of style, variant, weight and stretch, in any order (`normal` counts toward any), then the size.
    for (int prefix = 0; i < values.size() && !size; i++) {
        const css_token& t = *values[i];
        if (t.type == litehtml::IDENT) {
            const std::string ident = lowered(t.ident());
            if ((size = sizeKeyword(ident))) {
                break;
            }
            if (prefix == 4) {
                return std::nullopt;
            }
            prefix++;
            if (ident == "normal") {
                continue;
            }
            if (ident == "italic") {
                italic = true;
            } else if (ident == "oblique") {
                oblique = true;
            } else if (ident == "small-caps") {
                smallCaps = true;
            } else if (ident == "bold" || ident == "bolder") {
                weight = 700;
            } else if (ident == "lighter") {
                weight = 100;
            } else if (isStretch(ident)) {
                stretch = ident;
            } else {
                // A family before any size, or a system font keyword: not a shorthand the canvas takes.
                return std::nullopt;
            }
            continue;
        }
        if (t.type == litehtml::NUMBER && t.n.number >= 1 && t.n.number <= 1000 && prefix < 4) {
            weight = int(std::lround(t.n.number));
            prefix++;
            continue;
        }
        if ((size = sizeOf(t))) {
            break;
        }
        return std::nullopt;
    }
    if (!size || i >= values.size()) {
        return std::nullopt;
    }
    i++;
    // An optional line height, which the canvas ignores.
    if (i < values.size() && isDelim(*values[i], '/')) {
        if (i + 1 >= values.size()) {
            return std::nullopt;
        }
        const css_token& lh = *values[i + 1];
        const bool ok = lh.type == litehtml::NUMBER || lh.type == litehtml::DIMENSION || lh.type == litehtml::PERCENTAGE ||
                        (lh.type == litehtml::IDENT && lowered(lh.ident()) == "normal");
        if (!ok) {
            return std::nullopt;
        }
        i += 2;
    }
    // The family list: comma-separated strings or runs of identifiers.
    std::vector<std::string> families;
    std::vector<std::string> generics;
    std::string group;
    bool groupIsString = false;
    auto finish = [&]() {
        if (group.empty()) {
            return false;
        }
        families.push_back(groupIsString ? "\"" + group + "\"" : group);
        if (!groupIsString && profile::contains(profile::CSSTable::GenericFonts, lowered(group))) {
            generics.push_back(lowered(group));
        }
        group.clear();
        groupIsString = false;
        return true;
    };
    for (; i < values.size(); i++) {
        const css_token& t = *values[i];
        if (t.type == litehtml::COMMA) {
            if (!finish()) {
                return std::nullopt;
            }
        } else if (t.type == litehtml::STRING && group.empty()) {
            group = t.str();
            groupIsString = true;
        } else if (t.type == litehtml::IDENT && !groupIsString) {
            group += (group.empty() ? "" : " ") + t.ident();
        } else {
            return std::nullopt;
        }
    }
    if (!finish()) {
        return std::nullopt;
    }
    FontValue out;
    std::string familyText;
    for (const std::string& f : families) {
        familyText += (familyText.empty() ? "" : ", ") + f;
    }
    // A family list this long is no font a widget means; refused, so a saved state's font stays small (V5d final
    // review, C4).
    if (familyText.size() > kMaxFamilyBytes) {
        return std::nullopt;
    }
    std::string serialized;
    auto part = [&](const std::string& p) { serialized += (serialized.empty() ? "" : " ") + p; };
    if (italic) {
        part("italic");
    } else if (oblique) {
        part("oblique");
    }
    if (smallCaps) {
        part("small-caps");
    }
    if (weight == 700) {
        part("bold");
    } else if (weight != 400) {
        part(std::to_string(weight));
    }
    if (!stretch.empty()) {
        part(stretch);
    }
    part(number(*size) + "px");
    part(familyText);
    out.serialized = std::move(serialized);
    std::string generic;
    for (const std::string& g : generics) {
        generic += (generic.empty() ? "" : ", ") + g;
    }
    out.description.family = generic.empty() ? "sans-serif" : generic;
    out.description.size = litehtml::pixel_t(float(*size));
    out.description.weight = weight;
    out.description.style = italic || oblique ? litehtml::font_style_italic : litehtml::font_style_normal;
    return out;
}

} // namespace wr::canvas
