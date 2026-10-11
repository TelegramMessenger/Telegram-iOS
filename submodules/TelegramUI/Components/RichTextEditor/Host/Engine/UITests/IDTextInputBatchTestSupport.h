@import XCTest;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDTextInputBatchHost) {
    IDTextInputBatchHostStock,
    IDTextInputBatchHostCustom,
};

@interface IDTextInputBatchObservation : NSObject
@property(nonatomic, copy, readonly) NSString *rowIdentifier;
@property(nonatomic, copy, readonly) NSString *batchIdentifier;
@property(nonatomic, readonly) IDTextInputBatchHost host;
@property(nonatomic, copy, readonly) NSString *identity;
@end

@interface IDTextInputBatch : NSObject
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *subsystem;
@property(nonatomic, copy, readonly)
    NSArray<IDTextInputBatchObservation *> *observations;
@property(nonatomic, readonly, getter=isStateSensitive) BOOL stateSensitive;
@end

@interface IDTextInputGroup : NSObject
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *subsystem;
@property(nonatomic, copy, readonly) NSArray<IDTextInputBatch *> *batches;
@property(nonatomic, readonly, getter=isStateSensitive) BOOL stateSensitive;
@end

typedef NS_ENUM(NSInteger, IDTextInputGroupBoundaryKind) {
    IDTextInputGroupBoundaryKindRow,
    IDTextInputGroupBoundaryKindPass,
    IDTextInputGroupBoundaryKindHost,
};

typedef NS_ENUM(NSInteger, IDTextInputObservationAttemptOutcome) {
    IDTextInputObservationAttemptCompleted,
    IDTextInputObservationAttemptReadinessUnavailable,
};

typedef NS_ENUM(NSInteger, IDTextInputObservationEventKind) {
    IDTextInputObservationEventStarted,
    IDTextInputObservationEventRetryRequired,
    IDTextInputObservationEventOfferReady,
    IDTextInputObservationEventComplete,
};

@interface IDTextInputGroupBoundary : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property(nonatomic, readonly) IDTextInputGroupBoundaryKind kind;
@property(nonatomic, readonly) NSUInteger sequenceIndex;
@property(nonatomic, copy, readonly, nullable) NSString *batchIdentifier;
@property(nonatomic, copy, readonly, nullable) NSString *rowIdentifier;
@property(nonatomic, copy, readonly, nullable) NSString *completedHost;
@property(nonatomic, copy, readonly, nullable) NSString *nextHost;
@property(nonatomic, copy, readonly, nullable) NSString *completedRowIdentifier;
@property(nonatomic, copy, readonly, nullable) NSString *nextRowIdentifier;
@property(nonatomic, copy, readonly, nullable) NSString *completedBatchIdentifier;
@property(nonatomic, copy, readonly, nullable) NSString *nextBatchIdentifier;
@end

FOUNDATION_EXPORT NSString *const IDTextInputBatchErrorDomain;

FOUNDATION_EXPORT IDTextInputBatch * _Nullable
IDLoadTextInputBatchFromData(NSData *data, NSString *batchIdentifier,
                             NSError **error);
FOUNDATION_EXPORT IDTextInputGroup * _Nullable
IDLoadTextInputGroupFromData(NSData *data, NSString *groupIdentifier,
                             NSError **error);
FOUNDATION_EXPORT IDTextInputBatch * _Nullable
IDLoadSelectedTextInputBatch(XCTestCase *testCase, NSString *subsystem);
FOUNDATION_EXPORT IDTextInputGroup * _Nullable
IDLoadSelectedTextInputGroup(XCTestCase *testCase, NSString *subsystem);
FOUNDATION_EXPORT NSURL * _Nullable IDTextInputGroupHandshakeDirectory(
    NSURL * _Nullable dataContainerRoot, NSString *token, NSError **error);
FOUNDATION_EXPORT NSString * _Nullable
IDTextInputGroupTokenSHA256(NSString *token);
FOUNDATION_EXPORT BOOL IDWriteTextInputGroupBoundaryRequest(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    IDTextInputGroupBoundary *boundary, NSError **error);
FOUNDATION_EXPORT BOOL IDWaitForTextInputGroupBoundaryResponse(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    IDTextInputGroupBoundary *boundary, NSTimeInterval timeout,
    NSError **error);
FOUNDATION_EXPORT void IDRunTextInputBatch(
    XCTestCase *testCase, IDTextInputBatch *batch,
    void (^runObservation)(IDTextInputBatchObservation *observation));
FOUNDATION_EXPORT void IDRunTextInputGroup(
    XCTestCase *testCase, IDTextInputGroup *group,
    void (^runObservation)(IDTextInputBatchObservation *observation),
    BOOL (^crossBoundary)(IDTextInputGroupBoundary *boundary));
FOUNDATION_EXPORT void IDRunSnapshotTextInputGroup(
    XCTestCase *testCase, IDTextInputGroup *group,
    NSUInteger maximumReadinessAttempts,
    NSIndexSet *completedObservationIndexes,
    IDTextInputObservationAttemptOutcome (^runAttempt)(
        IDTextInputBatchObservation *observation, NSUInteger attempt),
    BOOL (^handleEvent)(IDTextInputObservationEventKind kind,
                        IDTextInputBatchObservation *observation,
                        NSUInteger attempt,
                        IDTextInputGroupBoundary * _Nullable precedingBoundary));
FOUNDATION_EXPORT NSIndexSet * _Nullable
IDLoadTextInputCompletedObservationIndexes(void);
FOUNDATION_EXPORT BOOL IDWriteTextInputObservationEvent(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    NSUInteger eventIndex, NSUInteger observationIndex,
    IDTextInputObservationEventKind kind,
    IDTextInputBatchObservation *observation, NSUInteger attempt,
    IDTextInputGroupBoundary * _Nullable precedingBoundary, NSError **error);
FOUNDATION_EXPORT BOOL IDWaitForTextInputObservationRestoreResponse(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    NSUInteger eventIndex, NSUInteger observationIndex,
    IDTextInputObservationEventKind preparationKind,
    IDTextInputBatchObservation *observation, NSUInteger attempt,
    IDTextInputGroupBoundary * _Nullable precedingBoundary,
    NSTimeInterval timeout, NSError **error);
FOUNDATION_EXPORT BOOL IDCrossSelectedTextInputGroupBoundary(
    XCTestCase *testCase, IDTextInputGroup *group,
    IDTextInputGroupBoundary *boundary);
FOUNDATION_EXPORT void IDWithTextInputBatch(
    IDTextInputBatch *batch, dispatch_block_t block);
FOUNDATION_EXPORT void IDWithTextInputBatchObservation(
    IDTextInputBatchObservation *observation, dispatch_block_t block);
FOUNDATION_EXPORT NSString *IDTextInputBatchAttachmentName(NSString *name);
FOUNDATION_EXPORT void IDAttachTextInputBatchHierarchy(
    XCTestCase *testCase, XCUIApplication *application);

NS_ASSUME_NONNULL_END
