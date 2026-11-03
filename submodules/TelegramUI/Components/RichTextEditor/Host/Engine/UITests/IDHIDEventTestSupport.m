#import "IDHIDEventTestSupport.h"

#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const IDHIDErrorDomain = @"com.inputdec.tests.hid-events";

@interface IDHIDTouchWaypoint ()
@property(nonatomic, readwrite) CGPoint screenPoint;
@property(nonatomic, readwrite) NSTimeInterval offset;
@property(nonatomic, readwrite, getter=isLift) BOOL lift;
@end

@implementation IDHIDTouchWaypoint

+ (instancetype)moveTo:(CGPoint)screenPoint offset:(NSTimeInterval)offset {
    IDHIDTouchWaypoint *waypoint = [self new];
    waypoint.screenPoint = screenPoint;
    waypoint.offset = offset;
    waypoint.lift = NO;
    return waypoint;
}

+ (instancetype)liftAtOffset:(NSTimeInterval)offset {
    IDHIDTouchWaypoint *waypoint = [self new];
    waypoint.screenPoint = CGPointZero;
    waypoint.offset = offset;
    waypoint.lift = YES;
    return waypoint;
}

@end

@interface IDHIDTouchPath ()
@property(nonatomic, readwrite) CGPoint startScreenPoint;
@property(nonatomic, readwrite) NSTimeInterval startOffset;
@property(nonatomic, copy, readwrite) NSArray<IDHIDTouchWaypoint *> *waypoints;
@end

@implementation IDHIDTouchPath

- (instancetype)initWithStartScreenPoint:(CGPoint)point
                              startOffset:(NSTimeInterval)offset
                                waypoints:(NSArray<IDHIDTouchWaypoint *> *)waypoints {
    self = [super init];
    if (self == nil) return nil;
    _startScreenPoint = point;
    _startOffset = offset;
    _waypoints = [waypoints copy];
    return self;
}

@end

@implementation IDHIDFloatingLifecycleSchedule
@end

BOOL IDHIDBuildFloatingLifecycleTouchPaths(
    CGPoint keyboardPoint,
    CGPoint actionPoint,
    IDHIDFloatingLifecycleSchedule *schedule,
    NSArray<IDHIDTouchPath *> **paths,
    NSError **error) {
    NSArray<NSNumber *> *offsets = @[
        @(schedule.keyboardActivation), @(schedule.heldCapture),
        @(schedule.actionDown), @(schedule.actionUp),
        @(schedule.immediateCapture), @(schedule.settledCapture),
        @(schedule.keyboardLift), @(schedule.postLiftCapture),
    ];
    for (NSNumber *offset in offsets) {
        if (!isfinite(offset.doubleValue)) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:IDHIDErrorDomain code:2 userInfo:@{
                    NSLocalizedDescriptionKey: @"Lifecycle offsets must be finite",
                }];
            }
            return NO;
        }
    }
    if (!(schedule.keyboardActivation > 0.0 &&
          schedule.keyboardActivation <= schedule.heldCapture &&
          schedule.heldCapture < schedule.actionDown &&
          schedule.actionDown < schedule.actionUp)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:IDHIDErrorDomain code:2 userInfo:@{
                NSLocalizedDescriptionKey: @"Lifecycle action must follow held capture in strict order",
            }];
        }
        return NO;
    }
    if (!(schedule.actionUp < schedule.keyboardLift)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:IDHIDErrorDomain code:2 userInfo:@{
                NSLocalizedDescriptionKey: @"actionUp must precede keyboardLift",
            }];
        }
        return NO;
    }
    if (!(schedule.actionUp < schedule.immediateCapture &&
          schedule.immediateCapture < schedule.settledCapture &&
          schedule.settledCapture < schedule.keyboardLift &&
          schedule.keyboardLift < schedule.postLiftCapture)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:IDHIDErrorDomain code:2 userInfo:@{
                NSLocalizedDescriptionKey: @"Lifecycle captures must follow actionUp and precede keyboardLift",
            }];
        }
        return NO;
    }
    BOOL exactSettled = fabs(schedule.settledCapture -
        (schedule.actionUp + 0.500)) < 0.000001;
    BOOL exactPostLift = fabs(schedule.postLiftCapture -
        (schedule.keyboardLift + 0.500)) < 0.000001;
    if (!exactSettled || !exactPostLift) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:IDHIDErrorDomain code:2 userInfo:@{
                NSLocalizedDescriptionKey: @"Lifecycle capture offsets must be exact +0.500 seconds",
            }];
        }
        return NO;
    }
    IDHIDTouchPath *keyboardPath = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:keyboardPoint startOffset:0.0 waypoints:@[
            [IDHIDTouchWaypoint moveTo:keyboardPoint offset:schedule.keyboardActivation],
            [IDHIDTouchWaypoint moveTo:keyboardPoint offset:schedule.keyboardLift - 0.25],
            [IDHIDTouchWaypoint liftAtOffset:schedule.keyboardLift],
        ]];
    IDHIDTouchPath *actionPath = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:actionPoint startOffset:schedule.actionDown waypoints:@[
            [IDHIDTouchWaypoint liftAtOffset:schedule.actionUp],
        ]];
    if (paths != NULL) *paths = @[keyboardPath, actionPath];
    return YES;
}

static const char *IDHIDSkipABIQualifiers(const char *type) {
    while (type != NULL && strchr("rnNoORV", type[0]) != NULL) type += 1;
    return type;
}

static BOOL IDHIDABITypeMatches(const char *actual, const char *expected) {
    actual = IDHIDSkipABIQualifiers(actual);
    expected = IDHIDSkipABIQualifiers(expected);
    return actual != NULL && expected != NULL && strcmp(actual, expected) == 0;
}

static void IDHIDRecordFailure(XCTestCase *testCase, NSString *description) {
    [testCase recordIssue:[[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
                                      compactDescription:description]];
}

static BOOL IDHIDAssertPrivateMethod(XCTestCase *testCase,
                                     Class cls,
                                     NSString *selectorName,
                                     const char *returnType,
                                     NSArray<NSString *> *argumentTypes) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (method == NULL) {
        IDHIDRecordFailure(testCase,
            [NSString stringWithFormat:@"Missing private XCTest selector %@", selectorName]);
        return NO;
    }
    NSMethodSignature *signature =
        [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    BOOL compatible = IDHIDABITypeMatches(signature.methodReturnType, returnType);
    if (!compatible) {
        IDHIDRecordFailure(testCase, [NSString stringWithFormat:@"%@ return ABI: %s",
                                      selectorName, signature.methodReturnType]);
    }
    if (signature.numberOfArguments != argumentTypes.count) {
        IDHIDRecordFailure(testCase, [NSString stringWithFormat:@"%@ argument count ABI",
                                      selectorName]);
        return NO;
    }
    for (NSUInteger index = 0; index < argumentTypes.count; index += 1) {
        const char *actual = [signature getArgumentTypeAtIndex:index];
        const char *expected = argumentTypes[index].UTF8String;
        if (!IDHIDABITypeMatches(actual, expected)) {
            IDHIDRecordFailure(testCase,
                [NSString stringWithFormat:@"%@ argument %lu ABI: %s", selectorName,
                                           (unsigned long)index, actual]);
            compatible = NO;
        }
    }
    return compatible;
}

static BOOL IDHIDClassesAreCompatible(XCTestCase *testCase,
                                      Class pathClass,
                                      Class recordClass) {
    if (pathClass == Nil || recordClass == Nil) {
        IDHIDRecordFailure(testCase, @"Missing private XCTest HID event classes");
        return NO;
    }
    NSString *objectType = [NSString stringWithUTF8String:@encode(id)];
    NSString *selectorType = [NSString stringWithUTF8String:@encode(SEL)];
    NSString *pointType = [NSString stringWithUTF8String:@encode(CGPoint)];
    NSString *doubleType = [NSString stringWithUTF8String:@encode(double)];
    return
        IDHIDAssertPrivateMethod(testCase, pathClass, @"initForTouchAtPoint:offset:",
                                 @encode(id),
                                 @[objectType, selectorType, pointType, doubleType]) &&
        IDHIDAssertPrivateMethod(testCase, pathClass, @"moveToPoint:atOffset:",
                                 @encode(void),
                                 @[objectType, selectorType, pointType, doubleType]) &&
        IDHIDAssertPrivateMethod(testCase, pathClass, @"liftUpAtOffset:",
                                 @encode(void),
                                 @[objectType, selectorType, doubleType]) &&
        IDHIDAssertPrivateMethod(testCase, recordClass, @"initWithName:", @encode(id),
                                 @[objectType, selectorType, objectType]) &&
        IDHIDAssertPrivateMethod(testCase, recordClass, @"addPointerEventPath:",
                                 @encode(void),
                                 @[objectType, selectorType, objectType]) &&
        IDHIDAssertPrivateMethod(testCase, recordClass, @"synthesizeWithError:",
                                 @encode(BOOL),
                                 @[objectType, selectorType, @"^@"]) ;
}

BOOL IDHIDAssertRuntimeCompatible(XCTestCase *testCase) {
    return IDHIDClassesAreCompatible(testCase,
                                     NSClassFromString(@"XCPointerEventPath"),
                                     NSClassFromString(@"XCSynthesizedEventRecord"));
}

static BOOL IDHIDValidatePaths(XCTestCase *testCase,
                               NSArray<IDHIDTouchPath *> *paths) {
    if (paths.count == 0) {
        IDHIDRecordFailure(testCase, @"HID event record requires at least one touch path");
        return NO;
    }
    for (IDHIDTouchPath *path in paths) {
        if (!isfinite(path.startScreenPoint.x) || !isfinite(path.startScreenPoint.y) ||
            !isfinite(path.startOffset)) {
            IDHIDRecordFailure(testCase, @"HID touch path requires a finite start point and offset");
            return NO;
        }
        NSTimeInterval priorOffset = path.startOffset;
        NSUInteger liftCount = 0;
        for (NSUInteger index = 0; index < path.waypoints.count; index += 1) {
            IDHIDTouchWaypoint *waypoint = path.waypoints[index];
            if (!isfinite(waypoint.offset) || waypoint.offset <= priorOffset) {
                IDHIDRecordFailure(testCase,
                    @"HID touch waypoint offsets must be finite and strictly increasing");
                return NO;
            }
            if (!isfinite(waypoint.screenPoint.x) || !isfinite(waypoint.screenPoint.y)) {
                IDHIDRecordFailure(testCase, @"HID touch waypoints require finite points");
                return NO;
            }
            if (waypoint.isLift) liftCount += 1;
            priorOffset = waypoint.offset;
        }
        if (liftCount != 1 || !path.waypoints.lastObject.isLift) {
            IDHIDRecordFailure(testCase,
                @"HID touch path requires exactly one terminal lift waypoint");
            return NO;
        }
    }
    return YES;
}

id IDHIDBuildEventRecord(XCTestCase *testCase,
                         NSArray<IDHIDTouchPath *> *paths,
                         Class pathClass,
                         Class recordClass) {
    if (!IDHIDClassesAreCompatible(testCase, pathClass, recordClass) ||
        !IDHIDValidatePaths(testCase, paths)) {
        return nil;
    }
    id record = ((id (*)(id, SEL, id))objc_msgSend)(
        [recordClass alloc], NSSelectorFromString(@"initWithName:"),
        @"InputDec HID touch paths");
    for (IDHIDTouchPath *specification in paths) {
        id path = ((id (*)(id, SEL, CGPoint, double))objc_msgSend)(
            [pathClass alloc], NSSelectorFromString(@"initForTouchAtPoint:offset:"),
            specification.startScreenPoint, specification.startOffset);
        for (IDHIDTouchWaypoint *waypoint in specification.waypoints) {
            if (waypoint.isLift) {
                ((void (*)(id, SEL, double))objc_msgSend)(
                    path, NSSelectorFromString(@"liftUpAtOffset:"), waypoint.offset);
            } else {
                ((void (*)(id, SEL, CGPoint, double))objc_msgSend)(
                    path, NSSelectorFromString(@"moveToPoint:atOffset:"),
                    waypoint.screenPoint, waypoint.offset);
            }
        }
        ((void (*)(id, SEL, id))objc_msgSend)(
            record, NSSelectorFromString(@"addPointerEventPath:"), path);
    }
    return record;
}

BOOL IDHIDSynthesizeTouchPaths(XCTestCase *testCase,
                               XCUIApplication *application,
                               NSArray<IDHIDTouchPath *> *paths,
                               NSError **error) {
    (void)application;
    Class pathClass = NSClassFromString(@"XCPointerEventPath");
    Class recordClass = NSClassFromString(@"XCSynthesizedEventRecord");
    id record = IDHIDBuildEventRecord(testCase, paths, pathClass, recordClass);
    if (record == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:IDHIDErrorDomain code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                         @"Private XCTest HID event contract is incompatible or invalid"}];
        }
        return NO;
    }
    return ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(
        record, NSSelectorFromString(@"synthesizeWithError:"), error);
}

static BOOL IDHIDTapSoftwareKeyboardKeyReporting(
    XCTestCase *testCase, XCUIApplication *application, NSString *key,
    BOOL reportFailure) {
    XCUIElementQuery *matches = [application.keyboards.keys matchingIdentifier:key];
    if (matches.count == 0) {
        NSString *buttonIdentifier =
            [key isEqualToString:@"return"] ? @"Return" : key;
        matches = [application.keyboards.buttons
            matchingIdentifier:buttonIdentifier];
    }
    if (matches.count == 0 && [key isEqualToString:@"."]) {
        XCUIElementQuery *moreMatches =
            [application.keyboards.keys matchingIdentifier:@"more"];
        if (moreMatches.count == 1 && moreMatches.firstMatch.isHittable) {
            [moreMatches.firstMatch tap];
            NSPredicate *ready = [NSPredicate predicateWithBlock:
                ^BOOL(XCUIElement *element, NSDictionary *bindings) {
                    (void)bindings;
                    return element.exists && element.isHittable;
                }];
            XCUIElement *period =
                [application.keyboards.keys matchingIdentifier:key].firstMatch;
            XCTNSPredicateExpectation *expectation =
                [[XCTNSPredicateExpectation alloc] initWithPredicate:ready
                                                              object:period];
            [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
            matches = [application.keyboards.keys matchingIdentifier:key];
        }
    }
    if (matches.count != 1) {
        if (reportFailure) {
            XCTAttachment *hierarchy = [XCTAttachment attachmentWithString:
                application.debugDescription ?: @"unavailable"];
            hierarchy.name = [NSString stringWithFormat:
                @"software-keyboard-key-%@-missing-hierarchy", key];
            hierarchy.lifetime = XCTAttachmentLifetimeKeepAlways;
            [testCase addAttachment:hierarchy];
            IDHIDRecordFailure(testCase, [NSString stringWithFormat:
                @"Expected exactly one software-keyboard key '%@', found %lu",
                key, (unsigned long)matches.count]);
        }
        return NO;
    }
    XCUIElement *element = matches.firstMatch;
    if (!element.isHittable) {
        XCUIElement *keyboardIntroductionContinue =
            application.buttons[@"Continue"];
        if (keyboardIntroductionContinue.exists &&
            keyboardIntroductionContinue.isHittable) {
            [keyboardIntroductionContinue tap];
        }
        NSDate *hittableDeadline =
            [NSDate dateWithTimeIntervalSinceNow:5.0];
        do {
            matches =
                [application.keyboards.keys matchingIdentifier:key];
            if (matches.count == 0) {
                NSString *buttonIdentifier =
                    [key isEqualToString:@"return"] ? @"Return" : key;
                matches = [application.keyboards.buttons
                    matchingIdentifier:buttonIdentifier];
            }
            if (matches.count == 1 && matches.firstMatch.isHittable) {
                element = matches.firstMatch;
                break;
            }
            [NSThread sleepForTimeInterval:0.05];
        } while (hittableDeadline.timeIntervalSinceNow > 0);
    }
    if (!element.isHittable) {
        if (reportFailure) {
            IDHIDRecordFailure(testCase, [NSString stringWithFormat:
                @"Software-keyboard key '%@' is not hittable", key]);
        }
        return NO;
    }
    [element tap];
    return YES;
}

BOOL IDHIDTapSoftwareKeyboardKey(XCTestCase *testCase,
                                 XCUIApplication *application,
                                 NSString *key) {
    return IDHIDTapSoftwareKeyboardKeyReporting(
        testCase, application, key, YES);
}

BOOL IDHIDTypeSoftwareKeyboardText(XCTestCase *testCase,
                                   XCUIApplication *application,
                                   NSString *text) {
    __block BOOL success = YES;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
        options:NSStringEnumerationByComposedCharacterSequences
        usingBlock:^(NSString *substring, NSRange substringRange,
                     NSRange enclosingRange, BOOL *stop) {
            (void)substringRange;
            (void)enclosingRange;
            NSString *key = [substring isEqualToString:@" "] ? @"space" : substring;
            if (!IDHIDTapSoftwareKeyboardKeyReporting(
                    testCase, application, key, YES)) {
                success = NO;
                *stop = YES;
            }
        }];
    return success;
}

BOOL IDHIDTryTypeSoftwareKeyboardText(XCUIApplication *application,
                                      NSString *text) {
    __block BOOL success = YES;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
        options:NSStringEnumerationByComposedCharacterSequences
        usingBlock:^(NSString *substring, NSRange substringRange,
                     NSRange enclosingRange, BOOL *stop) {
            (void)substringRange;
            (void)enclosingRange;
            NSString *key = [substring isEqualToString:@" "]
                ? @"space" : substring;
            if (!IDHIDTapSoftwareKeyboardKeyReporting(
                    nil, application, key, NO)) {
                success = NO;
                *stop = YES;
            }
        }];
    return success;
}
