#import "IDIMECompositionLifecycleTestSupport.h"
#import "IDTextInputBatchTestSupport.h"

@interface IDIMECompositionLifecycleUITests : XCTestCase
@end

@implementation IDIMECompositionLifecycleUITests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

- (IDIMECompositionRow *)rowForLanguage:(IDIMELanguage)language
                               location:(IDIMELocation)location
                               decision:(IDIMEDecision)decision {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(IDIMECompositionRow *row, NSDictionary *bindings) {
            (void)bindings;
            return row.language == language &&
                row.location == location && row.decision == decision;
        }];
    NSArray<IDIMECompositionRow *> *rows =
        [IDIMECompositionMatrix() filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(rows.count, 1U);
    return rows.firstObject;
}

- (NSArray<NSString *> *)physicalKeysForLanguage:(IDIMELanguage)language {
    return language == IDIMELanguageJapaneseRomaji
        ? @[@"k", @"a", @"n", @"a"]
        : @[@"n", @"i", @"h", @"a", @"o"];
}

- (NSDictionary<NSString *, id> *)stockFixtureForLanguage:
        (IDIMELanguage)language {
    NSString *name = language == IDIMELanguageJapaneseRomaji
        ? @"ime-japanese-romaji-stock-contract-v1"
        : @"ime-simplified-chinese-pinyin-stock-contract-v1";
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSURL *url = [bundle URLForResource:name
                          withExtension:@"json"];
    XCTAssertNotNil(url);
    NSData *data = url == nil ? nil :
        [NSData dataWithContentsOfURL:url];
    XCTAssertNotNil(data);
    NSDictionary<NSString *, id> *fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data
                                         options:0
                                           error:nil];
    XCTAssertTrue([fixture isKindOfClass:NSDictionary.class]);
    return fixture;
}

- (NSUInteger)offsetForRow:(IDIMECompositionRow *)row
                   fixture:(NSDictionary<NSString *, id> *)fixture {
    NSArray<NSString *> *keys = @[
        @"interiorOffset", @"beforeBoundaryOffset", @"afterBoundaryOffset",
    ];
    return [fixture[keys[(NSUInteger)row.location]]
        unsignedIntegerValue];
}

- (NSString *)insertText:(NSString *)text
               atOffset:(NSUInteger)offset
             inCanonical:(NSString *)canonical {
    return [canonical stringByReplacingCharactersInRange:
        NSMakeRange(offset, 0) withString:text];
}

- (NSString *)insertedTextInObservedResult:(NSString *)observed
                                  fixture:(NSDictionary<NSString *, id> *)fixture
                                offsetKey:(NSString *)offsetKey {
    NSString *baseline = fixture[@"canonicalDocument"];
    NSUInteger offset = [fixture[offsetKey] unsignedIntegerValue];
    XCTAssertGreaterThanOrEqual(observed.length, baseline.length);
    NSUInteger insertedLength = observed.length - baseline.length;
    XCTAssertLessThanOrEqual(offset + insertedLength, observed.length);
    return [observed substringWithRange:
        NSMakeRange(offset, insertedLength)];
}

- (NSArray<NSString *> *)expectedPhasesForDecision:
        (IDIMEDecision)decision {
    switch (decision) {
        case IDIMEDecisionCandidateCommit:
            return @[
                @"baseline", @"firstComposition", @"updatedComposition",
                @"candidateVisible", @"decision", @"immediate",
                @"quiesced",
            ];
        case IDIMEDecisionCancel:
        case IDIMEDecisionOrdinaryCommit:
            return @[
                @"baseline", @"firstComposition", @"updatedComposition",
                @"decision", @"immediate", @"quiesced",
            ];
        case IDIMEDecisionReturnCommitThenUndo:
            return @[
                @"baseline", @"firstComposition", @"updatedComposition",
                @"decision", @"immediate", @"quiesced", @"undo",
            ];
        case IDIMEDecisionResponderLoss:
            return @[
                @"baseline", @"firstComposition", @"updatedComposition",
                @"decision", @"postInterruption", @"quiesced",
            ];
    }
    return @[];
}

- (void)assertMonotonicEpochs:
        (NSArray<IDIMECompositionPhaseSnapshot *> *)phases {
    NSArray<NSString *> *keys = @[
        @"documentRevision", @"textEpoch", @"selectionEpoch",
        @"checkingEpoch", @"layoutEpoch",
    ];
    for (NSUInteger index = 1; index < phases.count; index += 1) {
        IDIMECompositionStatus *previous = phases[index - 1].status;
        IDIMECompositionStatus *current = phases[index].status;
        for (NSString *key in keys) {
            XCTAssertGreaterThanOrEqual(
                [[current valueForKey:key] unsignedIntegerValue],
                [[previous valueForKey:key] unsignedIntegerValue],
                @"%@ regressed from %@ to %@ at phase %@",
                key, [previous valueForKey:key], [current valueForKey:key],
                phases[index].phase);
        }
    }
}

- (void)assertCompleteStockLifecycle:
        (IDIMECompositionRunResult *)result
                            fixture:
        (NSDictionary<NSString *, id> *)fixture {
    IDIMECompositionRow *row = result.row;
    NSArray<IDIMECompositionPhaseSnapshot *> *phases = result.phases;
    XCTAssertEqualObjects(
        [phases valueForKey:@"phase"],
        [self expectedPhasesForDecision:row.decision]);
    for (IDIMECompositionPhaseSnapshot *phase in phases) {
        XCTAssertEqualObjects(
            phase.screenshotName,
            [@"ime-composition-" stringByAppendingString:phase.phase]);
    }

    IDIMECompositionStatus *baseline = phases.firstObject.status;
    XCTAssertEqualObjects(baseline.canonical, fixture[@"canonicalDocument"]);
    XCTAssertEqual(
        baseline.selection.location,
        [self offsetForRow:row fixture:fixture]);
    XCTAssertEqual(baseline.selection.length, 0U);
    XCTAssertEqual(baseline.markedRange.location, NSNotFound);

    IDIMECompositionStatus *first = phases[1].status;
    IDIMECompositionStatus *updated = phases[2].status;
    XCTAssertEqualObjects(first.markedText, fixture[@"firstComposition"]);
    XCTAssertEqualObjects(updated.markedText, fixture[@"updatedComposition"]);
    NSArray<NSDictionary<NSString *, NSNumber *> *> *markedSelections =
        fixture[@"markedSelections"];
    XCTAssertEqual(
        first.markedSelection.location,
        [markedSelections[0][@"location"] unsignedIntegerValue]);
    XCTAssertEqual(
        first.markedSelection.length,
        [markedSelections[0][@"length"] unsignedIntegerValue]);
    XCTAssertEqual(
        updated.markedSelection.location,
        [markedSelections[1][@"location"] unsignedIntegerValue]);
    XCTAssertEqual(
        updated.markedSelection.length,
        [markedSelections[1][@"length"] unsignedIntegerValue]);
    XCTAssertEqualObjects(
        baseline.keyboardState[@"primaryLanguage"],
        fixture[@"primaryLanguage"]);

    NSUInteger decisionIndex =
        [phases indexOfObjectPassingTest:
            ^BOOL(IDIMECompositionPhaseSnapshot *phase,
                  NSUInteger index, BOOL *stop) {
                (void)index;
                (void)stop;
                return [phase.phase isEqualToString:@"decision"];
            }];
    XCTAssertNotEqual(decisionIndex, NSNotFound);
    IDIMECompositionStatus *decision = phases[decisionIndex].status;
    NSString *baselineCanonical = fixture[@"canonicalDocument"];
    NSUInteger offset = [self offsetForRow:row fixture:fixture];
    NSString *expectedDecisionCanonical = nil;
    switch (row.decision) {
        case IDIMEDecisionCandidateCommit:
            expectedDecisionCanonical = [self
                insertText:fixture[@"committedText"]
                  atOffset:offset
                inCanonical:baselineCanonical];
            break;
        case IDIMEDecisionCancel:
            expectedDecisionCanonical = baselineCanonical;
            break;
        case IDIMEDecisionOrdinaryCommit: {
            NSString *inserted = [self
                insertedTextInObservedResult:fixture[@"ordinaryCommitResult"]
                                    fixture:fixture
                                  offsetKey:@"interiorOffset"];
            expectedDecisionCanonical = [self
                insertText:inserted
                  atOffset:offset
                inCanonical:baselineCanonical];
            break;
        }
        case IDIMEDecisionReturnCommitThenUndo: {
            NSString *inserted = [self
                insertedTextInObservedResult:fixture[@"returnCommitResult"]
                                    fixture:fixture
                                  offsetKey:@"beforeBoundaryOffset"];
            expectedDecisionCanonical = [self
                insertText:inserted
                  atOffset:offset
                inCanonical:baselineCanonical];
            break;
        }
        case IDIMEDecisionResponderLoss:
            expectedDecisionCanonical = fixture[@"responderLossResult"];
            break;
    }
    XCTAssertEqualObjects(decision.canonical, expectedDecisionCanonical);
    NSArray<NSString *> *expectedActions = nil;
    switch (row.decision) {
        case IDIMEDecisionCandidateCommit:
            expectedActions = @[[@"candidate:" stringByAppendingString:
                fixture[@"candidateAccessibilityIdentity"]]];
            break;
        case IDIMEDecisionCancel:
            expectedActions = [fixture[@"cancelAction"][@"value"]
                componentsSeparatedByString:@","];
            break;
        case IDIMEDecisionOrdinaryCommit:
            expectedActions = @[@"return"];
            break;
        case IDIMEDecisionReturnCommitThenUndo:
            expectedActions = @[@"return", @"undo"];
            break;
        case IDIMEDecisionResponderLoss:
            expectedActions = @[@"resign"];
            break;
    }
    XCTAssertEqualObjects(result.decisionActions, expectedActions);

    NSUInteger modifiedBlock =
        row.location == IDIMELocationAfterBoundary ? 1U : 0U;
    NSUInteger unaffectedBlock = modifiedBlock == 0 ? 1U : 0U;
    for (IDIMECompositionPhaseSnapshot *phase in phases) {
        IDIMECompositionStatus *status = phase.status;
        XCTAssertEqualObjects(
            status.blockIdentifiers, baseline.blockIdentifiers);
        XCTAssertEqualObjects(
            status.anchorIdentities, baseline.anchorIdentities);
        XCTAssertEqualObjects(
            status.blocks[unaffectedBlock],
            baseline.blocks[unaffectedBlock]);
        if ([phase.phase isEqualToString:@"decision"] ||
            [phase.phase isEqualToString:@"immediate"] ||
            [phase.phase isEqualToString:@"postInterruption"] ||
            [phase.phase isEqualToString:@"quiesced"]) {
            XCTAssertEqual(status.markedRange.location, NSNotFound);
            XCTAssertEqual(status.markedText.length, 0U);
            XCTAssertEqualObjects(
                status.canonical, expectedDecisionCanonical);
        } else if ([phase.phase isEqualToString:@"undo"]) {
            XCTAssertEqual(status.markedRange.location, NSNotFound);
            XCTAssertEqual(status.markedText.length, 0U);
        }
    }

    if (row.decision == IDIMEDecisionCandidateCommit) {
        IDIMECompositionStatus *candidate = phases[3].status;
        XCTAssertEqualObjects(
            candidate.candidateDescriptor[@"selectedLabel"],
            fixture[@"candidateAccessibilityIdentity"]);
        XCTAssertTrue(
            [candidate.candidateDescriptor[@"labels"]
                containsObject:fixture[@"candidateAccessibilityIdentity"]]);
        XCTAssertTrue([candidate.candidateDescriptor[@"actionable"]
            boolValue]);
    } else if (row.decision == IDIMEDecisionCancel) {
        for (IDIMECompositionPhaseSnapshot *phase in phases) {
            if ([phase.phase isEqualToString:@"decision"] ||
                [phase.phase isEqualToString:@"immediate"] ||
                [phase.phase isEqualToString:@"quiesced"]) {
                XCTAssertTrue(NSEqualRanges(
                    phase.status.selection, baseline.selection));
            }
        }
    } else if (row.decision == IDIMEDecisionReturnCommitThenUndo) {
        IDIMECompositionStatus *undo = phases.lastObject.status;
        XCTAssertEqualObjects(undo.canonical, fixture[@"undoResult"]);
        XCTAssertEqual(undo.selection.location, baseline.selection.location);
    } else if (row.decision == IDIMEDecisionResponderLoss) {
        XCTAssertFalse(decision.isFirstResponder);
        XCTAssertFalse(phases.lastObject.status.isFirstResponder);
    }
    [self assertMonotonicEpochs:phases];
}

- (void)runCompleteStockTruthForLanguage:(IDIMELanguage)language
                                location:(IDIMELocation)location
                                decision:(IDIMEDecision)decision {
    IDIMECompositionRow *row =
        [self rowForLanguage:language
                    location:location
                    decision:decision];
    IDIMECompositionRunResult *result = IDRunIMECompositionLifecycle(
        self, IDLaunchStockIMECompositionScenario(row), row);
    [self assertCompleteStockLifecycle:result
                              fixture:
        [self stockFixtureForLanguage:language]];
}

- (void)runCompleteCustomTruthForLanguage:(IDIMELanguage)language
                                 location:(IDIMELocation)location
                                 decision:(IDIMEDecision)decision
                                  minimal:(BOOL)minimal {
    IDIMECompositionRow *row =
        [self rowForLanguage:language
                    location:location
                    decision:decision];
    XCUIApplication *application =
        IDLaunchCustomIMECompositionScenario(row);
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
        NSDictionary *payload = [NSJSONSerialization
            JSONObjectWithData:
                [serialized dataUsingEncoding:NSUTF8StringEncoding]
                      options:0 error:nil];
        XCTAssertEqualObjects(payload[@"backend"], @"minimal");
        XCTAssertEqualObjects(payload[@"report"][@"detached"], @NO);
        NSPredicate *activeInput = [NSPredicate predicateWithFormat:
            @"identifier == %@ AND state == %@",
            @"inputController", @"active"];
        XCTAssertEqual(
            [payload[@"report"][@"capabilities"]
                filteredArrayUsingPredicate:activeInput].count,
            1U);
    }
    IDIMECompositionRunResult *result = IDRunIMECompositionLifecycle(
        self, application, row);
    [self assertCompleteStockLifecycle:result
                              fixture:
        [self stockFixtureForLanguage:language]];
}

- (void)runCompleteCustomTruthForLanguage:(IDIMELanguage)language
                                 location:(IDIMELocation)location
                                 decision:(IDIMEDecision)decision {
    [self runCompleteCustomTruthForLanguage:language
                                   location:location
                                   decision:decision
                                    minimal:NO];
}

- (void)runCertificationRow:(IDIMECompositionRow *)row
                       host:(IDTextInputBatchHost)host {
    XCUIApplication *application = host == IDTextInputBatchHostStock
        ? IDLaunchStockIMECompositionScenario(row)
        : IDLaunchCustomIMECompositionScenario(row);
    @try {
        IDIMECompositionRunResult *result =
            IDRunIMECompositionLifecycle(self, application, row);
        XCTAssertEqualObjects(result.row.identifier, row.identifier);
        [self assertCompleteStockLifecycle:result
                                  fixture:
            [self stockFixtureForLanguage:row.language]];
        NSDictionary<NSString *, id> *lifecycle =
            IDIMECompositionLifecycleDictionary(
                result, @"testBatchedCertification");
        NSError *error = nil;
        NSData *data = [NSJSONSerialization
            dataWithJSONObject:lifecycle
                       options:NSJSONWritingSortedKeys
                         error:&error];
        XCTAssertNotNil(data, @"%@", error);
        if (data == nil) return;
        XCTAttachment *attachment =
            [XCTAttachment attachmentWithData:data
                      uniformTypeIdentifier:@"public.json"];
        attachment.name =
            IDTextInputBatchAttachmentName(@"ime-lifecycle.json");
        attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:attachment];
    } @finally {
        IDAttachTextInputBatchHierarchy(self, application);
        [application terminate];
    }
}

- (void)testBatchedCertification {
    IDTextInputGroup *group = IDLoadSelectedTextInputGroup(self, @"ime");
    XCTAssertNotNil(group);
    if (group == nil) return;
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            NSArray<IDIMECompositionRow *> *rows =
                IDIMECompositionRowsMatchingIdentifier(
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

- (NSDictionary<NSString *, NSString *> *)actionWithKind:(NSString *)kind
                                                    value:(NSString *)value
                                    accessibilityIdentity:
                                        (NSString *)accessibilityIdentity {
    return @{
        @"kind": kind,
        @"value": value,
        @"accessibilityIdentity": accessibilityIdentity,
    };
}

- (void)attachStockObservationForLanguage:(IDIMELanguage)language
                                        candidate:
            (IDIMECompositionRunResult *)candidateResult
                                           ordinary:
            (IDIMECompositionRunResult *)ordinaryResult
                                             cancel:
            (IDIMECompositionRunResult *)cancelResult
                                         returnUndo:
            (IDIMECompositionRunResult *)returnUndoResult
                                      responderLoss:
            (IDIMECompositionRunResult *)responderLossResult {
    IDIMECompositionStatus *baseline = candidateResult.phases[0].status;
    IDIMECompositionStatus *first = candidateResult.phases[1].status;
    IDIMECompositionStatus *updated = candidateResult.phases[2].status;
    IDIMECompositionStatus *candidate = candidateResult.phases[3].status;
    IDIMECompositionStatus *candidateDecision =
        candidateResult.phases[4].status;
    IDIMECompositionStatus *ordinaryDecision =
        ordinaryResult.phases[3].status;
    IDIMECompositionStatus *cancelDecision =
        cancelResult.phases[3].status;
    IDIMECompositionStatus *returnDecision =
        returnUndoResult.phases[3].status;
    IDIMECompositionStatus *undoDecision =
        returnUndoResult.phases[4].status;
    IDIMECompositionStatus *responderDecision =
        responderLossResult.phases[3].status;

    NSRange boundary = [baseline.canonical rangeOfString:@"\n"];
    XCTAssertNotEqual(boundary.location, NSNotFound);
    NSUInteger committedLength =
        candidateDecision.canonical.length - baseline.canonical.length;
    NSString *committedText = [candidateDecision.canonical
        substringWithRange:NSMakeRange(
            baseline.selection.location, committedLength)];
    NSString *candidateIdentity =
        candidate.candidateDescriptor[@"selectedLabel"];
    NSString *languageName =
        language == IDIMELanguageJapaneseRomaji
            ? @"japanese-romaji" : @"simplified-chinese-pinyin";
    NSString *inputModePrefix =
        language == IDIMELanguageJapaneseRomaji
            ? @"ja_JP-Romaji@" : @"zh_Hans-Pinyin@";
    NSString *inputModeIdentifier = nil;
    for (NSString *identifier in
         baseline.keyboardState[@"enabledInputModeIdentifiers"]) {
        if ([identifier hasPrefix:inputModePrefix]) {
            inputModeIdentifier = identifier;
            break;
        }
    }
    XCTAssertNotNil(inputModeIdentifier);
    XCTAssertGreaterThan(candidateIdentity.length, 0U);
    XCTAssertGreaterThan(cancelResult.decisionActions.count, 0U);

    NSDictionary<NSString *, id> *fixture = @{
        @"schema": @1,
        @"runtime": @{@"osVersion": @"26.5", @"osBuild": @"23F73"},
        @"language": languageName,
        @"inputModeIdentifier": inputModeIdentifier ?: @"",
        @"primaryLanguage":
            baseline.keyboardState[@"primaryLanguage"] ?: @"",
        @"canonicalDocument": baseline.canonical,
        @"interiorOffset": @(baseline.selection.location),
        @"beforeBoundaryOffset": @(boundary.location),
        @"afterBoundaryOffset": @(NSMaxRange(boundary)),
        @"physicalKeySequence": [self physicalKeysForLanguage:language],
        @"firstComposition": first.markedText,
        @"updatedComposition": updated.markedText,
        @"markedSelections": @[
            @{@"location": @(first.markedSelection.location),
              @"length": @(first.markedSelection.length)},
            @{@"location": @(updated.markedSelection.location),
              @"length": @(updated.markedSelection.length)},
        ],
        @"candidateAction": [self
            actionWithKind:@"candidate-cell-tap"
                     value:committedText
     accessibilityIdentity:candidateIdentity],
        @"candidateLabel": committedText,
        @"candidateAccessibilityIdentity": candidateIdentity,
        @"committedText": committedText,
        @"ordinaryCommitAction": [self
            actionWithKind:@"software-keyboard-button"
                     value:@"Return"
     accessibilityIdentity:@"Return"],
        @"ordinaryCommitResult": ordinaryDecision.canonical,
        @"cancelAction": [self
            actionWithKind:@"software-keyboard-key-sequence"
                     value:[cancelResult.decisionActions
                         componentsJoinedByString:@","]
     accessibilityIdentity:@"delete"],
        @"cancelResult": cancelDecision.canonical,
        @"returnAction": [self
            actionWithKind:@"software-keyboard-button"
                     value:@"Return"
     accessibilityIdentity:@"Return"],
        @"returnCommitResult": returnDecision.canonical,
        @"undoAction": [self
            actionWithKind:@"uikit-undo-manager"
                     value:@"undo"
     accessibilityIdentity:@"ime-undo"],
        @"undoResult": undoDecision.canonical,
        @"responderLossResult": responderDecision.canonical,
        @"geometryTolerance": @1.0,
    };
    NSDictionary<NSString *, id> *observation = @{
        @"schema": @1,
        @"fixture": fixture,
        @"candidateGeometry":
            candidate.candidateDescriptor[@"geometry"],
        @"compositionGeometry": candidate.compositionGeometry,
    };
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:observation
                   options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted
                     error:nil];
    XCTAssertNotNil(data);
    XCTAttachment *attachment =
        [XCTAttachment attachmentWithData:data
                      uniformTypeIdentifier:@"public.json"];
    attachment.name = @"ime-stock-contract-observation";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)runStockDiscoveryForLanguage:(IDIMELanguage)language
                     primaryLanguage:(NSString *)primaryLanguage {
    IDIMECompositionRow *row =
        [self rowForLanguage:language
                    location:IDIMELocationInterior
                    decision:IDIMEDecisionCandidateCommit];
    XCUIApplication *application =
        IDLaunchStockIMECompositionScenario(row);
    IDIMECompositionRunResult *result =
        IDRunIMECompositionLifecycle(self, application, row);

    XCTAssertEqualObjects([result.phases valueForKey:@"phase"], (@[
        @"baseline", @"firstComposition", @"updatedComposition",
        @"candidateVisible", @"decision", @"quiesced",
    ]));
    IDIMECompositionStatus *first = result.phases[1].status;
    IDIMECompositionStatus *updated = result.phases[2].status;
    IDIMECompositionStatus *candidate = result.phases[3].status;
    IDIMECompositionStatus *decision = result.phases[4].status;
    XCTAssertNotEqual(first.markedRange.location, NSNotFound);
    XCTAssertNotEqual(updated.markedRange.location, NSNotFound);
    XCTAssertGreaterThan(first.markedText.length, 0U);
    XCTAssertGreaterThan(updated.markedText.length, 0U);
    XCTAssertNotEqualObjects(first.markedText, updated.markedText);
    XCTAssertTrue([candidate.candidateDescriptor[@"visible"] boolValue]);
    XCTAssertTrue([candidate.candidateDescriptor[@"actionable"] boolValue]);
    XCTAssertGreaterThan(
        [candidate.candidateDescriptor[@"labels"] count], 0U);
    XCTAssertEqualObjects(
        candidate.keyboardState[@"primaryLanguage"], primaryLanguage);
    XCTAssertEqual(decision.markedRange.location, NSNotFound);
    XCTAssertGreaterThan(decision.canonical.length, 0U);

    IDIMECompositionRow *ordinaryRow =
        [self rowForLanguage:language
                    location:IDIMELocationInterior
                    decision:IDIMEDecisionOrdinaryCommit];
    IDIMECompositionRunResult *ordinary =
        IDRunIMECompositionLifecycle(
            self, IDLaunchStockIMECompositionScenario(ordinaryRow),
            ordinaryRow);
    IDIMECompositionRow *cancelRow =
        [self rowForLanguage:language
                    location:IDIMELocationInterior
                    decision:IDIMEDecisionCancel];
    IDIMECompositionRunResult *cancel =
        IDRunIMECompositionLifecycle(
            self, IDLaunchStockIMECompositionScenario(cancelRow), cancelRow);
    IDIMECompositionRow *returnRow =
        [self rowForLanguage:language
                    location:IDIMELocationBeforeBoundary
                    decision:IDIMEDecisionReturnCommitThenUndo];
    IDIMECompositionRunResult *returnUndo =
        IDRunIMECompositionLifecycle(
            self, IDLaunchStockIMECompositionScenario(returnRow), returnRow);
    IDIMECompositionRow *responderRow =
        [self rowForLanguage:language
                    location:IDIMELocationBeforeBoundary
                    decision:IDIMEDecisionResponderLoss];
    IDIMECompositionRunResult *responderLoss =
        IDRunIMECompositionLifecycle(
            self, IDLaunchStockIMECompositionScenario(responderRow),
            responderRow);
    [self attachStockObservationForLanguage:language
                                  candidate:result
                                   ordinary:ordinary
                                     cancel:cancel
                                 returnUndo:returnUndo
                              responderLoss:responderLoss];
}

- (void)testStockJapaneseRomajiDiscoveryTruth {
    [self runStockDiscoveryForLanguage:IDIMELanguageJapaneseRomaji
                       primaryLanguage:@"ja-JP"];
}

- (void)testStockSimplifiedChinesePinyinDiscoveryTruth {
    [self runStockDiscoveryForLanguage:
              IDIMELanguageSimplifiedChinesePinyin
                       primaryLanguage:@"zh-Hans"];
}

- (void)testStockJapaneseRomajiOrdinaryCommitDiscovery {
    IDIMECompositionRow *row =
        [self rowForLanguage:IDIMELanguageJapaneseRomaji
                    location:IDIMELocationInterior
                    decision:IDIMEDecisionOrdinaryCommit];
    IDIMECompositionRunResult *result = IDRunIMECompositionLifecycle(
        self, IDLaunchStockIMECompositionScenario(row), row);
    XCTAssertEqual(result.phases.lastObject.status.markedRange.location,
                   NSNotFound);
}

- (void)testStockJapaneseRomajiCancelDiscovery {
    IDIMECompositionRow *row =
        [self rowForLanguage:IDIMELanguageJapaneseRomaji
                    location:IDIMELocationInterior
                    decision:IDIMEDecisionCancel];
    IDIMECompositionRunResult *result = IDRunIMECompositionLifecycle(
        self, IDLaunchStockIMECompositionScenario(row), row);
    XCTAssertEqual(result.phases.lastObject.status.markedRange.location,
                   NSNotFound);
}

- (void)testStockJapaneseRomajiReturnUndoDiscovery {
    IDIMECompositionRow *row =
        [self rowForLanguage:IDIMELanguageJapaneseRomaji
                    location:IDIMELocationBeforeBoundary
                    decision:IDIMEDecisionReturnCommitThenUndo];
    IDIMECompositionRunResult *result = IDRunIMECompositionLifecycle(
        self, IDLaunchStockIMECompositionScenario(row), row);
    XCTAssertEqual(result.phases.lastObject.status.markedRange.location,
                   NSNotFound);
}

- (void)testStockJapaneseRomajiResponderLossDiscovery {
    IDIMECompositionRow *row =
        [self rowForLanguage:IDIMELanguageJapaneseRomaji
                    location:IDIMELocationBeforeBoundary
                    decision:IDIMEDecisionResponderLoss];
    IDIMECompositionRunResult *result = IDRunIMECompositionLifecycle(
        self, IDLaunchStockIMECompositionScenario(row), row);
    XCTAssertFalse(result.phases.lastObject.status.isFirstResponder);
}

#define ID_DEFINE_STOCK_IME_TRUTH_TEST(                                  \
    methodName, languageValue, locationValue, decisionValue)             \
- (void)methodName {                                                      \
    [self runCompleteStockTruthForLanguage:languageValue                  \
                                  location:locationValue                  \
                                  decision:decisionValue];                \
}

ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseInteriorCandidateCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationInterior,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseInteriorCancelTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationInterior,
    IDIMEDecisionCancel)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseInteriorOrdinaryCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationInterior,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseBeforeBoundaryCandidateCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseBeforeBoundaryCancelTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseBeforeBoundaryOrdinaryCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseBeforeBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionReturnCommitThenUndo)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseBeforeBoundaryResponderLossTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionResponderLoss)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseAfterBoundaryCandidateCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseAfterBoundaryCancelTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseAfterBoundaryOrdinaryCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockJapaneseAfterBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionReturnCommitThenUndo)

ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinInteriorCandidateCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationInterior,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinInteriorCancelTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationInterior,
    IDIMEDecisionCancel)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinInteriorOrdinaryCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationInterior,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinBeforeBoundaryCandidateCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinBeforeBoundaryCancelTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinBeforeBoundaryOrdinaryCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinBeforeBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionReturnCommitThenUndo)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinBeforeBoundaryResponderLossTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionResponderLoss)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinAfterBoundaryCandidateCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinAfterBoundaryCancelTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinAfterBoundaryOrdinaryCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_STOCK_IME_TRUTH_TEST(
    testStockSimplifiedChinesePinyinAfterBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionReturnCommitThenUndo)

#undef ID_DEFINE_STOCK_IME_TRUTH_TEST

#define ID_DEFINE_CUSTOM_IME_TRUTH_TEST(                                 \
    methodName, languageValue, locationValue, decisionValue)             \
- (void)methodName {                                                     \
    [self runCompleteCustomTruthForLanguage:languageValue                \
                                     location:locationValue              \
                                     decision:decisionValue];            \
}

ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseInteriorCandidateCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationInterior,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseInteriorCancelTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationInterior,
    IDIMEDecisionCancel)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseInteriorOrdinaryCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationInterior,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinInteriorCandidateCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationInterior,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinInteriorCancelTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationInterior,
    IDIMEDecisionCancel)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinInteriorOrdinaryCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationInterior,
    IDIMEDecisionOrdinaryCommit)

ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseBeforeBoundaryCandidateCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseBeforeBoundaryCancelTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseBeforeBoundaryOrdinaryCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseAfterBoundaryCandidateCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseAfterBoundaryCancelTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseAfterBoundaryOrdinaryCommitTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinBeforeBoundaryCandidateCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinBeforeBoundaryCancelTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinBeforeBoundaryOrdinaryCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionOrdinaryCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinAfterBoundaryCandidateCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionCandidateCommit)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinAfterBoundaryCancelTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionCancel)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinAfterBoundaryOrdinaryCommitTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionOrdinaryCommit)

ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseBeforeBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionReturnCommitThenUndo)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseBeforeBoundaryResponderLossTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationBeforeBoundary,
    IDIMEDecisionResponderLoss)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomJapaneseAfterBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageJapaneseRomaji, IDIMELocationAfterBoundary,
    IDIMEDecisionReturnCommitThenUndo)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinBeforeBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionReturnCommitThenUndo)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinBeforeBoundaryResponderLossTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationBeforeBoundary,
    IDIMEDecisionResponderLoss)
ID_DEFINE_CUSTOM_IME_TRUTH_TEST(
    testCustomSimplifiedChinesePinyinAfterBoundaryReturnCommitThenUndoTruth,
    IDIMELanguageSimplifiedChinesePinyin, IDIMELocationAfterBoundary,
    IDIMEDecisionReturnCommitThenUndo)

#undef ID_DEFINE_CUSTOM_IME_TRUTH_TEST

- (void)testMinimalJapaneseBeforeBoundaryReturnCommitThenUndoTruth {
    [self runCompleteCustomTruthForLanguage:IDIMELanguageJapaneseRomaji
                                   location:IDIMELocationBeforeBoundary
                                   decision:
        IDIMEDecisionReturnCommitThenUndo
                                    minimal:YES];
}

- (void)testMinimalSimplifiedChinesePinyinInteriorCandidateCommitTruth {
    [self runCompleteCustomTruthForLanguage:
        IDIMELanguageSimplifiedChinesePinyin
                                   location:IDIMELocationInterior
                                   decision:IDIMEDecisionCandidateCommit
                                    minimal:YES];
}

@end
