@import XCTest;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDIMELanguage) {
    IDIMELanguageJapaneseRomaji,
    IDIMELanguageSimplifiedChinesePinyin,
};

typedef NS_ENUM(NSInteger, IDIMELocation) {
    IDIMELocationInterior,
    IDIMELocationBeforeBoundary,
    IDIMELocationAfterBoundary,
};

typedef NS_ENUM(NSInteger, IDIMEDecision) {
    IDIMEDecisionCandidateCommit,
    IDIMEDecisionCancel,
    IDIMEDecisionOrdinaryCommit,
    IDIMEDecisionReturnCommitThenUndo,
    IDIMEDecisionResponderLoss,
};

@interface IDIMECompositionRow : NSObject
@property(nonatomic, readonly) IDIMELanguage language;
@property(nonatomic, readonly) IDIMELocation location;
@property(nonatomic, readonly) IDIMEDecision decision;
@property(nonatomic, copy, readonly) NSString *identifier;
@end

@interface IDIMECompositionStatus : NSObject
@property(nonatomic, copy, readonly) NSString *scenario;
@property(nonatomic, copy, readonly) NSString *language;
@property(nonatomic, copy, readonly) NSString *location;
@property(nonatomic, copy, readonly) NSString *decision;
@property(nonatomic, copy, readonly) NSString *canonical;
@property(nonatomic, copy, readonly) NSArray<NSString *> *blocks;
@property(nonatomic, copy, readonly) NSArray<NSString *> *blockIdentifiers;
@property(nonatomic, copy, readonly) NSArray<NSString *> *anchorIdentities;
@property(nonatomic, readonly) NSRange selection;
@property(nonatomic, copy, readonly) NSString *affinity;
@property(nonatomic, readonly) NSRange markedRange;
@property(nonatomic, copy, readonly) NSString *markedText;
@property(nonatomic, readonly) NSRange markedSelection;
@property(nonatomic, copy, readonly) NSArray<NSString *> *markedAttributeKeys;
@property(nonatomic, copy, readonly)
    NSArray<NSNumber *> *structuralNewlineLocations;
@property(nonatomic, copy, readonly) NSArray<NSValue *> *checkingRanges;
@property(nonatomic, copy, readonly)
    NSArray<NSDictionary<NSString *, id> *> *temporaryRenderingDescriptors;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, id> *candidateDescriptor;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, id> *keyboardState;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, id> *compositionGeometry;
@property(nonatomic, copy, readonly) NSArray<NSString *> *mutationTrace;
@property(nonatomic, copy, readonly) NSArray<NSString *> *eventTrace;
@property(nonatomic, copy, readonly) NSString *coordinateSpaceIdentity;
@property(nonatomic, readonly) NSUInteger documentRevision;
@property(nonatomic, readonly) NSUInteger textEpoch;
@property(nonatomic, readonly) NSUInteger selectionEpoch;
@property(nonatomic, readonly) NSUInteger checkingEpoch;
@property(nonatomic, readonly) NSUInteger layoutEpoch;
@property(nonatomic, readonly, getter=isFirstResponder) BOOL firstResponder;
@end

@interface IDIMECompositionPhaseSnapshot : NSObject
@property(nonatomic, copy, readonly) NSString *phase;
@property(nonatomic, strong, readonly) IDIMECompositionStatus *status;
@property(nonatomic, copy, readonly) NSString *screenshotName;
@end

@interface IDIMECompositionRunResult : NSObject
@property(nonatomic, strong, readonly) IDIMECompositionRow *row;
@property(nonatomic, copy, readonly)
    NSArray<IDIMECompositionPhaseSnapshot *> *phases;
@property(nonatomic, copy, readonly) NSArray<NSString *> *decisionActions;
@end

FOUNDATION_EXPORT NSString *const IDIMECompositionStatusErrorDomain;
FOUNDATION_EXPORT NSArray<IDIMECompositionRow *> *
IDIMECompositionMatrix(void);
FOUNDATION_EXPORT NSArray<IDIMECompositionRow *> *
IDIMECompositionRowsMatchingIdentifier(NSString * _Nullable identifier);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDIMECompositionLifecycleDictionary(IDIMECompositionRunResult *result,
                                    NSString *testMethod);
FOUNDATION_EXPORT IDIMECompositionStatus * _Nullable
IDParseIMECompositionStatus(NSString *serializedStatus, NSError **error);
FOUNDATION_EXPORT XCUIApplication *
IDLaunchStockIMECompositionScenario(IDIMECompositionRow *row);
FOUNDATION_EXPORT XCUIApplication *
IDLaunchCustomIMECompositionScenario(IDIMECompositionRow *row);
FOUNDATION_EXPORT IDIMECompositionRunResult *
IDRunIMECompositionLifecycle(XCTestCase *testCase,
                             XCUIApplication *application,
                             IDIMECompositionRow *row);
FOUNDATION_EXPORT void
IDAssertIMECompositionParity(XCTestCase *testCase,
                             IDIMECompositionRunResult *stock,
                             IDIMECompositionRunResult *custom);

NS_ASSUME_NONNULL_END
