#import "IDTextInputDifferentialRunner.h"

#include <math.h>
#import <objc/runtime.h>

#import "IDTextInputTestHost.h"
#import "IDTextInputTransactionDriver.h"

@interface IDTextInputDifference ()
@property(nonatomic, readwrite) NSUInteger transactionIndex;
@property(nonatomic, copy, readwrite) NSString *phase;
@property(nonatomic, copy, readwrite) NSString *fieldPath;
@property(nonatomic, readwrite) IDTextInputHostKind leftHostKind;
@property(nonatomic, readwrite) IDTextInputHostKind rightHostKind;
@property(nonatomic, strong, readwrite, nullable) id leftValue;
@property(nonatomic, strong, readwrite, nullable) id rightValue;
@end

@implementation IDTextInputDifference
@end

@interface IDTextInputDifferentialResult ()
@property(nonatomic, strong, readwrite) IDTextInputScenario *scenario;
@property(nonatomic, readwrite) IDTextInputExecutionOrder order;
@property(nonatomic, copy, readwrite)
    NSArray<NSNumber *> *executedHostKinds;
@property(nonatomic, copy, readwrite)
    NSArray<IDTextInputSnapshot *> *stockSnapshots;
@property(nonatomic, copy, readwrite)
    NSArray<IDTextInputSnapshot *> *referenceSnapshots;
@property(nonatomic, copy, readwrite)
    NSArray<IDTextInputSnapshot *> *minimalSnapshots;
@property(nonatomic, copy, readwrite)
    NSArray<IDTextInputDifference *> *differences;
@end

@implementation IDTextInputDifferentialResult
@end

static const void *IDSnapshotTransactionIndexKey =
    &IDSnapshotTransactionIndexKey;

static void IDSetSnapshotTransactionIndex(IDTextInputSnapshot *snapshot,
                                          NSUInteger index) {
    objc_setAssociatedObject(snapshot, IDSnapshotTransactionIndexKey,
                             @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSUInteger IDSnapshotTransactionIndex(IDTextInputSnapshot *snapshot,
                                             NSUInteger fallback) {
    NSNumber *value =
        objc_getAssociatedObject(snapshot, IDSnapshotTransactionIndexKey);
    return value == nil ? fallback : value.unsignedIntegerValue;
}

static BOOL IDGeometryEqual(id left, id right, CGFloat tolerance) {
    if (left == right) return YES;
    if ([left isKindOfClass:NSNumber.class] &&
        [right isKindOfClass:NSNumber.class]) {
        return fabs([left doubleValue] - [right doubleValue]) <= tolerance;
    }
    if ([left isKindOfClass:NSDictionary.class] &&
        [right isKindOfClass:NSDictionary.class]) {
        NSDictionary *leftDictionary = left;
        NSDictionary *rightDictionary = right;
        if (![[NSSet setWithArray:leftDictionary.allKeys]
              isEqualToSet:[NSSet setWithArray:rightDictionary.allKeys]]) {
            return NO;
        }
        for (id key in leftDictionary) {
            if (!IDGeometryEqual(leftDictionary[key],
                                 rightDictionary[key], tolerance)) {
                return NO;
            }
        }
        return YES;
    }
    if ([left isKindOfClass:NSArray.class] &&
        [right isKindOfClass:NSArray.class]) {
        NSArray *leftArray = left;
        NSArray *rightArray = right;
        if (leftArray.count != rightArray.count) return NO;
        for (NSUInteger index = 0; index < leftArray.count; index++) {
            if (!IDGeometryEqual(leftArray[index], rightArray[index],
                                 tolerance)) {
                return NO;
            }
        }
        return YES;
    }
    return [left isEqual:right];
}

static IDTextInputDifference *IDDifference(
    NSUInteger transactionIndex, NSString *phase, NSString *field,
    IDTextInputHostKind leftHostKind,
    IDTextInputHostKind rightHostKind,
    id leftValue, id rightValue) {
    IDTextInputDifference *difference = [IDTextInputDifference new];
    difference.transactionIndex = transactionIndex;
    difference.phase = phase ?: @"";
    difference.fieldPath = field;
    difference.leftHostKind = leftHostKind;
    difference.rightHostKind = rightHostKind;
    difference.leftValue = leftValue;
    difference.rightValue = rightValue;
    return difference;
}

static IDTextInputDifference *IDCompareTextInputSnapshotPair(
    NSArray<IDTextInputSnapshot *> *left,
    IDTextInputHostKind leftHostKind,
    NSArray<IDTextInputSnapshot *> *right,
    IDTextInputHostKind rightHostKind,
    NSArray<NSString *> *comparisonFields,
    CGFloat geometryTolerance) {
    static NSSet<NSString *> *diagnosticFields;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        diagnosticFields = [NSSet setWithArray:@[
            @"behaviorCapabilities", @"behaviorDetached",
        ]];
    });
    NSUInteger count = MIN(left.count, right.count);
    for (NSUInteger index = 0; index < count; index++) {
        IDTextInputSnapshot *leftSnapshot = left[index];
        IDTextInputSnapshot *rightSnapshot = right[index];
        if (![leftSnapshot.phase isEqualToString:rightSnapshot.phase]) {
            return IDDifference(
                IDSnapshotTransactionIndex(leftSnapshot, index),
                leftSnapshot.phase, @"phase",
                leftHostKind, rightHostKind,
                leftSnapshot.phase, rightSnapshot.phase);
        }
        for (NSString *field in comparisonFields) {
            if ([diagnosticFields containsObject:field]) continue;
            id leftValue = leftSnapshot.state[field];
            id rightValue = rightSnapshot.state[field];
            BOOL geometry = [field isEqualToString:@"caretRect"] ||
                [field isEqualToString:@"selectionRects"];
            BOOL equal = geometry
                ? IDGeometryEqual(leftValue, rightValue,
                                  geometryTolerance)
                : (leftValue == rightValue ||
                   [leftValue isEqual:rightValue]);
            if (!equal) {
                return IDDifference(
                    IDSnapshotTransactionIndex(leftSnapshot, index),
                    leftSnapshot.phase, field,
                    leftHostKind, rightHostKind,
                    leftValue, rightValue);
            }
        }
    }
    if (left.count != right.count) {
        IDTextInputSnapshot *snapshot =
            left.count > count ? left[count] :
            (right.count > count ? right[count] : nil);
        return IDDifference(
            snapshot == nil ? count :
                IDSnapshotTransactionIndex(snapshot, count),
            snapshot.phase, @"checkpoints",
            leftHostKind, rightHostKind,
            @(left.count), @(right.count));
    }
    return nil;
}

IDTextInputDifference *IDCompareTextInputSnapshots(
    NSArray<IDTextInputSnapshot *> *stock,
    NSArray<IDTextInputSnapshot *> *reference,
    NSArray<NSString *> *comparisonFields,
    CGFloat geometryTolerance) {
    return IDCompareTextInputSnapshotPair(
        stock, IDTextInputHostKindStock,
        reference, IDTextInputHostKindReference,
        comparisonFields, geometryTolerance);
}

NSArray<IDTextInputDifference *> *IDCompareTextInputSnapshotTriplet(
    NSArray<IDTextInputSnapshot *> *stock,
    NSArray<IDTextInputSnapshot *> *reference,
    NSArray<IDTextInputSnapshot *> *minimal,
    NSArray<NSString *> *comparisonFields,
    CGFloat geometryTolerance) {
    NSMutableArray<IDTextInputDifference *> *differences =
        [NSMutableArray array];
    IDTextInputDifference *stockReference =
        IDCompareTextInputSnapshotPair(
            stock, IDTextInputHostKindStock,
            reference, IDTextInputHostKindReference,
            comparisonFields, geometryTolerance);
    IDTextInputDifference *stockMinimal =
        IDCompareTextInputSnapshotPair(
            stock, IDTextInputHostKindStock,
            minimal, IDTextInputHostKindMinimal,
            comparisonFields, geometryTolerance);
    IDTextInputDifference *referenceMinimal =
        IDCompareTextInputSnapshotPair(
            reference, IDTextInputHostKindReference,
            minimal, IDTextInputHostKindMinimal,
            comparisonFields, geometryTolerance);
    if (stockReference != nil) [differences addObject:stockReference];
    if (stockMinimal != nil) [differences addObject:stockMinimal];
    if (referenceMinimal != nil) [differences addObject:referenceMinimal];
    return differences.copy;
}

@implementation IDTextInputDifferentialRunner

- (nullable NSArray<IDTextInputSnapshot *> *)executeScenario:
    (IDTextInputScenario *)scenario
                                                    kind:(IDTextInputHostKind)kind
                                                   error:(NSError **)error {
    if (error != NULL) *error = nil;
    NSError *executionError = nil;
    IDTextInputTestHost *host =
        [IDTextInputTestHost hostWithKind:kind
                                 scenario:scenario
                                    error:&executionError];
    if (host == nil) {
        if (error != NULL) *error = executionError;
        return nil;
    }
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    IDTextInputTransactionDriver *driver =
        [[IDTextInputTransactionDriver alloc]
            initWithHost:host recorder:recorder];
    NSMutableArray<IDTextInputSnapshot *> *snapshots =
        [NSMutableArray array];
    for (NSUInteger index = 0;
         index < scenario.transactions.count; index++) {
        IDTextInputTransaction *transaction =
            scenario.transactions[index];
        IDTextInputSnapshot *snapshot =
            [driver applyTransaction:transaction
                               index:index
                               error:&executionError];
        if (executionError != nil) {
            if (error != NULL) *error = executionError;
            [recorder detach];
            return nil;
        }
        if (transaction.kind ==
            IDTextInputTransactionKindCheckpoint) {
            if (snapshot == nil) {
                executionError = [NSError
                    errorWithDomain:IDTextInputTransactionErrorDomain
                               code:2
                           userInfo:@{
                    NSLocalizedDescriptionKey:
                        @"Checkpoint did not produce a snapshot.",
                }];
                if (error != NULL) {
                    *error = executionError;
                }
                [recorder detach];
                return nil;
            }
            IDSetSnapshotTransactionIndex(snapshot, index);
            [snapshots addObject:snapshot];
            [recorder resetTransactionTraces];
        }
    }
    [recorder detach];
    return snapshots.copy;
}

- (IDTextInputDifferentialResult *)runScenario:
    (IDTextInputScenario *)scenario
                                             order:(IDTextInputExecutionOrder)order
                                             error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (scenario == nil ||
        (order != IDTextInputExecutionOrderStockReferenceMinimal &&
         order != IDTextInputExecutionOrderMinimalReferenceStock)) {
        if (error != NULL) {
            *error = [NSError
                errorWithDomain:IDTextInputTransactionErrorDomain
                           code:3
                       userInfo:@{
                NSLocalizedDescriptionKey:
                    @"Scenario or execution order is invalid.",
            }];
        }
        return nil;
    }

    __block NSArray<IDTextInputSnapshot *> *stock = nil;
    __block NSArray<IDTextInputSnapshot *> *reference = nil;
    __block NSArray<IDTextInputSnapshot *> *minimal = nil;
    NSArray<NSNumber *> *executionOrder =
        order == IDTextInputExecutionOrderStockReferenceMinimal
            ? @[
                @(IDTextInputHostKindStock),
                @(IDTextInputHostKindReference),
                @(IDTextInputHostKindMinimal),
            ]
            : @[
                @(IDTextInputHostKindMinimal),
                @(IDTextInputHostKindReference),
                @(IDTextInputHostKindStock),
            ];
    for (NSNumber *kindValue in executionOrder) {
        @autoreleasepool {
            NSError *executionError = nil;
            NSArray *snapshots =
                [self executeScenario:scenario
                                 kind:kindValue.integerValue
                                error:&executionError];
            if (snapshots == nil) {
                if (error != NULL) *error = executionError;
                return nil;
            }
            if (kindValue.integerValue == IDTextInputHostKindStock)
                stock = snapshots;
            else if (kindValue.integerValue == IDTextInputHostKindReference)
                reference = snapshots;
            else
                minimal = snapshots;
        }
    }

    IDTextInputDifferentialResult *result =
        [IDTextInputDifferentialResult new];
    result.scenario = scenario;
    result.order = order;
    result.executedHostKinds = executionOrder;
    result.stockSnapshots = stock;
    result.referenceSnapshots = reference;
    result.minimalSnapshots = minimal;
    result.differences = IDCompareTextInputSnapshotTriplet(
        stock, reference, minimal, scenario.comparisonFields,
        scenario.geometryTolerance);
    return result;
}

@end
