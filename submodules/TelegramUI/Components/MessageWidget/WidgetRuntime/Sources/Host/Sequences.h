// WebIDL's sequence conversion for the built-ins that take `any` where the standard has a sequence (V5a plan,
// Tasks 6 and 9): the object's own @@iterator (the runtime's, which a script cannot replace) and its values.
#pragma once

#include <cstdint>
#include <optional>
#include <vector>

#include "Sources/Support/Values.h"

namespace wr {

/// The values of `object` through its @@iterator; nullopt when it has none (undefined or null). A non-object iterator
/// or result is a TypeError naming `what`. At most `limit` values are read: a sequence that has more gives exactly
/// `limit` (so a caller asks for one more than it takes), and its iterator is closed (V5d plan, Task 3: a million-entry
/// setLineDash is not read whole).
std::optional<std::vector<Value>> sequenceValues(JSContext* ctx, JSValueConst object, const char* what, size_t limit = SIZE_MAX);

} // namespace wr
