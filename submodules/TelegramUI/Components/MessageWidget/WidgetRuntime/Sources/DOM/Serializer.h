// HTML's fragment serialization algorithm (https://html.spec.whatwg.org/multipage/parsing.html#serialising-html-fragments),
// without shadow roots. Iterative: a tree of any depth serializes in constant native stack.
#pragma once

#include "Sources/DOM/Node.h"

namespace wr {

/// The algorithm run on `node`: the serialization of its children (a template's contents for a template; nothing for a
/// void element). innerHTML's getter.
String serializeChildren(JSContext* ctx, Node& node);
/// The serialization of `node` itself, as the algorithm writes a child of a fictional parent: outerHTML's getter.
String serializeOuter(JSContext* ctx, Node& node);

} // namespace wr
