@import XCTest;

#import "IDIMECompositionLifecycleTestSupport.h"
#import "IDBlockDocument.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDInlineTextFormatting.h"
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import "IDEngineSourceLayout.h"

static NSString *IDIMEProjectSourceRoot(void) {
    return IDEngineSourceRoot();
}

static NSDictionary<NSString *, id> *IDIMEJSONFixture(NSString *relativePath) {
    NSString *path =
        IDEngineSourceFile(relativePath);
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) return nil;
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static BOOL IDIMEExactKeys(id value, NSArray<NSString *> *keys) {
    return [value isKindOfClass:NSDictionary.class] &&
        [[NSSet setWithArray:[value allKeys]]
            isEqualToSet:[NSSet setWithArray:keys]];
}

static BOOL IDIMENonemptyString(id value) {
    return [value isKindOfClass:NSString.class] && [value length] > 0;
}

static BOOL IDIMEFixtureActionIsValid(id value) {
    return IDIMEExactKeys(
        value, @[@"kind", @"value", @"accessibilityIdentity"]) &&
        IDIMENonemptyString(value[@"kind"]) &&
        IDIMENonemptyString(value[@"value"]) &&
        IDIMENonemptyString(value[@"accessibilityIdentity"]);
}

static BOOL IDIMEFixtureRangeIsValid(id value, NSUInteger upperBound) {
    if (!IDIMEExactKeys(value, @[@"location", @"length"])) return NO;
    id location = value[@"location"];
    id length = value[@"length"];
    if (![location isKindOfClass:NSNumber.class] ||
        ![length isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)location) == CFBooleanGetTypeID() ||
        CFGetTypeID((__bridge CFTypeRef)length) == CFBooleanGetTypeID()) {
        return NO;
    }
    NSUInteger locationValue = [location unsignedIntegerValue];
    NSUInteger lengthValue = [length unsignedIntegerValue];
    return [location doubleValue] == (double)locationValue &&
        [length doubleValue] == (double)lengthValue &&
        locationValue <= upperBound &&
        lengthValue <= upperBound - locationValue;
}

static void IDAssertIMEStockFixture(
    NSDictionary<NSString *, id> *fixture,
    NSDictionary<NSString *, id> *keyboardMode,
    NSString *expectedLanguage) {
    NSArray<NSString *> *keys = @[
        @"schema", @"runtime", @"language", @"inputModeIdentifier",
        @"primaryLanguage", @"canonicalDocument", @"interiorOffset",
        @"beforeBoundaryOffset", @"afterBoundaryOffset",
        @"physicalKeySequence", @"firstComposition", @"updatedComposition",
        @"markedSelections", @"candidateAction", @"candidateLabel",
        @"candidateAccessibilityIdentity", @"committedText",
        @"ordinaryCommitAction", @"ordinaryCommitResult", @"cancelAction",
        @"cancelResult", @"returnAction", @"returnCommitResult",
        @"undoAction", @"undoResult", @"responderLossResult",
        @"geometryTolerance",
    ];
    XCTAssertTrue(IDIMEExactKeys(fixture, keys));
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(
        fixture[@"runtime"],
        (@{@"osVersion": @"26.5", @"osBuild": @"23F73"}));
    XCTAssertEqualObjects(fixture[@"language"], expectedLanguage);
    XCTAssertEqualObjects(
        fixture[@"inputModeIdentifier"],
        keyboardMode[@"inputModeIdentifier"]);
    XCTAssertEqualObjects(
        fixture[@"primaryLanguage"], keyboardMode[@"primaryLanguage"]);

    NSString *canonical = fixture[@"canonicalDocument"];
    XCTAssertTrue(IDIMENonemptyString(canonical));
    NSRange boundary = [canonical rangeOfString:@"\n"];
    XCTAssertNotEqual(boundary.location, NSNotFound);
    XCTAssertEqualObjects(fixture[@"beforeBoundaryOffset"],
                          @(boundary.location));
    XCTAssertEqualObjects(fixture[@"afterBoundaryOffset"],
                          @(NSMaxRange(boundary)));
    XCTAssertTrue(IDIMEFixtureRangeIsValid(
        @{@"location": fixture[@"interiorOffset"], @"length": @0},
        canonical.length));

    NSArray<NSString *> *physicalKeys = fixture[@"physicalKeySequence"];
    XCTAssertTrue([physicalKeys isKindOfClass:NSArray.class]);
    XCTAssertGreaterThan(physicalKeys.count, 1U);
    for (id key in physicalKeys) XCTAssertTrue(IDIMENonemptyString(key));

    NSString *firstComposition = fixture[@"firstComposition"];
    NSString *updatedComposition = fixture[@"updatedComposition"];
    XCTAssertTrue(IDIMENonemptyString(firstComposition));
    XCTAssertTrue(IDIMENonemptyString(updatedComposition));
    XCTAssertNotEqualObjects(firstComposition, updatedComposition);
    NSArray *markedSelections = fixture[@"markedSelections"];
    XCTAssertTrue([markedSelections isKindOfClass:NSArray.class]);
    XCTAssertEqual(markedSelections.count, 2U);
    if (markedSelections.count == 2) {
        XCTAssertTrue(IDIMEFixtureRangeIsValid(
            markedSelections[0], firstComposition.length));
        XCTAssertTrue(IDIMEFixtureRangeIsValid(
            markedSelections[1], updatedComposition.length));
    }

    for (NSString *actionKey in @[
        @"candidateAction", @"ordinaryCommitAction", @"cancelAction",
        @"returnAction", @"undoAction",
    ]) {
        XCTAssertTrue(IDIMEFixtureActionIsValid(fixture[actionKey]),
                      @"%@", actionKey);
    }
    for (NSString *stringKey in @[
        @"candidateLabel", @"candidateAccessibilityIdentity",
        @"committedText", @"ordinaryCommitResult", @"cancelResult",
        @"returnCommitResult", @"undoResult", @"responderLossResult",
    ]) {
        XCTAssertTrue(IDIMENonemptyString(fixture[stringKey]), @"%@",
                      stringKey);
    }

    id tolerance = fixture[@"geometryTolerance"];
    XCTAssertTrue([tolerance isKindOfClass:NSNumber.class]);
    XCTAssertNotEqual(
        CFGetTypeID((__bridge CFTypeRef)tolerance), CFBooleanGetTypeID());
    XCTAssertTrue(isfinite([tolerance doubleValue]));
    XCTAssertGreaterThanOrEqual([tolerance doubleValue], 0.0);
}

static NSDictionary<NSString *, id> *IDValidIMECompositionStatus(void) {
    return @{
        @"schema": @1,
        @"scenario": @"ime-japanese-romaji-interior-candidate-commit",
        @"language": @"japanese-romaji",
        @"location": @"interior",
        @"decision": @"candidate-commit",
        @"canonical": @"Firstかな\nSecond",
        @"blocks": @[@"Firstかな", @"Second"],
        @"blockIdentifiers": @[@"block-a", @"block-b"],
        @"anchorIdentities": @[@"anchor-caret"],
        @"selection": @{@"location": @7, @"length": @0},
        @"affinity": @"forward",
        @"markedRange": @{@"location": @5, @"length": @2},
        @"markedText": @"かな",
        @"markedSelection": @{@"location": @2, @"length": @0},
        @"markedAttributeKeys": @[@"NSMarkedClauseSegment"],
        @"structuralNewlineLocations": @[@7],
        @"checkingRanges": @[],
        @"temporaryRenderingDescriptors": @[
            @{
                @"range": @{@"location": @5, @"length": @2},
                @"attributeKeys": @[@"NSMarkedClauseSegment"],
                @"valueDescriptions": @[@"0"],
            },
        ],
        @"candidateDescriptor": @{
            @"visible": @YES,
            @"actionable": @YES,
            @"labels": @[@"仮名"],
            @"selectedLabel": @"仮名",
            @"geometry": @{
                @"x": @8, @"y": @40, @"width": @120, @"height": @44,
            },
        },
        @"keyboardState": @{
            @"visible": @YES,
            @"primaryLanguage": @"ja-JP",
            @"enabledInputModeIdentifiers": @[@"observed-japanese-romaji"],
        },
        @"compositionGeometry": @{
            @"x": @12, @"y": @20, @"width": @38, @"height": @22,
        },
        @"mutationTrace": @[@"setMarkedText"],
        @"eventTrace": @[@"selectionWillChange", @"textWillChange",
                         @"textDidChange", @"selectionDidChange"],
        @"coordinateSpaceIdentity": @"document-interaction-container",
        @"documentRevision": @1,
        @"textEpoch": @1,
        @"selectionEpoch": @1,
        @"checkingEpoch": @0,
        @"layoutEpoch": @1,
        @"firstResponder": @YES,
    };
}

static NSString *IDIMEJSONString(NSDictionary<NSString *, id> *dictionary) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@interface IDIMECompositionLifecycleContractTests : XCTestCase
@end

@implementation IDIMECompositionLifecycleContractTests

- (void)testMarkedTextUpdatesCarryTypingTraitsAndCommitOnce {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@""],
        ]];
    [view toggleInlineTextTrait:IDInlineTextTraitUnderline];
    NSUInteger initialRevision = view.id_document.documentRevision;

    [view setMarkedText:@"ka" selectedRange:NSMakeRange(2, 0)];
    [view setMarkedText:@"かな" selectedRange:NSMakeRange(2, 0)];
    NSUInteger revisionBeforeCommit = view.id_document.documentRevision;
    [view unmarkText];

    XCTAssertEqualObjects(view.text, @"かな");
    XCTAssertGreaterThan(revisionBeforeCommit, initialRevision);
    XCTAssertEqual(view.id_document.documentRevision, revisionBeforeCommit);
    for (NSUInteger index = 0; index < 2; index++) {
        XCTAssertTrue([[view.attributedBlocks[0]
            attribute:IDInlineTextUnderlineAttributeName
              atIndex:index
       effectiveRange:NULL] boolValue]);
    }
}

- (void)testMatrixContainsTwentyFourUniqueLanguageMajorRows {
    NSArray<IDIMECompositionRow *> *rows = IDIMECompositionMatrix();
    XCTAssertEqual(rows.count, 24U);
    NSCountedSet<NSNumber *> *languages = [NSCountedSet set];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (IDIMECompositionRow *row in rows) {
        [languages addObject:@(row.language)];
        [identifiers addObject:row.identifier];
        XCTAssertGreaterThan(row.identifier.length, 0U);
        if (row.decision == IDIMEDecisionResponderLoss) {
            XCTAssertEqual(row.location, IDIMELocationBeforeBoundary);
        }
        if (row.decision == IDIMEDecisionReturnCommitThenUndo) {
            XCTAssertNotEqual(row.location, IDIMELocationInterior);
        }
    }
    XCTAssertEqual(
        [languages countForObject:@(IDIMELanguageJapaneseRomaji)], 12U);
    XCTAssertEqual(
        [languages countForObject:
            @(IDIMELanguageSimplifiedChinesePinyin)], 12U);
    XCTAssertEqual(identifiers.count, 24U);

    for (NSUInteger index = 1; index < rows.count; index += 1) {
        IDIMECompositionRow *previous = rows[index - 1];
        IDIMECompositionRow *current = rows[index];
        XCTAssertTrue(previous.language < current.language ||
            (previous.language == current.language &&
             previous.location <= current.location));
    }
}

- (void)testParserAcceptsCompleteVersionOnePayload {
    NSError *error = nil;
    IDIMECompositionStatus *status = IDParseIMECompositionStatus(
        IDIMEJSONString(IDValidIMECompositionStatus()), &error);
    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertEqualObjects(
        status.scenario, @"ime-japanese-romaji-interior-candidate-commit");
    XCTAssertEqualObjects(status.language, @"japanese-romaji");
    XCTAssertEqualObjects(status.location, @"interior");
    XCTAssertEqualObjects(status.decision, @"candidate-commit");
    XCTAssertEqualObjects(status.canonical, @"Firstかな\nSecond");
    XCTAssertEqualObjects(status.blocks, (@[@"Firstかな", @"Second"]));
    XCTAssertEqual(status.markedRange.location, 5U);
    XCTAssertEqualObjects(status.markedText, @"かな");
    XCTAssertEqual(status.layoutEpoch, 1U);
    XCTAssertTrue(status.isFirstResponder);
}

- (void)testParserRejectsMissingAndExtraTopLevelKeys {
    NSMutableDictionary *missing =
        [IDValidIMECompositionStatus() mutableCopy];
    [missing removeObjectForKey:@"candidateDescriptor"];
    XCTAssertNil(IDParseIMECompositionStatus(
        IDIMEJSONString(missing), NULL));

    NSMutableDictionary *extra =
        [IDValidIMECompositionStatus() mutableCopy];
    extra[@"unexpected"] = @YES;
    XCTAssertNil(IDParseIMECompositionStatus(IDIMEJSONString(extra), NULL));
}

- (void)testParserRejectsMissingAndExtraCandidateKeys {
    for (NSDictionary *candidate in @[
        @{@"visible": @YES},
        @{
            @"visible": @YES,
            @"actionable": @YES,
            @"labels": @[@"仮名"],
            @"selectedLabel": @"仮名",
            @"geometry": @{
                @"x": @0, @"y": @0, @"width": @1, @"height": @1,
            },
            @"unexpected": @1,
        },
    ]) {
        NSMutableDictionary *payload =
            [IDValidIMECompositionStatus() mutableCopy];
        payload[@"candidateDescriptor"] = candidate;
        NSError *error = nil;
        XCTAssertNil(IDParseIMECompositionStatus(
            IDIMEJSONString(payload), &error));
        XCTAssertEqualObjects(error.domain, IDIMECompositionStatusErrorDomain);
    }
}

- (void)testParserRejectsNumericBooleanAndNonfiniteGeometry {
    NSMutableDictionary *numericBoolean =
        [IDValidIMECompositionStatus() mutableCopy];
    numericBoolean[@"firstResponder"] = @1;
    XCTAssertNil(IDParseIMECompositionStatus(
        IDIMEJSONString(numericBoolean), NULL));

    NSString *serialized =
        IDIMEJSONString(IDValidIMECompositionStatus());
    NSString *nonfinite = [serialized
        stringByReplacingOccurrencesOfString:@"\"x\":12"
                                  withString:@"\"x\":1e999"];
    XCTAssertNil(IDParseIMECompositionStatus(nonfinite, NULL));
}

- (void)testParserRejectsMalformedKeyboardAndRangeCollections {
    NSMutableDictionary *keyboard =
        [IDValidIMECompositionStatus() mutableCopy];
    keyboard[@"keyboardState"] = @{
        @"visible": @1,
        @"primaryLanguage": @"ja-JP",
        @"enabledInputModeIdentifiers": @[@"observed-japanese-romaji"],
    };
    XCTAssertNil(IDParseIMECompositionStatus(IDIMEJSONString(keyboard), NULL));

    for (NSString *key in @[
        @"structuralNewlineLocations", @"checkingRanges",
        @"markedAttributeKeys", @"blockIdentifiers", @"anchorIdentities",
    ]) {
        NSMutableDictionary *payload =
            [IDValidIMECompositionStatus() mutableCopy];
        payload[key] = @1;
        XCTAssertNil(IDParseIMECompositionStatus(
            IDIMEJSONString(payload), NULL), @"%@", key);
    }
}

- (void)testParserRejectsInconsistentCanonicalAndMarkedText {
    NSMutableDictionary *blocks =
        [IDValidIMECompositionStatus() mutableCopy];
    blocks[@"blocks"] = @[@"Different", @"Second"];
    XCTAssertNil(IDParseIMECompositionStatus(IDIMEJSONString(blocks), NULL));

    NSMutableDictionary *marked =
        [IDValidIMECompositionStatus() mutableCopy];
    marked[@"markedText"] = @"not-the-substring";
    XCTAssertNil(IDParseIMECompositionStatus(IDIMEJSONString(marked), NULL));
}

- (void)testJapaneseFixtureIsStrictAndComplete {
    NSDictionary<NSString *, id> *fixture = IDIMEJSONFixture(
        @"UITests/Fixtures/ime-japanese-romaji-stock-contract-v1.json");
    XCTAssertNotNil(fixture, @"Japanese stock truth must be frozen only after "
                            @"three independently erased observations agree");
    if (fixture == nil) return;

    NSDictionary<NSString *, id> *keyboardContract = IDIMEJSONFixture(
        @"UITests/Fixtures/ime-keyboard-modes-ios26.5-v1.json");
    XCTAssertNotNil(keyboardContract);
    NSDictionary<NSString *, id> *japaneseMode =
        [keyboardContract[@"inputModes"] firstObject];
    IDAssertIMEStockFixture(
        fixture, japaneseMode, @"japanese-romaji");
}

- (void)testChineseFixtureIsStrictAndComplete {
    NSDictionary<NSString *, id> *fixture = IDIMEJSONFixture(
        @"UITests/Fixtures/"
         "ime-simplified-chinese-pinyin-stock-contract-v1.json");
    XCTAssertNotNil(fixture, @"Chinese stock truth must be frozen only after "
                            @"three independently erased observations agree");
    if (fixture == nil) return;

    NSDictionary<NSString *, id> *keyboardContract = IDIMEJSONFixture(
        @"UITests/Fixtures/ime-keyboard-modes-ios26.5-v1.json");
    XCTAssertNotNil(keyboardContract);
    NSArray<NSDictionary<NSString *, id> *> *inputModes =
        keyboardContract[@"inputModes"];
    XCTAssertEqual(inputModes.count, 2U);
    IDAssertIMEStockFixture(
        fixture, inputModes.lastObject, @"simplified-chinese-pinyin");

    NSDictionary<NSString *, id> *japanese = IDIMEJSONFixture(
        @"UITests/Fixtures/ime-japanese-romaji-stock-contract-v1.json");
    XCTAssertNotNil(japanese);
    XCTAssertNotEqualObjects(
        fixture[@"language"], japanese[@"language"]);
    XCTAssertNotEqualObjects(
        fixture[@"inputModeIdentifier"], japanese[@"inputModeIdentifier"]);
    XCTAssertNotEqualObjects(
        fixture[@"physicalKeySequence"], japanese[@"physicalKeySequence"]);
    XCTAssertNotEqualObjects(
        (@[fixture[@"firstComposition"], fixture[@"updatedComposition"]]),
        (@[japanese[@"firstComposition"], japanese[@"updatedComposition"]]));
}

- (void)testCompleteStockLifecycleHasOneAddressableMethodPerMatrixRow {
    NSString *root = IDIMEProjectSourceRoot();
    NSString *testSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDIMECompositionLifecycleUITests.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    NSString *runner = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"Scripts/run-ime-stock-truth.sh")
        encoding:NSUTF8StringEncoding
        error:nil];
    XCTAssertNotNil(testSource);
    XCTAssertNotNil(runner);

    NSArray<NSString *> *languages =
        @[@"Japanese", @"SimplifiedChinesePinyin"];
    NSArray<NSString *> *locations =
        @[@"Interior", @"BeforeBoundary", @"AfterBoundary"];
    NSArray<NSString *> *decisions = @[
        @"CandidateCommit", @"Cancel", @"OrdinaryCommit",
        @"ReturnCommitThenUndo", @"ResponderLoss",
    ];
    NSMutableSet<NSString *> *methods = [NSMutableSet set];
    for (IDIMECompositionRow *row in IDIMECompositionMatrix()) {
        NSString *method = [NSString stringWithFormat:
            @"testStock%@%@%@Truth",
            languages[(NSUInteger)row.language],
            locations[(NSUInteger)row.location],
            decisions[(NSUInteger)row.decision]];
        XCTAssertTrue([testSource containsString:method], @"%@", method);
        XCTAssertTrue([runner containsString:method], @"%@", method);
        [methods addObject:method];
    }
    XCTAssertEqual(methods.count, 24U);
    XCTAssertTrue([runner containsString:@"\"all\""]);
    XCTAssertTrue([runner containsString:@"stock_test_methods"]);
    XCTAssertTrue([runner containsString:@"for test_method"]);
    XCTAssertTrue([runner containsString:@"-parallel-testing-enabled NO"]);
}

- (void)testCustomInteriorDifferentialIsAddressableAndHostNeutral {
    NSString *root = IDIMEProjectSourceRoot();
    NSString *appSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"App/IDDemoViewController.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    NSString *supportSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDIMECompositionLifecycleTestSupport.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    NSString *testSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDIMECompositionLifecycleUITests.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    NSString *runner = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"Scripts/run-ime-stock-truth.sh")
        encoding:NSUTF8StringEncoding
        error:nil];
    XCTAssertNotNil(appSource);
    XCTAssertNotNil(supportSource);
    XCTAssertNotNil(testSource);
    XCTAssertNotNil(runner);

    XCTAssertTrue([appSource containsString:@"ime-composition-status"]);
    XCTAssertTrue([appSource containsString:@"hasPrefix:@\"ime-\""]);
    XCTAssertTrue([supportSource containsString:
        @"XCUIApplication *IDLaunchCustomIMECompositionScenario("]);
    XCTAssertTrue([supportSource containsString:
        @"elements[@\"block-text-view\"]"]);

    for (NSString *language in @[
        @"Japanese", @"SimplifiedChinesePinyin",
    ]) {
        for (NSString *decision in @[
            @"CandidateCommit", @"Cancel", @"OrdinaryCommit",
        ]) {
            NSString *method = [NSString stringWithFormat:
                @"testCustom%@Interior%@Truth", language, decision];
            XCTAssertTrue([testSource containsString:method], @"%@", method);
            XCTAssertTrue([runner containsString:method], @"%@", method);
        }
    }
    XCTAssertTrue([runner containsString:@"--location"]);
    XCTAssertTrue([runner containsString:@"--host"]);
    XCTAssertTrue([runner containsString:@"-parallel-testing-enabled NO"]);
    XCTAssertTrue([runner containsString:@"rg \"$pinned_udid\""]);
    XCTAssertFalse([runner containsString:@"xcodebuild .*test"]);
}

- (void)testStockIMEStatusPublishesUIKitSelectionAffinity {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"StockOracleHost/main.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    XCTAssertNotNil(source);
    XCTAssertTrue([source containsString:
        @"@\"affinity\": editor.selectionAffinity =="]);
}

- (void)testCustomBoundaryDifferentialHasTwelveAddressableRows {
    NSString *root = IDIMEProjectSourceRoot();
    NSString *testSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDIMECompositionLifecycleUITests.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    NSString *runner = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"Scripts/run-ime-stock-truth.sh")
        encoding:NSUTF8StringEncoding
        error:nil];
    XCTAssertNotNil(testSource);
    XCTAssertNotNil(runner);

    for (NSString *language in @[
        @"Japanese", @"SimplifiedChinesePinyin",
    ]) {
        for (NSString *location in @[
            @"BeforeBoundary", @"AfterBoundary",
        ]) {
            for (NSString *decision in @[
                @"CandidateCommit", @"Cancel", @"OrdinaryCommit",
            ]) {
                NSString *method = [NSString stringWithFormat:
                    @"testCustom%@%@%@Truth",
                    language, location, decision];
                XCTAssertTrue(
                    [testSource containsString:method], @"%@", method);
                XCTAssertTrue([runner containsString:method], @"%@", method);
            }
        }
    }
    XCTAssertTrue([runner containsString:@"--location boundary"]);
    XCTAssertTrue([runner containsString:
        @"--decision candidate-commit,cancel,ordinary-commit"]);
    XCTAssertTrue([runner containsString:@"-parallel-testing-enabled NO"]);
}

- (void)testCustomTerminalDifferentialHasSixAddressableRowsAndUIKitActions {
    NSString *root = IDIMEProjectSourceRoot();
    NSString *appSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"App/IDDemoViewController.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    NSString *testSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDIMECompositionLifecycleUITests.m")
        encoding:NSUTF8StringEncoding
        error:nil];
    NSString *runner = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"Scripts/run-ime-stock-truth.sh")
        encoding:NSUTF8StringEncoding
        error:nil];
    XCTAssertNotNil(appSource);
    XCTAssertNotNil(testSource);
    XCTAssertNotNil(runner);

    for (NSString *language in @[
        @"Japanese", @"SimplifiedChinesePinyin",
    ]) {
        for (NSString *location in @[
            @"BeforeBoundary", @"AfterBoundary",
        ]) {
            NSString *method = [NSString stringWithFormat:
                @"testCustom%@%@ReturnCommitThenUndoTruth",
                language, location];
            XCTAssertTrue([testSource containsString:method], @"%@", method);
            XCTAssertTrue([runner containsString:method], @"%@", method);
        }
        NSString *responderMethod = [NSString stringWithFormat:
            @"testCustom%@BeforeBoundaryResponderLossTruth", language];
        XCTAssertTrue(
            [testSource containsString:responderMethod], @"%@", responderMethod);
        XCTAssertTrue(
            [runner containsString:responderMethod], @"%@", responderMethod);
    }

    XCTAssertTrue([appSource containsString:@"@\"ime-undo\""]);
    XCTAssertTrue([appSource containsString:@"@\"ime-resign\""]);
    XCTAssertTrue([appSource containsString:@".undoManager undo"]);
    XCTAssertTrue([appSource containsString:@"resignFirstResponder"]);
    XCTAssertTrue([runner containsString:
        @"return-commit-then-undo,responder-loss"]);
    XCTAssertTrue([runner containsString:@"terminal_custom_methods"]);
    XCTAssertTrue([runner containsString:@"-parallel-testing-enabled NO"]);
}

@end
