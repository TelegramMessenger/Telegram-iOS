@import XCTest;
@import UIKit;

typedef struct {
    NSRange range;
    CGRect caret;
    CGRect visible;
    CGPoint offset;
} IDCanvasUISelectionStatus;

static BOOL IDCanvasUIReadPair(NSString *source,
                               NSString *key,
                               CGFloat *first,
                               CGFloat *second) {
    NSString *prefix = [key stringByAppendingString:@"={"];
    NSRange keyRange = [source rangeOfString:prefix];
    if (keyRange.location == NSNotFound) return NO;
    NSString *tail = [source substringFromIndex:NSMaxRange(keyRange)];
    NSScanner *scanner = [NSScanner scannerWithString:tail];
    double firstValue = 0;
    double secondValue = 0;
    if (![scanner scanDouble:&firstValue] || ![scanner scanString:@"," intoString:nil] ||
        ![scanner scanDouble:&secondValue]) {
        return NO;
    }
    if (first != NULL) *first = (CGFloat)firstValue;
    if (second != NULL) *second = (CGFloat)secondValue;
    return YES;
}

static BOOL IDCanvasUIReadRect(NSString *source, NSString *key, CGRect *result) {
    NSString *prefix = [key stringByAppendingString:@"={{"];
    NSRange keyRange = [source rangeOfString:prefix];
    if (keyRange.location == NSNotFound) return NO;
    NSString *tail = [source substringFromIndex:NSMaxRange(keyRange)];
    NSScanner *scanner = [NSScanner scannerWithString:tail];
    double x = 0;
    double y = 0;
    double width = 0;
    double height = 0;
    if (![scanner scanDouble:&x] || ![scanner scanString:@"," intoString:nil] ||
        ![scanner scanDouble:&y] || ![scanner scanString:@"},{" intoString:nil] ||
        ![scanner scanDouble:&width] || ![scanner scanString:@"," intoString:nil] ||
        ![scanner scanDouble:&height]) {
        return NO;
    }
    if (result != NULL) {
        *result = CGRectMake((CGFloat)x, (CGFloat)y, (CGFloat)width, (CGFloat)height);
    }
    return YES;
}

static BOOL IDCanvasUIParseSelectionStatus(id value, IDCanvasUISelectionStatus *result) {
    NSString *source = [value isKindOfClass:NSString.class] ? value : [value description];
    if (source.length == 0) return NO;
    CGFloat location = 0;
    CGFloat length = 0;
    IDCanvasUISelectionStatus status = {0};
    if (!IDCanvasUIReadPair(source, @"range", &location, &length) ||
        !IDCanvasUIReadRect(source, @"caret", &status.caret) ||
        !IDCanvasUIReadRect(source, @"visible", &status.visible) ||
        !IDCanvasUIReadPair(source, @"offset", &status.offset.x, &status.offset.y)) {
        return NO;
    }
    status.range = NSMakeRange((NSUInteger)MAX(location, 0), (NSUInteger)MAX(length, 0));
    if (result != NULL) *result = status;
    return YES;
}

static NSUInteger IDCanvasUICountRedPixels(XCUIScreenshot *screenshot, CGRect screenRect) {
    CGImageRef source = screenshot.image.CGImage;
    if (source == NULL || CGRectIsEmpty(screenRect)) return 0;
    size_t width = CGImageGetWidth(source);
    size_t height = CGImageGetHeight(source);
    CGFloat scaleX = width / MAX(screenshot.image.size.width, 1);
    CGFloat scaleY = height / MAX(screenshot.image.size.height, 1);
    CGRect pixelRect = CGRectIntegral(CGRectMake(screenRect.origin.x * scaleX,
                                                 screenRect.origin.y * scaleY,
                                                 screenRect.size.width * scaleX,
                                                 screenRect.size.height * scaleY));
    pixelRect = CGRectIntersection(pixelRect, CGRectMake(0, 0, width, height));
    if (CGRectIsNull(pixelRect) || CGRectIsEmpty(pixelRect)) return 0;

    size_t bytesPerRow = width * 4;
    uint8_t *pixels = calloc(height, bytesPerRow);
    if (pixels == NULL) return 0;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast |
                                                     (CGBitmapInfo)kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        free(pixels);
        return 0;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), source);
    CGContextRelease(context);

    NSUInteger count = 0;
    for (NSUInteger y = (NSUInteger)CGRectGetMinY(pixelRect);
         y < (NSUInteger)CGRectGetMaxY(pixelRect);
         y++) {
        for (NSUInteger x = (NSUInteger)CGRectGetMinX(pixelRect);
             x < (NSUInteger)CGRectGetMaxX(pixelRect);
             x++) {
            uint8_t *pixel = pixels + y * bytesPerRow + x * 4;
            NSUInteger red = pixel[0];
            NSUInteger green = pixel[1];
            NSUInteger blue = pixel[2];
            if (pixel[3] > 0 && red >= 140 && red * 4 > green * 5 && red * 4 > blue * 5) {
                count += 1;
            }
        }
    }
    free(pixels);
    return count;
}

@interface IDTextLayoutCanvasUITests : XCTestCase
@end

@implementation IDTextLayoutCanvasUITests

- (XCUIApplication *)launchScenario:(NSString *)scenario {
    XCUIApplication *application = [XCUIApplication new];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)",
        @"-AppleLocale", @"en_US",
        @"--id-ui-scenario", scenario,
    ];
    [application launch];
    return application;
}

- (XCUIElement *)element:(NSString *)identifier application:(XCUIApplication *)application {
    return [application descendantsMatchingType:XCUIElementTypeAny][identifier];
}

- (BOOL)waitForElement:(XCUIElement *)element
                 value:(BOOL (^)(id value))predicate
               timeout:(NSTimeInterval)timeout {
    NSPredicate *valuePredicate = [NSPredicate predicateWithBlock:^BOOL(XCUIElement *candidate,
                                                                        NSDictionary *bindings) {
        return candidate.exists && predicate(candidate.value);
    }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:valuePredicate object:element];
    return [XCTWaiter waitForExpectations:@[expectation] timeout:timeout] ==
        XCTWaiterResultCompleted;
}

- (BOOL)waitForElementToDisappear:(XCUIElement *)element timeout:(NSTimeInterval)timeout {
    NSPredicate *gone = [NSPredicate predicateWithFormat:@"exists == NO"];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:gone object:element];
    return [XCTWaiter waitForExpectations:@[expectation] timeout:timeout] ==
        XCTWaiterResultCompleted;
}

- (NSUInteger)waitForRedPixelCountInElement:(XCUIElement *)element
                                    matching:(BOOL (^)(NSUInteger count))predicate
                                     timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSUInteger lastCount = 0;
    while ([deadline timeIntervalSinceNow] > 0) {
        lastCount = IDCanvasUICountRedPixels(XCUIScreen.mainScreen.screenshot, element.frame);
        if (predicate(lastCount)) return lastCount;
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return lastCount;
}

- (void)testTypingPastViewportKeepsCollapsedCaretVisibleAtPositiveOffset {
    XCUIApplication *application = [self launchScenario:@"caret"];
    XCUIElement *editor = [self element:@"custom-text-view" application:application];
    XCUIElement *statusElement = [self element:@"selection-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);

    [editor tap];
    NSMutableString *typed = [NSMutableString string];
    for (NSUInteger line = 0; line < 18; line++) {
        [typed appendFormat:@"typed line %02lu\n", (unsigned long)line];
    }
    [typed appendString:@"visible caret"];
    [editor typeText:typed];

    __block IDCanvasUISelectionStatus status = {0};
    __block NSString *lastStatusValue = nil;
    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        lastStatusValue = [value description];
        IDCanvasUISelectionStatus candidate = {0};
        if (!IDCanvasUIParseSelectionStatus(value, &candidate)) return NO;
        status = candidate;
        return candidate.offset.y > 0 && candidate.range.length == 0 &&
            CGRectContainsRect(CGRectInset(candidate.visible, -1, -1), candidate.caret);
    }
                              timeout:8.0], @"%@", lastStatusValue);
    XCTAssertGreaterThan(status.offset.y, 0);
    XCTAssertEqual(status.range.length, 0U);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(status.visible, -1, -1), status.caret));
}

- (void)testSelectionDragChangesRangeAndSelectionPersistsAfterScrolling {
    XCUIApplication *application = [self launchScenario:@"selection"];
    XCUIElement *editor = [self element:@"custom-text-view" application:application];
    XCUIElement *statusElement = [self element:@"selection-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);
    id initialValue = statusElement.value;

    XCUICoordinate *start = [editor coordinateWithNormalizedOffset:CGVectorMake(0.28, 0.24)];
    XCUICoordinate *end = [editor coordinateWithNormalizedOffset:CGVectorMake(0.78, 0.42)];
    [start pressForDuration:0.8 thenDragToCoordinate:end];

    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        return ![value isEqual:initialValue];
    }
                              timeout:5.0]);
    XCUICoordinate *word = [editor coordinateWithNormalizedOffset:CGVectorMake(0.36, 0.24)];
    [word doubleTap];
    __block IDCanvasUISelectionStatus selected = {0};
    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        IDCanvasUISelectionStatus candidate = {0};
        if (!IDCanvasUIParseSelectionStatus(value, &candidate)) return NO;
        selected = candidate;
        return candidate.range.length > 0;
    }
                              timeout:5.0]);
    NSRange rangeBeforeHandleDrag = selected.range;
    CGFloat handleX = (CGRectGetMaxX(selected.caret) - selected.offset.x) /
        MAX(CGRectGetWidth(editor.frame), 1);
    CGFloat handleY = (CGRectGetMaxY(selected.caret) - selected.offset.y) /
        MAX(CGRectGetHeight(editor.frame), 1);
    XCUICoordinate *selectionHandle = [editor coordinateWithNormalizedOffset:
        CGVectorMake(MIN(MAX(handleX, 0.05), 0.95), MIN(MAX(handleY, 0.05), 0.92))];
    XCUICoordinate *expandedHandle = [editor coordinateWithNormalizedOffset:
        CGVectorMake(MIN(MAX(handleX + 0.20, 0.08), 0.95),
                     MIN(MAX(handleY + 0.12, 0.08), 0.92))];
    [selectionHandle pressForDuration:0.2 thenDragToCoordinate:expandedHandle];
    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        IDCanvasUISelectionStatus candidate = {0};
        if (!IDCanvasUIParseSelectionStatus(value, &candidate)) return NO;
        selected = candidate;
        return candidate.range.length > 0 && !NSEqualRanges(candidate.range,
                                                             rangeBeforeHandleDrag);
    }
                              timeout:5.0]);
    NSRange rangeBeforeScroll = selected.range;
    XCUICoordinate *scrollStart =
        [editor coordinateWithNormalizedOffset:CGVectorMake(0.90, 0.80)];
    XCUICoordinate *scrollEnd =
        [editor coordinateWithNormalizedOffset:CGVectorMake(0.90, 0.30)];
    [scrollStart pressForDuration:0.05 thenDragToCoordinate:scrollEnd];
    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        IDCanvasUISelectionStatus candidate = {0};
        return IDCanvasUIParseSelectionStatus(value, &candidate) &&
            candidate.offset.y > selected.offset.y &&
            NSEqualRanges(candidate.range, rangeBeforeScroll);
    }
                              timeout:5.0]);
}

- (void)testLongPressDragKeepsAppResponsiveAndMovesInsertionGeometry {
    XCUIApplication *application = [self launchScenario:@"selection"];
    XCUIElement *editor = [self element:@"custom-text-view" application:application];
    XCUIElement *statusElement = [self element:@"selection-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);

    __block IDCanvasUISelectionStatus before = {0};
    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        return IDCanvasUIParseSelectionStatus(value, &before);
    }
                              timeout:3.0]);
    XCUICoordinate *start = [editor coordinateWithNormalizedOffset:CGVectorMake(0.24, 0.22)];
    XCUICoordinate *end = [editor coordinateWithNormalizedOffset:CGVectorMake(0.72, 0.50)];
    [start pressForDuration:0.8 thenDragToCoordinate:end];

    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        IDCanvasUISelectionStatus after = {0};
        if (!IDCanvasUIParseSelectionStatus(value, &after)) return NO;
        return !CGRectEqualToRect(before.caret, after.caret) ||
            !NSEqualRanges(before.range, after.range);
    }
                              timeout:5.0]);
    XCTAssertEqual(application.state, XCUIApplicationStateRunningForeground);
}

- (void)testNativeSpellingMarkerAppearsForMisspellingAndClearsAfterCorrection {
    XCUIApplication *application = [self launchScenario:@"spelling"];
    XCUIElement *editor = [self element:@"custom-text-view" application:application];
    XCUIElement *statusElement = [self element:@"spelling-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);

    [editor tap];
    [editor typeText:@"hello "];
    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        return [[value description] containsString:@"text=hello "];
    }
                              timeout:3.0]);
    NSUInteger baselinePixels = [self waitForRedPixelCountInElement:editor
                                                            matching:^BOOL(NSUInteger count) {
        return count < 3;
    }
                                                             timeout:3.0];
    XCTAssertLessThan(baselinePixels, 3U);
    for (NSUInteger index = 0; index < @"mispelled".length; index++) {
        [editor typeText:[@"mispelled" substringWithRange:NSMakeRange(index, 1)]];
    }
    XCUIElement *spaceKey = application.keyboards.keys[@"space"];
    XCTAssertTrue([spaceKey waitForExistenceWithTimeout:3.0]);
    [spaceKey tap];
    __block NSString *lastSpellingStatus = nil;
    BOOL annotated = [self waitForElement:statusElement
                                value:^BOOL(id value) {
        NSString *status = [value description];
        lastSpellingStatus = status;
        return [status containsString:@"text=hello mispelled "] &&
            [status containsString:@"annotation=2"];
    }
                              timeout:8.0];
    XCTAssertTrue(annotated, @"%@", lastSpellingStatus);
    if (!annotated) return;
    NSUInteger misspelledPixels = [self waitForRedPixelCountInElement:editor
                                                              matching:^BOOL(NSUInteger count) {
        return count >= 3;
    }
                                                               timeout:8.0];
    XCTAssertGreaterThanOrEqual(misspelledPixels, 3U);

    for (NSUInteger character = 0; character < @"mispelled ".length; character++) {
        [editor typeText:XCUIKeyboardKeyDelete];
    }
    [editor typeText:@"misspelled "];
    XCTAssertTrue([self waitForElement:statusElement
                                value:^BOOL(id value) {
        NSString *status = [value description];
        return [status containsString:@"text=hello misspelled "] &&
            [status containsString:@"annotation=none"];
    }
                              timeout:8.0]);
    NSUInteger correctedPixels = [self waitForRedPixelCountInElement:editor
                                                             matching:^BOOL(NSUInteger count) {
        return count < misspelledPixels / 2;
    }
                                                              timeout:8.0];
    XCTAssertLessThan(correctedPixels, misspelledPixels / 2);
}

- (void)testAttachmentProviderReturnsAtStableDocumentFrameAfterViewportRoundTrip {
    XCUIApplication *application = [self launchScenario:@"attachment"];
    XCUIElement *editor = [self element:@"custom-text-view" application:application];
    XCUIElement *provider = [self element:@"attachment-provider" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([provider waitForExistenceWithTimeout:5.0]);
    NSString *initialDocumentFrame = [provider.value description];
    XCTAssertTrue([initialDocumentFrame hasPrefix:@"document-frame={{"]);

    for (NSUInteger attempt = 0; attempt < 4 && provider.exists; attempt++) {
        [editor swipeUp];
    }
    XCTAssertTrue([self waitForElementToDisappear:provider timeout:5.0]);
    for (NSUInteger attempt = 0; attempt < 4 && !provider.exists; attempt++) {
        [editor swipeDown];
    }
    XCTAssertTrue([provider waitForExistenceWithTimeout:5.0]);
    XCTAssertEqualObjects([provider.value description], initialDocumentFrame);
}

@end
