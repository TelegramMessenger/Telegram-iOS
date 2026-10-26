// The canvas's CSS values (V5d plan, Task 3): colours (fillStyle, strokeStyle, shadowColor, addColorStop) and the
// `font` shorthand, parsed with litehtml's CSS tokenizer and colour parser as the document's CSS is, and serialized
// as HTML says the 2D context reads them back.
#pragma once

#include <optional>
#include <string>

#include <litehtml/font_description.h>

#include "Sources/Canvas/CanvasOps.h"
#include "Sources/Support/Values.h"

namespace wr::canvas {

/// A CSS <color> (one component value, whitespace around it allowed); `currentcolor` is opaque black, as for a canvas
/// whose element has no computed colour here, and light-dark() takes its light branch. nullopt when it is not one.
std::optional<Color> parseColor(JSContext* ctx, const String& text);
/// HTML's "serialization of a color": `#rrggbb` when opaque, else `rgba(r, g, b, a)` with the shortest alpha that maps
/// back to the same byte.
std::string serializeColor(const Color& color);

/// A canvas `font` value: the CSS `font` shorthand ([style] [variant] [weight] [stretch] size [/ line-height] family),
/// sizes relative to the canvas default of 10px, line-height ignored as HTML says. Profile 1 keeps generic families only
/// (D3b): the family list keeps its generic families, and a list without one falls back to sans-serif.
struct FontValue {
    /// What `font` reads back: [italic|oblique] [small-caps] [bold|<weight>] <size>px <family as given>.
    std::string serialized;
    litehtml::font_description description;
};
/// nullopt when `text` is not a font shorthand (the setter then ignores it). A system font keyword (`caption`, `menu`,
/// …) is refused too, and so is a family list longer than kMaxFamilyBytes.
inline constexpr size_t kMaxFamilyBytes = 1024;
std::optional<FontValue> parseFont(JSContext* ctx, const String& text);

/// A CSS <length> (letterSpacing, wordSpacing): its serialization (`2px`, `0.5em`), nullopt when it is not one.
std::optional<std::string> serializedLength(JSContext* ctx, const String& text);

} // namespace wr::canvas
