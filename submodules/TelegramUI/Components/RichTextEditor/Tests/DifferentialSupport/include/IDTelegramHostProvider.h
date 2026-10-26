// NOT VENDORED. Written for Telegram, Task 9b.
//
// Everything in `include/` whose name starts `IDTextInput` is vendored byte-for-byte from InputDec
// and must never be edited (see `PROVENANCE.md`). THIS header is ours, and it exists precisely so
// that the vendored ones stay untouched.
//
// ## Why a provider seam at all
//
// `IDTextInputTestHost.h` is vendored, so `+hostWithKind:scenario:error:` is the only entry point
// the vendored runner will ever call and no Swift-friendly constructor may be added to it. The
// Telegram editor cannot be constructed from Objective-C either: `RichTextEditorView` is a plain
// Swift class with no `@objc`, its `UITextInput` witness (`DocumentCanvasView`) is `internal`, and
// SwiftPM hands an Objective-C target no Swift interop header for a Swift target in the same
// package. Adding `@objc` to the editor was rejected on sight — that is a production change made in
// service of a test.
//
// So the Swift test target REGISTERS a factory here before any scenario runs, and the host calls
// it. Only Swift touches the editor; only Objective-C presents the vendored `@interface`s; no
// vendored file changes.
//
// ## The projection, and why it takes a RANGE
//
// `IDTextInputTestHost.h` requires `@property NSTextStorage *observedTextStorage`, and Telegram has
// no single `NSTextStorage` (limitation 1). What it does have is a linear ATTRIBUTED projection of
// any range — the attributed twin of the `-[UITextInput textInRange:]` the vendored recorder
// already calls, walking the same leaf regions with the same "\n"-at-a-crossed-top-level-paragraph-
// boundary rule.
//
// The projection takes a `UITextRange` rather than being a whole-document mirror, and that is
// load-bearing. MEASURED 2026-08-24 on the real editor: **the `UITextInput` offset axis is SPARSE**
// — each top-level paragraph boundary occupies TWO position slots while the text projection emits
// ONE "\n", so `-offsetFromPosition:toPosition:` reads one MORE than the corresponding index into
// the projected string, and another one more at every further boundary. Concretely, for
// `"Alpha middle omega\nSecond block remains unchanged."`: `documentSize` 53,
// `beginningOfDocument` 1, `endOfDocument` 52 (span 51) against a 50-character projection, and the
// second paragraph's first character is offset 20 on the position axis but index 19 in the string.
//
// A whole-document mirror indexed by recorder-reported offsets would therefore read the WRONG
// CHARACTER'S attributes from the second paragraph onward, silently, and report it as agreement.
// Projecting the range the recorder actually holds moves that conversion to the one place that can
// do it correctly — the editor itself.
#import "IDTextInputScenario.h"
#import "IDTextInputTestHost.h"

NS_ASSUME_NONNULL_BEGIN

/// The attributed twin of `-[UITextInput textInRange:]`, supplied by the Swift side.
///
/// Contract: for any `range` the host's `input` produced, the returned string MUST equal
/// `[input textInRange:range]`. `nil` means "this range cannot be projected" and is honoured as a
/// decline, never smoothed into an empty string — an empty projection and an unavailable one are
/// different facts and a snapshot field must be able to tell them apart.
typedef NSAttributedString *_Nullable (^IDTelegramAttributedTextProjection)(UITextRange *range);

/// TASK 9c. The editor's own TOP-LEVEL BLOCK TEXTS, in document order — the `blocks` comparison
/// field, which all 68 scenarios compare.
///
/// The vendored recorder answered `blocks` two different ways: `[canonical
/// componentsSeparatedByString:@"\n"]` for a stock host, and the custom view's real
/// `attributedBlocks` list for a non-stock one. That asymmetry is the point of the field — splitting
/// the canonical text on both sides would make `blocks` a restatement of `canonical` and compare
/// nothing new, while the real block list can disagree with the view's own text projection, which is
/// a class of bug only a block-structured editor has.
///
/// Reproducing it needs the editor's block list, which lives behind `internal` Swift types, so it
/// arrives as a block from the Swift factory rather than as a downcast in the recorder. `nil` means
/// "declined" and costs `blocks` its value at that capture; it is never smoothed into `@[]`.
typedef NSArray<NSString *> *_Nullable (^IDTelegramBlockTextsProvider)(void);

/// TASK 9c. The typing attributes at a COLLAPSED selection — what the next typed character would
/// carry — for the `typingInlineTraits` comparison field.
///
/// The vendored recorder's fallback for this case is `-textStylingAtPosition:inDirection:`, an
/// `@optional` `UITextInput` member that `UITextView` implements and `DocumentCanvasView` does not
/// (measured by Task 9b and pinned by a test), and its other branch downcasts to the InputDec view.
/// Neither is available, so the editor answers for itself through this block.
///
/// It takes the whole (collapsed) `UITextRange` rather than a `UITextPosition` for the same reason
/// the attributed projection does: the offsets on either side of it are on the editor's SPARSE axis,
/// and the conversion belongs inside the editor. `nil` means "declined".
typedef NSDictionary<NSAttributedStringKey, id> *_Nullable (^IDTelegramTypingAttributesProvider)(
    UITextRange *collapsedSelection);

/// TASK 9d. An inline-trait toggle ("bold" / "italic" / "underline" / "strikethrough") applied
/// through the editor's OWN public command, for the `toggleInlineTrait` transaction kind.
///
/// The vendored driver's non-stock branch downcast `host.input` to `IDBlockTextView` and called
/// `-toggleInlineTextTrait:` — one of the three coupling hits that kept that file from being
/// vendored. There is no neutral `UITextInput` spelling of "toggle bold over the selection" to
/// replace it with (`textStylingAtPosition:inDirection:` reads, it does not write, and the canvas
/// does not implement it anyway), so the editor answers for itself through this block, registered
/// by the same Swift factory that builds it.
///
/// Return NO for a trait the editor cannot toggle; the driver then FAILS the transaction rather
/// than treating an untoggled trait as a toggle that had no visible effect. The two are different
/// facts and only one of them is a finding about the editor.
typedef BOOL (^IDTelegramInlineTraitToggle)(NSString *traitName);

/// What the Swift factory hands back for one host instance.
@interface IDTelegramInputHandle : NSObject

/// `input` is the `UITextInput` witness (the canvas). `ownerView` is the view the host adds to the
/// window and lays out — the public editor façade, which is `input`'s ancestor, not `input` itself.
/// Pass `nil` for `ownerView` when the input view is its own owner.
+ (instancetype)handleWithInput:(UIView<UITextInput> *)input
                      ownerView:(nullable UIView *)ownerView
       attributedTextProjection:(nullable IDTelegramAttributedTextProjection)projection;

/// The designated form, adding Task 9c's two sampling providers. Every provider is optional and a
/// `nil` provider (or one that returns `nil`) is honoured as a DECLINE by the recorder, never as an
/// empty answer.
+ (instancetype)handleWithInput:(UIView<UITextInput> *)input
                      ownerView:(nullable UIView *)ownerView
       attributedTextProjection:(nullable IDTelegramAttributedTextProjection)projection
                     blockTexts:(nullable IDTelegramBlockTextsProvider)blockTexts
                typingAttributes:(nullable IDTelegramTypingAttributesProvider)typingAttributes;

/// TASK 9d's designated form, adding the inline-trait toggle. A `nil` toggle means the editor
/// offers none, and the driver fails a `toggleInlineTrait` transaction rather than silently
/// skipping it.
+ (instancetype)handleWithInput:(UIView<UITextInput> *)input
                      ownerView:(nullable UIView *)ownerView
       attributedTextProjection:(nullable IDTelegramAttributedTextProjection)projection
                     blockTexts:(nullable IDTelegramBlockTextsProvider)blockTexts
               typingAttributes:(nullable IDTelegramTypingAttributesProvider)typingAttributes
              inlineTraitToggle:(nullable IDTelegramInlineTraitToggle)inlineTraitToggle;

@property(nonatomic, strong, readonly) UIView<UITextInput> *input;
@property(nonatomic, strong, readonly) UIView *ownerView;
@property(nonatomic, copy, readonly, nullable)
    IDTelegramAttributedTextProjection attributedTextProjection;
@property(nonatomic, copy, readonly, nullable)
    IDTelegramBlockTextsProvider blockTextsProvider;
@property(nonatomic, copy, readonly, nullable)
    IDTelegramTypingAttributesProvider typingAttributesProvider;
@property(nonatomic, copy, readonly, nullable)
    IDTelegramInlineTraitToggle inlineTraitToggle;

@end

/// Builds one host's input for `kind` (never `IDTextInputHostKindStock` — the host builds stock
/// itself, verbatim from the vendored original). Returns `nil` and fills `error` on failure.
typedef IDTelegramInputHandle *_Nullable (^IDTelegramInputFactory)(
    IDTextInputHostKind kind, IDTextInputScenario *scenario, NSError **error);

/// A READ-ONLY PULL PROJECTION presented as an `NSTextStorage`, because the vendored
/// `IDTextInputTestHost.h` and `IDTextInputStateRecorder.h` both insist on that type.
///
/// Two properties are deliberate and load-bearing:
///
/// 1. **It never posts `NSTextStorageDidProcessEditingNotification`.** `-refresh` swaps the backing
///    string outright rather than going through `NSMutableAttributedString` mutation, so the
///    recorder's storage observer can never fire. That is not an oversight: an edit trace assembled
///    from *our own refresh calls* would describe when the recorder sampled, not when the editor
///    edited, and would compare against stock's genuine trace as though the two meant the same
///    thing. `storageMutationTrace` must therefore be DECLINED for a Telegram host, and this type
///    makes that structural rather than a convention Task 9c has to remember.
/// 2. **`isAligned` is checked, not assumed.** Every `-refresh` compares the projected string with
///    `[input textInRange:]` over the whole document and, on any disagreement, empties the backing
///    and records `misalignmentReason`. A misaligned projection declines; it does not guess.
///
/// Mutating it raises: nothing may write through this object.
@interface IDTelegramProjectedTextStorage : NSTextStorage

/// YES iff the last `-refresh` produced a projection whose string equalled the host's canonical
/// text. When NO, the backing is EMPTY and every storage-derived snapshot field must be omitted —
/// an empty run list is a plausible-looking value, and a plausible-looking value that was never
/// measured is the one failure mode an oracle must not have.
@property(nonatomic, readonly) BOOL isAligned;
@property(nonatomic, copy, readonly, nullable) NSString *misalignmentReason;

/// Re-pull from the editor. Task 9c calls this at the top of every capture.
- (void)refresh;

@end

/// Runs `block` and returns the `NSException` it raised, or `nil`. Swift cannot catch an
/// Objective-C exception, and the projected storage's refusal to be mutated is worth pinning.
FOUNDATION_EXPORT NSException *_Nullable IDTelegramCatchException(
    NS_NOESCAPE void (^block)(void));

@interface IDTextInputTestHost (IDTelegramProvider)

/// Registered by the Swift test target before any non-stock host is built. Passing `nil` clears it,
/// and a non-stock `+hostWithKind:` with no factory registered FAILS rather than quietly producing
/// a stock host — a differential run that silently compared stock against stock would be green and
/// meaningless.
+ (void)id_setTelegramInputFactory:(nullable IDTelegramInputFactory)factory;
+ (nullable IDTelegramInputFactory)id_telegramInputFactory;

/// The range projection for this host, or `nil` for a stock host (whose real `NSTextStorage` is
/// already the answer to every question this block exists for).
@property(nonatomic, copy, readonly, nullable)
    IDTelegramAttributedTextProjection id_attributedTextProjection;

/// TASK 9c's two sampling providers, `nil` for a stock host (which answers both from its own
/// `UITextView` API, exactly as the vendored recorder does).
@property(nonatomic, copy, readonly, nullable)
    IDTelegramBlockTextsProvider id_blockTextsProvider;
@property(nonatomic, copy, readonly, nullable)
    IDTelegramTypingAttributesProvider id_typingAttributesProvider;

/// TASK 9d's inline-trait toggle, `nil` for a stock host (which the driver formats through its own
/// `UITextView` API, reproducing the vendored original's stock branch exactly).
@property(nonatomic, copy, readonly, nullable)
    IDTelegramInlineTraitToggle id_inlineTraitToggle;

/// Re-pulls `observedTextStorage` when it is a projection; a no-op for a stock host, whose storage
/// is live. Task 9c calls this before sampling.
- (void)id_refreshObservedTextStorage;

/// Always YES for a stock host. For a Telegram host, the projection's `isAligned`.
@property(nonatomic, readonly) BOOL id_observedTextStorageIsAligned;
@property(nonatomic, copy, readonly, nullable) NSString *id_observedTextStorageMisalignmentReason;

/// The scenario's `initialTraits` this host's `input` did NOT take, name -> why, measured at
/// construction by applying each trait and READING IT BACK. Empty means every trait stuck.
///
/// This is not decoration; there are two distinct ways a trait fails to apply and the vendored host
/// could see neither, because both of ITS inputs were `UITextView`-shaped:
///
///   * **The selector is absent.** `UITextInputTraits` declares all ten as `@optional` and `UIView`
///     implements none, so an unguarded send raises `unrecognized selector`. MEASURED 2026-08-24:
///     `DocumentCanvasView` implements six of the ten — `autocapitalizationType`, `keyboardType`,
///     `returnKeyType` and `secureTextEntry` are absent on it and present on `UITextView`.
///   * **The setter is a no-op.** The six the canvas does implement are `get`-only in substance
///     (`set { }`), a documented deviation in the editor, so the value is fixed by the editor rather
///     than by the scenario.
///
/// Reading it back catches both without the harness having to know which is which. Task 9c must
/// consult this rather than assuming the ten traits it reads describe what the scenario asked for.
@property(nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *id_unappliedTraits;

/// The guarded trait application `id_unappliedTraits` is measured by, exposed so that TASK 9d's
/// `set-traits` transaction kind applies traits through the SAME code that applied the scenario's
/// initial ones. Two copies of the ten-selector table is two places for the guard to be forgotten,
/// and forgetting it raises `unrecognized selector` rather than failing a comparison.
/// Returns the traits that did not stick, name -> why; the caller decides what that means.
+ (NSDictionary<NSString *, NSString *> *)id_applyTraits:(NSDictionary<NSString *, id> *)traits
                                                   input:(UIView<UITextInput> *)input;

@end

NS_ASSUME_NONNULL_END
