// NOT VENDORED. Written for Telegram, Task 9c.
//
// **THE AXIS MAP — the single conversion between the editor's `UITextInput` position axis and the
// stock CHARACTER axis the corpus is written in.**
//
// ## What the divergence is, measured
//
// The editor's position axis is SPARSE: it counts the non-renderable structural token slots between
// blocks, so it is not a plain character count. (`TelegramDocumentInputClient.swift:8-10` states
// this in production source, and it predates the input-backend seam.) Measured 2026-08-24 on
// `"Alpha middle omega\nSecond block remains unchanged."` — the initial text of all 24 IME scenarios:
//
//     leaf regions          [1,19) and [21,52)        documentSize 53
//     beginningOfDocument   raw 1        endOfDocument raw 52      (span 51)
//     canonical text        50 characters
//     raw slot 20           NOT RENDERABLE — snaps forward to 21, backward to 19
//
// so the character index of a raw slot is `raw - 1` up to the boundary and `raw - 2` after it.
//
// ## Why this is a MAP and not an excused difference
//
// `selection` is a comparison field of ALL 68 scenarios and 58 of the 68 touch a paragraph boundary
// (measured over the corpus). A named expectation excusing `selection` wherever a boundary exists
// would excuse ~85% of the corpus on a field every scenario compares — an oracle that certifies
// almost nothing while reporting green. A systematic offset is a map.
//
// ## The map, and its residue
//
//     characterIndex(p) = [[input textInRange:(beginningOfDocument … p)] length]
//
// — *how much text lies before this position*, taken through the very projection that produces
// `canonical`. It is exact for stock by construction (for a `UITextView` the prefix length IS
// `-offsetFromPosition:toPosition:`), it needs no Telegram type, and both arms run it unchanged.
//
// **Residue: none.** Over every position the editor can actually reach — enumerated by stepping
// `-positionFromPosition:offset:1`, which snaps past the non-renderable slot — the map is monotone
// AND injective, and it covers every character index exactly once. Pinned by
// `TelegramDifferentialRecorderTests.test_theMapIsMonotoneAndSurjectiveOverEveryPositionTheEditorCanReach`.
// (Raw slots 20 and 21 do share character index 19, but 20 is not renderable and no caret can sit
// there, so no reachable state is ambiguous.)
//
// ## THE INVERSE IS THE ONE TASK 9d MUST NOT IMPROVISE
//
// The corpus's transactions carry ranges in STOCK CHARACTER coordinates. The obvious way to realise
// one — `[input positionFromPosition:input.beginningOfDocument offset:location]` — is **WRONG on the
// editor past a boundary**, and wrong quietly: it does raw-offset arithmetic (`p.offset + offset`,
// then snap), so requesting offset 25 lands on raw 26, which is character **24**. Measured:
//
//     position(begin, +12) -> raw 13 -> character 12   ✓ (before the boundary)
//     position(begin, +19) -> raw 21 -> character 19   ✓ (the snap happens to compensate)
//     position(begin, +25) -> raw 26 -> character 24   ✗ one character early
//
// A driver built on that would apply every post-boundary edit one character off, the recorder would
// faithfully report the resulting text, and the difference would be attributed to the editor's
// EDITING rather than to the harness's aim. Use `IDTelegramTextRangeForCharacterRange` instead; it
// steps the editor's own positions and is therefore right on both arms by construction.
#import "IDTextInputScenario.h"

NS_ASSUME_NONNULL_BEGIN

/// The character index of `position` on the stock axis, or `nil` when the input cannot answer.
/// Never falls back to `0`, which is a real and very plausible index.
FOUNDATION_EXPORT NSNumber *_Nullable IDTelegramCharacterIndexForPosition(
    id<UITextInput> input, UITextPosition *_Nullable position);

/// `range` as an `NSRange` on the stock character axis. A `nil` range yields `{NSNotFound, 0}` (the
/// vendored recorder's value for "no selection / no marked text", and one both arms produce
/// identically); a range the map cannot convert yields `nil`.
FOUNDATION_EXPORT NSValue *_Nullable IDTelegramCharacterRangeForTextRange(
    id<UITextInput> input, UITextRange *_Nullable range);

/// The inverse: the position at character index `index`, found by stepping the input's OWN positions
/// so that non-renderable slots are skipped exactly as the editor skips them. `nil` when the index is
/// past the end of the document or the input stops making progress.
FOUNDATION_EXPORT UITextPosition *_Nullable IDTelegramPositionForCharacterIndex(
    id<UITextInput> input, NSUInteger index);

/// The inverse for a whole range. `nil` for `{NSNotFound, …}` or an index the document cannot reach.
FOUNDATION_EXPORT UITextRange *_Nullable IDTelegramTextRangeForCharacterRange(
    id<UITextInput> input, NSRange range);

NS_ASSUME_NONNULL_END
