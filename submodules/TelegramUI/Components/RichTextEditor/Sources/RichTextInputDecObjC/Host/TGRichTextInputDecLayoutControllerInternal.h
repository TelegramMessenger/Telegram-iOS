// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecLayoutController.h"
#import "TGRichTextInputDecPosition.h"
#import "TGRichTextInputDecRange.h"

NS_ASSUME_NONNULL_BEGIN

/// The neutral `id_`-prefixed surface `TGRichTextInputDecLayoutController`'s private-selector
/// forwards call into. Every private callback the class implements is a one-line forward
/// (`- (X)privateSelector { return [self id_privateSelector]; }`) to a member declared here, so
/// that the class body stays a flat, auditable list of forwards and the actual logic lives in
/// ordinary, testable, non-privately-named methods.
///
/// Grows one method group per Stage-C family; each group is headed by a comment naming the task
/// that owns it and the manifest rows it answers.
@interface TGRichTextInputDecLayoutController ()

// MARK: - Connection/teardown (Task C0; manifest rows 1, 26-29)

/// Backing store for the private `-textInputController` callback. Set by
/// `-id_adoptTextInputController:`, cleared by `-id_detachFromTextInputController`. `weak`: the
/// private input controller retains ITS layout controller (us), so holding it strongly back
/// would be a retain cycle; UIKit is the sole owner of its own controller instance.
@property(nonatomic, weak, nullable) id id_textInputControllerStorage;

- (nullable NSTextStorage *)id_textStorage;
- (nullable id)id_textInputController;
- (void)id_adoptTextInputController:(id)controller;
- (void)id_detachFromTextInputController;
- (BOOL)id_canAccessLayoutManager;

/// Not one of the manifest's 47 certified rows (`grep` for `"layoutManager"` in the decoded
/// contract data returns nothing) — but UIKit's private input controller sends plain `-layoutManager`
/// to its layout controller regardless of what the manifest certifies, and answering nil here
/// (paired with `id_canAccessLayoutManager` answering NO) is what keeps that message from being
/// mistaken for a real TextKit graph. Implemented defensively; not covered by contract evaluation.
- (nullable id)id_layoutManager;

// MARK: - Family 1: document reads & position/range conversion
// (Task C4; manifest rows 5-14, 16-19, 21-25, 31, 40)
//
// Every position/range argument below is one WE minted (`TGRichTextInputDecPosition`/
// `TGRichTextInputDecRange`); a stale one (its `documentRevision` behind the bridge's current
// `documentRevision()`) is rebased through `documentRebaseOffset:fromRevision:outOffset:`
// EXACTLY ONCE per position, in the private `TGResolvePosition` helper
// (`TGRichTextInputDecLayoutController.m`) — a second miss gives up rather than looping, and
// never fabricates offset 0 (see `TGRichTextInputDecClientBridge.h`'s doc comment). Ranges are
// never reordered (mirrors `TGRichTextInputDecRange`'s own verbatim `start`/`end` storage);
// converting to a concrete, non-negative `NSRange` (`id_characterRangeForTextRange:` and its
// `clippedToDocument:` sibling) is the one place `min`/`max` is applied.

- (nullable TGRichTextInputDecPosition *)id_beginningOfDocument;
- (nullable TGRichTextInputDecPosition *)id_endOfDocument;
- (nullable TGRichTextInputDecRange *)id_emptyTextRangeAtPosition:(TGRichTextInputDecPosition *)position;
- (nullable TGRichTextInputDecRange *)id_textRangeFromPosition:(TGRichTextInputDecPosition *)from
                                                      toPosition:(TGRichTextInputDecPosition *)to;
- (nullable TGRichTextInputDecPosition *)id_positionFromPosition:(TGRichTextInputDecPosition *)position
                                                            offset:(NSInteger)offset;
- (nullable TGRichTextInputDecPosition *)id_positionFromPosition:(TGRichTextInputDecPosition *)position
                                                            offset:(NSInteger)offset
                                                          affinity:(UITextStorageDirection)affinity;
- (nullable TGRichTextInputDecPosition *)id_positionFromPosition:(TGRichTextInputDecPosition *)position
                                                       inDirection:(UITextLayoutDirection)direction
                                                            offset:(NSInteger)offset
                                                          affinity:(UITextStorageDirection)affinity
                                              anchorPositionOffset:(CGFloat)anchorPositionOffset;
- (nullable TGRichTextInputDecRange *)id_textRangeForLineEnclosingPosition:(TGRichTextInputDecPosition *)position;
- (nullable TGRichTextInputDecRange *)id_textRangeForLineEnclosingPosition:(TGRichTextInputDecPosition *)position
                                                          effectiveAffinity:(UITextStorageDirection)affinity;
/// Honest-nil: Family 1's scope (per the task brief's `Consumes` list) does not include the
/// document client's `typingAttributes(at:)` — no bridge accessor for it exists on this group —
/// so there is no non-fabricated answer here yet. `nil` is `UITextInput`'s own documented "no
/// answer" shape for a styling query, matching `IDTextEditorBackend.textStyling(at:in:)`'s
/// existing `nil` stub.
- (nullable NSDictionary<NSAttributedStringKey, id> *)id_attributesAtPosition:(TGRichTextInputDecPosition *)position
                                                                    inDirection:(UITextStorageDirection)direction;
- (NSComparisonResult)id_comparePosition:(TGRichTextInputDecPosition *)position
                              toPosition:(TGRichTextInputDecPosition *)other;
- (NSInteger)id_offsetFromPosition:(TGRichTextInputDecPosition *)from
                        toPosition:(TGRichTextInputDecPosition *)to;
- (UITextStorageDirection)id_affinityForPosition:(TGRichTextInputDecPosition *)position;
- (NSRange)id_characterRangeForTextRange:(TGRichTextInputDecRange *)range;
- (NSRange)id_characterRangeForTextRange:(TGRichTextInputDecRange *)range
                       clippedToDocument:(BOOL)clippedToDocument;
- (NSArray<NSValue *> *)id_characterRangesForTextRange:(TGRichTextInputDecRange *)range
                                     clippedToDocument:(BOOL)clippedToDocument;
- (nullable TGRichTextInputDecRange *)id_textRangeForCharacterRange:(NSRange)range;
- (nullable TGRichTextInputDecRange *)id_textRangeForCharacterRanges:(NSArray<NSValue *> *)ranges;
- (nullable TGRichTextInputDecPosition *)id_positionWithOffset:(NSInteger)offset
                                                        affinity:(UITextStorageDirection)affinity;
/// "Type" is the private controller's own cluster-kind enum; Family 1 has no access to anything
/// richer than plain text (no tokenizer, no layout), so every type is answered the one honest way
/// available at this layer — the Unicode composed-character-sequence (grapheme cluster) the
/// offset falls in, via `-[NSString rangeOfComposedCharacterSequenceAtIndex:]`.
- (NSRange)id_rangeOfCharacterClusterAtIndex:(NSUInteger)index type:(NSInteger)type;
- (nullable NSAttributedString *)id_attributedTextInRange:(TGRichTextInputDecRange *)range;

// MARK: - Family 2: geometry (Task C5; manifest rows 2-4, 15, 20, 32-36, 38, 39)
//
// This layer has no real TextKit layout graph (`id_canAccessLayoutManager` answers NO), so every
// container callback below answers the ONE `syntheticContainer` and every geometry callback is a
// thin forward to the three `TGRichTextInputDecClientBridging` geometry methods. These nine
// callbacks (rows 32-36, 38-39, plus the container trio) have no home in the spec's six shared
// clients — they are private UIKit selectors, resolved here, and no shared protocol grows to
// accommodate them.

- (NSArray<NSTextContainer *> *)id_textContainers;
- (nullable NSTextContainer *)id_firstTextContainer;
- (nullable NSTextContainer *)id_textContainerForPosition:(TGRichTextInputDecPosition *)position;

- (NSWritingDirection)id_baseWritingDirectionAtPosition:(TGRichTextInputDecPosition *)position;
- (CGRect)id_boundingRectForCharacterRange:(NSRange)range;

- (NSArray<TGRichTextInputDecSelectionRect *> *)id_selectionRectsForRange:(TGRichTextInputDecRange *)range
                                                                    fromView:(nullable UIView *)fromView
                                                      forContainerPassingTest:
    (nullable BOOL (^)(NSTextContainer *container))test;
- (void)id_requestTextGeometryAtPosition:(TGRichTextInputDecPosition *)position
                        typingAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes
                             resultBlock:(void (^)(CGRect rect, NSWritingDirection writingDirection))resultBlock;
/// Position is `UITextPosition *`, NOT the concrete `TGRichTextInputDecPosition *` every other
/// `id_` method in this file takes — matching the task brief's own Step 5 snippet for this row
/// verbatim (it casts to the concrete type via a local `p` inside the method body instead of at
/// the one-line-forward call site, the only row in Family 2 that does).
- (CGRect)id_insertionRectForPosition:(UITextPosition *)position
                      typingAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes
                 placeholderAttachment:(nullable id)attachment
                         textContainer:(NSTextContainer * _Nullable * _Nullable)textContainer;
- (nullable TGRichTextInputDecPosition *)id_cursorPositionAtPoint:(CGPoint)point
                                                       inContainer:(nullable NSTextContainer *)container;
- (nullable TGRichTextInputDecPosition *)id_nearestPositionAtPoint:(CGPoint)point
                                                        inContainer:(nullable NSTextContainer *)container;

/// Honest no-ops: no real TextKit layout graph exists at this layer to ensure or invalidate (see
/// `id_canAccessLayoutManager` above) — nothing this layout controller can do makes either call
/// meaningful, so both simply return.
- (void)id_ensureLayoutForRange:(NSRange)range;
- (void)id_invalidateLayoutForRange:(NSRange)range;

// MARK: - Family 3: selected range and input-delegate ownership (Task C6; manifest row 30)
//
// The ONE row this task owns. Like `id_ensureLayoutForRange:`/`id_invalidateLayoutForRange:`
// above, this layer has no real display surface to invalidate yet — the redraw path this private
// callback exists to trigger (continuous-spelling / native-checking annotation redraw, per the
// manifest's own evidence tag `#native-continuous-spelling` — the SAME tag C14's seven
// remaining `incomingCallbacks` rows carry) has no consumer until whichever task wires the
// annotation client through. Honest no-op, not a fabricated success.

- (void)id_invalidateDisplayForCharacterRange:(NSRange)range;

// MARK: - Family 9: touch interaction and selection (Task C12; manifest row 37)
//
// The ONE row this task owns: `_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:`
// — a genuinely PRIVATE selector (leading underscore, unlike every `id_`-mirrored PUBLIC
// `UITextInput` requirement above), sent by the private interaction assistant while a
// selection-handle drag is in flight, asking "if the dragged handle moved to `point`, what would
// the resulting selection range be, given the drag started from `position` in `direction`".
// `extent`'s real (undocumented) enum meaning is unknown — `Vendor/VENDOR.md` records that
// `referenceOnly` (53 rows) was dropped from this export — so, exactly like `id_
// rangeOfCharacterClusterAtIndex:type:`'s own `type:` parameter (Family 1), it is received and
// passed through untyped (`NSInteger`) rather than guessed at.
//
// Reuses Family 1/2 machinery rather than inventing new geometry math: resolves `point` to the
// nearest offset the SAME way `id_cursorPositionAtPoint:inContainer:`/
// `id_nearestPositionAtPoint:inContainer:` already do, then builds the range from the caller's own
// `position` to that resolved endpoint via `id_textRangeFromPosition:toPosition:` — a documented,
// best-effort reconstruction (not a certified contract), matching this file's own established
// convention for undocumented rows (see C4/C6's identical framing for their own reconstructed
// rows).
- (nullable TGRichTextInputDecRange *)id_visualSelectionRangeForExtent:(NSInteger)extent
                                                                forPoint:(CGPoint)point
                                                            fromPosition:(TGRichTextInputDecPosition *)position
                                                              inDirection:(UITextLayoutDirection)direction;

// MARK: - Family 11: spellchecking and annotations (Task C14; manifest rows 41-47)
//
// The final seven `incomingCallbacks` rows — the ones that keep the WHOLE capability rejected
// until this task lands. Every one of the seven is deliberately NOT run through the Family-1
// `TGResolvePosition` rebase helper (unlike almost every other family in this file): the incoming
// position/range's OWN, unresolved `documentRevision` is threaded straight through to
// `TGRichTextInputDecClientBridging`'s matching annotation method, because
// `TelegramAnnotationInputClient`'s `guard revision == canvas.documentRevision` is the REAL
// staleness gate for this family (D17's pre-existing "ranges do not shift" divergence — see
// DIVERGENCES.md entry 14) — resolving first would make that gate vacuous. `position`/`range`
// arrive typed `UITextPosition *`/`UITextRange *` at the one-line-forward call sites (mirroring
// Family 9's own `id_visualSelectionRangeForExtent:...`), cast to the concrete
// `TGRichTextInputDecPosition *`/`TGRichTextInputDecRange *` before these declarations are called.

- (nullable NSAttributedString *)id_annotatedSubstringForRange:(TGRichTextInputDecRange *)range;
- (nullable id)id_annotationAttribute:(id)key atPosition:(TGRichTextInputDecPosition *)position;
- (void)id_addAnnotationAttribute:(id)key value:(id)value forRange:(TGRichTextInputDecRange *)range;
- (void)id_removeAnnotationAttribute:(id)key forRange:(TGRichTextInputDecRange *)range;
- (void)id_addRenderingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                          forRange:(TGRichTextInputDecRange *)range;
- (void)id_removeRenderingAttributes:(NSArray<NSAttributedStringKey> *)keys
                             forRange:(TGRichTextInputDecRange *)range;
- (void)id_invalidateTemporaryAttributesInRange:(TGRichTextInputDecRange *)range;

// Tasks C15+ append their groups below this line, one per family.

@end

NS_ASSUME_NONNULL_END

#endif
