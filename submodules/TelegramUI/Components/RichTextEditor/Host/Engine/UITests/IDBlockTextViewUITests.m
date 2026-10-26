@import XCTest;
@import UIKit;

#include <math.h>

static NSDictionary<NSString *, id> *IDBlockUIStatusDictionary(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
    id object = data == nil ? nil : [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:nil];
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

static BOOL IDBlockUIFiniteNumber(id value) {
    return [value isKindOfClass:NSNumber.class] && isfinite([value doubleValue]);
}

static BOOL IDBlockUIStatusHasExactSchema(NSDictionary<NSString *, id> *status) {
    NSSet *expectedKeys = [NSSet setWithArray:@[
        @"blockCount", @"blockOrigins", @"canonical", @"caret", @"scenario",
        @"inlineFormatting", @"selection", @"spelling",
        @"spellingGeometryRequests", @"state", @"visible",
    ]];
    if (status == nil) return NO;
    if (![expectedKeys isEqualToSet:[NSSet setWithArray:status.allKeys]]) return NO;
    NSDictionary *selection = status[@"selection"];
    NSDictionary *caret = status[@"caret"];
    NSDictionary *formatting = status[@"inlineFormatting"];
    NSArray *origins = status[@"blockOrigins"];
    if (![selection isKindOfClass:NSDictionary.class] ||
        ![caret isKindOfClass:NSDictionary.class] ||
        ![formatting isKindOfClass:NSDictionary.class] ||
        ![origins isKindOfClass:NSArray.class]) return NO;
    if (![[NSSet setWithArray:selection.allKeys]
            isEqualToSet:[NSSet setWithArray:@[@"length", @"location"]]]) return NO;
    if (![[NSSet setWithArray:caret.allKeys]
            isEqualToSet:[NSSet setWithArray:@[@"height", @"width", @"x", @"y"]]]) return NO;
    if (![[NSSet setWithArray:formatting.allKeys]
            isEqualToSet:[NSSet setWithArray:@[
                @"blocks", @"effectiveTypingTraits", @"states",
            ]]]) return NO;
    if (![formatting[@"blocks"] isKindOfClass:NSArray.class] ||
        ![formatting[@"effectiveTypingTraits"] isKindOfClass:NSArray.class] ||
        ![formatting[@"states"] isKindOfClass:NSDictionary.class]) return NO;
    if (![status[@"blockCount"] isKindOfClass:NSNumber.class] ||
        origins.count != [status[@"blockCount"] unsignedIntegerValue] ||
        !IDBlockUIFiniteNumber(selection[@"location"]) ||
        !IDBlockUIFiniteNumber(selection[@"length"]) ||
        !IDBlockUIFiniteNumber(caret[@"x"]) || !IDBlockUIFiniteNumber(caret[@"y"]) ||
        !IDBlockUIFiniteNumber(caret[@"width"]) || !IDBlockUIFiniteNumber(caret[@"height"]) ||
        [caret[@"width"] doubleValue] <= 0 || [caret[@"height"] doubleValue] <= 0) return NO;
    double priorY = -DBL_MAX;
    for (NSDictionary *origin in origins) {
        if (![origin isKindOfClass:NSDictionary.class] ||
            ![[NSSet setWithArray:origin.allKeys]
                isEqualToSet:[NSSet setWithArray:@[@"x", @"y"]]] ||
            !IDBlockUIFiniteNumber(origin[@"x"]) || !IDBlockUIFiniteNumber(origin[@"y"]) ||
            [origin[@"y"] doubleValue] < priorY) return NO;
        priorY = [origin[@"y"] doubleValue];
    }
    return [status[@"canonical"] isKindOfClass:NSString.class] &&
        [status[@"scenario"] isKindOfClass:NSString.class] &&
        [status[@"state"] isKindOfClass:NSString.class] &&
        [status[@"spelling"] isKindOfClass:NSString.class] &&
        [status[@"spellingGeometryRequests"] isKindOfClass:NSNumber.class] &&
        [status[@"visible"] isKindOfClass:NSNumber.class];
}

static BOOL IDGeometryStatusHasExactSchema(NSDictionary<NSString *, id> *status) {
    if (status == nil) return NO;
    NSString *scenario = status[@"scenario"];
    BOOL large = [scenario isEqualToString:@"geometry-large-selection"] ||
        [scenario isEqualToString:@"stock-geometry-large-selection"];
    NSMutableSet *expectedKeys = [NSMutableSet setWithArray:@[
        @"blockCount", @"boundary", @"canonical", @"caret", @"contentOffset",
        @"firstResponder", @"scenario", @"selection", @"selectionRects",
        @"state", @"visible",
    ]];
    if (large) {
        [expectedKeys addObjectsFromArray:@[
            @"canonicalLength", @"selectionTextLength",
        ]];
    }
    if (![expectedKeys isEqualToSet:[NSSet setWithArray:status.allKeys]]) return NO;
    NSDictionary *selection = status[@"selection"];
    NSDictionary *boundary = status[@"boundary"];
    NSDictionary *caret = status[@"caret"];
    NSDictionary *offset = status[@"contentOffset"];
    NSDictionary *visible = status[@"visible"];
    NSArray *selectionRects = status[@"selectionRects"];
    if (![selection isKindOfClass:NSDictionary.class] ||
        ![boundary isKindOfClass:NSDictionary.class] ||
        ![caret isKindOfClass:NSDictionary.class] ||
        ![offset isKindOfClass:NSDictionary.class] ||
        ![visible isKindOfClass:NSDictionary.class] ||
        ![selectionRects isKindOfClass:NSArray.class]) return NO;
    NSSet *boundaryKeys = [NSSet setWithArray:@[
        @"affinity", @"baseWritingDirection", @"bundleIdentifier",
        @"firstResponder", @"launchArguments", @"localeIdentifier",
        @"primaryLanguage", @"role", @"scenario", @"selection",
    ]];
    if (![boundaryKeys isEqualToSet:[NSSet setWithArray:boundary.allKeys]] ||
        ![boundary[@"selection"] isEqual:selection] ||
        ![boundary[@"affinity"] isKindOfClass:NSNumber.class] ||
        ![boundary[@"baseWritingDirection"] isKindOfClass:NSNumber.class] ||
        ![boundary[@"bundleIdentifier"] isKindOfClass:NSString.class] ||
        ![boundary[@"firstResponder"] isKindOfClass:NSNumber.class] ||
        ![boundary[@"launchArguments"] isKindOfClass:NSArray.class] ||
        ![boundary[@"localeIdentifier"] isKindOfClass:NSString.class] ||
        ![boundary[@"primaryLanguage"] isKindOfClass:NSString.class] ||
        ![boundary[@"role"] isKindOfClass:NSString.class] ||
        ![boundary[@"scenario"] isKindOfClass:NSString.class]) return NO;
    if (![[NSSet setWithArray:selection.allKeys]
            isEqualToSet:[NSSet setWithArray:@[@"length", @"location"]]] ||
        ![[NSSet setWithArray:caret.allKeys]
            isEqualToSet:[NSSet setWithArray:@[@"height", @"width", @"x", @"y"]]] ||
        ![[NSSet setWithArray:offset.allKeys]
            isEqualToSet:[NSSet setWithArray:@[@"x", @"y"]]] ||
        ![[NSSet setWithArray:visible.allKeys]
            isEqualToSet:[NSSet setWithArray:@[@"height", @"width", @"x", @"y"]]]) {
        return NO;
    }
    for (id value in @[
        selection[@"location"], selection[@"length"],
        caret[@"x"], caret[@"y"], caret[@"width"], caret[@"height"],
        offset[@"x"], offset[@"y"],
        visible[@"x"], visible[@"y"], visible[@"width"], visible[@"height"],
    ]) {
        if (!IDBlockUIFiniteNumber(value)) return NO;
    }
    NSSet *selectionRectKeys = [NSSet setWithArray:@[
        @"containsEnd", @"containsStart", @"height", @"vertical", @"width",
        @"writingDirection", @"x", @"y",
    ]];
    for (NSDictionary *rect in selectionRects) {
        if (![rect isKindOfClass:NSDictionary.class] ||
            ![selectionRectKeys isEqualToSet:[NSSet setWithArray:rect.allKeys]]) {
            return NO;
        }
        for (NSString *key in @[@"height", @"width", @"writingDirection", @"x", @"y"]) {
            if (!IDBlockUIFiniteNumber(rect[key])) return NO;
        }
        if (![rect[@"containsStart"] isKindOfClass:NSNumber.class] ||
            ![rect[@"containsEnd"] isKindOfClass:NSNumber.class] ||
            ![rect[@"vertical"] isKindOfClass:NSNumber.class]) return NO;
    }
    return [status[@"blockCount"] isKindOfClass:NSNumber.class] &&
        [status[@"canonical"] isKindOfClass:NSString.class] &&
        [status[@"firstResponder"] isKindOfClass:NSNumber.class] &&
        [scenario isKindOfClass:NSString.class] &&
        [status[@"state"] isKindOfClass:NSString.class] &&
        (!large ||
         ([status[@"canonicalLength"] isKindOfClass:NSNumber.class] &&
          [status[@"selectionTextLength"] isKindOfClass:NSNumber.class]));
}

static NSUInteger IDBlockUICountRedPixels(XCUIScreenshot *screenshot, CGRect screenRect) {
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
         y < (NSUInteger)CGRectGetMaxY(pixelRect); y += 1) {
        for (NSUInteger x = (NSUInteger)CGRectGetMinX(pixelRect);
             x < (NSUInteger)CGRectGetMaxX(pixelRect); x += 1) {
            uint8_t *pixel = pixels + y * bytesPerRow + x * 4;
            if (pixel[3] > 0 && pixel[0] >= 140 &&
                pixel[0] * 4 > pixel[1] * 5 && pixel[0] * 4 > pixel[2] * 5) {
                count += 1;
            }
        }
    }
    free(pixels);
    return count;
}

@interface IDBlockTextViewUITests : XCTestCase
@end

@implementation IDBlockTextViewUITests

- (void)terminateAllHosts {
    [[[XCUIApplication alloc] initWithBundleIdentifier:@"com.inputdec.demo"]
        terminate];
    [[[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"] terminate];
}

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    [self terminateAllHosts];
}

- (void)tearDown {
    [self terminateAllHosts];
    [super tearDown];
}

- (XCUIApplication *)launchScenario:(NSString *)scenario {
    [self terminateAllHosts];
    XCUIApplication *application = [XCUIApplication new];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)",
        @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", scenario,
    ];
    [application launch];
    return application;
}

- (XCUIApplication *)launchGeometryScenario:(NSString *)scenario
                                   selection:(NSRange)selection {
    [self terminateAllHosts];
    XCUIApplication *application = [XCUIApplication new];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)",
        @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", scenario,
    ];
    application.launchEnvironment = @{
        @"IDGeometrySelectionLength": @(selection.length).stringValue,
        @"IDGeometrySelectionLocation": @(selection.location).stringValue,
    };
    [application launch];
    return application;
}

- (XCUIApplication *)launchStockNavigationScenario:(NSString *)scenario {
    [self terminateAllHosts];
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)",
        @"-AppleLocale", @"en_US",
    ];
    application.launchEnvironment = @{
        @"IDStockTouchScenario": scenario,
    };
    [application launch];
    return application;
}

- (XCUIApplication *)launchStockGeometryScenario:(NSString *)scenario
                                         selection:(NSRange)selection {
    [self terminateAllHosts];
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)",
        @"-AppleLocale", @"en_US",
    ];
    application.launchEnvironment = @{
        @"IDGeometrySelectionLength": @(selection.length).stringValue,
        @"IDGeometrySelectionLocation": @(selection.location).stringValue,
        @"IDStockTouchScenario": scenario,
    };
    [application launch];
    return application;
}

- (XCUIElement *)element:(NSString *)identifier application:(XCUIApplication *)application {
    return [application descendantsMatchingType:XCUIElementTypeAny][identifier];
}

- (BOOL)waitForStatus:(XCUIElement *)element
              timeout:(NSTimeInterval)timeout
                block:(BOOL (^)(NSDictionary<NSString *, id> *status))block {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(XCUIElement *candidate,
                                                                    NSDictionary *bindings) {
        return candidate.exists && block(IDBlockUIStatusDictionary(candidate.value));
    }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:element];
    return [XCTWaiter waitForExpectations:@[expectation] timeout:timeout] ==
        XCTWaiterResultCompleted;
}

- (NSDictionary<NSString *, id> *)waitForNavigationStatus:
    (XCUIElement *)element
                                                     stock:(BOOL)stock
                                                  scenario:(NSString *)scenario
                                                 canonical:(NSString *)canonical
                                         previousSelection:(NSValue *)previousSelection
                                                   timeout:(NSTimeInterval)timeout {
    NSDictionary<NSString *, id> *last = nil;
    BOOL completed = NO;
    NSString *expectedScenario = stock
        ? [@"stock-" stringByAppendingString:scenario]
        : scenario;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        last = IDBlockUIStatusDictionary(element.value);
        NSDictionary *selection = last[@"selection"];
        NSDictionary *caret = last[@"caret"];
        BOOL identityMatches = [last[@"canonical"] isEqualToString:canonical] &&
            [last[@"scenario"] isEqualToString:expectedScenario] &&
            [selection isKindOfClass:NSDictionary.class] &&
            [caret isKindOfClass:NSDictionary.class];
        NSRange currentSelection = NSMakeRange(
            [selection[@"location"] unsignedIntegerValue],
            [selection[@"length"] unsignedIntegerValue]);
        completed = identityMatches &&
            (previousSelection == nil ||
             !NSEqualRanges(currentSelection, previousSelection.rangeValue));
        if (!completed) {
            [NSRunLoop.mainRunLoop runUntilDate:
                [NSDate dateWithTimeIntervalSinceNow:0.25]];
        }
    } while (!completed && [deadline timeIntervalSinceNow] > 0.0);
    XCTAssertTrue(completed, @"stock=%d scenario=%@ last=%@",
                  stock, scenario, last);
    NSDictionary *selection = last[@"selection"];
    NSDictionary *caret = last[@"caret"];
    XCTAssertTrue(IDBlockUIFiniteNumber(selection[@"location"]), @"%@", last);
    XCTAssertTrue(IDBlockUIFiniteNumber(selection[@"length"]), @"%@", last);
    XCTAssertLessThanOrEqual([selection[@"location"] unsignedIntegerValue],
                             canonical.length, @"%@", last);
    NSUInteger location = [selection[@"location"] unsignedIntegerValue];
    NSUInteger length = [selection[@"length"] unsignedIntegerValue];
    XCTAssertLessThanOrEqual(location + length, canonical.length, @"%@", last);
    XCTAssertTrue(IDBlockUIFiniteNumber(caret[@"x"]), @"%@", last);
    XCTAssertTrue(IDBlockUIFiniteNumber(caret[@"y"]), @"%@", last);
    XCTAssertTrue(IDBlockUIFiniteNumber(caret[@"width"]), @"%@", last);
    XCTAssertTrue(IDBlockUIFiniteNumber(caret[@"height"]), @"%@", last);
    if ([selection[@"length"] unsignedIntegerValue] == 0) {
        XCTAssertGreaterThan([caret[@"width"] doubleValue], 0.0, @"%@", last);
        XCTAssertGreaterThan([caret[@"height"] doubleValue], 0.0, @"%@", last);
    }
    return completed ? last : nil;
}

- (NSRange)navigationSelectionFromStatus:(NSDictionary<NSString *, id> *)status {
    NSDictionary *selection = status[@"selection"];
    return NSMakeRange([selection[@"location"] unsignedIntegerValue],
                       [selection[@"length"] unsignedIntegerValue]);
}

- (NSArray<NSValue *> *)navigationTraceForEditor:(XCUIElement *)editor
                                          status:(XCUIElement *)status
                                           stock:(BOOL)stock
                                        scenario:(NSString *)scenario
                                       canonical:(NSString *)canonical
                                            keys:(NSArray<NSDictionary<NSString *, id> *> *)keys {
    NSMutableArray<NSValue *> *trace = [NSMutableArray array];
    __block NSDictionary<NSString *, id> *readyStatus = nil;
    XCTAssertTrue([self waitForStatus:status timeout:4.0
        block:^BOOL(NSDictionary<NSString *, id> *value) {
            readyStatus = value;
            NSString *expectedScenario = stock
                ? [@"stock-" stringByAppendingString:scenario]
                : scenario;
            return [value[@"canonical"] isEqualToString:canonical] &&
                [value[@"scenario"] isEqualToString:expectedScenario];
        }], @"stock=%d scenario=%@ last=%@", stock, scenario, readyStatus);
    NSDictionary *initial = [self waitForNavigationStatus:status
                                                    stock:stock
                                                 scenario:scenario
                                                canonical:canonical
                                        previousSelection:nil
                                                  timeout:4.0];
    if (initial == nil) return @[];
    [trace addObject:[NSValue valueWithRange:
        [self navigationSelectionFromStatus:initial]]];

    NSPredicate *focusPredicate =
        [NSPredicate predicateWithFormat:@"hasKeyboardFocus == true"];
    XCTNSPredicateExpectation *focusExpectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:focusPredicate
                                                      object:editor];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[focusExpectation]
                                          timeout:4.0],
                   XCTWaiterResultCompleted,
                   @"editor never acquired keyboard focus: stock=%d scenario=%@",
                   stock, scenario);

    for (NSDictionary<NSString *, id> *step in keys) {
        [editor typeKey:step[@"key"]
          modifierFlags:[step[@"modifiers"] unsignedIntegerValue]];
        NSDictionary<NSString *, id> *current = [self
            waitForNavigationStatus:status
                              stock:stock
                           scenario:scenario
                          canonical:canonical
                  previousSelection:trace.lastObject
                            timeout:2.0];
        if (current == nil) return trace.copy;
        [trace addObject:[NSValue valueWithRange:
            [self navigationSelectionFromStatus:current]]];
    }
    return trace.copy;
}

- (NSArray<NSDictionary<NSString *, id> *> *)navigationKeys:
    (NSString *)key
                                                          count:(NSUInteger)count
                                                      modifiers:(XCUIKeyModifierFlags)modifiers {
    NSMutableArray<NSDictionary<NSString *, id> *> *keys = [NSMutableArray array];
    for (NSUInteger index = 0; index < count; index += 1) {
        [keys addObject:@{@"key": key, @"modifiers": @(modifiers)}];
    }
    return keys.copy;
}

- (NSDictionary<NSString *, id> *)waitForGeometryStatus:(XCUIElement *)element
                                                   stock:(BOOL)stock
                                                scenario:(NSString *)scenario
                                               canonical:(NSString *)canonical
                                       previousSelection:(nullable NSValue *)previousSelection
                                                 timeout:(NSTimeInterval)timeout {
    __block NSDictionary<NSString *, id> *last = nil;
    NSString *expectedScenario = stock
        ? [@"stock-" stringByAppendingString:scenario]
        : scenario;
    BOOL completed = [self waitForStatus:element timeout:timeout
        block:^BOOL(NSDictionary<NSString *, id> *status) {
            last = status;
            if (!IDGeometryStatusHasExactSchema(status) ||
                ![status[@"canonical"] isEqualToString:canonical] ||
                ![status[@"scenario"] isEqualToString:expectedScenario] ||
                ![status[@"firstResponder"] boolValue]) {
                return NO;
            }
            if (previousSelection == nil) return YES;
            NSRange selection = [self navigationSelectionFromStatus:status];
            return !NSEqualRanges(selection, previousSelection.rangeValue);
        }];
    XCTAssertTrue(completed, @"stock=%d scenario=%@ last=%@", stock, scenario, last);
    return completed ? last : nil;
}

- (NSArray<NSDictionary<NSString *, id> *> *)geometryTapTraceForEditor:
    (XCUIElement *)editor
                                                                  status:
    (XCUIElement *)status
                                                                   stock:(BOOL)stock
                                                                scenario:(NSString *)scenario
                                                               canonical:(NSString *)canonical
                                                                  points:(NSArray<NSValue *> *)points {
    NSMutableArray<NSDictionary<NSString *, id> *> *trace = [NSMutableArray array];
    NSDictionary *current = [self waitForGeometryStatus:status
                                                  stock:stock
                                               scenario:scenario
                                              canonical:canonical
                                      previousSelection:nil
                                                timeout:4.0];
    for (NSValue *value in points) {
        NSRange previous = [self navigationSelectionFromStatus:current];
        CGPoint point = value.CGPointValue;
        [[editor coordinateWithNormalizedOffset:
            CGVectorMake(point.x, point.y)] tap];
        current = [self waitForGeometryStatus:status
                                        stock:stock
                                     scenario:scenario
                                    canonical:canonical
                            previousSelection:[NSValue valueWithRange:previous]
                                      timeout:3.0];
        if (current == nil) return trace.copy;
        [trace addObject:current];
    }
    return trace.copy;
}

- (NSArray<NSDictionary<NSString *, id> *> *)geometrySelectionTraceForEditor:
    (XCUIElement *)editor
                                                                       status:
    (XCUIElement *)status
                                                                        stock:(BOOL)stock
                                                                     scenario:(NSString *)scenario
                                                                    canonical:(NSString *)canonical
                                                                         keys:(NSArray<NSDictionary<NSString *, id> *> *)keys {
    NSMutableArray<NSDictionary<NSString *, id> *> *trace = [NSMutableArray array];
    NSDictionary *current = [self waitForGeometryStatus:status
                                                  stock:stock
                                               scenario:scenario
                                              canonical:canonical
                                      previousSelection:nil
                                                timeout:4.0];
    if (current == nil) return @[];
    NSPredicate *focusPredicate =
        [NSPredicate predicateWithFormat:@"hasKeyboardFocus == true"];
    XCTNSPredicateExpectation *focusExpectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:focusPredicate
                                                      object:editor];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[focusExpectation] timeout:4.0],
                   XCTWaiterResultCompleted);
    for (NSDictionary<NSString *, id> *step in keys) {
        NSRange previous = [self navigationSelectionFromStatus:current];
        [editor typeKey:step[@"key"]
          modifierFlags:[step[@"modifiers"] unsignedIntegerValue]];
        current = [self waitForGeometryStatus:status
                                        stock:stock
                                     scenario:scenario
                                    canonical:canonical
                            previousSelection:[NSValue valueWithRange:previous]
                                      timeout:3.0];
        if (current == nil) return trace.copy;
        [trace addObject:current];
    }
    return trace.copy;
}

- (void)assertSelectionStatus:(NSDictionary<NSString *, id> *)custom
                  matchesStock:(NSDictionary<NSString *, id> *)stock {
    XCTAssertTrue(NSEqualRanges([self navigationSelectionFromStatus:custom],
                                [self navigationSelectionFromStatus:stock]),
                  @"stock=%@ custom=%@", stock, custom);
    NSArray<NSDictionary<NSString *, id> *> *customRects = custom[@"selectionRects"];
    NSArray<NSDictionary<NSString *, id> *> *stockRects = stock[@"selectionRects"];
    XCTAssertEqual(customRects.count, stockRects.count,
                   @"stock=%@ custom=%@", stockRects, customRects);
    NSUInteger count = MIN(customRects.count, stockRects.count);
    for (NSUInteger index = 0; index < count; index += 1) {
        NSDictionary *customRect = customRects[index];
        NSDictionary *stockRect = stockRects[index];
        for (NSString *key in @[
            @"containsStart", @"containsEnd", @"vertical", @"writingDirection",
        ]) {
            XCTAssertEqualObjects(customRect[key], stockRect[key],
                                  @"index=%lu key=%@ stock=%@ custom=%@",
                                  (unsigned long)index, key, stockRect, customRect);
        }
        for (NSString *key in @[@"x", @"y", @"width", @"height"]) {
            XCTAssertEqualWithAccuracy([customRect[key] doubleValue],
                                       [stockRect[key] doubleValue], 1.0,
                                       @"index=%lu key=%@ stock=%@ custom=%@",
                                       (unsigned long)index, key, stockRect, customRect);
        }
    }
}

- (void)assertCustomBoundary:(NSDictionary<NSString *, id> *)customStatus
                 matchesStock:(NSDictionary<NSString *, id> *)stockStatus {
    NSDictionary<NSString *, id> *custom = customStatus[@"boundary"];
    NSDictionary<NSString *, id> *stock = stockStatus[@"boundary"];
    XCTAssertEqualObjects(custom[@"role"], @"custom");
    XCTAssertEqualObjects(stock[@"role"], @"stock");
    XCTAssertEqualObjects(custom[@"bundleIdentifier"], @"com.inputdec.demo");
    XCTAssertEqualObjects(stock[@"bundleIdentifier"],
                          @"com.inputdec.stockoracle");
    XCTAssertTrue([custom[@"launchArguments"] isKindOfClass:NSArray.class]);
    XCTAssertTrue([stock[@"launchArguments"] isKindOfClass:NSArray.class]);
    for (NSString *key in @[
        @"localeIdentifier", @"primaryLanguage", @"firstResponder",
        @"selection", @"affinity", @"baseWritingDirection", @"scenario",
    ]) {
        XCTAssertEqualObjects(custom[key], stock[key], @"key=%@ stock=%@ custom=%@",
                              key, stock, custom);
    }
}

- (NSUInteger)waitForRedPixelsInElement:(XCUIElement *)element
                                 timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSUInteger count = 0;
    while ([deadline timeIntervalSinceNow] > 0) {
        count = IDBlockUICountRedPixels(XCUIScreen.mainScreen.screenshot, element.frame);
        if (count >= 3) return count;
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return count;
}

- (void)testPublicTypingReturnSplitAndMovedCaretStayVisible {
    XCUIApplication *application = [self launchScenario:@"caret"];
    XCUIElement *editor = [self element:@"block-text-view" application:application];
    XCUIElement *status = [self element:@"block-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);

    NSMutableString *typed = [@"alpha\nbeta" mutableCopy];
    for (NSUInteger line = 0; line < 18; line += 1) {
        [typed appendFormat:@"\nscroll line %02lu", (unsigned long)line];
    }
    [editor typeText:typed];

    __block NSDictionary *last = nil;
    XCTAssertTrue([self waitForStatus:status timeout:8.0 block:^BOOL(NSDictionary *value) {
        last = value;
        NSDictionary *selection = value[@"selection"];
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:typed] &&
            [value[@"scenario"] isEqualToString:@"caret"] &&
            [value[@"state"] isEqualToString:@"edited"] &&
            [value[@"blockCount"] unsignedIntegerValue] == 20 &&
            [selection[@"location"] unsignedIntegerValue] == typed.length &&
            [selection[@"length"] unsignedIntegerValue] == 0 &&
            [value[@"visible"] boolValue];
    }], @"%@", last);
}

- (void)testBackwardDeleteAtSecondBlockBoundaryMergesBlocks {
    XCUIApplication *application = [self launchScenario:@"boundary"];
    XCUIElement *editor = [self element:@"block-text-view" application:application];
    XCUIElement *status = [self element:@"block-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);

    [editor typeText:XCUIKeyboardKeyDelete];
    XCTAssertTrue([self waitForStatus:status timeout:5.0 block:^BOOL(NSDictionary *value) {
        NSDictionary *selection = value[@"selection"];
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:@"alphabeta"] &&
            [value[@"scenario"] isEqualToString:@"boundary"] &&
            [value[@"state"] isEqualToString:@"merged"] &&
            [value[@"blockCount"] unsignedIntegerValue] == 1 &&
            [selection[@"location"] unsignedIntegerValue] == 5 &&
            [selection[@"length"] unsignedIntegerValue] == 0;
    }]);
}

- (void)testPublicShiftArrowSelectionSpansStructuralNewlineAtStockCompatibleEndpoint {
    XCUIApplication *application = [self launchScenario:@"selection"];
    XCUIElement *editor = [self element:@"block-text-view" application:application];
    XCUIElement *status = [self element:@"block-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([self waitForStatus:status timeout:4.0 block:^BOOL(NSDictionary *value) {
        NSDictionary *selection = value[@"selection"];
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:@"alpha\nbeta"] &&
            [value[@"scenario"] isEqualToString:@"selection"] &&
            [value[@"state"] isEqualToString:@"seeded-caret"] &&
            [value[@"blockCount"] unsignedIntegerValue] == 2 &&
            [selection[@"location"] unsignedIntegerValue] == 3 &&
            [selection[@"length"] unsignedIntegerValue] == 0;
    }]);
    for (NSUInteger index = 0; index < 4; index += 1) {
        [editor typeKey:XCUIKeyboardKeyRightArrow modifierFlags:XCUIKeyModifierShift];
    }
    __block NSDictionary<NSString *, id> *last = nil;
    XCTAssertTrue([self waitForStatus:status timeout:4.0 block:^BOOL(NSDictionary *value) {
        last = value;
        NSDictionary *selection = value[@"selection"];
        NSUInteger location = [selection[@"location"] unsignedIntegerValue];
        NSUInteger length = [selection[@"length"] unsignedIntegerValue];
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:@"alpha\nbeta"] &&
            [value[@"scenario"] isEqualToString:@"selection"] &&
            [value[@"state"] isEqualToString:@"public-selection"] &&
            [value[@"blockCount"] unsignedIntegerValue] == 2 &&
            length > 0 &&
            location <= 5 &&
            location <= 7 &&
            length <= 7 - location &&
            location + length == 7;
    }], @"%@", last);
}

- (void)testPublicArrowCaretCrossesStructuralNewlineInBothDirections {
    XCUIApplication *application = [self launchScenario:@"selection"];
    XCUIElement *editor = [self element:@"block-text-view" application:application];
    XCUIElement *status = [self element:@"block-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);

    __block NSDictionary<NSString *, id> *last = nil;
    BOOL (^waitForLocation)(NSUInteger) = ^BOOL(NSUInteger expectedLocation) {
        return [self waitForStatus:status timeout:4.0 block:^BOOL(NSDictionary *value) {
            last = value;
            NSDictionary *selection = value[@"selection"];
            return IDBlockUIStatusHasExactSchema(value) &&
                [value[@"canonical"] isEqualToString:@"alpha\nbeta"] &&
                [value[@"scenario"] isEqualToString:@"selection"] &&
                [value[@"state"] isEqualToString:@"seeded-caret"] &&
                [value[@"blockCount"] unsignedIntegerValue] == 2 &&
                [selection[@"location"] unsignedIntegerValue] == expectedLocation &&
                [selection[@"length"] unsignedIntegerValue] == 0;
        }];
    };

    XCTAssertTrue(waitForLocation(3), @"%@", last);
    for (NSUInteger index = 0; index < 3; index += 1) {
        [editor typeKey:XCUIKeyboardKeyRightArrow modifierFlags:0];
    }
    XCTAssertTrue(waitForLocation(6), @"%@", last);
    [editor typeKey:XCUIKeyboardKeyRightArrow modifierFlags:0];
    XCTAssertTrue(waitForLocation(7), @"%@", last);
    for (NSUInteger index = 0; index < 2; index += 1) {
        [editor typeKey:XCUIKeyboardKeyLeftArrow modifierFlags:0];
    }
    XCTAssertTrue(waitForLocation(5), @"%@", last);
}

- (void)testPublicHorizontalNavigationCoversBiDiEmojiAndConsecutiveEmptyBlocks {
    NSString *scenario = @"navigation-horizontal";
    NSString *canonical = @"abc אבג\nA👨‍👩‍👧‍👦B\n\n\ntail";
    NSMutableArray<NSDictionary<NSString *, id> *> *keys = [NSMutableArray array];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyRightArrow
                                                 count:15
                                             modifiers:0]];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyLeftArrow
                                                 count:15
                                             modifiers:0]];

    XCUIApplication *stock = [self launchStockNavigationScenario:scenario];
    XCUIElement *stockEditor = [self element:@"stock-text-view" application:stock];
    XCUIElement *stockStatus = [self element:@"touch-status" application:stock];
    XCTAssertTrue([stockEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([stockStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *stockTrace = [self navigationTraceForEditor:stockEditor
                                                            status:stockStatus
                                                             stock:YES
                                                          scenario:scenario
                                                         canonical:canonical
                                                              keys:keys];
    [stock terminate];

    XCUIApplication *custom = [self launchScenario:scenario];
    XCUIElement *customEditor = [self element:@"block-text-view" application:custom];
    XCUIElement *customStatus = [self element:@"block-status" application:custom];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *customTrace = [self navigationTraceForEditor:customEditor
                                                              status:customStatus
                                                               stock:NO
                                                            scenario:scenario
                                                           canonical:canonical
                                                                keys:keys];

    XCTAssertEqualObjects(customTrace, stockTrace);
    XCTAssertEqual(stockTrace.count, keys.count + 1);
    if (stockTrace.count != keys.count + 1) return;
    XCTAssertTrue(NSEqualRanges(stockTrace.firstObject.rangeValue,
                                NSMakeRange(3, 0)));
    for (NSValue *value in stockTrace) {
        NSRange selection = value.rangeValue;
        XCTAssertEqual(selection.length, 0U);
        XCTAssertFalse(selection.location > 9 && selection.location < 20,
                       @"caret stopped inside emoji cluster at %@", value);
    }
    NSArray<NSNumber *> *emptyBoundaryStops = @[@21, @22, @23, @24];
    NSUInteger nextStop = 0;
    for (NSUInteger index = 0; index <= 15 &&
         nextStop < emptyBoundaryStops.count; index += 1) {
        if (stockTrace[index].rangeValue.location ==
            emptyBoundaryStops[nextStop].unsignedIntegerValue) {
            nextStop += 1;
        }
    }
    XCTAssertEqual(nextStop, emptyBoundaryStops.count,
                   @"right trace skipped an empty-block stop: %@", stockTrace);
    BOOL crossedFirstSeparatorForward = NO;
    BOOL crossedFirstSeparatorBackward = NO;
    for (NSUInteger index = 1; index < stockTrace.count; index += 1) {
        NSUInteger before = stockTrace[index - 1].rangeValue.location;
        NSUInteger after = stockTrace[index].rangeValue.location;
        crossedFirstSeparatorForward |= before == 7 && after == 8;
        crossedFirstSeparatorBackward |= before == 8 && after == 7;
    }
    XCTAssertTrue(crossedFirstSeparatorForward, @"%@", stockTrace);
    XCTAssertTrue(crossedFirstSeparatorBackward, @"%@", stockTrace);
}

- (void)testPublicVerticalNavigationPreservesAnchorAcrossLongShortLongBlocksLikeStock {
    NSString *scenario = @"navigation-vertical";
    NSString *canonical = @"abcdefghijklmno\nxy\nabcdefghijklmno";
    NSArray<NSDictionary<NSString *, id> *> *keys = @[
        @{@"key": XCUIKeyboardKeyDownArrow, @"modifiers": @0},
        @{@"key": XCUIKeyboardKeyDownArrow, @"modifiers": @0},
        @{@"key": XCUIKeyboardKeyUpArrow, @"modifiers": @0},
        @{@"key": XCUIKeyboardKeyUpArrow, @"modifiers": @0},
    ];

    XCUIApplication *stock = [self launchStockNavigationScenario:scenario];
    XCUIElement *stockEditor = [self element:@"stock-text-view" application:stock];
    XCUIElement *stockStatus = [self element:@"touch-status" application:stock];
    XCTAssertTrue([stockEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([stockStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *stockTrace = [self navigationTraceForEditor:stockEditor
                                                            status:stockStatus
                                                             stock:YES
                                                          scenario:scenario
                                                         canonical:canonical
                                                              keys:keys];
    [stock terminate];

    XCUIApplication *custom = [self launchScenario:scenario];
    XCUIElement *customEditor = [self element:@"block-text-view" application:custom];
    XCUIElement *customStatus = [self element:@"block-status" application:custom];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *customTrace = [self navigationTraceForEditor:customEditor
                                                              status:customStatus
                                                               stock:NO
                                                            scenario:scenario
                                                           canonical:canonical
                                                                keys:keys];

    XCTAssertEqualObjects(customTrace, stockTrace);
    XCTAssertEqual(stockTrace.count, 5U);
    if (stockTrace.count != 5U) return;
    XCTAssertTrue(NSEqualRanges(stockTrace[0].rangeValue, NSMakeRange(12, 0)));
    XCTAssertTrue(NSLocationInRange(stockTrace[1].rangeValue.location,
                                    NSMakeRange(16, 3)),
                  @"first Down skipped the short adjacent block: %@", stockTrace);
    XCTAssertGreaterThanOrEqual(stockTrace[2].rangeValue.location, 19U);
    XCTAssertTrue(NSLocationInRange(stockTrace[3].rangeValue.location,
                                    NSMakeRange(16, 3)));
    XCTAssertEqual(stockTrace[4].rangeValue.location, 12U);
}

- (void)testPublicShiftArrowExtendsReversesAndCollapsesAcrossMultipleStructuralNewlinesLikeStock {
    NSString *scenario = @"navigation-selection";
    NSString *canonical = @"alpha\n\nbeta\ngamma";
    NSMutableArray<NSDictionary<NSString *, id> *> *keys = [NSMutableArray array];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyRightArrow
                                                 count:8
                                             modifiers:XCUIKeyModifierShift]];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyLeftArrow
                                                 count:8
                                             modifiers:XCUIKeyModifierShift]];
    [keys addObject:@{@"key": XCUIKeyboardKeyLeftArrow,
                      @"modifiers": @(XCUIKeyModifierShift)}];

    XCUIApplication *stock = [self launchStockNavigationScenario:scenario];
    XCUIElement *stockEditor = [self element:@"stock-text-view" application:stock];
    XCUIElement *stockStatus = [self element:@"touch-status" application:stock];
    XCTAssertTrue([stockEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([stockStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *stockTrace = [self navigationTraceForEditor:stockEditor
                                                            status:stockStatus
                                                             stock:YES
                                                          scenario:scenario
                                                         canonical:canonical
                                                              keys:keys];
    [stock terminate];

    XCUIApplication *custom = [self launchScenario:scenario];
    XCUIElement *customEditor = [self element:@"block-text-view" application:custom];
    XCUIElement *customStatus = [self element:@"block-status" application:custom];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *customTrace = [self navigationTraceForEditor:customEditor
                                                              status:customStatus
                                                               stock:NO
                                                            scenario:scenario
                                                           canonical:canonical
                                                                keys:keys];

    XCTAssertEqualObjects(customTrace, stockTrace);
    XCTAssertEqual(stockTrace.count, keys.count + 1);
    if (stockTrace.count != keys.count + 1) return;
    XCTAssertTrue(NSEqualRanges(stockTrace.firstObject.rangeValue,
                                NSMakeRange(3, 0)));
    NSRange extended = stockTrace[8].rangeValue;
    XCTAssertEqual(extended.location, 4U);
    XCTAssertEqual(NSMaxRange(extended), 11U);
    XCTAssertEqual([[canonical substringWithRange:extended]
        componentsSeparatedByString:@"\n"].count - 1, 2U);
    XCTAssertTrue(NSEqualRanges(stockTrace[15].rangeValue,
                                NSMakeRange(4, 0)));
    XCTAssertTrue(NSEqualRanges(stockTrace[16].rangeValue,
                                NSMakeRange(3, 1)));
    XCTAssertTrue(NSEqualRanges(stockTrace[17].rangeValue,
                                NSMakeRange(2, 2)));
    for (NSValue *value in stockTrace) {
        NSRange selection = value.rangeValue;
        NSString *selected = [canonical substringWithRange:selection];
        NSUInteger newlineCount = [selected componentsSeparatedByString:@"\n"].count - 1;
        NSUInteger includedLocations = 0;
        for (NSNumber *location in @[@5, @6, @11]) {
            if (location.unsignedIntegerValue >= selection.location &&
                location.unsignedIntegerValue < NSMaxRange(selection)) {
                includedLocations += 1;
            }
        }
        XCTAssertEqual(newlineCount, includedLocations, @"%@", value);
    }
}

- (void)testPublicSelectionRectsMatchStockAcrossIndependentBlocks {
    NSString *scenario = @"geometry-authority";
    NSString *canonical = @"alpha beta wrapped words\n\nאבגדה six mixed text\nA👨‍👩‍👧‍👦B composed tail\nfinal block";
    NSRange selection = NSMakeRange([@"alpha beta wrapped words" length], 1);

    XCUIApplication *stockApplication =
        [self launchStockGeometryScenario:scenario selection:selection];
    NSDictionary *stockStatus = [self waitForGeometryStatus:
        [self element:@"geometry-status" application:stockApplication]
                                                      stock:YES
                                                   scenario:scenario
                                                  canonical:canonical
                                          previousSelection:nil
                                                    timeout:4.0];
    [stockApplication terminate];

    XCUIApplication *customApplication =
        [self launchGeometryScenario:scenario selection:selection];
    NSDictionary *customStatus = [self waitForGeometryStatus:
        [self element:@"geometry-status" application:customApplication]
                                                       stock:NO
                                                    scenario:scenario
                                                   canonical:canonical
                                           previousSelection:nil
                                                     timeout:4.0];
    XCTAssertNotNil(stockStatus);
    XCTAssertNotNil(customStatus);
    if (stockStatus != nil && customStatus != nil) {
        XCTAssertTrue(NSEqualRanges(
            [self navigationSelectionFromStatus:stockStatus], selection));
        [self assertSelectionStatus:customStatus matchesStock:stockStatus];
    }
}

- (void)testPublicSelectionEndpointRolesMatchStockForMixedBiDiAndReversal {
    NSString *scenario = @"geometry-authority";
    NSString *canonical = @"alpha beta wrapped words\n\nאבגדה six mixed text\nA👨‍👩‍👧‍👦B composed tail\nfinal block";
    NSUInteger bidiStart = [@"alpha beta wrapped words\n\n" length] + 2;
    NSMutableArray *keys = [NSMutableArray array];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyRightArrow
                                                 count:2
                                             modifiers:XCUIKeyModifierShift]];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyLeftArrow
                                                 count:4
                                             modifiers:XCUIKeyModifierShift]];

    XCUIApplication *stockApplication =
        [self launchStockGeometryScenario:scenario
                                selection:NSMakeRange(bidiStart, 0)];
    XCUIElement *stockStatusElement =
        [self element:@"geometry-status" application:stockApplication];
    NSDictionary *stockBoundaryStatus = [self waitForGeometryStatus:
        stockStatusElement stock:YES scenario:scenario canonical:canonical
        previousSelection:nil timeout:4.0];
    NSArray *stockTrace = [self geometrySelectionTraceForEditor:
        [self element:@"stock-text-view" application:stockApplication]
                                                        status:
        stockStatusElement
                                                         stock:YES
                                                      scenario:scenario
                                                     canonical:canonical
                                                          keys:keys];
    [stockApplication terminate];

    XCUIApplication *customApplication =
        [self launchGeometryScenario:scenario
                           selection:NSMakeRange(bidiStart, 0)];
    XCUIElement *customStatusElement =
        [self element:@"geometry-status" application:customApplication];
    NSDictionary *customBoundaryStatus = [self waitForGeometryStatus:
        customStatusElement stock:NO scenario:scenario canonical:canonical
        previousSelection:nil timeout:4.0];
    XCTAssertNotNil(stockBoundaryStatus);
    XCTAssertNotNil(customBoundaryStatus);
    if (stockBoundaryStatus != nil && customBoundaryStatus != nil) {
        [self assertCustomBoundary:customBoundaryStatus
                       matchesStock:stockBoundaryStatus];
    }
    NSArray *customTrace = [self geometrySelectionTraceForEditor:
        [self element:@"block-text-view" application:customApplication]
                                                         status:
        customStatusElement
                                                          stock:NO
                                                       scenario:scenario
                                                      canonical:canonical
                                                           keys:keys];
    XCTAssertEqual(customTrace.count, stockTrace.count);
    XCTAssertEqual(stockTrace.count, keys.count);
    NSUInteger count = MIN(customTrace.count, stockTrace.count);
    for (NSUInteger index = 0; index < count; index += 1) {
        [self assertSelectionStatus:customTrace[index]
                      matchesStock:stockTrace[index]];
    }
    if (stockTrace.count == keys.count) {
        NSRange last = [self navigationSelectionFromStatus:stockTrace.lastObject];
        XCTAssertGreaterThan(last.length, 0U);
        XCTAssertLessThan(last.location, bidiStart,
                          @"final shift-left must reverse through the anchor");
    }
}

- (void)testPublicGeometryCaretAndTapSequenceMatchesStockAcrossIndependentBlocks {
    NSString *scenario = @"geometry-authority";
    NSString *canonical = @"alpha beta wrapped words\n\nאבגדה six mixed text\nA👨‍👩‍👧‍👦B composed tail\nfinal block";
    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(0.65, 0.055)],
        [NSValue valueWithCGPoint:CGPointMake(0.18, 0.122)],
        [NSValue valueWithCGPoint:CGPointMake(0.45, 0.189)],
        [NSValue valueWithCGPoint:CGPointMake(0.70, 0.256)],
        [NSValue valueWithCGPoint:CGPointMake(0.35, 0.322)],
    ];

    XCUIApplication *stock = [self launchStockNavigationScenario:scenario];
    XCUIElement *stockEditor = [self element:@"stock-text-view" application:stock];
    XCUIElement *stockStatus = [self element:@"geometry-status" application:stock];
    XCTAssertTrue([stockEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([stockStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSDictionary<NSString *, id> *> *stockTrace =
        [self geometryTapTraceForEditor:stockEditor status:stockStatus
                                  stock:YES scenario:scenario
                              canonical:canonical points:points];
    [stock terminate];

    XCUIApplication *custom = [self launchScenario:scenario];
    XCUIElement *customEditor = [self element:@"block-text-view" application:custom];
    XCUIElement *customStatus = [self element:@"geometry-status" application:custom];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSDictionary<NSString *, id> *> *customTrace =
        [self geometryTapTraceForEditor:customEditor status:customStatus
                                  stock:NO scenario:scenario
                              canonical:canonical points:points];

    XCTAssertEqual(stockTrace.count, points.count);
    XCTAssertEqual(customTrace.count, points.count);
    if (stockTrace.count != points.count || customTrace.count != points.count) return;
    NSRange emoji = [canonical rangeOfString:@"👨‍👩‍👧‍👦"];
    for (NSUInteger index = 0; index < points.count; index += 1) {
        NSRange stockSelection = [self navigationSelectionFromStatus:stockTrace[index]];
        NSRange customSelection = [self navigationSelectionFromStatus:customTrace[index]];
        XCTAssertTrue(NSEqualRanges(customSelection, stockSelection),
                      @"tap=%lu stock=%@ custom=%@",
                      (unsigned long)index,
                      NSStringFromRange(stockSelection),
                      NSStringFromRange(customSelection));
        XCTAssertEqual(stockSelection.length, 0U);
        XCTAssertFalse(stockSelection.location > emoji.location &&
                       stockSelection.location < NSMaxRange(emoji));
        for (NSDictionary *status in @[stockTrace[index], customTrace[index]]) {
            NSDictionary *caret = status[@"caret"];
            XCTAssertTrue(IDBlockUIFiniteNumber(caret[@"x"]));
            XCTAssertTrue(IDBlockUIFiniteNumber(caret[@"y"]));
            XCTAssertGreaterThan([caret[@"width"] doubleValue], 0.0);
            XCTAssertGreaterThan([caret[@"height"] doubleValue], 0.0);
        }
    }
}

- (void)testPublicGeometryShiftSelectionUsesStockCompatibleLineBoundaries {
    NSString *scenario = @"geometry-authority";
    NSString *canonical = @"alpha beta wrapped words\n\nאבגדה six mixed text\nA👨‍👩‍👧‍👦B composed tail\nfinal block";
    NSMutableArray<NSDictionary<NSString *, id> *> *keys = [NSMutableArray array];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyDownArrow
                                                 count:4
                                             modifiers:XCUIKeyModifierShift]];
    [keys addObjectsFromArray:[self navigationKeys:XCUIKeyboardKeyUpArrow
                                                 count:4
                                             modifiers:XCUIKeyModifierShift]];

    XCUIApplication *stock = [self launchStockNavigationScenario:scenario];
    XCUIElement *stockEditor = [self element:@"stock-text-view" application:stock];
    XCUIElement *stockStatus = [self element:@"geometry-status" application:stock];
    XCTAssertTrue([stockEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([stockStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *stockTrace = [self navigationTraceForEditor:stockEditor
                                                            status:stockStatus
                                                             stock:YES
                                                          scenario:scenario
                                                         canonical:canonical
                                                              keys:keys];
    [stock terminate];

    XCUIApplication *custom = [self launchScenario:scenario];
    XCUIElement *customEditor = [self element:@"block-text-view" application:custom];
    XCUIElement *customStatus = [self element:@"geometry-status" application:custom];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    NSArray<NSValue *> *customTrace = [self navigationTraceForEditor:customEditor
                                                              status:customStatus
                                                               stock:NO
                                                            scenario:scenario
                                                           canonical:canonical
                                                                keys:keys];

    XCTAssertEqualObjects(customTrace, stockTrace);
    XCTAssertEqual(stockTrace.count, keys.count + 1);
}

- (void)testPublicLargeDocumentSelectAllRetainsCanonicalRangeWhileVisibleGeometryChanges {
    NSString *scenario = @"geometry-large-selection";
    NSMutableArray<NSString *> *blocks = [NSMutableArray array];
    for (NSUInteger index = 0; index < 120; index += 1) {
        [blocks addObject:[NSString stringWithFormat:@"block %03lu",
            (unsigned long)index]];
    }
    NSString *canonical = [blocks componentsJoinedByString:@"\n"];

    for (NSNumber *stockValue in @[@YES, @NO]) {
        BOOL stock = stockValue.boolValue;
        XCUIApplication *application = stock
            ? [self launchStockNavigationScenario:scenario]
            : [self launchScenario:scenario];
        XCUIElement *editor = [self element:stock ? @"stock-text-view" : @"block-text-view"
                                    application:application];
        XCUIElement *status = [self element:@"geometry-status" application:application];
        XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
        XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
        NSDictionary *ready = [self waitForGeometryStatus:status
                                                    stock:stock
                                                 scenario:scenario
                                                canonical:canonical
                                        previousSelection:nil
                                                  timeout:5.0];
        XCTAssertEqual([ready[@"canonicalLength"] unsignedIntegerValue], canonical.length);

        NSPredicate *focusPredicate =
            [NSPredicate predicateWithFormat:@"hasKeyboardFocus == true"];
        XCTNSPredicateExpectation *focusExpectation =
            [[XCTNSPredicateExpectation alloc] initWithPredicate:focusPredicate
                                                          object:editor];
        XCTAssertEqual([XCTWaiter waitForExpectations:@[focusExpectation]
                                              timeout:4.0],
                       XCTWaiterResultCompleted,
                       @"editor never acquired keyboard focus: stock=%d", stock);
        XCUIElement *selectAll =
            [self element:@"geometry-select-all" application:application];
        BOOL hasSelectAll = [selectAll waitForExistenceWithTimeout:2.0];
        XCTAssertTrue(hasSelectAll, @"Select All fixture action absent: stock=%d", stock);
        if (!hasSelectAll) {
            [application terminate];
            continue;
        }
        [selectAll tap];
        __block NSDictionary<NSString *, id> *selected = nil;
        BOOL selectedAll = [self waitForStatus:status timeout:5.0
            block:^BOOL(NSDictionary<NSString *, id> *value) {
                selected = value;
                NSRange range = [self navigationSelectionFromStatus:value];
                return IDGeometryStatusHasExactSchema(value) &&
                    range.location == 0 && range.length == canonical.length &&
                    [value[@"selectionTextLength"] unsignedIntegerValue] == canonical.length;
            }];
        XCTAssertTrue(selectedAll, @"stock=%d last=%@", stock, selected);
        if (!selectedAll) {
            [application terminate];
            continue;
        }
        CGFloat previousOffsetY = [selected[@"contentOffset"][@"y"] doubleValue];
        for (NSUInteger index = 0; index < 2; index += 1) {
            [editor swipeUp];
            __block NSDictionary<NSString *, id> *scrolled = nil;
            XCTAssertTrue([self waitForStatus:status timeout:4.0
                block:^BOOL(NSDictionary<NSString *, id> *value) {
                    scrolled = value;
                    NSRange range = [self navigationSelectionFromStatus:value];
                    return IDGeometryStatusHasExactSchema(value) &&
                        range.location == 0 && range.length == canonical.length &&
                        [value[@"selectionTextLength"] unsignedIntegerValue] == canonical.length &&
                        [value[@"contentOffset"][@"y"] doubleValue] > previousOffsetY;
                }], @"stock=%d scroll=%lu last=%@",
                stock, (unsigned long)index, scrolled);
            previousOffsetY = [scrolled[@"contentOffset"][@"y"] doubleValue];
        }
        [application terminate];
    }
}

- (void)testReturnThenBackspaceWithSpellingMarkerMergesWithoutCrashing {
    XCUIApplication *application = [self launchScenario:@"spelling"];
    XCUIElement *editor = [self element:@"block-text-view" application:application];
    XCUIElement *status = [self element:@"block-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);

    NSString *word = @"hello mispelled ";
    [editor typeText:word];
    __block NSDictionary *last = nil;
    __block NSUInteger postReturnGeometryRequests = 0;
    XCTAssertTrue([self waitForStatus:status timeout:8.0 block:^BOOL(NSDictionary *value) {
        last = value;
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:word] &&
            [value[@"scenario"] isEqualToString:@"spelling"] &&
            [value[@"state"] isEqualToString:@"annotated"] &&
            [value[@"spelling"] isEqualToString:@"2"];
    }], @"%@", last);

    NSUInteger mergeLocation = word.length - 1;
    [editor typeKey:XCUIKeyboardKeyLeftArrow modifierFlags:0];
    XCTAssertTrue([self waitForStatus:status timeout:5.0 block:^BOOL(NSDictionary *value) {
        last = value;
        NSDictionary *selection = value[@"selection"];
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:word] &&
            [value[@"spelling"] isEqualToString:@"2"] &&
            [selection[@"location"] unsignedIntegerValue] == mergeLocation &&
            [selection[@"length"] unsignedIntegerValue] == 0;
    }], @"%@", last);

    NSString *splitText = [word stringByReplacingCharactersInRange:
        NSMakeRange(mergeLocation, 0) withString:@"\n"];
    [editor typeText:@"\n"];
    XCTAssertTrue([self waitForStatus:status timeout:5.0 block:^BOOL(NSDictionary *value) {
        last = value;
        NSDictionary *selection = value[@"selection"];
        BOOL matches = IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:splitText] &&
            [value[@"blockCount"] unsignedIntegerValue] == 2 &&
            [value[@"spelling"] isEqualToString:@"2"] &&
            [selection[@"location"] unsignedIntegerValue] == mergeLocation + 1 &&
            [selection[@"length"] unsignedIntegerValue] == 0;
        if (matches) {
            postReturnGeometryRequests =
                [value[@"spellingGeometryRequests"] unsignedIntegerValue];
        }
        return matches;
    }], @"%@", last);

    [editor typeText:XCUIKeyboardKeyDelete];
    XCTAssertTrue([self waitForStatus:status timeout:5.0 block:^BOOL(NSDictionary *value) {
        last = value;
        NSDictionary *selection = value[@"selection"];
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:word] &&
            [value[@"blockCount"] unsignedIntegerValue] == 1 &&
            [value[@"spellingGeometryRequests"] unsignedIntegerValue] >
                postReturnGeometryRequests &&
            [selection[@"location"] unsignedIntegerValue] == mergeLocation &&
            [selection[@"length"] unsignedIntegerValue] == 0;
    }], @"%@", last);
}

- (void)testNativeSpellingMarkerProducesVisibleRedPixels {
    XCUIApplication *application = [self launchScenario:@"spelling"];
    XCUIElement *editor = [self element:@"block-text-view" application:application];
    XCUIElement *status = [self element:@"block-status" application:application];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);

    [editor typeText:@"hello mispelled "];
    __block NSDictionary *last = nil;
    BOOL annotated = [self waitForStatus:status timeout:8.0 block:^BOOL(NSDictionary *value) {
        last = value;
        return IDBlockUIStatusHasExactSchema(value) &&
            [value[@"canonical"] isEqualToString:@"hello mispelled "] &&
            [value[@"scenario"] isEqualToString:@"spelling"] &&
            [value[@"state"] isEqualToString:@"annotated"] &&
            ![value[@"spelling"] isEqualToString:@"none"];
    }];
    XCTAssertTrue(annotated, @"%@", last);
    if (!annotated) return;
    XCTAssertGreaterThanOrEqual([self waitForRedPixelsInElement:editor timeout:8.0], 3U);
}

@end
