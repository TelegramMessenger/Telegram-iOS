#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;
#import "TGIDEngineObservation.h"

NS_ASSUME_NONNULL_BEGIN

/// The private text-alternatives surface of `UITextView`, on the engine's view.
///
/// When the keyboard accepts an autocorrection it does not send plain text. It asks the text input
/// whether it takes `insertText:alternatives:style:` and, when it does, delivers the corrected word
/// with its alternatives — the typed original among them. `UITextView` answers by inserting an
/// attributed string that carries an `NSTextAlternatives` object, and its `UITextInputController`
/// then annotates the inserted range with `NSTextAlternativesDisplayStyle` through the layout
/// controller: that annotation is the blue underline, and the object behind it is what the tap's
/// prompt offers (`UITextSelectionInteraction` asks `rangeWithTextAlternatives:atPosition:`). The
/// engine's `IDBlockTextView` implements none of the family, so the keyboard fell back to plain
/// `insertText:` and a corrected word was indistinguishable from a typed one — no underline, no
/// revert (K3, 2026-09-11). Recovered by in-process disassembly of `UITextView`,
/// `UITextInputController` and `UITextSelectionInteraction` on iOS 26.5 (`23F73`); the package
/// `CLAUDE.md` has the record.
///
/// Every method keeps the engine's own rule — an annotation is never written into storage. The
/// text goes through this view's gated `insertText:` / `replaceRange:withText:`, and the
/// alternatives go into the engine's annotation store through its layout controller, which
/// mirrors them as the TextKit 2 temporary attributes the canvas draws — the path the spelling
/// flag already takes.
@interface TGIDObservingBlockTextView (TGIDTextAlternatives)

/// The keyboard's delivery of an accepted correction. `style` is the alternatives' low-confidence
/// flag, and the display style the controller stores is that flag: 0 for a normal correction,
/// 1 for a low-confidence one (spelling is 2).
- (void)insertText:(NSString *)text
      alternatives:(NSArray<NSString *> *)alternatives
             style:(UITextAlternativeStyle)style;
- (void)insertText:(NSString *)text
             style:(UITextAlternativeStyle)style
      alternatives:(NSArray<NSString *> *)alternatives;

/// A replacement whose attributed string carries the annotations itself (dictation, the checker).

/// Annotates the primary string's occurrence that ends at the selection, as the controller does.
- (void)addTextAlternatives:(id)alternatives;

/// The tap's question: the alternatives at `position` — or one before it, where a tap on a word's
/// last letter parks the caret — and their range, or nil.

- (void)removeAnnotation:(id)annotation forRange:(UITextRange *)range;

/// The two attribute keys, spelled once. Read by tests; the keyboard never asks.
+ (NSAttributedStringKey)tgid_textAlternativesKey;
+ (NSAttributedStringKey)tgid_textAlternativesDisplayStyleKey;

@end

NS_ASSUME_NONNULL_END

#endif
