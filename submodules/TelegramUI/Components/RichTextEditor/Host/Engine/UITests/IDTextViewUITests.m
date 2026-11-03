@import XCTest;

@interface IDTextViewUITests : XCTestCase
@end

@implementation IDTextViewUITests

- (XCUIApplication *)launchApplication {
    XCUIApplication *application = [XCUIApplication new];
    [application launch];
    return application;
}

- (XCUIApplication *)launchInlineFormattingApplication {
    XCUIApplication *application = [XCUIApplication new];
    application.launchArguments = @[
        @"--id-block-ui-scenario", @"inline-formatting",
    ];
    [application launch];
    return application;
}

- (NSDictionary *)inlineFormattingDiagnostics:
    (XCUIApplication *)application {
    XCUIElement *element =
        [application descendantsMatchingType:XCUIElementTypeAny][
            @"inline-format-diagnostics"];
    XCTAssertTrue([element waitForExistenceWithTimeout:3.0]);
    NSData *data = [[element.value description]
        dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *value =
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertTrue([value isKindOfClass:NSDictionary.class]);
    return value;
}

- (XCUIElement *)editorInApplication:(XCUIApplication *)application {
    return [application descendantsMatchingType:XCUIElementTypeAny][@"custom-text-view"];
}

- (void)waitForElementToDisappear:(XCUIElement *)element {
    NSPredicate *gone = [NSPredicate predicateWithFormat:@"exists == NO"];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:gone object:element];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:3.0],
                   XCTWaiterResultCompleted);
}

- (void)testLaunchFindsExactlyOneCustomEditorAndTypingUpdatesItsValue {
    XCUIApplication *application = [self launchApplication];
    XCUIElementQuery *editors =
        [[application descendantsMatchingType:XCUIElementTypeAny]
            matchingIdentifier:@"custom-text-view"];
    XCTAssertTrue([editors.firstMatch waitForExistenceWithTimeout:3.0]);
    XCTAssertEqual(editors.count, 1);

    XCUIElement *editor = editors.firstMatch;
    [editor tap];
    [editor typeText:@"Hello "];
    XCTAssertTrue([[editor.value description] containsString:@"Hello "]);
}

- (void)testEditableToggleBlocksFurtherTypingAndReportsState {
    XCUIApplication *application = [self launchApplication];
    XCUIElement *editor = [self editorInApplication:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:3.0]);
    [editor tap];
    [editor typeText:@"Before "];

    XCUIElement *toggle = application.buttons[@"editable-toggle"];
    XCTAssertTrue(toggle.exists);
    XCTAssertEqualObjects(toggle.label, @"Editable");
    XCTAssertEqualObjects(toggle.value, @"On");
    [toggle tap];
    XCTAssertEqualObjects(toggle.label, @"Editable");
    XCTAssertEqualObjects(toggle.value, @"Off");
    id valueBeforeBlockedType = editor.value;
    [self waitForElementToDisappear:application.keyboards.firstMatch];
    [editor tap];
    XCTAssertFalse(application.keyboards.firstMatch.exists);
    XCTAssertEqualObjects(editor.value, valueBeforeBlockedType);
}

- (void)testSelectableToggleReportsStateIndependently {
    XCUIApplication *application = [self launchApplication];
    XCUIElement *toggle = application.buttons[@"selectable-toggle"];
    XCTAssertTrue([toggle waitForExistenceWithTimeout:3.0]);
    XCTAssertEqualObjects(toggle.label, @"Selectable");
    XCTAssertEqualObjects(toggle.value, @"On");

    [toggle tap];
    XCTAssertEqualObjects(toggle.label, @"Selectable");
    XCTAssertEqualObjects(toggle.value, @"Off");
    XCTAssertEqualObjects(application.buttons[@"editable-toggle"].value, @"On");
    [toggle tap];
    XCTAssertEqualObjects(toggle.value, @"On");
}

- (void)testResetRestoresSampleText {
    XCUIApplication *application = [self launchApplication];
    XCUIElement *editor = [self editorInApplication:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:3.0]);
    NSString *sample = [editor.value description];
    [editor tap];
    [editor typeText:@"Changed "];
    XCTAssertNotEqualObjects(editor.value, sample);

    [application.buttons[@"reset-button"] tap];
    XCTAssertEqualObjects(editor.value, sample);
}

- (void)testLongSampleScrollGestureChangesVerticalPosition {
    XCUIApplication *application = [self launchApplication];
    XCUIElement *editor = [self editorInApplication:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:3.0]);
    XCUIElement *indicator = nil;
    for (XCUIElement *candidate in editor.otherElements.allElementsBoundByIndex) {
        if (candidate.value != nil && candidate.frame.size.height > candidate.frame.size.width) {
            indicator = candidate;
            break;
        }
    }
    XCTAssertNotNil(indicator);
    id valueBeforeScroll = indicator.value;

    [editor swipeUp];

    NSPredicate *valueChanged = [NSPredicate predicateWithBlock:^BOOL(XCUIElement *element,
                                                                      NSDictionary *bindings) {
        return ![element.value isEqual:valueBeforeScroll];
    }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:valueChanged object:indicator];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:3.0],
                   XCTWaiterResultCompleted);
}

- (void)testDismissHidesTheKeyboard {
    XCUIApplication *application = [self launchApplication];
    XCUIElement *editor = [self editorInApplication:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:3.0]);
    [editor tap];
    XCTAssertTrue([application.keyboards.firstMatch waitForExistenceWithTimeout:3.0]);

    [application.buttons[@"dismiss-button"] tap];
    [self waitForElementToDisappear:application.keyboards.firstMatch];
}

- (void)testDiagnosticsReportIsReachableAndCompatible {
    XCUIApplication *application = [self launchApplication];
    XCUIElement *button = application.buttons[@"diagnostics-button"];
    XCTAssertTrue([button waitForExistenceWithTimeout:3.0]);
    [button tap];

    XCTAssertTrue([application.staticTexts[@"All required contracts present"]
        waitForExistenceWithTimeout:2.0]);
    XCTAssertTrue([[application descendantsMatchingType:XCUIElementTypeAny][@"compatibility-report"]
        waitForExistenceWithTimeout:2.0]);
}

- (void)testInlineFormattingToolbarReflectsCaretAndMixedSelectionState {
    XCUIApplication *application = [self launchInlineFormattingApplication];
    XCUIElement *bold = application.buttons[@"inline-format-bold"];
    XCTAssertTrue([bold waitForExistenceWithTimeout:3.0]);
    XCTAssertEqualObjects(bold.value, @"Mixed");

    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][
            @"block-text-view"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:3.0]);
    [editor tap];
    XCTAssertEqualObjects(bold.value, @"Off");

    [bold tap];

    XCTAssertEqualObjects(bold.value, @"On");
    NSDictionary *formatting =
        [self inlineFormattingDiagnostics:application][@"inlineFormatting"];
    XCTAssertEqualObjects(formatting[@"states"][@"bold"], @"on");
}

- (void)testInlineFormattingToolbarFormatsAcrossBlocks {
    XCUIApplication *application = [self launchInlineFormattingApplication];
    XCUIElement *underline = application.buttons[@"inline-format-underline"];
    XCTAssertTrue([underline waitForExistenceWithTimeout:3.0]);
    XCTAssertEqualObjects(underline.value, @"Off");

    [underline tap];

    XCTAssertEqualObjects(underline.value, @"On");
    NSDictionary *formatting =
        [self inlineFormattingDiagnostics:application][@"inlineFormatting"];
    NSArray<NSDictionary *> *blocks = formatting[@"blocks"];
    XCTAssertEqual(blocks.count, 2U);
    XCTAssertEqualObjects(blocks[0][@"runs"][0][@"traits"],
                          (@[@"bold", @"underline"]));
    XCTAssertEqualObjects(blocks[1][@"runs"][0][@"traits"],
                          (@[@"underline"]));
    XCTAssertNil(formatting[@"separatorTraits"]);
}

@end
