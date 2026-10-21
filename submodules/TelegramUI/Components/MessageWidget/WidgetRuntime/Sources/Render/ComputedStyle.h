// CSSOM's resolved values for getComputedStyle (V3 plan, Task 4), from what litehtml computed for an element after
// layout: keywords as CSS writes them, colors as rgb()/rgba(), lengths in px (used values from the render box where
// CSSOM resolves to them: width, height, padding, the horizontal margins). A property the renderer does not model
// reads its initial value when that is a constant (direction, user-select, touch-action, quotes), else "".
#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace litehtml {
class element;
}

namespace wr {

enum class PseudoElement : uint8_t { None, Before, After };

/// The properties a computed declaration lists (its length and items), in order.
const std::vector<std::string>& computedPropertyNames();

/// The resolved value of `name` (lower-cased, or a custom property as written) for `element`, or for its
/// pseudo-element: a missing pseudo-element reads its host's inherited values, with `content: none`.
std::string computedValue(litehtml::element& element, std::string_view name, PseudoElement pseudo);

/// `::before` / `:before` and the like (ASCII case-insensitive), or None for anything else, empty included.
PseudoElement pseudoElementNamed(std::string_view name);

} // namespace wr
