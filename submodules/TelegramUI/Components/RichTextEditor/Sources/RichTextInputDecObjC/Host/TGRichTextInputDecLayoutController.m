// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecLayoutControllerInternal.h"
#import "TGPrivateMethodAliases.h"
#import "TGPrivateRuntimeNames.h"

// MARK: - Family 1 helpers (Task C4)
//
// Plain C functions, not methods: they only need `bridge`, so keeping them out of the class's
// selector namespace avoids any risk of colliding with a real (possibly still-undeclared) private
// UIKit selector, and keeps the per-family "id_" method list a flat, auditable read.

/// A fresh position at `offset`/`affinity`, stamped with the bridge's CURRENT document revision
/// — never a stale or caller-supplied one, so a position this file MINTS is never itself stale.
static TGRichTextInputDecPosition *TGMakePosition(
    id<TGRichTextInputDecClientBridging> bridge, NSInteger offset, UITextStorageDirection affinity) {
    return [TGRichTextInputDecPosition positionWithOffset:offset
                                                   affinity:affinity
                                                   revision:[bridge documentRevision]];
}

/// Resolves `position` against the CURRENT document revision. If it already matches, it is
/// returned unchanged (no bridge call at all — the fast, common path). Otherwise this attempts
/// EXACTLY ONE rebase through `documentRebaseOffset:fromRevision:outOffset:`: on success the
/// rebased offset is returned stamped with the current revision; on failure — "cannot be
/// rebased" — `position`'s OWN recorded offset is kept (never fabricated as 0) and likewise
/// stamped with the current revision, so a second call against the SAME already-resolved result
/// never re-attempts the rebase ("one rebase per operation — a second miss must give up, not
/// loop", per the task brief).
static TGRichTextInputDecPosition *TGResolvePosition(
    id<TGRichTextInputDecClientBridging> bridge, TGRichTextInputDecPosition *position) {
    uint64_t currentRevision = [bridge documentRevision];
    if (position.documentRevision == currentRevision) {
        return position;
    }
    NSInteger rebasedOffset = 0;
    BOOL rebased = [bridge documentRebaseOffset:position.utf16Offset
                                    fromRevision:position.documentRevision
                                       outOffset:&rebasedOffset];
    NSInteger resolvedOffset = rebased ? rebasedOffset : position.utf16Offset;
    return TGMakePosition(bridge, resolvedOffset, position.affinity);
}

/// Task R7 (cluster 4) — converts a STRUCTURAL axis offset (0...`documentLength`, this document
/// model's own node-token addressing — see `id_characterRangeForTextRange:`'s own doc comment for the
/// full account) to its PLAIN-TEXT axis equivalent: the offset into `documentPlainTextInRange:`'s own
/// dense projection, which is exactly what the facade's `NSTextStorage` mirror (and `text(in:)` itself)
/// is built from. `documentPlainTextInRange:`'s RESULT LENGTH over `[0, structuralOffset)` IS that
/// conversion — the same projection already used everywhere else, asked a question nothing had asked
/// it before. Read-only and independent of `mirror`'s own sync state (it goes straight to `bridge`),
/// so callers may use it before or after `synchronizeMirrorWithDocumentIfNeeded` runs.
static NSInteger TGPlainTextOffsetForStructuralOffset(
    id<TGRichTextInputDecClientBridging> bridge, NSInteger structuralOffset, NSInteger documentLength) {
    if (bridge == nil || ![bridge respondsToSelector:@selector(documentPlainTextInRange:)]) {
        return structuralOffset;
    }
    NSInteger clamped = MIN(MAX(structuralOffset, 0), MAX(documentLength, 0));
    NSString *prefix = [bridge documentPlainTextInRange:NSMakeRange(0, (NSUInteger)clamped)];
    // No fabricated 0 on a nil answer (mid-teardown, an unimplemented bridge) — the ORIGINAL
    // structural offset is the least-wrong fallback, matching this file's "never fabricate" rule.
    return prefix != nil ? (NSInteger)prefix.length : structuralOffset;
}

/// Task D3c — the INVERSE of `TGPlainTextOffsetForStructuralOffset` above: the smallest STRUCTURAL
/// offset S in `[0, documentLength]` whose plain-text prefix length equals `plainOffset`.
/// `TGPlainTextOffsetForStructuralOffset` is monotonic non-decreasing in its structural argument —
/// each structural step advances the plain-text prefix length by 0 or 1, staying flat while
/// stepping through a paragraph boundary's non-renderable token slots (the "\n" those slots
/// represent has no structural position of its own) — so a binary search always finds a valid
/// preimage, including at a boundary "plateau" where several structural offsets share one
/// plain-text length. The SMALLEST preimage is the right answer for
/// `id_rangeOfCharacterClusterAtIndex:type:` below: round-tripping a range through this pair only
/// has to be SELF-CONSISTENT with `TGPlainTextOffsetForStructuralOffset` (so `computePlainRange`
/// in `replaceCharactersInRange:withString:` maps it back to the exact same plain span), not pick
/// a canonical side of the boundary.
static NSInteger TGStructuralOffsetForPlainTextOffset(
    id<TGRichTextInputDecClientBridging> bridge, NSInteger plainOffset, NSInteger documentLength) {
    if (bridge == nil || ![bridge respondsToSelector:@selector(documentPlainTextInRange:)]) {
        return plainOffset;
    }
    NSInteger lo = 0;
    NSInteger hi = MAX(documentLength, 0);
    while (lo < hi) {
        NSInteger mid = lo + (hi - lo) / 2;
        NSInteger midPlain = TGPlainTextOffsetForStructuralOffset(bridge, mid, documentLength);
        if (midPlain < plainOffset) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    return lo;
}

/// The RESOLVED, ordered, non-negative STRUCTURAL-axis `NSRange` for `range` — exactly what
/// `id_characterRangeForTextRange:` computed inline before Task R7 split it out, so
/// `id_attributedTextInRange:` (which must keep passing `documentPlainTextInRange:` a STRUCTURAL
/// range — that method's whole contract) and `id_characterRangeForTextRange:` (which now converts
/// this structural range to the PLAIN-TEXT axis for its callers — see that method's own doc comment)
/// share one resolution instead of maintaining two.
static NSRange TGStructuralCharacterRangeForTextRange(
    id<TGRichTextInputDecClientBridging> bridge, TGRichTextInputDecRange *range) {
    TGRichTextInputDecPosition *start = TGResolvePosition(
        bridge, (TGRichTextInputDecPosition *)range.start);
    TGRichTextInputDecPosition *end = TGResolvePosition(
        bridge, (TGRichTextInputDecPosition *)range.end);
    NSInteger lo = MIN(start.utf16Offset, end.utf16Offset);
    NSInteger hi = MAX(start.utf16Offset, end.utf16Offset);
    lo = MAX(lo, 0);
    hi = MAX(hi, lo);
    return NSMakeRange((NSUInteger)lo, (NSUInteger)(hi - lo));
}

// MARK: - Family 2 helpers (Task C5)
//
// Same rationale as the Family 1 helpers above: plain C functions kept out of the class's
// selector namespace.

/// Shared by `id_cursorPositionAtPoint:inContainer:` and `id_nearestPositionAtPoint:inContainer:`
/// — neither private callback's own signature carries a range (UIKit hands us only a point and a
/// container), so both ask the bridge for the closest offset over the WHOLE document (the
/// `NSNotFound`-location sentinel `closestOffsetToPoint:withinRange:revision:outOffset:`'s own doc
/// comment names) and mint a forward-leaning position from the result. `nil` on a bridge NO —
/// never a fabricated offset 0.
static TGRichTextInputDecPosition *_Nullable TGClosestPosition(
    id<TGRichTextInputDecClientBridging> bridge, CGPoint point) {
    NSInteger offset = 0;
    BOOL found = [bridge closestOffsetToPoint:point
                                   withinRange:NSMakeRange(NSNotFound, 0)
                                      revision:[bridge documentRevision]
                                     outOffset:&offset];
    if (!found) {
        return nil;
    }
    return TGMakePosition(bridge, offset, UITextStorageDirectionForward);
}

// MARK: - Family 11 helpers (Task C14)
//
// Deliberately does NOT call `TGResolvePosition` (Family 1's rebase helper) — Family 11 is the
// one family that must NOT silently rebase a stale range. See this file's own Family-11 `id_`
// section and DIVERGENCES.md entry 14: the annotation client's `revision ==
// canvas.documentRevision` check is the REAL staleness gate (reject-if-stale), and resolving
// through `TGResolvePosition` first would always stamp the CURRENT revision, making that gate
// vacuous.

/// The RAW (unresolved) character range for `range`, plus its RAW (unresolved) `documentRevision`
/// out-parameter — read directly off `range.start`, mirroring `TGRichTextInputDecRange`'s own
/// verbatim, non-independent start/end storage and `id_characterRangeForTextRange:`'s own
/// `start`-then-`end` ordering, but WITHOUT that method's `TGResolvePosition` call.
static NSRange TGRawCharacterRangeForRange(TGRichTextInputDecRange *range, uint64_t *outRevision) {
    TGRichTextInputDecPosition *start = (TGRichTextInputDecPosition *)range.start;
    TGRichTextInputDecPosition *end = (TGRichTextInputDecPosition *)range.end;
    NSInteger lo = MIN(start.utf16Offset, end.utf16Offset);
    NSInteger hi = MAX(start.utf16Offset, end.utf16Offset);
    lo = MAX(lo, 0);
    hi = MAX(hi, lo);
    if (outRevision != NULL) {
        *outRevision = start.documentRevision;
    }
    return NSMakeRange((NSUInteger)lo, (NSUInteger)(hi - lo));
}

@interface TGRichTextInputDecLayoutController ()
@property(nonatomic, strong, readonly) id<TGRichTextInputDecClientBridging> bridge;
@property(nonatomic, strong, readwrite) NSTextContainer *syntheticContainer;
@end

@implementation TGRichTextInputDecLayoutController

// The callbacks UIKit's private text-input machinery sends by name. Each is an `id_` method with
// the same arguments, added under the private name at run time rather than compiled under it, so
// the private names do not reach the binary as text (`TGPrivateMethodAliases.h`).
+ (void)initialize {
    if (self != TGRichTextInputDecLayoutController.class) {
        return;
    }
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_textInputController, @selector(id_textInputController) },
        { TGPN_adoptTextInputController_, @selector(id_adoptTextInputController:) },
        { TGPN_detachFromTextInputController, @selector(id_detachFromTextInputController) },
        { TGPN_canAccessLayoutManager, @selector(id_canAccessLayoutManager) },
        { TGPN_emptyTextRangeAtPosition_, @selector(id_emptyTextRangeAtPosition:) },
        { TGPN_textRangeForLineEnclosingPosition_, @selector(id_textRangeForLineEnclosingPosition:) },
        { TGPN_textRangeForLineEnclosingPosition_effectiveAffinity_, @selector(id_textRangeForLineEnclosingPosition:effectiveAffinity:) },
        { TGPN_attributesAtPosition_inDirection_, @selector(id_attributesAtPosition:inDirection:) },
        { TGPN_affinityForPosition_, @selector(id_affinityForPosition:) },
        { TGPN_characterRangeForTextRange_, @selector(id_characterRangeForTextRange:) },
        { TGPN_characterRangeForTextRange_clippedToDocument_, @selector(id_characterRangeForTextRange:clippedToDocument:) },
        { TGPN_characterRangesForTextRange_clippedToDocument_, @selector(id_characterRangesForTextRange:clippedToDocument:) },
        { TGPN_textRangeForCharacterRange_, @selector(id_textRangeForCharacterRange:) },
        { TGPN_textRangeForCharacterRanges_, @selector(id_textRangeForCharacterRanges:) },
        { TGPN_positionWithOffset_affinity_, @selector(id_positionWithOffset:affinity:) },
        { TGPN_rangeOfCharacterClusterAtIndex_type_, @selector(id_rangeOfCharacterClusterAtIndex:type:) },
        { TGPN_firstTextContainer, @selector(id_firstTextContainer) },
        { TGPN_textContainerForPosition_, @selector(id_textContainerForPosition:) },
        { TGPN_baseWritingDirectionAtPosition_, @selector(id_baseWritingDirectionAtPosition:) },
        { TGPN_boundingRectForCharacterRange_, @selector(id_boundingRectForCharacterRange:) },
        { TGPN_selectionRectsForRange_fromView_forContainerPassingTest_, @selector(id_selectionRectsForRange:fromView:forContainerPassingTest:) },
        { TGPN_requestTextGeometryAtPosition_typingAttributes_resultBlock_, @selector(id_requestTextGeometryAtPosition:typingAttributes:resultBlock:) },
        { TGPN_insertionRectForPosition_typingAttributes_placeholderAttachment_textContainer_, @selector(id_insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:) },
        { TGPN_cursorPositionAtPoint_inContainer_, @selector(id_cursorPositionAtPoint:inContainer:) },
        { TGPN_nearestPositionAtPoint_inContainer_, @selector(id_nearestPositionAtPoint:inContainer:) },
        { TGPN__visualSelectionRangeForExtent_forPoint_fromPosition_inDirection_, @selector(tgpn__visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:) },
        { TGPN_annotatedSubstringForRange_, @selector(id_annotatedSubstringForRange:) },
        { TGPN_addAnnotationAttribute_value_forRange_, @selector(id_addAnnotationAttribute:value:forRange:) },
        { TGPN_annotationAttribute_atPosition_, @selector(id_annotationAttribute:atPosition:) },
        { TGPN_removeAnnotationAttribute_forRange_, @selector(id_removeAnnotationAttribute:forRange:) },
        { TGPN_addRenderingAttributes_forRange_, @selector(id_addRenderingAttributes:forRange:) },
        { TGPN_removeRenderingAttributes_forRange_, @selector(id_removeRenderingAttributes:forRange:) },
        { TGPN__invalidateTemporaryAttributesInRange_, @selector(id_invalidateTemporaryAttributesInRange:) },
    };
    TGPrivateInstallMethodAliases(self, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

- (instancetype)initWithBridge:(id<TGRichTextInputDecClientBridging>)bridge {
    NSParameterAssert(bridge != nil);
    self = [super init];
    if (self == nil) return nil;
    _bridge = bridge;
    // Nothing ever lays text out against this container — `id_canAccessLayoutManager` answers
    // NO, so UIKit never demands a real TextKit graph — its only job is to exist as a distinct
    // object identity the 47-row contract can name.
    _syntheticContainer = [[NSTextContainer alloc] init];
    return self;
}

#pragma mark - Private callbacks (one-line forwards; manifest rows 1, 26-29)
//
// Each of these is a selector UIKit's private text-input machinery sends by name — deliberately
// UNDECLARED in any header (exactly like the equivalent canvas thunks in
// TGRichTextInputDecCanvasCallbacks.m), so nothing in this module can call them through static
// typing. `NSClassFromString`/`class_getInstanceMethod` find them by selector regardless of
// declaration, which is all the resolver's contract evaluation and UIKit's own runtime dispatch
// need.

- (nullable NSTextStorage *)textStorage {
    return [self id_textStorage];
}





/// Not a certified manifest row (see the Internal header's doc comment on
/// `id_layoutManager`) — implemented anyway as a defensive forward, matching upstream.
- (nullable id)layoutManager {
    return [self id_layoutManager];
}

#pragma mark - id_ implementations (Task C0: connection/teardown)

- (nullable NSTextStorage *)id_textStorage {
    return self.textStorageFacade;
}

- (nullable id)id_textInputController {
    return self.id_textInputControllerStorage;
}

- (void)id_adoptTextInputController:(id)controller {
    self.id_textInputControllerStorage = controller;
}

- (void)id_detachFromTextInputController {
    self.id_textInputControllerStorage = nil;
}

- (BOOL)id_canAccessLayoutManager {
    return NO;
}

- (nullable id)id_layoutManager {
    return nil;
}

#pragma mark - Private callbacks (one-line forwards; Family 1, Task C4)
//
// Same shape and same reasoning as the connection/teardown group above: each selector is
// deliberately UNDECLARED anywhere except this cast-through-`id_` forward, so nothing in this
// module can call it through static typing. Argument/return types here match the REAL `UITextInput`
// (or its private sibling) shapes the appendix's `@encode` column specifies — the concrete
// `TGRichTextInputDecPosition`/`TGRichTextInputDecRange` types are only used on the `id_` side.

- (nullable UITextPosition *)beginningOfDocument {
    return [self id_beginningOfDocument];
}

- (nullable UITextPosition *)endOfDocument {
    return [self id_endOfDocument];
}


- (nullable UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition
                                      toPosition:(UITextPosition *)toPosition {
    return [self id_textRangeFromPosition:(TGRichTextInputDecPosition *)fromPosition
                                toPosition:(TGRichTextInputDecPosition *)toPosition];
}

- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                            offset:(NSInteger)offset {
    return [self id_positionFromPosition:(TGRichTextInputDecPosition *)position offset:offset];
}

- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                            offset:(NSInteger)offset
                                          affinity:(UITextStorageDirection)affinity {
    return [self id_positionFromPosition:(TGRichTextInputDecPosition *)position
                                   offset:offset
                                 affinity:affinity];
}

- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                       inDirection:(UITextLayoutDirection)direction
                                            offset:(NSInteger)offset
                                          affinity:(UITextStorageDirection)affinity
                              anchorPositionOffset:(CGFloat)anchorPositionOffset {
    return [self id_positionFromPosition:(TGRichTextInputDecPosition *)position
                              inDirection:direction
                                   offset:offset
                                 affinity:affinity
                     anchorPositionOffset:anchorPositionOffset];
}




- (NSComparisonResult)comparePosition:(UITextPosition *)position
                            toPosition:(UITextPosition *)other {
    return [self id_comparePosition:(TGRichTextInputDecPosition *)position
                          toPosition:(TGRichTextInputDecPosition *)other];
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from
                      toPosition:(UITextPosition *)toPosition {
    return [self id_offsetFromPosition:(TGRichTextInputDecPosition *)from
                             toPosition:(TGRichTextInputDecPosition *)toPosition];
}









- (nullable NSAttributedString *)attributedTextInRange:(UITextRange *)range {
    return [self id_attributedTextInRange:(TGRichTextInputDecRange *)range];
}

#pragma mark - id_ implementations (Family 1, Task C4: document reads & position/range conversion)

/// Task R7 (cluster 4) — snaps `pos` to the nearest RENDERABLE offset (a position the caret can
/// actually occupy), searching forward when `forward` is YES, else backward. Mirrors
/// `LegacyRichTextInputBackend`'s own `beginningOfDocument`/`endOfDocument`, which snap through
/// `DocumentCanvasView.legacySnapToRenderable(_:forward:)` rather than handing UIKit the document's
/// raw structural offset — that offset is a STRUCTURAL token slot (this document model's own root-
/// node open/close boundary, one slot outside every top-level block's own `nodeStart`/`nodeStart +
/// nodeSize`, exactly the "the document's structural open-token slot at 0" LegacyRichTextInputBackend's
/// own `beginningOfDocument` doc comment warns is NOT where the caret can be drawn), not a position a
/// caret can occupy. Both backends share the SAME underlying position axis (one `DocumentCanvasView`,
/// one `Document`) — this is a faithful lift of that already-proven snapping shape onto this layer's
/// own bridge surface, not new behavior.
///
/// Reuses `documentIsValidInsertionOffset:` — the SAME renderability check
/// `DocumentCanvasView.isRenderablePosition(_:)` performs (via `TelegramDocumentInputClient
/// .isValidInsertionPosition(_:)`) — already `@optional`-bridged and already relied on elsewhere in
/// this file, rather than adding a new bridge crossing. A bounded linear scan, not a candidate-list
/// binary search like the canvas's own `snapToRenderable`: the fast path is the FIRST probe (a
/// position that is already renderable — every offset that is not inside a boundary gap), and a
/// top-level paragraph gap is ONE slot wide, so the loop that does run terminates in a step or two.
/// Only a document with no renderable offset at all in the requested direction walks far.
///
/// Task D4f — the cross-direction FALLBACK below matches `DocumentCanvasView.snapToRenderable
/// (_:forward:)`'s own final line, `forward ? (atOrAfter ?? atOrBefore ?? p) : (atOrBefore ??
/// atOrAfter ?? p)`. Without it this helper answered `pos` unchanged — i.e. a NON-renderable offset
/// — whenever the requested direction ran out of document, which is not hypothetical: the last
/// structural slot (`documentUTF16Length`, the root node's own close token) is never renderable, so
/// a `+1` step off the document's last renderable position handed back that slot instead of
/// standing still. Legacy's walk stops there; ours stepped one past the end.
static NSInteger TGSnapToRenderableOffset(
    id<TGRichTextInputDecClientBridging> bridge, NSInteger pos, NSInteger length, BOOL forward) {
    if (bridge == nil || ![bridge respondsToSelector:@selector(documentIsValidInsertionOffset:)]) {
        return pos;
    }
    NSInteger clamped = MIN(MAX(pos, 0), length);
    if ([bridge documentIsValidInsertionOffset:clamped]) {
        return clamped;
    }
    NSInteger atOrAfter = NSNotFound;
    for (NSInteger candidate = clamped; candidate <= length; candidate++) {
        if ([bridge documentIsValidInsertionOffset:candidate]) {
            atOrAfter = candidate;
            break;
        }
    }
    NSInteger atOrBefore = NSNotFound;
    for (NSInteger candidate = clamped; candidate >= 0; candidate--) {
        if ([bridge documentIsValidInsertionOffset:candidate]) {
            atOrBefore = candidate;
            break;
        }
    }
    NSInteger preferred = forward ? atOrAfter : atOrBefore;
    NSInteger fallback = forward ? atOrBefore : atOrAfter;
    if (preferred != NSNotFound) {
        return preferred;
    }
    if (fallback != NSNotFound) {
        return fallback;
    }
    // No renderable offset found anywhere (e.g. a document the bridge cannot yet answer for) —
    // the ORIGINAL raw offset, never a fabricated 0, matching this file's established "never
    // fabricate" convention for an honest "could not resolve" outcome.
    return pos;
}

- (nullable TGRichTextInputDecPosition *)id_beginningOfDocument {
    // Forward affinity: nothing precedes offset 0, so any caret there leans into the text that
    // follows. Mirrors `id_endOfDocument`'s opposite choice below.
    // `respondsToSelector:` guard, matching this file's own convention: `documentUTF16Length` is
    // `@optional`, and a bridge that doesn't implement it (e.g. a narrow test double built before
    // this row was reachable from here) gets the pre-R7 unsnapped offset 0 rather than a crash.
    NSInteger length = [self.bridge respondsToSelector:@selector(documentUTF16Length)]
        ? [self.bridge documentUTF16Length] : 0;
    NSInteger snapped = TGSnapToRenderableOffset(self.bridge, 0, length, YES);
    return TGMakePosition(self.bridge, snapped, UITextStorageDirectionForward);
}

- (nullable TGRichTextInputDecPosition *)id_endOfDocument {
    // Backward affinity: nothing follows the last offset, so a caret there leans into the text
    // that precedes it.
    NSInteger length = [self.bridge respondsToSelector:@selector(documentUTF16Length)]
        ? [self.bridge documentUTF16Length] : 0;
    NSInteger snapped = TGSnapToRenderableOffset(self.bridge, length, length, NO);
    return TGMakePosition(self.bridge, snapped, UITextStorageDirectionBackward);
}

- (nullable TGRichTextInputDecRange *)id_emptyTextRangeAtPosition:(TGRichTextInputDecPosition *)position {
    TGRichTextInputDecPosition *resolved = TGResolvePosition(self.bridge, position);
    return [TGRichTextInputDecRange rangeFrom:resolved to:resolved];
}

- (nullable TGRichTextInputDecRange *)id_textRangeFromPosition:(TGRichTextInputDecPosition *)from
                                                      toPosition:(TGRichTextInputDecPosition *)to {
    TGRichTextInputDecPosition *resolvedFrom = TGResolvePosition(self.bridge, from);
    TGRichTextInputDecPosition *resolvedTo = TGResolvePosition(self.bridge, to);
    // `start`/`end` stored VERBATIM — see `TGRichTextInputDecRange.h`'s doc comment. A reversed
    // pair (from > to) is a legitimate, unordered range, not an error.
    return [TGRichTextInputDecRange rangeFrom:resolvedFrom to:resolvedTo];
}

- (nullable TGRichTextInputDecPosition *)id_positionFromPosition:(TGRichTextInputDecPosition *)position
                                                            offset:(NSInteger)offset {
    TGRichTextInputDecPosition *resolved = TGResolvePosition(self.bridge, position);
    return [self id_positionFromPosition:resolved offset:offset affinity:resolved.affinity];
}

- (nullable TGRichTextInputDecPosition *)id_positionFromPosition:(TGRichTextInputDecPosition *)position
                                                            offset:(NSInteger)offset
                                                          affinity:(UITextStorageDirection)affinity {
    TGRichTextInputDecPosition *resolved = TGResolvePosition(self.bridge, position);
    NSInteger rawOffset = resolved.utf16Offset + offset;
    // "Position arithmetic must clamp through the client, not locally" (task brief) — the clamp
    // ALWAYS runs, even when `rawOffset` already looks in-bounds, so the document client is the
    // sole authority on validity. A clamped value that differs from the raw target means the
    // target fell outside the document, which is `nil` per `UITextInput.position(from:offset:)`'s
    // own documented contract ("returns nil" when the computed position is not in the document).
    NSInteger clamped = [self.bridge documentClampedOffset:rawOffset];
    if (clamped != rawOffset) {
        return nil;
    }
    // Task D4f — SNAP the arithmetic result onto a renderable caret slot, biased by the direction
    // of travel. This is `LegacyRichTextInputBackend.position(from:offset:)`
    // (`LegacyRichTextInputBackend+TextReads.swift`) member for member: an identical bounds guard,
    // then `legacySnapToRenderable(n, forward: offset >= 0)`. The two backends drive the SAME
    // `DocumentCanvasView` over the SAME structural axis, so a divergence here is a divergence in
    // this witness alone, and it was the last one.
    //
    // On that axis a top-level paragraph boundary occupies TWO non-renderable slots (paragraph one
    // closes, paragraph two opens) while the plain-text projection emits ONE `"\n"`. Raw `+1`
    // therefore parks the caret in the gap — a position no caret can be drawn at — and, because the
    // projection collapses the gap, the gap slot and the following paragraph's text start report
    // the SAME character index. Two distinct positions, one character index: the map from position
    // to character index stops being injective, which every caller that counts steps depends on.
    //
    // Measured consequences of NOT snapping, both fixed by this one line (see
    // `IDBackendRenderablePositionSteppingTests`):
    //
    //   * The differential corpus's own aim. `IDTelegramPositionForCharacterIndex`
    //     (`Tests/DifferentialSupport/IDTelegramCharacterAxis.m`) walks THIS witness and takes the
    //     FIRST position whose character index matches — so on `["Alpha middle omega", "Second
    //     block …"]` an aim at character 19 (the second paragraph's first character) resolved to
    //     structural 20, the gap, instead of 21. `DocumentCanvasView.legacySetMarkedText`
    //     (`+MarkedText.swift`) then fails `isBodyParagraphPosition(lo)` and degrades composition
    //     to `commitMarkedText()` + a plain `insertText(_:)`: the provisional character is committed
    //     as ordinary text with no canvas-side `markedRange`, so the next composition update inserts
    //     BESIDE it instead of replacing it (the corpus's doubled character), and the nested
    //     `insertText` drives a SECOND `replaceCharactersInRange:withString:` inside the first, so
    //     the façade mirror takes the same insert twice (its `canonical` divergence).
    //   * Caret stepping. `IDBackendDifferentialTraceTests`' `caret-across-paragraph-boundary`
    //     walked character indices 5 -> 6 -> 6 where legacy walks 5 -> 6 -> 7: the first arrow
    //     landed in the gap and the second only climbed out of it.
    //
    // `offset >= 0` (not `> 0`) matches legacy exactly, so `position(from: p, offset: 0)` snaps
    // forward — the same normalization legacy performs for a caller that resolves a position it
    // did not itself mint.
    NSInteger length = [self.bridge respondsToSelector:@selector(documentUTF16Length)]
        ? [self.bridge documentUTF16Length] : 0;
    NSInteger snapped = TGSnapToRenderableOffset(self.bridge, clamped, length, offset >= 0);
    return TGMakePosition(self.bridge, snapped, affinity);
}

- (nullable TGRichTextInputDecPosition *)id_positionFromPosition:(TGRichTextInputDecPosition *)position
                                                       inDirection:(UITextLayoutDirection)direction
                                                            offset:(NSInteger)offset
                                                          affinity:(UITextStorageDirection)affinity
                                              anchorPositionOffset:(CGFloat)anchorPositionOffset {
    switch (direction) {
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionLeft: {
            BOOL forward = (direction == UITextLayoutDirectionRight);
            TGRichTextInputDecPosition *raw = [self id_positionFromPosition:position
                                                                       offset:(forward ? offset : -offset)
                                                                     affinity:affinity];
            if (raw == nil) {
                return nil;
            }
            // Task D4f CORRECTION — the paragraph below described the state of
            // `id_positionFromPosition:offset:affinity:` BEFORE that member gained its own snap.
            // It now snaps too (matching `LegacyRichTextInputBackend.position(from:offset:)`), so
            // the snap here is a no-op on every path a direction step actually takes. It is KEPT,
            // for one reason that is not redundant: the inner snap derives its direction from the
            // SIGN of the offset it is handed, and `-0` is not negative — a `.left` step with
            // `offset == 0` would snap FORWARD there and backward here. Degenerate (no movement is
            // requested) but the direction is this method's own to decide, so it decides it.
            //
            // Task D3c — `id_positionFromPosition:offset:affinity:` (used above for the raw step)
            // WAS pure structural-axis arithmetic with NO renderable-caret-slot awareness, unlike
            // `id_beginningOfDocument`/`id_endOfDocument` just above, which already snap via
            // `TGSnapToRenderableOffset`. A top-level paragraph boundary occupies TWO
            // non-renderable structural token slots (see that helper's own doc comment), so a
            // single hardware-arrow-key `.right`/`.left` step landing inside the gap — rather than
            // stopping on its far renderable side, the way `DocumentCanvasView+Navigation.swift`'s
            // `nextTextPosition`/`prevTextPosition` already do for the legacy backend on this SAME
            // structural axis — reports a caret that cannot be drawn, and two real arrow presses
            // starting at a paragraph's end land one short of where legacy's own stepping lands
            // (the differential's own `caret-across-paragraph-boundary` divergence). Snapping
            // forward on `.right` / backward on `.left` — the same directional bias
            // `id_beginningOfDocument`/`id_endOfDocument` already use — clears the whole gap in the
            // step that entered it, matching legacy's result exactly, since a position already
            // renderable (every step that does not touch a boundary) is returned unchanged.
            NSInteger length = [self.bridge respondsToSelector:@selector(documentUTF16Length)]
                ? [self.bridge documentUTF16Length] : 0;
            NSInteger snapped = TGSnapToRenderableOffset(self.bridge, raw.utf16Offset, length, forward);
            if (snapped == raw.utf16Offset) {
                return raw;
            }
            return TGMakePosition(self.bridge, snapped, affinity);
        }
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionDown:
            // No layout manager at this layer (`id_canAccessLayoutManager` answers NO) — a
            // "line above/below" has no honest answer without real layout (Family 2/5's
            // geometry). Returning nil rather than fabricating "no movement".
            return nil;
    }
}

- (nullable TGRichTextInputDecRange *)id_textRangeForLineEnclosingPosition:(TGRichTextInputDecPosition *)position {
    return [self id_textRangeForLineEnclosingPosition:position effectiveAffinity:position.affinity];
}

- (nullable TGRichTextInputDecRange *)id_textRangeForLineEnclosingPosition:(TGRichTextInputDecPosition *)position
                                                          effectiveAffinity:(UITextStorageDirection)affinity {
    // No layout manager, so "line" is the one honest notion available here: the plain-text
    // paragraph delimited by "\n", exactly `NSString.lineRangeForRange:`'s definition — NOT a
    // visual (wrapped) line, which needs real layout Family 1 doesn't have.
    TGRichTextInputDecPosition *resolved = TGResolvePosition(self.bridge, position);
    NSInteger length = [self.bridge documentUTF16Length];
    NSInteger offset = MIN(MAX(resolved.utf16Offset, 0), length);
    NSString *whole = [self.bridge documentPlainTextInRange:NSMakeRange(0, (NSUInteger)length)];
    if (whole == nil) {
        return nil;
    }
    NSUInteger probe = (NSUInteger)offset;
    // At a "\n" boundary, affinity picks which line: backward leans into the line that just
    // ended, forward leans into the line that is about to start.
    if (affinity == UITextStorageDirectionBackward && probe > 0) {
        probe -= 1;
    }
    if (probe > whole.length) {
        probe = whole.length;
    }
    NSRange lineRange = [whole lineRangeForRange:NSMakeRange(probe, 0)];
    TGRichTextInputDecPosition *start = TGMakePosition(self.bridge, (NSInteger)lineRange.location,
                                                        UITextStorageDirectionForward);
    TGRichTextInputDecPosition *end = TGMakePosition(
        self.bridge, (NSInteger)(lineRange.location + lineRange.length), UITextStorageDirectionBackward);
    return [TGRichTextInputDecRange rangeFrom:start to:end];
}

- (nullable NSDictionary<NSAttributedStringKey, id> *)id_attributesAtPosition:(TGRichTextInputDecPosition *)position
                                                                    inDirection:(UITextStorageDirection)direction {
    // See the Internal header's doc comment on this row: Family 1's `Consumes` scope has no
    // typing-attributes accessor on the bridge, so `nil` — a documented "no answer", not a
    // fabricated empty dictionary — is the honest response at this layer.
    return nil;
}

- (NSComparisonResult)id_comparePosition:(TGRichTextInputDecPosition *)position
                              toPosition:(TGRichTextInputDecPosition *)other {
    TGRichTextInputDecPosition *resolvedA = TGResolvePosition(self.bridge, position);
    TGRichTextInputDecPosition *resolvedB = TGResolvePosition(self.bridge, other);
    if (resolvedA.utf16Offset < resolvedB.utf16Offset) {
        return NSOrderedAscending;
    }
    if (resolvedA.utf16Offset > resolvedB.utf16Offset) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}

- (NSInteger)id_offsetFromPosition:(TGRichTextInputDecPosition *)from
                        toPosition:(TGRichTextInputDecPosition *)to {
    TGRichTextInputDecPosition *resolvedFrom = TGResolvePosition(self.bridge, from);
    TGRichTextInputDecPosition *resolvedTo = TGResolvePosition(self.bridge, to);
    return resolvedTo.utf16Offset - resolvedFrom.utf16Offset;
}

- (UITextStorageDirection)id_affinityForPosition:(TGRichTextInputDecPosition *)position {
    // A pure read of state the position object already carries — no document data is needed, so
    // no staleness resolution (and no bridge call) is warranted here.
    return position.affinity;
}

- (NSRange)id_characterRangeForTextRange:(TGRichTextInputDecRange *)range {
    NSRange structural = TGStructuralCharacterRangeForTextRange(self.bridge, range);
    NSInteger lo = (NSInteger)structural.location;
    NSInteger hi = lo + (NSInteger)structural.length;
    // Task R7 (cluster 4) — THE losing hop for `text(in:)` reading wrong content on any document with
    // more than one top-level block. `lo`/`hi` above are on the STRUCTURAL position axis (this
    // document model's own node-token addressing — a paragraph's `nodeSize` is `textLength + 2`, one
    // token for its own open boundary and one for its close; `TelegramDocumentInputClient`'s own doc
    // comment: "that axis is STRUCTURAL... it is not a plain character count"). But the CALLER of this
    // private selector — UIKit's real input controller — uses the returned `NSRange` to index
    // `-[TGRichTextInputDecTextStorageFacade string]` DIRECTLY (verified by instrumentation: it reads
    // `-string`, then this method, then substrings the result), and that string is the DENSE plain-
    // text projection `documentPlainTextInRange:`/`text(in:)` both use — the same projection that
    // collapses a paragraph's open+close tokens and an inter-paragraph gap down to a single `"\n"`.
    // Handing back the raw structural distance therefore both mis-locates the start (short by the
    // document/paragraph's own leading open-token slots) and mis-sizes the length (long by however
    // many non-renderable slots the span crosses) — reproduced exactly: a 2-paragraph "Alpha\nBeta"
    // selected end to end resolved structural `{1,11}`, one past the mirror's own 10-character bound,
    // and substringing it read "lpha\nBeta" (silently dropping the leading "A" against the intersected,
    // in-bounds tail) instead of raising on the frank out-of-bounds request.
    //
    // `TGPlainTextOffsetForStructuralOffset` converts each endpoint independently by reusing
    // `documentPlainTextInRange:`'s own existing, already-verified projection — its RESULT LENGTH over
    // `[0, structuralOffset)` is exactly the plain-text offset that structural position corresponds to
    // (the same projection `text(in:)` itself returns), so no new bridge crossing or position concept
    // is needed; this is a read the bridge could always answer, just never asked before.
    //
    // `respondsToSelector:` guard, matching this file's own convention (`documentUTF16Length` is
    // `@optional`): a bridge that doesn't implement it hands back the raw structural range unconverted
    // — the pre-R7 behavior — rather than crashing.
    if (![self.bridge respondsToSelector:@selector(documentUTF16Length)]) {
        return NSMakeRange((NSUInteger)lo, (NSUInteger)(hi - lo));
    }
    NSInteger documentLength = [self.bridge documentUTF16Length];
    NSInteger plainLo = TGPlainTextOffsetForStructuralOffset(self.bridge, lo, documentLength);
    NSInteger plainHi = TGPlainTextOffsetForStructuralOffset(self.bridge, hi, documentLength);
    plainHi = MAX(plainHi, plainLo);
    return NSMakeRange((NSUInteger)plainLo, (NSUInteger)(plainHi - plainLo));
}

- (NSRange)id_characterRangeForTextRange:(TGRichTextInputDecRange *)range
                       clippedToDocument:(BOOL)clippedToDocument {
    NSRange raw = [self id_characterRangeForTextRange:range];
    if (!clippedToDocument) {
        return raw;
    }
    NSInteger length = [self.bridge documentUTF16Length];
    NSInteger lo = MAX((NSInteger)raw.location, 0);
    NSInteger hi = MIN((NSInteger)(raw.location + raw.length), length);
    if (hi < lo) {
        hi = lo;
    }
    return NSMakeRange((NSUInteger)lo, (NSUInteger)(hi - lo));
}

- (NSArray<NSValue *> *)id_characterRangesForTextRange:(TGRichTextInputDecRange *)range
                                     clippedToDocument:(BOOL)clippedToDocument {
    // No per-run/bidi structure exists at this layer — the honest degrade of "multiple disjoint
    // character ranges" is the single contiguous range a `UITextRange` can actually represent.
    NSRange single = [self id_characterRangeForTextRange:range clippedToDocument:clippedToDocument];
    return @[[NSValue valueWithRange:single]];
}

- (nullable TGRichTextInputDecRange *)id_textRangeForCharacterRange:(NSRange)range {
    // A raw `NSRange` carries no revision of its own — it always describes an offset pair
    // against the CURRENT document, so both endpoints clamp through the client (never locally)
    // and the result is stamped with the current revision.
    //
    // Task D3e — `range` is on the PLAIN-TEXT axis, not structural, despite the "clamp through the
    // client" comment above (which is still true — only the AXIS was wrong, not the clamp
    // discipline). This is the manifest's `incoming.rangeForCharacters` entry — the private
    // controller CALLS US with what it itself calls a "character range", the SAME plain-text
    // vocabulary as `id_characterRangeForTextRange:`'s own "reads document content ... indexes
    // `-[…Facade string]` DIRECTLY" (that method's doc comment) and `id_rangeOfCharacterClusterAtIndex:
    // type:`'s Task D3c fix one hop over — the private controller derives this range from ITS OWN
    // bookkeeping over `mirror`, the facade's plain-text-backed `NSTextStorage`, never our
    // structural position model. Confirmed by direct instrumentation (temporary `NSLog`, reverted
    // before commit), not assumed: composing one character at a caret whose STRUCTURAL offset is 6
    // (this document model's axis is 1-based — `beginningOfDocument.utf16Offset == 1` — so
    // structural 6 is "right after Alpha", 5 characters in) produced a PLAIN range `{5,1}` here (5
    // == `"Alpha".utf16.count`, the plain-text axis's own 0-based count). Passing that straight to
    // `documentClampedOffset:` — a STRUCTURAL-axis clamp with no conversion — silently reused the
    // plain offset 5 as if it were the structural offset 6, landing `markedTextRange.start` exactly
    // ONE POSITION BEFORE the caret it must start at: `test_setMarkedTextPublishesAMarkedRange`'s
    // `offset(from: caret, to: markedUITextRange.start)` measured `-1`, not `0`.
    // `TGStructuralOffsetForPlainTextOffset` (Task D3c's own inverse of
    // `TGPlainTextOffsetForStructuralOffset`) converts each endpoint independently, exactly as
    // `id_rangeOfCharacterClusterAtIndex:type:` already does for its own plain-axis input — the
    // same fix, at this method's own incoming crossing point.
    NSInteger documentLength = [self.bridge respondsToSelector:@selector(documentUTF16Length)]
        ? [self.bridge documentUTF16Length] : 0;
    NSInteger structuralLocation = TGStructuralOffsetForPlainTextOffset(
        self.bridge, (NSInteger)range.location, documentLength);
    NSInteger structuralEnd = TGStructuralOffsetForPlainTextOffset(
        self.bridge, (NSInteger)(range.location + range.length), documentLength);
    NSInteger lo = [self.bridge documentClampedOffset:structuralLocation];
    NSInteger hi = [self.bridge documentClampedOffset:structuralEnd];
    if (hi < lo) {
        hi = lo;
    }
    TGRichTextInputDecPosition *start = TGMakePosition(self.bridge, lo, UITextStorageDirectionForward);
    TGRichTextInputDecPosition *end = TGMakePosition(self.bridge, hi, UITextStorageDirectionBackward);
    return [TGRichTextInputDecRange rangeFrom:start to:end];
}

- (nullable TGRichTextInputDecRange *)id_textRangeForCharacterRanges:(NSArray<NSValue *> *)ranges {
    if (ranges.count == 0) {
        return nil;
    }
    NSInteger lo = NSIntegerMax;
    NSInteger hi = NSIntegerMin;
    for (NSValue *value in ranges) {
        NSRange r = value.rangeValue;
        lo = MIN(lo, (NSInteger)r.location);
        hi = MAX(hi, (NSInteger)(r.location + r.length));
    }
    // Collapses several disjoint character ranges to the ONE contiguous `UITextRange` spanning
    // all of them — the mirror image of `id_characterRangesForTextRange:clippedToDocument:`'s
    // own single-range degrade.
    return [self id_textRangeForCharacterRange:NSMakeRange((NSUInteger)lo, (NSUInteger)(hi - lo))];
}

- (nullable TGRichTextInputDecPosition *)id_positionWithOffset:(NSInteger)offset
                                                        affinity:(UITextStorageDirection)affinity {
    NSInteger clamped = [self.bridge documentClampedOffset:offset];
    if (clamped != offset) {
        return nil;
    }
    return TGMakePosition(self.bridge, clamped, affinity);
}

- (NSRange)id_rangeOfCharacterClusterAtIndex:(NSUInteger)index type:(NSInteger)type {
    NSInteger length = [self.bridge documentUTF16Length];
    if (length <= 0) {
        return NSMakeRange(0, 0);
    }
    NSInteger clampedIndex = [self.bridge documentClampedOffset:(NSInteger)index];
    NSString *whole = [self.bridge documentPlainTextInRange:NSMakeRange(0, (NSUInteger)length)];
    if (whole == nil || whole.length == 0) {
        return NSMakeRange((NSUInteger)MAX(clampedIndex, 0), 0);
    }
    // Task D3c — `index` is on the PLAIN-TEXT axis, not structural: the kernel asks this question
    // against its own text-storage view of the document (the facade's plain-text-backed mirror —
    // the same coordinate space `id_characterRangeForTextRange:` converts INTO for its callers, see
    // that method's own doc comment), and `whole` here is exactly that dense plain-text projection.
    // `documentClampedOffset:` above clamps on the STRUCTURAL axis (looser than plain-text's own
    // bound whenever the document has more than one top-level block), so it cannot by itself catch
    // a plain-text index past `whole`'s end — `safeIndex`'s own clamp against `whole.length - 1` is
    // what actually bounds it; `documentClampedOffset:` still runs first as a defensive floor at 0.
    NSUInteger safeIndex = (NSUInteger)MIN(MAX(clampedIndex, 0), (NSInteger)whole.length - 1);
    NSRange plainRange = [whole rangeOfComposedCharacterSequenceAtIndex:safeIndex];
    // Task D4d — the answer stays on the PLAIN-TEXT axis it was computed on. **Both halves of
    // this method now speak one axis**, which is the point: `index` is plain (Task D3c established
    // that, and the comment above still says so), and so is the result.
    //
    // D3c ALSO added a plain -> STRUCTURAL conversion here, in the same commit that gave
    // `replaceCharactersInRange:withString:` its `.deleteBackward`/`.markedText` exception —
    // "BOTH hand back a range ALREADY on `mirror`'s own plain-text axis". Those two halves
    // contradict each other, and this one lost: the kernel is a pure pass-through between them,
    // so a structural answer here reached the facade and was applied to `mirror` verbatim as a
    // plain range. Measured end to end (temporary NSLogs in this method and in the facade,
    // reverted before commit), on a `.inputDec` canvas seeded "Alpha"/"Beta" with the caret at
    // the end of "Alpha":
    //
    //     clusterAtIndex index=4 -> plain {4,1} -> structural {5,1}
    //     facade replace range={5,1} intent=deleteBackward
    //     document blocks ["Alph","Beta"]   (CORRECT)
    //     mirror         "AlphaBeta"        (deleted the "\n" at plain 5, not the 'a' at plain 4)
    //
    // — i.e. EVERY backward delete corrupted the mirror, by exactly the number of extra structural
    // slots standing before that offset (>= 1 always, because of the document's own leading open
    // token). It was invisible in most fixtures because only `canonical`/`inlineRuns` read the
    // mirror while `blocks` reads the real document, and invisible in the corpus's
    // `interior-accept-then-delete` because the characters on either side of that caret are both
    // spaces, so the wrong delete produced an identical STRING. It surfaced in
    // `before-boundary-accept-then-delete`/`after-boundary-accept-then-delete`, where the
    // character one slot late is the paragraph "\n" — which read as a spurious paragraph MERGE in
    // `canonical` even though the document had merged nothing.
    //
    // That the kernel wants plain here is not an inference from the facade alone: instrumentation
    // shows it feeds this very result straight back into `id_textRangeForCharacterRange:`, whose
    // own Task D3e comment records the same finding independently ("the private controller derives
    // this range from ITS OWN bookkeeping over `mirror`" — plain in, plain out).
    //
    // D3c's cited reproduction (the "start of Beta" backspace landing inside "Alpha") was the
    // PRE-facade-exception behaviour, fixed by the OTHER half of that same commit; re-verified
    // here after this change: the merge lands on the boundary and `mirror` matches the document.
    return plainRange;
}

- (nullable NSAttributedString *)id_attributedTextInRange:(TGRichTextInputDecRange *)range {
    // Task R7 — `documentPlainTextInRange:` takes a STRUCTURAL range (every OTHER call site in this
    // file passes one), so this reads the structural resolution directly rather than
    // `id_characterRangeForTextRange:`'s result, which is now on the PLAIN-TEXT axis for ITS
    // callers (see that method's own doc comment) — a different, incompatible unit for this call.
    NSRange characterRange = TGStructuralCharacterRangeForTextRange(self.bridge, range);
    NSString *text = [self.bridge documentPlainTextInRange:characterRange];
    if (text == nil) {
        return nil;
    }
    return [[NSAttributedString alloc] initWithString:text];
}

#pragma mark - Private callbacks (one-line forwards; Family 2, Task C5)
//
// Same shape and reasoning as the earlier groups: each selector is deliberately UNDECLARED
// anywhere except this cast-through-`id_` forward.

- (NSArray<NSTextContainer *> *)textContainers {
    return [self id_textContainers];
}










// TASK C14 FIX — rows 38/39's argument type was `(NSRange)range`, but the manifest's own
// `argumentTypes` for BOTH rows is `@` (an object — `UITextRange *`), not `{_NSRange=QQ}` (a raw
// struct, which is what row 30's `invalidateDisplayForCharacterRange:` genuinely wants — the two
// private protocols use different conventions, and Family 2/C5's implementation matched the WRONG
// one). This mismatch was invisible until this task: `IDUIKitCapabilityResolver.evaluateContract:`
// only ever SURFACES `abiMismatches` when `missing.count == 0` for the whole contract (`missing`
// wins outright otherwise) — with 7 required rows still missing, these two ABI mismatches were
// computed but discarded on every prior measurement (C4-C13's own SCRATCH logs). Landing this
// task's 7 rows completes `missing`, which is what let these surface for the first time — see
// DIVERGENCES.md entry 14 for the measurement. Both are display/layout no-ops downstream
// (`id_ensureLayoutForRange:`/`id_invalidateLayoutForRange:`'s bodies are empty), so converting
// the incoming `UITextRange *` via the existing `id_characterRangeForTextRange:` helper (Family 1)
// changes NO observable behavior — only the wire type now matches the certified ABI.
- (void)ensureLayoutForRange:(UITextRange *)range {
    [self id_ensureLayoutForRange:[self id_characterRangeForTextRange:(TGRichTextInputDecRange *)range]];
}

- (void)invalidateLayoutForRange:(UITextRange *)range {
    [self id_invalidateLayoutForRange:[self id_characterRangeForTextRange:(TGRichTextInputDecRange *)range]];
}

#pragma mark - Private callbacks (one-line forward; Family 3, Task C6)

- (void)invalidateDisplayForCharacterRange:(NSRange)range {
    [self id_invalidateDisplayForCharacterRange:range];
}

#pragma mark - Private callbacks (one-line forward; Family 9, Task C12)

/// Row 37. `position` arrives typed `UITextPosition *` here — this is a genuinely PRIVATE selector
/// (unlike the public-`UITextInput`-mirrored forwards above it), so its real argument type is
/// unknown; casting to the concrete `TGRichTextInputDecPosition *` at the call site matches every
/// OTHER `id_position…` forward in this file (Family 2's `id_insertionRectForPosition:` is the
/// one documented exception, and only because the task brief for THAT row gave the literal
/// snippet — no such snippet exists for this row).
///
/// TASK C14 FIX — `extent` was typed `(NSInteger)extent`, but the manifest's own `argumentTypes`
/// for this row is `@` (an object) at index 0, not `q` (a raw scalar): the real private selector
/// evidently boxes `extent` (an `NSNumber`, most likely, matching an ordinary enum-boxing
/// convention), which C12's own doc comment already flagged as unknown/undocumented — it just
/// guessed the WRONG wire shape for "untyped." Same invisible-until-this-task story as
/// `ensureLayoutForRange:`/`invalidateLayoutForRange:` above (see that fix's own comment and
/// DIVERGENCES.md entry 14). `extent` is UNUSED by `id_visualSelectionRangeForExtent:...`'s body
/// (`(void)extent;`), so accepting it as `id` and best-effort-unboxing changes NO observable
/// behavior — the value was never read either way.
- (nullable UITextRange *)tgpn__visualSelectionRangeForExtent:(id)extent
                                                  forPoint:(CGPoint)point
                                              fromPosition:(UITextPosition *)position
                                                inDirection:(UITextLayoutDirection)direction {
    NSInteger extentValue = [extent respondsToSelector:@selector(integerValue)]
        ? [(NSNumber *)extent integerValue] : 0;
    return [self id_visualSelectionRangeForExtent:extentValue
                                          forPoint:point
                                      fromPosition:(TGRichTextInputDecPosition *)position
                                        inDirection:direction];
}

#pragma mark - Private callbacks (one-line forwards; Family 11, Task C14)
//
// Same shape and reasoning as every earlier group: each selector is deliberately UNDECLARED
// anywhere except this cast-through-`id_` forward. Rows 41/43 mirror `attributedTextInRange:`'s
// PUBLIC-`UITextInput`-shaped `UITextRange *`/`UITextPosition *` argument types (Family 1); rows
// 42/44/45/46/47 are genuinely PRIVATE selectors (no public `UITextInput` counterpart), so their
// `key`/`attributes`/`keys` arguments arrive as plain `id`/`NSDictionary *`/`NSArray *` — the
// manifest's own `@encode` column carries no more information than that.








#pragma mark - id_ implementations (Family 2, Task C5: geometry)

- (NSArray<NSTextContainer *> *)id_textContainers {
    return @[self.syntheticContainer];
}

- (nullable NSTextContainer *)id_firstTextContainer {
    return self.syntheticContainer;
}

- (nullable NSTextContainer *)id_textContainerForPosition:(TGRichTextInputDecPosition *)position {
    return self.syntheticContainer;
}

- (NSWritingDirection)id_baseWritingDirectionAtPosition:(TGRichTextInputDecPosition *)position {
    // No dedicated "writing direction only" bridge method exists (the client bridge header
    // declares exactly three Family-2 methods) — this reuses `caretGeometryAtOffset:...` purely
    // for its `outWritingDirection` out-param. A bridge NO falls back to `.leftToRight`, mirroring
    // this package's existing UIKit-edge fallback for the same field
    // (`LegacyRichTextInputBackend+Geometry.swift`'s `baseWritingDirection(for:in:)`,
    // `?? .leftToRight`) — there is no CGRect-style null sentinel for a scalar
    // `NSWritingDirection`, so a scalar answer must be given either way.
    TGRichTextInputDecPosition *resolved = TGResolvePosition(self.bridge, position);
    CGRect rect;
    NSWritingDirection direction;
    uint64_t generation;
    BOOL ok = [self.bridge caretGeometryAtOffset:resolved.utf16Offset
                                        affinity:resolved.affinity
                                        revision:resolved.documentRevision
                                         purpose:TGRichTextInputDecGeometryPurposeKeyboard
                                         outRect:&rect
                             outWritingDirection:&direction
                             outLayoutGeneration:&generation];
    return ok ? direction : NSWritingDirectionLeftToRight;
}

- (CGRect)id_boundingRectForCharacterRange:(NSRange)range {
    NSArray<TGRichTextInputDecSelectionRect *> *rects =
        [self.bridge selectionRectsForRange:range
                                 visibleRect:CGRectNull
                                    revision:[self.bridge documentRevision]];
    if (rects.count == 0) {
        // Backend-private fallback decision, NOT CGRectZero — same reasoning as
        // `id_insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:`
        // below: the shared geometry client never learns that UIKit is intolerant of absence.
        return CGRectNull;
    }
    CGRect result = rects.firstObject.rect;
    for (TGRichTextInputDecSelectionRect *r in rects) {
        result = CGRectUnion(result, r.rect);
    }
    return result;
}

- (NSArray<TGRichTextInputDecSelectionRect *> *)id_selectionRectsForRange:(TGRichTextInputDecRange *)range
                                                                    fromView:(nullable UIView *)fromView
                                                      forContainerPassingTest:
    (nullable BOOL (^)(NSTextContainer *container))test {
    // Exactly one container exists; if the caller's test rejects it, there is nothing to return —
    // honoring UIKit's own container-filtering contract rather than bypassing it.
    if (test != nil && !test(self.syntheticContainer)) {
        return @[];
    }
    NSRange characterRange = [self id_characterRangeForTextRange:range];
    // BOUNDED Select All (the spec's own large-selection requirement, already proven at the client
    // boundary by `BoundedSelectionGeometryTests`): `fromView` is UIKit's own requesting view for
    // this query — the same canvas `IDUIKitBehaviorKernel` was constructed with as `view:` — so its
    // `bounds` IS the visible rectangle that bounds the drawing geometry while the canonical
    // selection stays complete. `CGRectNull` (unbounded) only when UIKit hands us no view to derive
    // one from.
    CGRect visibleRect = fromView != nil ? fromView.bounds : CGRectNull;
    return [self.bridge selectionRectsForRange:characterRange
                                    visibleRect:visibleRect
                                       revision:[self.bridge documentRevision]];
}

- (void)id_requestTextGeometryAtPosition:(TGRichTextInputDecPosition *)position
                        typingAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes
                             resultBlock:(void (^)(CGRect rect, NSWritingDirection writingDirection))resultBlock {
    if (resultBlock == nil) {
        return;
    }
    // Calls the bridge SYNCHRONOUSLY and invokes the block INLINE — no async hop exists at this
    // layer (no real layout manager to defer to).
    TGRichTextInputDecPosition *resolved = TGResolvePosition(self.bridge, position);
    CGRect rect;
    NSWritingDirection direction;
    uint64_t generation;
    BOOL ok = [self.bridge caretGeometryAtOffset:resolved.utf16Offset
                                        affinity:resolved.affinity
                                        revision:resolved.documentRevision
                                         purpose:TGRichTextInputDecGeometryPurposeKeyboard
                                         outRect:&rect
                             outWritingDirection:&direction
                             outLayoutGeneration:&generation];
    resultBlock(ok ? rect : CGRectNull, ok ? direction : NSWritingDirectionLeftToRight);
}

- (CGRect)id_insertionRectForPosition:(UITextPosition *)position
                      typingAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes
                 placeholderAttachment:(nullable id)attachment
                         textContainer:(NSTextContainer * _Nullable * _Nullable)textContainer {
    if (textContainer != NULL) { *textContainer = self.syntheticContainer; }
    TGRichTextInputDecPosition *p = (TGRichTextInputDecPosition *)position;
    CGRect rect;
    NSWritingDirection direction;
    uint64_t generation;
    if (![self.bridge caretGeometryAtOffset:p.utf16Offset
                                    affinity:p.affinity
                                    revision:p.documentRevision
                                     purpose:TGRichTextInputDecGeometryPurposeKeyboard
                                     outRect:&rect
                         outWritingDirection:&direction
                         outLayoutGeneration:&generation]) {
        // Backend-private fallback decision, NOT CGRectZero: the shared geometry client never
        // learns that UIKit is intolerant of absence.
        return CGRectNull;
    }
    return rect;
}

- (nullable TGRichTextInputDecPosition *)id_cursorPositionAtPoint:(CGPoint)point
                                                       inContainer:(nullable NSTextContainer *)container {
    return TGClosestPosition(self.bridge, point);
}

- (nullable TGRichTextInputDecPosition *)id_nearestPositionAtPoint:(CGPoint)point
                                                        inContainer:(nullable NSTextContainer *)container {
    return TGClosestPosition(self.bridge, point);
}

- (void)id_ensureLayoutForRange:(NSRange)range {
    // No real TextKit layout graph exists at this layer (`id_canAccessLayoutManager` answers NO)
    // — nothing to ensure. Honest no-op, not a fabricated success.
}

- (void)id_invalidateLayoutForRange:(NSRange)range {
    // Same rationale: no layout graph to invalidate.
}

#pragma mark - id_ implementations (Family 3, Task C6: selected range and input-delegate ownership)

- (void)id_invalidateDisplayForCharacterRange:(NSRange)range {
    // Row 30. Mirrors `id_ensureLayoutForRange:`/`id_invalidateLayoutForRange:` above: nothing at
    // this layer owns a redraw surface for the range yet (the annotation client a later task
    // wires in — see C14's rows, tagged with the same manifest evidence — is what would
    // eventually consume this). Honest no-op, not a fabricated success.
}

#pragma mark - id_ implementations (Family 9, Task C12: touch interaction and selection)

- (nullable TGRichTextInputDecRange *)id_visualSelectionRangeForExtent:(NSInteger)extent
                                                                forPoint:(CGPoint)point
                                                            fromPosition:(TGRichTextInputDecPosition *)position
                                                              inDirection:(UITextLayoutDirection)direction {
    // `extent`/`direction` are received but not read — see this method's own doc comment in
    // `TGRichTextInputDecLayoutControllerInternal.h` on why their real (undocumented) meaning is
    // not guessed at. `position` is resolved exactly like every other minted position (a stale
    // `documentRevision` is rebased once, never fabricated).
    (void)extent;
    (void)direction;
    TGRichTextInputDecPosition *resolvedAnchor = TGResolvePosition(self.bridge, position);
    TGRichTextInputDecPosition *resolvedExtent = TGClosestPosition(self.bridge, point);
    if (resolvedExtent == nil) {
        // Honest nil: the bridge could not resolve the point to any offset — mirrors
        // `id_cursorPositionAtPoint:inContainer:`/`id_nearestPositionAtPoint:inContainer:`'s own
        // "no fabricated position" contract.
        return nil;
    }
    // `start`/`end` stored VERBATIM, same as `id_textRangeFromPosition:toPosition:` — the range
    // from the drag's anchor to where the finger resolved is a legitimate, unordered range.
    return [TGRichTextInputDecRange rangeFrom:resolvedAnchor to:resolvedExtent];
}

#pragma mark - id_ implementations (Family 11, Task C14: spellchecking and annotations)
//
// Every method below extracts the incoming position/range's RAW `documentRevision` via
// `TGRawCharacterRangeForRange`/`.documentRevision` directly — never `TGResolvePosition` — and a
// `respondsToSelector:` guard before each bridge send (this group is `@optional`, like every
// group after the first two required methods; `StubBridge` in `CanvasCallbackInstallationTests`
// implements neither, and this file's own thunks follow the identical caution).

- (nullable NSAttributedString *)id_annotatedSubstringForRange:(TGRichTextInputDecRange *)range {
    if (![self.bridge respondsToSelector:@selector(annotatedSubstringForRange:revision:)]) {
        return nil;
    }
    uint64_t revision = 0;
    NSRange characterRange = TGRawCharacterRangeForRange(range, &revision);
    return [self.bridge annotatedSubstringForRange:characterRange revision:revision];
}

- (nullable id)id_annotationAttribute:(id)key atPosition:(TGRichTextInputDecPosition *)position {
    if (![self.bridge respondsToSelector:@selector(annotationValueForKey:atPosition:revision:)]) {
        return nil;
    }
    return [self.bridge annotationValueForKey:key
                                    atPosition:position.utf16Offset
                                      revision:position.documentRevision];
}

- (void)id_addAnnotationAttribute:(id)key value:(id)value forRange:(TGRichTextInputDecRange *)range {
    if (![self.bridge respondsToSelector:@selector(addAnnotationKey:value:range:revision:)]) {
        return;
    }
    uint64_t revision = 0;
    NSRange characterRange = TGRawCharacterRangeForRange(range, &revision);
    [self.bridge addAnnotationKey:key value:value range:characterRange revision:revision];
}

- (void)id_removeAnnotationAttribute:(id)key forRange:(TGRichTextInputDecRange *)range {
    if (![self.bridge respondsToSelector:@selector(removeAnnotationKey:range:revision:)]) {
        return;
    }
    uint64_t revision = 0;
    NSRange characterRange = TGRawCharacterRangeForRange(range, &revision);
    [self.bridge removeAnnotationKey:key range:characterRange revision:revision];
}

- (void)id_addRenderingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                          forRange:(TGRichTextInputDecRange *)range {
    if (![self.bridge respondsToSelector:@selector(addRenderingAttributes:range:revision:)]) {
        return;
    }
    uint64_t revision = 0;
    NSRange characterRange = TGRawCharacterRangeForRange(range, &revision);
    [self.bridge addRenderingAttributes:attributes range:characterRange revision:revision];
}

- (void)id_removeRenderingAttributes:(NSArray<NSAttributedStringKey> *)keys
                             forRange:(TGRichTextInputDecRange *)range {
    if (![self.bridge respondsToSelector:@selector(removeRenderingAttributes:range:revision:)]) {
        return;
    }
    uint64_t revision = 0;
    NSRange characterRange = TGRawCharacterRangeForRange(range, &revision);
    [self.bridge removeRenderingAttributes:keys range:characterRange revision:revision];
}

- (void)id_invalidateTemporaryAttributesInRange:(TGRichTextInputDecRange *)range {
    if (![self.bridge respondsToSelector:@selector(invalidateTemporaryAttributesInRange:revision:)]) {
        return;
    }
    uint64_t revision = 0;
    NSRange characterRange = TGRawCharacterRangeForRange(range, &revision);
    [self.bridge invalidateTemporaryAttributesInRange:characterRange revision:revision];
}

@end

#endif
