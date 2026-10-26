// structuredClone (V5a plan, Task 4; HTML §2.7 "Safe passing of structured data").
#pragma once

#include <cstddef>

#include "Sources/Support/Values.h"

namespace wr {

/// Nesting deeper than this is a DataCloneError rather than native recursion without bound.
inline constexpr size_t kMaxCloneDepth = 1000;

/// HTML's StructuredSerializeInternal and StructuredDeserialize in one pass, within this realm.
Value structuredCloneValue(JSContext* ctx, JSValueConst value);

} // namespace wr
