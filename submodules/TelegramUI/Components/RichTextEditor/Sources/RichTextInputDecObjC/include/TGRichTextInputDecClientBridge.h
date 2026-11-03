#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "TGRichTextInputDecSelectionRect.h"
#import "TGRichTextInputDecTextStorageFacade.h"

NS_ASSUME_NONNULL_BEGIN

/// Geometry query purpose — mirrors the shared Swift `RichTextInputGeometryPurpose` (spec
/// `RichTextInputGeometryClient`), reproduced here as an NS_ENUM so the bridge stays ObjC-shaped.
/// `TGRichTextInputDecGeometryPurpose.asSwift` (`IDTextEditorBackendClientBridge.swift`) is the one
/// place the two enums are kept in step.
typedef NS_ENUM(NSInteger, TGRichTextInputDecGeometryPurpose) {
    TGRichTextInputDecGeometryPurposeKeyboard,
    TGRichTextInputDecGeometryPurposeCaret,
    TGRichTextInputDecGeometryPurposeSelectionEndpoint,
    TGRichTextInputDecGeometryPurposeSelectionPresentation,
    TGRichTextInputDecGeometryPurposeLoupe,
    TGRichTextInputDecGeometryPurposeFloatingCursor,
    TGRichTextInputDecGeometryPurposeEditMenu,
    TGRichTextInputDecGeometryPurposeAccessibility,
};

/// Selection-change reason — mirrors the shared Swift `RichTextSelectionChangeReason` (spec
/// `RichTextInputBackend.setSelection(_:reason:)`), reproduced here as an NS_ENUM for the same
/// reason `TGRichTextInputDecGeometryPurpose` is above. `.asSwift`
/// (`IDTextEditorBackendClientBridge.swift`) is the one place the two enums are kept in step.
typedef NS_ENUM(NSInteger, TGRichTextInputDecSelectionReason) {
    TGRichTextInputDecSelectionReasonKeyboard,
    TGRichTextInputDecSelectionReasonTouch,
    TGRichTextInputDecSelectionReasonFloatingCursor,
    TGRichTextInputDecSelectionReasonCommand,
    TGRichTextInputDecSelectionReasonProgrammatic,
    TGRichTextInputDecSelectionReasonExternalSynchronization,
};

/// The backend-private Objective-C ↔ Swift seam. This is NOT one of the six shared client
/// protocols: it is deliberately ObjC-shaped (primitives, NSRange, out-params, NS_ENUMs) so
/// that Swift-only concepts — `AnyHashable` line ids, the mutation enum's associated values,
/// the prepared-mutation UUID token, the presentation-invalidation OptionSet — never cross it.
/// It grows one method group per Stage-C family.
///
/// EVERY GROUP ADDED AFTER THIS ONE IS `@optional`. Objective-C protocol methods are `@required`
/// by default, and `StubBridge` in `CanvasCallbackInstallationTests` conforms to this protocol
/// with exactly the two methods below. Tasks C4 (six document methods), C5 (three geometry),
/// C6 (four delegate) and C7 (one mutation) each add a group; declaring any of them `@required`
/// would break that suite's compile — and therefore the whole UIKit test target — four separate
/// times, in four tasks that never mention it. The real conformer,
/// `IDTextEditorBackendClientBridge`, implements every method regardless; `@optional` costs it
/// nothing and costs the ObjC caller only a `respondsToSelector:` it already needs for the
/// nil-bridge case.
///
/// **Task C8 (Family 5, backward deletion) adds NO group here.** `deleteBackward()`'s whole path —
/// the controller's own `preflightBackwardDeleteRanges()`/`backwardDeleteRange()`, the
/// `.deleteBackward` intent latch (already installed by C7's `keyboardInputShouldDelete:` ABI-
/// witness edit), the `.deleteBackward` case in `IDTextEditorBackendIntent.mutation(for:...)`
/// (already added by C7), and the selection adoption after a kernel-driven delete
/// (`setCanonicalSelectionAnchor:head:reason:`, C6's fourth delegate method above) — was already
/// fully wired by the time this task started. See `DIVERGENCES.md` entry 8.
///
/// **Task C9 (Family 6, marked text and prediction) also adds NO group here.**
/// `setMarkedText:selectedRange:`/`unmarkText` (`IDTextEditorBackend+TextBackend.swift`) route
/// straight into `kernelInput` (the `IDUIKitInputControllerCapability` wrapper), which itself
/// forwards to the real private `UITextInputController` — a composing edit reaches THIS bridge only
/// through the SAME `prepareAndCommitReplacementInRange:...` crossing point C7 already declared
/// above, via the `keyboardInput:shouldInsertText:isMarkedText:YES` latch C7 already installed
/// (`TGRichTextInputDecCanvasCallbacks.m`) and the `.markedText` case C7 already added to
/// `IDTextEditorBackendIntent.mutation(for:...)`. `unmarkText` needs no bridge crossing at all — it
/// commits without mutating a character, so this backend retires its own `state.markedRange`
/// directly (`IDTextEditorBackend.commitMarkedTextStateIfComposing()`), never through this protocol.
/// See `DIVERGENCES.md` entry 9.
@protocol TGRichTextInputDecClientBridging <NSObject>

/// The NSTextStorage the private input controller mutates through. Never Telegram's model.
- (NSTextStorage *)textStorageFacade;

/// The canvas-side `keyboardInputShouldDelete:` preflight.
- (BOOL)canvasKeyboardInputShouldDelete;

// Tasks C4-C7 append their groups below this line, each opening with `@optional`.

@optional

// Task C4: document reads and position/range conversion (six methods). NO from
// `documentRebaseOffset:` means the position cannot be rebased; `outOffset` is untouched.
// Never fabricate 0.

- (NSInteger)documentUTF16Length;
- (uint64_t)documentRevision;
- (nullable NSString *)documentPlainTextInRange:(NSRange)range;
- (NSInteger)documentClampedOffset:(NSInteger)offset;
- (BOOL)documentIsValidInsertionOffset:(NSInteger)offset;
- (BOOL)documentRebaseOffset:(NSInteger)offset
                fromRevision:(uint64_t)revision
                   outOffset:(NSInteger *)outOffset;

// Task C5: geometry (three methods).
//
// NO ⇒ no geometry exists. Out-params are untouched on NO: the bridge never fabricates
// CGRectZero.

- (BOOL)caretGeometryAtOffset:(NSInteger)utf16Offset
                     affinity:(UITextStorageDirection)affinity
                     revision:(uint64_t)revision
                      purpose:(TGRichTextInputDecGeometryPurpose)purpose
                      outRect:(CGRect *)outRect
          outWritingDirection:(NSWritingDirection *)outWritingDirection
          outLayoutGeneration:(uint64_t *)outLayoutGeneration;

- (NSArray<TGRichTextInputDecSelectionRect *> *)selectionRectsForRange:(NSRange)range
                                                            visibleRect:(CGRect)visibleRect
                                                               revision:(uint64_t)revision;

- (BOOL)closestOffsetToPoint:(CGPoint)point
                 withinRange:(NSRange)range
                    revision:(uint64_t)revision
                   outOffset:(NSInteger *)outOffset;

// Task C6: selected range and input-delegate ownership (four methods).
//
// The four canvas thunks below (`TGRichTextInputDecCanvasCallbacks.m`) relay UIKit's own private
// text/selection-change callbacks through the first three; the backend — never this bridge, never
// the layout controller — is what actually sends the corresponding `UITextInputDelegate`
// notification (hard invariant 10; `IDTextEditorBackend.swift`'s `emitWillChange`/
// `adoptAndEmitDidChange` are the sole senders). The fourth adopts a NEW canonical selection the
// private controller reports after performing its own backward delete.

- (void)delegateTextInputDidChangeSelection;
- (void)delegateKeyboardInputChangedSelection;
- (void)delegateTextInputDidChange;
- (void)setCanonicalSelectionAnchor:(NSInteger)anchor
                                head:(NSInteger)head
                              reason:(TGRichTextInputDecSelectionReason)reason;

// Task C7: insertion and replacement (one method). The storage façade's ONE crossing point — every
// range replace UIKit's private input controller drives is a two-phase prepare/commit transaction
// through this method, never a direct document write.

/// `text`/`intent`/`expectedRevision` describe the replace the façade is about to apply;
/// `outOutcome` is untouched when this returns NO (a terminal rejection or no-change — see
/// `TGRichTextInputDecTextStorageFacade.m`'s caller). Returns YES only when the transaction's
/// disposition is `.applied`.
- (BOOL)prepareAndCommitReplacementInRange:(NSRange)range
                                       text:(NSString *)text
                                     intent:(TGRichTextInputDecIntent)intent
                           expectedRevision:(uint64_t)expectedRevision
                                 outOutcome:(TGRichTextInputDecMutationOutcome *)outOutcome;

/// Task R7 (cluster 4) — identical contract to the method above, PLUS a `beforeCommit` callout
/// invoked exactly once, only on the PREPARE-succeeded path (never for a terminal rejection/no-
/// change), strictly AFTER `prepareMutation` returns `.ready` but BEFORE `commitPreparedMutation`
/// runs — i.e. while the document is STILL in its pre-mutation state
/// (`TelegramDocumentInputClient.prepareMutation`'s own body performs no mutation;
/// `commitPreparedMutation` is where the real edit actually applies). Exists so a caller needing
/// PRE-mutation document state (the facade's own structural→plain-text range conversion — see
/// `TGRichTextInputDecTextStorageFacade.m`) can compute it at ZERO extra cost on the terminal path,
/// instead of paying for it unconditionally before the disposition is even known — measured
/// directly: computing it unconditionally added two `documentRead` log entries even to
/// `IDBackendMutationContractTests.test_terminalRejection_emitsNoDelegateNotifications_…`'s own
/// rejected mutation, which that suite's own event-log assertion (a DIFFERENT cluster's contract,
/// not this task's own) counts exactly. `@optional`, ADDITIVE to the plain selector above — a bridge
/// that implements only the original selector is unaffected (the facade falls back to computing
/// unconditionally before the call, `range` verbatim if neither is usable); `IDTextStorageFacadeTests`'
/// `FakeFacadeBridge` and `CanvasCallbackInstallationTests`' `StubBridge` need no changes.
- (BOOL)prepareAndCommitReplacementInRange:(NSRange)range
                                       text:(NSString *)text
                                     intent:(TGRichTextInputDecIntent)intent
                           expectedRevision:(uint64_t)expectedRevision
                               beforeCommit:(void (^ _Nullable)(void))beforeCommit
                                 outOutcome:(TGRichTextInputDecMutationOutcome *)outOutcome;

// Task C12: interaction-host thunks (Family 9, two methods). Backs the three canvas thunks
// `TGRichTextInputDecCanvasCallbacks.m` installs for `TGRichTextInputDecHostPreflight
// .requireInteractionHost:stage:`'s ABI check (`interactionAssistant`,
// `_textInputViewForAddingGestureRecognizers`, `selectionContainerView`) — the third,
// `_textInputViewForAddingGestureRecognizers`, needs no bridge crossing at all (it answers the
// canvas itself, mirroring `TGThunk_textInputView` above), so only two methods are added here.

/// The kernel's own interaction assistant (`IDUIKitInteractionCapability.privateAssistant`), once
/// `.interaction` is requested and its contract is accepted — `nil` before attach, after detach,
/// or whenever the contract was rejected. Backs the canvas thunk `-interactionAssistant`.
- (nullable id)canvasInteractionAssistant;

/// The presentation client's stable interaction container — backs the canvas thunk
/// `-selectionContainerView`. See `RichTextInputPresentationClient.interactionContainerView`'s own
/// doc comment ("stable for the backend lifetime"); `IDTextEditorBackend.swift`'s Step-4 note
/// records why no forcing is needed on this side of the seam.
- (nullable UIView *)interactionContainerView;

// Task C14: spellchecking and annotations (Family 11, nine methods).
//
// The seven annotation methods back the layout controller's `id_` implementations for manifest
// rows 41-47 (`TGRichTextInputDecLayoutController.m`) — the shared Swift
// `RichTextInputAnnotationClient` protocol reshaped into the bridge's ObjC-primitive vocabulary
// (NSRange/NSInteger/uint64_t, never `RichTextInputPosition`/`AnyHashable`, matching every earlier
// group's rule that Swift-only concepts never cross this header). NONE of the seven ObjC selectors
// on the layout controller side carries its own `revision` argument (the manifest's own
// `argumentTypes` prove it — see DIVERGENCES.md entry 14), so the layout controller extracts the
// RAW, UNRESOLVED `documentRevision` its incoming position/range object already carries and passes
// THAT through here — deliberately NOT the bridge's current `documentRevision()` and deliberately
// NOT run through the Family-1 `TGResolvePosition` rebase helper. DIVERGENCES.md entry 14 records
// why: annotation ranges are the one family that must not silently rebase (D17's pre-existing
// "ranges deliberately do not shift" behavior), and `TelegramAnnotationInputClient`'s own
// `guard revision == canvas.documentRevision` is the real staleness gate — passing a rebased,
// always-current revision here would make that gate vacuous.

/// Backs `id_annotatedSubstringForRange:` (row 41). `nil` ⇒ no answer (never a fabricated empty
/// string) — mirrors `RichTextInputAnnotationClient.annotatedSubstring(in:revision:)` verbatim.
- (nullable NSAttributedString *)annotatedSubstringForRange:(NSRange)range
                                                    revision:(uint64_t)revision;

/// Backs `id_annotationAttribute:atPosition:` (row 43). `key` is opaque (mirrors
/// `AnyHashable` on the Swift side — see this header's own opaque-annotation-key rule stated at
/// the top of the file); `position` is the RAW UTF-16 offset the incoming
/// `TGRichTextInputDecPosition` carries.
- (nullable id)annotationValueForKey:(id)key
                          atPosition:(NSInteger)utf16Offset
                            revision:(uint64_t)revision;

/// Backs `id_addAnnotationAttribute:value:forRange:` (row 42). Returns NO on a revision mismatch
/// or an unrecognized `value` — mirrors `addAnnotation(key:value:range:revision:)`'s
/// `@discardableResult Bool`.
- (BOOL)addAnnotationKey:(id)key
                    value:(id)value
                    range:(NSRange)range
                 revision:(uint64_t)revision;

/// Backs `id_removeAnnotationAttribute:forRange:` (row 44).
- (BOOL)removeAnnotationKey:(id)key
                       range:(NSRange)range
                    revision:(uint64_t)revision;

/// Backs `id_addRenderingAttributes:forRange:` (row 45). `attributes` carries display-only
/// rendering keys (ghost foreground / spoiler-hidden — see `TelegramAnnotationInputClient`'s own
/// header for the exact two the canvas recognizes); anything else is refused.
- (BOOL)addRenderingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                          range:(NSRange)range
                       revision:(uint64_t)revision;

/// Backs `id_removeRenderingAttributes:forRange:` (row 46).
- (BOOL)removeRenderingAttributes:(NSArray<NSAttributedStringKey> *)keys
                             range:(NSRange)range
                          revision:(uint64_t)revision;

/// Backs `id_invalidateTemporaryAttributesInRange:` (row 47). Void — a pure "repaint, nothing
/// changed" request; mirrors `invalidateTemporaryAttributes(in:revision:)`, which returns nothing.
- (void)invalidateTemporaryAttributesInRange:(NSRange)range
                                     revision:(uint64_t)revision;

// The two spellchecking canvas thunks (`TGRichTextInputDecCanvasCallbacks.m` installs
// `setContinuousSpellCheckingEnabled:`/`isContinuousSpellCheckingEnabled` onto the canvas,
// following the SAME best-effort-reconstruction precedent Family 3/4/9's non-`incomingCallbacks`
// thunks set — neither selector is one of the 47 `incomingCallbacks` rows; both names come from
// `CanvasCallbackInstallationTests`'s 22-name census, planned since before this family's work
// began). Named distinctly from the canvas-side selectors to avoid a same-name collision across
// the two different ObjC types (canvas vs. bridge) — see DIVERGENCES.md entry 14 for the full
// design-decision writeup, including why the setter ALSO forwards to the kernel's own outgoing
// `.checking` capability (`kernelInput.setContinuousSpellCheckingEnabled:`) rather than only
// updating the canvas's own `isSpellCheckingEnabled` flag.

/// Backs the canvas thunk `-setContinuousSpellCheckingEnabled:`.
- (void)setNativeContinuousSpellCheckingEnabled:(BOOL)enabled;

/// Backs the canvas thunk `-isContinuousSpellCheckingEnabled`.
- (BOOL)isNativeContinuousSpellCheckingEnabled;

@end

NS_ASSUME_NONNULL_END

#endif
