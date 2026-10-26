#import "IDTextInputStateRecorder.h"

#include <math.h>

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDUIKitBehaviorReport.h"

NSArray<NSString *> *IDNormalizedInlineTraitNames(
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    UIFont *font = attributes[NSFontAttributeName];
    UIFontDescriptorSymbolicTraits fontTraits =
        [font isKindOfClass:UIFont.class]
            ? font.fontDescriptor.symbolicTraits : 0;
    if ((fontTraits & UIFontDescriptorTraitBold) != 0) {
        [result addObject:@"bold"];
    }
    if ((fontTraits & UIFontDescriptorTraitItalic) != 0) {
        [result addObject:@"italic"];
    }
    if ([attributes[NSUnderlineStyleAttributeName] integerValue] != 0) {
        [result addObject:@"underline"];
    }
    if ([attributes[NSStrikethroughStyleAttributeName] integerValue] != 0) {
        [result addObject:@"strikethrough"];
    }
    return result.copy;
}

NSArray<NSDictionary<NSString *, id> *> *
IDNormalizedInlineRuns(NSTextStorage *storage) {
    if (storage.length == 0) return @[];
    NSMutableArray<NSDictionary<NSString *, id> *> *result =
        [NSMutableArray array];
    NSString *string = storage.string;
    NSUInteger runStart = 0;
    NSArray<NSString *> *runTraits = nil;
    for (NSUInteger index = 0; index < storage.length; index += 1) {
        NSArray<NSString *> *traits =
            [string characterAtIndex:index] == '\n'
                ? @[]
                : IDNormalizedInlineTraitNames(
                    [storage attributesAtIndex:index effectiveRange:NULL]);
        if (runTraits == nil) {
            runTraits = traits;
            runStart = index;
            continue;
        }
        if ([runTraits isEqualToArray:traits]) continue;
        [result addObject:@{
            @"range": @{
                @"location": @(runStart),
                @"length": @(index - runStart),
            },
            @"traits": runTraits,
        }];
        runStart = index;
        runTraits = traits;
    }
    [result addObject:@{
        @"range": @{
            @"location": @(runStart),
            @"length": @(storage.length - runStart),
        },
        @"traits": runTraits ?: @[],
    }];
    return result.copy;
}

@interface UIView (IDTextInputRecorderTraits)
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
- (UITextStorageDirection)selectionAffinity;
@end

@interface IDTextInputSnapshot ()
@property(nonatomic, copy, readwrite) NSString *phase;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *state;
@end

@implementation IDTextInputSnapshot
@end

@interface IDTextInputDelegateRecorder :
    NSObject <UITextInputDelegate>
@property(nonatomic, weak) id<UITextInputDelegate> forwardingDelegate;
@property(nonatomic, strong)
    NSMutableArray<NSString *> *events;
@end

@implementation IDTextInputDelegateRecorder

- (instancetype)init {
    self = [super init];
    if (self != nil) _events = [NSMutableArray array];
    return self;
}

- (void)selectionWillChange:(id<UITextInput>)textInput {
    [self.events addObject:@"selectionWillChange"];
    [self.forwardingDelegate selectionWillChange:textInput];
}

- (void)selectionDidChange:(id<UITextInput>)textInput {
    [self.events addObject:@"selectionDidChange"];
    [self.forwardingDelegate selectionDidChange:textInput];
}

- (void)textWillChange:(id<UITextInput>)textInput {
    [self.events addObject:@"textWillChange"];
    [self.forwardingDelegate textWillChange:textInput];
}

- (void)textDidChange:(id<UITextInput>)textInput {
    [self.events addObject:@"textDidChange"];
    [self.forwardingDelegate textDidChange:textInput];
}

- (void)conversationContext:(UIConversationContext *)context
                  didChange:(id<UITextInput>)textInput {
    [self.events addObject:@"conversationContextDidChange"];
    [self.forwardingDelegate conversationContext:context didChange:textInput];
}

@end

@interface IDTextInputStateRecorder ()

@property(nonatomic, strong) IDTextInputTestHost *host;
@property(nonatomic, strong) IDTextInputDelegateRecorder *delegateRecorder;
@property(nonatomic, strong, nullable) id<UITextInputDelegate> priorDelegate;
@property(nonatomic, strong, nullable) id storageObserver;
@property(nonatomic, strong)
    NSMutableArray<NSDictionary<NSString *, id> *> *storageMutations;
@property(nonatomic) BOOL detached;

@end

@implementation IDTextInputStateRecorder

static NSDictionary<NSString *, NSNumber *> *IDRecorderRange(NSRange range) {
    return @{@"location": @(range.location), @"length": @(range.length)};
}

static NSDictionary<NSString *, NSNumber *> *IDRecorderRect(CGRect rect) {
    return @{
        @"x": @(rect.origin.x),
        @"y": @(rect.origin.y),
        @"width": @(rect.size.width),
        @"height": @(rect.size.height),
    };
}

static BOOL IDRecorderRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

- (instancetype)initWithHost:(IDTextInputTestHost *)host {
    NSParameterAssert(host != nil);
    self = [super init];
    if (self == nil) return nil;
    _host = host;
    _storageMutations = [NSMutableArray array];
    _priorDelegate = host.input.inputDelegate;
    _delegateRecorder = [IDTextInputDelegateRecorder new];
    _delegateRecorder.forwardingDelegate = _priorDelegate;
    host.input.inputDelegate = _delegateRecorder;
    __weak typeof(self) weakSelf = self;
    _storageObserver = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:host.observedTextStorage
                     queue:nil
                usingBlock:^(NSNotification *notification) {
        typeof(self) strongSelf = weakSelf;
        NSTextStorage *storage = notification.object;
        if (strongSelf == nil || storage == nil) return;
        [strongSelf.storageMutations addObject:@{
            @"editedMask": @(storage.editedMask),
            @"range": IDRecorderRange(storage.editedRange),
            @"delta": @(storage.changeInLength),
        }];
    }];
    return self;
}

- (NSRange)rangeForTextRange:(UITextRange *)range {
    if (range == nil) return NSMakeRange(NSNotFound, 0);
    NSInteger location = [self.host.input
        offsetFromPosition:self.host.input.beginningOfDocument
                toPosition:range.start];
    NSInteger length = [self.host.input
        offsetFromPosition:range.start toPosition:range.end];
    if (location < 0 || length < 0) return NSMakeRange(NSNotFound, 0);
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (NSString *)canonicalText {
    UITextRange *range = [self.host.input
        textRangeFromPosition:self.host.input.beginningOfDocument
                    toPosition:self.host.input.endOfDocument];
    return [self.host.input textInRange:range] ?: @"";
}

- (NSArray<NSString *> *)blocksForCanonical:(NSString *)canonical {
    if (self.host.kind != IDTextInputHostKindStock) {
        IDBlockTextView *custom = (IDBlockTextView *)self.host.input;
        NSMutableArray<NSString *> *blocks = [NSMutableArray array];
        for (NSAttributedString *block in custom.attributedBlocks) {
            [blocks addObject:block.string ?: @""];
        }
        return blocks.copy;
    }
    return [canonical componentsSeparatedByString:@"\n"];
}

- (NSDictionary<NSString *, NSNumber *> *)traits {
    UIView *input = self.host.input;
    return @{
        @"autocapitalizationType": @(input.autocapitalizationType),
        @"autocorrectionType": @(input.autocorrectionType),
        @"spellCheckingType": @(input.spellCheckingType),
        @"smartQuotesType": @(input.smartQuotesType),
        @"smartDashesType": @(input.smartDashesType),
        @"smartInsertDeleteType": @(input.smartInsertDeleteType),
        @"inlinePredictionType": @(input.inlinePredictionType),
        @"keyboardType": @(input.keyboardType),
        @"returnKeyType": @(input.returnKeyType),
        @"secureTextEntry": @(input.isSecureTextEntry),
    };
}

- (NSArray<NSDictionary<NSString *, id> *> *)selectionRectangles {
    NSMutableArray<NSDictionary<NSString *, id> *> *result =
        [NSMutableArray array];
    for (UITextSelectionRect *selectionRect in
         [self.host.input
             selectionRectsForRange:self.host.input.selectedTextRange]) {
        if (!IDRecorderRectIsFinite(selectionRect.rect)) continue;
        [result addObject:@{
            @"rect": IDRecorderRect(selectionRect.rect),
            @"writingDirection": @(selectionRect.writingDirection),
            @"containsStart": @(selectionRect.containsStart),
            @"containsEnd": @(selectionRect.containsEnd),
            @"vertical": @(selectionRect.isVertical),
        }];
    }
    [result sortUsingComparator:
        ^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSDictionary *leftRect = left[@"rect"];
        NSDictionary *rightRect = right[@"rect"];
        for (NSString *key in @[@"y", @"x", @"height", @"width"]) {
            NSComparisonResult order =
                [leftRect[key] compare:rightRect[key]];
            if (order != NSOrderedSame) return order;
        }
        return NSOrderedSame;
    }];
    return result.copy;
}

- (NSArray<NSString *> *)typingInlineTraits {
    NSRange selectedRange =
        [self rangeForTextRange:self.host.input.selectedTextRange];
    if (selectedRange.location != NSNotFound &&
        selectedRange.length > 0) {
        NSMutableSet<NSString *> *intersection = nil;
        NSString *string = self.host.observedTextStorage.string;
        for (NSUInteger index = selectedRange.location;
             index < NSMaxRange(selectedRange); index++) {
            if ([string characterAtIndex:index] == '\n') continue;
            NSSet<NSString *> *traits = [NSSet setWithArray:
                IDNormalizedInlineTraitNames(
                    [self.host.observedTextStorage
                        attributesAtIndex:index effectiveRange:NULL])];
            if (intersection == nil) {
                intersection = traits.mutableCopy;
            } else {
                [intersection intersectSet:traits];
            }
        }
        NSMutableArray<NSString *> *ordered = [NSMutableArray array];
        for (NSString *name in @[
                 @"bold", @"italic", @"underline", @"strikethrough",
             ]) {
            if ([intersection containsObject:name])
                [ordered addObject:name];
        }
        return ordered.copy;
    }
    if (self.host.kind == IDTextInputHostKindStock &&
        [self.host.input isKindOfClass:UITextView.class]) {
        return IDNormalizedInlineTraitNames(
            ((UITextView *)self.host.input).typingAttributes ?: @{});
    }
    if (self.host.kind != IDTextInputHostKindStock &&
        [self.host.input isKindOfClass:IDBlockTextView.class]) {
        IDBlockTextView *view = (IDBlockTextView *)self.host.input;
        return IDNormalizedInlineTraitNames(
            IDPrivateInputTypingAttributes(view.id_inputController));
    }
    UITextPosition *position =
        self.host.input.selectedTextRange.start ?:
        self.host.input.beginningOfDocument;
    NSDictionary<NSAttributedStringKey, id> *attributes =
        [self.host.input textStylingAtPosition:position
                                  inDirection:UITextStorageDirectionForward];
    return IDNormalizedInlineTraitNames(attributes ?: @{});
}

static NSString *IDNormalizedAnnotationName(id key) {
    NSString *name = [key isKindOfClass:NSString.class]
        ? key : [key description];
    if ([name localizedCaseInsensitiveContainsString:@"spelling"])
        return @"spelling";
    if ([name localizedCaseInsensitiveContainsString:@"alternative"])
        return @"alternatives";
    if ([name localizedCaseInsensitiveContainsString:@"marked"])
        return @"marked-text";
    return name ?: @"unknown";
}

- (NSArray<NSDictionary<NSString *, id> *> *)annotationRanges {
    if (!self.host.comparesAnnotations) return @[];
    NSUInteger length = self.host.observedTextStorage.length;
    if (length == 0) return @[];

    NSAttributedString *annotated = nil;
    if (self.host.kind == IDTextInputHostKindStock) {
        annotated = [self.host.observedTextStorage
            attributedSubstringFromRange:NSMakeRange(0, length)];
    } else {
        IDBlockTextView *view = (IDBlockTextView *)self.host.input;
        UITextRange *range = [view
            textRangeFromPosition:view.beginningOfDocument
                       toPosition:view.endOfDocument];
        annotated = [view.id_richLayoutController
            id_annotatedSubstringForRange:range];
    }
    if (annotated.length == 0) return @[];

    NSSet<NSAttributedStringKey> *semanticKeys =
        [NSSet setWithArray:@[
            NSFontAttributeName, NSForegroundColorAttributeName,
            NSBackgroundColorAttributeName, NSUnderlineStyleAttributeName,
            NSStrikethroughStyleAttributeName, NSParagraphStyleAttributeName,
            NSKernAttributeName, NSLigatureAttributeName,
            NSBaselineOffsetAttributeName, NSLinkAttributeName,
            NSAttachmentAttributeName,
        ]];
    NSMutableArray<NSDictionary<NSString *, id> *> *result =
        [NSMutableArray array];
    [annotated enumerateAttributesInRange:NSMakeRange(0, annotated.length)
                                  options:0
                               usingBlock:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSRange range, BOOL *stop) {
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (id key in attributes) {
            if (![semanticKeys containsObject:key]) {
                [names addObject:IDNormalizedAnnotationName(key)];
            }
        }
        [names sortUsingSelector:@selector(compare:)];
        if (names.count == 0) return;
        [result addObject:@{
            @"range": IDRecorderRange(range),
            @"names": names.copy,
        }];
    }];
    return result.copy;
}

- (NSArray<NSDictionary<NSString *, id> *> *)behaviorCapabilities {
    if (self.host.kind == IDTextInputHostKindStock) {
        return @[@{@"identifier": @"stock-uikit",
                   @"state": @"system"}];
    }
    if (self.host.kind == IDTextInputHostKindReference) {
        return @[@{@"identifier": @"reference-uikit",
                   @"state": @"system"}];
    }
    IDBlockTextView *view = (IDBlockTextView *)self.host.input;
    NSMutableArray *result = [NSMutableArray array];
    for (IDUIKitCapabilityReport *capability
         in view.id_behaviorReport.capabilities) {
        [result addObject:capability.normalizedDictionary];
    }
    return result.copy;
}

- (BOOL)behaviorDetached {
    if (self.host.kind != IDTextInputHostKindMinimal) return NO;
    return ((IDBlockTextView *)self.host.input)
        .id_behaviorReport.isDetached;
}

- (IDTextInputSnapshot *)capturePhase:(NSString *)phase {
    NSParameterAssert(phase.length > 0);
    NSString *canonical = [self canonicalText];
    NSRange selection =
        [self rangeForTextRange:self.host.input.selectedTextRange];
    NSRange marked =
        [self rangeForTextRange:self.host.input.markedTextRange];
    NSString *markedText = self.host.input.markedTextRange != nil
        ? [self.host.input textInRange:self.host.input.markedTextRange] ?: @""
        : @"";
    UITextPosition *caretPosition =
        self.host.input.selectedTextRange.end ?:
        self.host.input.beginningOfDocument;
    CGRect caret = [self.host.input caretRectForPosition:caretPosition];
    UITextStorageDirection affinity =
        [(UIView *)self.host.input selectionAffinity];
    NSUndoManager *undoManager = self.host.input.undoManager;

    IDTextInputSnapshot *snapshot = [IDTextInputSnapshot new];
    snapshot.phase = phase;
    snapshot.state = @{
        @"canonical": canonical,
        @"blocks": [self blocksForCanonical:canonical],
        @"selection": IDRecorderRange(selection),
        @"markedRange": IDRecorderRange(marked),
        @"markedText": markedText,
        @"affinity":
            affinity == UITextStorageDirectionBackward
                ? @"backward" : @"forward",
        @"firstResponder": @(self.host.input.isFirstResponder),
        @"canUndo": @(undoManager.canUndo),
        @"canRedo": @(undoManager.canRedo),
        @"traits": [self traits],
        @"caretRect": IDRecorderRect(caret),
        @"selectionRects": [self selectionRectangles],
        @"inputDelegateTrace": self.delegateRecorder.events.copy,
        @"storageMutationTrace": self.storageMutations.copy,
        @"typingInlineTraits": [self typingInlineTraits],
        @"inlineRuns": IDNormalizedInlineRuns(self.host.observedTextStorage),
        @"annotationRanges": [self annotationRanges],
        @"behaviorCapabilities": [self behaviorCapabilities],
        @"behaviorDetached": @([self behaviorDetached]),
    };
    return snapshot;
}

- (void)resetTransactionTraces {
    [self.delegateRecorder.events removeAllObjects];
    [self.storageMutations removeAllObjects];
}

- (void)detach {
    if (self.detached) return;
    self.detached = YES;
    if (self.storageObserver != nil) {
        [NSNotificationCenter.defaultCenter
            removeObserver:self.storageObserver];
        self.storageObserver = nil;
    }
    if (self.host.input.inputDelegate == self.delegateRecorder) {
        self.host.input.inputDelegate = self.priorDelegate;
    }
    self.delegateRecorder.forwardingDelegate = nil;
}

- (void)dealloc {
    [self detach];
}

@end
