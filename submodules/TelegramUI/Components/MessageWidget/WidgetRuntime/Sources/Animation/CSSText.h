// Small text helpers the animation code reads values with (V5e plan, Task 1), ported from twidget's `css.{h,cpp}`
// (PROVENANCE.md). None of them is a CSS parser: they read keyframe values as text, as twidget's animation engine did.
#pragma once

#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace wr::animation {

/// `s` without leading and trailing ASCII whitespace.
std::string trimmed(std::string_view s);
/// ASCII lowercase.
std::string lowered(std::string_view s);
bool equalsIgnoringCase(std::string_view a, std::string_view b);
/// A finite double from the whole of `s` (trimmed), or nullopt.
std::optional<double> parseNumber(std::string_view s);
/// Splits at `separator` outside parentheses and quotes (`a, rgb(1,2,3)` is two parts).
std::vector<std::string> splitTopLevel(std::string_view text, char separator);
/// Rewrites every colour in `text` as `rgba(r, g, b, a)`, so two values interpolate number by number: `#hex` and
/// `rgb()`/`rgba()` exactly, as twidget did; named colours and `hsl()`/`hsla()` through litehtml's colour parser.
/// `currentcolor`, and colour functions litehtml does not parse (`hwb()`, `lab()`, …), stay as written.
std::string normalizeColors(std::string_view text);
/// Shortest decimal form: integers without a point, at most `digits` fractional digits; a non-finite value is "0".
std::string formatNumber(double value, int digits = 4);

} // namespace wr::animation
