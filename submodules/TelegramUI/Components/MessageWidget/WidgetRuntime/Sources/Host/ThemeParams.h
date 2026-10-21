// The chat's palette (SDK v1 §2.3; V2a plan, Task 4): TelegramWidget.themeParams and the root's --tg-theme-* custom
// properties. The policy is the reference's, widget-sandbox v0.1.0 packages/core/src/shared/sdk-policy.ts: THEME_KEYS,
// DEFAULT_THEME_PARAMS, checkThemeParams, completeThemeParams and themeVariables (without the button tokens, §2.4).
#pragma once

#include <array>
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
/// themeVariables' colours, as declarations for the root: --tg-theme-<key, _ as -> and --tg-color-scheme, each
/// !important.
std::string themeRootDeclarations(const ThemeParams& params, Theme theme);

} // namespace wr
