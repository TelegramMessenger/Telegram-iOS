#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDUIKitInputControllerCapability.h"

#import <objc/message.h>

NSErrorDomain const IDUIKitInputControllerCapabilityErrorDomain =
    @"IDUIKitInputControllerCapabilityErrorDomain";

typedef NS_ENUM(NSInteger, IDUIKitInputControllerCapabilityError) {
    IDUIKitInputControllerCapabilityErrorRejectedContract = 1,
    IDUIKitInputControllerCapabilityErrorMissingControllerClass,
    IDUIKitInputControllerCapabilityErrorInitializationFailed,
    IDUIKitInputControllerCapabilityErrorInvalidAdoptedController,
};

typedef id (*IDUIKitInputControllerInitializerSend)(
    id __attribute__((ns_consumed)),
    SEL,
    id) __attribute__((ns_returns_retained));

@interface IDUIKitInputControllerCapability ()
@property(nonatomic, strong, readwrite) id privateController;
@property(nonatomic, strong, readwrite)
    IDUIKitCapabilityReport *report;
@property(nonatomic, getter=isDetached) BOOL detached;
@property(nonatomic) IDUIKitBehaviorCapabilities validatedOptionalCapabilities;
@end

static NSError *IDUIKitInputControllerError(
    IDUIKitInputControllerCapabilityError code,
    NSString *description) {
    return [NSError
        errorWithDomain:IDUIKitInputControllerCapabilityErrorDomain
                   code:code
               userInfo:@{
                   NSLocalizedDescriptionKey: description,
               }];
}

static NSArray<NSString *> *IDUIKitRequiredMemberIdentifiers(
    IDUIKitRuntimeCapabilityContract *contract) {
    NSMutableArray<NSString *> *identifiers =
        [NSMutableArray array];
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if (member.isRequired) {
            [identifiers addObject:member.identifier];
        }
    }
    return [identifiers
        sortedArrayUsingSelector:@selector(compare:)];
}

static IDUIKitCapabilityReport *IDUIKitInputReport(
    IDUIKitRuntimeCapabilityContract *contract,
    IDUIKitContractResult *result) {
    NSString *reason = result.mismatches.count == 0
        ? nil
        : [result.mismatches componentsJoinedByString:@"\n"];
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:contract.identifier
                     state:result.state
           requiredMembers:
               IDUIKitRequiredMemberIdentifiers(contract)
              observedABIs:result.observedABIs
              dependencies:contract.dependencies
                  fallback:contract.fallback
           rejectionReason:reason];
}

static IDUIKitRuntimeMemberContract *
IDUIKitInputMemberNamed(
    IDUIKitRuntimeCapabilityContract *contract,
    NSString *name) {
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if ([member.name isEqualToString:name]) {
            return member;
        }
    }
    return nil;
}

@implementation IDUIKitInputControllerCapability

- (instancetype)initWithContract:
    (IDUIKitRuntimeCapabilityContract *)contract
                         resolver:(IDUIKitCapabilityResolver *)resolver
                 layoutController:(id)layoutController
                         delegate:(id)delegate
                            error:(NSError **)error {
    NSParameterAssert(contract != nil);
    NSParameterAssert(resolver != nil);
    NSParameterAssert(layoutController != nil);
    IDUIKitContractResult *result =
        [resolver evaluateContract:contract];
    if (!result.isAccepted) {
        if (error != NULL) {
            *error = IDUIKitInputControllerError(
                IDUIKitInputControllerCapabilityErrorRejectedContract,
                [result.mismatches
                    componentsJoinedByString:@"\n"]);
        }
        return nil;
    }

    IDUIKitRuntimeMemberContract *initializer =
        IDUIKitInputMemberNamed(
            contract, @"initWithTextLayoutController:");
    Class controllerClass = initializer == nil
        ? Nil
        : [resolver classNamed:initializer.className];
    if (controllerClass == Nil) {
        if (error != NULL) {
            *error = IDUIKitInputControllerError(
                IDUIKitInputControllerCapabilityErrorMissingControllerClass,
                @"The validated input-controller class is unavailable.");
        }
        return nil;
    }

    SEL initializerSelector =
        NSSelectorFromString(@"initWithTextLayoutController:");
    id allocatedController = [controllerClass alloc];
    __strong id cleanupTarget = allocatedController;
    id controller = nil;
    @try {
        controller = ((IDUIKitInputControllerInitializerSend)objc_msgSend)(
            allocatedController,
            initializerSelector,
            layoutController);
        cleanupTarget = controller;
        if (controller == nil) {
            @throw [NSException
                exceptionWithName:NSInternalInconsistencyException
                           reason:@"The private input controller returned nil from initialization."
                         userInfo:nil];
        }
        ((void (*)(id, SEL, id))objc_msgSend)(
            controller,
            NSSelectorFromString(@"setDelegate:"),
            delegate);
    } @catch (NSException *exception) {
        @try {
            if (cleanupTarget != nil) {
                ((void (*)(id, SEL))objc_msgSend)(
                    cleanupTarget,
                    NSSelectorFromString(@"_detachFromLayoutManager"));
            }
        } @catch (__unused NSException *cleanupException) {
        }
        if (error != NULL) {
            *error = IDUIKitInputControllerError(
                IDUIKitInputControllerCapabilityErrorInitializationFailed,
                exception.reason ?:
                    @"The private input controller could not be initialized.");
        }
        return nil;
    }
    cleanupTarget = nil;

    self = [super init];
    if (self != nil) {
        _privateController = controller;
        _report = [IDUIKitInputReport(contract, result)
            reportByActivating];
        _validatedOptionalCapabilities = NSUIntegerMax;
    }
    return self;
}

- (instancetype)initAdoptingPrivateController:(id)controller
                                      contract:
    (IDUIKitRuntimeCapabilityContract *)contract
                                      resolver:
    (IDUIKitCapabilityResolver *)resolver
                                         error:(NSError **)error {
    NSParameterAssert(controller != nil);
    NSParameterAssert(contract != nil);
    NSParameterAssert(resolver != nil);
    IDUIKitContractResult *result =
        [resolver evaluateContract:contract];
    if (!result.isAccepted) {
        if (error != NULL) {
            *error = IDUIKitInputControllerError(
                IDUIKitInputControllerCapabilityErrorRejectedContract,
                [result.mismatches
                    componentsJoinedByString:@"\n"]);
        }
        return nil;
    }
    IDUIKitRuntimeMemberContract *initializer =
        IDUIKitInputMemberNamed(
            contract, @"initWithTextLayoutController:");
    Class expectedClass = initializer == nil
        ? Nil
        : [resolver classNamed:initializer.className];
    if (expectedClass == Nil ||
        ![controller isKindOfClass:expectedClass]) {
        if (error != NULL) {
            *error = IDUIKitInputControllerError(
                IDUIKitInputControllerCapabilityErrorInvalidAdoptedController,
                @"The adopted controller does not match the validated class.");
        }
        return nil;
    }
    self = [super init];
    if (self != nil) {
        _privateController = controller;
        _report = [IDUIKitInputReport(contract, result)
            reportByActivating];
        _validatedOptionalCapabilities = NSUIntegerMax;
    }
    return self;
}

- (void)setValidatedOptionalCapabilities:
    (IDUIKitBehaviorCapabilities)capabilities {
    _validatedOptionalCapabilities = capabilities;
}

- (BOOL)hasValidatedCapability:
    (IDUIKitBehaviorCapabilities)capability {
    return (self.validatedOptionalCapabilities & capability) != 0;
}

- (id<UITextInput, UIKeyInput>)activeController {
    if (!self.isDetached && self.privateController != nil) {
        return self.privateController;
    }
    @throw [NSException
        exceptionWithName:NSInternalInconsistencyException
                   reason:@"The UIKit input-controller capability is detached."
                 userInfo:nil];
}

- (NSString *)textInRange:(UITextRange *)range {
    return [[self activeController] textInRange:range];
}

- (void)replaceRange:(UITextRange *)range
             withText:(NSString *)text {
    [[self activeController] replaceRange:range withText:text];
}

- (UITextRange *)selectedTextRange {
    return [self activeController].selectedTextRange;
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange {
    [self activeController].selectedTextRange = selectedTextRange;
}

- (UITextRange *)markedTextRange {
    return [self activeController].markedTextRange;
}

- (NSDictionary<NSAttributedStringKey, id> *)markedTextStyle {
    return [self activeController].markedTextStyle;
}

- (void)setMarkedTextStyle:
    (NSDictionary<NSAttributedStringKey, id> *)markedTextStyle {
    [self activeController].markedTextStyle = markedTextStyle;
}

- (void)setMarkedText:(NSString *)markedText
        selectedRange:(NSRange)selectedRange {
    [[self activeController]
        setMarkedText:markedText
        selectedRange:selectedRange];
}

- (void)setAttributedMarkedText:(NSAttributedString *)markedText
                  selectedRange:(NSRange)selectedRange {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityPrediction]) {
        [self setMarkedText:markedText.string
              selectedRange:selectedRange];
        return;
    }
    id controller = [self activeController];
    ((void (*)(id, SEL, id, NSRange))objc_msgSend)(
        controller,
        @selector(setAttributedMarkedText:selectedRange:),
        markedText,
        selectedRange);
}

- (void)unmarkText {
    [[self activeController] unmarkText];
}

- (UITextPosition *)beginningOfDocument {
    return [self activeController].beginningOfDocument;
}

- (UITextPosition *)endOfDocument {
    return [self activeController].endOfDocument;
}

- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition
                            toPosition:(UITextPosition *)toPosition {
    return [[self activeController]
        textRangeFromPosition:fromPosition
        toPosition:toPosition];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position
                                  offset:(NSInteger)offset {
    return [[self activeController]
        positionFromPosition:position
        offset:offset];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position
                             inDirection:(UITextLayoutDirection)direction
                                  offset:(NSInteger)offset {
    return [[self activeController]
        positionFromPosition:position
        inDirection:direction
        offset:offset];
}

- (NSComparisonResult)comparePosition:(UITextPosition *)position
                           toPosition:(UITextPosition *)other {
    return [[self activeController]
        comparePosition:position
        toPosition:other];
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from
                     toPosition:(UITextPosition *)toPosition {
    return [[self activeController]
        offsetFromPosition:from
        toPosition:toPosition];
}

- (id<UITextInputDelegate>)inputDelegate {
    return [self activeController].inputDelegate;
}

- (void)setInputDelegate:(id<UITextInputDelegate>)inputDelegate {
    [self activeController].inputDelegate = inputDelegate;
}

- (id<UITextInputTokenizer>)tokenizer {
    return [self activeController].tokenizer;
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range
                    farthestInDirection:
    (UITextLayoutDirection)direction {
    return [[self activeController]
        positionWithinRange:range
        farthestInDirection:direction];
}

- (UITextRange *)characterRangeByExtendingPosition:
    (UITextPosition *)position
                                       inDirection:
    (UITextLayoutDirection)direction {
    return [[self activeController]
        characterRangeByExtendingPosition:position
        inDirection:direction];
}

- (NSWritingDirection)baseWritingDirectionForPosition:
    (UITextPosition *)position
                                           inDirection:
    (UITextStorageDirection)direction {
    return [[self activeController]
        baseWritingDirectionForPosition:position
        inDirection:direction];
}

- (void)setBaseWritingDirection:(NSWritingDirection)writingDirection
                       forRange:(UITextRange *)range {
    [[self activeController]
        setBaseWritingDirection:writingDirection
        forRange:range];
}

- (CGRect)firstRectForRange:(UITextRange *)range {
    return [[self activeController] firstRectForRange:range];
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    return [[self activeController]
        caretRectForPosition:position];
}

- (NSArray<UITextSelectionRect *> *)selectionRectsForRange:
    (UITextRange *)range {
    return [[self activeController]
        selectionRectsForRange:range];
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point {
    return [[self activeController]
        closestPositionToPoint:point];
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point
                               withinRange:(UITextRange *)range {
    return [[self activeController]
        closestPositionToPoint:point
        withinRange:range];
}

- (UITextRange *)characterRangeAtPoint:(CGPoint)point {
    return [[self activeController]
        characterRangeAtPoint:point];
}

- (NSDictionary<NSAttributedStringKey, id> *)
    textStylingAtPosition:(UITextPosition *)position
              inDirection:(UITextStorageDirection)direction {
    return [[self activeController]
        textStylingAtPosition:position
        inDirection:direction];
}

- (void)insertText:(NSString *)text {
    [[self activeController] insertText:text];
}

- (void)deleteBackward {
    [[self activeController] deleteBackward];
}

- (BOOL)hasText {
    return [self comparePosition:self.beginningOfDocument
                      toPosition:self.endOfDocument] != NSOrderedSame;
}

- (NSUndoManager *)undoManager {
    id controller = [self activeController];
    return ((id (*)(id, SEL))objc_msgSend)(
        controller, NSSelectorFromString(@"undoManager"));
}

- (UITextStorageDirection)selectionAffinity {
    id controller = [self activeController];
    return ((UITextStorageDirection (*)(id, SEL))objc_msgSend)(
        controller, NSSelectorFromString(@"selectionAffinity"));
}

- (void)setSelectionAffinity:(UITextStorageDirection)selectionAffinity {
    [self activeController].selectionAffinity = selectionAffinity;
}

- (NSDictionary<NSAttributedStringKey, id> *)typingAttributes {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityTypingAttributes]) {
        return @{};
    }
    id controller = [self activeController];
    return ((id (*)(id, SEL))objc_msgSend)(
        controller, NSSelectorFromString(@"typingAttributes"));
}

- (void)setTypingAttributes:
    (NSDictionary<NSAttributedStringKey, id> *)typingAttributes {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityTypingAttributes]) {
        return;
    }
    id controller = [self activeController];
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller,
        NSSelectorFromString(@"setTypingAttributes:"),
        typingAttributes);
}

- (id)textInputTraits {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityTypingAttributes]) {
        return nil;
    }
    id controller = [self activeController];
    return ((id (*)(id, SEL))objc_msgSend)(
        controller, NSSelectorFromString(@"_textInputTraits"));
}

- (void)setAllowedTypingAttributeNames:
    (NSSet<NSAttributedStringKey> *)attributeNames {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityTypingAttributes]) {
        return;
    }
    id controller = [self activeController];
    SEL getSelector =
        NSSelectorFromString(@"_allowedTypingAttributes");
    SEL setSelector =
        NSSelectorFromString(@"_setAllowedTypingAttributes:");
    NSSet *current =
        ((id (*)(id, SEL))objc_msgSend)(controller, getSelector);
    NSMutableSet *allowed =
        current.mutableCopy ?: [NSMutableSet set];
    [allowed unionSet:attributeNames];
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, setSelector, allowed.copy);
}

- (void)invalidateTypingAttributes {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityTypingAttributes]) {
        return;
    }
    id controller = [self activeController];
    ((void (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(@"_invalidateTypingAttributes"));
}

- (void)performWhileSuppressingDelegateNotifications:
    (void (NS_NOESCAPE ^)(void))body {
    id controller = [self activeController];
    ((void (*)(id, SEL, void (^)(void)))objc_msgSend)(
        controller,
        NSSelectorFromString(
            @"_performWhileSuppressingDelegateNotifications:"),
        body);
}

- (id)validatedBackwardDeleteRanges {
    id controller = [self activeController];
    id ranges = ((id (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(@"_rangesForBackwardsDelete"));
    SEL unionSelector = NSSelectorFromString(@"unionRange");
    if (![ranges respondsToSelector:unionSelector]) {
        @throw [NSException
            exceptionWithName:NSInternalInconsistencyException
                       reason:@"Backward-delete ranges do not implement unionRange."
                     userInfo:nil];
    }
    return ranges;
}

- (void)preflightBackwardDeleteRanges {
    (void)[self validatedBackwardDeleteRanges];
}

- (NSRange)backwardDeleteRange {
    return ((NSRange (*)(id, SEL))objc_msgSend)(
        [self validatedBackwardDeleteRanges],
        NSSelectorFromString(@"unionRange"));
}

- (BOOL)shouldHandlePasteAction:(SEL)action sender:(id)sender {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityPaste]) {
        return action == @selector(paste:) &&
            UIPasteboard.generalPasteboard.string.length > 0;
    }
    id controller = [self activeController];
    BOOL canHandle = ((BOOL (*)(id, SEL, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(@"_canHandleResponderAction:"),
        action);
    return canHandle &&
        ((BOOL (*)(id, SEL, SEL, id))objc_msgSend)(
            controller,
            NSSelectorFromString(
                @"_shouldHandleResponderAction:withSender:"),
            action,
            sender);
}

- (void)performCut:(id)sender {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityPaste]) {
        return;
    }
    id controller = [self activeController];
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, @selector(cut:), sender);
}

- (void)performCopy:(id)sender {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityPaste]) {
        return;
    }
    id controller = [self activeController];
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, @selector(copy:), sender);
}

- (void)performPaste:(id)sender {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityPaste]) {
        NSString *text = UIPasteboard.generalPasteboard.string;
        if (text.length > 0) {
            [[self activeController] insertText:text];
        }
        return;
    }
    id controller = [self activeController];
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, @selector(paste:), sender);
}

- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityChecking]) {
        return;
    }
    id controller = [self activeController];
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        controller,
        NSSelectorFromString(
            @"setContinuousSpellCheckingEnabled:"),
        enabled);
}

- (BOOL)isContinuousSpellCheckingEnabled {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityChecking]) {
        return NO;
    }
    id controller = [self activeController];
    return ((BOOL (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(
            @"continuousSpellCheckingEnabled"));
}

- (BOOL)insertDictationResultIfSupported:
    (NSArray<UIDictationPhrase *> *)dictationResult {
    if (![self hasValidatedCapability:
            IDUIKitBehaviorCapabilityDictation]) {
        return NO;
    }
    id controller = [self activeController];
    SEL selector =
        NSSelectorFromString(@"insertDictationResult:");
    if (![controller respondsToSelector:selector]) {
        return NO;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, selector, dictationResult);
    return YES;
}

- (void)detach {
    if (self.isDetached) {
        return;
    }
    id controller = self.privateController;
    self.detached = YES;
    self.privateController = nil;
    ((void (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(@"_detachFromLayoutManager"));
}

@end

#endif
