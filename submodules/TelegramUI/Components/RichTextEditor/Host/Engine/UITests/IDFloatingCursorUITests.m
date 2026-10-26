#import "IDFloatingCursorTestSupport.h"
#import "IDHIDEventTestSupport.h"

#import <QuartzCore/QuartzCore.h>

static CGPoint IDFloatingCursorCenter(CGRect rect) {
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

@interface IDFloatingCursorObservation : NSObject
@property(nonatomic) IDFloatingCursorStatus held;
@property(nonatomic) IDFloatingCursorStatus moved;
@property(nonatomic, strong) XCUIScreenshot *heldScreenshot;
@property(nonatomic, strong) XCUIScreenshot *movedScreenshot;
@property(nonatomic, copy) NSString *heldCanonical;
@property(nonatomic, copy) NSString *movedCanonical;
@property(nonatomic) CFTimeInterval heldCaptureTime;
@property(nonatomic) CFTimeInterval movedCaptureTime;
@property(nonatomic) BOOL heldParsed;
@property(nonatomic) BOOL movedParsed;
@end
@implementation IDFloatingCursorObservation @end

@interface IDFloatingCursorRun : NSObject
@property(nonatomic) IDFloatingCursorStatus initial;
@property(nonatomic) IDFloatingCursorStatus ended;
@property(nonatomic) CGRect editorFrame;
@property(nonatomic, copy) NSString *initialCanonical;
@property(nonatomic, copy) NSString *endedCanonical;
@end
@implementation IDFloatingCursorRun @end

@interface IDFloatingCursorLifecycleRun : NSObject
@property(nonatomic) IDFloatingCursorStatus initial;
@property(nonatomic) IDFloatingCursorStatus held;
@property(nonatomic) IDFloatingCursorStatus ended;
@property(nonatomic) IDFloatingCursorStatus immediate;
@property(nonatomic) IDFloatingCursorStatus settled;
@property(nonatomic) IDFloatingCursorStatus quiesced;
@property(nonatomic, copy) NSDictionary<NSString *, id> *initialTrace;
@property(nonatomic, copy) NSDictionary<NSString *, id> *heldTrace;
@property(nonatomic, copy) NSDictionary<NSString *, id> *endedTrace;
@property(nonatomic, copy) NSDictionary<NSString *, id> *immediateTrace;
@property(nonatomic, copy) NSDictionary<NSString *, id> *settledTrace;
@property(nonatomic, copy) NSDictionary<NSString *, id> *quiescedTrace;
@property(nonatomic, copy) NSDictionary<NSString *, id> *heldSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *terminalSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *immediateSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *exactSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *postLiftSnapshot;
@property(nonatomic) CFTimeInterval epoch;
@property(nonatomic) NSTimeInterval keyboardLiftOffset;
@property(nonatomic) CFTimeInterval heldTime;
@property(nonatomic) CFTimeInterval immediateTime;
@property(nonatomic) CFTimeInterval settledTime;
@property(nonatomic) NSUInteger heldKeyboardCount;
@property(nonatomic) NSUInteger endedKeyboardCount;
@property(nonatomic) NSUInteger initialKeyboardCount;
@property(nonatomic) NSUInteger immediateKeyboardCount;
@property(nonatomic) NSUInteger settledKeyboardCount;
@property(nonatomic) NSUInteger quiescedKeyboardCount;
@end
@implementation IDFloatingCursorLifecycleRun @end

@interface IDFloatingCursorScrollTrace : NSObject
@property(nonatomic) IDFloatingCursorStatus initial;
@property(nonatomic) IDFloatingCursorStatus ended;
@property(nonatomic) IDFloatingCursorStatus quiesced;
@property(nonatomic, copy) NSString *canonical;
@property(nonatomic, strong) IDFloatingCursorHoldObservation *observation;
@property(nonatomic) CGPoint primaryStart;
@property(nonatomic) CGPoint primaryDestination;
@property(nonatomic) CGPoint terminalDestination;
@property(nonatomic) CGPoint secondaryStart;
@property(nonatomic) BOOL usesSelectionExtension;
@end
@implementation IDFloatingCursorScrollTrace @end

typedef NS_ENUM(NSUInteger, IDFloatingCursorEndpointRole) {
    IDFloatingCursorEndpointRoleUnknown,
    IDFloatingCursorEndpointRoleStart,
    IDFloatingCursorEndpointRoleEnd,
};

@interface IDFloatingCursorSelectionSample : NSObject
@property(nonatomic) IDFloatingCursorStatus status;
@property(nonatomic) CFTimeInterval requestedOffset;
@property(nonatomic) CFTimeInterval captureOffset;
@property(nonatomic, copy) NSString *canonical;
@property(nonatomic, copy) NSDictionary<NSString *, id> *cursorCallback;
@property(nonatomic) BOOL parsed;
@property(nonatomic, strong) XCUIScreenshot *screenshot;
@end
@implementation IDFloatingCursorSelectionSample @end

@interface IDFloatingCursorSelectionTrace : NSObject
@property(nonatomic) IDFloatingCursorStatus initial;
@property(nonatomic) IDFloatingCursorStatus ended;
@property(nonatomic) IDFloatingCursorStatus quiesced;
@property(nonatomic, copy) NSString *canonical;
@property(nonatomic, copy) NSArray<IDFloatingCursorSelectionSample *> *samples;
@property(nonatomic) CGRect editorFrame;
@end
@implementation IDFloatingCursorSelectionTrace @end

@interface IDFloatingCursorHIDFakePath : NSObject
@property(nonatomic, strong) NSMutableArray<NSString *> *operations;
- (instancetype)initForTouchAtPoint:(CGPoint)point offset:(NSTimeInterval)offset;
- (void)moveToPoint:(CGPoint)point atOffset:(NSTimeInterval)offset;
- (void)liftUpAtOffset:(NSTimeInterval)offset;
@end

@implementation IDFloatingCursorHIDFakePath
- (instancetype)initForTouchAtPoint:(CGPoint)point offset:(NSTimeInterval)offset {
    self = [super init];
    if (self != nil) {
        _operations = [NSMutableArray arrayWithObject:[NSString stringWithFormat:
            @"start %@ %.2f", NSStringFromCGPoint(point), offset]];
    }
    return self;
}
- (void)moveToPoint:(CGPoint)point atOffset:(NSTimeInterval)offset {
    [self.operations addObject:[NSString stringWithFormat:
        @"move %@ %.2f", NSStringFromCGPoint(point), offset]];
}
- (void)liftUpAtOffset:(NSTimeInterval)offset {
    [self.operations addObject:[NSString stringWithFormat:@"lift %.2f", offset]];
}
@end

@interface IDFloatingCursorHIDFakeRecord : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSMutableArray<IDFloatingCursorHIDFakePath *> *paths;
- (instancetype)initWithName:(NSString *)name;
- (void)addPointerEventPath:(IDFloatingCursorHIDFakePath *)path;
- (BOOL)synthesizeWithError:(NSError **)error;
@end

@implementation IDFloatingCursorHIDFakeRecord
- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _paths = [NSMutableArray array];
    }
    return self;
}
- (void)addPointerEventPath:(IDFloatingCursorHIDFakePath *)path {
    [self.paths addObject:path];
}
- (BOOL)synthesizeWithError:(NSError **)error {
    (void)error;
    return YES;
}
@end

@interface IDFloatingCursorUITests : XCTestCase
- (NSUInteger)firstNonemptySampleIndexInTrace:(IDFloatingCursorSelectionTrace *)trace;
@end

@implementation IDFloatingCursorUITests

- (NSDictionary<NSString *, id> *)dictionaryFromStatusElement:(XCUIElement *)element {
    NSString *description = [element.value description] ?: @"";
    NSData *data = [description dataUsingEncoding:NSUTF8StringEncoding];
    id value = data == nil ? nil : [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

- (XCUIApplication *)minimalApplicationFromCustom:
    (XCUIApplication *)application {
    [application terminate];
    application.launchArguments = [application.launchArguments
        arrayByAddingObjectsFromArray:@[
            @"-InputDecBehaviorBackend", @"minimal",
        ]];
    [application launch];
    XCUIElement *behavior =
        [application descendantsMatchingType:XCUIElementTypeAny][
            @"behavior-capability-status"];
    XCTAssertTrue([behavior waitForExistenceWithTimeout:4.0]);
    NSString *serialized =
        [behavior.value isKindOfClass:NSString.class]
            ? behavior.value : @"{}";
    NSDictionary *payload = [NSJSONSerialization
        JSONObjectWithData:
            [serialized dataUsingEncoding:NSUTF8StringEncoding]
                  options:0 error:nil];
    XCTAssertEqualObjects(payload[@"backend"], @"minimal");
    XCTAssertEqualObjects(payload[@"report"][@"detached"], @NO);
    NSPredicate *activeFloating = [NSPredicate predicateWithFormat:
        @"identifier == %@ AND state == %@",
        @"floatingCursor", @"active"];
    XCTAssertEqual(
        [payload[@"report"][@"capabilities"]
            filteredArrayUsingPredicate:activeFloating].count,
        1U);
    return application;
}

- (NSDictionary<NSString *, id> *)waitForAtomicTruthStatus:(XCUIElement *)element {
    CFTimeInterval deadline = IDFloatingCursorMonotonicTime() + 2.0;
    NSDictionary *value = @{};
    do {
        value = [self dictionaryFromStatusElement:element];
        if (IDFloatingCursorTruthSnapshotIsAtomic(value)) return value;
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    } while (IDFloatingCursorMonotonicTime() < deadline);
    XCTFail(@"atomic truth status unavailable: %@", value);
    return value;
}

- (IDFloatingCursorStatus)statusFromAtomicTruthSnapshot:(NSDictionary *)snapshot {
    IDFloatingCursorStatus status = {0};
    status.selection = NSMakeRange(
        [snapshot[@"selection"][@"location"] unsignedIntegerValue],
        [snapshot[@"selection"][@"length"] unsignedIntegerValue]);
    status.startAffinity = [snapshot[@"startAffinity"] integerValue];
    status.endAffinity = [snapshot[@"endAffinity"] integerValue];
    status.firstResponder = [snapshot[@"firstResponder"] boolValue];
    status.containerCreations = [snapshot[@"containerCreations"] unsignedIntegerValue];
    status.containerStable = [snapshot[@"containerStable"] boolValue];
    status.presentationUpdates = [snapshot[@"presentationUpdates"] unsignedIntegerValue];
    status.contentOffset = CGPointMake(
        [snapshot[@"contentOffset"][@"x"] doubleValue],
        [snapshot[@"contentOffset"][@"y"] doubleValue]);
    return status;
}

- (void)hydrateRun:(IDFloatingCursorLifecycleRun *)run
    fromStoredTruthInApplication:(XCUIApplication *)application
                   terminalEvent:(NSString *)terminalEvent {
    XCUIElementQuery *elements =
        [application descendantsMatchingType:XCUIElementTypeAny];
    NSDictionary *held = [self waitForAtomicTruthStatus:
        elements[@"floating-release-held-status"]];
    NSDictionary *terminal = [self waitForAtomicTruthStatus:
        elements[@"floating-terminal-status"]];
    NSDictionary *immediate = [self waitForAtomicTruthStatus:
        elements[@"floating-release-immediate-status"]];
    NSDictionary *exact = [self waitForAtomicTruthStatus:
        elements[@"floating-release-exact-status"]];
    NSDictionary *postLift = [self waitForAtomicTruthStatus:
        elements[@"floating-release-post-lift-status"]];
    XCTAssertTrue(IDFloatingCursorTruthPhasesHaveValidChronology(
        @[held, terminal, immediate, exact, postLift], NO));
    run.heldSnapshot = held;
    run.terminalSnapshot = terminal;
    run.immediateSnapshot = immediate;
    run.exactSnapshot = exact;
    run.postLiftSnapshot = postLift;
    run.held = [self statusFromAtomicTruthSnapshot:held];
    run.ended = [self statusFromAtomicTruthSnapshot:terminal];
    run.immediate = [self statusFromAtomicTruthSnapshot:immediate];
    run.settled = [self statusFromAtomicTruthSnapshot:exact];
    run.quiesced = [self statusFromAtomicTruthSnapshot:postLift];
    run.heldTrace = held[@"lifecycle"];
    run.endedTrace = terminal[@"lifecycle"];
    run.immediateTrace = immediate[@"lifecycle"];
    run.settledTrace = exact[@"lifecycle"];
    run.quiescedTrace = postLift[@"lifecycle"];
    run.heldKeyboardCount = [held[@"keyboardVisible"] boolValue] ? 1 : 0;
    run.endedKeyboardCount = [terminal[@"keyboardVisible"] boolValue] ? 1 : 0;
    run.immediateKeyboardCount = [immediate[@"keyboardVisible"] boolValue] ? 1 : 0;
    run.settledKeyboardCount = [exact[@"keyboardVisible"] boolValue] ? 1 : 0;
    run.quiescedKeyboardCount = [postLift[@"keyboardVisible"] boolValue] ? 1 : 0;
    XCTAssertTrue(run.held.firstResponder);
    XCTAssertGreaterThan(run.heldKeyboardCount, 0U);
    XCTAssertTrue([run.heldTrace[@"sessionActive"] boolValue]);
    XCTAssertEqualObjects(terminal[@"observation"][@"terminalEvent"], terminalEvent);
    XCTAssertGreaterThan([terminal[@"observation"][@"terminalCountAtRelease"]
        unsignedIntegerValue], 0U);
    XCTAssertEqualObjects(exact[@"observation"][@"phase"],
        [exact[@"observation"][@"actionEpoch"] doubleValue] > 0
            ? @"exact-action-500ms" : @"exact-terminal-500ms");
    XCTAssertEqualObjects(postLift[@"observation"][@"phase"],
                          @"post-keyboard-lift-500ms");
    XCTAttachment *chronology = [XCTAttachment attachmentWithString:
        [NSString stringWithFormat:@"held=%@ terminal=%@ immediate=%@ exact=%@ postLift=%@",
         held[@"observation"], terminal[@"observation"], immediate[@"observation"],
         exact[@"observation"], postLift[@"observation"]]];
    chronology.name = [terminalEvent stringByAppendingString:@"-stored-chronology"];
    chronology.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:chronology];
}

- (void)testScrollPhaseClassifierRequiresEndpointAndViewportDirection {
    IDFloatingCursorStatus initial = {0};
    initial.selection = NSMakeRange(900, 0);
    initial.contentOffset = CGPointMake(0, 715);
    IDFloatingCursorStatus wrongViewportDirection = initial;
    wrongViewportDirection.selection = NSMakeRange(734, 0);
    wrongViewportDirection.contentOffset.y = 782;
    IDFloatingCursorStatus sessionTransient = initial;
    sessionTransient.selection = NSMakeRange(1907, 0);
    sessionTransient.contentOffset.y = 774.667;
    IDFloatingCursorStatus firstMeasuredUpperProgress = initial;
    firstMeasuredUpperProgress.selection = NSMakeRange(587, 0);
    firstMeasuredUpperProgress.contentOffset.y = 661.667;
    NSArray<NSValue *> *samples = @[
        IDFloatingCursorStatusValue(wrongViewportDirection),
        IDFloatingCursorStatusValue(sessionTransient),
        IDFloatingCursorStatusValue(firstMeasuredUpperProgress),
    ];

    XCTAssertEqual(IDFloatingCursorFirstDirectionalProgressIndex(initial, samples, NO), 2U);
}

- (void)testHeldCaptureRejectsScreenshotCompletionAfterLift {
    IDFloatingCursorStatus held = {0};
    held.selection = NSMakeRange(734, 0);
    held.contentOffset = CGPointMake(0, 603.667);
    XCTAssertFalse(IDFloatingCursorHeldCaptureIsAtomic(
        held, held, IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress,
        IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress,
        7.251, 7.252, 7.250));
}

- (void)testHeldCaptureRejectsStateChangeDuringScreenshot {
    IDFloatingCursorStatus before = {0};
    before.selection = NSMakeRange(734, 0);
    before.startAffinity = UITextStorageDirectionForward;
    before.endAffinity = UITextStorageDirectionForward;
    before.contentOffset = CGPointMake(0, 603.667);
    IDFloatingCursorStatus after = before;
    after.endAffinity = UITextStorageDirectionBackward;
    after.contentOffset.y = 602.667;
    XCTAssertFalse(IDFloatingCursorHeldCaptureIsAtomic(
        before, after, IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress,
        IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress,
        7.190, 7.200, 7.250));
}

- (void)testHeldCaptureRejectsAfterReadCrossingLiftAfterScreenshotCompletedBeforeLift {
    IDFloatingCursorStatus held = {0};
    held.selection = NSMakeRange(734, 0);
    held.contentOffset = CGPointMake(0, 603.667);
    XCTAssertFalse(IDFloatingCursorHeldCaptureIsAtomic(
        held, held, IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress,
        IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress,
        7.240, 7.251, 7.250));
}

- (void)testHeldCaptureRetriesOnlyBeforeDeadlineAndUntilAtomicCaptureIsRetained {
    XCTAssertTrue(IDFloatingCursorHeldCaptureShouldRetry(NO, 7.200, 7.250));
    XCTAssertFalse(IDFloatingCursorHeldCaptureShouldRetry(YES, 7.200, 7.250));
    XCTAssertFalse(IDFloatingCursorHeldCaptureShouldRetry(NO, 7.250, 7.250));
}

- (NSString *)statusJSONWithCanonical:(NSString *)canonical {
    NSData *canonicalData = [NSJSONSerialization dataWithJSONObject:@[canonical]
                                                             options:0 error:nil];
    NSString *arrayJSON = [[NSString alloc] initWithData:canonicalData
                                                encoding:NSUTF8StringEncoding];
    NSString *quoted = [arrayJSON substringWithRange:NSMakeRange(1, arrayJSON.length - 2)];
    return [NSString stringWithFormat:
        @"{\"scenario\":\"floating-ltr\",\"canonical\":%@,"
         "\"selection\":{\"location\":46,\"length\":0},"
         "\"startAffinity\":0,\"endAffinity\":0,"
         "\"caret\":{\"x\":0,\"y\":0,\"width\":1,\"height\":1},"
         "\"visible\":{\"x\":0,\"y\":0,\"width\":1,\"height\":1},"
         "\"contentOffset\":{\"x\":0,\"y\":0},\"blockCount\":3,"
         "\"presentationUpdates\":0,\"containerCreations\":1,"
         "\"containerStable\":true,\"firstResponder\":true,"
         "\"cursorCallback\":null,\"autoscrollTrace\":{},"
         "\"interactionHostTopology\":{},"
         "\"lifecycle\":{"
         "\"normalEndCount\":0,\"windowDetachActionCount\":0,"
         "\"windowDetachCount\":0,\"resignActionCount\":0,"
         "\"keyboardDismissActionCount\":0,\"responderLossCount\":0,"
         "\"editableOffActionCount\":0,\"selectableOffActionCount\":0,"
         "\"editableOffCount\":0,\"selectableOffCount\":0,"
         "\"startCount\":0,\"cancelCount\":0,"
         "\"editable\":true,\"selectable\":true,"
         "\"presentationUpdates\":0,\"containerToken\":\"token\","
         "\"containerStable\":true,\"containerSubviews\":0,"
         "\"sessionObject\":false,\"assistantSessionObject\":false,"
         "\"displaySessionObject\":false,\"sessionOwnersMatch\":false,"
         "\"assistantSessionToken\":\"nil\",\"displaySessionToken\":\"nil\","
         "\"sessionActive\":false,"
         "\"autoscrollObject\":false,\"autoscrollActive\":false,"
         "\"recognizerCount\":0,\"recognizerBaselineCount\":0,"
         "\"recognizerUnexpectedNewCount\":0,\"recognizerSubsetOfBaseline\":true,"
         "\"recognizerBaselineIdentitySignature\":[],"
         "\"recognizerIdentitySignature\":[],"
         "\"recognizerSignature\":[],\"startAffinity\":0,\"endAffinity\":0}}", quoted];
}

- (void)testStatusParserAcceptsExactLifecycleSchema {
    IDFloatingCursorStatus parsed = {0};
    NSString *status = [self statusJSONWithCanonical:@"schema"];
    XCTAssertTrue(IDFloatingCursorParseStatus(status, &parsed));
    XCTAssertNotNil(IDFloatingCursorCopyLifecycle(status));
}

- (void)testStatusParserRequiresInteractionHostTopologyField {
    IDFloatingCursorStatus parsed = {0};
    NSString *status = [self statusJSONWithCanonical:@"interaction topology"];
    XCTAssertTrue(IDFloatingCursorParseStatus(status, &parsed));
    NSString *missing = [status stringByReplacingOccurrencesOfString:
        @"\"interactionHostTopology\":{}," withString:@""];
    XCTAssertFalse(IDFloatingCursorParseStatus(missing, &parsed));
}

- (void)testStatusParserRequiresRecognizerBaselineSubsetSchema {
    NSString *status = [self statusJSONWithCanonical:@"recognizers"];
    IDFloatingCursorStatus parsed = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(status, &parsed));
    NSString *old = [status stringByReplacingOccurrencesOfString:
        @"\"recognizerUnexpectedNewCount\":0,\"recognizerSubsetOfBaseline\":true,"
        withString:@"\"recognizerDuplicateCount\":0,"];
    XCTAssertNil(IDFloatingCursorCopyLifecycle(old));
}

- (void)testStatusParserRequiresExplicitSessionOwnershipSchema {
    NSString *status = [self statusJSONWithCanonical:@"session ownership"];
    IDFloatingCursorStatus parsed = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(status, &parsed));
    NSString *ambiguous = [status stringByReplacingOccurrencesOfString:
        @"\"assistantSessionObject\":false,\"displaySessionObject\":false,"
        withString:@""];
    XCTAssertNil(IDFloatingCursorCopyLifecycle(ambiguous));
    NSString *identityFree = [status stringByReplacingOccurrencesOfString:
        @"\"sessionOwnersMatch\":false,\"assistantSessionToken\":\"nil\","
         "\"displaySessionToken\":\"nil\"," withString:@""];
    XCTAssertNil(IDFloatingCursorCopyLifecycle(identityFree));
}

- (NSDictionary<NSString *, id> *)validAtomicTruthSnapshot {
    NSData *data = [[self statusJSONWithCanonical:@"atomic"]
        dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *status = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return @{
        @"selection": status[@"selection"], @"startAffinity": status[@"startAffinity"],
        @"endAffinity": status[@"endAffinity"], @"firstResponder": @YES,
        @"keyboardVisible": @YES, @"containerCreations": @1,
        @"containerStable": @YES, @"presentationUpdates": @0,
        @"contentOffset": status[@"contentOffset"], @"lifecycle": status[@"lifecycle"],
        @"retention": @{@"editorRetained": @YES, @"assistantRetained": @YES,
            @"containerRetained": @YES, @"sessionRetained": @NO,
            @"autoscrollRetained": @NO},
        @"observation": @{@"source": @"app-side-weak-reference-snapshot",
            @"sequence": @7, @"lifecycleSequence": @7, @"retentionSequence": @7,
            @"capturedAt": @12.5, @"actionEpoch": @0, @"releaseEpoch": @11.5,
            @"terminalEpoch": @11.4, @"liftTargetEpoch": @11.5,
            @"captureTargetEpoch": @12.0, @"phase": @"exact-release-500ms",
            @"terminalEvent": @"normalEnd", @"terminalCountAtRelease": @1},
    };
}

- (void)testTruthSnapshotRejectsCrossTimeFusionAndSyntheticRetentionSource {
    NSDictionary *valid = [self validAtomicTruthSnapshot];
    XCTAssertTrue(IDFloatingCursorTruthSnapshotIsAtomic(valid));
    NSMutableDictionary *fused = [valid mutableCopy];
    NSMutableDictionary *observation = [valid[@"observation"] mutableCopy];
    observation[@"retentionSequence"] = @6;
    fused[@"observation"] = observation;
    XCTAssertFalse(IDFloatingCursorTruthSnapshotIsAtomic(fused));
    NSMutableDictionary *synthetic = [valid mutableCopy];
    observation = [valid[@"observation"] mutableCopy];
    observation[@"source"] = @"xcu-injected-retention";
    synthetic[@"observation"] = observation;
    XCTAssertFalse(IDFloatingCursorTruthSnapshotIsAtomic(synthetic));
}

- (void)testTruthPhaseChronologyRejectsTerminalBeforeOrdinaryAction {
    NSDictionary *valid = [self validAtomicTruthSnapshot];
    NSMutableArray *phases = [NSMutableArray array];
    NSArray *names = @[@"held", @"terminal", @"immediate", @"exact-action-500ms",
                       @"post-keyboard-lift-500ms"];
    NSArray *captures = @[@9.0, @10.01, @10.02, @10.5, @12.05];
    NSArray *targets = @[@9.0, @10.01, @10.0, @10.5, @12.05];
    for (NSUInteger index = 0; index < names.count; index += 1) {
        NSMutableDictionary *snapshot = [valid mutableCopy];
        NSMutableDictionary *observation = [valid[@"observation"] mutableCopy];
        observation[@"sequence"] = @(index + 1);
        observation[@"lifecycleSequence"] = @(index + 1);
        observation[@"retentionSequence"] = @(index + 1);
        observation[@"phase"] = names[index];
        observation[@"capturedAt"] = captures[index];
        observation[@"captureTargetEpoch"] = targets[index];
        observation[@"actionEpoch"] = index == 0 ? @0 : @10.0;
        observation[@"terminalEpoch"] = index == 0 ? @0 : @10.01;
        observation[@"releaseEpoch"] = @0;
        observation[@"liftTargetEpoch"] = index == 0 ? @0 : @11.55;
        snapshot[@"observation"] = observation;
        [phases addObject:snapshot];
    }
    XCTAssertTrue(IDFloatingCursorTruthPhasesHaveValidChronology(phases, NO));
    NSMutableArray *reversed = [phases mutableCopy];
    NSMutableDictionary *terminal = [reversed[1] mutableCopy];
    NSMutableDictionary *observation = [terminal[@"observation"] mutableCopy];
    observation[@"terminalEpoch"] = @9.99;
    terminal[@"observation"] = observation;
    reversed[1] = terminal;
    XCTAssertFalse(IDFloatingCursorTruthPhasesHaveValidChronology(reversed, NO));
}

- (void)testReleaseChronologyOrdersExactAndPostByLiteralCaptureTargets {
    NSDictionary *valid = [self validAtomicTruthSnapshot];
    NSArray *names = @[@"held", @"terminal", @"immediate",
                       @"exact-release-500ms", @"post-keyboard-lift-500ms"];
    NSArray *captures = @[@10.0, @11.51, @11.52, @12.01, @12.0];
    NSArray *targets = @[@10.0, @11.51, @11.51, @12.01, @12.0];
    NSArray *sequences = @[@1, @2, @3, @5, @4];
    NSMutableArray *phases = [NSMutableArray array];
    for (NSUInteger index = 0; index < names.count; index += 1) {
        NSMutableDictionary *snapshot = [valid mutableCopy];
        NSMutableDictionary *observation = [valid[@"observation"] mutableCopy];
        observation[@"sequence"] = sequences[index];
        observation[@"lifecycleSequence"] = sequences[index];
        observation[@"retentionSequence"] = sequences[index];
        observation[@"phase"] = names[index];
        observation[@"capturedAt"] = captures[index];
        observation[@"captureTargetEpoch"] = targets[index];
        observation[@"actionEpoch"] = @0;
        observation[@"terminalEpoch"] = index == 0 ? @0 : @11.5;
        observation[@"releaseEpoch"] = index == 0 ? @0 : @11.51;
        observation[@"liftTargetEpoch"] = index == 0 ? @0 : @11.5;
        snapshot[@"observation"] = observation;
        [phases addObject:snapshot];
    }
    XCTAssertTrue(IDFloatingCursorTruthPhasesHaveValidChronology(phases, YES));
    NSMutableArray *inverted = [phases mutableCopy];
    for (NSUInteger index = 3; index <= 4; index += 1) {
        NSMutableDictionary *snapshot = [inverted[index] mutableCopy];
        NSMutableDictionary *observation = [snapshot[@"observation"] mutableCopy];
        observation[@"sequence"] = index == 3 ? @4 : @5;
        observation[@"lifecycleSequence"] = observation[@"sequence"];
        observation[@"retentionSequence"] = observation[@"sequence"];
        snapshot[@"observation"] = observation;
        inverted[index] = snapshot;
    }
    XCTAssertFalse(IDFloatingCursorTruthPhasesHaveValidChronology(inverted, YES));
}

- (void)testNormalPhaseParityRejectsMissingFieldAndBrokenWithinHostRelation {
    NSDictionary *valid = [self validAtomicTruthSnapshot];
    NSArray *stock = @[valid, valid, valid, valid, valid];
    NSArray *custom = @[valid, valid, valid, valid, valid];
    XCTAssertTrue(IDFloatingCursorNormalPhasesHaveCompleteParity(stock, custom));
    NSMutableDictionary *missing = [valid mutableCopy];
    [missing removeObjectForKey:@"keyboardVisible"];
    XCTAssertFalse(IDFloatingCursorNormalPhasesHaveCompleteParity(
        stock, @[valid, valid, missing, valid, valid]));
    NSMutableDictionary *changed = [valid mutableCopy];
    NSMutableDictionary *lifecycle = [valid[@"lifecycle"] mutableCopy];
    lifecycle[@"containerToken"] = @"different-within-custom-host";
    changed[@"lifecycle"] = lifecycle;
    XCTAssertFalse(IDFloatingCursorNormalPhasesHaveCompleteParity(
        stock, @[valid, valid, changed, valid, valid]));
}

- (NSArray<NSDictionary<NSString *, id> *> *)selectableParityPhasesWithWeakSession:
    (BOOL)weakSession {
    NSDictionary *valid = [self validAtomicTruthSnapshot];
    NSMutableArray *phases = [NSMutableArray array];
    for (NSUInteger index = 0; index < 5; index += 1) {
        NSMutableDictionary *phase = [valid mutableCopy];
        NSMutableDictionary *retention = [valid[@"retention"] mutableCopy];
        retention[@"sessionRetained"] = @((BOOL)(weakSession &&
            (index == 1 || index == 2)));
        phase[@"retention"] = retention;
        NSMutableDictionary *lifecycle = [valid[@"lifecycle"] mutableCopy];
        if (index > 0) {
            lifecycle[@"selectableOffActionCount"] = @1;
            lifecycle[@"selectableOffCount"] = @1;
            lifecycle[@"responderLossCount"] = @1;
            lifecycle[@"editable"] = @NO;
            lifecycle[@"selectable"] = @NO;
            phase[@"firstResponder"] = @NO;
            phase[@"presentationUpdates"] = @1;
        }
        if (index >= 3) phase[@"keyboardVisible"] = @NO;
        phase[@"lifecycle"] = lifecycle;
        [phases addObject:phase];
    }
    return phases;
}

- (NSArray<NSDictionary<NSString *, id> *> *)phasesByMutatingPhase:(NSUInteger)index
    inPhases:(NSArray<NSDictionary<NSString *, id> *> *)phases
    block:(void (^)(NSMutableDictionary *, NSMutableDictionary *,
                    NSMutableDictionary *))block {
    NSMutableArray *copy = [phases mutableCopy];
    NSMutableDictionary *phase = [copy[index] mutableCopy];
    NSMutableDictionary *lifecycle = [phase[@"lifecycle"] mutableCopy];
    NSMutableDictionary *retention = [phase[@"retention"] mutableCopy];
    block(phase, lifecycle, retention);
    phase[@"lifecycle"] = lifecycle;
    phase[@"retention"] = retention;
    copy[index] = phase;
    return copy;
}

- (void)testSelectableWeakSessionExceptionRejectsBrokenSemanticAndQuiescentState {
    NSArray *stock = [self selectableParityPhasesWithWeakSession:NO];
    NSArray *custom = [self selectableParityPhasesWithWeakSession:YES];
    for (NSUInteger index = 0; index < stock.count; index += 1) {
        XCTAssertTrue(IDFloatingCursorTruthSnapshotIsAtomic(stock[index]),
                      @"stock atomic index %lu", (unsigned long)index);
        XCTAssertTrue(IDFloatingCursorTruthSnapshotIsAtomic(custom[index]),
                      @"custom atomic index %lu", (unsigned long)index);
    }
    XCTAssertTrue(IDFloatingCursorNormalPhasesHaveCompleteParity(stock, stock),
                  @"strict stock fixture invalid");
    XCTAssertTrue(IDFloatingCursorNormalPhasesHaveCompleteParity(custom, custom),
                  @"strict custom fixture invalid");
    XCTAssertTrue(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
        stock, stock, @"selectableOffAction"), @"stock fixture invalid");
    XCTAssertTrue(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
        custom, custom, @"selectableOffAction"), @"custom fixture invalid");
    XCTAssertTrue(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
        stock, custom, @"selectableOffAction"));
    for (NSString *key in @[@"assistantSessionObject", @"displaySessionObject",
                             @"sessionObject", @"sessionOwnersMatch", @"sessionActive",
                             @"autoscrollActive"]) {
        NSArray *broken = [self phasesByMutatingPhase:1 inPhases:custom
            block:^(NSMutableDictionary *phase, NSMutableDictionary *lifecycle,
                    NSMutableDictionary *retention) {
                (void)phase; (void)retention; lifecycle[key] = @YES;
            }];
        XCTAssertFalse(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
            stock, broken, @"selectableOffAction"), @"accepted broken %@", key);
    }
    for (NSNumber *index in @[@3, @4]) {
        NSArray *broken = [self phasesByMutatingPhase:index.unsignedIntegerValue
            inPhases:custom block:^(NSMutableDictionary *phase,
                NSMutableDictionary *lifecycle, NSMutableDictionary *retention) {
                (void)phase; (void)lifecycle; retention[@"sessionRetained"] = @YES;
            }];
        XCTAssertFalse(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
            stock, broken, @"selectableOffAction"));
    }
    NSArray<NSDictionary *> *mutations = @[
        @{@"phase": @4, @"kind": @"selection"},
        @{@"phase": @4, @"kind": @"presentation"},
        @{@"phase": @4, @"kind": @"container"},
        @{@"phase": @4, @"kind": @"creations"},
        @{@"phase": @4, @"kind": @"offset"},
        @{@"phase": @4, @"kind": @"autoscroll"},
        @{@"phase": @4, @"kind": @"counter"},
        @{@"phase": @4, @"kind": @"recognizer"},
    ];
    for (NSDictionary *mutation in mutations) {
        NSString *kind = mutation[@"kind"];
        NSArray *broken = [self phasesByMutatingPhase:[mutation[@"phase"] unsignedIntegerValue]
            inPhases:custom block:^(NSMutableDictionary *phase,
                NSMutableDictionary *lifecycle, NSMutableDictionary *retention) {
                (void)retention;
                if ([kind isEqualToString:@"selection"])
                    phase[@"selection"] = @{@"location": @47, @"length": @0};
                else if ([kind isEqualToString:@"presentation"])
                    phase[@"presentationUpdates"] = @2;
                else if ([kind isEqualToString:@"container"])
                    lifecycle[@"containerToken"] = @"delayed-container";
                else if ([kind isEqualToString:@"creations"])
                    phase[@"containerCreations"] = @2;
                else if ([kind isEqualToString:@"offset"])
                    phase[@"contentOffset"] = @{@"x": @0, @"y": @1};
                else if ([kind isEqualToString:@"autoscroll"])
                    lifecycle[@"autoscrollActive"] = @YES;
                else if ([kind isEqualToString:@"counter"])
                    lifecycle[@"selectableOffCount"] = @2;
                else {
                    lifecycle[@"recognizerIdentitySignature"] = @[@"new"];
                    lifecycle[@"recognizerCount"] = @1;
                    lifecycle[@"recognizerUnexpectedNewCount"] = @1;
                    lifecycle[@"recognizerSubsetOfBaseline"] = @NO;
                }
            }];
        XCTAssertFalse(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
            stock, broken, @"selectableOffAction"), @"accepted delayed %@", kind);
    }
}

- (void)testWeakSessionMismatchRemainsStrictOutsideSelectableTerminalAndImmediate {
    NSArray *stock = [self selectableParityPhasesWithWeakSession:NO];
    NSArray *custom = [self selectableParityPhasesWithWeakSession:YES];
    for (id event in @[@"normalEnd", @"resignAction", @"keyboardDismissAction",
                       @"editableOffAction", @"windowDetachAction", NSNull.null]) {
        XCTAssertFalse(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
            stock, custom, event == NSNull.null ? nil : event), @"relaxed %@", event);
    }
    for (NSNumber *index in @[@0, @3, @4]) {
        NSArray *broken = [self phasesByMutatingPhase:index.unsignedIntegerValue
            inPhases:stock block:^(NSMutableDictionary *phase,
                NSMutableDictionary *lifecycle, NSMutableDictionary *retention) {
                (void)phase; (void)lifecycle; retention[@"sessionRetained"] = @YES;
            }];
        XCTAssertFalse(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
            stock, broken, @"selectableOffAction"));
    }
}

- (void)testStatusCanonicalCopyRequiresExactValidStatus {
    NSMutableString *canonical = [@"unchanged canonical" mutableCopy];
    NSString *status = [self statusJSONWithCanonical:canonical];
    NSString *copy = IDFloatingCursorCopyCanonical(status);
    XCTAssertEqualObjects(copy, @"unchanged canonical");
    [canonical appendString:@" mutated"];
    XCTAssertEqualObjects(copy, @"unchanged canonical");
    XCTAssertNil(IDFloatingCursorCopyCanonical(
        [status stringByReplacingOccurrencesOfString:@"\"firstResponder\":true"
                                          withString:@"\"firstResponder\":true,\"extra\":0"]));
}

- (void)testStatusParserAcceptsAtomicCursorCallbackRecord {
    NSString *status = [self statusJSONWithCanonical:@"unchanged canonical"];
    NSString *original = status;
    status = [status stringByReplacingOccurrencesOfString:@"\"cursorCallback\":null"
                                               withString:
        @"\"cursorCallback\":{"
         "\"sequence\":1,\"kind\":\"cursor\","
         "\"interactionContainer\":true,"
         "\"point\":{\"x\":123.5,\"y\":22.25},"
         "\"output\":{\"offset\":11,\"affinity\":0}}"];
    XCTAssertNotEqualObjects(status, original);
    XCTAssertNotNil([NSJSONSerialization JSONObjectWithData:
        [status dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]);
    IDFloatingCursorStatus parsed = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(status, &parsed));
}

- (void)testStatusParserRejectsCursorCallbackOutsideInteractionContainer {
    NSString *status = [self statusJSONWithCanonical:@"unchanged canonical"];
    NSString *original = status;
    status = [status stringByReplacingOccurrencesOfString:@"\"cursorCallback\":null"
                                               withString:
        @"\"cursorCallback\":{"
         "\"sequence\":1,\"kind\":\"cursor\","
         "\"interactionContainer\":false,"
         "\"point\":{\"x\":123.5,\"y\":22.25},"
         "\"output\":{\"offset\":11,\"affinity\":0}}"];
    XCTAssertNotEqualObjects(status, original);
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:
        [status dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    XCTAssertTrue([object[@"cursorCallback"] isKindOfClass:NSDictionary.class]);
    XCTAssertEqualObjects(object[@"cursorCallback"][@"interactionContainer"], @NO);
    IDFloatingCursorStatus parsed = {0};
    XCTAssertFalse(IDFloatingCursorParseStatus(status, &parsed));
}

- (void)testSpacebarFrameValidatorRejectsNullInfiniteAndEveryNonfiniteComponent {
    XCTAssertTrue(IDFloatingCursorFrameIsValid(CGRectMake(1, 2, 3, 4)));
    XCTAssertFalse(IDFloatingCursorFrameIsValid(CGRectNull));
    XCTAssertFalse(IDFloatingCursorFrameIsValid(CGRectInfinite));
    NSArray<NSValue *> *invalid = @[
        [NSValue valueWithCGRect:CGRectMake(NAN, 2, 3, 4)],
        [NSValue valueWithCGRect:CGRectMake(1, INFINITY, 3, 4)],
        [NSValue valueWithCGRect:CGRectMake(1, 2, -INFINITY, 4)],
        [NSValue valueWithCGRect:CGRectMake(1, 2, 3, NAN)],
    ];
    for (NSValue *value in invalid) {
        XCTAssertFalse(IDFloatingCursorFrameIsValid(value.CGRectValue), @"%@", value);
    }
}

- (void)addScreenshot:(XCUIScreenshot *)screenshot name:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (IDFloatingCursorRun *)runApplication:(XCUIApplication *)application
                                  editor:(XCUIElement *)editor
                                  status:(XCUIElement *)statusElement {
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);
    IDFloatingCursorRun *run = [IDFloatingCursorRun new];
    IDFloatingCursorStatus initial = {0};
    NSString *initialCanonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(statusElement, 4.0,
        ^BOOL(IDFloatingCursorStatus status) {
            return status.firstResponder && status.selection.length == 0 &&
                status.containerStable && status.containerCreations == 1;
        }, &initial, &initialCanonical), @"status=%@", statusElement.value);
    run.initial = initial;
    run.initialCanonical = initialCanonical;
    XCTAssertNotNil(run.initialCanonical);
    run.editorFrame = editor.frame;
    [self addScreenshot:XCUIScreen.mainScreen.screenshot name:@"floating-cursor-baseline"];

    CGRect spacebar = IDFloatingCursorSpacebarFrame(self, application);
    XCTAssertFalse(CGRectIsNull(spacebar));
    if (CGRectIsNull(spacebar)) return run;
    CGPoint center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    CGPoint horizontal = CGPointMake(center.x + 24.0, center.y);
    CGPoint finalPoint = CGPointMake(center.x + 48.0, center.y - 18.0);
    IDHIDTouchPath *path = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:center startOffset:0.0 waypoints:@[
            [IDHIDTouchWaypoint moveTo:center offset:0.55],
            [IDHIDTouchWaypoint moveTo:horizontal offset:0.85],
            [IDHIDTouchWaypoint moveTo:finalPoint offset:1.15],
            [IDHIDTouchWaypoint moveTo:finalPoint offset:1.55],
            [IDHIDTouchWaypoint liftAtOffset:1.80],
        ]];

    IDFloatingCursorObservation *observation = [IDFloatingCursorObservation new];
    dispatch_semaphore_t observed = dispatch_semaphore_create(0);
    CFTimeInterval epoch = CACurrentMediaTime();
    CFTimeInterval liftTime = epoch + 1.80;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (CACurrentMediaTime() < epoch + 0.62) [NSThread sleepForTimeInterval:0.01];
        IDFloatingCursorStatus held = {0};
        id heldValue = statusElement.value;
        observation.heldParsed = IDFloatingCursorParseStatus(heldValue, &held);
        observation.held = held;
        observation.heldCanonical = IDFloatingCursorCopyCanonical(heldValue);
        observation.heldScreenshot = XCUIScreen.mainScreen.screenshot;
        observation.heldCaptureTime = CACurrentMediaTime();
        while (CACurrentMediaTime() < epoch + 1.28) [NSThread sleepForTimeInterval:0.01];
        IDFloatingCursorStatus moved = {0};
        id movedValue = statusElement.value;
        observation.movedParsed = IDFloatingCursorParseStatus(movedValue, &moved);
        observation.moved = moved;
        observation.movedCanonical = IDFloatingCursorCopyCanonical(movedValue);
        observation.movedScreenshot = XCUIScreen.mainScreen.screenshot;
        observation.movedCaptureTime = CACurrentMediaTime();
        dispatch_semaphore_signal(observed);
    });
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, application, @[path], &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(observed,
        dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0L);
    XCTAssertTrue(observation.heldParsed);
    XCTAssertTrue(observation.movedParsed);
    XCTAssertNotNil(observation.heldScreenshot);
    XCTAssertNotNil(observation.movedScreenshot);
    XCTAssertLessThan(observation.heldCaptureTime, liftTime);
    XCTAssertLessThan(observation.movedCaptureTime, liftTime);
    if (!observation.heldParsed || !observation.movedParsed) return run;
    if (observation.heldScreenshot != nil)
        [self addScreenshot:observation.heldScreenshot name:@"floating-cursor-held"];
    if (observation.movedScreenshot != nil)
        [self addScreenshot:observation.movedScreenshot name:@"floating-cursor-moved"];
    XCTAssertEqual(observation.held.selection.length, 0U);
    XCTAssertEqual(observation.moved.selection.length, 0U);
    XCTAssertFalse(NSEqualRanges(observation.moved.selection, run.initial.selection));
    XCTAssertEqualObjects(observation.heldCanonical, run.initialCanonical);
    XCTAssertEqualObjects(observation.movedCanonical, run.initialCanonical);
    XCTAssertEqual(observation.moved.containerCreations, run.initial.containerCreations);
    XCTAssertTrue(observation.moved.containerStable);

    IDFloatingCursorStatus ended = {0};
    NSString *endedCanonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(statusElement, 3.0,
        ^BOOL(IDFloatingCursorStatus status) {
            return status.selection.length == 0 && status.containerStable;
        }, &ended, &endedCanonical), @"status=%@", statusElement.value);
    run.ended = ended;
    run.endedCanonical = endedCanonical;
    XCTAssertEqualObjects(run.endedCanonical, run.initialCanonical);
    [self addScreenshot:XCUIScreen.mainScreen.screenshot name:@"floating-cursor-ended"];
    NSRange endedRange = run.ended.selection;
    [NSThread sleepForTimeInterval:0.5];
    IDFloatingCursorStatus quiesced = {0};
    id quiescedValue = statusElement.value;
    XCTAssertTrue(IDFloatingCursorParseStatus(quiescedValue, &quiesced));
    XCTAssertEqualObjects(IDFloatingCursorCopyCanonical(quiescedValue), run.initialCanonical);
    XCTAssertTrue(NSEqualRanges(quiesced.selection, endedRange));
    XCTAssertEqual(quiesced.containerCreations, run.initial.containerCreations);
    XCTAssertTrue(quiesced.containerStable);
    NSString *host = [editor.identifier isEqualToString:@"block-text-view"] ? @"custom" : @"stock";
    XCTAttachment *ranges = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
        @"initial=%@ held=%@ moved=%@ ended=%@ quiesced=%@ "
         "heldCapture=%.3f movedCapture=%.3f lift=%.3f canonicalUnchanged=%@",
        NSStringFromRange(run.initial.selection), NSStringFromRange(observation.held.selection),
        NSStringFromRange(observation.moved.selection), NSStringFromRange(run.ended.selection),
        NSStringFromRange(quiesced.selection), observation.heldCaptureTime - epoch,
        observation.movedCaptureTime - epoch, liftTime - epoch,
        [run.endedCanonical isEqualToString:run.initialCanonical] ? @"YES" : @"NO"]];
    ranges.name = [host stringByAppendingString:@"-floating-cursor-ranges"];
    ranges.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:ranges];
    return run;
}

- (void)testSpacebarTrackpadMovesCollapsedCursorLikeStock {
    IDFloatingCursorStatus parser = {0};
    NSString *maximum = [[self statusJSONWithCanonical:@"x"]
        stringByReplacingOccurrencesOfString:@"\"location\":46"
                                  withString:@"\"location\":18446744073709551615"];
    XCTAssertTrue(IDFloatingCursorParseStatus(maximum, &parser));
    XCTAssertEqual(parser.selection.location, NSUIntegerMax);
    IDFloatingCursorStatus successor = {0};
    XCTAssertFalse(IDFloatingCursorParseStatus(
        [maximum stringByReplacingOccurrencesOfString:@"18446744073709551615"
                                           withString:@"18446744073709551616"], &successor));

    XCUIApplication *custom = IDFloatingCursorLaunchCustom(self, @"floating-ltr");
    XCUIElement *customEditor =
        [custom descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *customStatus =
        [custom descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    IDFloatingCursorRun *customRun = [self runApplication:custom
                                                   editor:customEditor status:customStatus];
    [custom terminate];

    XCUIApplication *stock = IDFloatingCursorLaunchStock(self, @"floating-ltr",
                                                         customRun.editorFrame);
    XCUIElement *stockEditor =
        [stock descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"];
    XCUIElement *stockStatus =
        [stock descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    IDFloatingCursorRun *stockRun = [self runApplication:stock
                                                  editor:stockEditor status:stockStatus];
    XCTAssertTrue(NSEqualRanges(customRun.initial.selection, stockRun.initial.selection),
                  @"custom=%@ stock=%@", NSStringFromRange(customRun.initial.selection),
                  NSStringFromRange(stockRun.initial.selection));
    XCTAssertFalse(NSEqualRanges(stockRun.initial.selection, stockRun.ended.selection));
    XCTAssertFalse(NSEqualRanges(customRun.initial.selection, customRun.ended.selection));
    XCTAssertTrue(NSEqualRanges(customRun.ended.selection, stockRun.ended.selection),
                  @"custom=%@ stock=%@", NSStringFromRange(customRun.ended.selection),
                  NSStringFromRange(stockRun.ended.selection));
    XCTAssertEqual(customRun.ended.selection.length, 0U);
    XCTAssertEqual(stockRun.ended.selection.length, 0U);
}

- (IDFloatingCursorLifecycleRun *)runLifecycleApplication:(XCUIApplication *)application
                                                    editor:(XCUIElement *)editor
                                                    status:(XCUIElement *)statusElement
                                             truthHeldOnly:(BOOL)truthHeldOnly
                                               actionPoint:(CGPoint)actionPoint
                                                      name:(NSString *)name {
    IDFloatingCursorStatus initial = {0};
    XCTAssertTrue(IDFloatingCursorWaitForStatus(statusElement, 4.0,
        ^BOOL(IDFloatingCursorStatus status) {
            return status.firstResponder && status.containerStable;
        }, &initial, NULL), @"status=%@", statusElement.value);
    CGRect spacebar = IDFloatingCursorSpacebarFrame(self, application);
    XCTAssertFalse(CGRectIsNull(spacebar));
    CGPoint center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    IDHIDFloatingLifecycleSchedule *schedule = [IDHIDFloatingLifecycleSchedule new];
    schedule.keyboardActivation = 0.55;
    schedule.heldCapture = 0.92;
    schedule.actionDown = 1.05;
    schedule.actionUp = 1.15;
    schedule.immediateCapture = 1.30;
    schedule.settledCapture = 1.65;
    schedule.keyboardLift = 2.70;
    schedule.postLiftCapture = 3.20;
    NSArray<IDHIDTouchPath *> *touchPaths = nil;
    NSError *scheduleError = nil;
    XCTAssertTrue(IDHIDBuildFloatingLifecycleTouchPaths(
        center, actionPoint, schedule, &touchPaths, &scheduleError), @"%@", scheduleError);
    if (touchPaths == nil) return [IDFloatingCursorLifecycleRun new];
    IDFloatingCursorLifecycleRun *run = [IDFloatingCursorLifecycleRun new];
    run.initial = initial;
    run.initialTrace = IDFloatingCursorCopyLifecycle(statusElement.value);
    run.initialKeyboardCount = application.keyboards.count;
    __block BOOL heldParsed = NO;
    __block BOOL endedParsed = NO;
    __block BOOL immediateParsed = NO;
    __block BOOL settledParsed = NO;
    __block IDFloatingCursorStatus heldStatus = {0};
    __block IDFloatingCursorStatus endedStatus = {0};
    __block IDFloatingCursorStatus immediateStatus = {0};
    __block IDFloatingCursorStatus settledStatus = {0};
    __block XCUIScreenshot *heldScreenshot = nil;
    __block XCUIScreenshot *endedScreenshot = nil;
    __block XCUIScreenshot *immediateScreenshot = nil;
    __block XCUIScreenshot *settledScreenshot = nil;
    dispatch_semaphore_t observed = dispatch_semaphore_create(0);
    CFTimeInterval epoch = IDFloatingCursorMonotonicTime();
    run.epoch = epoch;
    run.keyboardLiftOffset = schedule.keyboardLift;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (IDFloatingCursorMonotonicTime() < epoch + schedule.heldCapture)
            [NSThread sleepForTimeInterval:0.005];
        run.heldKeyboardCount = application.keyboards.count;
        id heldValue = statusElement.value;
        heldParsed = IDFloatingCursorParseStatus(heldValue, &heldStatus);
        run.heldTrace = IDFloatingCursorCopyLifecycle(heldValue);
        heldScreenshot = XCUIScreen.mainScreen.screenshot;
        run.heldTime = IDFloatingCursorMonotonicTime();
        while (IDFloatingCursorMonotonicTime() < epoch + schedule.actionUp + 0.02)
            [NSThread sleepForTimeInterval:0.005];
        id endedValue = statusElement.value;
        endedParsed = IDFloatingCursorParseStatus(endedValue, &endedStatus);
        run.endedTrace = IDFloatingCursorCopyLifecycle(endedValue);
        run.endedKeyboardCount = application.keyboards.count;
        endedScreenshot = XCUIScreen.mainScreen.screenshot;
        while (IDFloatingCursorMonotonicTime() < epoch + schedule.immediateCapture)
            [NSThread sleepForTimeInterval:0.005];
        id immediateValue = statusElement.value;
        immediateParsed = IDFloatingCursorParseStatus(immediateValue, &immediateStatus);
        run.immediateTrace = IDFloatingCursorCopyLifecycle(immediateValue);
        run.immediateKeyboardCount = application.keyboards.count;
        immediateScreenshot = XCUIScreen.mainScreen.screenshot;
        run.immediateTime = IDFloatingCursorMonotonicTime();
        while (IDFloatingCursorMonotonicTime() < epoch + schedule.settledCapture)
            [NSThread sleepForTimeInterval:0.005];
        id settledValue = statusElement.value;
        settledParsed = IDFloatingCursorParseStatus(settledValue, &settledStatus);
        run.settledTrace = IDFloatingCursorCopyLifecycle(settledValue);
        run.settledKeyboardCount = application.keyboards.count;
        settledScreenshot = XCUIScreen.mainScreen.screenshot;
        run.settledTime = IDFloatingCursorMonotonicTime();
        dispatch_semaphore_signal(observed);
    });
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, application, touchPaths, &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(observed,
        dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0L);
    XCTAssertTrue(heldParsed);
    XCTAssertTrue(endedParsed);
    XCTAssertTrue(immediateParsed);
    XCTAssertTrue(settledParsed);
    run.held = heldStatus;
    run.ended = endedStatus;
    run.immediate = immediateStatus;
    run.settled = settledStatus;
    XCTAssertGreaterThan(run.heldKeyboardCount, 0U);
    if (!truthHeldOnly) {
        XCTAssertTrue(run.held.firstResponder);
        XCTAssertTrue([run.heldTrace[@"sessionObject"] boolValue]);
        XCTAssertTrue([run.heldTrace[@"assistantSessionObject"] boolValue]);
        XCTAssertTrue([run.heldTrace[@"displaySessionObject"] boolValue]);
        XCTAssertTrue([run.heldTrace[@"sessionOwnersMatch"] boolValue]);
        XCTAssertEqualObjects(run.heldTrace[@"assistantSessionToken"],
                              run.heldTrace[@"displaySessionToken"]);
        XCTAssertTrue([run.heldTrace[@"sessionActive"] boolValue]);
    }
    XCTAssertFalse(run.immediate.firstResponder);
    XCTAssertTrue(NSEqualRanges(run.immediate.selection, run.settled.selection));
    XCTAssertEqual(run.settled.containerCreations, initial.containerCreations);
    XCTAssertTrue(run.settled.containerStable);
    while (IDFloatingCursorMonotonicTime() < epoch + schedule.postLiftCapture) {
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    id quiescedValue = statusElement.value;
    IDFloatingCursorStatus quiesced = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(quiescedValue, &quiesced));
    run.quiesced = quiesced;
    run.quiescedTrace = IDFloatingCursorCopyLifecycle(quiescedValue);
    run.quiescedKeyboardCount = application.keyboards.count;
    XCTAssertFalse(run.quiesced.firstResponder);
    if (!truthHeldOnly) XCTAssertEqual(run.quiescedKeyboardCount, 0U);
    XCTAssertTrue(NSEqualRanges(run.settled.selection, run.quiesced.selection));
    XCTAssertEqual(run.settled.containerCreations, run.quiesced.containerCreations);
    XCTAssertEqual(run.settled.containerStable, run.quiesced.containerStable);
    XCTAssertEqual(run.settled.presentationUpdates, run.quiesced.presentationUpdates);
    XCTAssertEqualObjects(run.settledTrace[@"editable"], run.quiescedTrace[@"editable"]);
    XCTAssertEqualObjects(run.settledTrace[@"selectable"], run.quiescedTrace[@"selectable"]);
    XCTAssertEqualObjects(run.settledTrace[@"sessionObject"],
                          run.quiescedTrace[@"sessionObject"]);
    XCTAssertEqualObjects(run.settledTrace[@"autoscrollObject"],
                          run.quiescedTrace[@"autoscrollObject"]);
    if (!truthHeldOnly) {
        XCTAssertFalse([run.quiescedTrace[@"sessionActive"] boolValue]);
        XCTAssertFalse([run.quiescedTrace[@"autoscrollActive"] boolValue]);
    }
    XCUIScreenshot *quiescedScreenshot = XCUIScreen.mainScreen.screenshot;
    [self addScreenshot:heldScreenshot name:[name stringByAppendingString:@"-held"]];
    [self addScreenshot:endedScreenshot name:[name stringByAppendingString:@"-ended"]];
    [self addScreenshot:immediateScreenshot name:[name stringByAppendingString:@"-interrupted"]];
    [self addScreenshot:settledScreenshot name:[name stringByAppendingString:@"-settled"]];
    [self addScreenshot:quiescedScreenshot name:[name stringByAppendingString:@"-post-lift"]];
    XCTAttachment *states = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
        @"initial=%@ held=%@ immediate=%@ settled=%@ quiesced=%@ firstResponder=%@/%@/%@/%@/%@ "
         "keyboard=%lu/%lu/%lu/%lu timing=%.3f/%.3f/%.3f lift=%.3f trace=%@",
        NSStringFromRange(initial.selection), NSStringFromRange(run.held.selection),
        NSStringFromRange(run.immediate.selection), NSStringFromRange(run.settled.selection),
        NSStringFromRange(run.quiesced.selection),
        initial.firstResponder ? @"YES" : @"NO", run.held.firstResponder ? @"YES" : @"NO",
        run.immediate.firstResponder ? @"YES" : @"NO",
        run.settled.firstResponder ? @"YES" : @"NO",
        run.quiesced.firstResponder ? @"YES" : @"NO",
        (unsigned long)run.heldKeyboardCount, (unsigned long)run.immediateKeyboardCount,
        (unsigned long)run.settledKeyboardCount, (unsigned long)run.quiescedKeyboardCount,
        run.heldTime - epoch, run.immediateTime - epoch, run.settledTime - epoch,
        schedule.keyboardLift, run.settledTrace]];
    states.name = [name stringByAppendingString:@"-status"];
    states.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:states];
    (void)editor;
    return run;
}

- (void)assertLifecycleStock:(IDFloatingCursorLifecycleRun *)stock
                      custom:(IDFloatingCursorLifecycleRun *)custom
                       event:(NSString *)event
           projectAutoscroll:(BOOL)projectAutoscroll {
    {
    NSArray<NSDictionary<NSString *, id> *> *stockPhases = @[
        stock.heldSnapshot, stock.terminalSnapshot, stock.immediateSnapshot,
        stock.exactSnapshot, stock.postLiftSnapshot];
    NSArray<NSDictionary<NSString *, id> *> *customPhases = @[
        custom.heldSnapshot, custom.terminalSnapshot, custom.immediateSnapshot,
        custom.exactSnapshot, custom.postLiftSnapshot];
    NSArray<NSString *> *phaseNames = @[@"held", @"terminal", @"immediate",
        @"exact", @"postLift"];
    NSArray<NSString *> *topKeys = @[@"selection", @"startAffinity", @"endAffinity",
        @"firstResponder", @"keyboardVisible", @"containerCreations",
        @"containerStable", @"contentOffset", @"retention"];
    NSArray<NSString *> *lifecycleKeys = @[@"normalEndCount", @"windowDetachActionCount",
        @"windowDetachCount", @"resignActionCount", @"keyboardDismissActionCount",
        @"editableOffActionCount", @"selectableOffActionCount", @"responderLossCount",
        @"editableOffCount", @"selectableOffCount", @"startCount", @"cancelCount",
        @"editable", @"selectable", @"containerStable", @"containerSubviews",
        @"sessionObject", @"assistantSessionObject", @"displaySessionObject",
        @"sessionOwnersMatch", @"sessionActive", @"autoscrollObject",
        @"autoscrollActive", @"startAffinity", @"endAffinity"];
    NSString *stockContainer = stockPhases.firstObject[@"lifecycle"][@"containerToken"];
    NSString *customContainer = customPhases.firstObject[@"lifecycle"][@"containerToken"];
    NSUInteger stockInitialPresentation =
        [stockPhases.firstObject[@"presentationUpdates"] unsignedIntegerValue];
    NSUInteger customInitialPresentation =
        [customPhases.firstObject[@"presentationUpdates"] unsignedIntegerValue];
    NSUInteger previousStockPresentation = 0;
    NSUInteger previousCustomPresentation = 0;
    NSMutableArray<NSString *> *diagnostics = [NSMutableArray array];
    for (NSUInteger index = 0; index < phaseNames.count; index += 1) {
        NSDictionary *stockPhase = stockPhases[index];
        NSDictionary *customPhase = customPhases[index];
        [diagnostics addObject:[NSString stringWithFormat:@"phase=%@", phaseNames[index]]];
        for (NSString *key in topKeys) {
            [diagnostics addObject:[NSString stringWithFormat:
                @"top.%@ stock=%@ custom=%@ equal=%@", key, stockPhase[key],
                customPhase[key], [stockPhase[key] isEqual:customPhase[key]] ? @"YES" : @"NO"]];
        }
        NSDictionary *stockLifecycle = stockPhase[@"lifecycle"];
        NSDictionary *customLifecycle = customPhase[@"lifecycle"];
        for (NSString *key in lifecycleKeys) {
            [diagnostics addObject:[NSString stringWithFormat:
                @"lifecycle.%@ stock=%@ custom=%@ equal=%@", key,
                stockLifecycle[key], customLifecycle[key],
                [stockLifecycle[key] isEqual:customLifecycle[key]] ? @"YES" : @"NO"]];
        }
        for (NSDictionary *host in @[
            @{@"name": @"stock", @"phase": stockPhase, @"container": stockContainer},
            @{@"name": @"custom", @"phase": customPhase, @"container": customContainer}]) {
            NSDictionary *lifecycle = host[@"phase"][@"lifecycle"];
            BOOL assistant = [lifecycle[@"assistantSessionObject"] boolValue];
            BOOL display = [lifecycle[@"displaySessionObject"] boolValue];
            BOOL assistantToken = ![lifecycle[@"assistantSessionToken"] isEqualToString:@"nil"];
            BOOL displayToken = ![lifecycle[@"displaySessionToken"] isEqualToString:@"nil"];
            BOOL ownersMatch = assistant && display &&
                [lifecycle[@"assistantSessionToken"] isEqualToString:
                    lifecycle[@"displaySessionToken"]];
            NSSet *current = [NSSet setWithArray:lifecycle[@"recognizerIdentitySignature"]];
            NSSet *baseline = [NSSet setWithArray:
                lifecycle[@"recognizerBaselineIdentitySignature"]];
            BOOL recognizerRelation = current.count ==
                    [lifecycle[@"recognizerCount"] unsignedIntegerValue] &&
                baseline.count == [lifecycle[@"recognizerBaselineCount"] unsignedIntegerValue] &&
                [current isSubsetOfSet:baseline] &&
                [lifecycle[@"recognizerUnexpectedNewCount"] unsignedIntegerValue] == 0 &&
                [lifecycle[@"recognizerSubsetOfBaseline"] boolValue];
            BOOL sessionRelation = assistant == assistantToken && display == displayToken &&
                [lifecycle[@"sessionOwnersMatch"] boolValue] == ownersMatch;
            BOOL containerRelation = [lifecycle[@"containerToken"] isEqual:host[@"container"]];
            [diagnostics addObject:[NSString stringWithFormat:
                @"relation.%@ container=%@ session=%@ recognizer=%@", host[@"name"],
                containerRelation ? @"YES" : @"NO", sessionRelation ? @"YES" : @"NO",
                recognizerRelation ? @"YES" : @"NO"]];
        }
        NSUInteger stockPresentation = [stockPhase[@"presentationUpdates"] unsignedIntegerValue];
        NSUInteger customPresentation = [customPhase[@"presentationUpdates"] unsignedIntegerValue];
        [diagnostics addObject:[NSString stringWithFormat:
            @"presentation stock=%lu delta=%lu monotonic=%@ custom=%lu delta=%lu monotonic=%@ deltaParity=%@",
            (unsigned long)stockPresentation,
            (unsigned long)(stockPresentation - stockInitialPresentation),
            (index == 0 || stockPresentation >= previousStockPresentation) ? @"YES" : @"NO",
            (unsigned long)customPresentation,
            (unsigned long)(customPresentation - customInitialPresentation),
            (index == 0 || customPresentation >= previousCustomPresentation) ? @"YES" : @"NO",
            customPresentation - customInitialPresentation >=
                stockPresentation - stockInitialPresentation ? @"YES" : @"NO"]];
        previousStockPresentation = stockPresentation;
        previousCustomPresentation = customPresentation;
    }
    XCTAttachment *parityDiagnostics = [XCTAttachment attachmentWithString:
        [diagnostics componentsJoinedByString:@"\n"]];
    parityDiagnostics.name = [event stringByAppendingString:@"-paired-parity-diagnostics"];
    parityDiagnostics.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:parityDiagnostics];
    }
    NSArray<NSDictionary<NSString *, id> *> *stockSnapshots =
        @[stock.heldSnapshot, stock.terminalSnapshot, stock.immediateSnapshot,
          stock.exactSnapshot, stock.postLiftSnapshot];
    NSArray<NSDictionary<NSString *, id> *> *customSnapshots =
        @[custom.heldSnapshot, custom.terminalSnapshot,
          custom.immediateSnapshot, custom.exactSnapshot,
          custom.postLiftSnapshot];
    if (projectAutoscroll) {
        NSMutableArray *normalizedStock = [NSMutableArray array];
        NSMutableArray *normalizedCustom = [NSMutableArray array];
        for (NSArray *pair in @[stockSnapshots, customSnapshots]) {
            NSMutableArray *normalized = [NSMutableArray array];
            for (NSDictionary *snapshot in pair) {
                NSMutableDictionary *row = [snapshot mutableCopy];
                NSMutableDictionary *lifecycle =
                    [row[@"lifecycle"] mutableCopy];
                lifecycle[@"autoscrollObject"] = @NO;
                row[@"lifecycle"] = lifecycle.copy;
                NSMutableDictionary *retention =
                    [row[@"retention"] mutableCopy];
                retention[@"autoscrollRetained"] = @NO;
                row[@"retention"] = retention.copy;
                [normalized addObject:row.copy];
            }
            if (pair == stockSnapshots) {
                [normalizedStock addObjectsFromArray:normalized];
            } else {
                [normalizedCustom addObjectsFromArray:normalized];
            }
        }
        stockSnapshots = normalizedStock.copy;
        customSnapshots = normalizedCustom.copy;
    }
    XCTAssertTrue(IDFloatingCursorLifecyclePhasesHaveCompleteParity(
        stockSnapshots, customSnapshots, event));
    XCTAssertTrue(NSEqualRanges(stock.initial.selection, custom.initial.selection));
    XCTAssertTrue(NSEqualRanges(stock.held.selection, custom.held.selection));
    XCTAssertTrue(NSEqualRanges(stock.ended.selection, custom.ended.selection));
    XCTAssertTrue(NSEqualRanges(stock.immediate.selection, custom.immediate.selection));
    XCTAssertTrue(NSEqualRanges(stock.settled.selection, custom.settled.selection));
    XCTAssertTrue(NSEqualRanges(stock.quiesced.selection, custom.quiesced.selection));
    XCTAssertEqual(stock.initial.startAffinity, custom.initial.startAffinity);
    XCTAssertEqual(stock.initial.endAffinity, custom.initial.endAffinity);
    XCTAssertEqual(stock.held.startAffinity, custom.held.startAffinity);
    XCTAssertEqual(stock.held.endAffinity, custom.held.endAffinity);
    XCTAssertEqual(stock.ended.startAffinity, custom.ended.startAffinity);
    XCTAssertEqual(stock.ended.endAffinity, custom.ended.endAffinity);
    XCTAssertEqual(stock.immediate.startAffinity, custom.immediate.startAffinity);
    XCTAssertEqual(stock.immediate.endAffinity, custom.immediate.endAffinity);
    XCTAssertEqual(stock.settled.startAffinity, custom.settled.startAffinity);
    XCTAssertEqual(stock.settled.endAffinity, custom.settled.endAffinity);
    XCTAssertEqual(stock.quiesced.startAffinity, custom.quiesced.startAffinity);
    XCTAssertEqual(stock.quiesced.endAffinity, custom.quiesced.endAffinity);
    XCTAssertEqual(stock.initial.firstResponder, custom.initial.firstResponder);
    XCTAssertEqual(stock.held.firstResponder, custom.held.firstResponder);
    XCTAssertEqual(stock.ended.firstResponder, custom.ended.firstResponder);
    XCTAssertEqual(stock.immediate.firstResponder, custom.immediate.firstResponder);
    XCTAssertEqual(stock.settled.firstResponder, custom.settled.firstResponder);
    XCTAssertEqual(stock.quiesced.firstResponder, custom.quiesced.firstResponder);
    XCTAssertEqual(stock.initialKeyboardCount, custom.initialKeyboardCount);
    XCTAssertEqual(stock.heldKeyboardCount, custom.heldKeyboardCount);
    XCTAssertEqual(stock.endedKeyboardCount, custom.endedKeyboardCount);
    XCTAssertEqual(stock.immediateKeyboardCount, custom.immediateKeyboardCount);
    XCTAssertEqual(stock.settledKeyboardCount, custom.settledKeyboardCount);
    XCTAssertEqual(stock.quiescedKeyboardCount, custom.quiescedKeyboardCount);
    NSArray<NSValue *> *stockOffsets = @[
        [NSValue valueWithCGPoint:stock.initial.contentOffset],
        [NSValue valueWithCGPoint:stock.held.contentOffset],
        [NSValue valueWithCGPoint:stock.ended.contentOffset],
        [NSValue valueWithCGPoint:stock.immediate.contentOffset],
        [NSValue valueWithCGPoint:stock.settled.contentOffset],
        [NSValue valueWithCGPoint:stock.quiesced.contentOffset],
    ];
    NSArray<NSValue *> *customOffsets = @[
        [NSValue valueWithCGPoint:custom.initial.contentOffset],
        [NSValue valueWithCGPoint:custom.held.contentOffset],
        [NSValue valueWithCGPoint:custom.ended.contentOffset],
        [NSValue valueWithCGPoint:custom.immediate.contentOffset],
        [NSValue valueWithCGPoint:custom.settled.contentOffset],
        [NSValue valueWithCGPoint:custom.quiesced.contentOffset],
    ];
    XCTAssertEqualObjects(stockOffsets, customOffsets);
    XCTAssertEqual(stock.initial.containerCreations, custom.initial.containerCreations);
    XCTAssertEqual(stock.held.containerCreations, custom.held.containerCreations);
    XCTAssertEqual(stock.ended.containerCreations, custom.ended.containerCreations);
    XCTAssertEqual(stock.immediate.containerCreations, custom.immediate.containerCreations);
    XCTAssertEqual(stock.settled.containerCreations, custom.settled.containerCreations);
    XCTAssertEqual(stock.quiesced.containerCreations, custom.quiesced.containerCreations);
    XCTAssertEqual(stock.initial.containerStable, custom.initial.containerStable);
    XCTAssertEqual(stock.held.containerStable, custom.held.containerStable);
    NSArray<NSDictionary<NSString *, id> *> *stockPhases = @[
        stock.initialTrace, stock.heldTrace, stock.endedTrace, stock.immediateTrace,
        stock.settledTrace, stock.quiescedTrace,
    ];
    NSArray<NSDictionary<NSString *, id> *> *customPhases = @[
        custom.initialTrace, custom.heldTrace, custom.endedTrace, custom.immediateTrace,
        custom.settledTrace, custom.quiescedTrace,
    ];
    NSString *stockContainer = stock.initialTrace[@"containerToken"];
    NSString *customContainer = custom.initialTrace[@"containerToken"];
    NSArray<NSString *> *parityKeys = @[
        @"normalEndCount", @"windowDetachActionCount", @"windowDetachCount",
        @"resignActionCount", @"keyboardDismissActionCount",
        @"editableOffActionCount", @"selectableOffActionCount",
        @"responderLossCount", @"editableOffCount", @"selectableOffCount",
        @"startCount", @"cancelCount", @"editable", @"selectable",
        @"containerStable", @"containerSubviews",
        @"sessionObject", @"assistantSessionObject", @"displaySessionObject",
        @"sessionOwnersMatch",
        @"sessionActive", @"autoscrollObject", @"autoscrollActive",
    ];
    for (NSUInteger index = 0; index < stockPhases.count; index += 1) {
        NSDictionary *stockPhase = stockPhases[index];
        NSDictionary *customPhase = customPhases[index];
        XCTAssertEqualObjects(stockPhase[@"containerToken"], stockContainer,
                              @"stock phase=%lu", (unsigned long)index);
        XCTAssertEqualObjects(customPhase[@"containerToken"], customContainer,
                              @"custom phase=%lu", (unsigned long)index);
        for (NSString *key in parityKeys) {
            if (projectAutoscroll &&
                [key isEqualToString:@"autoscrollObject"]) {
                continue;
            }
            XCTAssertEqualObjects(stockPhase[key], customPhase[key],
                                  @"phase=%lu key=%@ stock=%@ custom=%@",
                                  (unsigned long)index, key, stockPhase[key], customPhase[key]);
        }
        if (projectAutoscroll) {
            XCTAssertFalse([customPhase[@"autoscrollObject"] boolValue]);
            if (index == 0) {
                XCTAssertFalse(
                    [stockPhase[@"autoscrollObject"] boolValue]);
            } else {
                XCTAssertTrue(
                    [stockPhase[@"autoscrollObject"] boolValue]);
            }
        }
        for (NSDictionary *phase in @[stockPhase, customPhase]) {
            BOOL assistantPresent = [phase[@"assistantSessionObject"] boolValue];
            BOOL displayPresent = [phase[@"displaySessionObject"] boolValue];
            XCTAssertEqual(assistantPresent,
                ![phase[@"assistantSessionToken"] isEqualToString:@"nil"]);
            XCTAssertEqual(displayPresent,
                ![phase[@"displaySessionToken"] isEqualToString:@"nil"]);
            XCTAssertEqual([phase[@"sessionOwnersMatch"] boolValue],
                assistantPresent && displayPresent &&
                [phase[@"assistantSessionToken"] isEqualToString:
                    phase[@"displaySessionToken"]]);
        }
        if (index > 0) {
            XCTAssertGreaterThanOrEqual(
                [stockPhase[@"presentationUpdates"] unsignedIntegerValue],
                [stockPhases[index - 1][@"presentationUpdates"] unsignedIntegerValue]);
            XCTAssertGreaterThanOrEqual(
                [customPhase[@"presentationUpdates"] unsignedIntegerValue],
                [customPhases[index - 1][@"presentationUpdates"] unsignedIntegerValue]);
        }
        NSUInteger stockPresentationDelta =
            [stockPhase[@"presentationUpdates"] unsignedIntegerValue] -
            [stock.initialTrace[@"presentationUpdates"] unsignedIntegerValue];
        NSUInteger customPresentationDelta =
            [customPhase[@"presentationUpdates"] unsignedIntegerValue] -
            [custom.initialTrace[@"presentationUpdates"] unsignedIntegerValue];
        XCTAssertGreaterThanOrEqual(customPresentationDelta, stockPresentationDelta,
            @"phase=%lu presentation relation", (unsigned long)index);
    }
    NSArray<NSDictionary *> *stockStored = @[
        stock.heldTrace, stock.endedTrace, stock.immediateTrace,
        stock.settledTrace, stock.quiescedTrace,
    ];
    NSArray<NSDictionary *> *customStored = @[
        custom.heldTrace, custom.endedTrace, custom.immediateTrace,
        custom.settledTrace, custom.quiescedTrace,
    ];
    for (NSUInteger index = 0; index < stockStored.count; index += 1) {
        NSDictionary *stockPhase = stockStored[index];
        NSDictionary *customPhase = customStored[index];
        for (NSDictionary *phase in @[stockPhase, customPhase]) {
            NSArray *baselineIdentities = phase[@"recognizerBaselineIdentitySignature"];
            NSArray *currentIdentities = phase[@"recognizerIdentitySignature"];
            NSSet *baseline = [NSSet setWithArray:baselineIdentities];
            NSSet *current = [NSSet setWithArray:currentIdentities];
            XCTAssertEqual([phase[@"recognizerUnexpectedNewCount"] unsignedIntegerValue], 0U);
            XCTAssertTrue([phase[@"recognizerSubsetOfBaseline"] boolValue]);
            XCTAssertEqual(current.count, currentIdentities.count);
            XCTAssertEqual(current.count, [phase[@"recognizerCount"] unsignedIntegerValue]);
            XCTAssertEqual(baseline.count, baselineIdentities.count);
            XCTAssertEqual(baseline.count,
                           [phase[@"recognizerBaselineCount"] unsignedIntegerValue]);
            XCTAssertEqual([phase[@"recognizerSignature"] count], current.count);
            XCTAssertTrue([current isSubsetOfSet:baseline]);
        }
        BOOL stockCountChanged = [stockPhase[@"recognizerCount"] unsignedIntegerValue] !=
            [stockStored[0][@"recognizerCount"] unsignedIntegerValue];
        BOOL customCountChanged = [customPhase[@"recognizerCount"] unsignedIntegerValue] !=
            [customStored[0][@"recognizerCount"] unsignedIntegerValue];
        XCTAssertEqual(stockCountChanged, customCountChanged);
        XCTAssertEqual(
            ![stockPhase[@"recognizerSignature"] isEqual:
                stockStored[0][@"recognizerSignature"]],
            ![customPhase[@"recognizerSignature"] isEqual:
                customStored[0][@"recognizerSignature"]]);
    }
    NSUInteger stockRemoved =
        [stock.heldTrace[@"recognizerBaselineCount"] unsignedIntegerValue] -
        [stock.settledTrace[@"recognizerCount"] unsignedIntegerValue];
    NSUInteger customRemoved =
        [custom.heldTrace[@"recognizerBaselineCount"] unsignedIntegerValue] -
        [custom.settledTrace[@"recognizerCount"] unsignedIntegerValue];
    XCTAssertEqual(stockRemoved > 0, customRemoved > 0);
    XCTAssertEqualObjects(stock.settledTrace[@"recognizerIdentitySignature"],
                          stock.quiescedTrace[@"recognizerIdentitySignature"]);
    XCTAssertEqualObjects(custom.settledTrace[@"recognizerIdentitySignature"],
                          custom.quiescedTrace[@"recognizerIdentitySignature"]);
    XCTAssertEqualObjects(stock.settledTrace[@"presentationUpdates"],
                          stock.quiescedTrace[@"presentationUpdates"]);
    XCTAssertEqualObjects(custom.settledTrace[@"presentationUpdates"],
                          custom.quiescedTrace[@"presentationUpdates"]);
    BOOL changesSelectionGestures = [event isEqualToString:@"editableOffAction"] ||
        [event isEqualToString:@"selectableOffAction"];
    if (changesSelectionGestures) {
        XCTAssertEqualObjects(stock.settledTrace[@"recognizerSignature"],
                              stock.quiescedTrace[@"recognizerSignature"]);
        XCTAssertEqualObjects(custom.settledTrace[@"recognizerSignature"],
                              custom.quiescedTrace[@"recognizerSignature"]);
    }
    NSString *countKey = [event stringByAppendingString:@"Count"];
    XCTAssertEqual([stock.settledTrace[countKey] unsignedIntegerValue], 1U);
    XCTAssertEqual([custom.settledTrace[countKey] unsignedIntegerValue], 1U);
    for (NSString *actionKey in @[@"resignActionCount", @"keyboardDismissActionCount",
                                  @"editableOffActionCount", @"selectableOffActionCount"]) {
        NSUInteger expected = [actionKey isEqualToString:countKey] ? 1U : 0U;
        XCTAssertEqual([stock.settledTrace[actionKey] unsignedIntegerValue], expected);
        XCTAssertEqual([custom.settledTrace[actionKey] unsignedIntegerValue], expected);
    }
}

- (void)testLifecycleInterruptionTimingRejectsActionAfterKeyboardLift {
    IDHIDFloatingLifecycleSchedule *schedule = [IDHIDFloatingLifecycleSchedule new];
    schedule.keyboardActivation = 0.55;
    schedule.heldCapture = 0.92;
    schedule.actionDown = 2.75;
    schedule.actionUp = 2.80;
    schedule.immediateCapture = 2.90;
    schedule.settledCapture = 3.30;
    schedule.keyboardLift = 2.70;
    schedule.postLiftCapture = 3.20;
    NSArray<IDHIDTouchPath *> *paths = nil;
    NSError *error = nil;
    XCTAssertFalse(IDHIDBuildFloatingLifecycleTouchPaths(
        CGPointMake(180, 760), CGPointMake(80, 171), schedule, &paths, &error));
    XCTAssertNil(paths);
    XCTAssertEqualObjects(error.domain, @"com.inputdec.tests.hid-events");
    XCTAssertTrue([error.localizedDescription containsString:@"actionUp must precede keyboardLift"]);
}

- (void)runPairedLifecycleAction:(NSString *)action {
    XCUIApplication *frameApplication = IDFloatingCursorLaunchCustom(self, @"floating-ltr");
    XCUIElement *frameEditor =
        [frameApplication descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    CGRect editorFrame = frameEditor.frame;
    CGPoint actionPoint = CGPointZero;
    CGRect customActionFrame = CGRectNull;
    NSString *event = @"resignAction";
    NSString *terminalEvent = @"responderLoss";
    NSString *actionIdentifier = @"floating-resign";
    if ([action isEqualToString:@"resign"]) {
        customActionFrame =
            [frameApplication descendantsMatchingType:XCUIElementTypeAny][@"floating-resign"].frame;
        actionPoint = IDFloatingCursorCenter(customActionFrame);
    } else if ([action isEqualToString:@"keyboard-dismiss"]) {
        actionIdentifier = @"floating-keyboard-dismiss";
        customActionFrame = [frameApplication descendantsMatchingType:XCUIElementTypeAny]
            [@"floating-keyboard-dismiss"].frame;
        actionPoint = IDFloatingCursorCenter(customActionFrame);
        event = @"keyboardDismissAction";
    } else if ([action isEqualToString:@"editable"]) {
        actionIdentifier = @"floating-editable-off";
        customActionFrame = [frameApplication descendantsMatchingType:XCUIElementTypeAny]
            [@"floating-editable-off"].frame;
        actionPoint = IDFloatingCursorCenter(customActionFrame);
        event = @"editableOffAction";
        terminalEvent = @"editableOff";
    } else {
        actionIdentifier = @"floating-selectable-off";
        customActionFrame = [frameApplication descendantsMatchingType:XCUIElementTypeAny]
            [@"floating-selectable-off"].frame;
        actionPoint = IDFloatingCursorCenter(customActionFrame);
        event = @"selectableOffAction";
        terminalEvent = @"selectableOff";
    }
    XCTAssertTrue(isfinite(actionPoint.x) && isfinite(actionPoint.y));
    [frameApplication terminate];
    XCUIApplication *stockApp = IDFloatingCursorLaunchStockWithTruthEvent(
        self, @"floating-ltr", editorFrame, terminalEvent, event);
    XCUIElement *stockAction =
        [stockApp descendantsMatchingType:XCUIElementTypeAny][actionIdentifier];
    XCTAssertTrue([stockAction waitForExistenceWithTimeout:4.0]);
    CGRect stockActionFrame = stockAction.frame;
    XCTAssertEqualWithAccuracy(CGRectGetMidX(stockActionFrame),
                               CGRectGetMidX(customActionFrame), 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMidY(stockActionFrame),
                               CGRectGetMidY(customActionFrame), 0.5);
    actionPoint = IDFloatingCursorCenter(stockActionFrame);
    IDFloatingCursorLifecycleRun *stock = [self
        runLifecycleApplication:stockApp
        editor:[stockApp descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"]
        status:[stockApp descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        truthHeldOnly:YES
        actionPoint:actionPoint name:[@"stock-" stringByAppendingString:action]];
    [self hydrateRun:stock fromStoredTruthInApplication:stockApp
        terminalEvent:terminalEvent];
    [stockApp terminate];
    XCUIApplication *customApp = IDFloatingCursorLaunchCustomWithTruthEvent(
        self, @"floating-ltr", terminalEvent, event);
    IDFloatingCursorLifecycleRun *custom = [self
        runLifecycleApplication:customApp
        editor:[customApp descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"]
        status:[customApp descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        truthHeldOnly:YES
        actionPoint:actionPoint name:[@"custom-" stringByAppendingString:action]];
    [self hydrateRun:custom fromStoredTruthInApplication:customApp
        terminalEvent:terminalEvent];
    [customApp terminate];
    [self assertLifecycleStock:stock custom:custom event:event
             projectAutoscroll:NO];
}

- (IDFloatingCursorLifecycleRun *)runNormalEndLifecycleApplication:
        (XCUIApplication *)application
        editor:(XCUIElement *)editor
        status:(XCUIElement *)statusElement
        truthHeldOnly:(BOOL)truthHeldOnly
        name:(NSString *)name {
    IDFloatingCursorLifecycleRun *run = [IDFloatingCursorLifecycleRun new];
    IDFloatingCursorStatus initial = {0};
    XCTAssertTrue(IDFloatingCursorWaitForStatus(statusElement, 4.0,
        ^BOOL(IDFloatingCursorStatus status) {
            return status.firstResponder && status.containerStable;
        }, &initial, NULL), @"status=%@", statusElement.value);
    run.initial = initial;
    run.initialTrace = IDFloatingCursorCopyLifecycle(statusElement.value);
    run.initialKeyboardCount = application.keyboards.count;
    CGRect spacebar = IDFloatingCursorSpacebarFrame(self, application);
    XCTAssertFalse(CGRectIsNull(spacebar));
    CGPoint center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    const NSTimeInterval heldOffset = 0.92;
    const NSTimeInterval liftOffset = 1.80;
    const NSTimeInterval settledOffset = liftOffset + 0.500;
    IDHIDTouchPath *path = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:center startOffset:0.0 waypoints:@[
            [IDHIDTouchWaypoint moveTo:center offset:0.55],
            [IDHIDTouchWaypoint moveTo:center offset:0.95],
            [IDHIDTouchWaypoint liftAtOffset:liftOffset],
        ]];
    __block BOOL heldParsed = NO;
    __block XCUIScreenshot *heldScreenshot = nil;
    dispatch_semaphore_t held = dispatch_semaphore_create(0);
    CFTimeInterval epoch = IDFloatingCursorMonotonicTime();
    run.epoch = epoch;
    run.keyboardLiftOffset = liftOffset;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (IDFloatingCursorMonotonicTime() < epoch + heldOffset)
            [NSThread sleepForTimeInterval:0.005];
        run.heldKeyboardCount = application.keyboards.count;
        id value = statusElement.value;
        IDFloatingCursorStatus heldStatus = {0};
        heldParsed = IDFloatingCursorParseStatus(value, &heldStatus);
        run.held = heldStatus;
        run.heldTrace = IDFloatingCursorCopyLifecycle(value);
        run.heldTime = IDFloatingCursorMonotonicTime();
        heldScreenshot = XCUIScreen.mainScreen.screenshot;
        dispatch_semaphore_signal(held);
    });
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, application, @[path], &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(held,
        dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0L);
    XCTAssertTrue(heldParsed);
    id endedValue = statusElement.value;
    IDFloatingCursorStatus endedStatus = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(endedValue, &endedStatus));
    run.ended = endedStatus;
    run.endedTrace = IDFloatingCursorCopyLifecycle(endedValue);
    run.endedKeyboardCount = application.keyboards.count;
    XCUIScreenshot *endedScreenshot = XCUIScreen.mainScreen.screenshot;
    id immediateValue = statusElement.value;
    IDFloatingCursorStatus immediateStatus = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(immediateValue, &immediateStatus));
    run.immediate = immediateStatus;
    run.immediateTrace = IDFloatingCursorCopyLifecycle(immediateValue);
    run.immediateKeyboardCount = application.keyboards.count;
    run.immediateTime = IDFloatingCursorMonotonicTime();
    XCUIScreenshot *immediateScreenshot = XCUIScreen.mainScreen.screenshot;
    while (IDFloatingCursorMonotonicTime() < epoch + settledOffset)
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    id settledValue = statusElement.value;
    IDFloatingCursorStatus settledStatus = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(settledValue, &settledStatus));
    run.settled = settledStatus;
    run.settledTrace = IDFloatingCursorCopyLifecycle(settledValue);
    run.settledKeyboardCount = application.keyboards.count;
    run.settledTime = IDFloatingCursorMonotonicTime();
    XCUIScreenshot *settledScreenshot = XCUIScreen.mainScreen.screenshot;
    id postLiftValue = statusElement.value;
    IDFloatingCursorStatus postLiftStatus = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(postLiftValue, &postLiftStatus));
    run.quiesced = postLiftStatus;
    run.quiescedTrace = IDFloatingCursorCopyLifecycle(postLiftValue);
    run.quiescedKeyboardCount = application.keyboards.count;
    XCUIScreenshot *postLiftScreenshot = XCUIScreen.mainScreen.screenshot;
    XCTAssertGreaterThan(run.heldKeyboardCount, 0U);
    XCTAssertTrue([run.heldTrace[@"assistantSessionObject"] boolValue]);
    XCTAssertTrue([run.heldTrace[@"displaySessionObject"] boolValue]);
    XCTAssertTrue([run.heldTrace[@"sessionOwnersMatch"] boolValue]);
    XCTAssertEqualObjects(run.heldTrace[@"assistantSessionToken"],
                          run.heldTrace[@"displaySessionToken"]);
    XCTAssertTrue([run.heldTrace[@"sessionActive"] boolValue]);
    XCTAssertFalse([run.endedTrace[@"assistantSessionObject"] boolValue]);
    XCTAssertTrue([run.endedTrace[@"displaySessionObject"] boolValue]);
    XCTAssertFalse([run.endedTrace[@"sessionActive"] boolValue]);
    XCTAssertFalse([run.endedTrace[@"autoscrollActive"] boolValue]);
    if (!truthHeldOnly)
        XCTAssertEqualWithAccuracy(run.settledTime - epoch, settledOffset, 0.08);
    XCTAssertEqual([run.settledTrace[@"normalEndCount"] unsignedIntegerValue], 1U);
    XCTAssertFalse([run.settledTrace[@"sessionActive"] boolValue]);
    XCTAssertFalse([run.settledTrace[@"autoscrollActive"] boolValue]);
    [self addScreenshot:heldScreenshot name:[name stringByAppendingString:@"-held"]];
    [self addScreenshot:endedScreenshot name:[name stringByAppendingString:@"-ended"]];
    [self addScreenshot:immediateScreenshot name:[name stringByAppendingString:@"-immediate"]];
    [self addScreenshot:settledScreenshot name:[name stringByAppendingString:@"-exact-500ms"]];
    [self addScreenshot:postLiftScreenshot name:[name stringByAppendingString:@"-post-lift-500ms"]];
    XCTAttachment *evidence = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
        @"held=%.3f ended=%.3f immediate=%.3f exact500=%.3f postLift500=%.3f lifecycle=%@",
        run.heldTime - epoch, liftOffset, run.immediateTime - epoch,
        run.settledTime - epoch, settledOffset, run.settledTrace]];
    evidence.name = [name stringByAppendingString:@"-normal-end-phases"];
    evidence.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:evidence];
    (void)editor;
    return run;
}

- (void)runFloatingCursorNormalEndComparisonMinimal:(BOOL)minimal {
    XCUIApplication *frameApplication = IDFloatingCursorLaunchCustom(self, @"floating-ltr");
    CGRect editorFrame =
        [frameApplication descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"].frame;
    [frameApplication terminate];
    XCUIApplication *stock = IDFloatingCursorLaunchStockWithTruthEvent(
        self, @"floating-ltr", editorFrame, @"normalEnd", nil);
    IDFloatingCursorLifecycleRun *stockRun = [self runNormalEndLifecycleApplication:stock
        editor:[stock descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"]
        status:[stock descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        truthHeldOnly:YES
        name:@"stock-normal-end"];
    [self hydrateRun:stockRun fromStoredTruthInApplication:stock
        terminalEvent:@"normalEnd"];
    [stock terminate];
    XCUIApplication *custom = IDFloatingCursorLaunchCustomWithTruthEvent(
        self, @"floating-ltr", @"normalEnd", nil);
    if (minimal) {
        custom = [self minimalApplicationFromCustom:custom];
    }
    IDFloatingCursorLifecycleRun *customRun = [self runNormalEndLifecycleApplication:custom
        editor:[custom descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"]
        status:[custom descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        truthHeldOnly:YES
        name:@"custom-normal-end"];
    [self hydrateRun:customRun fromStoredTruthInApplication:custom
        terminalEvent:@"normalEnd"];
    [self assertLifecycleStock:stockRun custom:customRun event:@"normalEnd"
             projectAutoscroll:minimal];
    [custom terminate];
}

- (void)testFloatingCursorNormalEndMatchesStockAndQuiesces {
    [self runFloatingCursorNormalEndComparisonMinimal:NO];
}

- (void)testMinimalFloatingCursorNormalEndMatchesStockAndQuiesces {
    [self runFloatingCursorNormalEndComparisonMinimal:YES];
}

- (void)testFloatingCursorResponderLossCancelsLikeStock {
    [self runPairedLifecycleAction:@"resign"];
}

- (void)testFloatingCursorKeyboardDismissalCancelsLikeStock {
    [self runPairedLifecycleAction:@"keyboard-dismiss"];
}

- (void)testFloatingCursorSelectableAndEditableTransitionsMatchStock {
    [self runPairedLifecycleAction:@"editable"];
    [self runPairedLifecycleAction:@"selectable"];
}

- (NSDictionary<NSString *, NSArray *> *)reconstructionTraceForApplication:
    (XCUIApplication *)application editorIdentifier:(NSString *)editorIdentifier {
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][editorIdentifier];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    XCUIElement *selectableOff =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-selectable-off"];
    XCUIElement *selectableOn =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-selectable-on"];
    XCTAssertTrue([selectableOff waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([selectableOn waitForExistenceWithTimeout:1.0]);
    CGPoint actionPoint = IDFloatingCursorCenter(selectableOff.frame);
    NSDictionary *initial = IDFloatingCursorCopyLifecycle(status.value);
    NSString *containerToken = initial[@"containerToken"];
    NSUInteger containerCreations = 1;
    NSMutableSet<NSString *> *sessionTokens = [NSMutableSet set];
    NSMutableArray<NSNumber *> *recognizerCounts = [NSMutableArray array];
    NSMutableArray<NSArray<NSString *> *> *recognizerClasses = [NSMutableArray array];
    for (NSUInteger cycle = 0; cycle < 3; cycle += 1) {
        IDFloatingCursorLifecycleRun *run = [self runLifecycleApplication:application
            editor:editor status:status truthHeldOnly:YES actionPoint:actionPoint
            name:[NSString stringWithFormat:@"selectable-reconstruction-%lu",
                  (unsigned long)cycle]];
        [self hydrateRun:run fromStoredTruthInApplication:application
            terminalEvent:@"selectableOff"];
        NSDictionary *held = run.heldSnapshot;
        NSDictionary *terminal = run.terminalSnapshot;
        NSDictionary *exact = run.exactSnapshot;
        NSDictionary *post = run.postLiftSnapshot;
        NSDictionary *heldLifecycle = held[@"lifecycle"];
        NSString *sessionToken = heldLifecycle[@"assistantSessionToken"];
        XCTAssertNotNil(sessionToken);
        XCTAssertNotEqualObjects(sessionToken, @"nil");
        if (sessionToken != nil && ![sessionToken isEqualToString:@"nil"]) {
            XCTAssertFalse([sessionTokens containsObject:sessionToken]);
            [sessionTokens addObject:sessionToken];
        }
        XCTAssertTrue([held[@"firstResponder"] boolValue]);
        XCTAssertTrue([held[@"keyboardVisible"] boolValue]);
        XCTAssertTrue([heldLifecycle[@"sessionActive"] boolValue]);
        XCTAssertLessThan([held[@"observation"][@"capturedAt"] doubleValue],
                          [terminal[@"observation"][@"actionEpoch"] doubleValue]);
        XCTAssertEqualObjects(heldLifecycle[@"containerToken"], containerToken);
        XCTAssertEqual([held[@"containerCreations"] unsignedIntegerValue],
                       containerCreations);
        NSSet *heldRecognizers = [NSSet setWithArray:
            heldLifecycle[@"recognizerIdentitySignature"]];
        NSSet *heldBaseline = [NSSet setWithArray:
            heldLifecycle[@"recognizerBaselineIdentitySignature"]];
        [recognizerCounts addObject:@(heldRecognizers.count)];
        [recognizerClasses addObject:[heldLifecycle[@"recognizerSignature"] copy]];
        XCTAssertEqual(heldRecognizers.count,
                       [heldLifecycle[@"recognizerCount"] unsignedIntegerValue]);
        XCTAssertTrue([heldRecognizers isSubsetOfSet:heldBaseline]);
        XCTAssertEqual([heldLifecycle[@"recognizerUnexpectedNewCount"] unsignedIntegerValue], 0U);
        for (NSDictionary *snapshot in @[exact, post]) {
            NSDictionary *phase = snapshot[@"lifecycle"];
            XCTAssertFalse([snapshot[@"retention"][@"sessionRetained"] boolValue]);
            for (NSString *key in @[@"assistantSessionObject", @"displaySessionObject",
                                     @"sessionObject", @"sessionOwnersMatch", @"sessionActive",
                                     @"autoscrollActive"]) {
                XCTAssertFalse([phase[key] boolValue], @"cycle=%lu key=%@",
                               (unsigned long)cycle, key);
            }
            XCTAssertEqualObjects(phase[@"containerToken"], containerToken);
            XCTAssertEqual([phase[@"recognizerUnexpectedNewCount"] unsignedIntegerValue], 0U);
            XCTAssertTrue([phase[@"recognizerSubsetOfBaseline"] boolValue]);
            NSArray *identities = phase[@"recognizerIdentitySignature"];
            NSSet *uniqueIdentities = [NSSet setWithArray:identities];
            XCTAssertEqual(uniqueIdentities.count, identities.count);
            XCTAssertTrue([uniqueIdentities isSubsetOfSet:heldBaseline]);
        }
        for (NSString *key in @[@"selectableOffActionCount", @"selectableOffCount",
                                 @"responderLossCount"]) {
            NSUInteger before = [run.initialTrace[key] unsignedIntegerValue];
            NSUInteger after = [run.quiescedTrace[key] unsignedIntegerValue];
            XCTAssertEqual(after, before + 1, @"cycle=%lu key=%@ before=%lu after=%lu",
                           (unsigned long)cycle, key, (unsigned long)before,
                           (unsigned long)after);
            XCTAssertEqual([run.endedTrace[key] unsignedIntegerValue], after);
            XCTAssertEqual([run.immediateTrace[key] unsignedIntegerValue], after);
            XCTAssertEqual([run.settledTrace[key] unsignedIntegerValue], after);
        }
        if (cycle + 1 < 3) {
            [selectableOn tap];
            IDFloatingCursorStatus restored = {0};
            XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 4.0,
                ^BOOL(IDFloatingCursorStatus value) { return value.firstResponder; },
                &restored, NULL));
        }
    }
    XCTAssertEqual(sessionTokens.count, 3U);
    return @{@"counts": recognizerCounts.copy, @"classes": recognizerClasses.copy};
}

- (void)testSelectableReconstructionRunsThreeLiveHIDSessionsWithoutGraphLeakage {
    XCUIApplication *custom = IDFloatingCursorLaunchCustomWithTruthEvent(
        self, @"floating-ltr", @"selectableOff", @"selectableOffAction");
    XCUIElement *customEditor =
        [custom descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    CGRect editorFrame = customEditor.frame;
    NSDictionary *customTrace = [self reconstructionTraceForApplication:custom
        editorIdentifier:@"block-text-view"];
    [custom terminate];

    XCUIApplication *stock = IDFloatingCursorLaunchStockWithTruthEvent(
        self, @"floating-ltr", editorFrame, @"selectableOff", @"selectableOffAction");
    NSDictionary *stockTrace = [self reconstructionTraceForApplication:stock
        editorIdentifier:@"stock-text-view"];
    [stock terminate];

    NSArray<NSNumber *> *customCounts = customTrace[@"counts"];
    NSArray<NSNumber *> *stockCounts = stockTrace[@"counts"];
    NSArray<NSArray<NSString *> *> *customClasses = customTrace[@"classes"];
    NSArray<NSArray<NSString *> *> *stockClasses = stockTrace[@"classes"];
    XCTAssertEqual(customCounts.count, 3U);
    XCTAssertEqual(stockCounts.count, 3U);
    for (NSUInteger cycle = 1; cycle < 3; cycle += 1) {
        NSInteger customDelta = customCounts[cycle].integerValue -
            customCounts[cycle - 1].integerValue;
        NSInteger stockDelta = stockCounts[cycle].integerValue -
            stockCounts[cycle - 1].integerValue;
        XCTAssertEqual(customDelta, stockDelta, @"cycle=%lu custom=%@ stock=%@",
                       (unsigned long)cycle, customCounts, stockCounts);
        BOOL customChanged = ![customClasses[cycle]
            isEqualToArray:customClasses[cycle - 1]];
        BOOL stockChanged = ![stockClasses[cycle]
            isEqualToArray:stockClasses[cycle - 1]];
        XCTAssertEqual(customChanged, stockChanged,
            @"cycle=%lu custom=%@ stock=%@", (unsigned long)cycle,
            customClasses, stockClasses);
    }
}

- (NSDictionary *)truthRowForAction:(NSString *)action editorFrame:(CGRect)editorFrame {
    BOOL releaseAttempt = [action hasPrefix:@"release-attempt-"];
    NSDictionary<NSString *, NSString *> *terminalEvents = @{
        @"normal-lift": @"normalEnd",
        @"responder-loss": @"responderLoss",
        @"keyboard-dismissal": @"responderLoss",
        @"window-detach": @"windowDetach",
        @"editable-off": @"editableOff",
        @"selectable-off": @"selectableOff",
        @"release-attempt-after-normal": @"normalEnd",
        @"release-attempt-after-interruption": @"responderLoss",
    };
    NSString *terminalEvent = terminalEvents[action];
    NSDictionary<NSString *, NSString *> *actionEvents = @{
        @"responder-loss": @"resignAction",
        @"keyboard-dismissal": @"keyboardDismissAction",
        @"window-detach": @"windowDetachAction",
        @"editable-off": @"editableOffAction",
        @"selectable-off": @"selectableOffAction",
        @"release-attempt-after-interruption": @"resignAction",
    };
    NSString *actionEvent = actionEvents[action];
    XCTAssertNotNil(terminalEvent);
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
    ];
    NSMutableDictionary<NSString *, NSString *> *environment = [@{
        @"IDStockEditorFrame": NSStringFromCGRect(editorFrame),
        @"IDStockTouchScenario": @"floating-ltr",
        @"IDStockTruthTerminalEvent": terminalEvent,
    } mutableCopy];
    if (actionEvent.length > 0) environment[@"IDStockTruthActionEvent"] = actionEvent;
    if (releaseAttempt) {
        environment[@"IDStockHideEditorFromAccessibility"] = @"1";
        environment[@"IDStockReleaseAttempt"] = [action isEqualToString:
            @"release-attempt-after-normal"] ? @"after-normal" : @"after-interruption";
    }
    application.launchEnvironment = environment;
    [application launch];
    XCUIElement *editor = releaseAttempt ? nil :
        [application descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    XCUIElement *terminalStatus =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-terminal-status"];
    XCUIElement *immediateReleaseStatus = [application descendantsMatchingType:XCUIElementTypeAny]
        [@"floating-release-immediate-status"];
    XCUIElement *heldReleaseStatus = [application descendantsMatchingType:XCUIElementTypeAny]
        [@"floating-release-held-status"];
    XCUIElement *exactReleaseStatus = [application descendantsMatchingType:XCUIElementTypeAny]
        [@"floating-release-exact-status"];
    XCUIElement *postLiftReleaseStatus = [application descendantsMatchingType:XCUIElementTypeAny]
        [@"floating-release-post-lift-status"];
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    BOOL normal = [action isEqualToString:@"normal-lift"] ||
        [action isEqualToString:@"release-attempt-after-normal"];
    IDFloatingCursorLifecycleRun *run = nil;
    if (normal) {
        run = [self runNormalEndLifecycleApplication:application editor:editor status:status
            truthHeldOnly:YES
            name:[@"truth-" stringByAppendingString:action]];
    } else {
        NSDictionary *identifiers = @{
            @"responder-loss": @"floating-resign",
            @"keyboard-dismissal": @"floating-keyboard-dismiss",
            @"window-detach": @"floating-window-detach",
            @"editable-off": @"floating-editable-off",
            @"selectable-off": @"floating-selectable-off",
            @"release-attempt-after-interruption": @"floating-resign",
        };
        XCUIElement *control = [application descendantsMatchingType:XCUIElementTypeAny]
            [identifiers[action]];
        XCTAssertTrue([control waitForExistenceWithTimeout:4.0]);
        run = [self runLifecycleApplication:application editor:editor status:status
            truthHeldOnly:YES
            actionPoint:IDFloatingCursorCenter(control.frame)
            name:[@"truth-" stringByAppendingString:action]];
    }
    NSDictionary *held = [self waitForAtomicTruthStatus:heldReleaseStatus];
    NSDictionary *terminal = [self waitForAtomicTruthStatus:terminalStatus];
    NSDictionary *immediate = [self waitForAtomicTruthStatus:immediateReleaseStatus];
    NSDictionary *exact500 = [self waitForAtomicTruthStatus:exactReleaseStatus];
    NSDictionary *postLift500 = [self waitForAtomicTruthStatus:postLiftReleaseStatus];
    NSDictionary *observation = immediate[@"observation"];
    XCTAssertEqualObjects(observation[@"terminalEvent"], terminalEvent);
    XCTAssertEqual([observation[@"terminalCountAtRelease"] unsignedIntegerValue], 1U);
    double releaseEpoch = [observation[@"releaseEpoch"] doubleValue];
    double actionEpoch = [observation[@"actionEpoch"] doubleValue];
    double terminalEpoch = [observation[@"terminalEpoch"] doubleValue];
    double liftTargetEpoch = [observation[@"liftTargetEpoch"] doubleValue];
    double baseEpoch = releaseAttempt ? releaseEpoch :
        (actionEpoch > 0 ? actionEpoch : terminalEpoch);
    XCTAssertGreaterThan(terminalEpoch, 0.0);
    if (releaseAttempt) XCTAssertGreaterThanOrEqual(releaseEpoch, terminalEpoch);
    else XCTAssertEqual(releaseEpoch, 0.0);
    if (actionEvent.length > 0) XCTAssertGreaterThan(actionEpoch, 0.0);
    else XCTAssertEqual(actionEpoch, 0.0);
    XCTAssertGreaterThanOrEqual([observation[@"capturedAt"] doubleValue], baseEpoch);
    XCTAssertEqualObjects(observation[@"phase"], @"immediate");
    XCTAssertEqualWithAccuracy(
        [exact500[@"observation"][@"captureTargetEpoch"] doubleValue],
        baseEpoch + 0.500, 0.001);
    XCTAssertEqualWithAccuracy(
        [exact500[@"observation"][@"capturedAt"] doubleValue] - baseEpoch,
        0.500, 0.08);
    XCTAssertEqualWithAccuracy(
        [postLift500[@"observation"][@"captureTargetEpoch"] doubleValue],
        liftTargetEpoch + 0.500, 0.001);
    XCTAssertEqualWithAccuracy(
        [postLift500[@"observation"][@"capturedAt"] doubleValue] - liftTargetEpoch,
        0.500, 0.08);
    XCTAssertEqualObjects(exact500[@"observation"][@"phase"], releaseAttempt
        ? @"exact-release-500ms" : (actionEpoch > 0
            ? @"exact-action-500ms" : @"exact-terminal-500ms"));
    XCTAssertEqualObjects(postLift500[@"observation"][@"phase"],
                          @"post-keyboard-lift-500ms");
    if (releaseAttempt) XCTAssertLessThanOrEqual(terminalEpoch, baseEpoch);
    else if (actionEpoch > 0) XCTAssertLessThanOrEqual(actionEpoch, terminalEpoch);
    else XCTAssertEqual(baseEpoch, terminalEpoch);
    XCTAssertLessThanOrEqual(baseEpoch,
        [immediate[@"observation"][@"capturedAt"] doubleValue]);
    XCTAssertLessThanOrEqual(
        [immediate[@"observation"][@"capturedAt"] doubleValue],
        [exact500[@"observation"][@"capturedAt"] doubleValue]);
    XCTAssertTrue([held[@"keyboardVisible"] boolValue]);
    XCTAssertTrue([held[@"firstResponder"] boolValue]);
    XCTAssertTrue([held[@"lifecycle"][@"sessionActive"] boolValue]);
    XCTAssertEqualObjects(held[@"observation"][@"phase"], @"held");
    XCTAssertEqual([held[@"observation"][@"releaseEpoch"] doubleValue], 0.0);
    XCTAssertEqual([held[@"observation"][@"terminalCountAtRelease"] unsignedIntegerValue], 0U);
    if ([action isEqualToString:@"selectable-off"]) {
        XCTAssertFalse([postLift500[@"retention"][@"assistantRetained"] boolValue]);
    }
    XCTAttachment *chronology = [XCTAttachment attachmentWithString:
        [NSString stringWithFormat:@"held=%@ terminal=%@ immediate=%@ exact=%@ postLift=%@",
         held[@"observation"], terminal[@"observation"], immediate[@"observation"],
         exact500[@"observation"], postLift500[@"observation"]]];
    chronology.name = [action stringByAppendingString:@"-atomic-chronology"];
    chronology.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:chronology];
    NSDictionary *ended = terminal;
    for (NSDictionary *snapshot in @[held, ended, immediate, exact500, postLift500])
        XCTAssertTrue(IDFloatingCursorTruthSnapshotIsAtomic(snapshot), @"%@", snapshot);
    XCTAssertTrue(IDFloatingCursorTruthPhasesHaveValidChronology(
        @[held, ended, immediate, exact500, postLift500], releaseAttempt));
    [application terminate];
    return @{@"action": action, @"held": held, @"ended": ended,
             @"immediate": immediate, @"exact500ms": exact500,
             @"postLift500ms": postLift500};
}

- (void)testStockHostedFloatingLifecycleTruthTableHasExactRowsPhasesAndSchema {
    XCUIApplication *frameApplication = IDFloatingCursorLaunchCustom(self, @"floating-ltr");
    CGRect editorFrame =
        [frameApplication descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"].frame;
    [frameApplication terminate];
    NSArray *actions = @[@"normal-lift", @"responder-loss", @"keyboard-dismissal",
        @"window-detach", @"editable-off", @"selectable-off",
        @"release-attempt-after-normal", @"release-attempt-after-interruption"];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *action in actions) {
        [rows addObject:[self truthRowForAction:action editorFrame:editorFrame]];
    }
    NSSet *rowKeys = [NSSet setWithArray:@[@"action", @"held", @"ended", @"immediate",
                                            @"exact500ms", @"postLift500ms"]];
    NSSet *snapshotKeys = [NSSet setWithArray:@[@"selection", @"startAffinity",
        @"endAffinity", @"firstResponder", @"keyboardVisible", @"containerCreations",
        @"containerStable", @"presentationUpdates", @"contentOffset", @"lifecycle",
        @"retention", @"observation"]];
    NSSet *retentionKeys = [NSSet setWithArray:@[@"editorRetained", @"assistantRetained",
        @"containerRetained", @"sessionRetained", @"autoscrollRetained"]];
    NSSet *observationKeys = [NSSet setWithArray:@[@"source", @"sequence",
        @"lifecycleSequence", @"retentionSequence", @"capturedAt", @"actionEpoch",
        @"releaseEpoch",
        @"terminalEpoch", @"liftTargetEpoch", @"captureTargetEpoch", @"phase",
        @"terminalEvent", @"terminalCountAtRelease"]];
    NSSet *lifecycleKeys = [NSSet setWithArray:@[
        @"normalEndCount", @"windowDetachActionCount", @"windowDetachCount",
        @"resignActionCount", @"keyboardDismissActionCount",
        @"editableOffActionCount", @"selectableOffActionCount", @"responderLossCount",
        @"editableOffCount", @"selectableOffCount", @"startCount", @"cancelCount",
        @"editable", @"selectable", @"presentationUpdates", @"containerToken",
        @"containerStable", @"containerSubviews", @"sessionObject",
        @"assistantSessionObject", @"displaySessionObject", @"sessionOwnersMatch",
        @"assistantSessionToken", @"displaySessionToken", @"sessionActive",
        @"autoscrollObject", @"autoscrollActive", @"recognizerCount",
        @"recognizerBaselineCount", @"recognizerUnexpectedNewCount",
        @"recognizerSubsetOfBaseline", @"recognizerBaselineIdentitySignature",
        @"recognizerIdentitySignature", @"recognizerSignature", @"startAffinity",
        @"endAffinity"]];
    XCTAssertEqualObjects([rows valueForKey:@"action"], actions);
    for (NSDictionary *row in rows) {
        XCTAssertEqualObjects([NSSet setWithArray:row.allKeys], rowKeys);
        for (NSString *phase in @[@"held", @"ended", @"immediate", @"exact500ms",
                                   @"postLift500ms"]) {
            NSDictionary *snapshot = row[phase];
            XCTAssertEqualObjects([NSSet setWithArray:snapshot.allKeys], snapshotKeys);
            XCTAssertEqualObjects([NSSet setWithArray:[snapshot[@"retention"] allKeys]],
                                  retentionKeys);
            XCTAssertEqualObjects([NSSet setWithArray:[snapshot[@"lifecycle"] allKeys]],
                                  lifecycleKeys);
            NSDictionary *observation = snapshot[@"observation"];
            XCTAssertEqualObjects([NSSet setWithArray:observation.allKeys], observationKeys);
            XCTAssertEqualObjects(observation[@"source"],
                                  @"app-side-weak-reference-snapshot");
            XCTAssertEqualObjects(observation[@"sequence"],
                                  observation[@"lifecycleSequence"]);
            XCTAssertEqualObjects(observation[@"sequence"],
                                  observation[@"retentionSequence"]);
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:rows
        options:NSJSONWritingPrettyPrinted error:nil];
    XCTAttachment *attachment = [XCTAttachment attachmentWithData:data
        uniformTypeIdentifier:@"public.json"];
    attachment.name = @"stock-hosted-floating-lifecycle-truth-table.json";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testStockHostedReleaseAttemptAfterNormalCapturesObservedRetentionTruth {
    NSDictionary *row = [self truthRowForAction:@"release-attempt-after-normal"
        editorFrame:CGRectMake(16, 198, 370, 333)];
    XCTAssertEqualObjects(row[@"postLift500ms"][@"retention"], (@{
        @"editorRetained": @YES, @"assistantRetained": @YES,
        @"containerRetained": @YES, @"sessionRetained": @NO,
        @"autoscrollRetained": @YES,
    }));
}

- (void)testStockHostedResponderLossUsesAtomicStoredTruth {
    NSDictionary *row = [self truthRowForAction:@"responder-loss"
        editorFrame:CGRectMake(16, 198, 370, 333)];
    XCTAssertEqualObjects(row[@"ended"][@"observation"][@"terminalEvent"],
                          @"responderLoss");
    XCTAssertEqual([row[@"ended"][@"observation"][@"terminalCountAtRelease"]
        unsignedIntegerValue], 1U);
    XCTAssertEqual([row[@"ended"][@"observation"][@"releaseEpoch"] doubleValue], 0.0);
}

- (void)testStockHostedReleaseAttemptAfterInterruptionCapturesObservedRetentionTruth {
    NSDictionary *row = [self truthRowForAction:@"release-attempt-after-interruption"
        editorFrame:CGRectMake(16, 198, 370, 333)];
    XCTAssertEqualObjects(row[@"postLift500ms"][@"retention"], (@{
        @"editorRetained": @YES, @"assistantRetained": @YES,
        @"containerRetained": @YES, @"sessionRetained": @YES,
        @"autoscrollRetained": @YES,
    }));
}

- (IDFloatingCursorEndpointRole)roleForRange:(NSRange)range
                                 fixedOffset:(NSUInteger)fixedOffset {
    if (range.location == fixedOffset) return IDFloatingCursorEndpointRoleStart;
    if (range.location <= NSUIntegerMax - range.length &&
        NSMaxRange(range) == fixedOffset) return IDFloatingCursorEndpointRoleEnd;
    return IDFloatingCursorEndpointRoleUnknown;
}

- (BOOL)range:(NSRange)range preservesLogicalAnchor:(NSUInteger)anchor {
    return range.location <= NSUIntegerMax - range.length &&
        range.location <= anchor && anchor <= NSMaxRange(range);
}

- (IDFloatingCursorEndpointRole)sharedRoleForRange:(NSRange)first
                                             range:(NSRange)second
                                            offset:(NSUInteger *)offset {
    if (first.location == second.location) {
        if (offset != NULL) *offset = first.location;
        return IDFloatingCursorEndpointRoleStart;
    }
    if (first.location <= NSUIntegerMax - first.length &&
        second.location <= NSUIntegerMax - second.length &&
        NSMaxRange(first) == NSMaxRange(second)) {
        if (offset != NULL) *offset = NSMaxRange(first);
        return IDFloatingCursorEndpointRoleEnd;
    }
    return IDFloatingCursorEndpointRoleUnknown;
}

- (NSUInteger)firstNonemptySampleIndexInTrace:(IDFloatingCursorSelectionTrace *)trace {
    for (NSUInteger index = 0; index < trace.samples.count; index += 1) {
        if (trace.samples[index].status.selection.length > 0) return index;
    }
    return NSNotFound;
}

- (IDFloatingCursorSelectionTrace *)runSelectionExtensionApplication:
        (XCUIApplication *)application
                                                           editor:(XCUIElement *)editor
                                                           status:(XCUIElement *)status
                                                             host:(NSString *)host {
    IDFloatingCursorSelectionTrace *trace = [IDFloatingCursorSelectionTrace new];
    trace.editorFrame = editor.frame;
    IDFloatingCursorStatus initial = {0};
    NSString *canonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 4.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.firstResponder && sample.selection.location == 46 &&
                sample.selection.length == 0;
        }, &initial, &canonical), @"status=%@", status.value);
    trace.initial = initial;
    trace.canonical = canonical;
    XCTAssertNotNil(canonical);

    CGRect spacebar = IDFloatingCursorSpacebarFrame(self, application);
    XCTAssertFalse(CGRectIsNull(spacebar));
    if (CGRectIsNull(spacebar)) return trace;
    CGPoint center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    CGPoint secondaryStartPoint = CGPointMake(
        center.x - MIN(60.0, CGRectGetWidth(spacebar) * 0.25), center.y);
    CGPoint secondaryHeldPoint = secondaryStartPoint;
    CGPoint firstPrimaryPoint = CGPointMake(center.x - 48.0, center.y);
    CGPoint secondPrimaryPoint = CGPointMake(center.x + 52.0, center.y);
    NSTimeInterval primaryActivationOffset = 0.55;
    NSTimeInterval firstMoveOffset = 2.40;
    NSTimeInterval secondMoveOffset = 8.40;
    NSTimeInterval primaryLiftOffset = 9.80;
    NSTimeInterval secondaryDownOffset = 0.85;
    NSTimeInterval secondaryHeldOffset = 9.20;
    NSTimeInterval secondaryLiftOffset = 9.50;
    IDHIDTouchPath *spacebarPath = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:center
                     startOffset:0.0
                       waypoints:@[
            [IDHIDTouchWaypoint moveTo:center offset:primaryActivationOffset],
            [IDHIDTouchWaypoint moveTo:firstPrimaryPoint offset:firstMoveOffset],
            [IDHIDTouchWaypoint moveTo:secondPrimaryPoint offset:secondMoveOffset],
            [IDHIDTouchWaypoint liftAtOffset:primaryLiftOffset],
        ]];
    IDHIDTouchPath *extensionPath = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:secondaryStartPoint
                     startOffset:secondaryDownOffset
                       waypoints:@[
            [IDHIDTouchWaypoint moveTo:secondaryHeldPoint offset:secondaryHeldOffset],
            [IDHIDTouchWaypoint liftAtOffset:secondaryLiftOffset],
        ]];

    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:
            @"spacebar=%@ primary(id=path-0) start=%@ down=0.000 activation=0.550 "
             "secondary(id=path-1) start=%@ down=0.850 held=9.200 lift=9.500 "
             "primaryPoints={first=%@ @2.400,second=%@ @8.400,lift=9.800} "
             "initial=%@ canonicalLength=%lu",
            NSStringFromCGRect(spacebar), NSStringFromCGPoint(center),
            NSStringFromCGPoint(secondaryStartPoint),
            NSStringFromCGPoint(firstPrimaryPoint),
            NSStringFromCGPoint(secondPrimaryPoint),
            NSStringFromRange(initial.selection), (unsigned long)canonical.length]];
    NSMutableArray<IDFloatingCursorSelectionSample *> *samples = [NSMutableArray array];
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    CFTimeInterval epoch = CACurrentMediaTime();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<NSNumber *> *offsets = @[
            @0.70, @1.05, @1.55, @2.55, @3.55, @4.55, @5.55, @6.55, @7.55, @8.55,
        ];
        for (NSNumber *number in offsets) {
            while (CACurrentMediaTime() < epoch + number.doubleValue)
                [NSThread sleepForTimeInterval:0.005];
            id value = status.value;
            IDFloatingCursorSelectionSample *sample =
                [IDFloatingCursorSelectionSample new];
            sample.requestedOffset = number.doubleValue;
            IDFloatingCursorStatus parsedStatus = {0};
            sample.parsed = IDFloatingCursorParseStatus(value, &parsedStatus);
            sample.status = parsedStatus;
            sample.canonical = IDFloatingCursorCopyCanonical(value);
            sample.cursorCallback = IDFloatingCursorCopyCursorCallback(value);
            sample.captureOffset = CACurrentMediaTime() - epoch;
            if ([number isEqualToNumber:@1.55] || [number isEqualToNumber:@4.55] ||
                [number isEqualToNumber:@7.55]) {
                sample.screenshot = XCUIScreen.mainScreen.screenshot;
            }
            @synchronized (rows) {
                [rows addObject:[NSString stringWithFormat:
                    @"t=%.3f requested=%.3f selection=%@ parsed=%@ "
                     "observableModifier=none canonicalUnchanged=%@",
                    sample.captureOffset, number.doubleValue,
                    NSStringFromRange(sample.status.selection),
                    sample.parsed ? @"YES" : @"NO",
                    [sample.canonical isEqualToString:canonical]
                        ? @"YES" : @"NO"]];
                [samples addObject:sample];
            }
        }
        dispatch_semaphore_signal(finished);
    });
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, application,
                                            @[spacebarPath, extensionPath], &error),
                  @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(finished,
        dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)), 0L);
    trace.samples = samples.copy;
    XCTAssertEqual(trace.samples.count, 10U);
    for (NSUInteger index = 0; index < trace.samples.count; index += 1) {
        IDFloatingCursorSelectionSample *sample = trace.samples[index];
        XCTAssertTrue(sample.parsed, @"host=%@ index=%lu", host, (unsigned long)index);
        XCTAssertLessThan(sample.captureOffset, primaryLiftOffset);
        XCTAssertEqualObjects(sample.canonical, canonical);
        if (sample.screenshot != nil) {
            [self addScreenshot:sample.screenshot name:[NSString stringWithFormat:
                @"%@-selection-extension-prelift-%lu", host, (unsigned long)index]];
        }
    }
    IDFloatingCursorStatus ended = {0};
    NSString *endedCanonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 3.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.selection.length > 0 && sample.containerStable;
        }, &ended, &endedCanonical), @"host=%@ status=%@", host, status.value);
    trace.ended = ended;
    XCTAssertEqualObjects(endedCanonical, canonical);
    [NSThread sleepForTimeInterval:0.5];
    IDFloatingCursorStatus quiesced = {0};
    id quiescedValue = status.value;
    XCTAssertTrue(IDFloatingCursorParseStatus(quiescedValue, &quiesced));
    trace.quiesced = quiesced;
    XCTAssertEqualObjects(IDFloatingCursorCopyCanonical(quiescedValue), canonical);
    XCTAssertTrue(NSEqualRanges(ended.selection, quiesced.selection));
    XCTAssertTrue(quiesced.containerStable);
    XCTAttachment *traceAttachment =
        [XCTAttachment attachmentWithString:[rows componentsJoinedByString:@"\n"]];
    traceAttachment.name = [host stringByAppendingString:@"-selection-extension-trace"];
    traceAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:traceAttachment];
    [self addScreenshot:XCUIScreen.mainScreen.screenshot
                   name:[host stringByAppendingString:@"-selection-extension-ended"]];
    return trace;
}

- (NSArray<IDFloatingCursorSelectionTrace *> *)
    stockAndCustomSelectionExtensionTracesMinimal:(BOOL)minimal {
    XCUIApplication *frameApplication = IDFloatingCursorLaunchCustom(self, @"floating-ltr");
    XCUIElement *frameEditor =
        [frameApplication descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    CGRect editorFrame = frameEditor.frame;
    [frameApplication terminate];

    XCUIApplication *stock = IDFloatingCursorLaunchStock(self, @"floating-ltr", editorFrame);
    IDFloatingCursorSelectionTrace *stockTrace = [self
        runSelectionExtensionApplication:stock
        editor:[stock descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"]
        status:[stock descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        host:@"stock"];
    [stock terminate];

    XCUIApplication *custom = IDFloatingCursorLaunchCustom(self, @"floating-ltr");
    if (minimal) {
        custom = [self minimalApplicationFromCustom:custom];
    }
    IDFloatingCursorSelectionTrace *customTrace = [self
        runSelectionExtensionApplication:custom
        editor:[custom descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"]
        status:[custom descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        host:@"custom"];
    [custom terminate];
    return @[stockTrace, customTrace];
}

- (NSArray<IDFloatingCursorSelectionTrace *> *)
    stockAndCustomSelectionExtensionTraces {
    return [self stockAndCustomSelectionExtensionTracesMinimal:NO];
}

- (IDFloatingCursorSelectionTrace *)runTask4SelectionApplication:
        (XCUIApplication *)application
                                                        editor:(XCUIElement *)editor
                                                        status:(XCUIElement *)status
                                                          host:(NSString *)host
                                                      scenario:(NSString *)scenario
                                                 initialOffset:(NSUInteger)initialOffset
                                                        deltas:(NSArray<NSValue *> *)deltas {
    XCTAssertEqual(deltas.count, 3U);
    IDFloatingCursorSelectionTrace *trace = [IDFloatingCursorSelectionTrace new];
    trace.editorFrame = editor.frame;
    IDFloatingCursorStatus initial = {0};
    NSString *canonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 4.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.firstResponder && sample.selection.location == initialOffset &&
                sample.selection.length == 0;
        }, &initial, &canonical), @"host=%@ status=%@", host, status.value);
    trace.initial = initial;
    trace.canonical = canonical;
    XCTAssertNotNil(canonical);

    CGRect spacebar = IDFloatingCursorSpacebarFrame(self, application);
    XCTAssertFalse(CGRectIsNull(spacebar));
    if (CGRectIsNull(spacebar)) return trace;
    CGPoint center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    CGPoint secondary = CGPointMake(
        center.x - MIN(60.0, CGRectGetWidth(spacebar) * 0.25), center.y);
    NSMutableArray<IDHIDTouchWaypoint *> *primaryWaypoints = [NSMutableArray arrayWithArray:@[
        [IDHIDTouchWaypoint moveTo:center offset:0.55],
    ]];
    NSArray<NSNumber *> *moveOffsets = @[@2.40, @5.00, @7.80];
    NSArray<NSNumber *> *holdOffsets = @[@4.00, @7.00, @9.20];
    for (NSUInteger index = 0; index < deltas.count; index += 1) {
        CGPoint delta = deltas[index].CGPointValue;
        CGPoint destination = CGPointMake(center.x + delta.x, center.y + delta.y);
        if ([scenario isEqualToString:@"floating-bidi"] && index == 1) {
            CGPoint prior = deltas[0].CGPointValue;
            for (NSUInteger step = 1; step <= 4; step += 1) {
                CGFloat fraction = (CGFloat)step / 4.0;
                CGPoint subdivided = CGPointMake(
                    center.x + prior.x + (delta.x - prior.x) * fraction,
                    center.y + prior.y + (delta.y - prior.y) * fraction);
                [primaryWaypoints addObject:[IDHIDTouchWaypoint
                    moveTo:subdivided offset:4.0 + 0.5 * step]];
            }
        } else {
            [primaryWaypoints addObject:[IDHIDTouchWaypoint
                moveTo:destination offset:moveOffsets[index].doubleValue]];
        }
        [primaryWaypoints addObject:[IDHIDTouchWaypoint
            moveTo:destination offset:holdOffsets[index].doubleValue]];
    }
    [primaryWaypoints addObject:[IDHIDTouchWaypoint liftAtOffset:9.80]];
    IDHIDTouchPath *primary = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:center startOffset:0.0 waypoints:primaryWaypoints];
    IDHIDTouchPath *extension = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:secondary startOffset:0.85 waypoints:@[
            [IDHIDTouchWaypoint moveTo:secondary offset:9.20],
            [IDHIDTouchWaypoint liftAtOffset:9.50],
        ]];

    NSMutableArray<IDFloatingCursorSelectionSample *> *samples = [NSMutableArray array];
    NSMutableArray<NSString *> *rows = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"host=%@ scenario=%@ initial=%@ "
         "initialAffinities={%ld,%ld} initialCaret=%@ canonicalLength=%lu "
         "spacebar=%@ primary=%@ secondary=%@ deltas=%@",
         host, scenario, NSStringFromRange(initial.selection),
         (long)initial.startAffinity, (long)initial.endAffinity,
         NSStringFromCGRect(initial.caret),
         (unsigned long)canonical.length, NSStringFromCGRect(spacebar),
         NSStringFromCGPoint(center), NSStringFromCGPoint(secondary), deltas]];
    NSArray<NSNumber *> *captureOffsets = @[@3.50, @6.50, @8.80];
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    CFTimeInterval epoch = CACurrentMediaTime();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (NSUInteger index = 0; index < captureOffsets.count; index += 1) {
            NSNumber *requested = captureOffsets[index];
            while (CACurrentMediaTime() < epoch + requested.doubleValue)
                [NSThread sleepForTimeInterval:0.005];
            id value = status.value;
            IDFloatingCursorSelectionSample *sample =
                [IDFloatingCursorSelectionSample new];
            sample.requestedOffset = requested.doubleValue;
            sample.captureOffset = CACurrentMediaTime() - epoch;
            IDFloatingCursorStatus parsed = {0};
            sample.parsed = IDFloatingCursorParseStatus(value, &parsed);
            sample.status = parsed;
            sample.canonical = IDFloatingCursorCopyCanonical(value);
            sample.cursorCallback = IDFloatingCursorCopyCursorCallback(value);
            sample.screenshot = XCUIScreen.mainScreen.screenshot;
            @synchronized (samples) {
                [samples addObject:sample];
                [rows addObject:[NSString stringWithFormat:
                    @"phase=%lu t=%.3f selection=%@ affinities={%ld,%ld} "
                     "canonicalUnchanged=%@ cursorCallback=%@",
                    (unsigned long)index, sample.captureOffset,
                    NSStringFromRange(parsed.selection), (long)parsed.startAffinity,
                    (long)parsed.endAffinity,
                    [sample.canonical isEqualToString:canonical] ? @"YES" : @"NO",
                    sample.cursorCallback ?: @"none"]];
            }
        }
        dispatch_semaphore_signal(finished);
    });
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, application,
                                            @[primary, extension], &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(finished,
        dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)), 0L);
    trace.samples = samples.copy;
    XCTAssertEqual(trace.samples.count, captureOffsets.count);
    for (NSUInteger index = 0; index < trace.samples.count; index += 1) {
        IDFloatingCursorSelectionSample *sample = trace.samples[index];
        XCTAssertTrue(sample.parsed, @"host=%@ phase=%lu", host, (unsigned long)index);
        XCTAssertLessThan(sample.captureOffset, 9.80);
        XCTAssertEqualObjects(sample.canonical, canonical);
        [self addScreenshot:sample.screenshot name:[NSString stringWithFormat:
            @"%@-%@-phase-%lu", host, scenario, (unsigned long)index]];
    }
    IDFloatingCursorStatus ended = {0};
    NSString *endedCanonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 3.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.containerStable && sample.selection.length > 0;
        }, &ended, &endedCanonical), @"host=%@ status=%@", host, status.value);
    trace.ended = ended;
    XCTAssertEqualObjects(endedCanonical, canonical);
    [NSThread sleepForTimeInterval:0.5];
    IDFloatingCursorStatus quiesced = {0};
    id quiescedValue = status.value;
    XCTAssertTrue(IDFloatingCursorParseStatus(quiescedValue, &quiesced));
    trace.quiesced = quiesced;
    XCTAssertEqualObjects(IDFloatingCursorCopyCanonical(quiescedValue), canonical);
    XCTAssertTrue(NSEqualRanges(ended.selection, quiesced.selection));
    XCTAttachment *attachment =
        [XCTAttachment attachmentWithString:[rows componentsJoinedByString:@"\n"]];
    attachment.name = [NSString stringWithFormat:@"%@-%@-phase-trace", host, scenario];
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
    return trace;
}

- (NSArray<IDFloatingCursorSelectionTrace *> *)task4TracesForScenario:(NSString *)scenario
                                                        initialOffset:(NSUInteger)initialOffset
                                                               deltas:(NSArray<NSValue *> *)deltas {
    XCUIApplication *frameApplication = IDFloatingCursorLaunchCustom(self, scenario);
    XCUIElement *frameEditor =
        [frameApplication descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    CGRect editorFrame = frameEditor.frame;
    [frameApplication terminate];

    XCUIApplication *stock = IDFloatingCursorLaunchStock(self, scenario, editorFrame);
    IDFloatingCursorSelectionTrace *stockTrace = [self
        runTask4SelectionApplication:stock
        editor:[stock descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"]
        status:[stock descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        host:@"stock" scenario:scenario initialOffset:initialOffset deltas:deltas];
    [stock terminate];
    XCUIApplication *custom = IDFloatingCursorLaunchCustom(self, scenario);
    IDFloatingCursorSelectionTrace *customTrace = [self
        runTask4SelectionApplication:custom
        editor:[custom descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"]
        status:[custom descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        host:@"custom" scenario:scenario initialOffset:initialOffset deltas:deltas];
    [custom terminate];
    return @[stockTrace, customTrace];
}

- (void)assertTask4Trace:(IDFloatingCursorSelectionTrace *)custom
             equalsStock:(IDFloatingCursorSelectionTrace *)stock {
    XCTAssertEqualObjects(custom.canonical, stock.canonical);
    XCTAssertTrue(NSEqualRanges(custom.initial.selection, stock.initial.selection));
    XCTAssertEqual(custom.initial.startAffinity, stock.initial.startAffinity);
    XCTAssertEqual(custom.initial.endAffinity, stock.initial.endAffinity);
    XCTAssertEqualWithAccuracy(custom.initial.caret.origin.x, stock.initial.caret.origin.x, 0.5);
    XCTAssertEqualWithAccuracy(custom.initial.caret.origin.y, stock.initial.caret.origin.y, 0.5);
    XCTAssertEqualWithAccuracy(custom.initial.caret.size.width, stock.initial.caret.size.width, 0.5);
    XCTAssertEqualWithAccuracy(custom.initial.caret.size.height, stock.initial.caret.size.height, 0.5);
    XCTAssertEqual(custom.samples.count, stock.samples.count);
    for (NSUInteger index = 0; index < stock.samples.count; index += 1) {
        IDFloatingCursorStatus expected = stock.samples[index].status;
        IDFloatingCursorStatus actual = custom.samples[index].status;
        XCTAssertTrue(NSEqualRanges(actual.selection, expected.selection),
                      @"phase=%lu stock=%@ custom=%@", (unsigned long)index,
                      NSStringFromRange(expected.selection), NSStringFromRange(actual.selection));
        XCTAssertEqual(actual.startAffinity, expected.startAffinity,
                       @"phase=%lu", (unsigned long)index);
        XCTAssertEqual(actual.endAffinity, expected.endAffinity,
                       @"phase=%lu", (unsigned long)index);
    }
    XCTAssertTrue(NSEqualRanges(custom.ended.selection, stock.ended.selection));
    XCTAssertEqual(custom.ended.startAffinity, stock.ended.startAffinity);
    XCTAssertEqual(custom.ended.endAffinity, stock.ended.endAffinity);
    XCTAssertTrue(NSEqualRanges(custom.quiesced.selection, stock.quiesced.selection));
}

- (void)testSelectionExtensionPathsShareOneRecordInOrderAndLiftIndependently {
    CGPoint spacebarCenter = CGPointMake(202.0, 779.0);
    CGPoint firstPrimaryPoint = CGPointMake(154.0, 779.0);
    CGPoint secondPrimaryPoint = CGPointMake(254.0, 779.0);
    CGPoint secondaryStartPoint = CGPointMake(152.6666666667, 779.0);
    IDHIDTouchPath *spacebarPath = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:spacebarCenter startOffset:0.0 waypoints:@[
            [IDHIDTouchWaypoint moveTo:spacebarCenter offset:0.55],
            [IDHIDTouchWaypoint moveTo:firstPrimaryPoint offset:2.40],
            [IDHIDTouchWaypoint moveTo:secondPrimaryPoint offset:8.40],
            [IDHIDTouchWaypoint liftAtOffset:9.80],
        ]];
    IDHIDTouchPath *extensionPath = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:secondaryStartPoint startOffset:0.85 waypoints:@[
            [IDHIDTouchWaypoint moveTo:secondaryStartPoint offset:9.20],
            [IDHIDTouchWaypoint liftAtOffset:9.50],
        ]];
    IDFloatingCursorHIDFakeRecord *record = IDHIDBuildEventRecord(
        self, @[spacebarPath, extensionPath], IDFloatingCursorHIDFakePath.class,
        IDFloatingCursorHIDFakeRecord.class);
    XCTAssertNotNil(record);
    XCTAssertEqual(record.paths.count, 2U);
    XCTAssertEqualObjects(record.paths[0].operations, (@[
        @"start {202, 779} 0.00", @"move {202, 779} 0.55",
        @"move {154, 779} 2.40", @"move {254, 779} 8.40", @"lift 9.80",
    ]));
    XCTAssertEqualObjects(record.paths[1].operations, (@[
        @"start {152.6666666667, 779} 0.85",
        @"move {152.6666666667, 779} 9.20", @"lift 9.50",
    ]));
}

- (void)testSelectionExtensionOracleScansPastCollapsedStockCheckpoints {
    IDFloatingCursorSelectionSample *collapsed = [IDFloatingCursorSelectionSample new];
    collapsed.status = (IDFloatingCursorStatus){.selection = NSMakeRange(46, 0)};
    IDFloatingCursorSelectionSample *nonempty = [IDFloatingCursorSelectionSample new];
    nonempty.status = (IDFloatingCursorStatus){.selection = NSMakeRange(43, 3)};
    IDFloatingCursorSelectionTrace *trace = [IDFloatingCursorSelectionTrace new];
    trace.samples = @[collapsed, nonempty];

    XCTAssertEqual([self firstNonemptySampleIndexInTrace:trace], 1U);
}

- (void)testBiDiAnchorOracleRejectsAdjacentSharedEndpointThatIsNotInitialAnchor {
    NSRange first = NSMakeRange(17, 3);
    NSRange second = NSMakeRange(17, 8);
    NSUInteger inferred = NSNotFound;
    XCTAssertEqual([self sharedRoleForRange:first range:second offset:&inferred],
                   IDFloatingCursorEndpointRoleStart);
    XCTAssertEqual(inferred, 17U);
    XCTAssertEqual([self roleForRange:first fixedOffset:16],
                   IDFloatingCursorEndpointRoleUnknown);
    XCTAssertEqual([self roleForRange:second fixedOffset:16],
                   IDFloatingCursorEndpointRoleUnknown);
    XCTAssertFalse([self range:first preservesLogicalAnchor:16]);
    XCTAssertFalse([self range:second preservesLogicalAnchor:16]);
}

- (void)testFloatingCursorSelectionExtensionKeepsInitialLogicalAnchor {
    NSArray *traces = [self stockAndCustomSelectionExtensionTraces];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *custom = traces[1];
    XCTAssertEqualObjects(stock.canonical, custom.canonical);
    XCTAssertTrue(NSEqualRanges(stock.initial.selection, NSMakeRange(46, 0)));
    XCTAssertTrue(NSEqualRanges(stock.initial.selection, custom.initial.selection));
    NSUInteger firstNonemptyIndex = [self firstNonemptySampleIndexInTrace:stock];
    XCTAssertNotEqual(firstNonemptyIndex, NSNotFound);
    if (firstNonemptyIndex == NSNotFound) return;
    NSUInteger fixedLogicalAnchor = stock.initial.selection.location;
    XCTAssertEqual(fixedLogicalAnchor, 46U);
    NSRange firstStockRange = stock.samples[firstNonemptyIndex].status.selection;
    NSRange firstCustomRange = custom.samples[firstNonemptyIndex].status.selection;
    IDFloatingCursorEndpointRole stockRole =
        [self roleForRange:firstStockRange fixedOffset:fixedLogicalAnchor];
    XCTAssertNotEqual(stockRole, IDFloatingCursorEndpointRoleUnknown);
    XCTAssertEqual([self roleForRange:firstCustomRange fixedOffset:fixedLogicalAnchor],
                   stockRole);
    XCTAssertTrue(NSEqualRanges(firstCustomRange, firstStockRange));
    for (NSUInteger index = 3; index <= 5; index += 1) {
        NSRange expected = stock.samples[index].status.selection;
        NSRange actual = custom.samples[index].status.selection;
        XCTAssertEqual([self roleForRange:expected fixedOffset:fixedLogicalAnchor], stockRole);
        XCTAssertTrue(NSEqualRanges(actual, expected), @"index=%lu stock=%@ custom=%@",
                      (unsigned long)index, NSStringFromRange(expected),
                      NSStringFromRange(actual));
        XCTAssertEqual([self roleForRange:actual fixedOffset:fixedLogicalAnchor], stockRole);
    }
}

- (void)testMinimalFloatingCursorSelectionExtensionKeepsInitialLogicalAnchor {
    NSArray *traces =
        [self stockAndCustomSelectionExtensionTracesMinimal:YES];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *minimal = traces[1];
    XCTAssertEqualObjects(stock.canonical, minimal.canonical);
    XCTAssertTrue(NSEqualRanges(stock.initial.selection,
                               minimal.initial.selection));
    NSUInteger firstNonemptyIndex =
        [self firstNonemptySampleIndexInTrace:stock];
    XCTAssertNotEqual(firstNonemptyIndex, NSNotFound);
    if (firstNonemptyIndex == NSNotFound) return;
    NSUInteger fixedLogicalAnchor = stock.initial.selection.location;
    XCTAssertEqual(fixedLogicalAnchor, 46U);
    NSRange firstStockRange =
        stock.samples[firstNonemptyIndex].status.selection;
    NSRange firstMinimalRange =
        minimal.samples[firstNonemptyIndex].status.selection;
    IDFloatingCursorEndpointRole role = [self
        roleForRange:firstStockRange
         fixedOffset:fixedLogicalAnchor];
    XCTAssertNotEqual(role, IDFloatingCursorEndpointRoleUnknown);
    XCTAssertEqual(
        [self roleForRange:firstMinimalRange fixedOffset:fixedLogicalAnchor],
        role);
    XCTAssertTrue(NSEqualRanges(firstMinimalRange, firstStockRange));
    for (NSUInteger index = 3; index <= 5; index += 1) {
        NSRange expected = stock.samples[index].status.selection;
        NSRange actual = minimal.samples[index].status.selection;
        XCTAssertEqual(
            [self roleForRange:expected fixedOffset:fixedLogicalAnchor],
            role);
        XCTAssertTrue(NSEqualRanges(actual, expected),
                      @"index=%lu stock=%@ minimal=%@",
                      (unsigned long)index,
                      NSStringFromRange(expected),
                      NSStringFromRange(actual));
        XCTAssertEqual(
            [self roleForRange:actual fixedOffset:fixedLogicalAnchor],
            role);
    }
}

- (void)testFloatingCursorSelectionExtensionReversesWithoutMovingFixedAnchor {
    NSArray *traces = [self stockAndCustomSelectionExtensionTraces];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *custom = traces[1];
    NSUInteger firstNonemptyIndex = [self firstNonemptySampleIndexInTrace:stock];
    XCTAssertNotEqual(firstNonemptyIndex, NSNotFound);
    if (firstNonemptyIndex == NSNotFound) return;
    NSUInteger fixedLogicalAnchor = stock.initial.selection.location;
    XCTAssertEqual(fixedLogicalAnchor, 46U);
    IDFloatingCursorEndpointRole stockRole = [self
        roleForRange:stock.samples[firstNonemptyIndex].status.selection
         fixedOffset:fixedLogicalAnchor];
    XCTAssertNotEqual(stockRole, IDFloatingCursorEndpointRoleUnknown);
    for (NSUInteger index = 2; index <= 4; index += 1) {
        NSRange expected = stock.samples[index].status.selection;
        NSRange actual = custom.samples[index].status.selection;
        XCTAssertEqual([self roleForRange:expected fixedOffset:fixedLogicalAnchor], stockRole);
        XCTAssertTrue(NSEqualRanges(actual, expected), @"index=%lu stock=%@ custom=%@",
                      (unsigned long)index, NSStringFromRange(expected),
                      NSStringFromRange(actual));
        XCTAssertEqual([self roleForRange:actual fixedOffset:fixedLogicalAnchor], stockRole);
    }
    XCTAssertTrue(NSEqualRanges(stock.samples[3].status.selection,
                                stock.samples[4].status.selection));
    XCTAssertTrue(NSEqualRanges(custom.samples[3].status.selection,
                                custom.samples[4].status.selection));
    XCTAssertEqualObjects(stock.canonical, custom.canonical);
}

- (void)testFloatingCursorSelectionExtensionCrossesAnchorLikeStock {
    NSArray *traces = [self stockAndCustomSelectionExtensionTraces];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *custom = traces[1];
    for (NSUInteger index = 7; index < stock.samples.count; index += 1) {
        NSRange expected = stock.samples[index].status.selection;
        NSRange actual = custom.samples[index].status.selection;
        XCTAssertTrue(NSEqualRanges(actual, expected), @"index=%lu stock=%@ custom=%@",
                      (unsigned long)index, NSStringFromRange(expected),
                      NSStringFromRange(actual));
    }
    NSUInteger stockFixed = NSNotFound;
    NSUInteger customFixed = NSNotFound;
    IDFloatingCursorEndpointRole stockRole = [self
        sharedRoleForRange:stock.samples[5].status.selection
                     range:stock.samples[6].status.selection offset:&stockFixed];
    IDFloatingCursorEndpointRole customRole = [self
        sharedRoleForRange:custom.samples[5].status.selection
                     range:custom.samples[6].status.selection offset:&customFixed];
    XCTAssertNotEqual(stockRole, IDFloatingCursorEndpointRoleUnknown);
    XCTAssertEqual(customRole, stockRole);
    XCTAssertEqual(customFixed, stockFixed);
    XCTAssertTrue(NSEqualRanges(custom.ended.selection, stock.ended.selection));
    XCTAssertTrue(NSEqualRanges(custom.quiesced.selection, stock.quiesced.selection));
    XCTAssertEqualObjects(stock.canonical, custom.canonical);
}

- (NSArray<IDFloatingCursorSelectionTrace *> *)task4BoundaryTraces {
    return [self task4TracesForScenario:@"floating-boundary" initialOffset:50 deltas:@[
        [NSValue valueWithCGPoint:CGPointMake(0, -24)],
        [NSValue valueWithCGPoint:CGPointMake(0, -52)],
        [NSValue valueWithCGPoint:CGPointMake(0, -82)],
    ]];
}

- (NSArray<IDFloatingCursorSelectionTrace *> *)task4BiDiTraces {
    return [self task4TracesForScenario:@"floating-bidi" initialOffset:16 deltas:@[
        [NSValue valueWithCGPoint:CGPointMake(-52, 0)],
        [NSValue valueWithCGPoint:CGPointMake(68, 0)],
        [NSValue valueWithCGPoint:CGPointMake(-120, 0)],
    ]];
}

- (void)testFloatingCursorCrossesMultipleIndependentBlocksLikeStock {
    NSArray *traces = [self task4BoundaryTraces];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *custom = traces[1];
    [self assertTask4Trace:custom equalsStock:stock];
    NSUInteger fixedAnchor = stock.initial.selection.location;
    XCTAssertEqual(fixedAnchor, 50U);
    NSUInteger firstNonempty = [self firstNonemptySampleIndexInTrace:stock];
    XCTAssertNotEqual(firstNonempty, NSNotFound);
    if (firstNonempty == NSNotFound) return;
    IDFloatingCursorEndpointRole fixedRole = [self
        roleForRange:stock.samples[firstNonempty].status.selection
         fixedOffset:fixedAnchor];
    XCTAssertNotEqual(fixedRole, IDFloatingCursorEndpointRoleUnknown);
    BOOL visitedSecond = NO;
    BOOL visitedFirst = NO;
    for (NSUInteger index = firstNonempty; index < stock.samples.count; index += 1) {
        NSRange range = stock.samples[index].status.selection;
        NSRange customRange = custom.samples[index].status.selection;
        if (range.length > 0) {
            XCTAssertEqual([self roleForRange:range fixedOffset:fixedAnchor],
                           fixedRole);
            XCTAssertEqual([self roleForRange:customRange fixedOffset:fixedAnchor],
                           fixedRole);
        }
        if (range.length > 0 && range.location >= 17 && range.location <= 35)
            visitedSecond = YES;
        if (range.length > 0 && range.location <= 16) visitedFirst = YES;
    }
    XCTAssertTrue(visitedSecond, @"stock=%@", stock.samples);
    XCTAssertTrue(visitedFirst, @"stock=%@", stock.samples);
}

- (void)testFloatingCursorSelectionIncludesEachStructuralNewlineExactlyOnce {
    NSArray *traces = [self task4BoundaryTraces];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *custom = traces[1];
    [self assertTask4Trace:custom equalsStock:stock];
    BOOL provedOneSeparator = NO;
    BOOL provedTwoSeparators = NO;
    for (IDFloatingCursorSelectionSample *sample in stock.samples) {
        NSRange range = sample.status.selection;
        if (range.length == 0 || NSMaxRange(range) > stock.canonical.length) continue;
        NSString *selected = [stock.canonical substringWithRange:range];
        NSUInteger separators = [selected componentsSeparatedByString:@"\n"].count - 1;
        if (range.location >= 17 && range.location <= 35) {
            XCTAssertEqual(separators, 1U, @"range=%@ selected=%@",
                           NSStringFromRange(range), selected);
            provedOneSeparator = YES;
        } else if (range.location <= 16) {
            XCTAssertEqual(separators, 2U, @"range=%@ selected=%@",
                           NSStringFromRange(range), selected);
            provedTwoSeparators = YES;
        }
    }
    XCTAssertTrue(provedOneSeparator);
    XCTAssertTrue(provedTwoSeparators);
}

- (void)testFloatingCursorMixedBiDiPreservesAffinityAndLogicalAnchor {
    NSArray *traces = [self task4BiDiTraces];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *custom = traces[1];
    [self assertTask4Trace:custom equalsStock:stock];
    NSUInteger fixedAnchor = stock.initial.selection.location;
    XCTAssertEqual(fixedAnchor, 16U);
    XCTAssertNotEqual([self roleForRange:stock.samples[0].status.selection
                              fixedOffset:fixedAnchor],
                      IDFloatingCursorEndpointRoleUnknown);
    XCTAssertNotEqual([self roleForRange:custom.samples[0].status.selection
                              fixedOffset:fixedAnchor],
                      IDFloatingCursorEndpointRoleUnknown);
    for (NSUInteger index = 0; index < stock.samples.count; index += 1) {
        NSRange stockRange = stock.samples[index].status.selection;
        NSRange customRange = custom.samples[index].status.selection;
        XCTAssertTrue([self range:stockRange preservesLogicalAnchor:fixedAnchor],
                      @"phase=%lu stock=%@", (unsigned long)index,
                      NSStringFromRange(stockRange));
        XCTAssertTrue([self range:customRange preservesLogicalAnchor:fixedAnchor],
                      @"phase=%lu custom=%@", (unsigned long)index,
                      NSStringFromRange(customRange));
    }
}

- (void)testFloatingCursorMixedBiDiReversalMatchesStock {
    NSArray *traces = [self task4BiDiTraces];
    IDFloatingCursorSelectionTrace *stock = traces[0];
    IDFloatingCursorSelectionTrace *custom = traces[1];
    [self assertTask4Trace:custom equalsStock:stock];
    // Direct stock cursor scans on the pinned runtime define these caret-stop intervals.
    NSArray<NSNumber *> *lowerBounds = @[@88.0, @214.75, @(-INFINITY)];
    NSArray<NSNumber *> *upperBounds = @[@96.75, @228.25, @7.25];
    NSArray<NSNumber *> *expectedOffsets = @[@11, @25, @0];
    for (IDFloatingCursorSelectionTrace *trace in @[stock, custom]) {
        for (NSUInteger index = 0; index < trace.samples.count; index += 1) {
            NSDictionary *callback = trace.samples[index].cursorCallback;
            XCTAssertNotNil(callback, @"phase=%lu", (unsigned long)index);
            CGFloat x = [callback[@"point"][@"x"] doubleValue];
            NSInteger output = [callback[@"output"][@"offset"] integerValue];
            XCTAssertEqual(output, expectedOffsets[index].integerValue,
                           @"phase=%lu callback=%@", (unsigned long)index, callback);
            CGFloat lower = lowerBounds[index].doubleValue;
            CGFloat upper = upperBounds[index].doubleValue;
            CGFloat margin = MIN(x - lower, upper - x);
            if (!isfinite(lower)) margin = upper - x;
            XCTAssertGreaterThanOrEqual(margin, 3.0,
                @"phase=%lu x=%.3f interval=[%.3f,%.3f) callback=%@",
                (unsigned long)index, x, lower, upper, callback);
        }
    }
    NSUInteger fixedAnchor = stock.initial.selection.location;
    XCTAssertEqual(fixedAnchor, 16U);
    for (NSUInteger index = 0; index < stock.samples.count; index += 1) {
        XCTAssertTrue([self range:stock.samples[index].status.selection
                    preservesLogicalAnchor:fixedAnchor], @"phase=%lu stock=%@",
                    (unsigned long)index,
                    NSStringFromRange(stock.samples[index].status.selection));
        XCTAssertTrue([self range:custom.samples[index].status.selection
                    preservesLogicalAnchor:fixedAnchor], @"phase=%lu custom=%@",
                    (unsigned long)index,
                    NSStringFromRange(custom.samples[index].status.selection));
    }
    XCTAssertLessThan([stock.samples[0].cursorCallback[@"output"][@"offset"] integerValue],
                      (NSInteger)fixedAnchor);
    XCTAssertGreaterThan([stock.samples[1].cursorCallback[@"output"][@"offset"] integerValue],
                         (NSInteger)fixedAnchor);
    XCTAssertLessThan([stock.samples[2].cursorCallback[@"output"][@"offset"] integerValue],
                      (NSInteger)fixedAnchor);
}

- (NSUInteger)activeEndpointForStatus:(IDFloatingCursorStatus)status
                          fixedOffset:(NSUInteger)fixedOffset {
    if (status.selection.length == 0) return status.selection.location;
    if (status.selection.location == fixedOffset) return NSMaxRange(status.selection);
    if (NSMaxRange(status.selection) == fixedOffset) return status.selection.location;
    return NSNotFound;
}

- (NSUInteger)fixedEndpointForStatus:(IDFloatingCursorStatus)status
                         fixedOffset:(NSUInteger)fixedOffset {
    if (status.selection.length == 0) return fixedOffset;
    if (status.selection.location == fixedOffset ||
        NSMaxRange(status.selection) == fixedOffset) return fixedOffset;
    return NSNotFound;
}

- (IDFloatingCursorScrollTrace *)runScrollApplication:(XCUIApplication *)application
                                                editor:(XCUIElement *)editor
                                                status:(XCUIElement *)statusElement
                                                  host:(NSString *)host
                                                 lower:(BOOL)lower
                                     selectionExtension:(BOOL)selectionExtension {
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);
    IDFloatingCursorScrollTrace *trace = [IDFloatingCursorScrollTrace new];
    NSString *canonical = nil;
    IDFloatingCursorStatus initial = {0};
    XCTAssertTrue(IDFloatingCursorWaitForStatus(statusElement, 4.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            BOOL offsetReady = lower || sample.contentOffset.y > 1.0;
            CGFloat caretMidY = CGRectGetMidY(sample.caret);
            CGFloat expectedPhysicalY = lower ? sample.visible.size.height - 45.0 : 45.0;
            CGFloat physicalY = caretMidY - CGRectGetMinY(sample.visible);
            BOOL edgeReady = fabs(physicalY - expectedPhysicalY) <= 1.0;
            NSUInteger expectedInitialOffset = selectionExtension ? 900 : (lower ? 1600 : 891);
            return sample.firstResponder &&
                sample.selection.location == expectedInitialOffset &&
                sample.selection.length == 0 &&
                sample.containerStable && sample.containerCreations == 1 &&
                offsetReady && edgeReady;
        }, &initial, &canonical), @"host=%@ status=%@", host, statusElement.value);
    trace.initial = initial;
    trace.canonical = canonical;
    trace.usesSelectionExtension = selectionExtension;
    XCTAssertEqual(initial.blockCount, 33U);
    XCTAssertEqualWithAccuracy(initial.visible.size.height, 360.0, 0.5);

    CGRect spacebar = IDFloatingCursorSpacebarFrame(self, application);
    XCTAssertFalse(CGRectIsNull(spacebar));
    if (CGRectIsNull(spacebar)) return trace;
    CGPoint center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    CGPoint destination = CGPointMake(center.x, center.y + (lower ? 68.0 : -110.0));
    CGPoint initialDirectionalDestination =
        CGPointMake(center.x, center.y + (lower ? 24.0 : -36.0));
    CGRect applicationFrame = application.frame;
    CGPoint cursorTerminal = lower
        ? CGPointMake(CGRectGetMaxX(applicationFrame) - 1.0,
                      CGRectGetMaxY(applicationFrame) - 1.0)
        : CGPointMake(1.0, 1.0);
    CGPoint terminal = selectionExtension ? destination : cursorTerminal;
    XCTAssertTrue(CGRectContainsPoint(applicationFrame, terminal));
    CGPoint secondary = CGPointMake(
        center.x - MIN(60.0, CGRectGetWidth(spacebar) * 0.25), center.y);
    trace.primaryStart = center;
    trace.primaryDestination = destination;
    trace.terminalDestination = terminal;
    trace.secondaryStart = secondary;

    NSTimeInterval terminalOffset = 7.50;
    NSTimeInterval liftOffset = 11.00;
    NSTimeInterval directionalMoveOffset = selectionExtension ? 2.40 : 1.20;
    IDHIDTouchPath *primary = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:center startOffset:0.0 waypoints:@[
            [IDHIDTouchWaypoint moveTo:center offset:0.55],
            [IDHIDTouchWaypoint moveTo:initialDirectionalDestination
                                offset:directionalMoveOffset],
            [IDHIDTouchWaypoint moveTo:destination
                                offset:directionalMoveOffset + 1.20],
            [IDHIDTouchWaypoint moveTo:terminal offset:terminalOffset],
            [IDHIDTouchWaypoint liftAtOffset:liftOffset],
        ]];
    NSMutableArray<IDHIDTouchPath *> *paths = [NSMutableArray arrayWithObject:primary];
    if (selectionExtension) {
        [paths addObject:[[IDHIDTouchPath alloc]
            initWithStartScreenPoint:secondary startOffset:0.85 waypoints:@[
                [IDHIDTouchWaypoint moveTo:secondary offset:10.70],
                [IDHIDTouchWaypoint liftAtOffset:10.80],
            ]]];
    }

    IDFloatingCursorHoldObservation *observation = [IDFloatingCursorHoldObservation new];
    NSMutableArray<NSValue *> *samples = [NSMutableArray array];
    NSMutableArray<NSNumber *> *sampleTimes = [NSMutableArray array];
    NSMutableArray<id> *sampleCallbacks = [NSMutableArray array];
    __block NSString *heldCanonical = nil;
    __block NSDictionary<NSString *, id> *heldAutoscrollTrace = nil;
    __block NSDictionary<NSString *, id> *lastAutoscrollTrace = nil;
    __block NSString *lastParsedDescription = nil;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    CFTimeInterval epoch = IDFloatingCursorMonotonicTime();
    CFTimeInterval liftDeadline = epoch + liftOffset;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        IDFloatingCursorObservationPhase phase =
            IDFloatingCursorObservationPhaseWaitingForDirectionalProgress;
        while (IDFloatingCursorMonotonicTime() < epoch + 10.70) {
            id value = statusElement.value;
            IDFloatingCursorStatus parsed = {0};
            if (!IDFloatingCursorParseStatus(value, &parsed)) {
                observation.parseFailures += 1;
            } else {
                lastAutoscrollTrace = IDFloatingCursorCopyAutoscrollTrace(value);
                lastParsedDescription = [NSString stringWithFormat:
                    @"selection=%@ offset=%@", NSStringFromRange(parsed.selection),
                    NSStringFromCGPoint(parsed.contentOffset)];
                NSArray<NSValue *> *candidate = @[IDFloatingCursorStatusValue(parsed)];
                BOOL directionalProgress =
                    IDFloatingCursorFirstDirectionalProgressIndex(initial, candidate, lower) == 0;
                if (directionalProgress &&
                    phase == IDFloatingCursorObservationPhaseWaitingForDirectionalProgress) {
                    phase = IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress;
                    observation.firstProgressTime = IDFloatingCursorMonotonicTime();
                }
                if (phase == IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress &&
                    IDFloatingCursorMonotonicTime() < liftDeadline) {
                    [samples addObject:IDFloatingCursorStatusValue(parsed)];
                    [sampleTimes addObject:@(IDFloatingCursorMonotonicTime() - epoch)];
                    [sampleCallbacks addObject:
                        IDFloatingCursorCopyCursorCallback(value) ?: NSNull.null];
                    observation.lastSampleTime = IDFloatingCursorMonotonicTime();
                    if (IDFloatingCursorHeldCaptureShouldRetry(
                            observation.heldScreenshot != nil,
                            IDFloatingCursorMonotonicTime(), liftDeadline) &&
                        IDFloatingCursorMonotonicTime() >= epoch + 7.75) {
                        IDFloatingCursorStatus before = parsed;
                        NSString *beforeCanonical = IDFloatingCursorCopyCanonical(value);
                        IDFloatingCursorObservationPhase beforePhase = phase;
                        XCUIScreenshot *screenshot = XCUIScreen.mainScreen.screenshot;
                        CFTimeInterval completionTime = IDFloatingCursorMonotonicTime();
                        id afterValue = statusElement.value;
                        CFTimeInterval afterReadCompletionTime =
                            IDFloatingCursorMonotonicTime();
                        IDFloatingCursorStatus after = {0};
                        if (!IDFloatingCursorParseStatus(afterValue, &after)) {
                            observation.parseFailures += 1;
                        } else {
                            IDFloatingCursorObservationPhase afterPhase =
                                afterReadCompletionTime < liftDeadline
                                ? phase : IDFloatingCursorObservationPhaseLifted;
                            NSString *afterCanonical = IDFloatingCursorCopyCanonical(afterValue);
                            if (IDFloatingCursorHeldCaptureIsAtomic(
                                    before, after, beforePhase, afterPhase,
                                    completionTime, afterReadCompletionTime, liftDeadline) &&
                                [beforeCanonical isEqualToString:afterCanonical]) {
                                heldCanonical = beforeCanonical;
                                heldAutoscrollTrace =
                                    IDFloatingCursorCopyAutoscrollTrace(value);
                                observation.heldStatus = IDFloatingCursorStatusValue(before);
                                observation.heldPhase = beforePhase;
                                observation.heldScreenshotCompletionTime = completionTime;
                                observation.heldAfterReadCompletionTime =
                                    afterReadCompletionTime;
                                observation.heldScreenshot = screenshot;
                            }
                        }
                    }
                }
            }
            [NSThread sleepForTimeInterval:0.025];
        }
        observation.samples = samples.copy;
        dispatch_semaphore_signal(finished);
    });
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, application, paths, &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(finished,
        dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0L);
    trace.observation = observation;
    XCTAssertEqual(observation.parseFailures, 0U, @"host=%@", host);
    XCTAssertGreaterThanOrEqual(observation.samples.count, 2U,
        @"host=%@ initial=%@ last=%@", host, NSStringFromRange(initial.selection),
        lastParsedDescription);
    XCTAssertGreaterThan(observation.firstProgressTime, epoch, @"host=%@", host);
    XCTAssertLessThan(observation.lastSampleTime, epoch + liftOffset);
    XCTAssertNotNil(observation.heldScreenshot, @"host=%@", host);
    XCTAssertNotNil(observation.heldStatus, @"host=%@", host);
    XCTAssertEqual(observation.heldPhase,
                   IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress);
    XCTAssertLessThan(observation.heldScreenshotCompletionTime, liftDeadline);
    XCTAssertLessThan(observation.heldAfterReadCompletionTime, liftDeadline);
    XCTAssertTrue([observation.samples containsObject:observation.heldStatus]);
    XCTAssertEqualObjects(heldCanonical, canonical, @"host=%@", host);
    if (observation.heldScreenshot != nil) {
        [self addScreenshot:observation.heldScreenshot name:[NSString stringWithFormat:
            @"%@-floating-scroll-%@-%@-held", host, lower ? @"lower" : @"upper",
            selectionExtension ? @"selection" : @"cursor"]];
    }

    IDFloatingCursorStatus previous = initial;
    for (NSValue *value in observation.samples) {
        IDFloatingCursorStatus sample = IDFloatingCursorStatusFromValue(value);
        NSUInteger active = [self activeEndpointForStatus:sample
                                             fixedOffset:initial.selection.location];
        NSUInteger previousActive = [self activeEndpointForStatus:previous
                                                     fixedOffset:initial.selection.location];
        XCTAssertNotEqual(active, NSNotFound);
        XCTAssertNotEqual(previousActive, NSNotFound);
        XCTAssertEqual([self fixedEndpointForStatus:sample
                                        fixedOffset:initial.selection.location],
                       initial.selection.location);
        if (lower) {
            XCTAssertGreaterThanOrEqual(sample.contentOffset.y,
                                        previous.contentOffset.y - 0.01);
            XCTAssertGreaterThanOrEqual(active, previousActive);
        } else {
            XCTAssertLessThanOrEqual(sample.contentOffset.y,
                                     previous.contentOffset.y + 0.01);
            XCTAssertLessThanOrEqual(active, previousActive);
        }
        previous = sample;
    }
    IDFloatingCursorStatus first =
        IDFloatingCursorStatusFromValue(observation.samples.firstObject);
    IDFloatingCursorStatus last =
        IDFloatingCursorStatusFromValue(observation.samples.lastObject);
    NSUInteger firstActive = [self activeEndpointForStatus:first
                                               fixedOffset:initial.selection.location];
    NSUInteger lastActive = [self activeEndpointForStatus:last
                                              fixedOffset:initial.selection.location];
    if (lower) {
        XCTAssertGreaterThan(last.contentOffset.y, first.contentOffset.y + 0.01);
        XCTAssertGreaterThan(lastActive, firstActive);
    } else {
        XCTAssertLessThan(last.contentOffset.y, first.contentOffset.y - 0.01);
        XCTAssertLessThan(lastActive, firstActive);
    }
    NSMutableArray<NSString *> *sampleRows = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:
            @"host=%@ direction=%@ mode=%@ initialSelection=%@ initialOffset=%@ "
             "primaryStart=%@ primaryDestination=%@ secondaryStart=%@ "
             "terminalDestination=%@ "
             "firstProgress=%.6f lastSample=%.6f screenshotCompletion=%.6f "
             "afterReadCompletion=%.6f "
             "liftDeadline=%.6f heldPhase=%lu parseFailures=%lu "
             "heldAutoscroll=%@ lastAutoscroll=%@",
            host, lower ? @"lower" : @"upper",
            selectionExtension ? @"selection" : @"cursor",
            NSStringFromRange(initial.selection), NSStringFromCGPoint(initial.contentOffset),
            NSStringFromCGPoint(center), NSStringFromCGPoint(destination),
            NSStringFromCGPoint(secondary), NSStringFromCGPoint(terminal),
            observation.firstProgressTime - epoch,
            observation.lastSampleTime - epoch,
            observation.heldScreenshotCompletionTime - epoch,
            observation.heldAfterReadCompletionTime - epoch, liftDeadline - epoch,
            (unsigned long)observation.heldPhase,
            (unsigned long)observation.parseFailures,
            heldAutoscrollTrace, lastAutoscrollTrace]];
    IDFloatingCursorStatus attachedPrevious = {0};
    BOOL hasAttachedPrevious = NO;
    NSUInteger plateauCount = 0;
    for (NSUInteger index = 0; index < observation.samples.count; index += 1) {
        IDFloatingCursorStatus sample =
            IDFloatingCursorStatusFromValue(observation.samples[index]);
        BOOL changed = !hasAttachedPrevious ||
            !NSEqualRanges(sample.selection, attachedPrevious.selection) ||
            !CGPointEqualToPoint(sample.contentOffset, attachedPrevious.contentOffset);
        if (!changed && index + 1 < observation.samples.count) {
            plateauCount += 1;
            continue;
        }
        [sampleRows addObject:[NSString stringWithFormat:
            @"%04lu t=%.6f selection=%@ offset=%@ fixed=%lu active=%lu callback=%@",
            (unsigned long)index, sampleTimes[index].doubleValue,
            NSStringFromRange(sample.selection),
            NSStringFromCGPoint(sample.contentOffset),
            (unsigned long)[self fixedEndpointForStatus:sample
                                            fixedOffset:initial.selection.location],
            (unsigned long)[self activeEndpointForStatus:sample
                                             fixedOffset:initial.selection.location],
            sampleCallbacks[index]]];
        attachedPrevious = sample;
        hasAttachedPrevious = YES;
    }
    [sampleRows addObject:[NSString stringWithFormat:@"plateauSamples=%lu totalSamples=%lu",
        (unsigned long)plateauCount, (unsigned long)observation.samples.count]];
    XCTAttachment *sampleAttachment = [XCTAttachment attachmentWithString:
        [sampleRows componentsJoinedByString:@"\n"]];
    sampleAttachment.name = [NSString stringWithFormat:@"%@-floating-scroll-%@-%@-samples",
        host, lower ? @"lower" : @"upper",
        selectionExtension ? @"selection" : @"cursor"];
    sampleAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:sampleAttachment];

    IDFloatingCursorStatus ended = {0};
    NSString *endedCanonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(statusElement, 3.0,
        ^BOOL(IDFloatingCursorStatus sample) { return sample.containerStable; },
        &ended, &endedCanonical), @"host=%@ status=%@", host, statusElement.value);
    trace.ended = ended;
    NSDictionary<NSString *, id> *endedCallback =
        IDFloatingCursorCopyCursorCallback(statusElement.value);
    XCTAssertEqualObjects(endedCanonical, canonical);
    [NSThread sleepForTimeInterval:0.5];
    IDFloatingCursorStatus quiesced = {0};
    id quiescedValue = statusElement.value;
    XCTAssertTrue(IDFloatingCursorParseStatus(quiescedValue, &quiesced));
    trace.quiesced = quiesced;
    NSDictionary<NSString *, id> *quiescedCallback =
        IDFloatingCursorCopyCursorCallback(quiescedValue);
    XCTAssertTrue(NSEqualRanges(ended.selection, quiesced.selection));
    XCTAssertEqualWithAccuracy(ended.contentOffset.y, quiesced.contentOffset.y, 0.01);
    if (!selectionExtension) {
        NSUInteger expectedTerminalEndpoint = lower ? 1728U : 0U;
        NSUInteger endedActive = [self activeEndpointForStatus:ended
                                                    fixedOffset:initial.selection.location];
        XCTAssertEqual(endedActive, expectedTerminalEndpoint,
                       @"host=%@ terminal=%@", host, NSStringFromCGPoint(terminal));
        XCTAssertEqual([endedCallback[@"output"][@"offset"] unsignedIntegerValue],
                       expectedTerminalEndpoint, @"host=%@ terminal callback", host);
        XCTAssertEqual(lower ? canonical.length - endedActive : endedActive,
                       lower ? 179U : 0U,
                       @"host=%@ terminal boundary margin", host);
    }
    XCTAssertEqualObjects(IDFloatingCursorCopyCanonical(quiescedValue), canonical);
    XCTAttachment *releaseAttachment = [XCTAttachment attachmentWithString:
        [NSString stringWithFormat:
            @"host=%@ direction=%@ mode=%@ heldCallback=%@ endedSelection=%@ "
             "endedOffset=%@ endedCallback=%@ quiescedSelection=%@ quiescedOffset=%@ "
             "quiescedCallback=%@",
            host, lower ? @"lower" : @"upper",
            selectionExtension ? @"selection" : @"cursor",
            sampleCallbacks.lastObject, NSStringFromRange(ended.selection),
            NSStringFromCGPoint(ended.contentOffset), endedCallback,
            NSStringFromRange(quiesced.selection), NSStringFromCGPoint(quiesced.contentOffset),
            quiescedCallback]];
    releaseAttachment.name = [NSString stringWithFormat:
        @"%@-floating-scroll-%@-%@-release", host, lower ? @"lower" : @"upper",
        selectionExtension ? @"selection" : @"cursor"];
    releaseAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:releaseAttachment];
    return trace;
}

- (NSArray<IDFloatingCursorScrollTrace *> *)scrollTracesForLower:(BOOL)lower
                                                selectionExtension:(BOOL)selectionExtension {
    XCUIApplication *frameApplication =
        IDFloatingCursorLaunchCustomScroll(self, lower, selectionExtension);
    XCUIElement *frameEditor =
        [frameApplication descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    CGRect editorFrame = frameEditor.frame;
    [frameApplication terminate];

    XCUIApplication *stock =
        IDFloatingCursorLaunchStockScroll(self, editorFrame, lower, selectionExtension);
    IDFloatingCursorScrollTrace *stockTrace = [self runScrollApplication:stock
        editor:[stock descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"]
        status:[stock descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        host:@"stock" lower:lower selectionExtension:selectionExtension];
    [stock terminate];
    XCUIApplication *custom =
        IDFloatingCursorLaunchCustomScroll(self, lower, selectionExtension);
    IDFloatingCursorScrollTrace *customTrace = [self runScrollApplication:custom
        editor:[custom descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"]
        status:[custom descendantsMatchingType:XCUIElementTypeAny][@"floating-status"]
        host:@"custom" lower:lower selectionExtension:selectionExtension];
    [custom terminate];
    XCTAssertTrue(CGPointEqualToPoint(stockTrace.primaryStart, customTrace.primaryStart));
    XCTAssertTrue(CGPointEqualToPoint(stockTrace.primaryDestination,
                                      customTrace.primaryDestination));
    XCTAssertTrue(CGPointEqualToPoint(stockTrace.terminalDestination,
                                      customTrace.terminalDestination));
    XCTAssertTrue(CGPointEqualToPoint(stockTrace.secondaryStart, customTrace.secondaryStart));
    XCTAssertEqualObjects(stockTrace.canonical, customTrace.canonical);
    XCTAssertTrue(NSEqualRanges(stockTrace.initial.selection, customTrace.initial.selection),
                  @"stock=%@ custom=%@", NSStringFromRange(stockTrace.initial.selection),
                  NSStringFromRange(customTrace.initial.selection));
    XCTAssertEqual(stockTrace.initial.startAffinity, customTrace.initial.startAffinity);
    XCTAssertEqual(stockTrace.initial.endAffinity, customTrace.initial.endAffinity);
    CGFloat stockPhysicalCaretY = CGRectGetMidY(stockTrace.initial.caret) -
        CGRectGetMinY(stockTrace.initial.visible);
    CGFloat customPhysicalCaretY = CGRectGetMidY(customTrace.initial.caret) -
        CGRectGetMinY(customTrace.initial.visible);
    XCTAssertEqualWithAccuracy(stockPhysicalCaretY, customPhysicalCaretY, 0.5,
                               @"stockOffset=%.3f customOffset=%.3f",
                               stockTrace.initial.contentOffset.y,
                               customTrace.initial.contentOffset.y);
    XCTAssertTrue(NSEqualRanges(stockTrace.ended.selection, customTrace.ended.selection),
                  @"stock=%@ custom=%@", NSStringFromRange(stockTrace.ended.selection),
                  NSStringFromRange(customTrace.ended.selection));
    XCTAssertTrue(NSEqualRanges(stockTrace.quiesced.selection, customTrace.quiesced.selection),
                  @"stock=%@ custom=%@", NSStringFromRange(stockTrace.quiesced.selection),
                  NSStringFromRange(customTrace.quiesced.selection));
    return @[stockTrace, customTrace];
}

- (void)testFloatingCursorHeldBelowViewportScrollsAndAdvancesInsertion {
    [self scrollTracesForLower:YES selectionExtension:NO];
}

- (void)testFloatingCursorSelectionHeldBelowViewportScrollsAndExtendsSelection {
    [self scrollTracesForLower:YES selectionExtension:YES];
}

- (void)testFloatingCursorHeldAboveViewportScrollsAndRetreatsInsertion {
    [self scrollTracesForLower:NO selectionExtension:NO];
}

- (void)testFloatingCursorSelectionHeldAboveViewportKeepsOppositeEndpointFixed {
    [self scrollTracesForLower:NO selectionExtension:YES];
}

@end
