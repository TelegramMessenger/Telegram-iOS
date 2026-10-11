@import XCTest;

#import "IDHIDEventTestSupport.h"

static NSString *const IDInlineFormattingKeyboardScenario =
    @"inline-formatting-keyboard";
static NSString *const IDInlineFormattingKeyboardStatusIdentifier =
    @"inline-formatting-keyboard-status";

@interface IDInlineFormattingKeyboardUITests : XCTestCase
@end

@implementation IDInlineFormattingKeyboardUITests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

- (BOOL)waitForSoftwareKeyboardReady:(XCUIApplication *)application
                             timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        XCUIElementQuery *keys =
            [application.keyboards.keys matchingIdentifier:@"t"];
        if (keys.count == 1 && keys.firstMatch.isHittable) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

- (XCUIApplication *)launchStock:(BOOL)stock
                          minimal:(BOOL)minimal {
    XCUIApplication *application = stock
        ? [[XCUIApplication alloc]
            initWithBundleIdentifier:@"com.inputdec.stockoracle"]
        : [XCUIApplication new];
    [application terminate];
    NSArray<NSString *> *customArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", IDInlineFormattingKeyboardScenario,
    ];
    if (minimal) {
        customArguments = [customArguments arrayByAddingObjectsFromArray:@[
            @"-InputDecBehaviorBackend", @"minimal",
        ]];
    }
    application.launchArguments = stock
        ? @[@"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US"]
        : customArguments;
    application.launchEnvironment = stock
        ? @{
            @"IDStockTouchScenario": IDInlineFormattingKeyboardScenario,
            @"IDStockEditorFrame":
                NSStringFromCGRect(CGRectMake(16, 198, 370, 360)),
            @"IDInlineFormattingOriginal": @"adress",
            @"IDForceEnglishUSInputMode": @"1",
        }
        : @{
            @"IDInlineFormattingOriginal": @"adress",
            @"IDForceEnglishUSInputMode": @"1",
        };
    [application launch];
    if (![self waitForSoftwareKeyboardReady:application timeout:5.0]) {
        [application terminate];
        [application launch];
        XCTAssertTrue(
            [self waitForSoftwareKeyboardReady:application timeout:5.0],
            @"Software keyboard did not become ready");
    }

    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][
            stock ? @"stock-text-view" : @"block-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][
            IDInlineFormattingKeyboardStatusIdentifier];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    if (minimal) {
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
        NSPredicate *activeTyping = [NSPredicate predicateWithFormat:
            @"identifier == %@ AND state == %@",
            @"typingAttributes", @"active"];
        XCTAssertEqual(
            [payload[@"report"][@"capabilities"]
                filteredArrayUsingPredicate:activeTyping].count,
            1U);
    }
    return application;
}

- (XCUIApplication *)launchStock:(BOOL)stock {
    return [self launchStock:stock minimal:NO];
}

- (NSDictionary<NSString *, id> *)status:
    (XCUIApplication *)application {
    XCUIElement *element =
        [application descendantsMatchingType:XCUIElementTypeAny][
            IDInlineFormattingKeyboardStatusIdentifier];
    XCTAssertTrue([element waitForExistenceWithTimeout:4.0]);
    NSString *serialized = [element.value isKindOfClass:NSString.class]
        ? element.value : @"{}";
    NSData *data = [serialized dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *status = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertTrue([status isKindOfClass:NSDictionary.class],
                  @"Invalid formatting status: %@", serialized);
    return status;
}

- (NSDictionary<NSString *, id> *)waitForStatus:
    (XCUIApplication *)application
                                    predicate:
    (BOOL (^)(NSDictionary<NSString *, id> *))predicate
                                      timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSDictionary<NSString *, id> *status = nil;
    do {
        status = [self status:application];
        if (predicate(status)) return status;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    XCTFail(@"Formatting status did not reach expected state: %@", status);
    return status;
}

- (BOOL)waitForHittableElement:(XCUIElement *)element
                       timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        if (element.exists && element.isHittable) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

- (void)assertStockStatus:(NSDictionary<NSString *, id> *)stock
      matchesCustomStatus:(NSDictionary<NSString *, id> *)custom {
    NSArray<NSString *> *keys = @[
        @"canonical", @"selection", @"markedRange",
        @"typingInlineTraits", @"inlineRuns", @"canUndo",
    ];
    for (NSString *key in keys) {
        XCTAssertEqualObjects(stock[key], custom[key], @"%@", key);
    }
}

- (NSDictionary<NSString *, id> *)runBoldTypingStock:(BOOL)stock
                                              minimal:(BOOL)minimal {
    XCUIApplication *application =
        [self launchStock:stock minimal:minimal];
    XCTAssertTrue(IDHIDTypeSoftwareKeyboardText(
        self, application, @"hello"));
    return [self waitForStatus:application
        predicate:^BOOL(NSDictionary<NSString *, id> *status) {
            return [status[@"canonical"] isEqual:@"hello"];
        }
        timeout:4.0];
}

- (NSDictionary<NSString *, id> *)runBoldTypingStock:(BOOL)stock {
    return [self runBoldTypingStock:stock minimal:NO];
}

- (NSDictionary<NSString *, id> *)runAutocorrectionStock:(BOOL)stock
                                                   minimal:(BOOL)minimal {
    XCUIApplication *application =
        [self launchStock:stock minimal:minimal];
    XCTAssertTrue(IDHIDTypeSoftwareKeyboardText(
        self, application, @"adress"));
    NSPredicate *candidatePredicate = [NSPredicate predicateWithFormat:
        @"label == %@ OR value == %@ OR identifier == %@",
        @"address", @"address", @"address"];
    XCUIElement *candidate =
        [[application descendantsMatchingType:XCUIElementTypeAny]
            matchingPredicate:candidatePredicate].firstMatch;
    XCTAssertTrue([self waitForHittableElement:candidate timeout:5.0],
                  @"Expected native candidate 'address' was not actionable");
    [candidate tap];
    [NSThread sleepForTimeInterval:0.5];
    return [self waitForStatus:application
        predicate:^BOOL(NSDictionary<NSString *, id> *status) {
            return [status[@"canonical"] isEqual:@"address "];
        }
        timeout:4.0];
}

- (NSDictionary<NSString *, id> *)runAutocorrectionStock:(BOOL)stock {
    return [self runAutocorrectionStock:stock minimal:NO];
}

- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)
    runPredictionStock:(BOOL)stock
                accept:(BOOL)accept
               minimal:(BOOL)minimal {
    XCUIApplication *application =
        [self launchStock:stock minimal:minimal];
    XCTAssertTrue(IDHIDTypeSoftwareKeyboardText(
        self, application, @"i look forward "));
    NSDictionary *offered = [self waitForStatus:application
        predicate:^BOOL(NSDictionary<NSString *, id> *status) {
            return [status[@"markedRange"][@"length"]
                unsignedIntegerValue] > 0;
        }
        timeout:8.0];
    if (accept) {
        XCTAssertTrue(IDHIDTapSoftwareKeyboardKey(
            self, application, @"space"));
    } else {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.inputdec.inline-prediction.dismiss"),
            NULL, NULL, true);
    }
    NSDictionary *settled = [self waitForStatus:application
        predicate:^BOOL(NSDictionary<NSString *, id> *status) {
            return [status[@"markedRange"][@"location"]
                unsignedIntegerValue] == NSNotFound;
        }
        timeout:5.0];
    if (!accept) {
        XCTAssertTrue(IDHIDTypeSoftwareKeyboardText(
            self, application, @"x"));
        settled = [self waitForStatus:application
            predicate:^BOOL(NSDictionary<NSString *, id> *status) {
                return [status[@"canonical"] hasSuffix:@"x"];
            }
            timeout:4.0];
    }
    return @{@"offered": offered, @"settled": settled};
}

- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)
    runPredictionStock:(BOOL)stock accept:(BOOL)accept {
    return [self runPredictionStock:stock
                             accept:accept
                            minimal:NO];
}

- (void)testRealKeyboardBoldTypingMatchesStock {
    NSDictionary *stock = [self runBoldTypingStock:YES];
    NSDictionary *custom = [self runBoldTypingStock:NO];
    [self assertStockStatus:stock matchesCustomStatus:custom];
    XCTAssertEqualObjects(custom[@"typingInlineTraits"], (@[@"bold"]));
    XCTAssertEqualObjects(custom[@"inlineRuns"], (@[
        @{
            @"range": @{@"location": @0, @"length": @5},
            @"traits": @[@"bold"],
        },
    ]));
}

- (void)testRealKeyboardAutocorrectionPreservesBoldMatchesStock {
    NSDictionary *stock = [self runAutocorrectionStock:YES];
    NSDictionary *custom = [self runAutocorrectionStock:NO];
    [self assertStockStatus:stock matchesCustomStatus:custom];
    XCTAssertEqualObjects(custom[@"inlineRuns"], (@[
        @{
            @"range": @{@"location": @0, @"length": @8},
            @"traits": @[@"bold"],
        },
    ]));
}

- (void)testRealKeyboardPredictionAcceptAndRejectDoNotLeakTraits {
    NSDictionary *stockAccepted =
        [self runPredictionStock:YES accept:YES][@"settled"];
    NSDictionary *customAccepted =
        [self runPredictionStock:NO accept:YES][@"settled"];
    [self assertStockStatus:stockAccepted
        matchesCustomStatus:customAccepted];

    NSDictionary *stockRejected =
        [self runPredictionStock:YES accept:NO][@"settled"];
    NSDictionary *customRejected =
        [self runPredictionStock:NO accept:NO][@"settled"];
    [self assertStockStatus:stockRejected
        matchesCustomStatus:customRejected];
    XCTAssertFalse([customRejected[@"canonical"] containsString:@"to"]);
}

- (void)testRealKeyboardMarkedTextCommitPreservesActiveTraits {
    NSDictionary *stock =
        [self runPredictionStock:YES accept:YES];
    NSDictionary *custom =
        [self runPredictionStock:NO accept:YES];
    [self assertStockStatus:stock[@"offered"]
        matchesCustomStatus:custom[@"offered"]];
    [self assertStockStatus:stock[@"settled"]
        matchesCustomStatus:custom[@"settled"]];
    for (NSDictionary *status in
         @[custom[@"offered"], custom[@"settled"]]) {
        for (NSDictionary *run in status[@"inlineRuns"]) {
            XCTAssertEqualObjects(run[@"traits"], (@[@"bold"]));
        }
    }
}

- (void)testMinimalRealKeyboardBoldTypingMatchesStock {
    NSDictionary *stock =
        [self runBoldTypingStock:YES minimal:NO];
    NSDictionary *minimal =
        [self runBoldTypingStock:NO minimal:YES];
    [self assertStockStatus:stock matchesCustomStatus:minimal];
}

- (void)testMinimalRealKeyboardAutocorrectionPreservesBoldMatchesStock {
    NSDictionary *stock =
        [self runAutocorrectionStock:YES minimal:NO];
    NSDictionary *minimal =
        [self runAutocorrectionStock:NO minimal:YES];
    [self assertStockStatus:stock matchesCustomStatus:minimal];
}

- (void)testMinimalRealKeyboardPredictionAcceptAndRejectDoNotLeakTraits {
    NSDictionary *stockAccepted =
        [self runPredictionStock:YES
                          accept:YES
                         minimal:NO][@"settled"];
    NSDictionary *minimalAccepted =
        [self runPredictionStock:NO
                          accept:YES
                         minimal:YES][@"settled"];
    [self assertStockStatus:stockAccepted
        matchesCustomStatus:minimalAccepted];
    NSDictionary *stockRejected =
        [self runPredictionStock:YES
                          accept:NO
                         minimal:NO][@"settled"];
    NSDictionary *minimalRejected =
        [self runPredictionStock:NO
                          accept:NO
                         minimal:YES][@"settled"];
    [self assertStockStatus:stockRejected
        matchesCustomStatus:minimalRejected];
}

- (void)testMinimalRealKeyboardMarkedTextCommitPreservesActiveTraits {
    NSDictionary *stock =
        [self runPredictionStock:YES accept:YES minimal:NO];
    NSDictionary *minimal =
        [self runPredictionStock:NO accept:YES minimal:YES];
    [self assertStockStatus:stock[@"offered"]
        matchesCustomStatus:minimal[@"offered"]];
    [self assertStockStatus:stock[@"settled"]
        matchesCustomStatus:minimal[@"settled"]];
}

@end
