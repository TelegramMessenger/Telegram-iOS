// The chat's palette (SDK v1 §2.3; V2a plan, Task 4): TelegramWidget.themeParams and the root's --tg-theme-* custom
// properties. The policy is the reference's, widget-sandbox v0.1.0 packages/core/src/shared/sdk-policy.ts: THEME_KEYS,
// DEFAULT_THEME_PARAMS, checkThemeParams, completeThemeParams and themeVariables; and the client's button tokens (§2.4;
// V2b plan, Task 2), checked against their grammar from the spec's text.
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
/// four lengths, `height` a length or `auto` (lengths in px, em or rem), `font` a font shorthand whose families are all
/// generic, the opacities in [0, 1].
ThemeButtonTokens checkButtonTokens(const ThemeButtonTokens& tokens);
/// themeVariables, as declarations for the root: --tg-theme-<key, _ as -> and --tg-color-scheme, then --tg-button-* for
/// each token passed (already checked), each !important.
std::string themeRootDeclarations(const ThemeParams& params, Theme theme, const ThemeButtonTokens& tokens = {});

} // namespace wr
