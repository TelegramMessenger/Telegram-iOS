// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

// Only a FORWARD declaration of the bridge protocol, deliberately — `TGRichTextInputDecClientBridge.h`
// imports THIS header (for `TGRichTextInputDecIntent` / `TGRichTextInputDecMutationOutcome`, both
// declared below), so a reciprocal full `#import` here would make the two headers' processing order
// load-bearing (whichever is imported first would see the other only partially expanded). Only the
// PROTOCOL NAME is needed to declare the `bridge` property below; the full protocol (with the C7
// method group) is consumed only from `TGRichTextInputDecTextStorageFacade.m`, which imports the real
// header directly.
@protocol TGRichTextInputDecClientBridging;

NS_ASSUME_NONNULL_BEGIN

/// Family 4 (Task C7) — the intent latch UIKit's raw `replaceCharactersInRange:withString:` cannot
/// carry on its own. Set by the pre-mutation canvas thunks
/// (`TGRichTextInputDecCanvasCallbacks.m`) before UIKit drives a storage mutation, consumed and reset
/// to `.programmatic` by `TGRichTextInputDecTextStorageFacade` at the top of every mutation — a
/// single-transaction latch, never sticky across two mutations.
typedef NS_ENUM(NSInteger, TGRichTextInputDecIntent) {
    TGRichTextInputDecIntentProgrammatic,
    TGRichTextInputDecIntentInsertText,
    TGRichTextInputDecIntentMarkedText,
    TGRichTextInputDecIntentDeleteBackward,
    TGRichTextInputDecIntentPaste,
    TGRichTextInputDecIntentDictation,
};

/// What a two-phase mutation transaction settled on, reported back to the façade's caller through an
/// out-parameter (a plain C struct, not an object, so it crosses the `TGRichTextInputDecPerform`-style
/// boundary without any allocation).
typedef struct {
    uint64_t revision;
    NSInteger selectionAnchor;
    NSInteger selectionHead;
} TGRichTextInputDecMutationOutcome;

/// The `NSTextStorage` UIKit's private input controller mutates through — never Telegram's own
/// document model. `NSTextStorage` is ABSTRACT in four primitives (`string`,
/// `attributesAtIndex:effectiveRange:`, `replaceCharactersInRange:withString:`,
/// `setAttributes:range:`); this class overrides all four. UIKit calls `string` and
/// `attributesAtIndex:effectiveRange:` constantly during layout and selection, so `mirror` — a plain
/// `NSMutableAttributedString` — answers those reads; Telegram's document (behind `bridge`) remains
/// the WRITE authority. A range replace routes through `bridge`'s two-phase
/// prepare/commit transaction (Family 4's `prepareAndCommitReplacementInRange:...`) BEFORE the mirror
/// is touched — a rejected or no-change transaction leaves the mirror, and therefore what UIKit sees
/// via `string`, untouched.
@interface TGRichTextInputDecTextStorageFacade : NSTextStorage

/// Weak: the Swift-side client bridge owns this façade (mirrors the layout controller's own
/// `textStorageFacade` back-pointer shape), not the other way around.
@property(nonatomic, weak, nullable) id<TGRichTextInputDecClientBridging> bridge;

/// The latch. Read once per mutation by `replaceCharactersInRange:withString:`, then reset to
/// `.programmatic` — see the type's own doc comment.
@property(nonatomic) TGRichTextInputDecIntent currentIntent;

/// The document revision this façade last observed. Set from the outcome of every successfully
/// applied transaction; read as the `expectedRevision` of the next one.
@property(nonatomic) uint64_t revision;

/// The read model. See the class's own doc comment for why this exists alongside `bridge`.
@property(nonatomic, strong, readonly) NSMutableAttributedString *mirror;

/// Task R3 — the general fix for the "NSMutableRLEArray … Out of bounds" crash class (R1
/// cluster 5 / R3D's diagnostic). `mirror` used to be created empty in `-init` and NEVER
/// seeded, so any UIKit-driven range past its (0-length) backing threw. This method makes
/// `mirror` self-correcting: it compares `mirror.length` against `bridge`'s current
/// `-documentUTF16Length`, and if — and only if — they disagree, replaces the WHOLE mirror
/// content with `bridge`'s current `-documentPlainTextInRange:` projection (also refreshing
/// `revision` from `-documentRevision`). Already-in-sync is a cheap length compare, not a
/// fetch-and-diff, safe to call from a hot path.
///
/// TWO call sites today (see `IDTextEditorBackend.swift`'s own R3 notes):
///   1. `attach(to:)` — the host may already hold real content at attach time (the fake-client
///      test harness does; a re-attach after a mode switch could too).
///   2. **Here in this class**, at the top of `replaceCharactersInRange:withString:` — the load-
///      bearing one: `DocumentCanvasView.setBlocks`/`setParagraphs` (the document-swap primitive
///      `RichTextInputBackendHarness.setParagraphs`/`makeBackendHarness`'s factory call, and — per
///      that file's own doc comment — every production caller except `reload`) does NOT go through
///      `synchronizeAfterExternalChange` at all, by design (that method's own doc comment: a
///      bracket on `setBlocks` itself would fire a COUNTERFEIT external change). So content set
///      that way never reaches (1), and the mirror would still go stale the moment a kernel-driven
///      mutation reads/writes through this witness. Checking here, at the one call site every one
///      of the six `NSMutableRLEArray … Out of bounds` failures in R1's cluster 5 actually threw
///      from (verified in R3D's report — every one is attributed to the SAME source line, this
///      method's own mirror mutation), makes the fix correct regardless of which path last touched
///      the document — never relying on an exhaustive, easily-incomplete enumeration of every
///      Swift call site that can change content.
///
/// A THIRD call site — `synchronizeAfterExternalChange(_:)`, mirroring (1) so a pure read witness
/// (`attributesAtIndex:effectiveRange:`, spell-check, layout queries) could never see stale content
/// even with no subsequent mutation — was tried and REVERTED: it caused a measured regression
/// (`IDBackendFamily6Tests.test_preserveIfRebasablePolicy_keepsTheMarkedRangeWhenRebaseSucceeds`,
/// `rebaseCallCount` 2 → 6). A full mirror-content replace there posts `NSTextStorageEditedCharacters`
/// over the whole prior range, and the REAL kernel's `TGRichTextInputDecLayoutController` (attached
/// as this facade's observer even under the fake-CLIENT test harness — only the Swift-side clients
/// are fake, the kernel itself is real) reacts by re-validating the marked range against the new
/// content, calling back into `documentClient.rebase` extra times the caller does not expect. See
/// `IDTextEditorBackend.swift`'s `synchronizeAfterExternalChange(_:)` for the full account.
- (void)synchronizeMirrorWithDocumentIfNeeded;

@end

NS_ASSUME_NONNULL_END

#endif
