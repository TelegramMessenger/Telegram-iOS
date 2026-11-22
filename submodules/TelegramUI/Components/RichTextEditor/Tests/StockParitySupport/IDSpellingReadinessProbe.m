// PORTED from /Users/isaac/Documents/InputDec/Tests/IDSpellingReadinessProbe.m
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369.
//
// Carried over VERBATIM with exactly four mechanical edits, all recorded in ../PROVENANCE.md:
//   1. `#import "IDTextCanvasTestSupport.h"` -> `#import "IDStockParityPixels.h"` (the ported half
//      of that support file; the dropped half is the canvas fixture).
//   2. file-static `IDTemporaryRenderingRanges` -> exported `IDStockTemporaryRenderingRanges`.
//   3. file-static `IDRunMainRunLoopForInterval` -> exported (same name).
//   4. one appended function, `IDObserveSpellingLifecycleWithStimulus`, clearly fenced at the end.
// No upstream body is otherwise altered. The classifier, the lease state machine, the swizzle
// install/restore, and the readiness observation are byte-identical to upstream apart from those
// renames.

#import "IDSpellingReadinessProbe.h"

#import "IDStockParityPixels.h"

#import <objc/runtime.h>

@import QuartzCore;
@import XCTest;

@interface UITextView (IDSpellingReadinessContinuousChecking)
- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled;
- (BOOL)isContinuousSpellCheckingEnabled;
@end

NSErrorDomain const IDSpellingInputModeLeaseErrorDomain =
    @"IDSpellingInputModeLeaseErrorDomain";

static void IDSetSpellingInputModeLeaseError(
    NSError **error,
    IDSpellingInputModeLeaseErrorCode code,
    NSString *description) {
    if (error == NULL) {
        return;
    }
    *error = [NSError errorWithDomain:IDSpellingInputModeLeaseErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey: description}];
}

static const void *IDSpellingInputModeLeaseAssociationKey =
    &IDSpellingInputModeLeaseAssociationKey;

@interface IDSpellingInputModeLease ()
@property(nonatomic, readwrite, getter=isActive) BOOL active;
@property(nonatomic, readwrite, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, strong) id input;
@property(nonatomic, strong) id<IDSpellingInputModeDriving> driver;
@property(nonatomic, strong) id priorMode;
@property(nonatomic, copy) NSString *priorIdentifier;
@property(nonatomic, strong) NSObject *ownershipToken;
@property(nonatomic) NSTimeInterval transitionTimeout;
- (instancetype)initWithInput:(id)input
                       driver:(id<IDSpellingInputModeDriving>)driver
                    priorMode:(id)priorMode
               ownershipToken:(NSObject *)ownershipToken;
- (BOOL)waitForIdentifier:(NSString *)identifier
          afterGeneration:(NSUInteger)generation
           requireEnglish:(BOOL)requireEnglish;
- (BOOL)driverAlreadyReportsPriorMode;
- (void)finishInvalidation;
@end


@implementation IDSpellingInputModeLease

- (instancetype)initWithInput:(id)input
                       driver:(id<IDSpellingInputModeDriving>)driver
                    priorMode:(id)priorMode
               ownershipToken:(NSObject *)ownershipToken {
    self = [super init];
    if (self != nil) {
        _input = input;
        _driver = driver;
        _priorMode = priorMode;
        _ownershipToken = ownershipToken;
    }
    return self;
}

- (BOOL)waitForIdentifier:(NSString *)identifier
          afterGeneration:(NSUInteger)generation
           requireEnglish:(BOOL)requireEnglish {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:
        MAX(self.transitionTimeout, 0)];
    do {
        id controllerMode = [self.driver currentControllerInputMode];
        id inputMode = [self.driver currentInputModeForInput:self.input];
        BOOL identifiersMatch =
            [[self.driver identifierForMode:controllerMode]
                isEqualToString:identifier] &&
            [[self.driver identifierForMode:inputMode]
                isEqualToString:identifier];
        BOOL languageMatches = !requireEnglish ||
            [[[self.driver primaryLanguageForInput:self.input]
                lowercaseString] isEqualToString:@"en-us"];
        if ([self.driver modeChangeGeneration] > generation &&
            identifiersMatch && languageMatches) {
            return YES;
        }
        if ([deadline timeIntervalSinceNow] <= 0) {
            break;
        }
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.01]];
    } while ([deadline timeIntervalSinceNow] > 0);
    return NO;
}

+ (instancetype)leaseForInput:(id)input
                        driver:(id<IDSpellingInputModeDriving>)driver
                       timeout:(NSTimeInterval)timeout
                         error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (input == nil || driver == nil ||
        ![driver isVisibleFirstResponder:input]) {
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorInputNotReady,
            @"Spelling input-mode lease requires a visible first responder");
        return nil;
    }

    NSObject *token = [NSObject new];
    @synchronized (input) {
        if (objc_getAssociatedObject(
                input, IDSpellingInputModeLeaseAssociationKey) != nil) {
            IDSetSpellingInputModeLeaseError(
                error,
                IDSpellingInputModeLeaseErrorAlreadyLeased,
                @"The spelling input already has an active input-mode lease");
            return nil;
        }
        objc_setAssociatedObject(input,
                                 IDSpellingInputModeLeaseAssociationKey,
                                 token,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    NSDate *readinessDeadline = [NSDate dateWithTimeIntervalSinceNow:
        MAX(timeout, 0)];
    do {
        if ([driver isKeyboardPipelineReadyForInput:input]) {
            break;
        }
        if ([readinessDeadline timeIntervalSinceNow] <= 0) {
            objc_setAssociatedObject(input,
                                     IDSpellingInputModeLeaseAssociationKey,
                                     nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            IDSetSpellingInputModeLeaseError(
                error,
                IDSpellingInputModeLeaseErrorKeyboardPipelineTimedOut,
                @"The keyboard pipeline did not become ready before the lease deadline");
            return nil;
        }
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.01]];
    } while (YES);

    id priorMode = [driver currentControllerInputMode];
    if (priorMode == nil) {
        objc_setAssociatedObject(input,
                                 IDSpellingInputModeLeaseAssociationKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorPriorModeUnavailable,
            @"The current input mode could not be captured");
        return nil;
    }
    NSString *priorIdentifier = [driver identifierForMode:priorMode];
    if (priorIdentifier.length == 0) {
        objc_setAssociatedObject(input,
                                 IDSpellingInputModeLeaseAssociationKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorPriorModeUnavailable,
            @"The current controller input mode has no identifier");
        return nil;
    }
    id englishMode = [driver englishUSInputMode];
    if (englishMode == nil) {
        objc_setAssociatedObject(input,
                                 IDSpellingInputModeLeaseAssociationKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorEnglishUSModeUnavailable,
            @"UIKit could not synthesize the en-US input mode");
        return nil;
    }
    NSString *englishIdentifier = [driver identifierForMode:englishMode];
    if (englishIdentifier.length == 0) {
        objc_setAssociatedObject(input,
                                 IDSpellingInputModeLeaseAssociationKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorEnglishUSModeUnavailable,
            @"The synthesized en-US input mode has no identifier");
        return nil;
    }

    IDSpellingInputModeLease *lease =
        [[self alloc] initWithInput:input
                            driver:driver
                         priorMode:priorMode
                    ownershipToken:token];
    lease.priorIdentifier = priorIdentifier;
    lease.transitionTimeout = timeout;
    lease.active = YES;
    NSUInteger generation = [driver modeChangeGeneration];
    NSError *driverError = nil;
    if (![driver forceInputMode:englishMode error:&driverError]) {
        NSError *restorationError = nil;
        if (![lease invalidateWithError:&restorationError]) {
            if (error != NULL) {
                *error = restorationError;
            }
            return nil;
        }
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorActivationFailed,
            driverError.localizedDescription ?: @"The en-US input mode could not be activated");
        return nil;
    }
    [driver reloadInputViewsForInput:input];
    if ([lease waitForIdentifier:englishIdentifier
                 afterGeneration:generation
                  requireEnglish:YES]) {
        return lease;
    }

    NSError *restorationError = nil;
    if (![lease invalidateWithError:&restorationError]) {
        if (error != NULL) {
            *error = restorationError;
        }
        return nil;
    }
    IDSetSpellingInputModeLeaseError(
        error,
        IDSpellingInputModeLeaseErrorActivationTimedOut,
        @"The input did not report en-US before the lease deadline");
    return nil;
}

- (BOOL)invalidateWithError:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (self.invalidated) {
        return YES;
    }
    if ([self driverAlreadyReportsPriorMode]) {
        [self finishInvalidation];
        return YES;
    }
    NSUInteger generation = [self.driver modeChangeGeneration];
    NSError *driverError = nil;
    if (![self.driver forceInputMode:self.priorMode error:&driverError]) {
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorRestorationFailed,
            driverError.localizedDescription ?: @"The prior input mode could not be restored");
        return NO;
    }
    [self.driver reloadInputViewsForInput:self.input];
    if (![self waitForIdentifier:self.priorIdentifier
                 afterGeneration:generation
                  requireEnglish:NO]) {
        IDSetSpellingInputModeLeaseError(
            error,
            IDSpellingInputModeLeaseErrorRestorationFailed,
            @"The prior input mode was not notification-confirmed before the deadline");
        return NO;
    }
    [self finishInvalidation];
    return YES;
}

- (BOOL)driverAlreadyReportsPriorMode {
    id controllerMode = [self.driver currentControllerInputMode];
    id inputMode = [self.driver currentInputModeForInput:self.input];
    NSString *controllerIdentifier =
        [self.driver identifierForMode:controllerMode];
    NSString *inputIdentifier = [self.driver identifierForMode:inputMode];
    return controllerIdentifier.length > 0 &&
        inputIdentifier.length > 0 &&
        [controllerIdentifier isEqualToString:self.priorIdentifier] &&
        [inputIdentifier isEqualToString:self.priorIdentifier];
}

- (void)finishInvalidation {
    @synchronized (self.input) {
        if (objc_getAssociatedObject(
                self.input, IDSpellingInputModeLeaseAssociationKey) ==
            self.ownershipToken) {
            objc_setAssociatedObject(self.input,
                                     IDSpellingInputModeLeaseAssociationKey,
                                     nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    self.active = NO;
    self.invalidated = YES;
}

- (void)dealloc {
    [self invalidateWithError:NULL];
    if (!self.invalidated && self.input != nil) {
        @synchronized (self.input) {
            if (objc_getAssociatedObject(
                    self.input, IDSpellingInputModeLeaseAssociationKey) ==
                self.ownershipToken) {
                objc_setAssociatedObject(self.input,
                                         IDSpellingInputModeLeaseAssociationKey,
                                         nil,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
}

@end

IDSpellingReadinessStatus
IDClassifySpellingReadiness(BOOL continuousCheckingEnabled,
                            BOOL temporaryAnnotationObserved,
                            NSUInteger markerPixelCount) {
    return IDClassifySpellingReadinessForPrimaryLanguages(
        @"en-US", @"en-US", continuousCheckingEnabled,
        temporaryAnnotationObserved, markerPixelCount);
}

IDSpellingReadinessStatus
IDClassifySpellingReadinessForPrimaryLanguages(
    NSString *currentPrimaryLanguage,
    NSString *inputPrimaryLanguage,
    BOOL continuousCheckingEnabled,
    BOOL temporaryAnnotationObserved,
    NSUInteger markerPixelCount) {
    if (![currentPrimaryLanguage isEqualToString:@"en-US"] ||
        ![inputPrimaryLanguage isEqualToString:@"en-US"]) {
        return IDSpellingReadinessStatusInputModeMismatch;
    }
    if (!continuousCheckingEnabled) {
        return IDSpellingReadinessStatusContinuousCheckingDisabled;
    }
    if (!temporaryAnnotationObserved) {
        return IDSpellingReadinessStatusTemporaryAnnotationUnavailable;
    }
    if (markerPixelCount == 0) {
        return IDSpellingReadinessStatusMarkerRenderingUnavailable;
    }
    return IDSpellingReadinessStatusReady;
}

NSString *IDSpellingReadinessStatusString(IDSpellingReadinessStatus status) {
    switch (status) {
        case IDSpellingReadinessStatusReady:
            return @"ready";
        case IDSpellingReadinessStatusInputModeMismatch:
            return @"inputModeMismatch";
        case IDSpellingReadinessStatusContinuousCheckingDisabled:
            return @"continuousCheckingDisabled";
        case IDSpellingReadinessStatusTemporaryAnnotationUnavailable:
            return @"temporaryAnnotationUnavailable";
        case IDSpellingReadinessStatusMarkerRenderingUnavailable:
            return @"markerRenderingUnavailable";
    }
}

static NSDictionary<NSString *, NSNumber *> *IDRangeDictionary(NSRange range) {
    return @{ @"location": @(range.location), @"length": @(range.length) };
}

static NSDictionary<NSString *, NSNumber *> *IDRectDictionary(CGRect rect) {
    return @{
        @"x": @(rect.origin.x),
        @"y": @(rect.origin.y),
        @"width": @(rect.size.width),
        @"height": @(rect.size.height),
    };
}

@implementation IDSpellingReadinessObservation

- (instancetype)initWithStatus:(IDSpellingReadinessStatus)status
      continuousCheckingEnabled:(BOOL)continuousCheckingEnabled
    temporaryAnnotationObserved:(BOOL)temporaryAnnotationObserved
               markerPixelCount:(NSUInteger)markerPixelCount
                 elapsedSeconds:(NSTimeInterval)elapsedSeconds
         currentPrimaryLanguage:(NSString *)currentPrimaryLanguage
           inputPrimaryLanguage:(NSString *)inputPrimaryLanguage
                           word:(NSString *)word
                      wordRange:(NSRange)wordRange
                      firstRect:(CGRect)firstRect
                      markerROI:(CGRect)markerROI {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _status = status;
    _continuousCheckingEnabled = continuousCheckingEnabled;
    _temporaryAnnotationObserved = temporaryAnnotationObserved;
    _markerPixelCount = markerPixelCount;
    _elapsedSeconds = elapsedSeconds;
    _currentPrimaryLanguage = [currentPrimaryLanguage copy];
    _inputPrimaryLanguage = [inputPrimaryLanguage copy];
    _word = [word copy];
    _wordRange = wordRange;
    _firstRect = firstRect;
    _markerROI = markerROI;
    return self;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        @"schema": @2,
        @"status": IDSpellingReadinessStatusString(self.status),
        @"currentPrimaryLanguage": self.currentPrimaryLanguage,
        @"inputPrimaryLanguage": self.inputPrimaryLanguage,
        @"continuousCheckingEnabled": @(self.continuousCheckingEnabled),
        @"temporaryAnnotationObserved": @(self.temporaryAnnotationObserved),
        @"markerPixelCount": @(self.markerPixelCount),
        @"elapsedSeconds": @(self.elapsedSeconds),
        @"word": self.word,
        @"wordRange": IDRangeDictionary(self.wordRange),
        @"firstRect": IDRectDictionary(self.firstRect),
        @"markerROI": IDRectDictionary(self.markerROI),
    };
}

@end

@interface IDSpellingLifecycleTrace ()
- (instancetype)initWithDictionaryRepresentation:
    (NSDictionary<NSString *, id> *)dictionaryRepresentation;
@end

@implementation IDSpellingLifecycleTrace

- (instancetype)initWithDictionaryRepresentation:
    (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    self = [super init];
    if (self != nil) {
        _dictionaryRepresentation = [dictionaryRepresentation copy];
    }
    return self;
}

@end

@interface IDSpellingLifecycleRecorder : NSObject
@property(nonatomic) CFTimeInterval startTime;
@property(nonatomic) NSUInteger nextSequence;
@property(nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *events;
- (void)recordName:(NSString *)name details:(NSDictionary<NSString *, id> *)details;
@end

@implementation IDSpellingLifecycleRecorder

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _startTime = CACurrentMediaTime();
        _events = [NSMutableArray array];
    }
    return self;
}

- (void)recordName:(NSString *)name details:(NSDictionary<NSString *, id> *)details {
    @synchronized (self) {
        NSMutableDictionary<NSString *, id> *event = [@{
            @"sequence": @(self.nextSequence),
            @"elapsedSeconds": @(CACurrentMediaTime() - self.startTime),
            @"name": name,
        } mutableCopy];
        [event addEntriesFromDictionary:details];
        [self.events addObject:event];
        self.nextSequence += 1;
    }
}

@end


typedef void (*IDVoidObjectMethodIMP)(id, SEL);
typedef void (*IDRangeMethodIMP)(id, SEL, NSRange);
typedef id _Nullable (*IDObjectMethodIMP)(id, SEL);
typedef void (*IDObjectArgumentMethodIMP)(id, SEL, id);

static IDSpellingLifecycleRecorder *IDActiveSpellingLifecycleRecorder;
static Method IDEndSelectionChangeMethod;
static Method IDDidChangeSelectionMethod;
static Method IDCheckSelectionMethod;
static Method IDTextCheckerMethod;
static Method IDCheckWordMethod;
static Method IDKeyboardLanguagesMethod;
static IMP IDOriginalEndSelectionChangeIMP;
static IMP IDOriginalDidChangeSelectionIMP;
static IMP IDOriginalCheckSelectionIMP;
static IMP IDOriginalTextCheckerIMP;
static IMP IDOriginalCheckWordIMP;
static IMP IDOriginalKeyboardLanguagesIMP;

static NSDictionary<NSString *, NSNumber *> *IDRangeEventDetails(NSRange range) {
    return @{ @"location": @(range.location), @"length": @(range.length) };
}

static void IDTraceEndSelectionChange(id self, SEL _cmd) {
    [IDActiveSpellingLifecycleRecorder recordName:@"input.endSelectionChange"
                                           details:@{}];
    ((IDVoidObjectMethodIMP)IDOriginalEndSelectionChangeIMP)(self, _cmd);
}

static void IDTraceDidChangeSelection(id self, SEL _cmd, id range) {
    [IDActiveSpellingLifecycleRecorder
        recordName:@"checking.didChangeSelection"
           details:@{ @"rangeClass": range == nil ? @"" : NSStringFromClass([range class]) }];
    ((IDObjectArgumentMethodIMP)IDOriginalDidChangeSelectionIMP)(self, _cmd, range);
}

static void IDTraceCheckSelection(id self, SEL _cmd, NSRange range) {
    [IDActiveSpellingLifecycleRecorder
        recordName:@"checking.checkSelection"
           details:@{ @"range": IDRangeEventDetails(range) }];
    ((IDRangeMethodIMP)IDOriginalCheckSelectionIMP)(self, _cmd, range);
}

static id IDTraceTextChecker(id self, SEL _cmd) {
    id checker = ((IDObjectMethodIMP)IDOriginalTextCheckerIMP)(self, _cmd);
    [IDActiveSpellingLifecycleRecorder
        recordName:@"checking.textChecker"
           details:@{
               @"available": @(checker != nil),
               @"class": checker == nil ? @"" : NSStringFromClass([checker class]),
           }];
    return checker;
}

static void IDTraceCheckWord(id self, SEL _cmd, id range) {
    [IDActiveSpellingLifecycleRecorder
        recordName:@"checking.checkWord"
           details:@{ @"rangeClass": range == nil ? @"" : NSStringFromClass([range class]) }];
    ((IDObjectArgumentMethodIMP)IDOriginalCheckWordIMP)(self, _cmd, range);
}

static id IDTraceKeyboardLanguages(id self, SEL _cmd) {
    id languages = ((IDObjectMethodIMP)IDOriginalKeyboardLanguagesIMP)(self, _cmd);
    NSArray *jsonLanguages = [languages isKindOfClass:NSArray.class]
        ? [languages copy]
        : @[];
    [IDActiveSpellingLifecycleRecorder
        recordName:@"checker.keyboardLanguages"
           details:@{ @"languages": jsonLanguages }];
    return languages;
}

static void IDClearSpellingLifecycleHookState(void) {
    IDEndSelectionChangeMethod = NULL;
    IDDidChangeSelectionMethod = NULL;
    IDCheckSelectionMethod = NULL;
    IDTextCheckerMethod = NULL;
    IDCheckWordMethod = NULL;
    IDKeyboardLanguagesMethod = NULL;
    IDOriginalEndSelectionChangeIMP = NULL;
    IDOriginalDidChangeSelectionIMP = NULL;
    IDOriginalCheckSelectionIMP = NULL;
    IDOriginalTextCheckerIMP = NULL;
    IDOriginalCheckWordIMP = NULL;
    IDOriginalKeyboardLanguagesIMP = NULL;
    IDActiveSpellingLifecycleRecorder = nil;
}

static BOOL IDRestoreSpellingLifecycleHooks(void) {
    BOOL restored = YES;
    struct {
        Method method;
        IMP wrapper;
        IMP original;
    } hooks[] = {
        { IDEndSelectionChangeMethod, (IMP)IDTraceEndSelectionChange,
          IDOriginalEndSelectionChangeIMP },
        { IDDidChangeSelectionMethod, (IMP)IDTraceDidChangeSelection,
          IDOriginalDidChangeSelectionIMP },
        { IDCheckSelectionMethod, (IMP)IDTraceCheckSelection,
          IDOriginalCheckSelectionIMP },
        { IDTextCheckerMethod, (IMP)IDTraceTextChecker,
          IDOriginalTextCheckerIMP },
        { IDCheckWordMethod, (IMP)IDTraceCheckWord,
          IDOriginalCheckWordIMP },
        { IDKeyboardLanguagesMethod, (IMP)IDTraceKeyboardLanguages,
          IDOriginalKeyboardLanguagesIMP },
    };
    for (NSUInteger index = 0; index < sizeof(hooks) / sizeof(hooks[0]); index++) {
        if (hooks[index].method == NULL || hooks[index].original == NULL) {
            continue;
        }
        if (method_getImplementation(hooks[index].method) != hooks[index].wrapper) {
            restored = NO;
            continue;
        }
        method_setImplementation(hooks[index].method, hooks[index].original);
        restored = restored &&
            method_getImplementation(hooks[index].method) == hooks[index].original;
    }
    IDClearSpellingLifecycleHookState();
    return restored;
}

static BOOL IDInstallSpellingLifecycleHooks(IDSpellingLifecycleRecorder *recorder) {
    @synchronized (IDSpellingLifecycleRecorder.class) {
        if (IDActiveSpellingLifecycleRecorder != nil) {
            return NO;
        }
        Class inputController = NSClassFromString(@"UITextInputController");
        Class checkingController = NSClassFromString(@"UITextCheckingController");
        IDEndSelectionChangeMethod =
            class_getInstanceMethod(inputController, NSSelectorFromString(@"endSelectionChange"));
        IDDidChangeSelectionMethod = class_getInstanceMethod(
            checkingController, NSSelectorFromString(@"didChangeSelectionFromRange:"));
        IDCheckSelectionMethod = class_getInstanceMethod(
            checkingController,
            NSSelectorFromString(@"checkSpellingForSelectionChangeFromRange:"));
        IDTextCheckerMethod = class_getInstanceMethod(
            checkingController, NSSelectorFromString(@"textChecker"));
        IDCheckWordMethod = class_getInstanceMethod(
            checkingController, NSSelectorFromString(@"checkSpellingForWordInRange:"));
        IDKeyboardLanguagesMethod = class_getClassMethod(
            UITextChecker.class, NSSelectorFromString(@"keyboardLanguages"));
        if (IDEndSelectionChangeMethod == NULL || IDDidChangeSelectionMethod == NULL ||
            IDCheckSelectionMethod == NULL || IDTextCheckerMethod == NULL || IDCheckWordMethod == NULL ||
            IDKeyboardLanguagesMethod == NULL) {
            IDClearSpellingLifecycleHookState();
            return NO;
        }

        IDOriginalEndSelectionChangeIMP =
            method_getImplementation(IDEndSelectionChangeMethod);
        IDOriginalDidChangeSelectionIMP =
            method_getImplementation(IDDidChangeSelectionMethod);
        IDOriginalCheckSelectionIMP = method_getImplementation(IDCheckSelectionMethod);
        IDOriginalTextCheckerIMP = method_getImplementation(IDTextCheckerMethod);
        IDOriginalCheckWordIMP = method_getImplementation(IDCheckWordMethod);
        IDOriginalKeyboardLanguagesIMP =
            method_getImplementation(IDKeyboardLanguagesMethod);
        IDActiveSpellingLifecycleRecorder = recorder;
        method_setImplementation(IDEndSelectionChangeMethod,
                                 (IMP)IDTraceEndSelectionChange);
        method_setImplementation(IDDidChangeSelectionMethod,
                                 (IMP)IDTraceDidChangeSelection);
        method_setImplementation(IDCheckSelectionMethod, (IMP)IDTraceCheckSelection);
        method_setImplementation(IDTextCheckerMethod, (IMP)IDTraceTextChecker);
        method_setImplementation(IDCheckWordMethod, (IMP)IDTraceCheckWord);
        method_setImplementation(IDKeyboardLanguagesMethod,
                                 (IMP)IDTraceKeyboardLanguages);
        return YES;
    }
}

static BOOL IDRenderingAttributesDifferFromPersistentAttributes(
    UITextView *editor,
    NSRange wordRange) {
    NSTextLayoutManager *layoutManager = editor.textLayoutManager;
    NSTextContentManager *contentManager = layoutManager.textContentManager;
    if (layoutManager == nil || contentManager == nil) {
        return NO;
    }
    id<NSTextLocation> documentStart = contentManager.documentRange.location;
    __block BOOL observed = NO;
    [layoutManager enumerateRenderingAttributesFromLocation:documentStart
                                                    reverse:NO
                                                 usingBlock:
        ^BOOL(NSTextLayoutManager *manager,
              NSDictionary<NSAttributedStringKey, id> *attributes,
              NSTextRange *textRange) {
            (void)manager;
            NSInteger start = [contentManager offsetFromLocation:documentStart
                                                       toLocation:textRange.location];
            NSInteger end = [contentManager offsetFromLocation:documentStart
                                                     toLocation:textRange.endLocation];
            if (start == NSNotFound || end == NSNotFound || end < start) {
                return YES;
            }
            NSRange renderingRange = NSMakeRange((NSUInteger)start,
                                                  (NSUInteger)(end - start));
            NSRange intersection = NSIntersectionRange(renderingRange, wordRange);
            if (intersection.length == 0 || attributes.count == 0) {
                return YES;
            }
            NSDictionary<NSAttributedStringKey, id> *persistent = @{};
            if (intersection.location < editor.attributedText.length) {
                persistent = [editor.attributedText
                    attributesAtIndex:intersection.location
                       effectiveRange:NULL];
            }
            for (NSAttributedStringKey key in attributes) {
                id renderingValue = attributes[key];
                id persistentValue = persistent[key];
                if (renderingValue == NSNull.null ||
                    ![renderingValue isEqual:persistentValue]) {
                    observed = YES;
                    return NO;
                }
            }
            return YES;
        }];
    return observed;
}

NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDStockTemporaryRenderingRanges(UITextView *editor) {
    NSTextLayoutManager *layoutManager = editor.textLayoutManager;
    NSTextContentManager *contentManager = layoutManager.textContentManager;
    if (layoutManager == nil || contentManager == nil) {
        return @[];
    }
    id<NSTextLocation> documentStart = contentManager.documentRange.location;
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *ranges =
        [NSMutableArray array];
    [layoutManager enumerateRenderingAttributesFromLocation:documentStart
                                                    reverse:NO
                                                 usingBlock:
        ^BOOL(NSTextLayoutManager *manager,
              NSDictionary<NSAttributedStringKey, id> *attributes,
              NSTextRange *textRange) {
            (void)manager;
            if (attributes.count == 0) {
                return YES;
            }
            NSInteger start = [contentManager offsetFromLocation:documentStart
                                                       toLocation:textRange.location];
            NSInteger end = [contentManager offsetFromLocation:documentStart
                                                     toLocation:textRange.endLocation];
            if (start == NSNotFound || end == NSNotFound || end < start) {
                return YES;
            }
            NSDictionary<NSAttributedStringKey, id> *persistent = @{};
            if ((NSUInteger)start < editor.attributedText.length) {
                persistent = [editor.attributedText attributesAtIndex:(NSUInteger)start
                                                        effectiveRange:NULL];
            }
            BOOL differs = NO;
            for (NSAttributedStringKey key in attributes) {
                id renderingValue = attributes[key];
                id persistentValue = persistent[key];
                if (renderingValue == NSNull.null ||
                    ![renderingValue isEqual:persistentValue]) {
                    differs = YES;
                    break;
                }
            }
            if (differs) {
                [ranges addObject:IDRangeDictionary(
                    NSMakeRange((NSUInteger)start, (NSUInteger)(end - start)))];
            }
            return YES;
        }];
    return ranges;
}

void IDRunMainRunLoopForInterval(NSTimeInterval interval) {
    if (interval <= 0) {
        return;
    }
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:interval];
    while ([deadline timeIntervalSinceNow] > 0) {
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:
                MIN(0.01, MAX(0.001, [deadline timeIntervalSinceNow]))]];
    }
}

static NSString *IDFirstMissingSpellingLifecycleTransition(
    BOOL hooksInstalled,
    NSArray<NSDictionary<NSString *, id> *> *events,
    NSArray<NSDictionary<NSString *, NSNumber *> *> *annotationRanges) {
    if (!hooksInstalled) {
        return @"hooksUnavailable";
    }
    NSUInteger didChangeSelectionCount = 0;
    NSUInteger selectionCheckCount = 0;
    NSUInteger wordCheckCount = 0;
    BOOL checkerAvailable = NO;
    BOOL keyboardLanguagesAvailable = NO;
    for (NSDictionary<NSString *, id> *event in events) {
        NSString *name = event[@"name"];
        didChangeSelectionCount +=
            [name isEqualToString:@"checking.didChangeSelection"];
        selectionCheckCount += [name isEqualToString:@"checking.checkSelection"];
        wordCheckCount += [name isEqualToString:@"checking.checkWord"];
        if ([name isEqualToString:@"checking.textChecker"] &&
            [event[@"available"] boolValue]) {
            checkerAvailable = YES;
        }
        if ([name isEqualToString:@"checker.keyboardLanguages"] &&
            [event[@"languages"] isKindOfClass:NSArray.class] &&
            [event[@"languages"] count] > 0) {
            keyboardLanguagesAvailable = YES;
        }
    }
    if (didChangeSelectionCount == 0) {
        return @"selectionDepartureUnavailable";
    }
    if (selectionCheckCount == 0) {
        return @"selectionCheckUnavailable";
    }
    if (wordCheckCount == 0) {
        return @"wordCheckUnavailable";
    }
    if (!checkerAvailable) {
        return @"checkerUnavailable";
    }
    if (!keyboardLanguagesAvailable) {
        return @"keyboardLanguagesUnavailable";
    }
    if (annotationRanges.count == 0) {
        return @"annotationUnavailable";
    }
    return @"complete";
}

IDSpellingLifecycleTrace *
IDObserveStockSpellingLifecycle(UITextView *editor,
                                IDSpellingLifecycleStimulus stimulus,
                                NSTimeInterval timeout) {
    if (!NSThread.isMainThread || editor.window == nil || editor.window.hidden ||
        editor.hidden || editor.textLayoutManager == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Spelling lifecycle trace requires a visible main-thread TextKit 2 editor"];
    }

    editor.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    editor.backgroundColor = UIColor.whiteColor;
    editor.font = [UIFont systemFontOfSize:17.0];
    editor.textColor = UIColor.blackColor;
    editor.autocorrectionType = UITextAutocorrectionTypeNo;
    editor.spellCheckingType = UITextSpellCheckingTypeYes;
    editor.smartQuotesType = UITextSmartQuotesTypeNo;
    editor.smartDashesType = UITextSmartDashesTypeNo;
    editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    editor.inlinePredictionType = UITextInlinePredictionTypeNo;
    editor.text = @"";
    [editor layoutIfNeeded];

    IDSpellingLifecycleRecorder *recorder = [IDSpellingLifecycleRecorder new];
    BOOL hooksInstalled = IDInstallSpellingLifecycleHooks(recorder);
    __block NSArray<NSDictionary<NSString *, NSNumber *> *> *annotationRanges = @[];
    __block BOOL hooksRestored = !hooksInstalled;
    @try {
        [recorder recordName:@"stimulus.begin"
                      details:@{ @"kind": stimulus == IDSpellingLifecycleStimulusStaged
                          ? @"staged" : @"oneShot" }];
        [editor becomeFirstResponder];
        [editor setContinuousSpellCheckingEnabled:YES];
        if (stimulus == IDSpellingLifecycleStimulusStaged) {
            [recorder recordName:@"stimulus.insert"
                          details:@{ @"text": @"mispelled" }];
            [editor insertText:@"mispelled"];
            [recorder recordName:@"stimulus.insert"
                          details:@{ @"text": @" " }];
            [editor insertText:@" "];
            NSTimeInterval firstInterval = MIN(MAX(timeout * 0.5, 0.05), 0.5);
            IDRunMainRunLoopForInterval(firstInterval);
            NSArray *firstRanges = IDStockTemporaryRenderingRanges(editor);
            [recorder recordName:@"annotation.sample"
                          details:@{ @"stage": @"firstDeparture",
                                     @"ranges": firstRanges }];
            [recorder recordName:@"stimulus.insert"
                          details:@{ @"text": @"wrng" }];
            [editor insertText:@"wrng"];
            [recorder recordName:@"stimulus.insert"
                          details:@{ @"text": @" " }];
            [editor insertText:@" "];
            IDRunMainRunLoopForInterval(MAX(0, timeout - firstInterval));
        } else {
            [recorder recordName:@"stimulus.insert"
                          details:@{ @"text": @"mispelled " }];
            [editor insertText:@"mispelled "];
            IDRunMainRunLoopForInterval(MAX(0, timeout));
        }
        [editor setNeedsLayout];
        [editor layoutIfNeeded];
        [editor.textLayoutManager ensureLayoutForBounds:editor.bounds];
        annotationRanges = IDStockTemporaryRenderingRanges(editor);
        [recorder recordName:@"annotation.sample"
                      details:@{ @"stage": @"final", @"ranges": annotationRanges }];
        [editor resignFirstResponder];
    } @finally {
        if (hooksInstalled) {
            hooksRestored = IDRestoreSpellingLifecycleHooks();
        }
    }

    NSString *stimulusName = stimulus == IDSpellingLifecycleStimulusStaged
        ? @"staged" : @"oneShot";
    NSArray<NSDictionary<NSString *, id> *> *events = [recorder.events copy];
    NSDictionary<NSString *, id> *dictionary = @{
        @"schema": @1,
        @"stimulus": stimulusName,
        @"events": events,
        @"hooksInstalled": @(hooksInstalled),
        @"hooksRestored": @(hooksRestored),
        @"annotationRanges": annotationRanges,
        @"firstMissingTransition":
            IDFirstMissingSpellingLifecycleTransition(
                hooksInstalled, events, annotationRanges),
    };
    return [[IDSpellingLifecycleTrace alloc]
        initWithDictionaryRepresentation:dictionary];
}

IDSpellingReadinessObservation *
IDObserveStockSpellingReadiness(UITextView *editor, NSTimeInterval timeout) {
    if (editor.window == nil || editor.window.hidden || editor.hidden) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Stock spelling probe requires a visible hosted editor"];
    }
    if (editor.textLayoutManager == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Stock spelling probe requires TextKit 2"];
    }

    static NSString * const warmupWord = @"mispelled";
    static NSString * const measuredWord = @"wrng";
    NSRange wordRange = NSMakeRange(warmupWord.length + 1,
                                    measuredWord.length);
    if (CGRectIsEmpty(editor.bounds)) {
        editor.frame = CGRectMake(0, 0, 300, 120);
    }
    editor.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    editor.backgroundColor = UIColor.whiteColor;
    editor.font = [UIFont systemFontOfSize:17.0];
    editor.textColor = UIColor.blackColor;
    editor.autocorrectionType = UITextAutocorrectionTypeNo;
    editor.spellCheckingType = UITextSpellCheckingTypeYes;
    editor.smartQuotesType = UITextSmartQuotesTypeNo;
    editor.smartDashesType = UITextSmartDashesTypeNo;
    editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    editor.inlinePredictionType = UITextInlinePredictionTypeNo;
    editor.text = @"";
    [editor layoutIfNeeded];
    [editor becomeFirstResponder];
    [editor setContinuousSpellCheckingEnabled:YES];

    CFTimeInterval startTime = CACurrentMediaTime();
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MAX(timeout, 0)];
    NSString *currentPrimaryLanguage = @"";
    NSString *inputPrimaryLanguage = @"";
    do {
        currentPrimaryLanguage =
            UITextInputMode.currentInputMode.primaryLanguage ?: @"";
        inputPrimaryLanguage = editor.textInputMode.primaryLanguage ?: @"";
        if ([currentPrimaryLanguage isEqualToString:@"en-US"] &&
            [inputPrimaryLanguage isEqualToString:@"en-US"]) {
            break;
        }
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.01]];
    } while ([deadline timeIntervalSinceNow] > 0);

    [editor insertText:[warmupWord stringByAppendingString:@" "]];
    NSTimeInterval remaining = MAX(0, deadline.timeIntervalSinceNow);
    IDRunMainRunLoopForInterval(MIN(0.5, remaining * 0.5));
    [editor insertText:[measuredWord stringByAppendingString:@" "]];
    BOOL annotationObserved = NO;
    NSUInteger markerPixels = 0;
    NSUInteger previousMarkerPixels = NSUIntegerMax;
    NSUInteger stableSamples = 0;
    CGRect firstRect = CGRectZero;
    CGRect markerROI = CGRectZero;
    do {
        [editor setNeedsLayout];
        [editor layoutIfNeeded];
        [editor.textLayoutManager ensureLayoutForBounds:editor.bounds];
        UITextPosition *start =
            [editor positionFromPosition:editor.beginningOfDocument
                                  offset:(NSInteger)wordRange.location];
        UITextPosition *end =
            [editor positionFromPosition:editor.beginningOfDocument
                                  offset:(NSInteger)NSMaxRange(wordRange)];
        UITextRange *range =
            start == nil || end == nil
                ? nil
                : [editor textRangeFromPosition:start toPosition:end];
        firstRect = range == nil ? CGRectZero : [editor firstRectForRange:range];
        markerROI = CGRectIntersection(CGRectInset(firstRect, -3, -5),
                                       editor.bounds);
        annotationObserved = annotationObserved ||
            IDRenderingAttributesDifferFromPersistentAttributes(editor, wordRange);
        markerPixels = IDCountRedPixels(IDRenderView(editor), markerROI);
        if (markerPixels > 0 && markerPixels == previousMarkerPixels) {
            stableSamples += 1;
        } else {
            stableSamples = markerPixels > 0 ? 1 : 0;
        }
        previousMarkerPixels = markerPixels;
        if (annotationObserved && stableSamples >= 2) {
            break;
        }
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.01]];
    } while ([deadline timeIntervalSinceNow] > 0);

    BOOL continuousCheckingEnabled =
        editor.spellCheckingType == UITextSpellCheckingTypeYes;
    if ([editor respondsToSelector:@selector(isContinuousSpellCheckingEnabled)]) {
        continuousCheckingEnabled = editor.isContinuousSpellCheckingEnabled;
    }
    IDSpellingReadinessStatus status =
        IDClassifySpellingReadinessForPrimaryLanguages(
            currentPrimaryLanguage,
            inputPrimaryLanguage,
            continuousCheckingEnabled,
            annotationObserved,
            stableSamples >= 2 ? markerPixels : 0);
    NSTimeInterval elapsed = CACurrentMediaTime() - startTime;
    [editor resignFirstResponder];
    return [[IDSpellingReadinessObservation alloc]
        initWithStatus:status
        continuousCheckingEnabled:continuousCheckingEnabled
        temporaryAnnotationObserved:annotationObserved
        markerPixelCount:stableSamples >= 2 ? markerPixels : 0
        elapsedSeconds:elapsed
        currentPrimaryLanguage:currentPrimaryLanguage
        inputPrimaryLanguage:inputPrimaryLanguage
        word:measuredWord
        wordRange:wordRange
        firstRect:firstRect
        markerROI:markerROI];
}

BOOL IDAssertEnglishCheckerAvailable(XCTestCase *testCase) {
    BOOL hasEnglish = NO;
    for (NSString *language in UITextChecker.availableLanguages) {
        if ([language.lowercaseString hasPrefix:@"en"]) {
            hasEnglish = YES;
            break;
        }
    }
    if (!hasEnglish) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:
                @"The iOS 26.5 runtime reports no installed English checker language"]];
        return NO;
    }
    NSRange misspelling = [[UITextChecker new]
        rangeOfMisspelledWordInString:@"mispelled"
                               range:NSMakeRange(0, 9)
                          startingAt:0
                                wrap:NO
                            language:@"en_US"];
    if (!NSEqualRanges(misspelling, NSMakeRange(0, 9))) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:
                @"The installed en_US checker did not identify {0, 9} in mispelled"]];
        return NO;
    }
    return YES;
}

void IDAttachSpellingObservation(XCTestCase *testCase,
                                 NSString *role,
                                 NSDictionary<NSString *, id> *observation,
                                 UIImage *image) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:observation
                                                   options:NSJSONWritingPrettyPrinted |
                                                           NSJSONWritingSortedKeys
                                                     error:NULL];
    XCTAttachment *json = [XCTAttachment attachmentWithData:data
                                     uniformTypeIdentifier:@"public.json"];
    json.name = [role stringByAppendingString:@".json"];
    json.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:json];
    if (image != nil) {
        XCTAttachment *rendering = [XCTAttachment attachmentWithImage:image];
        rendering.name = [role stringByAppendingString:@".png"];
        rendering.lifetime = XCTAttachmentLifetimeKeepAlways;
        [testCase addAttachment:rendering];
    }
}

#pragma mark - TELEGRAM ADDITION (not upstream)

IDSpellingLifecycleTrace *
IDObserveSpellingLifecycleWithStimulus(
    NSString *stimulusName,
    NSTimeInterval timeout,
    void (^stimulus)(void),
    NSArray<NSDictionary<NSString *, NSNumber *> *> *_Nullable (^_Nullable annotationSampler)(void)) {
    if (!NSThread.isMainThread) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Spelling lifecycle trace must run on the main thread"];
    }

    IDSpellingLifecycleRecorder *recorder = [IDSpellingLifecycleRecorder new];
    BOOL hooksInstalled = IDInstallSpellingLifecycleHooks(recorder);
    __block NSArray<NSDictionary<NSString *, NSNumber *> *> *annotationRanges = @[];
    __block BOOL hooksRestored = !hooksInstalled;
    @try {
        [recorder recordName:@"stimulus.begin" details:@{ @"kind": stimulusName }];
        if (stimulus != nil) {
            stimulus();
        }
        IDRunMainRunLoopForInterval(MAX(0, timeout));
        if (annotationSampler != nil) {
            annotationRanges = annotationSampler() ?: @[];
        }
        [recorder recordName:@"annotation.sample"
                     details:@{ @"stage": @"final", @"ranges": annotationRanges }];
    } @finally {
        if (hooksInstalled) {
            hooksRestored = IDRestoreSpellingLifecycleHooks();
        }
    }

    NSArray<NSDictionary<NSString *, id> *> *events = [recorder.events copy];
    NSDictionary<NSString *, id> *dictionary = @{
        @"schema": @1,
        @"stimulus": stimulusName,
        @"events": events,
        @"hooksInstalled": @(hooksInstalled),
        @"hooksRestored": @(hooksRestored),
        @"annotationRanges": annotationRanges,
        @"firstMissingTransition":
            IDFirstMissingSpellingLifecycleTransition(
                hooksInstalled, events, annotationRanges),
    };
    return [[IDSpellingLifecycleTrace alloc]
        initWithDictionaryRepresentation:dictionary];
}
