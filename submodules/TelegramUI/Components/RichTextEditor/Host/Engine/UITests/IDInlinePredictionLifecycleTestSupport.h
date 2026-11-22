@import XCTest;

@class IDTextInputBatchObservation;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDInlinePredictionLocation) {
    IDInlinePredictionLocationInterior,
    IDInlinePredictionLocationBeforeBoundary,
    IDInlinePredictionLocationAfterBoundary,
};

typedef NS_ENUM(NSInteger, IDInlinePredictionDecision) {
    IDInlinePredictionDecisionAccept,
    IDInlinePredictionDecisionDismissThenType,
    IDInlinePredictionDecisionAcceptThenDelete,
};

@interface IDInlinePredictionRow : NSObject
@property(nonatomic, readonly) IDInlinePredictionLocation location;
@property(nonatomic, readonly) IDInlinePredictionDecision decision;
@property(nonatomic, copy, readonly) NSString *identifier;
@end

@interface IDInlinePredictionStatus : NSObject
@property(nonatomic, copy, readonly) NSString *canonical;
@property(nonatomic, copy, readonly) NSArray<NSString *> *blocks;
@property(nonatomic, readonly) NSRange selection;
@property(nonatomic, copy, readonly) NSString *affinity;
@property(nonatomic, readonly) NSRange markedRange;
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *structuralNewlineLocations;
@property(nonatomic, copy, readonly) NSArray<NSValue *> *checkingRanges;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *predictionDescriptor;
@property(nonatomic, copy, readonly)
    NSArray<NSDictionary<NSString *, id> *> *temporaryRenderingDescriptors;
@property(nonatomic, copy, readonly) NSArray<NSString *> *mutationTrace;
@property(nonatomic, copy, readonly) NSArray<NSString *> *eventTrace;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *keyboardState;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *predictionGeometry;
@property(nonatomic, copy, readonly) NSString *coordinateSpaceIdentity;
@property(nonatomic, readonly) NSUInteger documentRevision;
@property(nonatomic, readonly) NSUInteger textEpoch;
@property(nonatomic, readonly) NSUInteger selectionEpoch;
@property(nonatomic, readonly) NSUInteger checkingEpoch;
@property(nonatomic, readonly, getter=isFirstResponder) BOOL firstResponder;
@end

@interface IDInlinePredictionPhaseSnapshot : NSObject
@property(nonatomic, copy, readonly) NSString *phase;
@property(nonatomic, strong, readonly) IDInlinePredictionStatus *status;
@property(nonatomic, copy, readonly) NSString *screenshotName;
@property(nonatomic, copy, readonly) NSData *screenshotPNGData;
@end

@interface IDInlinePredictionRunResult : NSObject
@property(nonatomic, strong, readonly) IDInlinePredictionRow *row;
@property(nonatomic, copy, readonly)
    NSArray<IDInlinePredictionPhaseSnapshot *> *phases;
@end

@interface IDInlinePredictionLifecycleAttempt : NSObject
@property(nonatomic, readonly) BOOL offerReady;
@property(nonatomic, strong, readonly, nullable)
    IDInlinePredictionRunResult *result;
@end

FOUNDATION_EXPORT NSString *const IDInlinePredictionStatusErrorDomain;
FOUNDATION_EXPORT NSArray<IDInlinePredictionRow *> *
IDInlinePredictionMatrix(void);
FOUNDATION_EXPORT NSArray<IDInlinePredictionRow *> *
IDInlinePredictionRowsMatchingIdentifier(NSString * _Nullable identifier);
FOUNDATION_EXPORT IDInlinePredictionStatus * _Nullable
IDParseInlinePredictionStatus(NSString *serializedStatus, NSError **error);
FOUNDATION_EXPORT XCUIApplication *
IDLaunchStockInlinePredictionScenario(IDInlinePredictionRow *row);
FOUNDATION_EXPORT XCUIApplication *
IDLaunchCustomInlinePredictionScenario(IDInlinePredictionRow *row);
FOUNDATION_EXPORT IDInlinePredictionRunResult *
IDRunInlinePredictionLifecycle(XCTestCase *testCase,
                               XCUIApplication *application,
                               IDInlinePredictionRow *row);
FOUNDATION_EXPORT IDInlinePredictionLifecycleAttempt *
IDAttemptInlinePredictionLifecycle(XCTestCase *testCase,
                                   XCUIApplication *application,
                                   IDInlinePredictionRow *row);
FOUNDATION_EXPORT BOOL IDWriteInlinePredictionObservationCheckpoint(
    NSURL *directory, IDInlinePredictionRunResult *result,
    IDTextInputBatchObservation *observation, NSUInteger successfulAttempt,
    XCUIApplication *application, NSError **error);

NS_ASSUME_NONNULL_END
