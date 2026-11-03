@import XCTest;

#import "IDAutocorrectionDecisionTestSupport.h"
#import "IDIMECompositionLifecycleTestSupport.h"
#import "IDInlinePredictionLifecycleTestSupport.h"
#import "IDTextInputScenario.h"

@interface IDTextInputScenarioTests : XCTestCase
@end

@implementation IDTextInputScenarioTests

- (NSURL *)projectRootURL {
    NSString *testPath = [NSString stringWithUTF8String:__FILE__];
    return [NSURL fileURLWithPath:
        [[testPath stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]
                         isDirectory:YES];
}

- (NSURL *)fixtureURLNamed:(NSString *)name {
    return [[[self projectRootURL]
        URLByAppendingPathComponent:@"TestFixtures/TextInputScenarios"
                        isDirectory:YES]
        URLByAppendingPathComponent:
            [name stringByAppendingPathExtension:@"json"]];
}

- (NSDictionary<NSString *, id> *)validTransactionWithKind:(NSString *)kind {
    return @{
        @"kind": kind,
        @"text": NSNull.null,
        @"range": NSNull.null,
        @"selectedRange": NSNull.null,
        @"traits": @{},
        @"phase": [kind isEqualToString:@"checkpoint"]
            ? @"baseline" : NSNull.null,
    };
}

- (NSDictionary<NSString *, id> *)validScenarioDictionary {
    return @{
        @"identifier": @"ime-japanese-romaji-interior-candidate-commit",
        @"initial": @{
            @"text": @"First\nSecond",
            @"selection": @{@"location": @2, @"length": @0},
            @"traits": @{
                @"autocapitalizationType": @0,
                @"autocorrectionType": @1,
                @"spellCheckingType": @0,
                @"smartQuotesType": @0,
                @"smartDashesType": @0,
                @"smartInsertDeleteType": @0,
                @"inlinePredictionType": @0,
                @"keyboardType": @0,
                @"returnKeyType": @0,
                @"secureTextEntry": @NO,
            },
        },
        @"transactions": @[
            [self validTransactionWithKind:@"become-first-responder"],
            [self validTransactionWithKind:@"checkpoint"],
        ],
        @"comparisonFields": @[
            @"canonical", @"blocks", @"selection", @"markedRange",
            @"markedText", @"affinity", @"firstResponder", @"canUndo",
            @"canRedo", @"traits", @"caretRect", @"selectionRects",
            @"inputDelegateTrace", @"storageMutationTrace",
        ],
        @"geometryTolerance": @1.0,
        @"provenance": @{
            @"sourceFixture":
                @"UITests/Fixtures/ime-japanese-romaji-stock-contract-v1.json",
            @"stockEvidence": @".ime-task9-complete-matrix-attempt5",
            @"targetRuntime": @"iOS 26.5 (23F73)",
        },
    };
}

- (NSDictionary<NSString *, id> *)validFixtureDictionary {
    return @{
        @"schema": @1,
        @"runtime": @{@"osVersion": @"26.5", @"osBuild": @"23F73"},
        @"family": @"ime",
        @"scenarios": @[[self validScenarioDictionary]],
    };
}

- (NSDictionary<NSString *, id> *)validInlineFormattingFixtureDictionary {
    NSMutableDictionary<NSString *, id> *fixture =
        [[self validFixtureDictionary] mutableCopy];
    fixture[@"family"] = @"inline-formatting";
    NSMutableDictionary<NSString *, id> *scenario =
        [fixture[@"scenarios"][0] mutableCopy];
    scenario[@"identifier"] = @"caret-bold-type";
    scenario[@"comparisonFields"] = @[
        @"canonical", @"blocks", @"selection",
        @"typingInlineTraits", @"inlineRuns", @"canUndo", @"canRedo",
    ];
    NSMutableDictionary<NSString *, id> *toggle =
        [[self validTransactionWithKind:@"toggleInlineTrait"] mutableCopy];
    toggle[@"trait"] = @"bold";
    scenario[@"transactions"] = @[
        toggle,
        [self validTransactionWithKind:@"checkpoint"],
    ];
    fixture[@"scenarios"] = @[scenario];
    return fixture.copy;
}

- (NSURL *)writeTemporaryFixture:(NSDictionary<NSString *, id> *)fixture {
    NSURL *directory = [[NSURL fileURLWithPath:NSTemporaryDirectory()
                                   isDirectory:YES]
        URLByAppendingPathComponent:NSUUID.UUID.UUIDString
                        isDirectory:YES];
    XCTAssertTrue([[NSFileManager defaultManager]
        createDirectoryAtURL:directory
  withIntermediateDirectories:YES
                   attributes:nil
                        error:nil]);
    NSURL *url = [directory URLByAppendingPathComponent:@"fixture.json"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:fixture
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    XCTAssertNotNil(data);
    XCTAssertTrue([data writeToURL:url atomically:YES]);
    return url;
}

- (NSArray<IDTextInputScenario *> *)parseFixture:
    (NSDictionary<NSString *, id> *)fixture
                                             error:(NSError **)error {
    return IDLoadTextInputScenarios([self writeTemporaryFixture:fixture], error);
}

- (NSArray<IDTextInputScenario *> *)scenariosNamed:(NSString *)name {
    NSError *error = nil;
    NSArray<IDTextInputScenario *> *scenarios =
        IDLoadTextInputScenarios([self fixtureURLNamed:name], &error);
    XCTAssertNotNil(scenarios, @"%@", error);
    XCTAssertNil(error);
    return scenarios ?: @[];
}

- (NSArray<IDTextInputScenario *> *)allScenarios {
    NSMutableArray<IDTextInputScenario *> *all =
        [NSMutableArray array];
    for (NSString *name in @[
        @"ime-ios26.5-v1", @"autocorrection-ios26.5-v1",
        @"inline-prediction-ios26.5-v1",
        @"inline-formatting-ios26.5-v1",
    ]) {
        [all addObjectsFromArray:[self scenariosNamed:name]];
    }
    return all.copy;
}

- (void)testRepresentativeFixturesLoadWithExactRuntimeAndFamilies {
    NSArray<IDTextInputScenario *> *ime =
        [self scenariosNamed:@"ime-ios26.5-v1"];
    NSArray<IDTextInputScenario *> *correction =
        [self scenariosNamed:@"autocorrection-ios26.5-v1"];
    NSArray<IDTextInputScenario *> *prediction =
        [self scenariosNamed:@"inline-prediction-ios26.5-v1"];
    NSArray<IDTextInputScenario *> *formatting =
        [self scenariosNamed:@"inline-formatting-ios26.5-v1"];
    XCTAssertEqual(ime.count, 24U);
    XCTAssertEqual(correction.count, 21U);
    XCTAssertEqual(prediction.count, 9U);
    XCTAssertEqual(formatting.count, 14U);
    XCTAssertEqual(ime.firstObject.family, IDTextInputScenarioFamilyIME);
    XCTAssertEqual(correction.firstObject.family,
                   IDTextInputScenarioFamilyAutocorrection);
    XCTAssertEqual(prediction.firstObject.family,
                   IDTextInputScenarioFamilyInlinePrediction);
    XCTAssertEqual(formatting.firstObject.family,
                   IDTextInputScenarioFamilyInlineFormatting);
}

- (void)testIMECorpusMatchesEveryCurrentMatrixRow {
    NSArray<IDTextInputScenario *> *scenarios =
        [self scenariosNamed:@"ime-ios26.5-v1"];
    NSArray<IDIMECompositionRow *> *rows = IDIMECompositionMatrix();
    XCTAssertEqual(scenarios.count, 24U);
    XCTAssertEqualObjects(
        [NSSet setWithArray:[scenarios valueForKey:@"identifier"]],
        [NSSet setWithArray:[rows valueForKey:@"identifier"]]);

    NSSet<NSString *> *requiredPhases = [NSSet setWithArray:@[
        @"baseline", @"firstComposition", @"updatedComposition",
        @"terminal",
    ]];
    for (IDTextInputScenario *scenario in scenarios) {
        NSMutableSet<NSString *> *phases = [NSMutableSet set];
        NSMutableArray<NSNumber *> *kinds = [NSMutableArray array];
        NSUInteger begins = 0;
        NSUInteger ends = 0;
        for (IDTextInputTransaction *transaction in
             scenario.transactions) {
            [kinds addObject:@(transaction.kind)];
            if (transaction.phase != nil) {
                [phases addObject:transaction.phase];
            }
            if (transaction.kind ==
                IDTextInputTransactionKindBeginUndoGroup) {
                begins += 1;
            } else if (transaction.kind ==
                       IDTextInputTransactionKindEndUndoGroup) {
                ends += 1;
            }
        }
        XCTAssertTrue([requiredPhases isSubsetOfSet:phases],
                      @"%@", scenario.identifier);

        if ([scenario.identifier hasSuffix:@"candidate-commit"]) {
            XCTAssertTrue([kinds containsObject:
                @(IDTextInputTransactionKindReplaceRange)],
                @"%@", scenario.identifier);
        } else if ([scenario.identifier
                    hasSuffix:@"return-commit-then-undo"]) {
            XCTAssertGreaterThan(begins, 0U, @"%@", scenario.identifier);
            XCTAssertEqual(begins, ends, @"%@", scenario.identifier);
            XCTAssertTrue([kinds containsObject:
                @(IDTextInputTransactionKindUndo)],
                @"%@", scenario.identifier);
        } else if ([scenario.identifier
                    hasSuffix:@"responder-loss"]) {
            IDTextInputTransaction *lastOperation = nil;
            for (IDTextInputTransaction *transaction in
                 scenario.transactions.reverseObjectEnumerator) {
                if (transaction.kind !=
                    IDTextInputTransactionKindCheckpoint) {
                    lastOperation = transaction;
                    break;
                }
            }
            XCTAssertEqual(
                lastOperation.kind,
                IDTextInputTransactionKindResignFirstResponder,
                @"%@", scenario.identifier);
        }
    }
}

- (void)testAutocorrectionCorpusMatchesEveryCurrentMatrixRow {
    NSArray<IDTextInputScenario *> *scenarios =
        [self scenariosNamed:@"autocorrection-ios26.5-v1"];
    NSArray<IDAutocorrectionDecisionRow *> *rows =
        IDAutocorrectionDecisionMatrix();
    XCTAssertEqual(scenarios.count, 21U);
    XCTAssertEqualObjects(
        [NSSet setWithArray:[scenarios valueForKey:@"identifier"]],
        [NSSet setWithArray:[rows valueForKey:@"identifier"]]);

    for (IDTextInputScenario *scenario in scenarios) {
        NSMutableArray<NSNumber *> *kinds = [NSMutableArray array];
        NSMutableArray<NSString *> *insertions = [NSMutableArray array];
        NSUInteger begins = 0;
        NSUInteger ends = 0;
        NSUInteger undoIndex = NSNotFound;
        NSUInteger committedCheckpointIndex = NSNotFound;
        for (NSUInteger index = 0;
             index < scenario.transactions.count; index++) {
            IDTextInputTransaction *transaction =
                scenario.transactions[index];
            [kinds addObject:@(transaction.kind)];
            if (transaction.kind ==
                IDTextInputTransactionKindInsertText) {
                [insertions addObject:transaction.text];
            } else if (transaction.kind ==
                       IDTextInputTransactionKindBeginUndoGroup) {
                begins += 1;
            } else if (transaction.kind ==
                       IDTextInputTransactionKindEndUndoGroup) {
                ends += 1;
            } else if (transaction.kind ==
                       IDTextInputTransactionKindUndo) {
                undoIndex = index;
            } else if ([transaction.phase
                        isEqualToString:@"committed"]) {
                committedCheckpointIndex = index;
            }
        }

        BOOL rejects = [scenario.identifier
            hasSuffix:@"reject-precommit"];
        XCTAssertEqual(
            [kinds containsObject:
                @(IDTextInputTransactionKindReplaceRange)],
            !rejects, @"%@", scenario.identifier);
        if ([scenario.identifier hasSuffix:@"space"]) {
            XCTAssertTrue([insertions containsObject:@" "],
                          @"%@", scenario.identifier);
        } else if ([scenario.identifier
                    hasSuffix:@"punctuation"]) {
            XCTAssertTrue([insertions containsObject:@"."],
                          @"%@", scenario.identifier);
        } else if (rejects) {
            XCTAssertTrue([insertions containsObject:@" "],
                          @"%@", scenario.identifier);
        }

        if ([scenario.identifier containsString:@"undo-"]) {
            XCTAssertGreaterThan(begins, 0U, @"%@", scenario.identifier);
            XCTAssertEqual(begins, ends, @"%@", scenario.identifier);
            XCTAssertNotEqual(committedCheckpointIndex, NSNotFound,
                              @"%@", scenario.identifier);
            XCTAssertEqual(undoIndex,
                           scenario.transactions.count - 2,
                           @"%@", scenario.identifier);
            XCTAssertLessThan(committedCheckpointIndex, undoIndex,
                              @"%@", scenario.identifier);
        }
    }
}

- (void)testInlinePredictionCorpusMatchesEveryCurrentMatrixRow {
    NSArray<IDTextInputScenario *> *scenarios =
        [self scenariosNamed:@"inline-prediction-ios26.5-v1"];
    NSArray<IDInlinePredictionRow *> *rows =
        IDInlinePredictionMatrix();
    XCTAssertEqual(scenarios.count, 9U);
    XCTAssertEqualObjects(
        [NSSet setWithArray:[scenarios valueForKey:@"identifier"]],
        [NSSet setWithArray:[rows valueForKey:@"identifier"]]);

    NSSet<NSString *> *requiredPhases = [NSSet setWithArray:@[
        @"baseline", @"offered", @"terminal",
    ]];
    for (IDTextInputScenario *scenario in scenarios) {
        NSMutableSet<NSString *> *phases = [NSMutableSet set];
        NSMutableArray<NSNumber *> *kinds = [NSMutableArray array];
        NSMutableArray<NSString *> *insertions = [NSMutableArray array];
        for (IDTextInputTransaction *transaction in
             scenario.transactions) {
            if (transaction.phase != nil) {
                [phases addObject:transaction.phase];
            }
            [kinds addObject:@(transaction.kind)];
            if (transaction.kind ==
                IDTextInputTransactionKindInsertText) {
                [insertions addObject:transaction.text];
            }
        }
        XCTAssertTrue([requiredPhases isSubsetOfSet:phases],
                      @"%@", scenario.identifier);
        XCTAssertTrue([kinds containsObject:
            @(IDTextInputTransactionKindReplaceRange)],
            @"%@", scenario.identifier);
        if ([scenario.identifier hasSuffix:@"dismiss-then-type"]) {
            XCTAssertTrue([insertions containsObject:@"x"],
                          @"%@", scenario.identifier);
        } else if ([scenario.identifier
                    hasSuffix:@"accept-then-delete"]) {
            XCTAssertTrue([phases containsObject:@"accepted"],
                          @"%@", scenario.identifier);
            XCTAssertTrue([kinds containsObject:
                @(IDTextInputTransactionKindDeleteBackward)],
                @"%@", scenario.identifier);
        }
    }
}

- (void)testCompleteCorpusHasSixtyEightUniqueScenarios {
    NSArray<IDTextInputScenario *> *all = self.allScenarios;
    XCTAssertEqual(all.count, 68U);
    XCTAssertEqual(
        [NSSet setWithArray:[all valueForKey:@"identifier"]].count,
        68U);
}

- (void)testParserAcceptsCompleteVersionOneScenario {
    NSError *error = nil;
    NSArray<IDTextInputScenario *> *scenarios =
        [self parseFixture:[self validFixtureDictionary] error:&error];
    XCTAssertEqual(scenarios.count, 1U);
    XCTAssertNil(error);
    IDTextInputScenario *scenario = scenarios.firstObject;
    XCTAssertEqual(scenario.schemaVersion, 1);
    XCTAssertEqual(scenario.family, IDTextInputScenarioFamilyIME);
    XCTAssertEqualObjects(
        scenario.identifier,
        @"ime-japanese-romaji-interior-candidate-commit");
    XCTAssertEqualObjects(scenario.initialText, @"First\nSecond");
    XCTAssertTrue(NSEqualRanges(scenario.initialSelection,
                                NSMakeRange(2, 0)));
    XCTAssertEqual(scenario.transactions.count, 2U);
    XCTAssertEqual(scenario.transactions[0].kind,
                   IDTextInputTransactionKindBecomeFirstResponder);
    XCTAssertEqual(scenario.transactions[1].kind,
                   IDTextInputTransactionKindCheckpoint);
    XCTAssertEqualObjects(scenario.transactions[1].phase, @"baseline");
}

- (void)testParserAcceptsOneSemanticInlineFormattingTrait {
    NSError *error = nil;
    NSArray<IDTextInputScenario *> *scenarios = [self
        parseFixture:[self validInlineFormattingFixtureDictionary]
               error:&error];

    XCTAssertEqual(scenarios.count, 1U);
    XCTAssertNil(error);
    IDTextInputScenario *scenario = scenarios.firstObject;
    XCTAssertEqual(scenario.family,
                   IDTextInputScenarioFamilyInlineFormatting);
    XCTAssertEqual(scenario.transactions.firstObject.kind,
                   IDTextInputTransactionKindToggleInlineTrait);
    XCTAssertEqualObjects(scenario.transactions.firstObject.trait, @"bold");
}

- (void)testParserRejectsMalformedSemanticInlineFormattingTraits {
    for (id invalidTrait in @[
             @"", @"shadow", @[@"bold", @"italic"],
         ]) {
        NSMutableDictionary<NSString *, id> *fixture =
            [[self validInlineFormattingFixtureDictionary] mutableCopy];
        NSMutableDictionary<NSString *, id> *scenario =
            [fixture[@"scenarios"][0] mutableCopy];
        NSMutableDictionary<NSString *, id> *toggle =
            [scenario[@"transactions"][0] mutableCopy];
        toggle[@"trait"] = invalidTrait;
        scenario[@"transactions"] = @[
            toggle, scenario[@"transactions"][1],
        ];
        fixture[@"scenarios"] = @[scenario];

        XCTAssertNil([self parseFixture:fixture error:nil],
                     @"%@", invalidTrait);
    }
}

- (void)testParserRejectsFormattingFieldsOutsideFormattingFamily {
    NSMutableDictionary<NSString *, id> *fixture =
        [[self validFixtureDictionary] mutableCopy];
    NSMutableDictionary<NSString *, id> *scenario =
        [fixture[@"scenarios"][0] mutableCopy];
    scenario[@"comparisonFields"] = @[
        @"canonical", @"typingInlineTraits", @"inlineRuns",
    ];
    fixture[@"scenarios"] = @[scenario];

    XCTAssertNil([self parseFixture:fixture error:nil]);
}

- (void)testParserRejectsUnknownTransactionAndExtraScenarioKey {
    NSMutableDictionary *fixture =
        [[self validFixtureDictionary] mutableCopy];
    NSMutableDictionary *scenario =
        [fixture[@"scenarios"][0] mutableCopy];
    NSMutableDictionary *transaction =
        [scenario[@"transactions"][0] mutableCopy];
    transaction[@"kind"] = @"touch-candidate";
    scenario[@"transactions"] = @[transaction];
    scenario[@"unexpected"] = @YES;
    fixture[@"scenarios"] = @[scenario];
    NSError *error = nil;
    XCTAssertNil([self parseFixture:fixture error:&error]);
    XCTAssertEqualObjects(error.domain, IDTextInputScenarioErrorDomain);
}

- (void)testParserRejectsExtraTopLevelKeyAndWrongRuntime {
    NSMutableDictionary *extra =
        [[self validFixtureDictionary] mutableCopy];
    extra[@"unexpected"] = @YES;
    XCTAssertNil([self parseFixture:extra error:nil]);

    NSMutableDictionary *wrongRuntime =
        [[self validFixtureDictionary] mutableCopy];
    wrongRuntime[@"runtime"] =
        @{@"osVersion": @"26.4", @"osBuild": @"23E520"};
    XCTAssertNil([self parseFixture:wrongRuntime error:nil]);
}

- (void)testParserRejectsNonintegerAndOutOfBoundsRanges {
    for (NSDictionary *range in @[
        @{@"location": @1.5, @"length": @0},
        @{@"location": @20, @"length": @0},
        @{@"location": @2, @"length": @20},
        @{@"location": @YES, @"length": @0},
    ]) {
        NSMutableDictionary *fixture =
            [[self validFixtureDictionary] mutableCopy];
        NSMutableDictionary *scenario =
            [fixture[@"scenarios"][0] mutableCopy];
        NSMutableDictionary *initial = [scenario[@"initial"] mutableCopy];
        initial[@"selection"] = range;
        scenario[@"initial"] = initial;
        fixture[@"scenarios"] = @[scenario];
        XCTAssertNil([self parseFixture:fixture error:nil], @"%@", range);
    }
}

- (void)testParserRejectsDuplicateIdentifiers {
    NSMutableDictionary *fixture =
        [[self validFixtureDictionary] mutableCopy];
    NSDictionary *scenario = fixture[@"scenarios"][0];
    fixture[@"scenarios"] = @[scenario, [scenario copy]];
    XCTAssertNil([self parseFixture:fixture error:nil]);
}

- (void)testParserRejectsUnbalancedUndoGroups {
    for (NSArray<NSString *> *kinds in @[
        @[@"begin-undo-group", @"checkpoint"],
        @[@"end-undo-group", @"checkpoint"],
    ]) {
        NSMutableDictionary *fixture =
            [[self validFixtureDictionary] mutableCopy];
        NSMutableDictionary *scenario =
            [fixture[@"scenarios"][0] mutableCopy];
        NSMutableArray *transactions = [NSMutableArray array];
        for (NSString *kind in kinds) {
            [transactions addObject:
                [self validTransactionWithKind:kind]];
        }
        scenario[@"transactions"] = transactions;
        fixture[@"scenarios"] = @[scenario];
        XCTAssertNil([self parseFixture:fixture error:nil], @"%@", kinds);
    }
}

@end
