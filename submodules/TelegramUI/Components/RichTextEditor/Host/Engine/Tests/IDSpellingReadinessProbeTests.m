@import XCTest;

#import "IDSpellingReadinessProbe.h"
#import "IDTextCanvasTestSupport.h"

@interface IDSpellingReadinessProbeTests : XCTestCase
@property(nonatomic, strong) UIWindow *testWindow;
@property(nonatomic, weak) UIWindow *previousKeyWindow;
@end

@interface IDSpellingInputModeFakeDriver : NSObject
    <IDSpellingInputModeDriving>
@property(nonatomic) BOOL visibleFirstResponder;
@property(nonatomic, strong) id currentMode;
@property(nonatomic, strong) id englishMode;
@property(nonatomic, copy) NSString *primaryLanguage;
@property(nonatomic, strong) NSMutableArray<NSString *> *events;
@property(nonatomic) BOOL englishForceSucceeds;
@property(nonatomic) BOOL priorForceSucceeds;
@property(nonatomic) BOOL keyboardPipelineReady;
@property(nonatomic) NSUInteger readinessChecksBeforeReady;
@property(nonatomic) NSUInteger readinessCheckCount;
@property(nonatomic) BOOL inputFollowsEnglishForce;
@property(nonatomic) BOOL englishForceAdvancesGeneration;
@property(nonatomic) BOOL priorForceAdvancesGeneration;
@property(nonatomic) NSUInteger generation;
@property(nonatomic, strong) id inputMode;
@end

@implementation IDSpellingInputModeFakeDriver

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _events = [NSMutableArray array];
        _englishForceSucceeds = YES;
        _priorForceSucceeds = YES;
        _keyboardPipelineReady = YES;
        _inputFollowsEnglishForce = YES;
        _englishForceAdvancesGeneration = YES;
        _priorForceAdvancesGeneration = YES;
    }
    return self;
}

- (BOOL)isVisibleFirstResponder:(id)input {
    (void)input;
    return self.visibleFirstResponder;
}

- (id)currentInputModeForInput:(id)input {
    (void)input;
    return self.inputMode ?: self.currentMode;
}

- (BOOL)isKeyboardPipelineReadyForInput:(id)input {
    (void)input;
    self.readinessCheckCount += 1;
    return self.keyboardPipelineReady ||
        self.readinessCheckCount > self.readinessChecksBeforeReady;
}

- (id)currentControllerInputMode {
    [self.events addObject:@"current"];
    return self.currentMode;
}

- (id)englishUSInputMode {
    [self.events addObject:@"english"];
    return self.englishMode;
}

- (NSString *)identifierForMode:(id)mode {
    if (mode == nil) {
        return nil;
    }
    return mode == self.englishMode ? @"en_US@hw=Automatic" : @"prior";
}

- (NSUInteger)modeChangeGeneration {
    return self.generation;
}

- (BOOL)forceInputMode:(id)mode error:(NSError **)error {
    BOOL english = mode == self.englishMode;
    [self.events addObject:english ? @"force-english" : @"force-prior"];
    BOOL succeeds = english ? self.englishForceSucceeds : self.priorForceSucceeds;
    if (succeeds) {
        if (self.inputMode == nil) {
            self.inputMode = self.currentMode;
        }
        self.currentMode = mode;
        if (!english || self.inputFollowsEnglishForce) {
            self.inputMode = mode;
        }
        if ((english && self.englishForceAdvancesGeneration) ||
            (!english && self.priorForceAdvancesGeneration)) {
            self.generation += 1;
        }
    } else if (error != NULL) {
        *error = [NSError errorWithDomain:@"IDFakeInputModeDriver"
                                     code:1
                                 userInfo:nil];
    }
    return succeeds;
}

- (void)reloadInputViewsForInput:(id)input {
    (void)input;
    [self.events addObject:@"reload"];
}

- (NSString *)primaryLanguageForInput:(id)input {
    (void)input;
    [self.events addObject:@"language"];
    return self.primaryLanguage;
}

@end

@implementation IDSpellingReadinessProbeTests

- (void)installEditor:(UITextView *)editor {
    UIWindowScene *windowScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    XCTAssertNotNil(windowScene);
    self.previousKeyWindow = windowScene.keyWindow;
    self.testWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.testWindow.frame = CGRectMake(0, 0, 320, 240);
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.whiteColor;
    self.testWindow.rootViewController = controller;
    [self.testWindow makeKeyAndVisible];
    [controller.view addSubview:editor];
    [controller.view layoutIfNeeded];
    [editor layoutIfNeeded];
}

- (void)testInputModeLeaseRejectsInputThatIsNotAVisibleFirstResponder {
    NSObject *input = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = NO;
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(lease);
    XCTAssertEqualObjects(error.domain, IDSpellingInputModeLeaseErrorDomain);
    XCTAssertEqual(error.code, IDSpellingInputModeLeaseErrorInputNotReady);
    XCTAssertEqualObjects(driver.events, @[]);
}

- (void)testInputModeLeaseActivatesEnglishAndRestoresExactPriorMode {
    NSObject *input = [NSObject new];
    NSObject *priorMode = [NSObject new];
    NSObject *englishMode = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = priorMode;
    driver.englishMode = englishMode;
    driver.primaryLanguage = @"en-US";
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNotNil(lease);
    XCTAssertNil(error);
    XCTAssertTrue(lease.isActive);
    XCTAssertFalse(lease.isInvalidated);
    XCTAssertEqual(driver.currentMode, englishMode);
    XCTAssertEqualObjects(driver.events,
                          (@[@"current", @"english", @"force-english",
                             @"reload", @"current", @"language"]));

    XCTAssertTrue([lease invalidateWithError:&error]);
    XCTAssertNil(error);
    XCTAssertFalse(lease.isActive);
    XCTAssertTrue(lease.isInvalidated);
    XCTAssertEqual(driver.currentMode, priorMode);
    XCTAssertEqualObjects(driver.events,
                          (@[@"current", @"english", @"force-english",
                             @"reload", @"current", @"language",
                             @"current", @"force-prior", @"reload",
                             @"current"]));
}

- (void)testInputModeLeaseFailedForceRestoresBeforeReturningError {
    NSObject *input = [NSObject new];
    NSObject *priorMode = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = priorMode;
    driver.englishMode = [NSObject new];
    driver.englishForceSucceeds = NO;
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(lease);
    XCTAssertEqualObjects(error.domain, IDSpellingInputModeLeaseErrorDomain);
    XCTAssertEqual(error.code, IDSpellingInputModeLeaseErrorActivationFailed);
    XCTAssertEqual(driver.currentMode, priorMode);
    XCTAssertEqualObjects(driver.events,
                          (@[@"current", @"english", @"force-english",
                             @"current"]));
}

- (void)testInputModeLeaseAlreadyRestoredInvalidationDoesNotForceOrReload {
    NSObject *input = [NSObject new];
    NSObject *priorMode = [NSObject new];
    NSObject *englishMode = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = priorMode;
    driver.englishMode = englishMode;
    driver.primaryLanguage = @"en-US";
    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:NULL];
    XCTAssertNotNil(lease);

    driver.currentMode = priorMode;
    driver.inputMode = priorMode;
    NSUInteger eventCount = driver.events.count;

    XCTAssertTrue([lease invalidateWithError:NULL]);
    XCTAssertTrue(lease.isInvalidated);
    XCTAssertEqual(driver.events.count, eventCount + 1);
    XCTAssertEqualObjects(driver.events.lastObject, @"current");
    XCTAssertFalse([driver.events containsObject:@"force-prior"]);
}

- (void)testInputModeLeaseControllerOnlyAgreementStillForcesRestore {
    NSObject *input = [NSObject new];
    NSObject *priorMode = [NSObject new];
    NSObject *englishMode = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = priorMode;
    driver.englishMode = englishMode;
    driver.primaryLanguage = @"en-US";
    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:NULL];
    XCTAssertNotNil(lease);

    driver.currentMode = priorMode;
    driver.inputMode = englishMode;
    NSUInteger eventCount = driver.events.count;

    XCTAssertTrue([lease invalidateWithError:NULL]);
    NSArray *tail = [driver.events
        subarrayWithRange:NSMakeRange(eventCount,
                                      driver.events.count - eventCount)];
    XCTAssertEqualObjects(tail,
                          (@[@"current", @"force-prior", @"reload",
                             @"current"]));
}

- (void)testInputModeLeaseTimedOutActivationRestoresBeforeReturningError {
    NSObject *input = [NSObject new];
    NSObject *priorMode = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = priorMode;
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"zh-Hans";
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(lease);
    XCTAssertEqualObjects(error.domain, IDSpellingInputModeLeaseErrorDomain);
    XCTAssertEqual(error.code, IDSpellingInputModeLeaseErrorActivationTimedOut);
    XCTAssertEqual(driver.currentMode, priorMode);
    XCTAssertEqualObjects(driver.events,
                          (@[@"current", @"english", @"force-english",
                             @"reload", @"current", @"language",
                             @"current", @"force-prior", @"reload",
                             @"current"]));
}

- (void)testInputModeLeaseReportsRestorationFailureInsteadOfTimeout {
    NSObject *input = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = [NSObject new];
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"zh-Hans";
    driver.priorForceSucceeds = NO;
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(lease);
    XCTAssertEqualObjects(error.domain, IDSpellingInputModeLeaseErrorDomain);
    XCTAssertEqual(error.code, IDSpellingInputModeLeaseErrorRestorationFailed);
}

- (void)testInputModeLeaseWaitsForKeyboardPipelineBeforeCapturingMode {
    NSObject *input = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.keyboardPipelineReady = NO;
    driver.readinessChecksBeforeReady = 2;
    driver.currentMode = [NSObject new];
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"en-US";

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0.2
                                          error:NULL];

    XCTAssertNotNil(lease);
    XCTAssertGreaterThanOrEqual(driver.readinessCheckCount, 3U);
    XCTAssertEqualObjects(driver.events.firstObject, @"current");
    XCTAssertTrue([lease invalidateWithError:NULL]);
}

- (void)testInputModeLeaseReadinessTimeoutDoesNotCaptureOrForceMode {
    NSObject *input = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.keyboardPipelineReady = NO;
    driver.readinessChecksBeforeReady = NSUIntegerMax;
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(lease);
    XCTAssertEqual(error.code,
                   IDSpellingInputModeLeaseErrorKeyboardPipelineTimedOut);
    XCTAssertEqualObjects(driver.events, @[]);
}

- (void)testInputModeLeaseRequiresModeChangeNotificationForActivation {
    NSObject *input = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = [NSObject new];
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"en-US";
    driver.englishForceAdvancesGeneration = NO;
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(lease);
    XCTAssertEqual(error.code, IDSpellingInputModeLeaseErrorActivationTimedOut);
}

- (void)testInputModeLeaseRequiresControllerAndInputIdentifierAgreement {
    NSObject *input = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = [NSObject new];
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"en-US";
    driver.inputFollowsEnglishForce = NO;
    NSError *error = nil;

    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(lease);
    XCTAssertEqual(error.code, IDSpellingInputModeLeaseErrorActivationTimedOut);
}

- (void)testInputModeLeaseSecondInvalidationIsNoOp {
    NSObject *input = [NSObject new];
    NSObject *priorMode = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = priorMode;
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"en-US";
    NSError *error = nil;
    IDSpellingInputModeLease *lease =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];
    XCTAssertNotNil(lease);
    XCTAssertTrue([lease invalidateWithError:&error]);
    NSUInteger eventCount = driver.events.count;

    XCTAssertTrue([lease invalidateWithError:&error]);
    XCTAssertEqual(driver.events.count, eventCount);
    XCTAssertEqual(driver.currentMode, priorMode);
}

- (void)testInputModeLeaseRejectsSecondLiveLeaseForSameInput {
    NSObject *input = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = [NSObject new];
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"en-US";
    NSError *error = nil;
    IDSpellingInputModeLease *first =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];
    XCTAssertNotNil(first);
    NSUInteger eventCount = driver.events.count;

    IDSpellingInputModeLease *second =
        [IDSpellingInputModeLease leaseForInput:input
                                         driver:driver
                                        timeout:0
                                          error:&error];

    XCTAssertNil(second);
    XCTAssertEqual(error.code, IDSpellingInputModeLeaseErrorAlreadyLeased);
    XCTAssertEqual(driver.events.count, eventCount);
    XCTAssertTrue([first invalidateWithError:NULL]);
}

- (void)testInputModeLeaseDeallocationRestoresActiveLease {
    NSObject *input = [NSObject new];
    NSObject *priorMode = [NSObject new];
    IDSpellingInputModeFakeDriver *driver =
        [IDSpellingInputModeFakeDriver new];
    driver.visibleFirstResponder = YES;
    driver.currentMode = priorMode;
    driver.englishMode = [NSObject new];
    driver.primaryLanguage = @"en-US";
    __weak IDSpellingInputModeLease *weakLease = nil;

    @autoreleasepool {
        IDSpellingInputModeLease *lease =
            [IDSpellingInputModeLease leaseForInput:input
                                             driver:driver
                                            timeout:0
                                              error:NULL];
        XCTAssertNotNil(lease);
        weakLease = lease;
    }

    XCTAssertNil(weakLease);
    XCTAssertEqual(driver.currentMode, priorMode);
    XCTAssertEqualObjects(
        [driver.events subarrayWithRange:
            NSMakeRange(driver.events.count - 3, 3)],
        (@[@"force-prior", @"reload", @"current"]));
}

- (void)tearDown {
    [self.testWindow endEditing:YES];
    [self.testWindow resignKeyWindow];
    self.testWindow.hidden = YES;
    self.testWindow.rootViewController = nil;
    [self.previousKeyWindow makeKeyWindow];
    self.testWindow = nil;
    self.previousKeyWindow = nil;
    [super tearDown];
}

- (void)testClassificationRequiresCheckingThenAnnotationThenMarkerPixels {
    XCTAssertEqual(IDClassifySpellingReadinessForPrimaryLanguages(
                       @"zh-Hans", @"en-US", YES, YES, 4),
                   IDSpellingReadinessStatusInputModeMismatch);
    XCTAssertEqual(IDClassifySpellingReadinessForPrimaryLanguages(
                       @"en-US", @"zh-Hans", YES, YES, 4),
                   IDSpellingReadinessStatusInputModeMismatch);
    XCTAssertEqual(IDClassifySpellingReadinessForPrimaryLanguages(
                       @"en-US", @"en-US", NO, NO, 0),
                   IDSpellingReadinessStatusContinuousCheckingDisabled);
    XCTAssertEqual(IDClassifySpellingReadiness(NO, NO, 0),
                   IDSpellingReadinessStatusContinuousCheckingDisabled);
    XCTAssertEqual(IDClassifySpellingReadiness(YES, NO, 0),
                   IDSpellingReadinessStatusTemporaryAnnotationUnavailable);
    XCTAssertEqual(IDClassifySpellingReadiness(YES, YES, 0),
                   IDSpellingReadinessStatusMarkerRenderingUnavailable);
    XCTAssertEqual(IDClassifySpellingReadiness(YES, YES, 4),
                   IDSpellingReadinessStatusReady);
}

- (void)testObservationDictionaryUsesStableNumericSchema {
    IDSpellingReadinessObservation *observation =
        [[IDSpellingReadinessObservation alloc]
            initWithStatus:IDSpellingReadinessStatusReady
            continuousCheckingEnabled:YES
            temporaryAnnotationObserved:YES
            markerPixelCount:7
            elapsedSeconds:0.25
          currentPrimaryLanguage:@"en-US"
            inputPrimaryLanguage:@"en-US"
                           word:@"mispelled"
            wordRange:NSMakeRange(0, 9)
            firstRect:CGRectMake(1, 2, 30, 17)
            markerROI:CGRectMake(0, 14, 33, 6)];

    NSDictionary<NSString *, id> *dictionary =
        observation.dictionaryRepresentation;
    NSSet<NSString *> *expectedKeys = [NSSet setWithArray:@[
        @"schema", @"status", @"currentPrimaryLanguage",
        @"inputPrimaryLanguage", @"continuousCheckingEnabled",
        @"temporaryAnnotationObserved", @"markerPixelCount",
        @"elapsedSeconds", @"word", @"wordRange", @"firstRect",
        @"markerROI",
    ]];
    XCTAssertEqualObjects([NSSet setWithArray:dictionary.allKeys], expectedKeys);
    XCTAssertEqualObjects(dictionary[@"schema"], @2);
    XCTAssertEqualObjects(dictionary[@"status"], @"ready");
    XCTAssertEqualObjects(dictionary[@"currentPrimaryLanguage"], @"en-US");
    XCTAssertEqualObjects(dictionary[@"inputPrimaryLanguage"], @"en-US");
    XCTAssertEqualObjects(dictionary[@"wordRange"],
                          (@{@"location": @0, @"length": @9}));
    XCTAssertEqualObjects(dictionary[@"firstRect"],
                          (@{@"x": @1, @"y": @2, @"width": @30,
                             @"height": @17}));
    XCTAssertEqualObjects(dictionary[@"markerROI"],
                          (@{@"x": @0, @"y": @14, @"width": @33,
                             @"height": @6}));
    XCTAssertNoThrow([NSJSONSerialization dataWithJSONObject:dictionary
                                                      options:0
                                                        error:NULL]);
}

- (void)testProbeRejectsAnEditorWithoutAVisibleWindow {
    UITextView *editor = [[UITextView alloc] initWithFrame:CGRectZero
                                             textContainer:nil];
    XCTAssertNotNil(editor.textLayoutManager);
    XCTAssertThrowsSpecificNamed(IDObserveStockSpellingReadiness(editor, 0),
                                 NSException,
                                 NSInvalidArgumentException);
}

- (void)testStockReadinessMeasuresASecondDepartedWordAfterNaturalWarmup {
    UITextView *editor = [[UITextView alloc]
        initWithFrame:CGRectMake(10, 10, 300, 120)
        textContainer:nil];
    XCTAssertNotNil(editor.textLayoutManager);
    [self installEditor:editor];

    IDSpellingReadinessObservation *observation =
        IDObserveStockSpellingReadiness(editor, 0);

    XCTAssertEqualObjects(editor.text, @"mispelled wrng ");
    XCTAssertEqualObjects(observation.word, @"wrng");
    XCTAssertTrue(NSEqualRanges(observation.wordRange, NSMakeRange(10, 4)));
    UITextPosition *expectedStart =
        [editor positionFromPosition:editor.beginningOfDocument offset:10];
    UITextPosition *expectedEnd =
        [editor positionFromPosition:editor.beginningOfDocument offset:14];
    UITextRange *expectedRange =
        [editor textRangeFromPosition:expectedStart toPosition:expectedEnd];
    XCTAssertTrue(CGRectEqualToRect(observation.firstRect,
                                    [editor firstRectForRange:expectedRange]));
}

- (void)testEnglishUSCheckerRecognizesRegressionWord {
    XCTAssertTrue(IDAssertEnglishCheckerAvailable(self));
}

- (void)testStockTextViewSpellingEnvironmentIsReady {
    UITextView *editor = [[UITextView alloc]
        initWithFrame:CGRectMake(10, 10, 300, 120)
        textContainer:nil];
    XCTAssertNotNil(editor.textLayoutManager);
    [self installEditor:editor];

    IDSpellingReadinessObservation *observation =
        IDObserveStockSpellingReadiness(editor, 5.0);
    IDAttachSpellingObservation(self,
                                @"stock-spelling-readiness",
                                observation.dictionaryRepresentation,
                                IDRenderView(editor));

    XCTAssertEqual(observation.status,
                   IDSpellingReadinessStatusReady,
                   @"IDSpellingReadiness:stockUnavailable:%@ evidence=%@",
                   IDSpellingReadinessStatusString(observation.status),
                   observation.dictionaryRepresentation);
}

- (void)testLifecycleTraceUsesStableSchemaAndRestoresHooks {
    UITextView *editor = [[UITextView alloc]
        initWithFrame:CGRectMake(10, 10, 300, 120)
        textContainer:nil];
    XCTAssertNotNil(editor.textLayoutManager);
    [self installEditor:editor];

    IDSpellingLifecycleTrace *trace =
        IDObserveStockSpellingLifecycle(editor,
                                        IDSpellingLifecycleStimulusOneShot,
                                        0.1);
    NSDictionary<NSString *, id> *dictionary = trace.dictionaryRepresentation;
    NSSet<NSString *> *expectedKeys = [NSSet setWithArray:@[
        @"schema", @"stimulus", @"events", @"hooksInstalled",
        @"hooksRestored", @"annotationRanges", @"firstMissingTransition",
    ]];

    XCTAssertEqualObjects([NSSet setWithArray:dictionary.allKeys], expectedKeys);
    XCTAssertEqualObjects(dictionary[@"schema"], @1);
    XCTAssertEqualObjects(dictionary[@"stimulus"], @"oneShot");
    XCTAssertEqualObjects(dictionary[@"hooksInstalled"], @YES);
    XCTAssertEqualObjects(dictionary[@"hooksRestored"], @YES);
    XCTAssertTrue([dictionary[@"events"] isKindOfClass:NSArray.class]);
    XCTAssertTrue([dictionary[@"annotationRanges"] isKindOfClass:NSArray.class]);

    NSUInteger expectedSequence = 0;
    for (NSDictionary<NSString *, id> *event in dictionary[@"events"]) {
        XCTAssertEqualObjects(event[@"sequence"], @(expectedSequence));
        XCTAssertTrue([event[@"name"] isKindOfClass:NSString.class]);
        XCTAssertTrue([event[@"elapsedSeconds"] isKindOfClass:NSNumber.class]);
        expectedSequence += 1;
    }
}

- (void)testStockTextViewSpellingLifecycleTraceIdentifiesFirstMissingTransition {
    UITextView *oneShotEditor = [[UITextView alloc]
        initWithFrame:CGRectMake(10, 10, 300, 120)
        textContainer:nil];
    XCTAssertNotNil(oneShotEditor.textLayoutManager);
    [self installEditor:oneShotEditor];
    IDSpellingLifecycleTrace *oneShot =
        IDObserveStockSpellingLifecycle(oneShotEditor,
                                        IDSpellingLifecycleStimulusOneShot,
                                        0.5);

    [oneShotEditor removeFromSuperview];
    UITextView *stagedEditor = [[UITextView alloc]
        initWithFrame:CGRectMake(10, 10, 300, 120)
        textContainer:nil];
    XCTAssertNotNil(stagedEditor.textLayoutManager);
    [self.testWindow.rootViewController.view addSubview:stagedEditor];
    [stagedEditor layoutIfNeeded];
    IDSpellingLifecycleTrace *staged =
        IDObserveStockSpellingLifecycle(stagedEditor,
                                        IDSpellingLifecycleStimulusStaged,
                                        1.0);

    NSDictionary<NSString *, id> *oneShotDictionary =
        oneShot.dictionaryRepresentation;
    NSDictionary<NSString *, id> *stagedDictionary =
        staged.dictionaryRepresentation;
    IDAttachSpellingObservation(self,
                                @"stock-spelling-lifecycle-one-shot",
                                oneShotDictionary,
                                IDRenderView(oneShotEditor));
    IDAttachSpellingObservation(self,
                                @"stock-spelling-lifecycle-staged",
                                stagedDictionary,
                                IDRenderView(stagedEditor));

    NSSet<NSString *> *validTransitions = [NSSet setWithArray:@[
        @"hooksUnavailable", @"selectionDepartureUnavailable",
        @"selectionCheckUnavailable", @"wordCheckUnavailable",
        @"checkerUnavailable", @"keyboardLanguagesUnavailable",
        @"annotationUnavailable", @"complete",
    ]];
    XCTAssertTrue([validTransitions
        containsObject:oneShotDictionary[@"firstMissingTransition"]]);
    XCTAssertTrue([validTransitions
        containsObject:stagedDictionary[@"firstMissingTransition"]]);

    NSArray<NSDictionary<NSString *, id> *> *events = stagedDictionary[@"events"];
    NSUInteger didChangeSelectionCount = 0;
    NSUInteger selectionCheckCount = 0;
    NSUInteger wordCheckCount = 0;
    NSUInteger checkerReturnCount = 0;
    for (NSDictionary<NSString *, id> *event in events) {
        NSString *name = event[@"name"];
        didChangeSelectionCount +=
            [name isEqualToString:@"checking.didChangeSelection"];
        selectionCheckCount += [name isEqualToString:@"checking.checkSelection"];
        wordCheckCount += [name isEqualToString:@"checking.checkWord"];
        checkerReturnCount += [name isEqualToString:@"checking.textChecker"];
        if ([name isEqualToString:@"checker.keyboardLanguages"]) {
            XCTAssertTrue([event[@"languages"] isKindOfClass:NSArray.class]);
        }
    }
    XCTAssertGreaterThanOrEqual(didChangeSelectionCount, 2u);
    if (selectionCheckCount == 0) {
        XCTAssertEqualObjects(stagedDictionary[@"firstMissingTransition"],
                              @"selectionCheckUnavailable");
    }
    XCTAssertGreaterThanOrEqual(checkerReturnCount, wordCheckCount);
    XCTAssertEqualObjects(stagedDictionary[@"hooksRestored"], @YES);
}

@end
