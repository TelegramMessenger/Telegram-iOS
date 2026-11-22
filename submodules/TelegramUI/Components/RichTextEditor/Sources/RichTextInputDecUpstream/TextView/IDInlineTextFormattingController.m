#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDInlineTextFormattingController.h"

#import "IDBlockDocument.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapterInternal.h"
#import "IDInlineTextStyleResolver.h"
#import "IDUIKitInputControllerCapability.h"

@interface IDInlineTextFormattingController ()
@property(nonatomic, weak) IDBlockTextView *host;
@property(nonatomic, strong) IDBlockDocument *document;
@property(nonatomic, strong) IDCanonicalTextStorageAdapter *textStorage;
@property(nonatomic, strong) IDInlineTextStyleResolver *styleResolver;
@property(nonatomic, strong) NSArray<id> *undoCompletionObservers;
@property(nonatomic) BOOL performingFormattingCommand;
- (void)registerUndoSnapshot:(NSArray<NSAttributedString *> *)snapshot
                   selection:(NSRange)selection;
- (void)restoreSnapshot:(NSArray<NSAttributedString *> *)snapshot
              selection:(NSRange)selection;
- (void)notifyStateChanged;
@end

@implementation IDInlineTextFormattingController

- (instancetype)initWithHost:(IDBlockTextView *)host
                    document:(IDBlockDocument *)document
                 textStorage:(IDCanonicalTextStorageAdapter *)textStorage
               styleResolver:(IDInlineTextStyleResolver *)resolver {
    if (host == nil || document == nil || textStorage == nil ||
        resolver == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Inline formatting controller dependencies must not be nil."];
    }
    self = [super init];
    if (self != nil) {
        _host = host;
        _document = document;
        _textStorage = textStorage;
        _styleResolver = resolver;
        __weak typeof(self) weakSelf = self;
        NSMutableArray<id> *observers = [NSMutableArray array];
        for (NSNotificationName name in @[
                 NSUndoManagerDidUndoChangeNotification,
                 NSUndoManagerDidRedoChangeNotification,
             ]) {
            id observer = [NSNotificationCenter.defaultCenter
                addObserverForName:name
                            object:host.undoManager
                             queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *notification) {
                IDInlineTextFormattingController *strongSelf = weakSelf;
                if (strongSelf.host.id_behaviorInput != nil) {
                    [strongSelf.host.id_behaviorInput
                        invalidateTypingAttributes];
                    [strongSelf notifyStateChanged];
                }
            }];
            [observers addObject:observer];
        }
        _undoCompletionObservers = observers.copy;
    }
    return self;
}

- (void)dealloc {
    for (id observer in self.undoCompletionObservers) {
        [NSNotificationCenter.defaultCenter removeObserver:observer];
    }
}

- (void)validateTrait:(IDInlineTextTraits)trait {
    switch (trait) {
        case IDInlineTextTraitBold:
        case IDInlineTextTraitItalic:
        case IDInlineTextTraitUnderline:
        case IDInlineTextTraitStrikethrough:
            return;
        default:
            [NSException raise:NSInvalidArgumentException
                        format:@"Inline formatting commands require exactly one supported trait."];
    }
}

- (NSRange)selectedCanonicalRange {
    return [self.host id_NSRangeForTextRange:self.host.selectedTextRange];
}

- (void)enumerateSelectedTextRuns:
    (void (^)(NSDictionary<NSAttributedStringKey, id> *attributes,
              NSUInteger length))block {
    NSRange selection = [self selectedCanonicalRange];
    if (selection.location == NSNotFound || selection.length == 0 ||
        block == nil) {
        return;
    }
    __block NSUInteger blockStart = 0;
    [self.document.blocks enumerateObjectsUsingBlock:
        ^(IDBlock *documentBlock, NSUInteger index, BOOL *stop) {
        NSRange textRange =
            NSMakeRange(blockStart, documentBlock.attributedText.length);
        NSRange intersection = NSIntersectionRange(selection, textRange);
        if (intersection.length > 0) {
            NSRange localRange =
                NSMakeRange(intersection.location - blockStart,
                            intersection.length);
            [documentBlock.attributedText
                enumerateAttributesInRange:localRange
                                   options:0
                                usingBlock:
                ^(NSDictionary<NSAttributedStringKey, id> *attributes,
                  NSRange runRange,
                  BOOL *runStop) {
                block(attributes, runRange.length);
            }];
        }
        blockStart += documentBlock.attributedText.length;
        if (index + 1 < self.document.blocks.count) {
            blockStart += 1;
        }
    }];
}

- (IDInlineTextTraitState)stateForTrait:(IDInlineTextTraits)trait {
    [self validateTrait:trait];
    NSRange selection = [self selectedCanonicalRange];
    if (selection.location != NSNotFound && selection.length == 0) {
        IDInlineTextTraits typingTraits =
            [self.styleResolver traitsInAttributes:
                self.host.id_behaviorInput.typingAttributes];
        return (typingTraits & trait) != 0
            ? IDInlineTextTraitStateOn
            : IDInlineTextTraitStateOff;
    }
    __block NSUInteger selectedCharacterCount = 0;
    __block NSUInteger enabledCharacterCount = 0;
    [self enumerateSelectedTextRuns:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSUInteger length) {
        selectedCharacterCount += length;
        if (([self.styleResolver traitsInAttributes:attributes] &
             trait) != 0) {
            enabledCharacterCount += length;
        }
    }];
    if (selectedCharacterCount == 0 || enabledCharacterCount == 0) {
        return IDInlineTextTraitStateOff;
    }
    if (selectedCharacterCount == enabledCharacterCount) {
        return IDInlineTextTraitStateOn;
    }
    return IDInlineTextTraitStateMixed;
}

- (IDInlineTextTraits)effectiveInlineTextTraits {
    NSRange selection = [self selectedCanonicalRange];
    if (selection.location != NSNotFound && selection.length == 0) {
        return [self.styleResolver traitsInAttributes:
            self.host.id_behaviorInput.typingAttributes];
    }
    IDInlineTextTraits result = 0;
    for (NSNumber *value in @[
             @(IDInlineTextTraitBold),
             @(IDInlineTextTraitItalic),
             @(IDInlineTextTraitUnderline),
             @(IDInlineTextTraitStrikethrough),
         ]) {
        IDInlineTextTraits trait = value.unsignedIntegerValue;
        if ([self stateForTrait:trait] == IDInlineTextTraitStateOn) {
            result |= trait;
        }
    }
    return result;
}

#pragma mark - Host attributes

/// The STORAGE half of the host-attribute contract; `IDInlineTextStyleContributor` is the
/// presentation half. Deliberately mirrors `toggleTrait:` below rather than writing the document
/// directly — the undo snapshot, the `performingFormattingCommand` bracket and the state
/// notification are all load-bearing, and a host reaching past this into the document would skip
/// every one of them.
- (void)transformInlineAttributesUsingBlock:
    (NSDictionary<NSAttributedStringKey, id> *(^)(
        NSDictionary<NSAttributedStringKey, id> *))block {
    NSParameterAssert(block != nil);
    NSRange selection = [self selectedCanonicalRange];
    if (selection.location == NSNotFound) {
        return;
    }
    if (selection.length == 0) {
        self.host.id_behaviorInput.typingAttributes =
            block(self.host.id_behaviorInput.typingAttributes);
        [self notifyStateChanged];
        return;
    }
    NSArray<NSAttributedString *> *beforeBlocks = self.host.attributedBlocks;
    NSRange beforeSelection = selection;

    self.performingFormattingCommand = YES;
    IDBlockDocumentChange *change = nil;
    @try {
        change = [self.textStorage
            id_transformTextAttributesInCanonicalRange:selection
                                            usingBlock:block];
    } @finally {
        self.performingFormattingCommand = NO;
    }
    if (change == nil) {
        return;
    }
    [self registerUndoSnapshot:beforeBlocks selection:beforeSelection];
    [self notifyStateChanged];
}

- (void)setHostAttributeValue:(nullable id)value
                       forKey:(NSAttributedStringKey)key {
    NSParameterAssert(key.length > 0);
    [self transformInlineAttributesUsingBlock:
        ^NSDictionary<NSAttributedStringKey, id> *(
            NSDictionary<NSAttributedStringKey, id> *attributes) {
        NSMutableDictionary<NSAttributedStringKey, id> *result =
            [attributes mutableCopy];
        if (value == nil) {
            [result removeObjectForKey:key];
        } else {
            result[key] = value;
        }
        return result;
    }];
}

- (nullable id)hostAttributeValueForKey:(NSAttributedStringKey)key {
    NSParameterAssert(key.length > 0);
    NSRange selection = [self selectedCanonicalRange];
    if (selection.location == NSNotFound) {
        return nil;
    }
    if (selection.length == 0) {
        return self.host.id_behaviorInput.typingAttributes[key];
    }
    // A selection spanning two different links, or a link and plain text, has no single answer.
    // Reporting either endpoint's value would be a plausible-looking wrong answer of exactly the
    // shape this project bans, so it reports nil — "the selection carries no ONE value".
    __block id uniformValue = nil;
    __block BOOL sawFirstRun = NO;
    __block BOOL isMixed = NO;
    [self enumerateSelectedTextRuns:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSUInteger length) {
        if (isMixed) {
            return;
        }
        id value = attributes[key];
        if (!sawFirstRun) {
            uniformValue = value;
            sawFirstRun = YES;
            return;
        }
        BOOL same = (uniformValue == nil && value == nil) ||
                    [uniformValue isEqual:value];
        if (!same) {
            isMixed = YES;
        }
    }];
    return isMixed ? nil : uniformValue;
}

- (void)toggleTrait:(IDInlineTextTraits)trait {
    [self validateTrait:trait];
    NSRange selection = [self selectedCanonicalRange];
    if (selection.location == NSNotFound) {
        return;
    }
    if (selection.length == 0) {
        NSDictionary<NSAttributedStringKey, id> *attributes =
            self.host.id_behaviorInput.typingAttributes;
        IDInlineTextTraits traits =
            [self.styleResolver traitsInAttributes:attributes];
        traits = (traits & trait) != 0
            ? traits & ~trait
            : traits | trait;
        self.host.id_behaviorInput.typingAttributes =
            [self.styleResolver attributesByApplyingTraits:traits
                                              toAttributes:attributes];
        [self notifyStateChanged];
        return;
    }
    BOOL shouldEnable =
        [self stateForTrait:trait] != IDInlineTextTraitStateOn;
    NSArray<NSAttributedString *> *beforeBlocks =
        self.host.attributedBlocks;
    NSRange beforeSelection = selection;

    self.performingFormattingCommand = YES;
    IDBlockDocumentChange *change = nil;
    @try {
        __weak IDInlineTextFormattingController *weakSelf = self;
        change =
            [self.textStorage
                id_transformTextAttributesInCanonicalRange:selection
                                                usingBlock:
            ^NSDictionary<NSAttributedStringKey, id> *(
                NSDictionary<NSAttributedStringKey, id> *attributes) {
            IDInlineTextFormattingController *strongSelf = weakSelf;
            IDInlineTextTraits traits =
                [strongSelf.styleResolver
                    traitsInAttributes:attributes];
            traits = shouldEnable ? traits | trait : traits & ~trait;
            return [strongSelf.styleResolver
                attributesByApplyingTraits:traits
                              toAttributes:attributes];
        }];
    } @finally {
        self.performingFormattingCommand = NO;
    }
    if (change == nil) {
        return;
    }
    [self registerUndoSnapshot:beforeBlocks
                     selection:beforeSelection];
    [self notifyStateChanged];
}

- (void)registerUndoSnapshot:
    (NSArray<NSAttributedString *> *)snapshot
                     selection:(NSRange)selection {
    NSUndoManager *undoManager = self.host.undoManager;
    __weak IDInlineTextFormattingController *weakSelf = self;
    [undoManager
        registerUndoWithTarget:self
                      handler:
        ^(IDInlineTextFormattingController *target) {
        IDInlineTextFormattingController *strongSelf = weakSelf ?: target;
        [strongSelf restoreSnapshot:snapshot selection:selection];
    }];
    [undoManager setActionName:@"Formatting"];
}

- (void)restoreSnapshot:(NSArray<NSAttributedString *> *)snapshot
              selection:(NSRange)selection {
    NSArray<NSAttributedString *> *inverseSnapshot =
        self.host.attributedBlocks;
    NSRange inverseSelection = [self selectedCanonicalRange];
    self.performingFormattingCommand = YES;
    IDBlockDocumentChange *change = nil;
    @try {
        change = [self.textStorage id_restoreAttributedBlocks:snapshot];
        if (change != nil) {
            UITextPosition *start =
                [self.host
                    positionFromPosition:self.host.beginningOfDocument
                                 offset:(NSInteger)selection.location];
            UITextPosition *end =
                [self.host positionFromPosition:start
                                         offset:(NSInteger)selection.length];
            if (start != nil && end != nil) {
                self.host.selectedTextRange =
                    [self.host textRangeFromPosition:start
                                          toPosition:end];
            }
        }
    } @finally {
        self.performingFormattingCommand = NO;
    }
    if (change == nil) {
        return;
    }
    [self registerUndoSnapshot:inverseSnapshot
                     selection:inverseSelection];
    [self notifyStateChanged];
}

- (void)notifyStateChanged {
    void (^handler)(void) =
        self.host.inlineTextTraitStateDidChangeHandler;
    if (handler != nil) {
        handler();
    }
}

- (void)documentDidChange:(IDBlockDocumentChange *)change {
    if (!self.performingFormattingCommand) {
        [self notifyStateChanged];
    }
}

- (void)selectionDidChange {
    if (!self.performingFormattingCommand) {
        [self notifyStateChanged];
    }
}

@end

#endif
