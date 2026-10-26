// NOT VENDORED. Written for Telegram, Task 9d — the replacement for InputDec's own
// `IDTextInputTransactionDriver.m`, whose three references to `IDBlockTextView` are why it could
// not be carried over (see `PROVENANCE.md`).
//
// It presents the SAME vendored `@interface` — `-initWithHost:recorder:` and
// `-applyTransaction:index:error:` — because `IDTextInputDifferentialRunner.m` (vendored, and
// compiled from Task 9d onward) imports `IDTextInputTransactionDriver.h` directly and drives every
// host through it.
//
// **The stock branch is a faithful reproduction of the original's**, including the whole
// `toggleInlineTrait` typing-attribute / range-attribute machinery and its undo registration. That
// is not cargo-culting: this corpus re-derives stock behaviour LIVE rather than comparing against
// goldens, so an arm driven differently from the arm the corpus was captured against is not
// measuring the same thing. The only edit to that branch is mechanical — InputDec's
// `IDInlineTextTraits` (from `IDInlineTextFormatting.h`, which is not vendored) becomes the
// file-local `IDTelegramInlineTrait` with the same four bit values and the same meanings.
//
// ## Three deviations, all forced, all narrow
//
// 1. **RANGES ARE AIMED THROUGH `IDTelegramTextRangeForCharacterRange`, NEVER THROUGH
//    `-positionFromPosition:offset:`.** This is the single most important line in the file. The
//    corpus's `set-selection` and `replace-range` transactions carry ranges in STOCK CHARACTER
//    coordinates. The original realised one with
//    `[input positionFromPosition:input.beginningOfDocument offset:range.location]`, which is
//    correct on a `UITextView` and WRONG on the editor: that call adds to the RAW offset and then
//    snaps, and the editor's position axis is SPARSE (a top-level paragraph boundary occupies two
//    position slots where the text projection emits one "\n"), so it lands one character early at
//    every character index two or more past a boundary. Measured by Task 9c:
//
//        position(begin, +12) -> raw 13 -> character 12   correct (before the boundary)
//        position(begin, +25) -> raw 26 -> character 24   ONE CHARACTER EARLY
//
//    A driver built on it would apply every post-boundary edit one character off, the recorder
//    would faithfully report the resulting text, and the difference would be attributed to the
//    editor's EDITING rather than to this file's AIM. **Two of Task 9c's own tests were written that
//    way and failed against a correct recorder**, which is the strongest available evidence that the
//    mistake is the natural one to make. `IDTelegramTextRangeForCharacterRange` steps the input's
//    own positions, so it skips the non-renderable slots exactly as the editor does and is the
//    identity on stock.
//
//    The same applies to the DOCUMENT LENGTH the range is validated against: the original used
//    `-offsetFromPosition:toPosition:` over the whole document, which on the editor is the SPAN of
//    the sparse axis (51 where the text is 50 characters) and would admit a range one past the end.
//
// 2. **`set-traits` applies through `+[IDTextInputTestHost id_applyTraits:input:]`.** Every
//    `UITextInputTraits` member is `@optional`, `UIView` implements none, and `DocumentCanvasView`
//    implements six of the ten (Task 9b, measured), so the original's unguarded sends raise
//    `unrecognized selector` on a Telegram host. The validation half of the original's `applyTraits:`
//    — non-empty, keys a subset of the ten, values numeric — is reproduced here, because that is
//    about the SCENARIO being well-formed and belongs to the driver; the application half is the
//    host's, so that the guard exists in exactly one place. (For the record: **no scenario in this
//    corpus carries a `set-traits` transaction** — measured, all four families, 0 occurrences. This
//    path is implemented for completeness of the 15 kinds and is not exercised by the corpus.)
//
// 3. **`toggleInlineTrait` on a non-stock host goes through `id_inlineTraitToggle`**, the block the
//    Swift factory registers, instead of the original's `[(IDBlockTextView *)input
//    toggleInlineTextTrait:]` downcast. There is no neutral `UITextInput` spelling of "toggle bold
//    over the selection", so the editor has to answer for itself; routing it through a block keeps
//    this file free of any Telegram type, which is the same rule Task 9c's recorder follows.
//
// ## Errors name the host kind
//
// The original's message is `"Transaction %lu: %@"`. The runner surfaces a driver error by
// returning `nil` from `-runScenario:order:error:`, and at that point the caller can no longer tell
// WHICH of the three arms failed — which matters, because "the editor cannot undo here and stock
// can" is a finding about the editor, not a broken scenario. The kind is therefore in the message.
// Nothing compares these strings.
#import "IDTextInputTransactionDriver.h"

#import "IDTelegramCharacterAxis.h"
#import "IDTelegramHostProvider.h"

NSString *const IDTextInputTransactionErrorDomain =
    @"com.inputdec.tests.text-input-transaction";

/// InputDec's `IDInlineTextTraits`, reproduced with the same bit values. The original imported it
/// from `IDInlineTextFormatting.h`, which lives in InputDec's own text view and is therefore not
/// vendored. It is used only as a local bitmask inside the stock branch below.
typedef NS_OPTIONS(NSUInteger, IDTelegramInlineTrait) {
    IDTelegramInlineTraitBold          = 1 << 0,
    IDTelegramInlineTraitItalic        = 1 << 1,
    IDTelegramInlineTraitUnderline     = 1 << 2,
    IDTelegramInlineTraitStrikethrough = 1 << 3,
};

@interface IDTextInputTransactionDriver ()
@property(nonatomic, strong) IDTextInputTestHost *host;
@property(nonatomic, strong) IDTextInputStateRecorder *recorder;
@property(nonatomic) NSUInteger undoGroupingDepth;
- (void)restoreStockAttributes:(NSAttributedString *)snapshot
                         range:(NSRange)range
                 selectedRange:(NSRange)selectedRange;
@end

@implementation IDTextInputTransactionDriver

#pragma mark - Inline-trait helpers (stock branch; reproduced from the origin)

static IDTelegramInlineTrait IDInlineTraitNamed(NSString *name) {
    if ([name isEqualToString:@"bold"]) return IDTelegramInlineTraitBold;
    if ([name isEqualToString:@"italic"]) return IDTelegramInlineTraitItalic;
    if ([name isEqualToString:@"underline"])
        return IDTelegramInlineTraitUnderline;
    if ([name isEqualToString:@"strikethrough"])
        return IDTelegramInlineTraitStrikethrough;
    return 0;
}

static IDTelegramInlineTrait IDStockInlineTraits(
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    IDTelegramInlineTrait traits = 0;
    UIFont *font = attributes[NSFontAttributeName];
    UIFontDescriptorSymbolicTraits fontTraits =
        [font isKindOfClass:UIFont.class]
            ? font.fontDescriptor.symbolicTraits : 0;
    if ((fontTraits & UIFontDescriptorTraitBold) != 0)
        traits |= IDTelegramInlineTraitBold;
    if ((fontTraits & UIFontDescriptorTraitItalic) != 0)
        traits |= IDTelegramInlineTraitItalic;
    if ([attributes[NSUnderlineStyleAttributeName] integerValue] != 0)
        traits |= IDTelegramInlineTraitUnderline;
    if ([attributes[NSStrikethroughStyleAttributeName] integerValue] != 0)
        traits |= IDTelegramInlineTraitStrikethrough;
    return traits;
}

static NSDictionary<NSAttributedStringKey, id> *
IDStockAttributesBySettingTrait(
    NSDictionary<NSAttributedStringKey, id> *attributes,
    IDTelegramInlineTrait trait,
    BOOL enabled,
    UIFont *defaultFont) {
    NSMutableDictionary<NSAttributedStringKey, id> *result =
        attributes.mutableCopy;
    if (trait == IDTelegramInlineTraitBold ||
        trait == IDTelegramInlineTraitItalic) {
        UIFont *font = [attributes[NSFontAttributeName]
            isKindOfClass:UIFont.class]
            ? attributes[NSFontAttributeName] : defaultFont;
        UIFontDescriptorSymbolicTraits symbolicTraits =
            font.fontDescriptor.symbolicTraits;
        UIFontDescriptorSymbolicTraits fontTrait =
            trait == IDTelegramInlineTraitBold
                ? UIFontDescriptorTraitBold
                : UIFontDescriptorTraitItalic;
        symbolicTraits = enabled
            ? symbolicTraits | fontTrait
            : symbolicTraits & ~fontTrait;
        UIFontDescriptor *descriptor = [font.fontDescriptor
            fontDescriptorWithSymbolicTraits:symbolicTraits];
        result[NSFontAttributeName] = descriptor == nil
            ? font
            : [UIFont fontWithDescriptor:descriptor size:font.pointSize];
    } else {
        NSAttributedStringKey key =
            trait == IDTelegramInlineTraitUnderline
                ? NSUnderlineStyleAttributeName
                : NSStrikethroughStyleAttributeName;
        if (enabled) {
            result[key] = @(NSUnderlineStyleSingle);
        } else {
            [result removeObjectForKey:key];
        }
    }
    return result.copy;
}

#pragma mark - Errors

static NSString *IDHostKindName(IDTextInputHostKind kind) {
    switch (kind) {
        case IDTextInputHostKindStock: return @"stock";
        case IDTextInputHostKindReference: return @"reference";
        case IDTextInputHostKindMinimal: return @"minimal";
    }
    return @"unknown";
}

- (BOOL)fail:(NSError **)error
       index:(NSUInteger)index
 description:(NSString *)description {
    if (error != NULL) {
        *error = [NSError errorWithDomain:IDTextInputTransactionErrorDomain
                                     code:1
                                 userInfo:@{
            NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"Transaction %lu on the %@ host: %@",
                                           (unsigned long)index,
                                           IDHostKindName(self.host.kind),
                                           description],
        }];
    }
    return NO;
}

#pragma mark - Lifecycle

- (instancetype)initWithHost:(IDTextInputTestHost *)host
                    recorder:(IDTextInputStateRecorder *)recorder {
    NSParameterAssert(host != nil);
    NSParameterAssert(recorder != nil);
    self = [super init];
    if (self != nil) {
        _host = host;
        _recorder = recorder;
    }
    return self;
}

#pragma mark - Aiming

/// The document's length ON THE CHARACTER AXIS — how much text there is, which is the axis the
/// corpus's ranges are written in. NOT `-offsetFromPosition:toPosition:`, which measures the
/// editor's sparse position axis and reads one MORE per top-level boundary.
- (NSUInteger)documentLength {
    UIView<UITextInput> *input = self.host.input;
    UITextRange *whole = [input textRangeFromPosition:input.beginningOfDocument
                                           toPosition:input.endOfDocument];
    NSString *text = whole != nil ? [input textInRange:whole] : nil;
    return text.length;
}

- (nullable UITextRange *)textRangeForValue:(NSValue *)value
                                      index:(NSUInteger)index
                                      error:(NSError **)error {
    if (value == nil) {
        [self fail:error index:index description:@"Range is required."];
        return nil;
    }
    NSRange range = value.rangeValue;
    NSUInteger length = self.documentLength;
    if (range.location > length || range.length > length - range.location) {
        [self fail:error index:index
        description:[NSString stringWithFormat:
            @"Range {%lu, %lu} is outside the current %lu-character document.",
            (unsigned long)range.location, (unsigned long)range.length,
            (unsigned long)length]];
        return nil;
    }
    UITextRange *textRange =
        IDTelegramTextRangeForCharacterRange(self.host.input, range);
    if (textRange == nil) {
        [self fail:error index:index
        description:[NSString stringWithFormat:
            @"Range {%lu, %lu} cannot be represented by UITextInput.",
            (unsigned long)range.location, (unsigned long)range.length]];
    }
    return textRange;
}

#pragma mark - Traits

- (BOOL)applyTraits:(NSDictionary<NSString *, id> *)traits
              index:(NSUInteger)index
              error:(NSError **)error {
    static NSSet<NSString *> *allowed;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowed = [NSSet setWithArray:@[
            @"autocapitalizationType", @"autocorrectionType",
            @"spellCheckingType", @"smartQuotesType", @"smartDashesType",
            @"smartInsertDeleteType", @"inlinePredictionType",
            @"keyboardType", @"returnKeyType", @"secureTextEntry",
        ]];
    });
    if (traits.count == 0 ||
        ![[NSSet setWithArray:traits.allKeys] isSubsetOfSet:allowed]) {
        return [self fail:error index:index
              description:@"Trait transaction contains unknown or no keys."];
    }
    for (NSString *key in traits) {
        if (![traits[key] isKindOfClass:NSNumber.class]) {
            return [self fail:error index:index
                  description:@"Trait values must be numeric."];
        }
    }
    // Applied through the host's guarded, read-back application — see deviation 2 in the header.
    // A trait the input cannot take is NOT a driver failure: it is a property of the input, and the
    // recorder already publishes it under `telegramUnappliedTraits`. Failing here would abort a
    // scenario over a difference the oracle exists to REPORT.
    [IDTextInputTestHost id_applyTraits:traits input:self.host.input];
    return YES;
}

#pragma mark - Inline traits

- (BOOL)toggleInlineTraitNamed:(NSString *)name
                         index:(NSUInteger)index
                         error:(NSError **)error {
    IDTelegramInlineTrait trait = IDInlineTraitNamed(name);
    if (trait == 0) {
        return [self fail:error index:index
              description:@"Inline trait is unsupported."];
    }

    if (self.host.kind != IDTextInputHostKindStock) {
        IDTelegramInlineTraitToggle toggle = self.host.id_inlineTraitToggle;
        if (toggle == nil) {
            return [self fail:error index:index
                  description:@"The Telegram host offers no inline-trait toggle; the factory must "
                              @"register one. Skipping the toggle would let the arm agree with "
                              @"stock by never having formatted anything."];
        }
        if (!toggle(name)) {
            return [self fail:error index:index
                  description:[NSString stringWithFormat:
                      @"The editor does not support the inline trait '%@'.", name]];
        }
        return YES;
    }

    if (![self.host.input isKindOfClass:UITextView.class]) {
        return [self fail:error index:index
              description:@"Stock formatting host has the wrong class."];
    }

    UITextView *view = (UITextView *)self.host.input;
    UIFont *defaultFont = view.font ?: [UIFont systemFontOfSize:17.0];
    NSRange selection = view.selectedRange;
    if (selection.length == 0) {
        NSDictionary<NSAttributedStringKey, id> *attributes =
            view.typingAttributes ?: @{};
        BOOL enabled =
            (IDStockInlineTraits(attributes) & trait) == 0;
        view.typingAttributes = IDStockAttributesBySettingTrait(
            attributes, trait, enabled, defaultFont);
        return YES;
    }

    __block NSUInteger characterCount = 0;
    __block NSUInteger enabledCount = 0;
    [view.textStorage enumerateAttributesInRange:selection
                                         options:0
                                      usingBlock:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSRange range, BOOL *stop) {
        for (NSUInteger location = range.location;
             location < NSMaxRange(range); location++) {
            if ([view.textStorage.string characterAtIndex:location] == '\n')
                continue;
            characterCount += 1;
            if ((IDStockInlineTraits(attributes) & trait) != 0)
                enabledCount += 1;
        }
    }];
    BOOL enable = characterCount > 0 && enabledCount != characterCount;
    NSAttributedString *snapshot =
        [view.textStorage attributedSubstringFromRange:selection];
    NSRange selectedRange = view.selectedRange;
    [snapshot enumerateAttributesInRange:NSMakeRange(0, snapshot.length)
                                 options:0
                              usingBlock:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSRange localRange, BOOL *stop) {
        for (NSUInteger offset = 0; offset < localRange.length; offset++) {
            NSUInteger local = localRange.location + offset;
            if ([snapshot.string characterAtIndex:local] == '\n') continue;
            [view.textStorage setAttributes:
                IDStockAttributesBySettingTrait(
                    attributes, trait, enable, defaultFont)
                                      range:NSMakeRange(
                                          selection.location + local, 1)];
        }
    }];
    [view.undoManager registerUndoWithTarget:self handler:
        ^(IDTextInputTransactionDriver *target) {
        [target restoreStockAttributes:snapshot
                                 range:selection
                         selectedRange:selectedRange];
    }];
    return YES;
}

- (void)restoreStockAttributes:(NSAttributedString *)snapshot
                         range:(NSRange)range
                 selectedRange:(NSRange)selectedRange {
    UITextView *view = (UITextView *)self.host.input;
    NSAttributedString *inverse =
        [view.textStorage attributedSubstringFromRange:range];
    [view.undoManager registerUndoWithTarget:self handler:
        ^(IDTextInputTransactionDriver *target) {
        [target restoreStockAttributes:inverse
                                 range:range
                         selectedRange:selectedRange];
    }];
    [snapshot enumerateAttributesInRange:NSMakeRange(0, snapshot.length)
                                 options:0
                              usingBlock:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSRange localRange, BOOL *stop) {
        [view.textStorage setAttributes:attributes
                                  range:NSMakeRange(
                                      range.location + localRange.location,
                                      localRange.length)];
    }];
    view.selectedRange = selectedRange;
}

#pragma mark - The 15 transaction kinds

- (IDTextInputSnapshot *)applyTransaction:
    (IDTextInputTransaction *)transaction
                                    index:(NSUInteger)index
                                    error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (transaction == nil) {
        [self fail:error index:index description:@"Transaction is nil."];
        return nil;
    }
    if (transaction.kind != IDTextInputTransactionKindCheckpoint &&
        transaction.phase != nil) {
        [self fail:error index:index
        description:@"Only checkpoints may carry a phase."];
        return nil;
    }

    switch (transaction.kind) {
        case IDTextInputTransactionKindBecomeFirstResponder:
            if (self.host.input.isFirstResponder ||
                ![self.host.input becomeFirstResponder] ||
                !self.host.input.isFirstResponder) {
                [self fail:error index:index
                description:@"First-responder transition was absent."];
            }
            return nil;

        case IDTextInputTransactionKindResignFirstResponder:
            if (!self.host.input.isFirstResponder ||
                ![self.host.input resignFirstResponder] ||
                self.host.input.isFirstResponder) {
                [self fail:error index:index
                description:@"Responder resignation was absent."];
            }
            return nil;

        case IDTextInputTransactionKindSetSelection: {
            UITextRange *range =
                [self textRangeForValue:transaction.rangeValue
                                  index:index error:error];
            if (range != nil) self.host.input.selectedTextRange = range;
            return nil;
        }

        case IDTextInputTransactionKindSetMarkedText:
            if (transaction.text == nil ||
                transaction.selectedRangeValue == nil) {
                [self fail:error index:index
                description:@"Marked text and relative selection are required."];
                return nil;
            }
            [self.host.input
                setMarkedText:transaction.text
                selectedRange:transaction.selectedRangeValue.rangeValue];
            return nil;

        case IDTextInputTransactionKindUnmarkText:
            [self.host.input unmarkText];
            return nil;

        case IDTextInputTransactionKindInsertText:
            if (transaction.text == nil) {
                [self fail:error index:index
                description:@"Inserted text is required."];
                return nil;
            }
            [(id<UIKeyInput>)self.host.input insertText:transaction.text];
            return nil;

        case IDTextInputTransactionKindDeleteBackward:
            [(id<UIKeyInput>)self.host.input deleteBackward];
            return nil;

        case IDTextInputTransactionKindReplaceRange: {
            UITextRange *range =
                [self textRangeForValue:transaction.rangeValue
                                  index:index error:error];
            if (range == nil) return nil;
            if (transaction.text == nil) {
                [self fail:error index:index
                description:@"Replacement text is required."];
                return nil;
            }
            [self.host.input replaceRange:range withText:transaction.text];
            return nil;
        }

        case IDTextInputTransactionKindBeginUndoGroup:
            [self.host.input.undoManager beginUndoGrouping];
            self.undoGroupingDepth += 1;
            return nil;

        case IDTextInputTransactionKindEndUndoGroup:
            if (self.undoGroupingDepth == 0) {
                [self fail:error index:index
                description:@"Undo group closes before it opens."];
                return nil;
            }
            [self.host.input.undoManager endUndoGrouping];
            self.undoGroupingDepth -= 1;
            return nil;

        case IDTextInputTransactionKindUndo:
            if (!self.host.input.undoManager.canUndo) {
                [self fail:error index:index
                description:@"Undo is unavailable."];
                return nil;
            }
            [self.host.input.undoManager undo];
            return nil;

        case IDTextInputTransactionKindRedo:
            if (!self.host.input.undoManager.canRedo) {
                [self fail:error index:index
                description:@"Redo is unavailable."];
                return nil;
            }
            [self.host.input.undoManager redo];
            return nil;

        case IDTextInputTransactionKindSetTraits:
            [self applyTraits:transaction.traits index:index error:error];
            return nil;

        case IDTextInputTransactionKindToggleInlineTrait:
            [self toggleInlineTraitNamed:transaction.trait
                                   index:index error:error];
            return nil;

        case IDTextInputTransactionKindCheckpoint:
            if (transaction.phase.length == 0) {
                [self fail:error index:index
                description:@"Checkpoint phase is required."];
                return nil;
            }
            return [self.recorder capturePhase:transaction.phase];
    }
    [self fail:error index:index description:@"Transaction kind is unknown."];
    return nil;
}

@end
