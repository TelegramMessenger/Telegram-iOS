#import "IDInlinePredictionLifecycleTestSupport.h"
#import "IDTextInputBatchTestSupport.h"

@interface IDInlinePredictionLifecycleUITests : XCTestCase
@end

@implementation IDInlinePredictionLifecycleUITests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

- (IDInlinePredictionRow *)rowAtLocation:(IDInlinePredictionLocation)location
                                decision:(IDInlinePredictionDecision)decision {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(IDInlinePredictionRow *row, NSDictionary *bindings) {
            (void)bindings;
            return row.location == location && row.decision == decision;
        }];
    NSArray<IDInlinePredictionRow *> *rows =
        [IDInlinePredictionMatrix() filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(rows.count, 1U);
    return rows.firstObject;
}

- (void)assertStockResult:(IDInlinePredictionRunResult *)result
                 location:(IDInlinePredictionLocation)location
                 decision:(IDInlinePredictionDecision)decision {
    NSArray<NSString *> *expected = decision ==
        IDInlinePredictionDecisionDismissThenType
        ? @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced",
            @"postDismissTyping"]
        : decision == IDInlinePredictionDecisionAcceptThenDelete
        ? @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced",
            @"firstBackspace", @"secondBackspace"]
        : @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced"];
    XCTAssertEqualObjects([result.phases valueForKey:@"phase"], expected);
    XCTAssertTrue(
        [result.phases[1].status.predictionDescriptor[@"present"] boolValue]);
    XCTAssertEqualObjects(
        result.phases[1].status.predictionDescriptor[@"displayText"], @"to");
    XCTAssertTrue(NSEqualRanges(
        result.phases[1].status.markedRange, NSMakeRange(33, 2)));

    BOOL isInterior = location == IDInlinePredictionLocationInterior;
    BOOL isAfter = location == IDInlinePredictionLocationAfterBoundary;
    NSString *accepted = isInterior
        ? @"Earlier sentence. I look forward to  \nLater block stays."
        : isAfter
        ? @"Earlier sentence.\nI look forward to  \nLater block stays."
        : @"Earlier sentence. I look forward to \nLater block stays.";
    NSString *dismissed = isInterior
        ? @"Earlier sentence. I look forward  \nLater block stays."
        : isAfter
        ? @"Earlier sentence.\nI look forward  \nLater block stays."
        : @"Earlier sentence. I look forward \nLater block stays.";
    IDInlinePredictionStatus *decisionStatus = result.phases[2].status;
    XCTAssertEqualObjects(
        decisionStatus.canonical,
        decision == IDInlinePredictionDecisionDismissThenType
            ? dismissed : accepted);
    XCTAssertTrue(NSEqualRanges(
        decisionStatus.selection,
        NSMakeRange(
            decision == IDInlinePredictionDecisionDismissThenType ? 33 : 36,
            0)));
    XCTAssertEqual(decisionStatus.markedRange.location, NSNotFound);
    XCTAssertFalse(
        [decisionStatus.predictionDescriptor[@"present"] boolValue]);

    if (decision == IDInlinePredictionDecisionAcceptThenDelete) {
        NSString *firstBackspace = isInterior
            ? @"Earlier sentence. I look forward to \nLater block stays."
            : isAfter
            ? @"Earlier sentence.\nI look forward to \nLater block stays."
            : @"Earlier sentence. I look forward to\nLater block stays.";
        NSString *secondBackspace = isInterior
            ? @"Earlier sentence. I look forward t \nLater block stays."
            : isAfter
            ? @"Earlier sentence.\nI look forward t \nLater block stays."
            : @"Earlier sentence. I look forward t\nLater block stays.";
        XCTAssertEqualObjects(result.phases[5].status.canonical,
                              firstBackspace);
        XCTAssertEqualObjects(result.phases[6].status.canonical,
                              secondBackspace);
    }
}

- (void)runStockTruthAtLocation:(IDInlinePredictionLocation)location
                       decision:(IDInlinePredictionDecision)decision {
    IDInlinePredictionRow *row =
        [self rowAtLocation:location decision:decision];
    XCUIApplication *application =
        IDLaunchStockInlinePredictionScenario(row);
    IDInlinePredictionRunResult *result =
        IDRunInlinePredictionLifecycle(self, application, row);
    [self assertStockResult:result location:location decision:decision];
}

- (void)testStockInteriorAcceptTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationInterior
                        decision:IDInlinePredictionDecisionAccept];
}

- (void)testStockInteriorDismissThenTypeTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationInterior
                        decision:IDInlinePredictionDecisionDismissThenType];
}

- (void)testStockInteriorAcceptThenDeleteTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationInterior
                        decision:IDInlinePredictionDecisionAcceptThenDelete];
}

- (void)testStockBeforeBoundaryAcceptTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationBeforeBoundary
                        decision:IDInlinePredictionDecisionAccept];
}

- (void)testStockBeforeBoundaryDismissThenTypeTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationBeforeBoundary
                        decision:IDInlinePredictionDecisionDismissThenType];
}

- (void)testStockBeforeBoundaryAcceptThenDeleteTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationBeforeBoundary
                        decision:IDInlinePredictionDecisionAcceptThenDelete];
}

- (void)testStockAfterBoundaryAcceptTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationAfterBoundary
                        decision:IDInlinePredictionDecisionAccept];
}

- (void)testStockAfterBoundaryDismissThenTypeTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationAfterBoundary
                        decision:IDInlinePredictionDecisionDismissThenType];
}

- (void)testStockAfterBoundaryAcceptThenDeleteTruth {
    [self runStockTruthAtLocation:IDInlinePredictionLocationAfterBoundary
                        decision:IDInlinePredictionDecisionAcceptThenDelete];
}

- (XCUIApplication *)launchCustomRow:(IDInlinePredictionRow *)row
                              minimal:(BOOL)minimal {
    XCUIApplication *application =
        IDLaunchCustomInlinePredictionScenario(row);
    if (!minimal) return application;
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
    NSPredicate *activePrediction = [NSPredicate predicateWithFormat:
        @"identifier == %@ AND state == %@",
        @"prediction", @"active"];
    XCTAssertEqual(
        [payload[@"report"][@"capabilities"]
            filteredArrayUsingPredicate:activePrediction].count,
        1U);
    return application;
}

- (void)assertCustomInteriorResult:(IDInlinePredictionRunResult *)result
                          decision:(IDInlinePredictionDecision)decision {
    NSArray<NSString *> *expected = decision ==
        IDInlinePredictionDecisionDismissThenType
        ? @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced",
            @"postDismissTyping"]
        : decision == IDInlinePredictionDecisionAcceptThenDelete
        ? @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced",
            @"firstBackspace", @"secondBackspace"]
        : @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced"];
    XCTAssertEqualObjects([result.phases valueForKey:@"phase"], expected);
    XCTAssertTrue(
        [result.phases[1].status.predictionDescriptor[@"present"] boolValue]);
    XCTAssertEqualObjects(
        result.phases[1].status.predictionDescriptor[@"displayText"], @"to");
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *expectedByPhase =
        @{
            @"baseline": @{
                @"canonical": @"Earlier sentence.  \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(18, 0)],
            },
            @"offered": @{
                @"canonical":
                    @"Earlier sentence. I look forward to \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(33, 0)],
            },
            @"decision": @{
                @"canonical": decision ==
                    IDInlinePredictionDecisionDismissThenType
                    ? @"Earlier sentence. I look forward  \nLater block stays."
                    : @"Earlier sentence. I look forward to  \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(
                    decision == IDInlinePredictionDecisionDismissThenType
                        ? 33 : 36, 0)],
            },
            @"immediate": @{
                @"canonical": decision ==
                    IDInlinePredictionDecisionDismissThenType
                    ? @"Earlier sentence. I look forward  \nLater block stays."
                    : @"Earlier sentence. I look forward to  \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(
                    decision == IDInlinePredictionDecisionDismissThenType
                        ? 33 : 36, 0)],
            },
            @"quiesced": @{
                @"canonical": decision ==
                    IDInlinePredictionDecisionDismissThenType
                    ? @"Earlier sentence. I look forward  \nLater block stays."
                    : @"Earlier sentence. I look forward to  \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(
                    decision == IDInlinePredictionDecisionDismissThenType
                        ? 33 : 36, 0)],
            },
            @"postDismissTyping": @{
                @"canonical":
                    @"Earlier sentence. I look forward x \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(34, 0)],
            },
            @"firstBackspace": @{
                @"canonical":
                    @"Earlier sentence. I look forward to \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(35, 0)],
            },
            @"secondBackspace": @{
                @"canonical":
                    @"Earlier sentence. I look forward t \nLater block stays.",
                @"selection": [NSValue valueWithRange:NSMakeRange(34, 0)],
            },
        };
    for (IDInlinePredictionPhaseSnapshot *phase in result.phases) {
        NSDictionary<NSString *, id> *phaseExpected =
            expectedByPhase[phase.phase];
        NSString *canonical = phaseExpected[@"canonical"];
        XCTAssertEqualObjects(phase.status.canonical, canonical, @"%@",
                              phase.phase);
        XCTAssertEqualObjects(
            phase.status.blocks,
            [canonical componentsSeparatedByString:@"\n"], @"%@", phase.phase);
        XCTAssertTrue(NSEqualRanges(
            phase.status.selection,
            [phaseExpected[@"selection"] rangeValue]), @"%@", phase.phase);
        XCTAssertEqualObjects(phase.status.affinity, @"forward", @"%@",
                              phase.phase);
        XCTAssertEqualObjects(phase.status.checkingRanges, @[], @"%@",
                              phase.phase);
        XCTAssertEqualObjects(
            phase.status.temporaryRenderingDescriptors, @[], @"%@",
            phase.phase);
        XCTAssertTrue(phase.status.isFirstResponder, @"%@", phase.phase);
        XCTAssertTrue([phase.status.keyboardState[@"visible"] boolValue],
                      @"%@", phase.phase);
        XCTAssertTrue([phase.status.keyboardState[
            @"inlinePredictionEnabled"] boolValue], @"%@", phase.phase);
        if ([phase.phase isEqual:@"offered"]) {
            XCTAssertTrue(NSEqualRanges(
                phase.status.markedRange, NSMakeRange(33, 2)));
        } else {
            XCTAssertEqual(phase.status.markedRange.location, NSNotFound,
                           @"%@", phase.phase);
            XCTAssertFalse([phase.status.predictionDescriptor[
                @"present"] boolValue], @"%@", phase.phase);
        }
    }
}

- (void)runCustomInteriorDecision:(IDInlinePredictionDecision)decision
                           minimal:(BOOL)minimal {
    IDInlinePredictionRow *row =
        [self rowAtLocation:IDInlinePredictionLocationInterior
                   decision:decision];
    XCUIApplication *application =
        [self launchCustomRow:row minimal:minimal];
    IDInlinePredictionRunResult *result =
        IDRunInlinePredictionLifecycle(self, application, row);
    [self assertCustomInteriorResult:result decision:decision];
}

- (void)runCustomInteriorDecision:(IDInlinePredictionDecision)decision {
    [self runCustomInteriorDecision:decision minimal:NO];
}

- (void)testCustomInteriorAcceptMatchesStock {
    [self runCustomInteriorDecision:IDInlinePredictionDecisionAccept];
}

- (void)testCustomInteriorDismissThenTypeMatchesStock {
    [self runCustomInteriorDecision:
        IDInlinePredictionDecisionDismissThenType];
}

- (void)testCustomInteriorAcceptThenDeleteMatchesStock {
    [self runCustomInteriorDecision:
        IDInlinePredictionDecisionAcceptThenDelete];
}

- (void)assertCustomBoundaryResult:(IDInlinePredictionRunResult *)result
                          location:(IDInlinePredictionLocation)location
                          decision:(IDInlinePredictionDecision)decision {
    NSArray<NSString *> *expected = decision ==
        IDInlinePredictionDecisionDismissThenType
        ? @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced",
            @"postDismissTyping"]
        : decision == IDInlinePredictionDecisionAcceptThenDelete
        ? @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced",
            @"firstBackspace", @"secondBackspace"]
        : @[@"baseline", @"offered", @"decision", @"immediate", @"quiesced"];
    XCTAssertEqualObjects([result.phases valueForKey:@"phase"], expected);
    IDInlinePredictionStatus *offered = result.phases[1].status;
    XCTAssertTrue([offered.predictionDescriptor[@"present"] boolValue]);
    XCTAssertEqualObjects(offered.predictionDescriptor[@"displayText"], @"to");
    XCTAssertTrue(NSEqualRanges(offered.markedRange, NSMakeRange(33, 2)));

    BOOL isAfter =
        location == IDInlinePredictionLocationAfterBoundary;
    NSString *baseline = isAfter
        ? @"Earlier sentence.\n \nLater block stays."
        : @"Earlier sentence. \nLater block stays.";
    NSString *offeredCanonical = isAfter
        ? @"Earlier sentence.\nI look forward to \nLater block stays."
        : @"Earlier sentence. I look forward to\nLater block stays.";
    NSString *dismissed = isAfter
        ? @"Earlier sentence.\nI look forward  \nLater block stays."
        : @"Earlier sentence. I look forward \nLater block stays.";
    NSString *accepted = isAfter
        ? @"Earlier sentence.\nI look forward to  \nLater block stays."
        : @"Earlier sentence. I look forward to \nLater block stays.";
    NSString *postDismissTyping = isAfter
        ? @"Earlier sentence.\nI look forward x \nLater block stays."
        : @"Earlier sentence. I look forward x\nLater block stays.";
    NSString *firstBackspace = isAfter
        ? @"Earlier sentence.\nI look forward to \nLater block stays."
        : @"Earlier sentence. I look forward to\nLater block stays.";
    NSString *secondBackspace = isAfter
        ? @"Earlier sentence.\nI look forward t \nLater block stays."
        : @"Earlier sentence. I look forward t\nLater block stays.";
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *expectedByPhase =
        @{
            @"baseline": @{
                @"canonical": baseline,
                @"selection": [NSValue valueWithRange:NSMakeRange(18, 0)],
            },
            @"offered": @{
                @"canonical": offeredCanonical,
                @"selection": [NSValue valueWithRange:NSMakeRange(33, 0)],
            },
            @"decision": @{
                @"canonical": decision ==
                    IDInlinePredictionDecisionDismissThenType
                    ? dismissed : accepted,
                @"selection": [NSValue valueWithRange:NSMakeRange(
                    decision == IDInlinePredictionDecisionDismissThenType
                        ? 33 : 36, 0)],
            },
            @"immediate": @{
                @"canonical": decision ==
                    IDInlinePredictionDecisionDismissThenType
                    ? dismissed : accepted,
                @"selection": [NSValue valueWithRange:NSMakeRange(
                    decision == IDInlinePredictionDecisionDismissThenType
                        ? 33 : 36, 0)],
            },
            @"quiesced": @{
                @"canonical": decision ==
                    IDInlinePredictionDecisionDismissThenType
                    ? dismissed : accepted,
                @"selection": [NSValue valueWithRange:NSMakeRange(
                    decision == IDInlinePredictionDecisionDismissThenType
                        ? 33 : 36, 0)],
            },
            @"postDismissTyping": @{
                @"canonical": postDismissTyping,
                @"selection": [NSValue valueWithRange:NSMakeRange(34, 0)],
            },
            @"firstBackspace": @{
                @"canonical": firstBackspace,
                @"selection": [NSValue valueWithRange:NSMakeRange(35, 0)],
            },
            @"secondBackspace": @{
                @"canonical": secondBackspace,
                @"selection": [NSValue valueWithRange:NSMakeRange(34, 0)],
            },
        };
    NSMutableDictionary<NSString *, IDInlinePredictionStatus *> *statusByPhase =
        [NSMutableDictionary dictionary];
    for (IDInlinePredictionPhaseSnapshot *phase in result.phases) {
        IDInlinePredictionStatus *status = phase.status;
        statusByPhase[phase.phase] = status;
        NSDictionary<NSString *, id> *phaseExpected =
            expectedByPhase[phase.phase];
        NSString *canonical = phaseExpected[@"canonical"];
        XCTAssertEqualObjects(status.canonical, canonical, @"%@", phase.phase);
        XCTAssertEqualObjects(
            status.blocks, [canonical componentsSeparatedByString:@"\n"],
            @"%@", phase.phase);
        XCTAssertTrue(NSEqualRanges(
            status.selection, [phaseExpected[@"selection"] rangeValue]),
            @"%@", phase.phase);
        NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
        for (NSUInteger index = 0; index < canonical.length; index += 1) {
            if ([canonical characterAtIndex:index] == '\n') {
                [newlines addObject:@(index)];
            }
        }
        XCTAssertEqualObjects(status.structuralNewlineLocations, newlines,
                              @"%@", phase.phase);
        XCTAssertEqualObjects(status.affinity, @"forward", @"%@", phase.phase);
        XCTAssertEqualObjects(status.checkingRanges, @[], @"%@", phase.phase);
        XCTAssertEqualObjects(status.temporaryRenderingDescriptors, @[],
                              @"%@", phase.phase);
        XCTAssertEqualObjects(status.mutationTrace, status.eventTrace,
                              @"%@", phase.phase);
        XCTAssertTrue(status.isFirstResponder, @"%@", phase.phase);
        XCTAssertTrue([status.keyboardState[@"visible"] boolValue],
                      @"%@", phase.phase);
        XCTAssertTrue([status.keyboardState[
            @"inlinePredictionEnabled"] boolValue], @"%@", phase.phase);
        if ([phase.phase isEqual:@"offered"]) {
            XCTAssertTrue(NSEqualRanges(
                status.markedRange, NSMakeRange(33, 2)));
        } else {
            XCTAssertEqual(status.markedRange.location, NSNotFound,
                           @"%@", phase.phase);
            XCTAssertFalse([status.predictionDescriptor[@"present"] boolValue],
                           @"%@", phase.phase);
        }
    }
    XCTAssertEqual(
        statusByPhase[@"immediate"].documentRevision,
        statusByPhase[@"decision"].documentRevision);
    XCTAssertEqual(
        statusByPhase[@"quiesced"].documentRevision,
        statusByPhase[@"decision"].documentRevision);
    if (decision == IDInlinePredictionDecisionDismissThenType) {
        XCTAssertEqual(
            statusByPhase[@"decision"].documentRevision,
            statusByPhase[@"offered"].documentRevision + 1);
        XCTAssertEqual(
            statusByPhase[@"postDismissTyping"].documentRevision,
            statusByPhase[@"quiesced"].documentRevision + 1);
    } else if (decision == IDInlinePredictionDecisionAcceptThenDelete) {
        XCTAssertEqual(
            statusByPhase[@"firstBackspace"].documentRevision,
            statusByPhase[@"quiesced"].documentRevision + 1);
        XCTAssertEqual(
            statusByPhase[@"secondBackspace"].documentRevision,
            statusByPhase[@"firstBackspace"].documentRevision + 1);
    }
}

- (void)runCustomBoundaryAtLocation:(IDInlinePredictionLocation)location
                           decision:(IDInlinePredictionDecision)decision
                            minimal:(BOOL)minimal {
    IDInlinePredictionRow *row =
        [self rowAtLocation:location decision:decision];
    XCUIApplication *application =
        [self launchCustomRow:row minimal:minimal];
    IDInlinePredictionRunResult *result =
        IDRunInlinePredictionLifecycle(self, application, row);
    [self assertCustomBoundaryResult:result
                            location:location
                            decision:decision];
}

- (void)runCustomBoundaryAtLocation:(IDInlinePredictionLocation)location
                           decision:(IDInlinePredictionDecision)decision {
    [self runCustomBoundaryAtLocation:location
                             decision:decision
                              minimal:NO];
}

- (void)assertCustomResult:(IDInlinePredictionRunResult *)result
                  location:(IDInlinePredictionLocation)location
                  decision:(IDInlinePredictionDecision)decision {
    if (location == IDInlinePredictionLocationInterior) {
        [self assertCustomInteriorResult:result decision:decision];
    } else {
        [self assertCustomBoundaryResult:result
                                location:location
                                decision:decision];
    }
}

- (void)runCertificationRow:(IDInlinePredictionRow *)row
                       host:(IDTextInputBatchHost)host {
    XCUIApplication *application = host == IDTextInputBatchHostStock
        ? IDLaunchStockInlinePredictionScenario(row)
        : IDLaunchCustomInlinePredictionScenario(row);
    @try {
        IDInlinePredictionRunResult *result =
            IDRunInlinePredictionLifecycle(self, application, row);
        XCTAssertEqualObjects(result.row.identifier, row.identifier);
        if (host == IDTextInputBatchHostStock) {
            [self assertStockResult:result
                           location:row.location
                           decision:row.decision];
        } else {
            [self assertCustomResult:result
                            location:row.location
                            decision:row.decision];
        }
    } @finally {
        IDAttachTextInputBatchHierarchy(self, application);
        [application terminate];
    }
}

- (void)testBatchedCertification {
    IDTextInputGroup *group =
        IDLoadSelectedTextInputGroup(self, @"inline-prediction");
    XCTAssertNotNil(group);
    if (group == nil) return;

    NSIndexSet *completedObservationIndexes =
        IDLoadTextInputCompletedObservationIndexes();
    XCTAssertNotNil(completedObservationIndexes);
    if (completedObservationIndexes == nil) return;

    NSString *token = NSProcessInfo.processInfo.environment[
        @"INPUTDEC_TEXT_INPUT_GROUP_TOKEN"];
    NSError *directoryError = nil;
    NSURL *handshakeDirectory = IDTextInputGroupHandshakeDirectory(
        nil, token, &directoryError);
    XCTAssertNotNil(handshakeDirectory, @"%@", directoryError);
    if (handshakeDirectory == nil) return;

    __block NSUInteger eventIndex = 1;
    __block NSUInteger observationIndex =
        completedObservationIndexes.count + 1;
    IDRunSnapshotTextInputGroup(
        self, group, 20, completedObservationIndexes,
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            NSArray<IDInlinePredictionRow *> *rows =
                IDInlinePredictionRowsMatchingIdentifier(
                    observation.rowIdentifier);
            XCTAssertEqual(rows.count, 1U);
            if (rows.count != 1) {
                return IDTextInputObservationAttemptCompleted;
            }

            IDInlinePredictionRow *row = rows.firstObject;
            XCUIApplication *application =
                observation.host == IDTextInputBatchHostStock
                    ? IDLaunchStockInlinePredictionScenario(row)
                    : IDLaunchCustomInlinePredictionScenario(row);
            @try {
                IDInlinePredictionLifecycleAttempt *lifecycleAttempt =
                    IDAttemptInlinePredictionLifecycle(
                        self, application, row);
                if (!lifecycleAttempt.offerReady) {
                    return
                        IDTextInputObservationAttemptReadinessUnavailable;
                }

                IDInlinePredictionRunResult *result = lifecycleAttempt.result;
                XCTAssertNotNil(result);
                XCTAssertEqualObjects(result.row.identifier, row.identifier);
                if (observation.host == IDTextInputBatchHostStock) {
                    [self assertStockResult:result
                                   location:row.location
                                   decision:row.decision];
                } else {
                    [self assertCustomResult:result
                                    location:row.location
                                    decision:row.decision];
                }

                NSError *checkpointError = nil;
                BOOL checkpointWritten =
                    IDWriteInlinePredictionObservationCheckpoint(
                        handshakeDirectory, result, observation, attempt,
                        application, &checkpointError);
                XCTAssertTrue(checkpointWritten, @"%@", checkpointError);
                return IDTextInputObservationAttemptCompleted;
            } @finally {
                IDAttachTextInputBatchHierarchy(self, application);
                [application terminate];
            }
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *precedingBoundary) {
            NSError *eventError = nil;
            NSUInteger currentEventIndex = eventIndex;
            NSUInteger currentObservationIndex = observationIndex;
            BOOL handled = IDWriteTextInputObservationEvent(
                handshakeDirectory, token, group.identifier,
                currentEventIndex, currentObservationIndex, kind,
                observation, attempt, precedingBoundary, &eventError);
            if (handled &&
                (kind == IDTextInputObservationEventStarted ||
                 kind == IDTextInputObservationEventRetryRequired)) {
                handled = IDWaitForTextInputObservationRestoreResponse(
                    handshakeDirectory, token, group.identifier,
                    currentEventIndex, currentObservationIndex, kind,
                    observation, attempt, precedingBoundary, 60.0,
                    &eventError);
            }
            XCTAssertTrue(handled, @"Snapshot observation event %lu failed: %@",
                          (unsigned long)currentEventIndex, eventError);
            if (!handled) return NO;
            eventIndex += 1;
            if (kind == IDTextInputObservationEventComplete) {
                observationIndex += 1;
            }
            return YES;
        });
}

- (void)testCustomBeforeBoundaryAcceptMatchesStock {
    [self runCustomBoundaryAtLocation:
        IDInlinePredictionLocationBeforeBoundary
                             decision:IDInlinePredictionDecisionAccept];
}

- (void)testCustomBeforeBoundaryDismissThenTypeMatchesStock {
    [self runCustomBoundaryAtLocation:
        IDInlinePredictionLocationBeforeBoundary
                             decision:
        IDInlinePredictionDecisionDismissThenType];
}

- (void)testCustomBeforeBoundaryAcceptThenDeleteMatchesStock {
    [self runCustomBoundaryAtLocation:
        IDInlinePredictionLocationBeforeBoundary
                             decision:
        IDInlinePredictionDecisionAcceptThenDelete];
}

- (void)testCustomAfterBoundaryAcceptMatchesStock {
    [self runCustomBoundaryAtLocation:
        IDInlinePredictionLocationAfterBoundary
                             decision:IDInlinePredictionDecisionAccept];
}

- (void)testCustomAfterBoundaryDismissThenTypeMatchesStock {
    [self runCustomBoundaryAtLocation:
        IDInlinePredictionLocationAfterBoundary
                             decision:
        IDInlinePredictionDecisionDismissThenType];
}

- (void)testCustomAfterBoundaryAcceptThenDeleteMatchesStock {
    [self runCustomBoundaryAtLocation:
        IDInlinePredictionLocationAfterBoundary
                             decision:
        IDInlinePredictionDecisionAcceptThenDelete];
}

- (void)testMinimalInteriorAcceptMatchesStock {
    [self runCustomInteriorDecision:
        IDInlinePredictionDecisionAccept minimal:YES];
}

- (void)testMinimalBeforeBoundaryDismissThenTypeMatchesStock {
    [self runCustomBoundaryAtLocation:
        IDInlinePredictionLocationBeforeBoundary
                             decision:
        IDInlinePredictionDecisionDismissThenType
                              minimal:YES];
}

@end
