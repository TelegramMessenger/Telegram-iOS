@import XCTest;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    NSRange selection;
    NSInteger startAffinity;
    NSInteger endAffinity;
    CGRect caret;
    CGRect visible;
    CGPoint contentOffset;
    NSUInteger blockCount;
    NSUInteger presentationUpdates;
    NSUInteger containerCreations;
    BOOL containerStable;
    BOOL firstResponder;
} IDFloatingCursorStatus;

typedef NS_ENUM(NSUInteger, IDFloatingCursorObservationPhase) {
    IDFloatingCursorObservationPhaseWaitingForDirectionalProgress,
    IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress,
    IDFloatingCursorObservationPhaseLifted,
};

@interface IDFloatingCursorHoldObservation : NSObject
@property(nonatomic, copy) NSArray<NSValue *> *samples;
@property(nonatomic) NSUInteger parseFailures;
@property(nonatomic) CFTimeInterval firstProgressTime;
@property(nonatomic) CFTimeInterval lastSampleTime;
@property(nonatomic) CFTimeInterval heldScreenshotCompletionTime;
@property(nonatomic) CFTimeInterval heldAfterReadCompletionTime;
@property(nonatomic) IDFloatingCursorObservationPhase heldPhase;
@property(nonatomic, strong, nullable) NSValue *heldStatus;
@property(nonatomic, strong, nullable) XCUIScreenshot *heldScreenshot;
@end

FOUNDATION_EXPORT NSValue *IDFloatingCursorStatusValue(IDFloatingCursorStatus status);
FOUNDATION_EXPORT IDFloatingCursorStatus IDFloatingCursorStatusFromValue(NSValue *value);
FOUNDATION_EXPORT NSUInteger IDFloatingCursorFirstDirectionalProgressIndex(
    IDFloatingCursorStatus initial, NSArray<NSValue *> *samples, BOOL lower);
FOUNDATION_EXPORT BOOL IDFloatingCursorHeldCaptureIsAtomic(
    IDFloatingCursorStatus before,
    IDFloatingCursorStatus after,
    IDFloatingCursorObservationPhase beforePhase,
    IDFloatingCursorObservationPhase afterPhase,
    CFTimeInterval screenshotCompletionTime,
    CFTimeInterval afterReadCompletionTime,
    CFTimeInterval liftDeadline);
FOUNDATION_EXPORT BOOL IDFloatingCursorHeldCaptureShouldRetry(
    BOOL retainedAtomicCapture,
    CFTimeInterval now,
    CFTimeInterval liftDeadline);
/// QuartzCore host time: monotonic and comparable to HID schedule deadlines in this process.
FOUNDATION_EXPORT CFTimeInterval IDFloatingCursorMonotonicTime(void);

FOUNDATION_EXPORT BOOL IDFloatingCursorParseStatus(id value,
                                                    IDFloatingCursorStatus *status);
FOUNDATION_EXPORT NSString * _Nullable IDFloatingCursorCopyCanonical(id value);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable
IDFloatingCursorCopyCursorCallback(id value);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable
IDFloatingCursorCopyAutoscrollTrace(id value);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable
IDFloatingCursorCopyLifecycle(id value);
FOUNDATION_EXPORT BOOL IDFloatingCursorTruthSnapshotIsAtomic(id value);
FOUNDATION_EXPORT BOOL IDFloatingCursorNormalPhasesHaveCompleteParity(
    NSArray<NSDictionary<NSString *, id> *> *stockPhases,
    NSArray<NSDictionary<NSString *, id> *> *customPhases);
FOUNDATION_EXPORT BOOL IDFloatingCursorLifecyclePhasesHaveCompleteParity(
    NSArray<NSDictionary<NSString *, id> *> *stockPhases,
    NSArray<NSDictionary<NSString *, id> *> *customPhases,
    NSString * _Nullable actionEvent);
FOUNDATION_EXPORT BOOL IDFloatingCursorTruthPhasesHaveValidChronology(
    NSArray<NSDictionary<NSString *, id> *> *phases, BOOL releaseAttempt);
FOUNDATION_EXPORT BOOL IDFloatingCursorFrameIsValid(CGRect frame);
FOUNDATION_EXPORT XCUIApplication *IDFloatingCursorLaunchCustom(
    XCTestCase *testCase, NSString *scenario);
FOUNDATION_EXPORT XCUIApplication *IDFloatingCursorLaunchCustomWithTruthEvent(
    XCTestCase *testCase, NSString *scenario, NSString * _Nullable terminalEvent,
    NSString * _Nullable actionEvent);
FOUNDATION_EXPORT XCUIApplication *IDFloatingCursorLaunchStock(
    XCTestCase *testCase, NSString *scenario, CGRect editorFrame);
FOUNDATION_EXPORT XCUIApplication *IDFloatingCursorLaunchStockWithTruthEvent(
    XCTestCase *testCase, NSString *scenario, CGRect editorFrame,
    NSString * _Nullable terminalEvent, NSString * _Nullable actionEvent);
FOUNDATION_EXPORT XCUIApplication *IDFloatingCursorLaunchCustomScroll(
    XCTestCase *testCase, BOOL lower, BOOL selectionExtension);
FOUNDATION_EXPORT XCUIApplication *IDFloatingCursorLaunchStockScroll(
    XCTestCase *testCase, CGRect editorFrame, BOOL lower, BOOL selectionExtension);
FOUNDATION_EXPORT CGRect IDFloatingCursorSpacebarFrame(XCTestCase *testCase,
                                                       XCUIApplication *application);
FOUNDATION_EXPORT BOOL IDFloatingCursorWaitForStatus(
    XCUIElement *statusElement,
    NSTimeInterval timeout,
    BOOL (^predicate)(IDFloatingCursorStatus status),
    IDFloatingCursorStatus *result,
    NSString * _Nullable * _Nullable canonicalResult);

NS_ASSUME_NONNULL_END
