// The parser's gumbo-facing internals, shared by Parser.cpp, MarkupMembers.cpp and the tests: gumbo's options for a
// ParseLimits, the script markup cap, and the transient-heap bound they imply. DOM.h does not include it, so gumbo's
// types stay out of the public Parser.h.
#pragma once

#include <cstddef>
#include <cstdint>

#include "Sources/DOM/Parser.h"
#include "gumbo.h"

namespace wr {

/// The longest script-parsed markup accepted (the innerHTML and outerHTML setters, insertAdjacentHTML), in UTF-16
/// units. A documented divergence (MarkupMembers.cpp); it bounds the per-input-byte terms of transientHeapBound.
inline constexpr uint32_t kMaxScriptMarkupUnits = 1u << 20; // 1,048,576

/// What gumbo stores for one UTF-16 unit of script markup, at most: a BMP character is 3 UTF-8 bytes, a NUL becomes a
/// 3-byte U+FFFD, a surrogate pair is 4 bytes for 2 units, and no character reference grows past 6 bytes for 5.
inline constexpr size_t kMaxDecodedBytesPerUnit = 3;

/// gumbo's options for a document parse under `limits` (parseFragment adds the fragment context).
GumboOptions optionsFor(const ParseLimits& limits);

/// The terms of the transient-heap bound (derived in Parser.cpp, at transientHeapTerms): the most nodes, attributes and
/// attribute-string bytes the tree can hold when a parse stops, and the bound on the system heap gumbo holds at once.
struct TransientHeapTerms {
    size_t nodes;
    size_t attributes;
    size_t attributeBytes;
    size_t bytes;
};

/// The terms for markup whose decoded text (what gumbo stores: UTF-8, a NUL or invalid byte becoming a 3-byte U+FFFD)
/// is at most `decodedInputBytes`, under `limits`. For script markup pass kMaxDecodedBytesPerUnit x its UTF-16
/// length; for a document of n bytes, 3 x n.
TransientHeapTerms transientHeapTerms(const ParseLimits& limits, size_t decodedInputBytes);

/// The most system heap gumbo can hold at once for such markup: transientHeapTerms(...).bytes.
inline size_t transientHeapBound(const ParseLimits& limits, size_t decodedInputBytes) {
    return transientHeapTerms(limits, decodedInputBytes).bytes;
}

} // namespace wr
