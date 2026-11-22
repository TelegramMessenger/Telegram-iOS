// UAX #9, the Unicode Bidirectional Algorithm (rules X1–X10, W1–W7, N0–N2, I1–I2 and L1), over the bidi classes and
// paired brackets of the system ICU's uchar.h: the levels WidgetContainer::bidi_levels answers litehtml's line
// reordering with (twidget edit 47). ICU's own implementation (ubidi_*) is not public API on iOS (Sources/Host/ICU.h).
#pragma once

#include <cstdint>
#include <string_view>
#include <vector>

namespace wr::bidi {

/// The resolved embedding level of every UTF-16 unit of `text`, a paragraph at `paragraphLevel` (0 left to right, 1
/// right to left) laid out as one line, through rule L1. A character X9 removes (an embedding or override control, a
/// boundary neutral) gets the level of the character before it, or the paragraph's at the start; a surrogate pair's
/// units share their character's; an unpaired surrogate is U+FFFD. A paragraph separator inside `text` ends its
/// paragraph, and the next one starts at the same level. Linear in the length: bracket pairs nest at most 63 deep
/// (BD16), and each pair scans only what it encloses.
std::vector<uint8_t> levels(std::u16string_view text, uint8_t paragraphLevel);

/// Whether rule X9 removes the character `c`: its level is then the preceding character's.
bool isRemovedByX9(uint32_t c);

} // namespace wr::bidi
