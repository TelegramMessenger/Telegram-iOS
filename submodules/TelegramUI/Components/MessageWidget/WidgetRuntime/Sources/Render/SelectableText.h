// The selectable text (widget-sandbox v0.1.1, sdk-v1 §2.4, §5.10): the text of a published layout the client lets the
// reader select (its effective user-select is `text`, ComputedStyle.h's selectsText), as one UTF-16 string in document
// order, with where each run of it is drawn and which Text node it shows.
//
// What is selectable: a piece of a Text node (generated content, list markers and the ellipsis are not; Chromium does
// not select generated content) that is drawn (visibility: hidden draws nothing; opacity: 0 draws) and that its
// ancestors' overflow clips and the widget's clip at its visible height do not wholly hide. What it reads as: the drawn
// text (text-transform applied, a piece cut at an ellipsis only its drawn part); collapsible white space between two
// runs is one space, a <br>, a preserved newline and a change of block container are one newline, never at the start
// and never two in a row. Separators belong to no run.
//
// The export is the host's work, not the widget's: it runs no script and flushes nothing, so it never stops, fails or
// demotes a widget. The rendered text's caps bound it (the CPU-clock limits design).
#pragma once

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <litehtml/types.h>

#include "Sources/Render/HitTest.h"

namespace litehtml {
class element;
}

namespace wr {

struct SelectableRun {
    /// Its first UTF-16 unit in SelectableText::text, and how many.
    uint32_t start = 0;
    uint32_t length = 0;
    /// Its layout box, document CSS px, before `transform`.
    RenderBox box;
    /// length + 1 x offsets from box.x, one per UTF-16 boundary, where they are drawn (descending right to left).
    std::vector<float> carets;
    /// a b c d tx ty: box space → document, its ancestors' transforms composed as transformRects composes them.
    double transform[6] = {1, 0, 0, 1, 0, 0};
    /// The Text node's NodeKey (stable across patches), and the UTF-16 offset of `start` in that node's drawn text.
    uint64_t node = 0;
    uint32_t nodeOffset = 0;
};

struct SelectableText {
    std::u16string text;
    /// In `text` order.
    std::vector<SelectableRun> runs;
};

/// What the export reads.
struct SelectableTextSource {
    /// The published document's root element.
    const litehtml::element* root = nullptr;
    /// A text piece's Text node's NodeKey; 0 when the piece shows no Text node (generated content).
    std::function<uint64_t(const litehtml::element&)> keyOf;
    /// RenderHost::caretOffsets for litehtml's font handle.
    std::function<std::vector<float>(litehtml::uint_ptr font, std::string_view utf8)> caretOffsets;
    double visibleHeight = 0;
};

SelectableText exportSelectableText(const SelectableTextSource& source);

} // namespace wr
