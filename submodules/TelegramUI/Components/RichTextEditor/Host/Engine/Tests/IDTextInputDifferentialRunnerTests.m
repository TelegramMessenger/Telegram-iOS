@import XCTest;

#import "IDTextInputDifferentialRunner.h"
#import "IDTextInputScenario.h"
#import "IDTextInputStateRecorder.h"

@interface IDTextInputSnapshot (IDDifferentialTesting)
@property(nonatomic, copy, readwrite) NSString *phase;
@property(nonatomic, copy, readwrite) NSDictionary<NSString *, id> *state;
@end

@interface IDTextInputScenario (IDDifferentialTesting)
@property(nonatomic, copy, readwrite)
    NSArray<IDTextInputTransaction *> *transactions;
@end

@interface IDTextInputTransaction (IDDifferentialTesting)
@property(nonatomic, readwrite) IDTextInputTransactionKind kind;
@property(nonatomic, copy, readwrite, nullable) NSString *phase;
@end

@interface IDTextInputDifferentialRunnerTests : XCTestCase
@end

@implementation IDTextInputDifferentialRunnerTests

- (IDTextInputSnapshot *)snapshotWithPhase:(NSString *)phase
                                     state:(NSDictionary *)state {
    IDTextInputSnapshot *snapshot = [IDTextInputSnapshot new];
    snapshot.phase = phase;
    snapshot.state = state;
    return snapshot;
}

- (NSDictionary *)baseState {
    return @{
        @"canonical": @"abc",
        @"selection": @{@"location": @1, @"length": @0},
        @"markedRange": @{@"location": @(NSNotFound), @"length": @0},
        @"caretRect": @{@"x": @10, @"y": @20, @"width": @2, @"height": @22},
        @"traits": @{@"keyboardType": @0},
        @"inputDelegateTrace": @[@"textWillChange", @"textDidChange"],
        @"storageMutationTrace": @[
            @{@"editedMask": @1,
              @"range": @{@"location": @1, @"length": @1},
              @"delta": @1},
        ],
    };
}

- (NSArray<IDTextInputSnapshot *> *)snapshots {
    return @[
        [self snapshotWithPhase:@"baseline" state:self.baseState],
        [self snapshotWithPhase:@"firstComposition" state:self.baseState],
        [self snapshotWithPhase:@"updatedComposition" state:self.baseState],
    ];
}

- (NSArray<NSString *> *)allFields {
    return @[
        @"canonical", @"selection", @"markedRange", @"caretRect", @"traits",
        @"inputDelegateTrace", @"storageMutationTrace",
    ];
}

- (NSArray<IDTextInputSnapshot *> *)snapshotsByMutatingField:
    (NSString *)field {
    NSMutableArray<IDTextInputSnapshot *> *snapshots =
        [self.snapshots mutableCopy];
    NSMutableDictionary *state = [snapshots[2].state mutableCopy];
    if ([field isEqualToString:@"canonical"]) {
        state[field] = @"abd";
    } else if ([field isEqualToString:@"selection"] ||
               [field isEqualToString:@"markedRange"]) {
        state[field] = @{@"location": @2, @"length": @0};
    } else if ([field isEqualToString:@"caretRect"]) {
        state[field] = @{@"x": @20, @"y": @20,
                         @"width": @2, @"height": @22};
    } else if ([field isEqualToString:@"traits"]) {
        state[field] = @{@"keyboardType": @7};
    } else if ([field isEqualToString:@"inputDelegateTrace"]) {
        state[field] = @[@"textDidChange", @"textWillChange"];
    } else {
        state[field] = @[];
    }
    snapshots[2] = [self snapshotWithPhase:@"updatedComposition" state:state];
    return snapshots;
}

- (void)testComparatorReportsFirstChangedFieldAtStableCheckpoint {
    for (NSString *field in self.allFields) {
        IDTextInputDifference *difference =
            IDCompareTextInputSnapshots(
                self.snapshots,
                [self snapshotsByMutatingField:field],
                self.allFields, 1.0);
        XCTAssertEqualObjects(difference.fieldPath, field, @"%@", field);
        XCTAssertEqual(difference.transactionIndex, 2U, @"%@", field);
        XCTAssertEqualObjects(difference.phase,
                              @"updatedComposition", @"%@", field);
        XCTAssertEqual(difference.leftHostKind, IDTextInputHostKindStock);
        XCTAssertEqual(difference.rightHostKind, IDTextInputHostKindReference);
        XCTAssertNotEqualObjects(difference.leftValue,
                                 difference.rightValue, @"%@", field);
    }
}

- (NSArray *)selectionRectsAtX:(double)x {
    return @[@{
        @"rect": @{@"x": @(x), @"y": @20, @"width": @50, @"height": @22},
        @"writingDirection": @0,
        @"containsStart": @YES,
        @"containsEnd": @YES,
        @"vertical": @NO,
    }];
}

- (NSArray<IDTextInputSnapshot *> *)snapshotsWithSelectionRectsAtX:(double)x {
    NSMutableArray<IDTextInputSnapshot *> *snapshots =
        [self.snapshots mutableCopy];
    NSMutableDictionary *state = [snapshots[2].state mutableCopy];
    state[@"selectionRects"] = [self selectionRectsAtX:x];
    snapshots[2] = [self snapshotWithPhase:@"updatedComposition" state:state];
    return snapshots;
}

/// `selectionRects` is the one field an engine host and a stock host answer differently by design —
/// this editor fills a covered line where stock hugs the text column — and the harness has no way to
/// tell a correctly filled side from a wrongly filled one. So it is skipped across the stock boundary
/// and stays EXACT between two hosts of our own.
///
/// The third assertion is the one that keeps this narrow: another geometry field still differs across
/// the same boundary. Without it the skip could widen to "geometry is not compared" and this test
/// would keep passing.
- (void)testSelectionRectsIsSkippedOnlyAcrossTheStockBoundaryAndOnlyForThatField {
    NSArray<NSString *> *fields =
        [self.allFields arrayByAddingObject:@"selectionRects"];
    NSArray<IDTextInputSnapshot *> *stock =
        [self snapshotsWithSelectionRectsAtX:10.0];
    NSArray<IDTextInputSnapshot *> *reference =
        [self snapshotsWithSelectionRectsAtX:40.0];
    NSArray<IDTextInputSnapshot *> *minimal =
        [self snapshotsWithSelectionRectsAtX:70.0];

    // Stock against one of ours: the wash divergence is not a difference.
    XCTAssertNil(IDCompareTextInputSnapshots(stock, reference, fields, 1.0));

    // Ours against ours: still exact, and the stock pairs contribute nothing.
    NSArray<IDTextInputDifference *> *differences =
        IDCompareTextInputSnapshotTriplet(stock, reference, minimal,
                                          fields, 1.0);
    XCTAssertEqual(differences.count, 1U);
    XCTAssertEqualObjects(differences.firstObject.fieldPath,
                          @"selectionRects");
    XCTAssertEqual(differences.firstObject.leftHostKind,
                   IDTextInputHostKindReference);
    XCTAssertEqual(differences.firstObject.rightHostKind,
                   IDTextInputHostKindMinimal);

    // THE CONTROL: the skip is one field wide, not "geometry".
    IDTextInputDifference *caret = IDCompareTextInputSnapshots(
        self.snapshots, [self snapshotsByMutatingField:@"caretRect"],
        fields, 1.0);
    XCTAssertEqualObjects(caret.fieldPath, @"caretRect");
    XCTAssertEqual(caret.leftHostKind, IDTextInputHostKindStock);
    XCTAssertEqual(caret.rightHostKind, IDTextInputHostKindReference);
}

- (void)testComparatorHonorsGeometryToleranceButNotCallbackOrdering {
    NSMutableArray<IDTextInputSnapshot *> *near =
        [self.snapshots mutableCopy];
    NSMutableDictionary *nearState = [near[2].state mutableCopy];
    nearState[@"caretRect"] =
        @{@"x": @10.75, @"y": @20, @"width": @2, @"height": @22};
    near[2] = [self snapshotWithPhase:@"updatedComposition"
                                state:nearState];
    XCTAssertNil(IDCompareTextInputSnapshots(
        self.snapshots, near, self.allFields, 1.0));

    NSMutableArray<IDTextInputSnapshot *> *far = [near mutableCopy];
    NSMutableDictionary *farState = [far[2].state mutableCopy];
    farState[@"caretRect"] =
        @{@"x": @11.25, @"y": @20, @"width": @2, @"height": @22};
    far[2] = [self snapshotWithPhase:@"updatedComposition"
                               state:farState];
    XCTAssertEqualObjects(
        IDCompareTextInputSnapshots(
            self.snapshots, far, self.allFields, 1.0).fieldPath,
        @"caretRect");

    NSArray *reordered =
        [self snapshotsByMutatingField:@"inputDelegateTrace"];
    XCTAssertEqualObjects(
        IDCompareTextInputSnapshots(
            self.snapshots, reordered, self.allFields, 1.0).fieldPath,
        @"inputDelegateTrace");
}

- (NSURL *)fixtureURL {
    NSString *testPath = [NSString stringWithUTF8String:__FILE__];
    NSURL *root = [NSURL fileURLWithPath:
        [[testPath stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]
                              isDirectory:YES];
    return [root URLByAppendingPathComponent:
        @"TestFixtures/TextInputScenarios/ime-ios26.5-v1.json"];
}

- (void)testTripletComparatorReportsEveryAffectedPairInStableOrder {
    NSArray *baseline = self.snapshots;
    NSArray *referenceChanged =
        [self snapshotsByMutatingField:@"canonical"];
    NSArray<IDTextInputDifference *> *referenceDifferences =
        IDCompareTextInputSnapshotTriplet(
            baseline, referenceChanged, baseline, self.allFields, 1.0);
    XCTAssertEqual(referenceDifferences.count, 2U);
    XCTAssertEqual(referenceDifferences[0].leftHostKind,
                   IDTextInputHostKindStock);
    XCTAssertEqual(referenceDifferences[0].rightHostKind,
                   IDTextInputHostKindReference);
    XCTAssertEqual(referenceDifferences[1].leftHostKind,
                   IDTextInputHostKindReference);
    XCTAssertEqual(referenceDifferences[1].rightHostKind,
                   IDTextInputHostKindMinimal);

    NSArray *minimalChanged =
        [self snapshotsByMutatingField:@"selection"];
    NSArray<IDTextInputDifference *> *minimalDifferences =
        IDCompareTextInputSnapshotTriplet(
            baseline, baseline, minimalChanged, self.allFields, 1.0);
    XCTAssertEqual(minimalDifferences.count, 2U);
    XCTAssertEqual(minimalDifferences[0].leftHostKind,
                   IDTextInputHostKindStock);
    XCTAssertEqual(minimalDifferences[0].rightHostKind,
                   IDTextInputHostKindMinimal);
    XCTAssertEqual(minimalDifferences[1].leftHostKind,
                   IDTextInputHostKindReference);
    XCTAssertEqual(minimalDifferences[1].rightHostKind,
                   IDTextInputHostKindMinimal);
}

- (void)testCapabilityDiagnosticsNeverEnterSemanticEquality {
    NSMutableArray<IDTextInputSnapshot *> *changed =
        [self.snapshots mutableCopy];
    NSMutableDictionary *state = [changed[0].state mutableCopy];
    state[@"behaviorCapabilities"] = @[@"deliberately-different"];
    state[@"behaviorDetached"] = @YES;
    changed[0] = [self snapshotWithPhase:@"baseline" state:state];
    NSArray *fields = [self.allFields arrayByAddingObjectsFromArray:@[
        @"behaviorCapabilities", @"behaviorDetached",
    ]];
    XCTAssertNil(IDCompareTextInputSnapshots(
        self.snapshots, changed, fields, 1.0));
}

- (void)testRunnerExecutesRepresentativeScenarioInBothOrders {
    NSError *loadError = nil;
    IDTextInputScenario *scenario =
        IDLoadTextInputScenarios(self.fixtureURL, &loadError).firstObject;
    XCTAssertNotNil(scenario, @"%@", loadError);
    IDTextInputDifferentialRunner *runner =
        [IDTextInputDifferentialRunner new];
    for (NSNumber *order in @[
        @(IDTextInputExecutionOrderStockReferenceMinimal),
        @(IDTextInputExecutionOrderMinimalReferenceStock),
    ]) {
        NSError *error = nil;
        IDTextInputDifferentialResult *result =
            [runner runScenario:scenario
                          order:order.integerValue
                          error:&error];
        XCTAssertNotNil(result, @"%@", error);
        XCTAssertEqual(result.scenario, scenario);
        XCTAssertEqual(result.order, order.integerValue);
        NSArray<NSNumber *> *expectedHostKinds =
            order.integerValue ==
                IDTextInputExecutionOrderStockReferenceMinimal
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
        XCTAssertEqualObjects(result.executedHostKinds,
                              expectedHostKinds);
        XCTAssertEqual(
            [NSSet setWithArray:result.executedHostKinds].count, 3U);
        XCTAssertGreaterThan(result.stockSnapshots.count, 0U);
        XCTAssertEqual(result.stockSnapshots.count,
                       result.referenceSnapshots.count);
        XCTAssertEqual(result.stockSnapshots.count,
                       result.minimalSnapshots.count);
        XCTAssertEqual(result.differences.count, 0U, @"%@",
                       result.differences);
    }
}

- (void)testRunnerPairOutputIsIndependentOfExecutionOrder {
    NSError *loadError = nil;
    IDTextInputScenario *scenario =
        IDLoadTextInputScenarios(self.fixtureURL, &loadError).firstObject;
    XCTAssertNotNil(scenario, @"%@", loadError);
    IDTextInputDifferentialRunner *runner =
        [IDTextInputDifferentialRunner new];
    IDTextInputDifferentialResult *forward = [runner
        runScenario:scenario
              order:IDTextInputExecutionOrderStockReferenceMinimal
              error:&loadError];
    IDTextInputDifferentialResult *reverse = [runner
        runScenario:scenario
              order:IDTextInputExecutionOrderMinimalReferenceStock
              error:&loadError];
    XCTAssertNotNil(forward, @"%@", loadError);
    XCTAssertNotNil(reverse, @"%@", loadError);
    XCTAssertEqualObjects([forward.stockSnapshots valueForKey:@"state"],
                          [reverse.stockSnapshots valueForKey:@"state"]);
    XCTAssertEqualObjects([forward.referenceSnapshots valueForKey:@"state"],
                          [reverse.referenceSnapshots valueForKey:@"state"]);
    XCTAssertEqualObjects([forward.minimalSnapshots valueForKey:@"state"],
                          [reverse.minimalSnapshots valueForKey:@"state"]);
    XCTAssertEqualObjects([forward.differences valueForKey:@"fieldPath"],
                          [reverse.differences valueForKey:@"fieldPath"]);
}

- (void)testRunnerFailsClosedWhenCallerDoesNotRequestAnError {
    NSError *loadError = nil;
    IDTextInputScenario *scenario =
        IDLoadTextInputScenarios(self.fixtureURL, &loadError).firstObject;
    XCTAssertNotNil(scenario, @"%@", loadError);
    IDTextInputTransaction *invalid = [IDTextInputTransaction new];
    invalid.kind = IDTextInputTransactionKindInsertText;
    invalid.phase = @"only-checkpoints-may-have-a-phase";
    scenario.transactions = @[invalid];

    IDTextInputDifferentialRunner *runner =
        [IDTextInputDifferentialRunner new];
    XCTAssertNil([runner
        runScenario:scenario
              order:IDTextInputExecutionOrderStockReferenceMinimal
              error:nil]);
}

@end
