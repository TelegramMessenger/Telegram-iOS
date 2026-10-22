// What native work costs, in QuickJS work units (quickjs-ng change 2): the same units every JS limit counts. The rates
// are pinned by WorkCostTests (a native unit costs no more wall time than a JS unit at the reference rate).
#pragma once

#include <cstdint>

#include "quickjs.h"

namespace wr::work {

/// Every binding call: today's sandbox host-call base.
inline constexpr uint64_t kBindingCall = 50;
/// A node a tree walk visits.
inline constexpr uint64_t kNodeVisit = 2;
/// One compound selector tested against one element.
inline constexpr uint64_t kSelectorTest = 4;
/// One simple selector of a compound evaluated against one element, on top of the compound's kSelectorTest: a compound
/// of k simples that all succeed (`:defined` repeated) does k evaluations for one compound test.
inline constexpr uint64_t kSimpleSelectorTest = 1;
/// A selector token litehtml's componentizer copies once more for each block (function, (), [] or {}) it is nested in:
/// a CSS token is copyable but not movable, so every finished block is deep-copied into its parent. Charged per unit
/// of the tokens' summed nesting depth, before the componentizer runs.
inline constexpr uint64_t kComponentNesting = 1;
/// One block or function the componentizer builds (a token holding a vector of its own, copied with it).
inline constexpr uint64_t kComponentBlock = 8;
/// One byte of markup parsed by script (innerHTML, outerHTML, insertAdjacentHTML).
inline constexpr uint64_t kParseByte = 5;
/// Four bytes of markup serialized.
inline constexpr uint64_t kSerializeFourBytes = 1;
/// Eight UTF-16 units compared or scanned: QuickJS's JS_WORK_SCAN_SHIFT rate, which its own `===`, string search and
/// atom hashing charge (quickjs-ng change 2).
inline constexpr uint64_t kScanEightUnits = 1;
static_assert(JS_WORK_SCAN_SHIFT == 3, "kScanEightUnits is one unit per eight, QuickJS's scan rate");

// The render layer (M1c plan, Ruling 9). Uncalibrated: rate calibration is not a goal (M1c Global Constraints, "Work"),
// only that every path charges before its work.
/// A DOM node the render build visits.
inline constexpr uint64_t kRenderNode = 4;
/// An attribute the render build reads, on top of the chargeScan of its value.
inline constexpr uint64_t kRenderAttribute = 2;
/// A UTF-8 byte of CSS handed to litehtml's parser: a `<style>` sheet or a `style` attribute.
inline constexpr uint64_t kCssByte = 1;
/// An ICU formatter, rules or collator opened on an Intl cache miss (V5b plan): ICU loads its locale data for it.
inline constexpr uint64_t kIntlOpen = 2000;
/// Eight UTF-16 units ICU case-maps for a language with case rules of its own (toLocaleUpperCase('tr'), v0.1.1 plan,
/// Task 10), on top of the copy's scan; WorkCostTests holds it.
inline constexpr uint64_t kCaseMapEightUnits = 1;
/// A UTF-16 unit of a run the host places carets for (RenderHost::caretOffsets: on iOS CoreText's caret enumeration
/// over the line it draws, or the simple shaper's), for the selectable text export; charged before the host is asked.
/// WRSessionTests' testTheSelectableExportCostsNoMorePerUnitThanJS holds it.
inline constexpr uint64_t kCaretUnit = 3;
/// A box litehtml lays out and paints, pre-charged before render() (nothing charges inside a litehtml callback).
inline constexpr uint64_t kLayoutBox = 8;
/// Canvas 2D (V5d plan, Task 3): per 64 canvas pixels an op may touch (its bounds clipped to the bitmap).
inline constexpr uint64_t kCanvasSixtyFourPixels = 1;
/// A record of the render journal (Task 6).
inline constexpr uint64_t kJournalEntry = 2;
/// A layout query (CSSOM View: getBoundingClientRect, offsetHeight, …), on top of the flush it may make. V3 plan, Task 3.
inline constexpr uint64_t kLayoutQuery = 100;
/// What one task's layout queries may spend, their flushes included, before the widget stops with
/// StopReason::LayoutQuery: sdk-v1 §2's "Layout query limit exceeded" (queries blocking the renderer for more than
/// max(slice, 100 ms) in one task) as a budget of work, about 100 ms at the cost suite's reference rate. The queries'
/// work also counts toward the task's own budget.
inline constexpr uint64_t kLayoutQueryBudget = 10'000'000;
/// Resize Observer: the rounds of delivery one rendering update makes (deliver, lay out, gather) before it reports
/// "ResizeObserver loop completed with undelivered notifications." and leaves the rest for the next one (V3b, Task 2).
inline constexpr uint64_t kResizeObserverRounds = 4;
/// matchMedia: the longest query parsed (UTF-8 bytes). litehtml's tokenizer allocates outside the memory limit, so a
/// longer query is refused before it is copied: it reads as "not all" (the V3b review's C2; parseSelectors' cap).
inline constexpr size_t kMaxMediaQueryBytes = 16384;

} // namespace wr::work

namespace wr {

/// Charges native work; throws Thrown when the budget stops the widget (the interrupt is pending).
void charge(JSContext* ctx, uint64_t units);

/// Charges a scan or comparison of `codeUnits` UTF-16 units: work::kScanEightUnits per eight, rounded down (a remainder
/// under eight is part of the visit or call the scan belongs to). Every native loop over a string's characters charges
/// through this, before it runs when its length is known. Throws Thrown as charge() does.
inline void chargeScan(JSContext* ctx, uint64_t codeUnits) {
    if (codeUnits >= 8) {
        charge(ctx, codeUnits / 8 * work::kScanEightUnits);
    }
}

} // namespace wr
