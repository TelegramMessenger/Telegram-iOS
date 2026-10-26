#import "IDTextInputScenario.h"
#import "IDTextInputStateRecorder.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDTextInputDifference : NSObject
@property(nonatomic, readonly) NSUInteger transactionIndex;
@property(nonatomic, copy, readonly) NSString *phase;
@property(nonatomic, copy, readonly) NSString *fieldPath;
@property(nonatomic, readonly) IDTextInputHostKind leftHostKind;
@property(nonatomic, readonly) IDTextInputHostKind rightHostKind;
@property(nonatomic, strong, readonly, nullable) id leftValue;
@property(nonatomic, strong, readonly, nullable) id rightValue;
@end

@interface IDTextInputDifferentialResult : NSObject
@property(nonatomic, strong, readonly) IDTextInputScenario *scenario;
@property(nonatomic, readonly) IDTextInputExecutionOrder order;
@property(nonatomic, copy, readonly)
    NSArray<NSNumber *> *executedHostKinds;
@property(nonatomic, copy, readonly)
    NSArray<IDTextInputSnapshot *> *stockSnapshots;
@property(nonatomic, copy, readonly)
    NSArray<IDTextInputSnapshot *> *referenceSnapshots;
@property(nonatomic, copy, readonly)
    NSArray<IDTextInputSnapshot *> *minimalSnapshots;
@property(nonatomic, copy, readonly)
    NSArray<IDTextInputDifference *> *differences;
@end

FOUNDATION_EXPORT IDTextInputDifference * _Nullable
IDCompareTextInputSnapshots(NSArray<IDTextInputSnapshot *> *stock,
                            NSArray<IDTextInputSnapshot *> *reference,
                            NSArray<NSString *> *comparisonFields,
                            CGFloat geometryTolerance);

FOUNDATION_EXPORT NSArray<IDTextInputDifference *> *
IDCompareTextInputSnapshotTriplet(
    NSArray<IDTextInputSnapshot *> *stock,
    NSArray<IDTextInputSnapshot *> *reference,
    NSArray<IDTextInputSnapshot *> *minimal,
    NSArray<NSString *> *comparisonFields,
    CGFloat geometryTolerance);

@interface IDTextInputDifferentialRunner : NSObject
- (nullable IDTextInputDifferentialResult *)
    runScenario:(IDTextInputScenario *)scenario
          order:(IDTextInputExecutionOrder)order
          error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
