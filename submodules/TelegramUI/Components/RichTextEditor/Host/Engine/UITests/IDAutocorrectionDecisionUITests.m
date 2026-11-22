#import "IDAutocorrectionDecisionTestSupport.h"
#import "IDTextInputBatchTestSupport.h"

@interface IDAutocorrectionDecisionUITests : XCTestCase
@end

@implementation IDAutocorrectionDecisionUITests

- (IDAutocorrectionStatus *)waitForAutocorrectionStatus:
    (XCUIElement *)statusElement
                                             canonical:(NSString *)canonical
                                               timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    IDAutocorrectionStatus *last = nil;
    do {
        NSString *serialized =
            [statusElement.value isKindOfClass:NSString.class]
                ? statusElement.value : @"{}";
        last = IDParseAutocorrectionStatus(serialized, nil);
        if ([last.canonical isEqualToString:canonical]) {
            return last;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return last;
}

- (NSArray<NSString *> *)stockCanonicalSequenceForLocation:
    (IDAutocorrectionLocation)location delimiter:(NSString *)delimiter {
    switch (location) {
        case IDAutocorrectionLocationInterior:
            return @[
                @"A quiet  lantern waits.\nSecond block stays unchanged.",
                @"A quiet adress lantern waits.\nSecond block stays unchanged.",
                [NSString stringWithFormat:
                    @"A quiet address%@ lantern waits.\nSecond block stays unchanged.",
                    delimiter],
            ];
        case IDAutocorrectionLocationBeforeBoundary:
            return @[
                @"A quiet \nlantern waits.", @"A quiet adress\nlantern waits.",
                [NSString stringWithFormat:@"A quiet address%@\nlantern waits.",
                                                   delimiter],
            ];
        case IDAutocorrectionLocationAfterBoundary:
            return @[
                @"A quiet scene.\n lantern waits.",
                @"A quiet scene.\nadress lantern waits.",
                [NSString stringWithFormat:@"A quiet scene.\naddress%@ lantern waits.",
                                                   delimiter],
            ];
    }
    return @[];
}

- (void)assertStockAcceptance:(IDAutocorrectionRunResult *)result
                     delimiter:(NSString *)delimiter {
    NSArray<NSString *> *canonical = [self stockCanonicalSequenceForLocation:
        result.row.location delimiter:delimiter];
    NSArray<NSNumber *> *offeredSelections = @[@14, @14, @21];
    NSArray<NSNumber *> *committedSelections = @[@16, @16, @23];
    NSUInteger committedSelection =
        committedSelections[result.row.location].unsignedIntegerValue;
    IDAutocorrectionPhaseSnapshot *baseline = result.phases[0];
    IDAutocorrectionPhaseSnapshot *offered = result.phases[1];
    XCTAssertEqualObjects(baseline.status.canonical, canonical[0]);
    XCTAssertEqualObjects(offered.status.canonical, canonical[1]);
    XCTAssertEqual(offered.status.selection.location,
                   offeredSelections[result.row.location].unsignedIntegerValue);
    XCTAssertEqual(offered.status.selection.length, 0U);
    XCTAssertEqual(offered.status.documentRevision, 6U);
    XCTAssertEqual(offered.status.textEpoch, 6U);
    XCTAssertEqual(offered.status.selectionEpoch, 6U);
    XCTAssertEqual(offered.status.checkingEpoch, 6U);
    for (NSUInteger index = 2; index <= 4; index += 1) {
        IDAutocorrectionStatus *status = result.phases[index].status;
        XCTAssertEqualObjects(status.canonical, canonical[2]);
        XCTAssertEqual(status.selection.location, committedSelection);
        XCTAssertEqual(status.selection.length, 0U);
        XCTAssertEqual(status.documentRevision, 8U);
        XCTAssertEqual(status.textEpoch, 8U);
        XCTAssertEqual(status.selectionEpoch, 8U);
        XCTAssertEqual(status.checkingEpoch, 8U);
        XCTAssertFalse([status.candidateDescriptor[@"actionable"] boolValue]);
        XCTAssertEqualObjects(status.candidateDescriptor[@"candidate"], @"");
    }
    XCTAssertEqualObjects(result.phases[4].status.blocks,
                          [canonical[2] componentsSeparatedByString:@"\n"]);
    XCTAssertEqual(result.phases[4].status.structuralNewlineLocations.count, 1U);
    XCTAssertTrue(result.phases[4].status.isFirstResponder);
}

- (NSString *)stockCandidateCommitForLocation:(IDAutocorrectionLocation)location
                                      original:(BOOL)original {
    NSString *word = original ? @"adress" : @"address";
    switch (location) {
        case IDAutocorrectionLocationInterior:
            return [NSString stringWithFormat:
                @"A quiet %@ lantern waits.\nSecond block stays unchanged.", word];
        case IDAutocorrectionLocationBeforeBoundary:
            return [NSString stringWithFormat:@"A quiet %@ \nlantern waits.", word];
        case IDAutocorrectionLocationAfterBoundary:
            return [NSString stringWithFormat:
                @"A quiet scene.\n%@ lantern waits.", word];
    }
    return @"";
}

- (void)assertStockCandidateDecision:(IDAutocorrectionRunResult *)result
                             original:(BOOL)original {
    NSArray<NSString *> *offered = [self stockCanonicalSequenceForLocation:
        result.row.location delimiter:@""];
    NSArray<NSNumber *> *committedSelections = original
        ? @[@15, @15, @22]
        : @[@16, @16, @23];
    XCTAssertEqualObjects(result.phases[0].status.canonical, offered[0]);
    XCTAssertEqualObjects(result.phases[1].status.canonical, offered[1]);
    NSString *committed = [self stockCandidateCommitForLocation:
        result.row.location original:original];
    for (NSUInteger index = 2; index <= 4; index += 1) {
        IDAutocorrectionStatus *status = result.phases[index].status;
        XCTAssertEqualObjects(status.canonical, committed);
        XCTAssertEqual(status.selection.location,
                       committedSelections[result.row.location].unsignedIntegerValue);
        XCTAssertEqual(status.selection.length, 0U);
        XCTAssertFalse([status.candidateDescriptor[@"actionable"] boolValue]);
        XCTAssertEqualObjects(status.candidateDescriptor[@"candidate"], @"");
        XCTAssertTrue(status.isFirstResponder);
    }
    XCTAssertEqualObjects(result.phases[4].status.blocks,
                          [committed componentsSeparatedByString:@"\n"]);
}

- (void)assertStockImmediateUndo:(IDAutocorrectionRunResult *)result {
    BOOL candidateTap =
        result.row.decision == IDAutocorrectionDecisionUndoCandidate;
    NSArray<NSString *> *afterFirst = candidateTap ? @[
        @"A quiet addresslantern waits.\nSecond block stays unchanged.",
        @"A quiet address\nlantern waits.",
        @"A quiet scene.\naddresslantern waits.",
    ] : @[
        @"A quiet address lantern waits.\nSecond block stays unchanged.",
        @"A quiet address\nlantern waits.",
        @"A quiet scene.\naddress lantern waits.",
    ];
    NSArray<NSString *> *afterSecond = @[
        candidateTap ? @"A quiet addreslantern waits.\nSecond block stays unchanged."
                     : @"A quiet addres lantern waits.\nSecond block stays unchanged.",
        @"A quiet addres\nlantern waits.",
        candidateTap ? @"A quiet scene.\naddreslantern waits."
                     : @"A quiet scene.\naddres lantern waits.",
    ];
    NSArray<NSNumber *> *firstSelections = @[@15, @15, @22];
    IDAutocorrectionStatus *first = result.phases[5].status;
    IDAutocorrectionStatus *second = result.phases[6].status;
    XCTAssertEqualObjects(first.canonical, afterFirst[result.row.location]);
    XCTAssertEqual(first.selection.location,
                   firstSelections[result.row.location].unsignedIntegerValue);
    XCTAssertEqual(first.selection.length, 0U);
    NSArray<NSNumber *> *candidateFirstTextEpochs = @[@10, @9, @10];
    NSArray<NSNumber *> *candidateFirstSelectionEpochs = @[@11, @9, @11];
    NSUInteger firstTextEpoch = candidateTap
        ? candidateFirstTextEpochs[result.row.location].unsignedIntegerValue
        : 9U;
    NSUInteger firstSelectionEpoch = candidateTap
        ? candidateFirstSelectionEpochs[result.row.location].unsignedIntegerValue
        : firstTextEpoch;
    XCTAssertEqual(first.documentRevision, firstTextEpoch);
    XCTAssertEqual(first.textEpoch, firstTextEpoch);
    XCTAssertEqual(first.selectionEpoch, firstSelectionEpoch);
    XCTAssertEqual(first.checkingEpoch, firstTextEpoch);
    XCTAssertFalse([first.candidateDescriptor[@"actionable"] boolValue]);
    XCTAssertEqualObjects(first.candidateDescriptor[@"candidate"], @"");
    NSError *candidateError = nil;
    XCTAssertTrue(IDAutocorrectionCandidateDescriptorIsActionable(
        second.candidateDescriptor, @"address", &candidateError), @"%@",
        candidateError.localizedDescription);
    XCTAssertEqualObjects(second.canonical, afterSecond[result.row.location]);
    XCTAssertEqual(second.selection.location,
                   firstSelections[result.row.location].unsignedIntegerValue - 1);
    XCTAssertEqual(second.selection.length, 0U);
    XCTAssertEqual(second.documentRevision, firstTextEpoch + 1);
    XCTAssertEqual(second.textEpoch, firstTextEpoch + 1);
    XCTAssertEqual(second.selectionEpoch, firstSelectionEpoch + 1);
    XCTAssertEqual(second.checkingEpoch, firstTextEpoch + 1);
    XCTAssertTrue(first.isFirstResponder);
    XCTAssertTrue(second.isFirstResponder);
}

- (void)assertRejectionSurvivesFollowingSpace:(IDAutocorrectionRunResult *)result
                                stockChronology:(BOOL)stockChronology {
    NSArray<NSString *> *canonical = @[
        @"A quiet adress  lantern waits.\nSecond block stays unchanged.",
        @"A quiet adress \nlantern waits.",
        @"A quiet scene.\nadress  lantern waits.",
    ];
    NSArray<NSNumber *> *selections = @[@16, @15, @23];
    NSArray<NSNumber *> *textEpochs = @[@9, @8, @9];
    NSArray<NSNumber *> *selectionEpochs = @[@10, @8, @10];
    NSArray<NSNumber *> *documentRevisions = stockChronology
        ? textEpochs : @[@9, @9, @9];
    IDAutocorrectionStatus *status = result.phases[5].status;
    XCTAssertEqualObjects(result.phases[5].phase, @"postRejectionSpace");
    XCTAssertEqualObjects(status.canonical, canonical[result.row.location]);
    XCTAssertEqual(status.selection.location,
                   selections[result.row.location].unsignedIntegerValue);
    XCTAssertEqual(status.selection.length, 0U);
    XCTAssertEqual(status.documentRevision,
                   documentRevisions[result.row.location].unsignedIntegerValue);
    XCTAssertEqual(status.textEpoch,
                   textEpochs[result.row.location].unsignedIntegerValue);
    XCTAssertEqual(status.selectionEpoch,
                   selectionEpochs[result.row.location].unsignedIntegerValue);
    XCTAssertEqual(status.checkingEpoch,
                   textEpochs[result.row.location].unsignedIntegerValue);
    XCTAssertFalse([status.candidateDescriptor[@"actionable"] boolValue]);
    XCTAssertEqualObjects(status.candidateDescriptor[@"candidate"], @"");
    XCTAssertTrue(status.isFirstResponder);
}

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

- (void)testStockKeyboardWarmupOnly {
    IDAutocorrectionDecisionRow *row = IDAutocorrectionDecisionMatrix().firstObject;
    XCUIApplication *application = IDLaunchStockAutocorrectionScenario(row);
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"autocorrection-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    XCTAssertEqual(application.keyboards.keys[@"t"].exists, YES);
    XCTAssertEqualObjects(editor.value,
        @"A quiet  lantern waits.\nSecond block stays unchanged.");
}


- (void)assertExpectedResult:(IDAutocorrectionRunResult *)result
              stockChronology:(BOOL)stockChronology {
    IDAutocorrectionDecision decision = result.row.decision;
    NSArray<NSString *> *expectedPhases =
        decision >= IDAutocorrectionDecisionUndoSpace
            ? @[@"baseline", @"offered", @"decision", @"immediate",
                @"quiesced", @"firstBackspace", @"secondBackspace"]
            : decision == IDAutocorrectionDecisionRejectPrecommit
            ? @[@"baseline", @"offered", @"decision", @"immediate",
                @"quiesced", @"postRejectionSpace"]
            : @[@"baseline", @"offered", @"decision", @"immediate",
                @"quiesced"];
    XCTAssertEqualObjects([result.phases valueForKey:@"phase"], expectedPhases);
    IDAutocorrectionPhaseSnapshot *baseline = result.phases.firstObject;
    IDAutocorrectionPhaseSnapshot *offered = result.phases[1];
    XCTAssertTrue(baseline.status.isFirstResponder);
    NSError *candidateError = nil;
    XCTAssertTrue(IDAutocorrectionCandidateDescriptorIsActionable(
        offered.status.candidateDescriptor, @"address", &candidateError), @"%@",
        candidateError.localizedDescription);
    XCTAssertGreaterThan(offered.screenshotName.length, 0U);
    if (decision == IDAutocorrectionDecisionAcceptSpace ||
        decision == IDAutocorrectionDecisionUndoSpace) {
        [self assertStockAcceptance:result delimiter:@" "];
    } else if (decision == IDAutocorrectionDecisionAcceptPunctuation ||
               decision == IDAutocorrectionDecisionUndoPunctuation) {
        [self assertStockAcceptance:result delimiter:@"."];
    } else if (decision == IDAutocorrectionDecisionAcceptCandidate ||
               decision == IDAutocorrectionDecisionUndoCandidate) {
        [self assertStockCandidateDecision:result original:NO];
    } else {
        [self assertStockCandidateDecision:result original:YES];
    }
    if (decision >= IDAutocorrectionDecisionUndoSpace) {
        [self assertStockImmediateUndo:result];
    } else if (decision == IDAutocorrectionDecisionRejectPrecommit) {
        [self assertRejectionSurvivesFollowingSpace:result
                                    stockChronology:stockChronology];
    }
}

- (void)runStockTruthForLocation:(IDAutocorrectionLocation)location
                         decision:(IDAutocorrectionDecision)decision {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(IDAutocorrectionDecisionRow *row, NSDictionary *bindings) {
            (void)bindings;
            return row.location == location && row.decision == decision;
        }];
    NSArray<IDAutocorrectionDecisionRow *> *rows =
        [IDAutocorrectionDecisionMatrix() filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(rows.count, 1U);
    for (IDAutocorrectionDecisionRow *row in rows) {
        [XCTContext runActivityNamed:row.identifier block:^(id<XCTActivity> activity) {
            (void)activity;
            XCUIApplication *application = IDLaunchStockAutocorrectionScenario(row);
            IDAutocorrectionRunResult *result =
                IDRunAutocorrectionDecision(self, application, row);
            XCTAssertEqualObjects(result.row.identifier, row.identifier);
            [self assertExpectedResult:result stockChronology:YES];
        }];
    }
}

- (void)runCustomAcceptanceForLocation:(IDAutocorrectionLocation)location
                              decision:(IDAutocorrectionDecision)decision
                             delimiter:(NSString *)delimiter
                                minimal:(BOOL)minimal {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(IDAutocorrectionDecisionRow *candidate, NSDictionary *bindings) {
            (void)bindings;
            return candidate.location == location && candidate.decision == decision;
        }];
    IDAutocorrectionDecisionRow *row = [[IDAutocorrectionDecisionMatrix()
        filteredArrayUsingPredicate:predicate] firstObject];
    XCTAssertNotNil(row);
    XCUIApplication *application = IDLaunchCustomAutocorrectionScenario(row);
    if (minimal) {
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
        NSData *data =
            [serialized dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *payload = [NSJSONSerialization
            JSONObjectWithData:data options:0 error:nil];
        XCTAssertEqualObjects(payload[@"backend"], @"minimal");
        XCTAssertEqualObjects(payload[@"report"][@"detached"], @NO);
        NSArray *capabilities = payload[@"report"][@"capabilities"];
        NSPredicate *activeInput = [NSPredicate predicateWithFormat:
            @"identifier == %@ AND state == %@",
            @"inputController", @"active"];
        XCTAssertEqual(
            [capabilities filteredArrayUsingPredicate:activeInput].count,
            1U);
    }
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"autocorrection-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    IDAutocorrectionRunResult *result =
        IDRunAutocorrectionDecision(self, application, row);
    (void)delimiter;
    [self assertExpectedResult:result stockChronology:NO];
}

- (void)runCustomAcceptanceForLocation:(IDAutocorrectionLocation)location
                              decision:(IDAutocorrectionDecision)decision
                             delimiter:(NSString *)delimiter {
    [self runCustomAcceptanceForLocation:location
                                decision:decision
                               delimiter:delimiter
                                  minimal:NO];
}

- (void)runCertificationRow:(IDAutocorrectionDecisionRow *)row
                       host:(IDTextInputBatchHost)host {
    XCUIApplication *application = host == IDTextInputBatchHostStock
        ? IDLaunchStockAutocorrectionScenario(row)
        : IDLaunchCustomAutocorrectionScenario(row);
    @try {
        IDAutocorrectionRunResult *result =
            IDRunAutocorrectionDecision(self, application, row);
        XCTAssertEqualObjects(result.row.identifier, row.identifier);
        [self assertExpectedResult:result
                   stockChronology:host == IDTextInputBatchHostStock];
    } @finally {
        IDAttachTextInputBatchHierarchy(self, application);
        [application terminate];
    }
}

- (void)testBatchedCertification {
    IDTextInputGroup *group =
        IDLoadSelectedTextInputGroup(self, @"autocorrection");
    XCTAssertNotNil(group);
    if (group == nil) return;
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            NSArray<IDAutocorrectionDecisionRow *> *rows =
                IDAutocorrectionDecisionRowsMatchingIdentifier(
                    observation.rowIdentifier);
            XCTAssertEqual(rows.count, 1U);
            if (rows.count != 1) return;
            [self runCertificationRow:rows.firstObject
                                 host:observation.host];
        },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            return IDCrossSelectedTextInputGroupBoundary(
                self, group, boundary);
        });
}

- (void)testCustomInteriorAcceptSpaceMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationInterior
        decision:IDAutocorrectionDecisionAcceptSpace delimiter:@" "];
}

- (void)testCustomInteriorAcceptPunctuationMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationInterior
        decision:IDAutocorrectionDecisionAcceptPunctuation delimiter:@"."];
}

- (void)testCustomInteriorAcceptCandidateMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationInterior
        decision:IDAutocorrectionDecisionAcceptCandidate delimiter:@""];
}

- (void)testCustomBeforeBoundaryAcceptSpaceMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationBeforeBoundary
        decision:IDAutocorrectionDecisionAcceptSpace delimiter:@" "];
}

- (void)testCustomBeforeBoundaryAcceptPunctuationMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationBeforeBoundary
        decision:IDAutocorrectionDecisionAcceptPunctuation delimiter:@"."];
}

- (void)testCustomBeforeBoundaryAcceptCandidateMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationBeforeBoundary
        decision:IDAutocorrectionDecisionAcceptCandidate delimiter:@""];
}

- (void)testCustomAfterBoundaryAcceptSpaceMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationAfterBoundary
        decision:IDAutocorrectionDecisionAcceptSpace delimiter:@" "];
}

- (void)testCustomAfterBoundaryAcceptPunctuationMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationAfterBoundary
        decision:IDAutocorrectionDecisionAcceptPunctuation delimiter:@"."];
}

- (void)testCustomAfterBoundaryAcceptCandidateMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationAfterBoundary
        decision:IDAutocorrectionDecisionAcceptCandidate delimiter:@""];
}

- (void)testCustomInteriorRejectPrecommitMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationInterior
        decision:IDAutocorrectionDecisionRejectPrecommit delimiter:@""];
}

- (void)testCustomBeforeBoundaryRejectPrecommitMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationBeforeBoundary
        decision:IDAutocorrectionDecisionRejectPrecommit delimiter:@""];
}

- (void)testMinimalInteriorAcceptSpaceMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationInterior
        decision:IDAutocorrectionDecisionAcceptSpace
        delimiter:@" " minimal:YES];
}

- (void)testMinimalBeforeBoundaryRejectPrecommitMatchesStock {
    [self runCustomAcceptanceForLocation:
        IDAutocorrectionLocationBeforeBoundary
        decision:IDAutocorrectionDecisionRejectPrecommit
        delimiter:@"" minimal:YES];
}

- (void)testCustomAfterBoundaryRejectPrecommitMatchesStock {
    [self runCustomAcceptanceForLocation:IDAutocorrectionLocationAfterBoundary
        decision:IDAutocorrectionDecisionRejectPrecommit delimiter:@""];
}

#define ID_CUSTOM_UNDO_TEST(methodName, locationValue, decisionValue, delimiterValue) \
    - (void)methodName { \
        [self runCustomAcceptanceForLocation:locationValue \
            decision:decisionValue delimiter:delimiterValue]; \
    }

ID_CUSTOM_UNDO_TEST(testCustomInteriorUndoSpaceMatchesStock,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionUndoSpace, @" ")
ID_CUSTOM_UNDO_TEST(testCustomInteriorUndoPunctuationMatchesStock,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionUndoPunctuation, @".")
ID_CUSTOM_UNDO_TEST(testCustomInteriorUndoCandidateMatchesStock,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionUndoCandidate, @"")
ID_CUSTOM_UNDO_TEST(testCustomBeforeBoundaryUndoSpaceMatchesStock,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionUndoSpace, @" ")
ID_CUSTOM_UNDO_TEST(testCustomBeforeBoundaryUndoPunctuationMatchesStock,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionUndoPunctuation, @".")
ID_CUSTOM_UNDO_TEST(testCustomBeforeBoundaryUndoCandidateMatchesStock,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionUndoCandidate, @"")
ID_CUSTOM_UNDO_TEST(testCustomAfterBoundaryUndoSpaceMatchesStock,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionUndoSpace, @" ")
ID_CUSTOM_UNDO_TEST(testCustomAfterBoundaryUndoPunctuationMatchesStock,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionUndoPunctuation, @".")
ID_CUSTOM_UNDO_TEST(testCustomAfterBoundaryUndoCandidateMatchesStock,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionUndoCandidate, @"")

#undef ID_CUSTOM_UNDO_TEST

#define ID_STOCK_TRUTH_TEST(methodName, locationValue, decisionValue) \
    - (void)methodName { \
        [self runStockTruthForLocation:locationValue decision:decisionValue]; \
    }

ID_STOCK_TRUTH_TEST(testStockInteriorAcceptSpaceTruth,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionAcceptSpace)
ID_STOCK_TRUTH_TEST(testStockInteriorAcceptPunctuationTruth,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionAcceptPunctuation)
ID_STOCK_TRUTH_TEST(testStockInteriorAcceptCandidateTruth,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionAcceptCandidate)
ID_STOCK_TRUTH_TEST(testStockInteriorRejectPrecommitTruth,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionRejectPrecommit)
ID_STOCK_TRUTH_TEST(testStockInteriorUndoSpaceTruth,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionUndoSpace)
ID_STOCK_TRUTH_TEST(testStockInteriorUndoPunctuationTruth,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionUndoPunctuation)
ID_STOCK_TRUTH_TEST(testStockInteriorUndoCandidateTruth,
    IDAutocorrectionLocationInterior, IDAutocorrectionDecisionUndoCandidate)

ID_STOCK_TRUTH_TEST(testStockBeforeBoundaryAcceptSpaceTruth,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionAcceptSpace)
ID_STOCK_TRUTH_TEST(testStockBeforeBoundaryAcceptPunctuationTruth,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionAcceptPunctuation)
ID_STOCK_TRUTH_TEST(testStockBeforeBoundaryAcceptCandidateTruth,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionAcceptCandidate)
ID_STOCK_TRUTH_TEST(testStockBeforeBoundaryRejectPrecommitTruth,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionRejectPrecommit)
ID_STOCK_TRUTH_TEST(testStockBeforeBoundaryUndoSpaceTruth,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionUndoSpace)
ID_STOCK_TRUTH_TEST(testStockBeforeBoundaryUndoPunctuationTruth,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionUndoPunctuation)
ID_STOCK_TRUTH_TEST(testStockBeforeBoundaryUndoCandidateTruth,
    IDAutocorrectionLocationBeforeBoundary, IDAutocorrectionDecisionUndoCandidate)

ID_STOCK_TRUTH_TEST(testStockAfterBoundaryAcceptSpaceTruth,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionAcceptSpace)
ID_STOCK_TRUTH_TEST(testStockAfterBoundaryAcceptPunctuationTruth,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionAcceptPunctuation)
ID_STOCK_TRUTH_TEST(testStockAfterBoundaryAcceptCandidateTruth,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionAcceptCandidate)
ID_STOCK_TRUTH_TEST(testStockAfterBoundaryRejectPrecommitTruth,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionRejectPrecommit)
ID_STOCK_TRUTH_TEST(testStockAfterBoundaryUndoSpaceTruth,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionUndoSpace)
ID_STOCK_TRUTH_TEST(testStockAfterBoundaryUndoPunctuationTruth,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionUndoPunctuation)
ID_STOCK_TRUTH_TEST(testStockAfterBoundaryUndoCandidateTruth,
    IDAutocorrectionLocationAfterBoundary, IDAutocorrectionDecisionUndoCandidate)

#undef ID_STOCK_TRUTH_TEST

@end
