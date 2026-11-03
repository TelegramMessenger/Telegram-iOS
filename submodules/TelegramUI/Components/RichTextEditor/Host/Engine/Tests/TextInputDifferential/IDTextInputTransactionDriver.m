#import "IDTextInputTransactionDriver.h"

#import "IDBlockTextView.h"
#import "IDInlineTextFormatting.h"

NSString *const IDTextInputTransactionErrorDomain =
    @"com.inputdec.tests.text-input-transaction";

@interface UIView (IDTextInputDriverTraits)
@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;
@property(nonatomic) UITextSpellCheckingType spellCheckingType;
@property(nonatomic) UITextSmartQuotesType smartQuotesType;
@property(nonatomic) UITextSmartDashesType smartDashesType;
@property(nonatomic) UITextSmartInsertDeleteType smartInsertDeleteType;
@property(nonatomic) UITextInlinePredictionType inlinePredictionType;
@property(nonatomic) UIKeyboardType keyboardType;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@end

@interface IDTextInputTransactionDriver ()
@property(nonatomic, strong) IDTextInputTestHost *host;
@property(nonatomic, strong) IDTextInputStateRecorder *recorder;
@property(nonatomic) NSUInteger undoGroupingDepth;
- (void)restoreStockAttributes:(NSAttributedString *)snapshot
                          range:(NSRange)range
                  selectedRange:(NSRange)selectedRange;
@end

@implementation IDTextInputTransactionDriver

static IDInlineTextTraits IDInlineTraitNamed(NSString *name) {
    if ([name isEqualToString:@"bold"]) return IDInlineTextTraitBold;
    if ([name isEqualToString:@"italic"]) return IDInlineTextTraitItalic;
    if ([name isEqualToString:@"underline"])
        return IDInlineTextTraitUnderline;
    if ([name isEqualToString:@"strikethrough"])
        return IDInlineTextTraitStrikethrough;
    return 0;
}

static IDInlineTextTraits IDStockInlineTraits(
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    IDInlineTextTraits traits = 0;
    UIFont *font = attributes[NSFontAttributeName];
    UIFontDescriptorSymbolicTraits fontTraits =
        [font isKindOfClass:UIFont.class]
            ? font.fontDescriptor.symbolicTraits : 0;
    if ((fontTraits & UIFontDescriptorTraitBold) != 0)
        traits |= IDInlineTextTraitBold;
    if ((fontTraits & UIFontDescriptorTraitItalic) != 0)
        traits |= IDInlineTextTraitItalic;
    if ([attributes[NSUnderlineStyleAttributeName] integerValue] != 0)
        traits |= IDInlineTextTraitUnderline;
    if ([attributes[NSStrikethroughStyleAttributeName] integerValue] != 0)
        traits |= IDInlineTextTraitStrikethrough;
    return traits;
}

static NSDictionary<NSAttributedStringKey, id> *
IDStockAttributesBySettingTrait(
    NSDictionary<NSAttributedStringKey, id> *attributes,
    IDInlineTextTraits trait,
    BOOL enabled,
    UIFont *defaultFont) {
    NSMutableDictionary<NSAttributedStringKey, id> *result =
        attributes.mutableCopy;
    if (trait == IDInlineTextTraitBold ||
        trait == IDInlineTextTraitItalic) {
        UIFont *font = [attributes[NSFontAttributeName]
            isKindOfClass:UIFont.class]
            ? attributes[NSFontAttributeName] : defaultFont;
        UIFontDescriptorSymbolicTraits symbolicTraits =
            font.fontDescriptor.symbolicTraits;
        UIFontDescriptorSymbolicTraits fontTrait =
            trait == IDInlineTextTraitBold
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
            trait == IDInlineTextTraitUnderline
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

static NSError *IDTransactionError(NSUInteger index,
                                   NSString *description) {
    return [NSError errorWithDomain:IDTextInputTransactionErrorDomain
                               code:1
                           userInfo:@{
        NSLocalizedDescriptionKey:
            [NSString stringWithFormat:@"Transaction %lu: %@",
                                       (unsigned long)index, description],
    }];
}

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

- (BOOL)fail:(NSError **)error
       index:(NSUInteger)index
 description:(NSString *)description {
    if (error != NULL) *error = IDTransactionError(index, description);
    return NO;
}

- (NSUInteger)documentLength {
    NSInteger length = [self.host.input
        offsetFromPosition:self.host.input.beginningOfDocument
                toPosition:self.host.input.endOfDocument];
    return length < 0 ? 0 : (NSUInteger)length;
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
        description:@"Range is outside the current document."];
        return nil;
    }
    UITextPosition *start = [self.host.input
        positionFromPosition:self.host.input.beginningOfDocument
                       offset:(NSInteger)range.location];
    UITextPosition *end = [self.host.input
        positionFromPosition:start offset:(NSInteger)range.length];
    UITextRange *textRange = start != nil && end != nil
        ? [self.host.input textRangeFromPosition:start toPosition:end] : nil;
    if (textRange == nil) {
        [self fail:error index:index
        description:@"Range cannot be represented by UITextInput."];
    }
    return textRange;
}

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
    UIView *input = self.host.input;
    for (NSString *key in traits) {
        id value = traits[key];
        if (![value isKindOfClass:NSNumber.class]) {
            return [self fail:error index:index
                  description:@"Trait values must be numeric."];
        }
        if ([key isEqualToString:@"autocapitalizationType"])
            input.autocapitalizationType = [value integerValue];
        else if ([key isEqualToString:@"autocorrectionType"])
            input.autocorrectionType = [value integerValue];
        else if ([key isEqualToString:@"spellCheckingType"])
            input.spellCheckingType = [value integerValue];
        else if ([key isEqualToString:@"smartQuotesType"])
            input.smartQuotesType = [value integerValue];
        else if ([key isEqualToString:@"smartDashesType"])
            input.smartDashesType = [value integerValue];
        else if ([key isEqualToString:@"smartInsertDeleteType"])
            input.smartInsertDeleteType = [value integerValue];
        else if ([key isEqualToString:@"inlinePredictionType"])
            input.inlinePredictionType = [value integerValue];
        else if ([key isEqualToString:@"keyboardType"])
            input.keyboardType = [value integerValue];
        else if ([key isEqualToString:@"returnKeyType"])
            input.returnKeyType = [value integerValue];
        else if ([key isEqualToString:@"secureTextEntry"])
            input.secureTextEntry = [value boolValue];
    }
    return YES;
}

- (BOOL)toggleInlineTraitNamed:(NSString *)name
                          index:(NSUInteger)index
                          error:(NSError **)error {
    IDInlineTextTraits trait = IDInlineTraitNamed(name);
    if (trait == 0) {
        return [self fail:error index:index
              description:@"Inline trait is unsupported."];
    }
    if (self.host.kind != IDTextInputHostKindStock) {
        if (![self.host.input isKindOfClass:IDBlockTextView.class]) {
            return [self fail:error index:index
                  description:@"Custom formatting host has the wrong class."];
        }
        [(IDBlockTextView *)self.host.input toggleInlineTextTrait:trait];
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
