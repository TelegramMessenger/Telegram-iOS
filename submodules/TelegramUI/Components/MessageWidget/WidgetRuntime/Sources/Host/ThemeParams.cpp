#include "Sources/Host/ThemeParams.h"

#include <cmath>
#include <cstdio>
#include <vector>

#include "Sources/Host/Profile.h"

namespace wr {

const std::array<std::string_view, kThemeKeyCount> kThemeKeys = {
    "bg_color",
    "text_color",
    "hint_color",
    "link_color",
    "button_color",
    "button_text_color",
    "secondary_bg_color",
    "accent_text_color",
    "subtitle_text_color",
    "destructive_text_color",
    "section_bg_color",
    "section_header_text_color",
    "section_separator_color",
    "header_bg_color",
    "bottom_bar_bg_color",
};

namespace {

// DEFAULT_THEME_PARAMS, in kThemeKeys order.
constexpr std::array<std::string_view, kThemeKeyCount> kLightDefaults = {
    "#ffffff", "#000000", "#707579", "#3390ec", "#3390ec", "#ffffff", "#f4f4f5", "#3390ec",
    "#707579", "#e53935", "#ffffff", "#3390ec", "#e7e7e7", "#ffffff", "#ffffff",
};
constexpr std::array<std::string_view, kThemeKeyCount> kDarkDefaults = {
    "#212121", "#ffffff", "#aaaaaa", "#8774e1", "#8774e1", "#ffffff", "#181818", "#8774e1",
    "#aaaaaa", "#ff595a", "#212121", "#8774e1", "#3d3d3d", "#212121", "#212121",
};

bool isHexDigit(char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

/// /^#[0-9a-fA-F]{6}$/.
bool isHexColor(const std::string& value) {
    if (value.size() != 7 || value[0] != '#') {
        return false;
    }
    for (size_t i = 1; i < value.size(); i++) {
        if (!isHexDigit(value[i])) {
            return false;
        }
    }
    return true;
}

std::string lowercased(std::string value) {
    for (char& c : value) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c - 'A' + 'a');
        }
    }
    return value;
}

std::vector<std::string_view> splitOn(std::string_view text, char separator) {
    std::vector<std::string_view> parts;
    size_t start = 0;
    while (start <= text.size()) {
        const size_t end = text.find(separator, start);
        parts.push_back(text.substr(start, end == std::string_view::npos ? std::string_view::npos : end - start));
        if (end == std::string_view::npos) {
            break;
        }
        start = end + 1;
    }
    return parts;
}

/// A non-negative number: digits, with at most one dot between digits.
bool isNumber(std::string_view text) {
    if (text.empty()) {
        return false;
    }
    bool dot = false;
    bool digit = false;
    for (size_t i = 0; i < text.size(); i++) {
        const char c = text[i];
        if (c >= '0' && c <= '9') {
            digit = true;
        } else if (c == '.' && !dot && i > 0 && i + 1 < text.size()) {
            dot = true;
        } else {
            return false;
        }
    }
    return digit;
}

/// A length in px, em or rem.
bool isLength(std::string_view text) {
    for (std::string_view unit : {"rem", "px", "em"}) {
        if (text.size() > unit.size() && text.substr(text.size() - unit.size()) == unit) {
            return isNumber(text.substr(0, text.size() - unit.size()));
        }
    }
    return false;
}

/// A font shorthand: style and weight keywords or numeric weights, a size (a length, optionally /line-height as a
/// number or a length), then a comma-separated list of generic families.
bool isGenericFont(std::string_view text) {
    const std::vector<std::string_view> words = splitOn(text, ' ');
    size_t i = 0;
    for (; i < words.size(); i++) {
        const std::string_view word = words[i];
        if (word == "normal" || word == "italic" || word == "oblique" || word == "bold" || word == "bolder" || word == "lighter" ||
            word == "small-caps" || (word.size() == 3 && isNumber(word))) {
            continue;
        }
        break;
    }
    if (i >= words.size()) {
        return false;
    }
    const std::string_view size = words[i];
    const size_t slash = size.find('/');
    if (!isLength(size.substr(0, slash))) {
        return false;
    }
    if (slash != std::string_view::npos) {
        const std::string_view lineHeight = size.substr(slash + 1);
        if (!isNumber(lineHeight) && !isLength(lineHeight)) {
            return false;
        }
    }
    std::string families;
    for (size_t j = i + 1; j < words.size(); j++) {
        families += words[j];
    }
    if (families.empty()) {
        return false;
    }
    for (std::string_view family : splitOn(families, ',')) {
        if (family.empty() || !profile::contains(profile::CSSTable::GenericFonts, lowercased(std::string(family)))) {
            return false;
        }
    }
    return true;
}

/// The reference's LENGTH, /^(0|[0-9]{1,4}(\.[0-9]{1,3})?(px|em|rem))$/.
bool isTokenLength(std::string_view text) {
    if (text == "0") {
        return true;
    }
    for (std::string_view unit : {"rem", "px", "em"}) {
        if (text.size() <= unit.size() || text.substr(text.size() - unit.size()) != unit) {
            continue;
        }
        const std::string_view number = text.substr(0, text.size() - unit.size());
        const size_t dot = number.find('.');
        const std::string_view whole = number.substr(0, dot);
        const std::string_view fraction = dot == std::string_view::npos ? std::string_view() : number.substr(dot + 1);
        const auto digits = [](std::string_view part, size_t most) {
            return !part.empty() && part.size() <= most && part.find_first_not_of("0123456789") == std::string_view::npos;
        };
        return digits(whole, 4) && (dot == std::string_view::npos || digits(fraction, 3));
    }
    return false;
}

/// The reference's padding: one to four lengths separated by single spaces.
bool isTokenPadding(std::string_view text) {
    const std::vector<std::string_view> parts = splitOn(text, ' ');
    if (parts.empty() || parts.size() > 4) {
        return false;
    }
    for (std::string_view part : parts) {
        if (!isTokenLength(part)) {
            return false;
        }
    }
    return true;
}

/// The reference's bounded(): a finite number in [min, max], rounded to `decimals`.
std::optional<double> bounded(double value, double min, double max, int decimals) {
    if (!std::isfinite(value) || value < min || value > max) {
        return std::nullopt;
    }
    const double factor = std::pow(10.0, decimals);
    return std::round(value * factor) / factor;
}

/// The shortest decimal form of a value already rounded to `decimals`, as JavaScript's String(number) writes it.
std::string formatRounded(double value, int decimals) {
    char buffer[32];
    std::snprintf(buffer, sizeof(buffer), "%.*f", decimals, value);
    std::string text = buffer;
    if (text.find('.') != std::string::npos) {
        while (text.back() == '0') {
            text.pop_back();
        }
        if (text.back() == '.') {
            text.pop_back();
        }
    }
    return text;
}

bool isOpacity(double value) {
    return std::isfinite(value) && value >= 0 && value <= 1;
}

std::string formatOpacity(double value) {
    char buffer[32];
    std::snprintf(buffer, sizeof(buffer), "%.3g", value);
    return buffer;
}

} // namespace

ThemeButtonTokens checkButtonTokens(const ThemeButtonTokens& tokens) {
    ThemeButtonTokens checked;
    if (tokens.bg && isHexColor(*tokens.bg)) {
        checked.bg = lowercased(*tokens.bg);
    }
    if (tokens.text && isHexColor(*tokens.text)) {
        checked.text = lowercased(*tokens.text);
    }
    if (tokens.radius && isTokenLength(*tokens.radius)) {
        checked.radius = tokens.radius;
    }
    if (tokens.padding && isTokenPadding(*tokens.padding)) {
        checked.padding = tokens.padding;
    }
    if (tokens.height && (*tokens.height == "auto" || isTokenLength(*tokens.height))) {
        checked.height = tokens.height;
    }
    if (tokens.font && isGenericFont(*tokens.font)) {
        checked.font = tokens.font;
    }
    if (tokens.pressedOpacity && isOpacity(*tokens.pressedOpacity)) {
        checked.pressedOpacity = tokens.pressedOpacity;
    }
    if (tokens.disabledOpacity && isOpacity(*tokens.disabledOpacity)) {
        checked.disabledOpacity = tokens.disabledOpacity;
    }
    return checked;
}

ThemeTextTokens checkTextTokens(const ThemeTextTokens& tokens) {
    ThemeTextTokens checked;
    if (tokens.fontSize) {
        checked.fontSize = bounded(*tokens.fontSize, 8, 64, 2);
    }
    if (tokens.lineHeight) {
        checked.lineHeight = bounded(*tokens.lineHeight, 1, 3, 3);
    }
    if (tokens.padding && isTokenPadding(*tokens.padding)) {
        checked.padding = tokens.padding;
    }
    return checked;
}

ThemeParams completeThemeParams(const ThemePalette& palette, Theme theme) {
    const auto& defaults = theme == Theme::Dark ? kDarkDefaults : kLightDefaults;
    ThemeParams params;
    for (size_t i = 0; i < kThemeKeyCount; i++) {
        params[i] = std::string(defaults[i]);
    }
    for (const auto& [key, value] : palette) {
        if (!isHexColor(value)) {
            continue;
        }
        for (size_t i = 0; i < kThemeKeyCount; i++) {
            if (key == kThemeKeys[i]) {
                std::string lower = value;
                for (char& c : lower) {
                    if (c >= 'A' && c <= 'F') {
                        c = char(c - 'A' + 'a');
                    }
                }
                params[i] = std::move(lower);
                break;
            }
        }
    }
    return params;
}

ContentSafeArea checkContentSafeArea(const ContentSafeArea& area) {
    const auto checked = [](double value, double max) {
        return std::isfinite(value) && value >= 0 && value <= max ? std::round(value * 100) / 100 : 0.0;
    };
    constexpr double kMaxInset = 64;
    constexpr double kMaxCorner = 200;
    ContentSafeArea out;
    out.top = checked(area.top, kMaxInset);
    out.right = checked(area.right, kMaxInset);
    out.bottom = checked(area.bottom, kMaxInset);
    out.left = checked(area.left, kMaxInset);
    out.cornerLeft = checked(area.cornerLeft, kMaxCorner);
    out.cornerRight = checked(area.cornerRight, kMaxCorner);
    return out;
}

std::string contentSafeAreaRootDeclarations(const ContentSafeArea& area) {
    const std::pair<const char*, double> variables[] = {
        {"inset-top", area.top},     {"inset-right", area.right},       {"inset-bottom", area.bottom},
        {"inset-left", area.left},   {"corner-left", area.cornerLeft}, {"corner-right", area.cornerRight},
    };
    std::string out;
    for (const auto& [name, value] : variables) {
        if (!out.empty()) {
            out += ';';
        }
        out += "--tg-content-safe-area-";
        out += name;
        out += ':';
        out += formatRounded(value, 2);
        out += "px !important";
    }
    return out;
}

std::string themeRootDeclarations(const ThemeParams& params, Theme theme, const ThemeButtonTokens& tokens, const ThemeTextTokens& text) {
    std::string out;
    for (size_t i = 0; i < kThemeKeyCount; i++) {
        out += "--tg-theme-";
        for (char c : kThemeKeys[i]) {
            out += c == '_' ? '-' : c;
        }
        out += ':';
        out += params[i];
        out += " !important;";
    }
    out += "--tg-color-scheme:";
    out += theme == Theme::Dark ? "dark" : "light";
    out += " !important";
    const auto add = [&](std::string_view name, const std::optional<std::string>& value) {
        if (value) {
            out += ";--tg-button-";
            out += name;
            out += ':';
            out += *value;
            out += " !important";
        }
    };
    add("bg", tokens.bg);
    add("text", tokens.text);
    add("radius", tokens.radius);
    add("font", tokens.font);
    add("padding", tokens.padding);
    add("height", tokens.height);
    add("pressed-opacity", tokens.pressedOpacity ? std::optional<std::string>(formatOpacity(*tokens.pressedOpacity)) : std::nullopt);
    add("disabled-opacity", tokens.disabledOpacity ? std::optional<std::string>(formatOpacity(*tokens.disabledOpacity)) : std::nullopt);
    // DEFAULT_TEXT_TOKENS for a token not passed.
    out += ";--tg-text-font-size:";
    out += text.fontSize ? formatRounded(*text.fontSize, 2) + "px" : "15px";
    out += " !important;--tg-text-line-height:";
    out += text.lineHeight ? formatRounded(*text.lineHeight, 3) : "1.35";
    out += " !important;--tg-text-padding:";
    out += text.padding ? *text.padding : "8px 12px";
    out += " !important";
    return out;
}

} // namespace wr
