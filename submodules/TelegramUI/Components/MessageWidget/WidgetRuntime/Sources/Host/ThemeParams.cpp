#include "Sources/Host/ThemeParams.h"

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

} // namespace

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

std::string themeRootDeclarations(const ThemeParams& params, Theme theme) {
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
    return out;
}

} // namespace wr
