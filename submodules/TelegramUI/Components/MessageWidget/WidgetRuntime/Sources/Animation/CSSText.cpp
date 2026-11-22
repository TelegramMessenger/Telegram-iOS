#include "Sources/Animation/CSSText.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <optional>
#include <string_view>
#include <unordered_map>

#include <litehtml/css_parser.h>
#include <litehtml/web_color.h>

namespace wr::animation {

namespace {

bool isSpace(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f'; }
bool isDigit(char c) { return c >= '0' && c <= '9'; }
bool isAlpha(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }

int hexValue(char c) {
    if (isDigit(c)) {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1;
}

bool parseHex(std::string_view hex, double rgba[4]) {
    for (char c : hex) {
        if (hexValue(c) < 0) {
            return false;
        }
    }
    switch (hex.size()) {
    case 3:
    case 4:
        for (size_t i = 0; i < hex.size(); i++) {
            rgba[i] = hexValue(hex[i]) * 17;
        }
        rgba[3] = hex.size() == 4 ? rgba[3] / 255 : 1;
        return true;
    case 6:
    case 8:
        for (size_t i = 0; i < hex.size() / 2; i++) {
            rgba[i] = hexValue(hex[2 * i]) * 16 + hexValue(hex[2 * i + 1]);
        }
        rgba[3] = hex.size() == 8 ? rgba[3] / 255 : 1;
        return true;
    default:
        return false;
    }
}

/// The numbers inside `rgb(...)`, split at commas, spaces and `/`; `%` divides by 100.
std::vector<double> components(std::string_view inner, bool percent[3]) {
    std::vector<double> out;
    std::string current;
    auto flush = [&] {
        if (current.empty()) {
            return;
        }
        const bool pct = current.back() == '%';
        if (pct) {
            current.pop_back();
        }
        if (auto v = parseNumber(current)) {
            out.push_back(pct ? *v / 100 : *v);
            if (out.size() <= 3) {
                percent[out.size() - 1] = pct;
            }
        }
        current.clear();
    };
    for (char c : inner) {
        if (c == ',' || c == '/' || isSpace(c)) {
            flush();
        } else {
            current.push_back(c);
        }
    }
    flush();
    return out;
}

void appendRGBA(const double c[4], std::string& out) {
    out += "rgba(";
    out += formatNumber(c[0]);
    out += ", ";
    out += formatNumber(c[1]);
    out += ", ";
    out += formatNumber(c[2]);
    out += ", ";
    out += formatNumber(c[3]);
    out += ")";
}

/// `text` as one CSS colour through litehtml's parser (its named table, hsl()), componentized as litehtml's own style
/// values are; nullopt for anything else and for `currentcolor`. The caller hands it a word or a function with no nested
/// parentheses, so the componentizer never recurses.
std::optional<litehtml::web_color> litehtmlColor(std::string_view text) {
    const litehtml::css_token_vector values =
        litehtml::normalize(std::string(text), litehtml::f_componentize | litehtml::f_remove_whitespace);
    const litehtml::css_token* only = nullptr;
    for (const auto& token : values) {
        if (token.type == litehtml::WHITESPACE) {
            continue;
        }
        if (only) {
            return std::nullopt;
        }
        only = &token;
    }
    litehtml::web_color color;
    if (!only || !litehtml::parse_color(*only, color, nullptr) || color.is_current_color) {
        return std::nullopt;
    }
    return color;
}

/// litehtml's named colours (web_color.cpp's g_def_colors, lowercased). A word is looked up here first, so only a colour
/// name reaches litehtml, once per name per process: every identifier of a value used to go through litehtml's
/// tokenizer and its 146-entry scan (final review I9).
constexpr std::string_view kColorNames[] = {
    "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige", "bisque", "black", "blanchedalmond", "blue",
    "blueviolet", "brown", "burlywood", "cadetblue", "chartreuse", "chocolate", "coral", "cornflowerblue", "cornsilk",
    "crimson", "cyan", "darkblue", "darkcyan", "darkgoldenrod", "darkgray", "darkgreen", "darkgrey", "darkkhaki",
    "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred", "darksalmon", "darkseagreen",
    "darkslateblue", "darkslategray", "darkslategrey", "darkturquoise", "darkviolet", "deeppink", "deepskyblue",
    "dimgray", "dimgrey", "dodgerblue", "firebrick", "floralwhite", "forestgreen", "fuchsia", "gainsboro", "ghostwhite",
    "gold", "goldenrod", "gray", "green", "greenyellow", "grey", "honeydew", "hotpink", "ivory", "khaki", "lavender",
    "lavenderblush", "lawngreen", "lemonchiffon", "lightblue", "lightcoral", "lightcyan", "lightgoldenrodyellow",
    "lightgray", "lightgreen", "lightgrey", "lightpink", "lightsalmon", "lightseagreen", "lightskyblue",
    "lightslategray", "lightslategrey", "lightsteelblue", "lightyellow", "lime", "limegreen", "linen", "magenta",
    "maroon", "mediumaquamarine", "mediumblue", "mediumorchid", "mediumpurple", "mediumseagreen", "mediumslateblue",
    "mediumspringgreen", "mediumturquoise", "mediumvioletred", "midnightblue", "mintcream", "mistyrose", "moccasin",
    "navajowhite", "navy", "oldlace", "olive", "olivedrab", "orange", "orangered", "orchid", "palegoldenrod",
    "palegreen", "paleturquoise", "palevioletred", "papayawhip", "peachpuff", "peru", "pink", "plum", "powderblue",
    "purple", "red", "rosybrown", "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen", "seashell", "sienna",
    "silver", "skyblue", "slateblue", "slategray", "slategrey", "snow", "springgreen", "steelblue", "tan", "teal",
    "thistle", "tomato", "transparent", "turquoise", "violet", "wheat", "white", "whitesmoke", "yellow", "yellowgreen"
};

const litehtml::web_color* namedColor(std::string_view word) {
    constexpr size_t kLongestName = 20;
    if (word.empty() || word.size() > kLongestName) {
        return nullptr;
    }
    char lower[kLongestName];
    for (size_t i = 0; i < word.size(); i++) {
        lower[i] = char(std::tolower(static_cast<unsigned char>(word[i])));
    }
    static const std::unordered_map<std::string_view, litehtml::web_color>* const table = [] {
        auto* colors = new std::unordered_map<std::string_view, litehtml::web_color>();
        for (std::string_view name : kColorNames) {
            if (std::optional<litehtml::web_color> color = litehtmlColor(name)) {
                colors->emplace(name, *color);
            }
        }
        return colors;
    }();
    auto it = table->find(std::string_view(lower, word.size()));
    return it == table->end() ? nullptr : &it->second;
}

} // namespace

std::string trimmed(std::string_view s) {
    size_t a = 0, b = s.size();
    while (a < b && isSpace(s[a])) {
        a++;
    }
    while (b > a && isSpace(s[b - 1])) {
        b--;
    }
    return std::string(s.substr(a, b - a));
}

std::string lowered(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        c = char(std::tolower(static_cast<unsigned char>(c)));
    }
    return out;
}

bool equalsIgnoringCase(std::string_view a, std::string_view b) {
    if (a.size() != b.size()) {
        return false;
    }
    for (size_t i = 0; i < a.size(); i++) {
        if (std::tolower(static_cast<unsigned char>(a[i])) != std::tolower(static_cast<unsigned char>(b[i]))) {
            return false;
        }
    }
    return true;
}

std::optional<double> parseNumber(std::string_view s) {
    const std::string t = trimmed(s);
    if (t.empty()) {
        return std::nullopt;
    }
    char* end = nullptr;
    const double v = std::strtod(t.c_str(), &end);
    if (end != t.c_str() + t.size() || !std::isfinite(v)) {
        return std::nullopt;
    }
    return v;
}

std::vector<std::string> splitTopLevel(std::string_view text, char separator) {
    std::vector<std::string> parts;
    std::string current;
    int depth = 0;
    char quote = 0;
    bool escaped = false;
    for (char ch : text) {
        if (escaped) {
            escaped = false;
            current.push_back(ch);
            continue;
        }
        if (ch == '\\') {
            escaped = true;
            current.push_back(ch);
            continue;
        }
        if (quote) {
            if (ch == quote) {
                quote = 0;
            }
            current.push_back(ch);
            continue;
        }
        if (ch == '"' || ch == '\'') {
            quote = ch;
        } else if (ch == '(') {
            depth++;
        } else if (ch == ')') {
            depth = std::max(0, depth - 1);
        }
        if (ch == separator && depth == 0) {
            parts.push_back(std::move(current));
            current.clear();
        } else {
            current.push_back(ch);
        }
    }
    if (!current.empty()) {
        parts.push_back(std::move(current));
    }
    return parts;
}

std::string normalizeColors(std::string_view text) {
    std::string out;
    out.reserve(text.size() + 16);
    size_t i = 0;
    while (i < text.size()) {
        const char c = text[i];
        if (c == '#') {
            size_t j = i + 1;
            while (j < text.size() && hexValue(text[j]) >= 0) {
                j++;
            }
            double rgba[4];
            if (parseHex(text.substr(i + 1, j - i - 1), rgba)) {
                appendRGBA(rgba, out);
                i = j;
                continue;
            }
        }
        if (isAlpha(c) && (i == 0 || !(isAlpha(text[i - 1]) || isDigit(text[i - 1]) || text[i - 1] == '-'))) {
            size_t j = i;
            while (j < text.size() && (isAlpha(text[j]) || text[j] == '-')) {
                j++;
            }
            const std::string_view word = text.substr(i, j - i);
            if (j < text.size() && text[j] == '(') {
                const size_t close = text.find(')', j);
                // A nested parenthesis means it is not one of these colour functions.
                const bool flat = close != std::string_view::npos && text.substr(j + 1, close - j - 1).find('(') == std::string_view::npos;
                if (flat && (equalsIgnoringCase(word, "rgb") || equalsIgnoringCase(word, "rgba"))) {
                    bool pct[3] = {false, false, false};
                    std::vector<double> v = components(text.substr(j + 1, close - j - 1), pct);
                    if (v.size() >= 3) {
                        for (int k = 0; k < 3; k++) {
                            if (pct[k]) {
                                v[k] *= 255;
                            }
                        }
                        const double rgba[4] = {v[0], v[1], v[2], v.size() > 3 ? v[3] : 1};
                        appendRGBA(rgba, out);
                        i = close + 1;
                        continue;
                    }
                } else if (flat && (equalsIgnoringCase(word, "hsl") || equalsIgnoringCase(word, "hsla"))) {
                    if (auto color = litehtmlColor(text.substr(i, close + 1 - i))) {
                        const double rgba[4] = {double(color->red), double(color->green), double(color->blue), color->alpha / 255.0};
                        appendRGBA(rgba, out);
                        i = close + 1;
                        continue;
                    }
                }
            } else if (const litehtml::web_color* color = namedColor(word)) {
                const double rgba[4] = {double(color->red), double(color->green), double(color->blue), color->alpha / 255.0};
                appendRGBA(rgba, out);
                i = j;
                continue;
            }
            out.append(word);
            i = j;
            continue;
        }
        out.push_back(c);
        i++;
    }
    return out;
}

std::string formatNumber(double value, int digits) {
    if (!std::isfinite(value)) {
        return "0";
    }
    if (value == std::round(value) && std::fabs(value) < 1e9) {
        return std::to_string(static_cast<long long>(value));
    }
    char buffer[64];
    std::snprintf(buffer, sizeof buffer, "%.*f", digits, value);
    std::string s = buffer;
    while (!s.empty() && s.back() == '0') {
        s.pop_back();
    }
    if (!s.empty() && s.back() == '.') {
        s.pop_back();
    }
    if (s == "-0") {
        s = "0";
    }
    return s;
}

} // namespace wr::animation
