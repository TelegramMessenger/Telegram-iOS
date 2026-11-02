// CSS Syntax's component values from a string (V5c plan, Task 2): the preprocessing, litehtml's tokenizer and its
// componentizer, behind the caps the selector parser established (Selectors.cpp, M1b ruling 6). Shared by the selector
// parser and CSS.supports.
#pragma once

#include <array>
#include <climits>
#include <cstdint>
#include <optional>
#include <string>

#include <litehtml/css_parser.h>
#include <litehtml/css_tokenizer.h>

#include "Sources/Support/Values.h"

namespace wr::css {

/// Blocks (functions and brackets) nested past this are refused: the componentizer recurses once per block.
inline constexpr int kMaxBracketDepth = 64;
/// Ruling 6's length cap, in UTF-16 units, checked on the string's length before anything is converted or allocated.
/// It bounds the parse's transient C++ heap, which is outside the widget's memory limit (ruling 5). A unit is at most 3
/// UTF-8 bytes, and the worst peak measured is 545 bytes of heap per UTF-8 byte (a run of one-character tokens just
/// past a power of two, where the token vectors' growth slack is largest; method and table in the Task 17 report), so
/// the bound is 16,384 x 3 x 545 = 26.8 MB. A unit makes at most one token, so the worst per unit is the same 545 B
/// (16,384 x 545 = 8.9 MB); the largest peak measured at the cap itself is 5.8 MB.
inline constexpr uint32_t kMaxSelectorUnits = 16384;
static_assert(uint64_t(kMaxSelectorUnits) * 3 < uint64_t(INT_MAX), "litehtml's tokenizer indexes its input with int");

/// CSS Syntax's input preprocessing, in UTF-8 for litehtml's tokenizer (which wants valid UTF-8 without NUL): CR, FF
/// and CR LF become LF; NUL and lone surrogates become U+FFFD.
/// `limit`: convert only the first that many units.
std::string cssInput(const String& text, uint32_t limit = UINT32_MAX);

/// What litehtml's componentizer will build from a token stream.
struct BlockShape {
    /// Nesting past the cap: the componentizer recurses once per block, so it must not run.
    bool tooDeep = false;
};

/// The walk follows the componentizer's rules exactly: a function or an opening bracket opens a block; a closing token
/// closes only the innermost block, and only when it is that block's own kind (any other is an ordinary token inside
/// it); the end of the input closes every block. Stops at the first block past the cap.
BlockShape blockShape(const litehtml::css_token_vector& tokens);

/// `text`'s component values: nullopt past kMaxSelectorUnits (refused on the length alone, before anything is
/// converted or allocated) or kMaxBracketDepth.
std::optional<litehtml::css_token_vector> componentValues(JSContext* ctx, const String& text);

} // namespace wr::css
