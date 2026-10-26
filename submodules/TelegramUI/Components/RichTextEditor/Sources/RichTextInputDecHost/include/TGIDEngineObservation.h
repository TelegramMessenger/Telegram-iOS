#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;
#import "IDBlockTextView.h"
#import "IDInlineTextStyleResolver.h"

NS_ASSUME_NONNULL_BEGIN

/// Observation of the engine's own change funnels. Additive: the engine's behaviour is
/// unchanged, and no callback here may mutate the engine (Global Constraint 5).
@protocol TGIDEngineObservationSink <NSObject>
/// `charactersChanged` is NO for a change that only re-attributed text (see
/// `IDBlockDocumentChange.charactersChanged`), which the range's shape cannot tell from a
/// same-length replacement.
- (void)engineDidChangeDocumentWithReplacedRange:(NSRange)replacedRange
                               replacementLength:(NSUInteger)replacementLength
                               charactersChanged:(BOOL)charactersChanged;
- (void)engineDidChangeSelection;
/// The controller finished an edit it drove (typing, a keyboard replace, a paste): every storage
/// change of that keystroke — including any the controller itself adds after a host correction —
/// has landed. Sent from UIKit's `textInputDidChange:` on the private input delegate.
- (void)engineDidFinishEdit;
/// The engine laid itself out — its own `layoutSubviews`, which runs for a document change, a width
/// change, AND every tick of a placed run's horizontal scroll (`scrollViewDidScroll:` marks the text
/// view for layout). The engine is a SUBVIEW: nothing marks the host for layout when only the engine
/// is laid out, so a host that places views in the engine's coordinate space from geometry inside a
/// run — the table's structural chrome, anchored in the engine so its row grip does not ride the
/// scroll — must re-place them from here. Without it the chrome stayed put while the cells scrolled
/// under it (K3, 2026-09-11). Sent after `-[IDBlockTextView layoutSubviews]` has completed, so every
/// geometry answer is current.
///
/// A sink MAY change the engine from here — the host puts a table's parked scroll offset back in
/// this callback — but the change has to CONVERGE: a content-offset assignment marks the text view
/// for layout again, which calls this method back, so a sink must record that the work is done
/// before doing it rather than after.
- (void)engineDidLayout;
/// The engine took or gave up the first-responder role, on a GENUINE transition only (a tap while
/// already focused sends nothing).
///
/// It has to come from the engine rather than from the host view wrapping it. The wrapper is not
/// the text client — it deliberately never calls `super.becomeFirstResponder()` — so its own
/// override runs only when a host focuses the editor PROGRAMMATICALLY. A TAP is delivered to this
/// view by UIKit's text-interaction assistant, which calls `-becomeFirstResponder` on this object
/// directly, and the wrapper's override is never entered: the host heard nothing about the one way
/// users actually focus an editor. The article editor's sheet expands from that notification, so
/// tapping into it left it in its small detent with its action bar under the keyboard (K3,
/// 2026-09-11).
- (void)engineDidBecomeFirstResponder;
- (void)engineDidResignFirstResponder;
@end

/// Gated to match `IDBlockTextView`, which is `API_AVAILABLE(ios(18.4))` because six of its
/// properties use UIKit types newer than a host's deployment floor. A subclass cannot be more
/// widely available than its superclass.
API_AVAILABLE(ios(18.4))
@interface TGIDObservingBlockTextView : IDBlockTextView
@property(nonatomic, weak, nullable) id<TGIDEngineObservationSink> observationSink;
/// The composer host's custom keyboard-replacement view (R5's composer-host surface,
/// `RichTextEngineEditorView+Responder.swift`'s `customInputView`). Plain telegram-authored
/// storage: `IDBlockTextView` (upstream) never overrides `UIResponder.inputView`, which is
/// `readonly` at that level, so as vendored the engine has no path for a host to swap in a
/// custom input view. This subclass's `-inputView` override (see the .m) forwards to this
/// property and does nothing else — the property owns the storage, the override is one line.
@property(nonatomic, strong, nullable) UIView *tgid_customInputView;
/// The engine's OWN block identity, in document order — one `NSUUID` per entry of
/// `attributedBlocks`, read straight off `IDBlockDocument.blocks` (both `IDBlockDocument.blocks`
/// and `IDBlock.identifier` are public; `id_document` is reachable from this subclass through the
/// engine's internal header). Nothing is derived, computed or invented here.
///
/// This exists because the engine is the ONLY thing that can answer "which of these blocks is the
/// one that was already there". `-[IDBlockDocument replaceCanonicalRange:withAttributedString:]`
/// splits identity into three spans — blocks before the affected range keep their `NSUUID`, blocks
/// after keep theirs, and only blocks created INSIDE the affected span get fresh ones. A host that
/// re-derives that correspondence positionally is right only when new blocks appear at the END of
/// the document, and silently wrong (structure migrates onto the wrong paragraph) for every edit in
/// the middle of one. Order matches `attributedBlocks` element for element, because both are
/// projections of the same `blocks` array.
@property(nonatomic, copy, readonly) NSArray<NSUUID *> *tgid_blockIdentifiers;
/// The index of `identifier` in `tgid_blockIdentifiers` (its FIRST occurrence), or `NSNotFound` —
/// O(1) amortised where `tgid_blockIdentifiers.firstIndex(of:)` rebuilds and bridges the whole array
/// per call. The map is rebuilt only when `IDBlockDocument.blocks` is a different array: the
/// document replaces that (immutable, `copy`) array on every mutation, and the cache retains the one
/// it was built from, so a stale map can never be read against a recycled pointer. Measured
/// (composer harness, 2026-09-23): a host set asks this once per block from the canvas's
/// `updateForDocumentChange:width:`, which made a 1000-line rich paste O(n²) and froze for 149 s.
- (NSInteger)tgid_indexOfBlockIdentifier:(NSUUID *)identifier;
/// The block's first canonical position (blocks are one separator apart), or `NSNotFound`, from the
/// same cache as `tgid_indexOfBlockIdentifier:`. The spoiler display decorator asks it once per
/// block from the canvas's `updateForDocumentChange:width:`; summing the blocks before it per call
/// made a Format over N media blocks spend O(n²) there (composer harness, 2026-09-25,
/// `HarnessAtomFormatScalingTests`).
- (NSInteger)tgid_canonicalStartOfBlockIdentifier:(NSUUID *)identifier;
- (void)tgid_setAttributedBlocks:(NSArray<NSAttributedString *> *)blocks;

/// As above, plus the attributes each block's line should be MEASURED and its caret placed with
/// while the block is empty.
///
/// An empty attributed string carries no attributes at all, so nothing about the intended line —
/// neither the font nor a pinned paragraph height nor an indent — is reachable from it. An empty
/// line otherwise measures at the document's default font and its caret sits at the container's
/// leading edge rather than at the paragraph's indent.
///
/// Delivered to the engine's own `id_emptyLineAttributesByBlock`, keyed by block identity, which
/// reaches EVERY block. An earlier version put them on the separator instead — the newline that
/// follows a block — which cannot reach the LAST block, since it has none.
- (void)tgid_setAttributedBlocks:(NSArray<NSAttributedString *> *)blocks
             emptyLineAttributes:(nullable NSArray<NSDictionary<NSAttributedStringKey, id> *> *)
                                 emptyLineAttributes;

/// As above, plus how far along its line each block's EMPTY caret should sit.
///
/// For a host drawing a prompt in an empty line: a CENTRED prompt otherwise has the caret in its
/// middle. Separate from the attributes because those also decide what a first keystroke inherits.
- (void)tgid_setAttributedBlocks:(NSArray<NSAttributedString *> *)blocks
             emptyLineAttributes:(nullable NSArray<NSDictionary<NSAttributedStringKey, id> *> *)
                                 emptyLineAttributes
           emptyLineCaretOffsets:(nullable NSArray<NSNumber *> *)emptyLineCaretOffsets;

/// Replaces the blocks at `blockRange` (indices) with `blocks`, through the adapter as one canonical
/// replacement of the span those blocks occupy — separators inside the span included, joined exactly
/// as `tgid_setAttributedBlocks:` joins. Blocks outside the span keep their identities; the first
/// block inside keeps its own. An empty `blockRange` inserts before its location; an empty `blocks`
/// deletes the span together with one adjoining separator.
/// Applies `attributes` over `range` ADDITIVELY and removes `removedKeys` there: the keys the bridge
/// owns (presentation), with the engine's own keys left untouched. Through the adapter, so the
/// document records the change like any attribute edit.
- (void)tgid_mergeAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                removingKeys:(NSArray<NSAttributedStringKey> *)removedKeys
            inCanonicalRange:(NSRange)range;

/// `tgid_mergeAttributes:removingKeys:inCanonicalRange:` for MANY ranges, applied in order and
/// landed as ONE attribute edit (`ranges[i]` takes `attributes[i]` and loses `removedKeys[i]`; the
/// three arrays are parallel). Like the single merge, only block TEXT is edited: the part of a range
/// that covers a separator is ignored, and a range past the document's end is skipped. For a host
/// pass that re-derives the runs of many blocks — a theme change, a settle after a large paste —
/// where one merge per run re-projected the whole document and ran a canvas pass over every block
/// per run: a theme change over 240 paragraphs took 8.4 s (composer harness,
/// `HarnessPresentationPassScalingTests`).
- (void)tgid_mergeAttributeEditsInCanonicalRanges:(NSArray<NSValue *> *)ranges
                                       attributes:(NSArray<NSDictionary<NSAttributedStringKey, id> *> *)attributes
                                     removingKeys:(NSArray<NSArray<NSAttributedStringKey> *> *)removedKeys;

/// Rewrites every attribute run over `range` through `transform` (which answers the run's new
/// attributes, or the ones it was given to leave it alone) in ONE attribute edit through the adapter.
/// For a host that re-derives many small runs — the atoms of a long paragraph, the media blocks of a
/// long document — where one `tgid_mergeAttributes:` per run rebuilt the canonical projection per run
/// and made a Format command quadratic in the atom count (composer harness p15,
/// `HarnessAtomFormatScalingTests`).
- (void)tgid_transformAttributesInCanonicalRange:(NSRange)range
                                      usingBlock:(NSDictionary<NSAttributedStringKey, id> *(^)(
                                                     NSDictionary<NSAttributedStringKey, id> *existing))transform;

- (void)tgid_replaceBlocksInRange:(NSRange)blockRange
             withAttributedBlocks:(NSArray<NSAttributedString *> *)blocks;

/// Re-adopts the caret block's typing attributes from the host's empty-line provider when that block
/// is empty. The engine adopts on a selection CHANGE; a host that changes what the caret's block IS
/// without moving the caret — a container command on an empty paragraph, a document set that keeps
/// the text, a correction that declares a fresh block — has to ask for it.
- (void)tgid_readoptEmptyBlockTypingAttributes;

/// Re-derives the TYPING attributes for a non-empty selection from the text it covers now, through
/// UIKit's own invalidation — what a selection CHANGE and an undo run, and what a stock text view types
/// a replacement with. A host command that restyles the selected text without
/// moving the selection (Bold, Strikethrough, a link) has to ask for it, or a character typed over the
/// selection straight after the command takes the attributes the text had BEFORE it (composer harness
/// p18, `HarnessTypingOverFormattedSelectionTests`). Does nothing at a caret or during a composition.
- (void)tgid_adoptTypingAttributesOfSelectedText;

/// The canonical selection an inline FORMAT command last re-adopted the typing attributes for
/// (`tgid_adoptTypingAttributesOfSelectedText`), or nil. While the selection is still exactly this, a
/// selection starting on a line break types with the selected TEXT's traits rather than what the line
/// break derives (composer harness p22); any other selection clears it. Writable because it is TYPING
/// STATE an undo restores, as a stock text view's undo restores the attributes its newline was given:
/// the host's undo snapshot carries it, and a host that sets it calls
/// `tgid_readoptEmptyBlockTypingAttributes` afterwards.
@property(nonatomic, strong, nullable) NSValue *tgid_formatCommandSelection;

/// Rewrites the values of the attributes TYPING will use — the input controller's typing attributes
/// and, while a composition is open, the ones its commit re-applies — through `translate`, which
/// answers the replacement for a (key, value) pair or nil to keep it. For a host that re-renders the
/// document's presentation IN PLACE (a theme or Text Size change): the text around the caret takes
/// the new presentation, and without this the next typed character, or the next candidate of an
/// open composition, would still be attributed with the old one.
- (void)tgid_translateTypingAttributesUsingBlock:
    (id _Nullable (^)(NSAttributedStringKey key, id value))translate;

/// Draws the cursor on the caret NOW, in the pass this is called from, instead of leaving it to
/// UIKit's run-loop timer.
///
/// The engine already does this for changes it drives itself: `-id_flushSelectionDisplayUpdate` runs
/// at the end of its `-layoutSubviews`, but only for a pass that follows a DOCUMENT change, and only
/// once — the first such pass clears the flag. A host COMMAND moves the caret twice over one
/// document change: the host's own `document` set clamps it to the replaced span's end and lays the
/// engine out while measuring, and only then does the command put the caret where it belongs. The
/// flush is spent on the clamp, so the command's caret waits for the timer — one run-loop iteration,
/// which is a painted frame with the cursor in the wrong BLOCK. On K3 that read as "when adding a
/// detail block the cursor momentarily blinks in its body, and then jumps into the title"
/// (2026-09-15): the clamp lands in the body, the command wants the title.
///
/// Call it from the host's own layout pass, after the engine has laid out so every geometry answer
/// is current, and ONLY for a pass that draws a DOCUMENT change. `-layoutManagedSubviews` is the
/// RESETTING entry, and running it on a pass a bare selection move triggered disturbs the anchor the
/// keyboard-based selection interaction carries between key events — see
/// `-id_flushSelectionDisplayUpdate`'s own comment for the Shift+Right trace that rule came from.
- (void)tgid_flushSelectionDisplayUpdate;


/// The undo manager this view answers with, in place of the engine's own.
///
/// `UIResponder` reads `-undoManager` for `undo:`/`redo:` and for `-canPerformAction:`, so setting
/// this is what routes ⌘Z, shake-to-undo and the edit menu's Undo to the SAME stack the host's
/// toolbar button drives. That identity is the point: the two were reported as behaving
/// differently, and the only way they cannot is for there to be one stack.
///
/// nil restores the engine's own (`id_behaviorInput.undoManager`, which is UIKit's private
/// `_UITextUndoManager` for the text-input controller).
@property(nonatomic, strong, nullable) NSUndoManager *tgid_undoManagerOverride;

/// Set when a text or selection change asks for a reveal, cleared by the host's pass that performs
/// one. There is no matching sink callback on purpose: upstream reaches the caret path three times
/// for one keystroke, so WHEN to tell the host is a coalescing decision, and the wrapper makes it at
/// the end of the edit (`engineDidFinishEdit`) or immediately for a caret move with no edit in
/// flight.
///
/// It is what makes `ifNeeded` mean "something asked" rather than "the caret happens to be out of
/// band": both hosts re-lay out for reasons that have nothing to do with the caret, and a bare
/// out-of-band test would yank back a scroll the user deliberately dragged away.
@property(nonatomic) BOOL tgid_caretRevealPending;

/// Host veto for Backspace. Return `YES` to consume the keystroke; `NO` (or nil) lets the engine
/// handle it normally.
///
/// Exists for one case the engine cannot answer on its own: a caret inside an EMPTY container, where
/// the engine has no text to delete and nothing before it to merge into, so it correctly does nothing
/// and reports no change. The host hears nothing and an empty code block becomes undeletable — found
/// on device. The host knows the block is a container and that Backspace should dissolve it, which is
/// exactly the legacy editor's rule.
///
/// A host DECISION rather than engine behaviour, in the same shape as `typedTextAttributePolicy`:
/// what a container is, and what Backspace means inside an empty one, are host concepts.
@property(nonatomic, copy, nullable) BOOL (^tgid_deleteBackwardHandler)(void);

/// Host veto for UIKit's text-interaction recognizers (tap to place the caret, long-press, the
/// selection drag), consulted from `-gestureRecognizerShouldBegin:` with the touch's location in
/// this view's coordinates. Return `NO` to refuse. A host that places its own tappable content over
/// the text — a media block's hosted view — answers `NO` there, so a tap on a photo selects the
/// photo and is not immediately followed by the engine placing a caret beside it. The assistant's
/// recognizers are attached to THIS view (`IDBlockTextView+Interaction.m`), which is what makes the
/// `UIView` hook apply to them. THIS VIEW'S OWN SCROLL PAN (and pinch, when present) IS EXEMPT — this
/// view is a `UIScrollView`, and the veto exists only for the text-interaction assistant, never for
/// scrolling; a drag that starts on a hosted media view must still be able to scroll the editor.
/// `isTap` says whether the recognizer asking is a tap (`UITapGestureRecognizer` and its private
/// text subclasses) rather than a press or a drag: a host may let a tap through where it refuses a
/// drag — a table's resize knob takes the drag and gives up the tap, so the cells around the focused
/// one stay reachable by tap.
@property(nonatomic, copy, nullable) BOOL (^tgid_shouldBeginTextInteractionHandler)(CGPoint locationInView, BOOL isTap);

/// Host veto for THIS VIEW'S OWN SCROLL PAN — the recognizer the veto above is documented to exempt.
/// Consulted from `-gestureRecognizerShouldBegin:` with the touch's location in this view's
/// coordinates; return `NO` and the document does not scroll for that touch. The host answers `NO`
/// over a table's resize knob: a knob drag is vertical as often as not, and a scroll view whose
/// content fits still begins its pan on any vertical movement (it bounces), cancelling the knob's own
/// pan under it — on device (K3, 2026-09-10) a horizontal knob drag extended the selection and a
/// vertical one did nothing. Legacy's `GripYieldingScrollView` is the same yield. Everything else is
/// `YES`, the hosted-media case included: a drag that starts on a photo must still scroll the editor.
@property(nonatomic, copy, nullable) BOOL (^tgid_shouldBeginScrollPanHandler)(CGPoint locationInView);

/// Host veto for any recognizer on this view OTHER than its own scroll pan and pinch, asked with the
/// recognizer itself BEFORE `tgid_shouldBeginTextInteractionHandler`. It exists for arbitration that
/// needs to know WHICH recognizer is asking, which a location and a tap flag cannot say: the host's
/// text drag (`UIDragInteraction`, installed by the host because `UITextInteraction` installs none)
/// lifts on a long press, and a long press inside a selection must be the drag's, not the loupe's —
/// UITextView's rule. Return `NO` to refuse.
@property(nonatomic, copy, nullable) BOOL (^tgid_shouldBeginGestureRecognizerHandler)(UIGestureRecognizer *gestureRecognizer);

/// The chat's paste-media hooks (spec §7.4), consulted where the legacy canvas consults them.
/// `tgid_canPasteMediaHandler` makes Paste available for a pasteboard that holds only media;
/// `tgid_pasteMediaHandler` is called from `paste:` when the pasteboard has NO text representation
/// and returns whether it consumed the paste — the chat routes the media to its send flow, so
/// nothing lands in the editor. A pasteboard with text always goes to the engine.
@property(nonatomic, copy, nullable) BOOL (^tgid_canPasteMediaHandler)(void);
@property(nonatomic, copy, nullable) BOOL (^tgid_pasteMediaHandler)(void);

/// The host's own clipboard, consulted BEFORE the engine's.
///
/// The engine writes exactly one representation, `public.utf8-plain-text`, so every block structure
/// is ABSENT from a copy rather than degraded — a copied table arrives as its empty cells' newlines
/// (measured). The host writes a `Document` instead, in the three representations the legacy editor
/// has written since Phase 5d, and reads them back richest-first.
///
/// `tgid_copyHandler` returns YES having written the pasteboard; `tgid_richPasteHandler` returns YES
/// having consumed the paste. NO falls through to the engine, which is what keeps a plain-text or
/// media pasteboard behaving exactly as before. `cut:` is a copy plus an empty replacement, so it
/// picks the rich copy up through this hook without one of its own.
@property(nonatomic, copy, nullable) BOOL (^tgid_copyHandler)(void);
/// The flat range a Cut of `selection` deletes, when it is not the selection itself: what the host's
/// copy took (a medium or table the selection enters in part is taken whole). The deletion still goes
/// through the surface gate. nil — the selection.
@property(nonatomic, copy, nullable) NSRange (^tgid_cutRangeHandler)(NSRange selection);
@property(nonatomic, copy, nullable) BOOL (^tgid_richPasteHandler)(void);
/// Told when the ENGINE's own paste (plain text, RTF, RTFD, HTML from another app) is about to land:
/// UIKit has combined the pasteboard items and the insertion follows synchronously. The paste is
/// asynchronous (it lands 20-30 ms after `paste:`), so this is the one moment the host knows the next
/// storage edit is the paste — to make it an undo step of its own.
@property(nonatomic, copy, nullable) void (^tgid_pasteWillLandHandler)(void);

/// Host gate for text arriving at the view's UITextInput surface — typing, hardware Return, the
/// keyboard's own replaces (autocorrect, predictive text) — consulted BEFORE the controller edits,
/// with the canonical range the text replaces and the text. Return the text to forward (the same,
/// or a transform), or nil to forward nothing. The host may issue its own edits through the view's
/// API before it returns; they are ordinary top-level edits. Not consulted while marked text exists.
/// Same shape and reason as `tgid_deleteBackwardHandler`: what a newline means inside a container
/// is a host concept (surface-gate spec §3.1).
/// A selection deletion (`deleteBackward` with a selection, `cut:`) is issued as `replaceRange:withText:`
/// with empty text, so it reaches the gate too: a range across blocks is structural.
@property(nonatomic, copy, nullable) NSString *_Nullable (^tgid_textInputGate)(NSRange canonicalRange, NSString *text);

/// YES only while the gate is being asked to resolve the selection a COMPOSITION is about to start
/// over (an empty replacement, see `setMarkedText:selectedRange:`). A host that decides the deletion
/// itself uses it to keep the deletion and the composition that follows it ONE undo step, as a stock
/// text view's composition over a selection is.
@property(nonatomic, readonly) BOOL tgid_isResolvingCompositionSelection;

/// For a host resolving a composition's selection (`tgid_isResolvingCompositionSelection`) that puts
/// the composition somewhere other than the selection's start: called with the text the composition
/// replaces SELECTED as typing over it would select it, it records the controller's typing attributes
/// for that selection, and the composition starts with those instead of the ones taken from the
/// selection it found. Does nothing outside a resolution. Typing across a media unit selects the
/// caption head it inserts into; without this the composition took the attributes of the atom or
/// separator the selection began on, and dropped the caption's bold / link (composer harness p21,
/// `HarnessCompositionFromMediaStopTests`).
- (void)tgid_noteCompositionTypingAttributesOfSelection;

/// Called when a composition is about to START at a collapsed caret (no text marked, no selection),
/// with the caret's canonical offset, before the controller marks anything. The host may move the
/// caret, or issue its own edits to give the composition a place to live, and the composition then
/// begins at the caret that leaves; later candidates find text marked and are not asked about. For a
/// caret that is not a place text lands (an atom's stop), which the gate decides for a finished
/// keystroke but which a composition, whose candidates are not keystrokes, must not be decided per
/// candidate.
@property(nonatomic, copy, nullable) void (^tgid_compositionCaretResolver)(NSUInteger caret);

/// The text a composition MARKS, as the host lets it into the document: called with each candidate (and a
/// commit's `insertText:` while text is marked) that holds a line break, before the controller marks it.
/// Return the text to mark instead, or nil to keep it. Marked text never reaches the gate
/// (`tgid_textInputGate`), so without this a candidate holding `"\n"` — the engine's block separator —
/// split the block it was composed in before anything could rewrite it: a one-line field (a quote's
/// author, a details title) lost its tail to a body paragraph (composer harness p24,
/// `HarnessCompositionNewlineInOneLineFieldTests`). The composition itself is kept; the selection inside
/// the marked text is clamped to the text returned.
@property(nonatomic, copy, nullable) NSString *_Nullable (^tgid_markedTextFilter)(NSString *markedText);

/// Called when a composition ENDS by having its marked text replaced with nothing
/// (`setMarkedText:` with an empty string, how a keyboard cancels) rather than through `unmarkText`.
@property(nonatomic, copy, nullable) void (^tgid_compositionDidEmptyHandler)(void);

/// Called after a composition COMMITS through `unmarkText` (the text is no longer marked). A host
/// that defers structural consequences while an IME owns the text settles them here.
@property(nonatomic, copy, nullable) void (^tgid_compositionDidCommitHandler)(void);

/// What a REPLACEMENT arriving at the UITextInput surface is attributed with, consulted after the
/// gate has forwarded it and before the controller edits, with the canonical range being replaced and
/// the text replacing it. Return the attributes the replacement should carry, or nil to leave the
/// controller's own.
///
/// `replaceRange:withText:` is what autocorrect, an accepted prediction, text replacement and
/// dictation go through, and the controller attributes it from its typing attributes: font, colour
/// and the four engine traits, never a host marker (spoiler, inline code) — and, for a programmatic
/// replace, not even those. A stock text view gives a replacement the attributes of the start of the
/// text it replaces, so the host answers with those (composer harness, 2026-09-23,
/// `HarnessAutocorrectMarkerTests`). Only the host knows which replacements are keystrokes: its own
/// edits reach this surface too and must keep what they were given.
@property(nonatomic, copy, nullable)
    NSDictionary<NSAttributedStringKey, id> *_Nullable (^tgid_replacementAttributesHandler)(NSRange canonicalRange,
                                                                                           NSString *text);

/// VoiceOver's reading of the text, and the axis its offsets are counted on.
///
/// The engine's own `accessibilityValue` is its raw text, where every attachment atom (a custom
/// emoji, a formula, a medium, an inline button) is one `U+FFFC` — which VoiceOver skips or reads as
/// "object replacement character". The host answers the text with each atom replaced by what it
/// reads as, and because that changes lengths, it also maps VoiceOver's selection between that text
/// and the engine's canonical axis: the AX runtime derives a text area's selected range from
/// `-selectedTextRange` and reads characters out of `accessibilityValue` at those offsets, so leaving
/// the range on the engine axis would put VoiceOver's cursor one character early per expanded atom.
/// All three nil: the engine's own answers (raw text, canonical offsets).
@property(nonatomic, copy, nullable) NSString *_Nullable (^tgid_accessibilityValueProvider)(void);
@property(nonatomic, copy, nullable) NSRange (^tgid_accessibilityRangeFromCanonicalRange)(NSRange canonicalRange);
@property(nonatomic, copy, nullable) NSRange (^tgid_canonicalRangeFromAccessibilityRange)(NSRange accessibilityRange);

/// Keyboard input-language pre-selection, mirroring the legacy canvas's mechanism.
///
/// The chat composer seeds this from the draft's saved keyboard language so the keyboard opens in
/// that language. It lives HERE, on the engine, because the engine is the first responder — the
/// wrapper view deliberately never calls `super.becomeFirstResponder()`, so a `textInputMode`
/// override there would never be queried.
///
/// LOAD-BEARING ORDERING INVARIANT, carried over from the legacy implementation: the override is
/// SINGLE-SHOT. The first `textInputMode` query consumes the pre-selection, and correctness depends
/// on UIKit querying before the host reads back — which it does, because `becomeFirstResponder`
/// raises the keyboard (querying `textInputMode`) before any keystroke or host read. Do not add a
/// separate non-side-effecting read path.
@property(nonatomic, copy, nullable) NSString *tgid_initialPrimaryLanguage;

/// Re-arm the pre-selection so the next `textInputMode` query re-applies it.
- (void)tgid_resetInitialPrimaryLanguage;


/// Supplies the edit menu's contents, given the system's own suggested actions.
///
/// THIS IS THE SEAM, and finding it took an on-device probe. UIKit's private
/// `UITextInteractionAssistant` — which this engine uses for selection — presents the edit menu
/// itself and asks the TEXT-INPUT VIEW for its contents through
/// `-editMenuForTextRange:suggestedActions:`. It does NOT consult a `UIEditMenuInteraction` the host
/// attaches to the view (an earlier attempt did exactly that; a marker item returned unconditionally
/// from that delegate never appeared), and the selector is NOT the `-editMenuForTextInRange:` spelling
/// `UITextViewDelegate` uses. Both near-misses compile and read as correct.
@property(nonatomic, copy, nullable)
    NSArray<UIMenuElement *> *(^tgid_editMenuElementsProvider)
        (NSArray<UIMenuElement *> *suggestedActions);
@end

NS_ASSUME_NONNULL_END

#endif
