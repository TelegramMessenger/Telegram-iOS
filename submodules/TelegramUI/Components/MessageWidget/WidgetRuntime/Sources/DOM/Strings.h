// The string rules the DOM's and HTML's algorithms share (Infra's ASCII operations, the DOM's name checks).
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "Sources/Support/Allocator.h"
#include "Sources/Support/Values.h"

namespace wr {

inline bool isASCIIWhitespace(char16_t c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

/// `s` with A-Z mapped to a-z (Infra "ASCII lowercase"): `s` itself when it has none.
String asciiLowercase(JSContext* ctx, const String& s);
/// `s` with a-z mapped to A-Z (Infra "ASCII uppercase"): `s` itself when it has none.
String asciiUppercase(JSContext* ctx, const String& s);
/// Tokens separated by ASCII whitespace, empty ones dropped (DOM "ordered set parser" before deduplication). A
/// transient list, a constant multiple of `s`, which is already in JS memory (M1a plan, ruling 5).
std::vector<String> splitOnASCIIWhitespace(JSContext* ctx, const String& s);
/// A token of a string, as code units [start, end).
struct TokenRange {
    uint32_t start;
    uint32_t end;
};
/// DOM's "ordered set parser": `s`'s ASCII-whitespace-separated tokens in order of first occurrence, each distinct
/// token once (exact code units). Worst-case O(n log n): a stable merge sort of the tokens' indices, then each later
/// duplicate dropped, so no input (a hash collision, say) makes it quadratic. The lists are counted (JSAllocator).
Vector<TokenRange> orderedSetTokens(JSContext* ctx, const String& s);
/// HTML "strip and collapse ASCII whitespace".
String stripAndCollapseASCIIWhitespace(JSContext* ctx, const String& s);
/// "valid attribute local name" (DOM, 2025): non-empty, no ASCII whitespace, NUL, '/', '=' or '>'.
bool isValidAttributeLocalName(JSContext* ctx, const String& s);
/// "valid namespace prefix" (DOM, 2025): non-empty, no ASCII whitespace, NUL, '/' or '>'.
bool isValidNamespacePrefix(JSContext* ctx, const String& s);
/// Whether the qualified name `prefix` ':' `localName` is `name`, compared in place.
bool qualifiedNameIs(JSContext* ctx, JSAtom prefix, JSAtom localName, const String& name);
/// `s` in UTF-8 for an error message: at most 160 bytes, cut at a character boundary and then marked with '…'. QuickJS
/// keeps 255 bytes of a DOMException's message, cut wherever the byte count ends: converting more of a long name made
/// bytes no one saw, and a cut inside a character. 160 leaves the longest message's own text (55 bytes) whole.
/// Selectors quote the same way (Selectors.cpp).
std::string quotedForMessage(const String& s);

} // namespace wr
