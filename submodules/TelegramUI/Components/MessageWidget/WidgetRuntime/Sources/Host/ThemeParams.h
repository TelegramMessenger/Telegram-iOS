// The chat's palette (SDK v1 §2.3; V2a plan, Task 4): TelegramWidget.themeParams and the root's --tg-theme-* custom
// properties. The policy is the reference's, widget-sandbox v0.1.0 packages/core/src/shared/sdk-policy.ts: THEME_KEYS,
// DEFAULT_THEME_PARAMS, checkThemeParams, completeThemeParams and themeVariables; the client's button tokens (§2.4;
// V2b plan, Task 2), checked against their grammar from the spec's text; and its text tokens (§2.4, v0.1.1), checked as
// the reference's TEXT_VARS check them (v0.1.1 plan, Task 4).
#pragma once

#include <array>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "Sources/Render/RenderHost.h"

namespace wr {

inline constexpr size_t kThemeKeyCount = 15;
/// THEME_KEYS, in its order.
extern const std::array<std::string_view, kThemeKeyCount> kThemeKeys;

/// A palette as the host passes it, (key, value) pairs; checkThemeParams keeps a THEME_KEYS key with a #rrggbb value.
using ThemePalette = std::vector<std::pair<std::string, std::string>>;
/// Every key's value as lowercase #rrggbb, in kThemeKeys order.
using ThemeParams = std::array<std::string, kThemeKeyCount>;

/// completeThemeParams: DEFAULT_THEME_PARAMS for the scheme, overlaid by what checkThemeParams keeps of `palette` (a
/// later pair for the same key wins).
ThemeParams completeThemeParams(const ThemePalette& palette, Theme theme);
/// The client's button tokens (SDK v1 §2.4, WidgetTheme.button); a token not passed keeps the UA stylesheet's default.
struct ThemeButtonTokens {
    std::optional<std::string> bg, text, radius, font, padding, height;
    std::optional<double> pressedOpacity, disabledOpacity;
    bool operator==(const ThemeButtonTokens&) const = default;
};
/// Keeps each token that matches its grammar: `bg` and `text` #rrggbb (lowercased), `radius` a length, `padding` one to
/// four lengths, `height` a length or `auto` (lengths as the reference's LENGTH: `0`, or up to four digits and three
/// decimals in px, em or rem), `font` a font shorthand whose families are all generic, the opacities in [0, 1].
ThemeButtonTokens checkButtonTokens(const ThemeButtonTokens& tokens);
/// The client's message text (SDK v1 §2.4, WidgetTheme.text): the root's font size in CSS px, its unitless line height,
/// and the body's margin; a token not passed or refused is the reference set's (15px, 1.35, 8px 12px).
struct ThemeTextTokens {
    std::optional<double> fontSize, lineHeight;
    std::optional<std::string> padding;
    bool operator==(const ThemeTextTokens&) const = default;
};
/// Keeps each token that matches its grammar: `fontSize` 8–64, rounded to two decimals; `lineHeight` 1–3, rounded to
/// three; `padding` one to four lengths, each `0` or up to four digits and three decimals in px, em or rem.
ThemeTextTokens checkTextTokens(const ThemeTextTokens& tokens);
/// widget-sandbox v0.4.0 (SDK v1 §2.17, §5.12): what the client draws over the widget, in CSS px: the band of the message
/// time at the widget's bottom (`bottom`) and the corner the time takes in it, on its physical side (`cornerRight` in a
/// left-to-right interface, `cornerLeft` in a right-to-left one); the rest 0. All 0 with a caption below the widget, and
/// until the host says.
struct ContentSafeArea {
    double top = 0, right = 0, bottom = 0, left = 0, cornerLeft = 0, cornerRight = 0;
    bool operator==(const ContentSafeArea&) const = default;
};
/// upstream's checkContentSafeArea: each field a finite number within its range (an inset 0–64, a corner 0–200),
/// rounded to two decimals (Math.round(v * 100) / 100); anything else 0.
ContentSafeArea checkContentSafeArea(const ContentSafeArea& area);
/// contentSafeAreaVariables, as declarations for the root: the six --tg-content-safe-area-* of `area` (already checked),
/// always all of them, each !important.
std::string contentSafeAreaRootDeclarations(const ContentSafeArea& area);

/// themeVariables, as declarations for the root: --tg-theme-<key, _ as -> and --tg-color-scheme, then --tg-button-* for
/// each button token passed, then always the three --tg-text-* (all already checked), each !important.
std::string themeRootDeclarations(const ThemeParams& params, Theme theme, const ThemeButtonTokens& tokens = {},
                                  const ThemeTextTokens& text = {});

} // namespace wr
