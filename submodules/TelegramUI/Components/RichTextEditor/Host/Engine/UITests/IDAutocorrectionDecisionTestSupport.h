@import XCTest;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDAutocorrectionLocation) {
    IDAutocorrectionLocationInterior,
    IDAutocorrectionLocationBeforeBoundary,
    IDAutocorrectionLocationAfterBoundary,
};

typedef NS_ENUM(NSInteger, IDAutocorrectionDecision) {
    IDAutocorrectionDecisionAcceptSpace,
    IDAutocorrectionDecisionAcceptPunctuation,
    IDAutocorrectionDecisionAcceptCandidate,
    IDAutocorrectionDecisionRejectPrecommit,
    IDAutocorrectionDecisionUndoSpace,
    IDAutocorrectionDecisionUndoPunctuation,
    IDAutocorrectionDecisionUndoCandidate,
};

@interface IDAutocorrectionDecisionRow : NSObject
@property(nonatomic, readonly) IDAutocorrectionLocation location;
@property(nonatomic, readonly) IDAutocorrectionDecision decision;
@property(nonatomic, copy, readonly) NSString *identifier;
@end

@interface IDAutocorrectionStatus : NSObject
@property(nonatomic, copy, readonly) NSString *canonical;
@property(nonatomic, copy, readonly) NSArray<NSString *> *blocks;
@property(nonatomic, readonly) NSRange selection;
@property(nonatomic, copy, readonly) NSString *affinity;
@property(nonatomic, readonly) NSRange markedRange;
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *structuralNewlineLocations;
@property(nonatomic, copy, readonly) NSArray<NSValue *> *checkingRanges;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *candidateDescriptor;
@property(nonatomic, copy, readonly) NSArray<NSString *> *mutationTrace;
@property(nonatomic, copy, readonly) NSArray<NSString *> *eventTrace;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *keyboardState;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *correctionGeometry;
@property(nonatomic, copy, readonly) NSString *coordinateSpaceIdentity;
@property(nonatomic, readonly) NSUInteger documentRevision;
@property(nonatomic, readonly) NSUInteger textEpoch;
@property(nonatomic, readonly) NSUInteger selectionEpoch;
@property(nonatomic, readonly) NSUInteger checkingEpoch;
@property(nonatomic, readonly, getter=isFirstResponder) BOOL firstResponder;
@end

@interface IDAutocorrectionPhaseSnapshot : NSObject
@property(nonatomic, copy, readonly) NSString *phase;
@property(nonatomic, strong, readonly) IDAutocorrectionStatus *status;
@property(nonatomic, copy, readonly) NSString *screenshotName;
@end

@interface IDAutocorrectionRunResult : NSObject
@property(nonatomic, strong, readonly) IDAutocorrectionDecisionRow *row;
@property(nonatomic, copy, readonly) NSArray<IDAutocorrectionPhaseSnapshot *> *phases;
@end

FOUNDATION_EXPORT NSString *const IDAutocorrectionStatusErrorDomain;
FOUNDATION_EXPORT NSArray<IDAutocorrectionDecisionRow *> *
IDAutocorrectionDecisionMatrix(void);
FOUNDATION_EXPORT NSArray<IDAutocorrectionDecisionRow *> *
IDAutocorrectionDecisionRowsMatchingIdentifier(NSString * _Nullable identifier);
FOUNDATION_EXPORT IDAutocorrectionStatus * _Nullable
IDParseAutocorrectionStatus(NSString *serializedStatus, NSError **error);
FOUNDATION_EXPORT BOOL IDAutocorrectionCandidateDescriptorIsActionable(
    NSDictionary<NSString *, id> * _Nullable descriptor,
    NSString *expectedCandidate,
    NSError **error);
FOUNDATION_EXPORT BOOL IDAutocorrectionCandidateSignalsAreActionable(
    BOOL candidateExists, BOOL correctionVariantExists);
FOUNDATION_EXPORT XCUIApplication *IDLaunchStockAutocorrectionScenario(
    IDAutocorrectionDecisionRow *row);
FOUNDATION_EXPORT XCUIApplication *IDLaunchCustomAutocorrectionScenario(
    IDAutocorrectionDecisionRow *row);
FOUNDATION_EXPORT IDAutocorrectionPhaseSnapshot *IDCaptureAutocorrectionPhase(
    XCTestCase *testCase, XCUIApplication *application, NSString *phase);
FOUNDATION_EXPORT IDAutocorrectionRunResult *IDRunAutocorrectionDecision(
    XCTestCase *testCase, XCUIApplication *application,
    IDAutocorrectionDecisionRow *row);
FOUNDATION_EXPORT void IDAssertAutocorrectionParity(
    XCTestCase *testCase, IDAutocorrectionRunResult *stock,
    IDAutocorrectionRunResult *custom);

NS_ASSUME_NONNULL_END
