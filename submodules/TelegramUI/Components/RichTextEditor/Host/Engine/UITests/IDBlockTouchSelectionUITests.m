#import "IDTouchSelectionTestSupport.h"
#import "IDHIDEventTestSupport.h"
#import "IDVerticalAutoscroll.h"

#import <QuartzCore/QuartzCore.h>

static const NSTimeInterval IDTapSequenceQuiescenceInterval = 1.0;
static const NSTimeInterval IDEdgePressDuration = 0.10;
static const NSTimeInterval IDEdgeDragDuration = 0.80;
static const NSTimeInterval IDEdgeHoldSafetyMargin = 0.15;
static const NSTimeInterval IDEdgePhysicalHoldDuration = 2.50;
// Stock iOS 26.5, measured from a verified logical trailing handle: a raw
// synthesized endpoint at local {277.8333,388.8667} is delivered to
// -[UITextView startAutoscroll:] as {277.5,332.3333}.
static const CGVector IDStockTrailingHandleGrabOffset = { -0.3333333333, -56.5333333333 };
// Stock iOS 26.5, measured independently from a verified logical leading
// handle at content offset 1303. The initial offset was {-0.3333,+19.6}; one
// simulator-pixel calibration refinement produces the target assistant point.
static const CGVector IDStockLeadingHandleGrabOffset = { -0.3333333333, 20.5333333333 };
// The minimal controller's leading-handle adjustment point is delivered 25
// points below the reference controller for the same rendered-handle drag.
// Move only the synthesized endpoint so each backend enters the recovered
// 8-point phone edge band at the same effective adjustment point.
static const CGFloat IDMinimalLeadingHandleEndpointCalibration = 25.0;

typedef struct {
    CFTimeInterval start;
    CFTimeInterval end;
    CFTimeInterval scheduledLift;
} IDEdgeHoldWindow;

@interface IDEdgeHoldObservation : NSObject
@property(nonatomic, strong) NSMutableArray<NSValue *> *samples;
@property(nonatomic, strong)
    NSMutableArray<NSDictionary<NSString *, id> *> *traceSamples;
@property(nonatomic) NSUInteger parseFailures;
@property(nonatomic) CGFloat activeHandleEdgeDistance;
@property(nonatomic, copy, nullable) NSString *activeHandleStatus;
@property(nonatomic, strong, nullable) XCUIScreenshot *heldScreenshot;
@property(nonatomic) BOOL preLiftEdgeMarker;
@property(nonatomic) CFTimeInterval markerTime;
@property(nonatomic) CFTimeInterval screenshotTime;
@end

@implementation IDEdgeHoldObservation
@end

@interface IDHIDFakePath : NSObject
@property(nonatomic, strong) NSMutableArray<NSString *> *operations;
- (instancetype)initForTouchAtPoint:(CGPoint)point offset:(NSTimeInterval)offset;
- (void)moveToPoint:(CGPoint)point atOffset:(NSTimeInterval)offset;
- (void)liftUpAtOffset:(NSTimeInterval)offset;
@end

@implementation IDHIDFakePath
- (instancetype)initForTouchAtPoint:(CGPoint)point offset:(NSTimeInterval)offset {
    self = [super init];
    if (self == nil) return nil;
    _operations = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"start %@ %.2f", NSStringFromCGPoint(point), offset]];
    return self;
}
- (void)moveToPoint:(CGPoint)point atOffset:(NSTimeInterval)offset {
    [self.operations addObject:
        [NSString stringWithFormat:@"move %@ %.2f", NSStringFromCGPoint(point), offset]];
}
- (void)liftUpAtOffset:(NSTimeInterval)offset {
    [self.operations addObject:[NSString stringWithFormat:@"lift %.2f", offset]];
}
@end

@interface IDHIDFakeRecord : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSMutableArray<IDHIDFakePath *> *paths;
- (instancetype)initWithName:(NSString *)name;
- (void)addPointerEventPath:(IDHIDFakePath *)path;
- (BOOL)synthesizeWithError:(NSError **)error;
@end

@implementation IDHIDFakeRecord
- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self == nil) return nil;
    _name = [name copy];
    _paths = [NSMutableArray array];
    return self;
}
- (void)addPointerEventPath:(IDHIDFakePath *)path { [self.paths addObject:path]; }
- (BOOL)synthesizeWithError:(NSError **)error { return YES; }
@end

@interface IDHIDWrongPointABIPath : NSObject
- (instancetype)initForTouchAtPoint:(CGSize)point offset:(NSTimeInterval)offset;
- (void)moveToPoint:(CGSize)point atOffset:(NSTimeInterval)offset;
- (void)liftUpAtOffset:(NSTimeInterval)offset;
@end

@implementation IDHIDWrongPointABIPath
- (instancetype)initForTouchAtPoint:(CGSize)point offset:(NSTimeInterval)offset {
    return [super init];
}
- (void)moveToPoint:(CGSize)point atOffset:(NSTimeInterval)offset {}
- (void)liftUpAtOffset:(NSTimeInterval)offset {}
@end

@interface IDHIDFailureCapturingTestCase : XCTestCase
@property(nonatomic, strong) NSMutableArray<XCTIssue *> *capturedIssues;
@end

@implementation IDHIDFailureCapturingTestCase
- (instancetype)initWithInvocation:(NSInvocation *)invocation {
    self = [super initWithInvocation:invocation];
    if (self != nil) _capturedIssues = [NSMutableArray array];
    return self;
}
- (void)recordIssue:(XCTIssue *)issue { [self.capturedIssues addObject:issue]; }
@end

@interface IDBlockTouchSelectionUITests : XCTestCase
@end

@implementation IDBlockTouchSelectionUITests

- (NSString *)touchLTRText {
    return [@[
        @"First wrapped paragraph contains constellation and punctuation for precise taps.",
        @"Second wrapped paragraph provides selection handles across independent blocks.",
        @"Third wrapped paragraph keeps the viewport tall enough for controlled scrolling.",
    ] componentsJoinedByString:@"\n"];
}

- (NSString *)textForTouchScenario:(NSString *)scenario {
    if ([scenario isEqualToString:@"touch-boundary"]) {
        return @"Boundary alpha omega\nBoundary beta gamma";
    }
    if ([scenario isEqualToString:@"touch-bidi"]) {
        return @"English prefix\nאבגדה mixed suffix";
    }
    if ([scenario isEqualToString:@"touch-autoscroll"]) {
        NSMutableArray<NSString *> *lines = [[[self touchLTRText]
            componentsSeparatedByString:@"\n"] mutableCopy];
        for (NSUInteger index = 0; index < 30; index += 1) {
            [lines addObject:[NSString stringWithFormat:
                @"Autoscroll block %02lu carries enough words to wrap.",
                (unsigned long)index]];
        }
        return [lines componentsJoinedByString:@"\n"];
    }
    return [self touchLTRText];
}

- (UITextView *)stockOracleForEditor:(XCUIElement *)editor {
    UITextView *stock = [[UITextView alloc]
        initWithFrame:(CGRect){CGPointZero, editor.frame.size}];
    stock.font = [UIFont systemFontOfSize:20.0];
    stock.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [self touchLTRText];
    [stock layoutIfNeeded];
    return stock;
}

- (UITextView *)stockOracleForEditor:(XCUIElement *)editor scenario:(NSString *)scenario {
    UITextView *stock = [self stockOracleForEditor:editor];
    stock.text = [self textForTouchScenario:scenario];
    [stock layoutIfNeeded];
    return stock;
}

- (NSUInteger)offsetForPosition:(UITextPosition *)position inStock:(UITextView *)stock {
    NSInteger offset = [stock offsetFromPosition:stock.beginningOfDocument
                                      toPosition:position];
    XCTAssertGreaterThanOrEqual(offset, 0);
    return (NSUInteger)MAX(offset, 0);
}

- (NSRange)canonicalRange:(UITextRange *)range inStock:(UITextView *)stock {
    XCTAssertNotNil(range);
    NSUInteger location = [self offsetForPosition:range.start inStock:stock];
    NSInteger length = [stock offsetFromPosition:range.start toPosition:range.end];
    XCTAssertGreaterThanOrEqual(length, 0);
    return NSMakeRange(location, (NSUInteger)MAX(length, 0));
}

- (CGPoint)pointInsideCharacterAtOffset:(NSUInteger)offset inStock:(UITextView *)stock {
    UITextPosition *start = [stock positionFromPosition:stock.beginningOfDocument
                                                 offset:(NSInteger)offset];
    UITextPosition *end = [stock positionFromPosition:start offset:1];
    XCTAssertNotNil(start);
    XCTAssertNotNil(end);
    CGRect startCaret = [stock caretRectForPosition:start];
    CGRect endCaret = [stock caretRectForPosition:end];
    CGPoint point = CGPointMake((CGRectGetMidX(startCaret) + CGRectGetMidX(endCaret)) * 0.5,
                                CGRectGetMidY(startCaret));
    XCTAssertTrue(isfinite(point.x));
    XCTAssertTrue(isfinite(point.y));
    return point;
}

- (XCUICoordinate *)coordinateForLocalPoint:(CGPoint)point editor:(XCUIElement *)editor {
    CGRect frame = editor.frame;
    XCTAssertGreaterThan(CGRectGetWidth(frame), 0.0);
    XCTAssertGreaterThan(CGRectGetHeight(frame), 0.0);
    CGVector normalized = CGVectorMake(point.x / CGRectGetWidth(frame),
                                       point.y / CGRectGetHeight(frame));
    XCTAssertGreaterThanOrEqual(normalized.dx, 0.0);
    XCTAssertLessThanOrEqual(normalized.dx, 1.0);
    XCTAssertGreaterThanOrEqual(normalized.dy, 0.0);
    XCTAssertLessThanOrEqual(normalized.dy, 1.0);
    return [editor coordinateWithNormalizedOffset:normalized];
}

- (CGRect)screenCaretRectForStatus:(IDTouchSelectionStatus)status
                            editor:(XCUIElement *)editor
                textContainerInset:(UIEdgeInsets)textContainerInset {
    return CGRectOffset(
        status.caret,
        CGRectGetMinX(editor.frame) - status.contentOffset.x + textContainerInset.left,
        CGRectGetMinY(editor.frame) - status.contentOffset.y + textContainerInset.top);
}

- (IDTouchSelectionStatus)statusFromElement:(XCUIElement *)statusElement
                             selectionRects:(NSArray<NSDictionary<NSString *, id> *> **)rects {
    IDTouchSelectionStatus status = {0};
    XCTAssertTrue(IDTouchSelectionParseStatus(statusElement.value, &status, rects),
                  @"%@", statusElement.value);
    return status;
}

- (IDTouchSelectionStatus)waitForStatusElement:(XCUIElement *)statusElement
                                 selectionRange:(NSRange)range
                                 selectionRects:(NSArray<NSDictionary<NSString *, id> *> **)rects {
    NSPredicate *matches = [NSPredicate predicateWithBlock:
        ^BOOL(XCUIElement *element, NSDictionary *bindings) {
            IDTouchSelectionStatus status = {0};
            return IDTouchSelectionParseStatus(element.value, &status, NULL) &&
                NSEqualRanges(status.selection, range);
        }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:matches object:statusElement];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:4.0],
                   XCTWaiterResultCompleted,
                   @"Expected %@, current=%@", NSStringFromRange(range), statusElement.value);
    return [self statusFromElement:statusElement selectionRects:rects];
}

- (IDTouchSelectionStatus)waitForCollapsedPhysicalTapStatus:(XCUIElement *)statusElement {
    NSPredicate *matches = [NSPredicate predicateWithBlock:
        ^BOOL(XCUIElement *element, NSDictionary *bindings) {
            IDTouchSelectionStatus status = {0};
            return IDTouchSelectionParseStatus(element.value, &status, NULL) &&
                status.selection.location > 0 && status.selection.length == 0;
        }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:matches object:statusElement];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:4.0],
                   XCTWaiterResultCompleted,
                   @"Expected a nonzero collapsed physical-tap selection, current=%@",
                   statusElement.value);
    return [self statusFromElement:statusElement selectionRects:NULL];
}

- (IDTouchSelectionStatus)waitForCollapsedPhysicalTapStatus:(XCUIElement *)statusElement
                                         differentFromRange:(NSRange)priorRange {
    NSPredicate *matches = [NSPredicate predicateWithBlock:
        ^BOOL(XCUIElement *element, NSDictionary *bindings) {
            IDTouchSelectionStatus status = {0};
            return IDTouchSelectionParseStatus(element.value, &status, NULL) &&
                status.selection.location > 0 && status.selection.length == 0 &&
                !NSEqualRanges(status.selection, priorRange);
        }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:matches object:statusElement];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:4.0],
                   XCTWaiterResultCompleted,
                   @"Expected target tap to change %@, current=%@",
                   NSStringFromRange(priorRange), statusElement.value);
    return [self statusFromElement:statusElement selectionRects:NULL];
}

- (IDTouchSelectionStatus)waitForNonemptySelectionStatus:(XCUIElement *)statusElement
                                           selectionRects:(NSArray<NSDictionary<NSString *, id> *> **)rects {
    NSPredicate *matches = [NSPredicate predicateWithBlock:
        ^BOOL(XCUIElement *element, NSDictionary *bindings) {
            IDTouchSelectionStatus status = {0};
            return IDTouchSelectionParseStatus(element.value, &status, NULL) &&
                status.selection.length > 0;
        }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:matches object:statusElement];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:4.0],
                   XCTWaiterResultCompleted,
                   @"Expected a nonempty selection, current=%@", statusElement.value);
    return [self statusFromElement:statusElement selectionRects:rects];
}

- (IDTouchSelectionStatus)waitForStableContentOffsetInStatusElement:
    (XCUIElement *)statusElement {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
    IDTouchSelectionStatus latest = {0};
    CGFloat priorY = NAN;
    NSUInteger stableSamples = 0;
    while (deadline.timeIntervalSinceNow > 0.0) {
        IDTouchSelectionStatus candidate = {0};
        if (IDTouchSelectionParseStatus(statusElement.value, &candidate, NULL)) {
            latest = candidate;
            if (isfinite(priorY) && fabs(candidate.contentOffset.y - priorY) <= 0.01) {
                stableSamples += 1;
                if (stableSamples >= 3) return candidate;
            } else {
                stableSamples = 0;
            }
            priorY = candidate.contentOffset.y;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    XCTFail(@"Content offset did not settle, status=%@", statusElement.value);
    return latest;
}

- (void)waitForHalfSecondQuiescence {
    XCTestExpectation *expectation =
        [[XCTestExpectation alloc] initWithDescription:@"edge autoscroll quiescence"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:1.5],
                   XCTWaiterResultCompleted);
}

- (NSValue *)valueForTouchSelectionStatus:(IDTouchSelectionStatus)status {
    return [NSValue valueWithBytes:&status objCType:@encode(IDTouchSelectionStatus)];
}

- (IDTouchSelectionStatus)touchSelectionStatusFromValue:(NSValue *)value {
    IDTouchSelectionStatus status = {0};
    [value getValue:&status size:sizeof(status)];
    return status;
}

- (CGFloat)activeHandleEdgeDistanceFromStatusValue:(id)value
                                      logicalStart:(BOOL)start {
    NSString *string = [value isKindOfClass:NSString.class] ? value : nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *status = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *selectionRects = [status[@"selectionRects"] isKindOfClass:NSArray.class]
        ? status[@"selectionRects"] : @[];
    NSDictionary *endpointRect = nil;
    NSString *roleKey = start ? @"containsStart" : @"containsEnd";
    for (NSDictionary *rect in selectionRects) {
        if ([rect[roleKey] boolValue]) { endpointRect = rect; break; }
    }
    if (endpointRect == nil) return CGFLOAT_MAX;
    BOOL rtl = [endpointRect[@"direction"] integerValue] == NSWritingDirectionRightToLeft;
    CGFloat minX = [endpointRect[@"x"] doubleValue];
    CGFloat maxX = minX + [endpointRect[@"width"] doubleValue];
    CGPoint endpoint = CGPointMake(start == rtl ? maxX : minX,
        [endpointRect[@"y"] doubleValue] +
            (start ? 0.0 : [endpointRect[@"height"] doubleValue]));
    NSArray *handles = [status[@"visibleHandles"] isKindOfClass:NSArray.class]
        ? status[@"visibleHandles"] : @[];
    CGRect activeHandle = CGRectNull;
    CGFloat nearest = CGFLOAT_MAX;
    for (NSDictionary *handle in handles) {
        CGRect rect = CGRectMake([handle[@"x"] doubleValue], [handle[@"y"] doubleValue],
                                 [handle[@"width"] doubleValue],
                                 [handle[@"height"] doubleValue]);
        CGFloat distance = [self distanceFromPoint:endpoint toRect:rect];
        if (distance < nearest) { nearest = distance; activeHandle = rect; }
    }
    if (CGRectIsNull(activeHandle) || nearest > 12.0) return CGFLOAT_MAX;
    NSDictionary *visibleValue = status[@"visible"];
    CGRect visible = CGRectMake([visibleValue[@"x"] doubleValue],
                                [visibleValue[@"y"] doubleValue],
                                [visibleValue[@"width"] doubleValue],
                                [visibleValue[@"height"] doubleValue]);
    CGRect clipped = CGRectIntersection(activeHandle, visible);
    if (CGRectIsNull(clipped) || CGRectIsEmpty(clipped)) return CGFLOAT_MAX;
    return start ? CGRectGetMinY(clipped) - CGRectGetMinY(visible)
                 : CGRectGetMaxY(visible) - CGRectGetMaxY(clipped);
}

- (IDEdgeHoldWindow)holdWindowStartingAt:(CFTimeInterval)epoch
                             holdDuration:(NSTimeInterval)holdDuration {
    CFTimeInterval endpointArrival = epoch + IDEdgePressDuration + IDEdgeDragDuration;
    CFTimeInterval release = endpointArrival + holdDuration;
    return (IDEdgeHoldWindow){endpointArrival + IDEdgeHoldSafetyMargin,
                              release - IDEdgeHoldSafetyMargin,
                              release + 0.05};
}

- (void)observeStatusElement:(XCUIElement *)statusElement
                      initial:(IDTouchSelectionStatus)initial
                       bottom:(BOOL)bottom
                 logicalStart:(BOOL)logicalStart
                       window:(IDEdgeHoldWindow)window
                  observation:(IDEdgeHoldObservation *)observation {
    observation.samples = [NSMutableArray array];
    observation.traceSamples = [NSMutableArray array];
    observation.activeHandleEdgeDistance = CGFLOAT_MAX;
    BOOL movementBegan = NO;
    while (CACurrentMediaTime() < window.end) {
        if (CACurrentMediaTime() < window.start) {
            [NSThread sleepForTimeInterval:0.02];
            continue;
        }
        IDTouchSelectionStatus candidate = {0};
        id rawValue = statusElement.value;
        CFTimeInterval completed = CACurrentMediaTime();
        if (completed >= window.end) break;
        if (!IDTouchSelectionParseStatus(rawValue, &candidate, NULL)) {
            observation.parseFailures += 1;
        } else {
            BOOL moved = bottom
                ? candidate.contentOffset.y > initial.contentOffset.y + 0.01
                : candidate.contentOffset.y < initial.contentOffset.y - 0.01;
            movementBegan = movementBegan || moved;
            if (movementBegan) {
                [observation.samples addObject:[self valueForTouchSelectionStatus:candidate]];
                NSData *rawData = [rawValue
                    dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *rawStatus = rawData == nil
                    ? nil
                    : [NSJSONSerialization
                        JSONObjectWithData:rawData
                                  options:0
                                    error:nil];
                NSDictionary *autoscroll =
                    [rawStatus[@"autoscroll"]
                        isKindOfClass:NSDictionary.class]
                        ? rawStatus[@"autoscroll"]
                        : @{};
                CFTimeInterval firstTimestamp =
                    [observation.traceSamples.firstObject[
                        @"absoluteTimestamp"] doubleValue];
                if (observation.traceSamples.count == 0) {
                    firstTimestamp = completed;
                }
                [observation.traceSamples addObject:@{
                    @"absoluteTimestamp": @(completed),
                    @"relativeTimestamp":
                        @(completed - firstTimestamp),
                    @"backend":
                        rawStatus[@"backend"] ?: @"stock",
                    @"direction":
                        autoscroll[@"direction"] ?:
                            @(bottom
                                ? IDVerticalAutoscrollDirectionDown
                                : IDVerticalAutoscrollDirectionUp),
                    @"tickCount":
                        autoscroll[@"tickCount"] ?:
                            @(observation.traceSamples.count + 1),
                    @"contentOffsetY":
                        @(candidate.contentOffset.y),
                    @"canonicalSelectionLocation":
                        @(candidate.selection.location),
                    @"canonicalSelectionLength":
                        @(candidate.selection.length),
                    @"selectionContainerIdentity":
                        rawStatus[@"selectionContainerIdentity"] ?:
                            @"stable",
                    @"active": autoscroll[@"active"] ?: @YES,
                }];
                CGFloat distance = [self activeHandleEdgeDistanceFromStatusValue:rawValue
                                                                     logicalStart:logicalStart];
                if (distance < observation.activeHandleEdgeDistance) {
                    observation.activeHandleEdgeDistance = distance;
                    observation.activeHandleStatus = [rawValue copy];
                }
                if (distance <= 12.0 && completed < window.end) {
                    observation.preLiftEdgeMarker = YES;
                    observation.markerTime = completed;
                    if (observation.heldScreenshot == nil) {
                        XCUIScreenshot *screenshot = XCUIScreen.mainScreen.screenshot;
                        CFTimeInterval screenshotTime = CACurrentMediaTime();
                        if (screenshotTime < window.end) {
                            observation.heldScreenshot = screenshot;
                            observation.screenshotTime = screenshotTime;
                        }
                    }
                }
            }
        }
        [NSThread sleepForTimeInterval:0.05];
    }
}

- (void)attachNormalizedAutoscrollTrace:
    (IDEdgeHoldObservation *)observation
                                      name:(NSString *)name {
    NSMutableArray *normalized = [NSMutableArray array];
    for (NSDictionary *sample in observation.traceSamples) {
        NSMutableDictionary *row = [sample mutableCopy];
        [row removeObjectForKey:@"absoluteTimestamp"];
        [normalized addObject:row.copy];
    }
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:normalized
                   options:NSJSONWritingPrettyPrinted |
                           NSJSONWritingSortedKeys
                     error:nil];
    NSString *text = data == nil
        ? @"[]"
        : [[NSString alloc] initWithData:data
                                encoding:NSUTF8StringEncoding];
    XCTAttachment *attachment =
        [XCTAttachment attachmentWithString:text];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)waitForTapSequenceQuiescence {
    XCTestExpectation *expectation =
        [[XCTestExpectation alloc] initWithDescription:@"tap sequence quiescence"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(IDTapSequenceQuiescenceInterval * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation]
                                          timeout:IDTapSequenceQuiescenceInterval + 1.0],
                   XCTWaiterResultCompleted);
}

- (IDHIDTouchPath *)edgeTouchPathFromScreenPoint:(CGPoint)start
                                    toScreenPoint:(CGPoint)end
                                     holdDuration:(NSTimeInterval)holdDuration {
    NSMutableArray<IDHIDTouchWaypoint *> *waypoints = [NSMutableArray array];
    [waypoints addObject:[IDHIDTouchWaypoint moveTo:start offset:IDEdgePressDuration]];
    const NSUInteger waypointCount = 16;
    for (NSUInteger index = 1; index <= waypointCount; index += 1) {
        CGFloat progress = (CGFloat)index / (CGFloat)waypointCount;
        CGPoint point = CGPointMake(start.x + (end.x - start.x) * progress,
                                    start.y + (end.y - start.y) * progress);
        [waypoints addObject:[IDHIDTouchWaypoint moveTo:point
                                                  offset:IDEdgePressDuration +
                                                         IDEdgeDragDuration * progress]];
    }
    NSTimeInterval releaseOffset = IDEdgePressDuration + IDEdgeDragDuration + holdDuration;
    [waypoints addObject:[IDHIDTouchWaypoint moveTo:end offset:releaseOffset]];
    [waypoints addObject:[IDHIDTouchWaypoint liftAtOffset:releaseOffset + 0.05]];
    return [[IDHIDTouchPath alloc] initWithStartScreenPoint:start
                                                startOffset:0.0
                                                  waypoints:waypoints];
}

- (void)attachScreenshot:(XCUIScreenshot *)screenshot name:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)attachEdgeSamples:(IDEdgeHoldObservation *)observation
                  initial:(IDTouchSelectionStatus)initial
                     name:(NSString *)name {
    NSMutableString *text = [NSMutableString stringWithFormat:
        @"initial offset=%@ selection=%@ fixedStart=%lu fixedEnd=%lu visible=%@\n",
        NSStringFromCGPoint(initial.contentOffset), NSStringFromRange(initial.selection),
        (unsigned long)initial.selection.location,
        (unsigned long)NSMaxRange(initial.selection), NSStringFromCGRect(initial.visible)];
    NSUInteger index = 0;
    for (NSValue *sampleValue in observation.samples) {
        IDTouchSelectionStatus sample = [self touchSelectionStatusFromValue:sampleValue];
        [text appendFormat:@"sample[%lu] offset=%@ selection=%@ visible=%@\n",
            (unsigned long)index, NSStringFromCGPoint(sample.contentOffset),
            NSStringFromRange(sample.selection), NSStringFromCGRect(sample.visible)];
        index += 1;
    }
    [text appendFormat:@"activeHandleStatus=%@\n",
        observation.activeHandleStatus ?: @"<unavailable>"];
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:text];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (NSDictionary<NSString *, id> *)selectionRectForLogicalStart:(BOOL)start
                                                           rects:(NSArray<NSDictionary<NSString *, id> *> *)rects {
    NSString *key = start ? @"containsStart" : @"containsEnd";
    for (NSDictionary<NSString *, id> *rect in rects) {
        if ([rect[key] boolValue]) return rect;
    }
    return nil;
}

- (CGFloat)distanceFromPoint:(CGPoint)point toRect:(CGRect)rect {
    CGFloat dx = MAX(MAX(CGRectGetMinX(rect) - point.x, 0.0),
                     point.x - CGRectGetMaxX(rect));
    CGFloat dy = MAX(MAX(CGRectGetMinY(rect) - point.y, 0.0),
                     point.y - CGRectGetMaxY(rect));
    return hypot(dx, dy);
}

- (CGRect)matchedHandleForLogicalStart:(BOOL)start
                                 rects:(NSArray<NSDictionary<NSString *, id> *> *)rects
                                status:(IDTouchSelectionStatus)status
                                editor:(XCUIElement *)editor
                            screenshot:(XCUIScreenshot *)screenshot {
    NSArray<NSValue *> *components = IDTouchSelectionHandleComponents(screenshot, editor.frame);
    XCTAssertGreaterThanOrEqual(components.count, 2U,
                                @"Filtered blue components=%@", components);
    if (components.count < 2) return CGRectNull;
    CGRect matched = IDTouchSelectionMatchedHandle(
        start, rects, status, editor.frame, screenshot, 8.0);
    XCTAssertFalse(CGRectIsNull(matched), @"role=%@ components=%@",
                   start ? @"start" : @"end", components);
    return matched;
}

- (CGPoint)screenGrabPointForHandle:(CGRect)handle logicalStart:(BOOL)start {
    CGFloat radius = CGRectGetWidth(handle) * 0.5;
    return CGPointMake(CGRectGetMidX(handle),
                       start ? CGRectGetMinY(handle) + radius
                             : CGRectGetMaxY(handle) - radius);
}

- (void)attachHandleEvidenceScreenshot:(XCUIScreenshot *)screenshot
                             components:(NSArray<NSValue *> *)components
                                   name:(NSString *)name {
    [self attachScreenshot:screenshot name:name];
    XCTAttachment *bounds = [XCTAttachment attachmentWithString:components.description];
    bounds.name = [name stringByAppendingString:@"-component-bounds"];
    bounds.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:bounds];
}

- (CGRect)loupeSearchRectAboveCoordinate:(XCUICoordinate *)coordinate
                               screenshot:(XCUIScreenshot *)screenshot {
    CGPoint point = coordinate.screenPoint;
    CGRect screen = (CGRect){CGPointZero, screenshot.image.size};
    CGRect search = CGRectMake(point.x - 100.0, point.y - 200.0, 200.0, 200.0);
    return CGRectIntersection(screen, search);
}

- (void)assertLoupeRegion:(CGRect)region {
    XCTAssertTrue(IDTouchSelectionIsLoupeSizedRegion(region),
                  @"Expected a visible loupe-sized changed component above the held touch: %@",
                  NSStringFromCGRect(region));
    CGFloat width = CGRectGetWidth(region);
    CGFloat height = CGRectGetHeight(region);
    XCTAssertGreaterThanOrEqual(width, 36.0);
    XCTAssertLessThanOrEqual(width, 180.0);
    XCTAssertGreaterThanOrEqual(height, 36.0);
    XCTAssertLessThanOrEqual(height, 180.0);
    CGFloat aspect = height > 0.0 ? width / height : INFINITY;
    XCTAssertGreaterThanOrEqual(aspect, 0.65);
    XCTAssertLessThanOrEqual(aspect, 1.55);
}

- (void)assertFiniteGeometryForStatus:(IDTouchSelectionStatus)status
                       selectionRects:(NSArray<NSDictionary<NSString *, id> *> *)rects {
    if (status.selection.length == 0) {
        XCTAssertTrue(isfinite(status.caret.origin.x));
        XCTAssertTrue(isfinite(status.caret.origin.y));
        XCTAssertTrue(isfinite(status.caret.size.width));
        XCTAssertTrue(isfinite(status.caret.size.height));
        XCTAssertGreaterThan(status.caret.size.height, 0.0);
        return;
    }
    XCTAssertGreaterThan(rects.count, 0U);
    for (NSDictionary<NSString *, id> *rect in rects) {
        XCTAssertTrue(isfinite([rect[@"x"] doubleValue]));
        XCTAssertTrue(isfinite([rect[@"y"] doubleValue]));
        XCTAssertTrue(isfinite([rect[@"width"] doubleValue]));
        XCTAssertTrue(isfinite([rect[@"height"] doubleValue]));
    }
}

- (XCUIApplication *)launchTouchScenario:(NSString *)scenario {
    return [self launchTouchScenario:scenario minimal:NO];
}

- (XCUIApplication *)launchTouchScenario:(NSString *)scenario
                                 minimal:(BOOL)minimal {
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    NSMutableArray<NSString *> *arguments = [@[
        @"-AppleLanguages", @"(en)",
        @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", scenario,
    ] mutableCopy];
    if (minimal) {
        [arguments addObjectsFromArray:@[
            @"-InputDecBehaviorBackend", @"minimal",
        ]];
    }
    application.launchArguments = arguments;
    [application launch];
    return application;
}

- (XCUIApplication *)launchDefaultApplication {
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)",
        @"-AppleLocale", @"en_US",
    ];
    [application launch];
    return application;
}

- (XCUIApplication *)launchStockApplicationForFrame:(CGRect)frame
                                               editor:(XCUIElement * __strong *)editorResult
                                               status:(XCUIElement * __strong *)statusResult {
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[@"-AppleLanguages", @"(en)",
                                    @"-AppleLocale", @"en_US"];
    application.launchEnvironment = @{
        @"IDStockEditorFrame": NSStringFromCGRect(frame),
    };
    [application launch];
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue(CGRectEqualToRect(editor.frame, frame),
                  @"stock=%@ custom=%@",
                  NSStringFromCGRect(editor.frame), NSStringFromCGRect(frame));
    *editorResult = editor;
    *statusResult = status;
    return application;
}

- (XCUIApplication *)launchStockApplicationForFrame:(CGRect)frame
                                             scenario:(NSString *)scenario
                                               editor:(XCUIElement * __strong *)editorResult
                                               status:(XCUIElement * __strong *)statusResult {
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[@"-AppleLanguages", @"(en)",
                                    @"-AppleLocale", @"en_US"];
    application.launchEnvironment = @{
        @"IDStockEditorFrame": NSStringFromCGRect(frame),
        @"IDStockTouchScenario": scenario,
    };
    [application launch];
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue(CGRectEqualToRect(editor.frame, frame));
    *editorResult = editor;
    *statusResult = status;
    return application;
}

- (NSRange)dragTrailingHandleInEditor:(XCUIElement *)editor
                               status:(XCUIElement *)statusElement
                             scenario:(NSString *)scenario
                        selectionWord:(NSString *)selectionWord
                         targetOffset:(NSUInteger)targetOffset
                       attachmentName:(NSString *)attachmentName {
    UITextView *geometry = [self stockOracleForEditor:editor scenario:scenario];
    NSRange word = [geometry.text rangeOfString:selectionWord];
    XCTAssertNotEqual(word.location, NSNotFound);
    CGPoint selectionPoint = [self pointInsideCharacterAtOffset:word.location + 1
                                                        inStock:geometry];
    UITextPosition *probe = [geometry positionFromPosition:geometry.beginningOfDocument
                                                    offset:(NSInteger)word.location + 1];
    UITextRange *token = [geometry.tokenizer rangeEnclosingPosition:probe
                                                    withGranularity:UITextGranularityWord
                                                        inDirection:UITextStorageDirectionForward];
    NSRange initialExpected = [self canonicalRange:token inStock:geometry];
    [[self coordinateForLocalPoint:selectionPoint editor:editor] doubleTap];
    NSArray<NSDictionary<NSString *, id> *> *rects = nil;
    IDTouchSelectionStatus initial = [self waitForStatusElement:statusElement
                                                 selectionRange:initialExpected
                                                 selectionRects:&rects];
    XCTAssertEqual(initial.containerCreations, 1U);
    XCTAssertTrue(initial.containerStable);
    [NSThread sleepForTimeInterval:0.3];
    XCUIScreenshot *screenshot = XCUIScreen.mainScreen.screenshot;
    NSArray<NSValue *> *components = IDTouchSelectionHandleComponents(screenshot, editor.frame);
    [self attachHandleEvidenceScreenshot:screenshot components:components name:attachmentName];
    CGRect leading = [self matchedHandleForLogicalStart:YES rects:rects status:initial
                                                 editor:editor screenshot:screenshot];
    CGRect trailing = [self matchedHandleForLogicalStart:NO rects:rects status:initial
                                                  editor:editor screenshot:screenshot];
    XCTAssertFalse(CGRectIsNull(leading));
    XCTAssertFalse(CGRectIsNull(trailing));
    XCTAssertFalse(CGRectEqualToRect(leading, trailing));
    if ([scenario isEqualToString:@"touch-bidi"]) {
        NSDictionary *startRect = [self selectionRectForLogicalStart:YES rects:rects];
        NSDictionary *endRect = [self selectionRectForLogicalStart:NO rects:rects];
        BOOL startRTL = [startRect[@"direction"] integerValue] ==
            NSWritingDirectionRightToLeft;
        BOOL endRTL = [endRect[@"direction"] integerValue] ==
            NSWritingDirectionRightToLeft;
        CGFloat startX = [startRect[@"x"] doubleValue] +
            (startRTL ? [startRect[@"width"] doubleValue] : 0.0);
        CGFloat endX = [endRect[@"x"] doubleValue] +
            (endRTL ? 0.0 : [endRect[@"width"] doubleValue]);
        XCTAssertGreaterThan(startX, endX,
                             @"Logical start/end must remain visually reversed in the RTL run");
    }
    CGPoint targetPoint = [self pointInsideCharacterAtOffset:targetOffset inStock:geometry];
    if ([scenario isEqualToString:@"touch-boundary"]) {
        targetPoint.x = CGRectGetWidth(geometry.bounds) - 24.0;
        targetPoint.y += CGRectGetHeight([geometry caretRectForPosition:
            [geometry positionFromPosition:geometry.beginningOfDocument
                                    offset:(NSInteger)targetOffset]]) * 2.0;
    }
    UITextPosition *tokenStart = [geometry positionFromPosition:geometry.beginningOfDocument
                                                         offset:(NSInteger)initialExpected.location];
    UITextPosition *tokenEnd = [geometry positionFromPosition:tokenStart
                                                       offset:(NSInteger)initialExpected.length];
    UITextRange *geometryRange = [geometry textRangeFromPosition:tokenStart toPosition:tokenEnd];
    UITextSelectionRect *geometryEndRect = nil;
    for (UITextSelectionRect *candidate in [geometry selectionRectsForRange:geometryRange]) {
        if (candidate.containsEnd) geometryEndRect = candidate;
    }
    XCTAssertNotNil(geometryEndRect);
    if (geometryEndRect != nil) {
        BOOL stockRTL = geometryEndRect.writingDirection == NSWritingDirectionRightToLeft;
        CGPoint stockEndpoint = CGPointMake(stockRTL ? CGRectGetMinX(geometryEndRect.rect)
                                                     : CGRectGetMaxX(geometryEndRect.rect),
                                            CGRectGetMaxY(geometryEndRect.rect));
        CGPoint heldPoint = CGPointMake(CGRectGetMidX(trailing) - CGRectGetMinX(editor.frame),
                                        CGRectGetMidY(trailing) - CGRectGetMinY(editor.frame));
        targetPoint.x += heldPoint.x - stockEndpoint.x;
        targetPoint.y += heldPoint.y - stockEndpoint.y;
    }
    CGPoint screenHandlePoint = [self screenGrabPointForHandle:trailing logicalStart:NO];
    CGPoint handlePoint = CGPointMake(screenHandlePoint.x - CGRectGetMinX(editor.frame),
                                      screenHandlePoint.y - CGRectGetMinY(editor.frame));
    XCUICoordinate *handle = [[editor coordinateWithNormalizedOffset:CGVectorMake(0, 0)]
        coordinateWithOffset:CGVectorMake(handlePoint.x, handlePoint.y)];
    XCUICoordinate *target = [self coordinateForLocalPoint:targetPoint editor:editor];
    [handle pressForDuration:0.1
       thenDragToCoordinate:target
                withVelocity:XCUIGestureVelocitySlow
         thenHoldForDuration:0.3];
    [NSThread sleepForTimeInterval:0.5];
    NSArray<NSDictionary<NSString *, id> *> *finalRects = nil;
    IDTouchSelectionStatus final = [self statusFromElement:statusElement
                                            selectionRects:&finalRects];
    XCTAssertGreaterThan(final.selection.length, 0U);
    XCTAssertFalse(NSEqualRanges(final.selection, initial.selection));
    XCTAssertEqual(final.selection.location, initial.selection.location,
                   @"Dragging the logical end must not move the logical start");
    XCTAssertEqual(final.containerCreations, 1U);
    XCTAssertTrue(final.containerStable);
    return final.selection;
}

- (NSString *)statusJSONWithBlockCount:(NSString *)blockCount {
    return [NSString stringWithFormat:
        @"{\"blockCount\":%@,\"canonical\":\"fixture\","
         "\"caret\":{\"height\":0,\"width\":0,\"x\":0,\"y\":0},"
         "\"containerCreations\":1,\"containerStable\":true,"
         "\"contentOffset\":{\"x\":0,\"y\":0},\"presentationUpdates\":0,"
         "\"scenario\":\"parser-boundary\","
         "\"selection\":{\"length\":0,\"location\":0},"
         "\"selectionRects\":[],\"state\":\"idle\","
         "\"visible\":{\"height\":1,\"width\":1,\"x\":0,\"y\":0}}",
        blockCount];
}

- (void)testTouchLTRScenarioExposesExactStatusSchema {
    XCUIApplication *app = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *editor =
        [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *status =
        [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);

    IDTouchSelectionStatus parsed = {0};
    NSArray *rects = nil;
    XCTAssertTrue(IDTouchSelectionParseStatus(status.value, &parsed, &rects),
                  @"%@", status.value);
    XCTAssertEqual(parsed.blockCount, 3U);
    XCTAssertEqual(parsed.selection.length, 0U);
    XCTAssertTrue(parsed.containerStable);
}

- (void)testSingleTapMatchesStockDerivedCanonicalOffset {
    XCUIApplication *app = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *editor =
        [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *statusElement =
        [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);
    IDTouchSelectionStatus before = [self statusFromElement:statusElement selectionRects:NULL];

    UITextView *stock = [self stockOracleForEditor:editor];
    NSRange word = [stock.text rangeOfString:@"constellation"];
    XCTAssertNotEqual(word.location, NSNotFound);
    CGPoint point = [self pointInsideCharacterAtOffset:word.location + 2 inStock:stock];
    [editor tap];
    IDTouchSelectionStatus customFocus =
        [self waitForCollapsedPhysicalTapStatus:statusElement];
    [self waitForTapSequenceQuiescence];
    [[self coordinateForLocalPoint:point editor:editor] tap];
    IDTouchSelectionStatus customAfter =
        [self waitForCollapsedPhysicalTapStatus:statusElement
                             differentFromRange:customFocus.selection];
    XCTAssertEqual(customAfter.containerCreations, before.containerCreations);
    [self assertFiniteGeometryForStatus:customAfter selectionRects:nil];
    CGRect customFrame = editor.frame;
    [app terminate];

    XCUIElement *stockEditor = nil;
    XCUIElement *stockStatus = nil;
    XCUIApplication *stockApp =
        [self launchStockApplicationForFrame:customFrame
                                      editor:&stockEditor
                                      status:&stockStatus];
    stock = [self stockOracleForEditor:stockEditor];
    point = [self pointInsideCharacterAtOffset:word.location + 2 inStock:stock];
    [stockEditor tap];
    IDTouchSelectionStatus stockFocus =
        [self waitForCollapsedPhysicalTapStatus:stockStatus];
    [self waitForTapSequenceQuiescence];
    [[self coordinateForLocalPoint:point editor:stockEditor] tap];
    IDTouchSelectionStatus stockAfter =
        [self waitForCollapsedPhysicalTapStatus:stockStatus
                             differentFromRange:stockFocus.selection];

    XCTAssertTrue(NSEqualRanges(customAfter.selection, stockAfter.selection),
                  @"custom=%@ stock=%@",
                  NSStringFromRange(customAfter.selection),
                  NSStringFromRange(stockAfter.selection));
}

- (void)testSingleTapTimingMutationCharacterizesImmediateAndQuiescedSequences {
    XCUIApplication *customImmediateApp = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *customImmediateEditor =
        [customImmediateApp descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *customImmediateStatus =
        [customImmediateApp descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([customImmediateEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customImmediateStatus waitForExistenceWithTimeout:4.0]);
    CGRect customFrame = customImmediateEditor.frame;
    UITextView *geometryOracle = [self stockOracleForEditor:customImmediateEditor];
    NSRange word = [geometryOracle.text rangeOfString:@"constellation"];
    XCTAssertNotEqual(word.location, NSNotFound);
    CGPoint point = [self pointInsideCharacterAtOffset:word.location + 2
                                               inStock:geometryOracle];
    IDTouchSelectionStatus initial =
        [self statusFromElement:customImmediateStatus selectionRects:NULL];
    [customImmediateEditor tap];
    [[self coordinateForLocalPoint:point editor:customImmediateEditor] tap];
    [self waitForTapSequenceQuiescence];
    IDTouchSelectionStatus customImmediate =
        [self statusFromElement:customImmediateStatus selectionRects:NULL];
    XCTAssertFalse(NSEqualRanges(customImmediate.selection, initial.selection));
    [customImmediateApp terminate];

    XCUIApplication *customQuiescedApp = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *customQuiescedEditor =
        [customQuiescedApp descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *customQuiescedStatus =
        [customQuiescedApp descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([customQuiescedEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customQuiescedStatus waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue(CGRectEqualToRect(customQuiescedEditor.frame, customFrame));
    [customQuiescedEditor tap];
    IDTouchSelectionStatus customFocus =
        [self waitForCollapsedPhysicalTapStatus:customQuiescedStatus];
    [self waitForTapSequenceQuiescence];
    [[self coordinateForLocalPoint:point editor:customQuiescedEditor] tap];
    IDTouchSelectionStatus customQuiesced =
        [self waitForCollapsedPhysicalTapStatus:customQuiescedStatus
                             differentFromRange:customFocus.selection];
    [customQuiescedApp terminate];

    XCUIElement *stockImmediateEditor = nil;
    XCUIElement *stockImmediateStatus = nil;
    XCUIApplication *stockImmediateApp =
        [self launchStockApplicationForFrame:customFrame
                                      editor:&stockImmediateEditor
                                      status:&stockImmediateStatus];
    geometryOracle = [self stockOracleForEditor:stockImmediateEditor];
    point = [self pointInsideCharacterAtOffset:word.location + 2 inStock:geometryOracle];
    initial = [self statusFromElement:stockImmediateStatus selectionRects:NULL];
    [stockImmediateEditor tap];
    [[self coordinateForLocalPoint:point editor:stockImmediateEditor] tap];
    [self waitForTapSequenceQuiescence];
    IDTouchSelectionStatus stockImmediate =
        [self statusFromElement:stockImmediateStatus selectionRects:NULL];
    XCTAssertFalse(NSEqualRanges(stockImmediate.selection, initial.selection));
    [stockImmediateApp terminate];

    XCUIElement *stockQuiescedEditor = nil;
    XCUIElement *stockQuiescedStatus = nil;
    XCUIApplication *stockQuiescedApp =
        [self launchStockApplicationForFrame:customFrame
                                      editor:&stockQuiescedEditor
                                      status:&stockQuiescedStatus];
    geometryOracle = [self stockOracleForEditor:stockQuiescedEditor];
    point = [self pointInsideCharacterAtOffset:word.location + 2 inStock:geometryOracle];
    [stockQuiescedEditor tap];
    IDTouchSelectionStatus stockFocus =
        [self waitForCollapsedPhysicalTapStatus:stockQuiescedStatus];
    [self waitForTapSequenceQuiescence];
    [[self coordinateForLocalPoint:point editor:stockQuiescedEditor] tap];
    IDTouchSelectionStatus stockQuiesced =
        [self waitForCollapsedPhysicalTapStatus:stockQuiescedStatus
                             differentFromRange:stockFocus.selection];

    XCTAssertTrue(NSEqualRanges(customImmediate.selection, stockImmediate.selection),
                  @"immediate custom=%@ stock=%@",
                  NSStringFromRange(customImmediate.selection),
                  NSStringFromRange(stockImmediate.selection));
    XCTAssertTrue(NSEqualRanges(customQuiesced.selection, stockQuiesced.selection),
                  @"quiesced custom=%@ stock=%@",
                  NSStringFromRange(customQuiesced.selection),
                  NSStringFromRange(stockQuiesced.selection));
    XCTAssertEqual(customQuiesced.selection.length, 0U);
    XCTAssertEqual(stockQuiesced.selection.length, 0U);
    NSLog(@"Tap timing mutation immediate custom=%@ stock=%@; "
           "quiesced(%.1fs) custom=%@ stock=%@",
          NSStringFromRange(customImmediate.selection),
          NSStringFromRange(stockImmediate.selection),
          IDTapSequenceQuiescenceInterval,
          NSStringFromRange(customQuiesced.selection),
          NSStringFromRange(stockQuiesced.selection));
}

- (void)testDoubleTapSelectsExactStockWordRange {
    XCUIApplication *app = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *editor = [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *statusElement = [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);
    IDTouchSelectionStatus before = [self statusFromElement:statusElement selectionRects:NULL];

    UITextView *stock = [self stockOracleForEditor:editor];
    NSRange word = [stock.text rangeOfString:@"constellation"];
    XCTAssertNotEqual(word.location, NSNotFound);
    NSUInteger probe = word.location + 2;
    CGPoint point = [self pointInsideCharacterAtOffset:probe inStock:stock];
    UITextPosition *stockPosition = [stock positionFromPosition:stock.beginningOfDocument
                                                        offset:(NSInteger)probe];
    UITextRange *stockRange = [stock.tokenizer
        rangeEnclosingPosition:stockPosition
               withGranularity:UITextGranularityWord
                   inDirection:UITextStorageDirectionForward];
    NSRange expected = [self canonicalRange:stockRange inStock:stock];

    [editor tap];
    [self waitForCollapsedPhysicalTapStatus:statusElement];
    [self waitForTapSequenceQuiescence];
    [[self coordinateForLocalPoint:point editor:editor] doubleTap];
    NSArray *rects = nil;
    IDTouchSelectionStatus after = [self waitForStatusElement:statusElement
                                              selectionRange:expected
                                              selectionRects:&rects];
    XCTAssertEqual(after.containerCreations, before.containerCreations);
    [self assertFiniteGeometryForStatus:after selectionRects:rects];
}

- (void)testDoubleTapShowsBothNativeHandlesAtSelectionEndpoints {
    XCUIApplication *app = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *editor = [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *statusElement = [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);
    IDTouchSelectionStatus before = [self statusFromElement:statusElement selectionRects:NULL];
    UITextView *stock = [self stockOracleForEditor:editor];
    NSRange word = [stock.text rangeOfString:@"constellation"];
    CGPoint point = [self pointInsideCharacterAtOffset:word.location + 2 inStock:stock];
    UITextPosition *position = [stock positionFromPosition:stock.beginningOfDocument
                                                    offset:(NSInteger)word.location + 2];
    UITextRange *wordRange = [stock.tokenizer rangeEnclosingPosition:position
                                                    withGranularity:UITextGranularityWord
                                                        inDirection:UITextStorageDirectionForward];
    NSRange expected = [self canonicalRange:wordRange inStock:stock];

    [editor tap];
    [self waitForCollapsedPhysicalTapStatus:statusElement];
    [self waitForTapSequenceQuiescence];
    [[self coordinateForLocalPoint:point editor:editor] doubleTap];
    NSArray<NSDictionary<NSString *, id> *> *rects = nil;
    IDTouchSelectionStatus selected = [self waitForStatusElement:statusElement
                                                  selectionRange:expected
                                                  selectionRects:&rects];
    [NSThread sleepForTimeInterval:0.3];
    XCUIScreenshot *screenshot = XCUIScreen.mainScreen.screenshot;
    NSArray<NSValue *> *components = IDTouchSelectionHandleComponents(screenshot, editor.frame);
    [self attachHandleEvidenceScreenshot:screenshot components:components name:@"handles-ltr"];
    CGRect start = [self matchedHandleForLogicalStart:YES rects:rects status:selected
                                               editor:editor screenshot:screenshot];
    CGRect end = [self matchedHandleForLogicalStart:NO rects:rects status:selected
                                             editor:editor screenshot:screenshot];
    XCTAssertFalse(CGRectIsNull(start));
    XCTAssertFalse(CGRectIsNull(end));
    XCTAssertFalse(CGRectEqualToRect(start, end));
    XCTAssertEqual(before.containerCreations, 1U);
    XCTAssertTrue(before.containerStable);
    XCTAssertEqual(selected.containerCreations, 1U);
    XCTAssertTrue(selected.containerStable);
}

- (void)testTrailingHandleDragCrossesStructuralBoundaryLikeStock {
    NSString *scenario = @"touch-boundary";
    XCUIApplication *probeApp = [self launchTouchScenario:scenario];
    XCUIElement *probeEditor =
        [probeApp descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCTAssertTrue([probeEditor waitForExistenceWithTimeout:4.0]);
    CGRect frame = probeEditor.frame;
    [probeApp terminate];

    NSString *text = [self textForTouchScenario:scenario];
    NSUInteger targetOffset = text.length - 1;
    XCUIElement *stockEditor = nil;
    XCUIElement *stockStatus = nil;
    XCUIApplication *stockApp = [self launchStockApplicationForFrame:frame
                                                            scenario:scenario
                                                              editor:&stockEditor
                                                              status:&stockStatus];
    NSRange stockRange = [self dragTrailingHandleInEditor:stockEditor
                                                   status:stockStatus
                                                 scenario:scenario
                                            selectionWord:@"omega"
                                             targetOffset:targetOffset
                                           attachmentName:@"handles-boundary-stock"];
    [stockApp terminate];

    XCUIApplication *customApp = [self launchTouchScenario:scenario];
    XCUIElement *customEditor =
        [customApp descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *customStatus =
        [customApp descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    NSRange customRange = [self dragTrailingHandleInEditor:customEditor
                                                    status:customStatus
                                                  scenario:scenario
                                             selectionWord:@"omega"
                                              targetOffset:targetOffset
                                            attachmentName:@"handles-boundary-custom"];
    XCTAssertTrue(NSEqualRanges(customRange, stockRange),
                  @"custom=%@ stock=%@", NSStringFromRange(customRange),
                  NSStringFromRange(stockRange));
    NSUInteger separator = [text rangeOfString:@"\n"].location;
    XCTAssertTrue(NSLocationInRange(separator, customRange),
                  @"separator=%lu custom=%@ stock=%@",
                  (unsigned long)separator, NSStringFromRange(customRange),
                  NSStringFromRange(stockRange));
    XCTAssertEqual([[text substringWithRange:customRange]
        componentsSeparatedByString:@"\n"].count, 2U,
        @"The structural newline must occur exactly once");
}

- (void)testMixedBiDiHandleDragPreservesLogicalEndpointRoles {
    NSString *scenario = @"touch-bidi";
    XCUIApplication *probeApp = [self launchTouchScenario:scenario];
    XCUIElement *probeEditor =
        [probeApp descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCTAssertTrue([probeEditor waitForExistenceWithTimeout:4.0]);
    CGRect frame = probeEditor.frame;
    [probeApp terminate];

    NSString *text = [self textForTouchScenario:scenario];
    NSRange hebrew = [text rangeOfString:@"אבגדה"];
    XCTAssertNotEqual(hebrew.location, NSNotFound);
    NSUInteger targetOffset = hebrew.location + 2;
    XCUIElement *stockEditor = nil;
    XCUIElement *stockStatus = nil;
    XCUIApplication *stockApp = [self launchStockApplicationForFrame:frame
                                                            scenario:scenario
                                                              editor:&stockEditor
                                                              status:&stockStatus];
    NSRange stockRange = [self dragTrailingHandleInEditor:stockEditor
                                                   status:stockStatus
                                                 scenario:scenario
                                            selectionWord:@"אבגדה"
                                             targetOffset:targetOffset
                                           attachmentName:@"handles-bidi-stock"];
    [stockApp terminate];

    XCUIApplication *customApp = [self launchTouchScenario:scenario];
    XCUIElement *customEditor =
        [customApp descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *customStatus =
        [customApp descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    NSRange customRange = [self dragTrailingHandleInEditor:customEditor
                                                    status:customStatus
                                                  scenario:scenario
                                             selectionWord:@"אבגדה"
                                              targetOffset:targetOffset
                                            attachmentName:@"handles-bidi-custom"];
    XCTAssertTrue(NSEqualRanges(customRange, stockRange),
                  @"custom=%@ stock=%@", NSStringFromRange(customRange),
                  NSStringFromRange(stockRange));
}

- (void)testTripleTapSelectsExactStockParagraphRange {
    XCUIApplication *app = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *editor = [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *statusElement = [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);
    IDTouchSelectionStatus before = [self statusFromElement:statusElement selectionRects:NULL];

    UITextView *stock = [self stockOracleForEditor:editor];
    // XCUIElement's private triple-tap primitive activates the element center.
    // Derive the stock paragraph oracle from that exact physical activation point.
    CGPoint point = CGPointMake(CGRectGetWidth(editor.frame) * 0.5,
                                CGRectGetHeight(editor.frame) * 0.5);
    UITextPosition *stockPosition = [stock closestPositionToPoint:point];
    UITextRange *stockRange = [stock.tokenizer
        rangeEnclosingPosition:stockPosition
               withGranularity:UITextGranularityParagraph
                   inDirection:UITextStorageDirectionBackward];
    NSRange expected = [self canonicalRange:stockRange inStock:stock];

    [editor tapWithNumberOfTaps:3 numberOfTouches:1];
    NSArray *rects = nil;
    IDTouchSelectionStatus after = [self waitForStatusElement:statusElement
                                              selectionRange:expected
                                              selectionRects:&rects];
    XCTAssertEqual(after.containerCreations, before.containerCreations);
    [self assertFiniteGeometryForStatus:after selectionRects:rects];
}

- (void)runTrailingHandleHeldAtBottomAutoscrollsAndExtendsSelectionMinimal:
    (BOOL)minimal {
    XCUIApplication *app =
        [self launchTouchScenario:@"touch-autoscroll"
                         minimal:minimal];
    XCUIElement *editor = [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *statusElement =
        [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);

    UITextView *geometry = [self stockOracleForEditor:editor scenario:@"touch-autoscroll"];
    NSRange word = [geometry.text rangeOfString:@"block 01"];
    XCTAssertNotEqual(word.location, NSNotFound);
    CGPoint selectionPoint = [self pointInsideCharacterAtOffset:word.location + 2
                                                        inStock:geometry];
    [[self coordinateForLocalPoint:selectionPoint editor:editor] tap];
    [self waitForCollapsedPhysicalTapStatus:statusElement];
    [self waitForTapSequenceQuiescence];
    [[self coordinateForLocalPoint:selectionPoint editor:editor] doubleTap];
    NSArray<NSDictionary<NSString *, id> *> *initialRects = nil;
    IDTouchSelectionStatus initial =
        [self waitForNonemptySelectionStatus:statusElement selectionRects:&initialRects];
    if (initial.selection.length == 0) return;
    XCTAssertEqual(initial.contentOffset.y, 0.0);
    XCTAssertEqual(initial.containerCreations, 1U);
    XCTAssertTrue(initial.containerStable);

    [NSThread sleepForTimeInterval:0.3];
    XCUIScreenshot *initialScreenshot = XCUIScreen.mainScreen.screenshot;
    CGRect trailing = [self matchedHandleForLogicalStart:NO
                                                   rects:initialRects
                                                  status:initial
                                                  editor:editor
                                              screenshot:initialScreenshot];
    XCTAssertFalse(CGRectIsNull(trailing));
    if (CGRectIsNull(trailing)) return;
    CGPoint screenHandlePoint = [self screenGrabPointForHandle:trailing logicalStart:NO];
    XCUICoordinate *edge = [editor coordinateWithNormalizedOffset:CGVectorMake(0.75, 0.96)];
    CGPoint calibratedEndpoint = CGPointMake(
        edge.screenPoint.x - IDStockTrailingHandleGrabOffset.dx,
        edge.screenPoint.y - IDStockTrailingHandleGrabOffset.dy);

    dispatch_queue_t observationQueue = dispatch_queue_create(
        "com.inputdec.tests.bottom-edge-autoscroll", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t observed = dispatch_semaphore_create(0);
    IDEdgeHoldObservation *observation = [IDEdgeHoldObservation new];
    CFTimeInterval synthesisEpoch = CACurrentMediaTime();
    IDEdgeHoldWindow holdWindow = [self holdWindowStartingAt:synthesisEpoch
        holdDuration:IDEdgePhysicalHoldDuration];
    dispatch_async(observationQueue, ^{
        [self observeStatusElement:statusElement initial:initial bottom:YES logicalStart:NO
                            window:holdWindow observation:observation];
        dispatch_semaphore_signal(observed);
    });
    IDHIDTouchPath *path = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:screenHandlePoint
                     startOffset:0.0
                       waypoints:@[
            [IDHIDTouchWaypoint moveTo:screenHandlePoint offset:IDEdgePressDuration],
            [IDHIDTouchWaypoint moveTo:calibratedEndpoint
                                offset:IDEdgePressDuration + 0.8],
            [IDHIDTouchWaypoint liftAtOffset:
                IDEdgePressDuration + 0.8 + IDEdgePhysicalHoldDuration],
        ]];
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, app, @[path], &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(observed,
                                           dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    XCTAssertEqual(observation.parseFailures, 0U, @"Every sampled custom snapshot must parse");
    [self attachNormalizedAutoscrollTrace:observation
        name:minimal
            ? @"edge-autoscroll-bottom-minimal-trace"
            : @"edge-autoscroll-bottom-reference-trace"];
    XCTAssertGreaterThanOrEqual(observation.samples.count, 3U, @"status=%@", statusElement.value);
    XCTAssertTrue(observation.preLiftEdgeMarker);
    XCTAssertLessThan(observation.markerTime, holdWindow.end);
    XCTAssertNotNil(observation.heldScreenshot);
    XCTAssertLessThan(observation.screenshotTime, holdWindow.end);
    XCTAssertLessThan(holdWindow.end, holdWindow.scheduledLift);
    if (observation.samples.count < 3 || observation.heldScreenshot == nil) return;

    IDTouchSelectionStatus previous = initial;
    for (NSValue *value in observation.samples) {
        IDTouchSelectionStatus candidate = [self touchSelectionStatusFromValue:value];
        XCTAssertGreaterThanOrEqual(candidate.contentOffset.y + 0.01, previous.contentOffset.y);
        XCTAssertEqual(candidate.selection.location, initial.selection.location,
                       @"Trailing-handle autoscroll must preserve the logical start");
        XCTAssertGreaterThanOrEqual(NSMaxRange(candidate.selection), NSMaxRange(previous.selection));
        XCTAssertGreaterThanOrEqual(candidate.presentationUpdates, previous.presentationUpdates);
        XCTAssertEqualWithAccuracy(candidate.visible.origin.y - candidate.contentOffset.y,
                                   initial.visible.origin.y - initial.contentOffset.y,
                                   0.01);
        XCTAssertEqual(candidate.containerCreations, 1U);
        XCTAssertTrue(candidate.containerStable);
        previous = candidate;
    }
    XCTAssertGreaterThan(previous.contentOffset.y, initial.contentOffset.y);
    XCTAssertGreaterThan(NSMaxRange(previous.selection), NSMaxRange(initial.selection));
    XCTAssertGreaterThan(previous.presentationUpdates, initial.presentationUpdates);
    [self attachScreenshot:observation.heldScreenshot name:@"edge-autoscroll-bottom-held"];
    XCTAttachment *heldStatusAttachment = [XCTAttachment attachmentWithString:
        observation.activeHandleStatus ?: @"<no atomic held snapshot>"];
    heldStatusAttachment.name = @"edge-autoscroll-bottom-atomic-status";
    heldStatusAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:heldStatusAttachment];
    XCTAssertLessThanOrEqual(observation.activeHandleEdgeDistance, 12.0,
                             @"Atomic visible handle edge distance; status=%@",
                             observation.activeHandleStatus);

    IDTouchSelectionStatus released =
        [self statusFromElement:statusElement selectionRects:NULL];
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                      name:@"edge-autoscroll-bottom-released"];
    [self waitForHalfSecondQuiescence];
    IDTouchSelectionStatus settled =
        [self statusFromElement:statusElement selectionRects:NULL];
    XCTAssertEqualWithAccuracy(settled.contentOffset.y, released.contentOffset.y, 0.01);
    XCTAssertTrue(NSEqualRanges(settled.selection, released.selection));
}

- (void)testTrailingHandleHeldAtBottomAutoscrollsAndExtendsSelection {
    [self
        runTrailingHandleHeldAtBottomAutoscrollsAndExtendsSelectionMinimal:NO];
}

- (void)testMinimalTrailingHandleHeldAtBottomAutoscrollsAndExtendsSelection {
    [self
        runTrailingHandleHeldAtBottomAutoscrollsAndExtendsSelectionMinimal:YES];
}

- (void)testStockProbeTrailingHandleHeldAtBottomAutoscrolls {
    XCUIApplication *probe = [self launchTouchScenario:@"touch-autoscroll"];
    XCUIElement *probeEditor =
        [probe descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCTAssertTrue([probeEditor waitForExistenceWithTimeout:4.0]);
    CGRect frame = probeEditor.frame;
    [probe terminate];

    XCUIElement *editor = nil;
    XCUIElement *statusElement = nil;
    XCUIApplication *app = [self launchStockApplicationForFrame:frame
                                                       scenario:@"touch-autoscroll"
                                                         editor:&editor
                                                         status:&statusElement];
    UITextView *geometry = [self stockOracleForEditor:editor scenario:@"touch-autoscroll"];
    NSRange word = [geometry.text rangeOfString:@"block 01"];
    CGPoint selectionPoint = [self pointInsideCharacterAtOffset:word.location + 2
                                                        inStock:geometry];
    [[self coordinateForLocalPoint:selectionPoint editor:editor] doubleTap];
    NSArray<NSDictionary<NSString *, id> *> *rects = nil;
    IDTouchSelectionStatus initial =
        [self waitForNonemptySelectionStatus:statusElement selectionRects:&rects];
    XCTAssertGreaterThan(initial.selection.location, 0U);
    XCTAssertGreaterThan(initial.selection.length, 0U);
    [NSThread sleepForTimeInterval:0.3];
    XCUIScreenshot *screenshot = XCUIScreen.mainScreen.screenshot;
    CGRect trailing = [self matchedHandleForLogicalStart:NO rects:rects status:initial
                                                  editor:editor screenshot:screenshot];
    if (CGRectIsNull(trailing)) {
        [app terminate];
        return;
    }
    CGPoint screenHandlePoint = [self screenGrabPointForHandle:trailing logicalStart:NO];
    CGPoint handlePoint = CGPointMake(screenHandlePoint.x - CGRectGetMinX(editor.frame),
                                      screenHandlePoint.y - CGRectGetMinY(editor.frame));
    XCUICoordinate *handle = [[editor coordinateWithNormalizedOffset:CGVectorMake(0, 0)]
        coordinateWithOffset:CGVectorMake(handlePoint.x, handlePoint.y)];
    XCUICoordinate *edge =
        [editor coordinateWithNormalizedOffset:CGVectorMake(0.75, 0.96)];
    CGPoint calibratedEndpoint = CGPointMake(
        edge.screenPoint.x - IDStockTrailingHandleGrabOffset.dx,
        edge.screenPoint.y - IDStockTrailingHandleGrabOffset.dy);
    dispatch_queue_t observationQueue = dispatch_queue_create(
        "com.inputdec.tests.stock-bottom-edge-autoscroll", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t observationFinished = dispatch_semaphore_create(0);
    IDEdgeHoldObservation *observation = [IDEdgeHoldObservation new];
    CFTimeInterval synthesisEpoch = CACurrentMediaTime();
    IDEdgeHoldWindow holdWindow = [self holdWindowStartingAt:synthesisEpoch
        holdDuration:IDEdgePhysicalHoldDuration];
    dispatch_async(observationQueue, ^{
        [self observeStatusElement:statusElement initial:initial bottom:YES logicalStart:NO
                            window:holdWindow observation:observation];
        dispatch_semaphore_signal(observationFinished);
    });
    IDHIDTouchPath *path = [self edgeTouchPathFromScreenPoint:handle.screenPoint
                                                toScreenPoint:calibratedEndpoint
                                                 holdDuration:IDEdgePhysicalHoldDuration];
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, app, @[path], &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(observationFinished,
        dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0L);
    XCTAssertEqual(observation.parseFailures, 0U, @"Every sampled stock snapshot must parse");
    [self attachNormalizedAutoscrollTrace:observation
                                     name:@"edge-autoscroll-bottom-stock-trace"];
    IDTouchSelectionStatus final =
        [self statusFromElement:statusElement selectionRects:NULL];
    NSData *statusData = [statusElement.value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *rawStatus = [NSJSONSerialization JSONObjectWithData:statusData
                                                               options:0 error:nil];
    NSDictionary *autoscroll = rawStatus[@"autoscroll"];
    XCTAssertGreaterThan([autoscroll[@"startCount"] unsignedIntegerValue], 0U,
                         @"status=%@", statusElement.value);
    XCTAssertEqualWithAccuracy([autoscroll[@"lastPoint"][@"x"] doubleValue],
                               CGRectGetWidth(editor.frame) * 0.75, 0.5,
                               @"status=%@", statusElement.value);
    XCTAssertEqualWithAccuracy([autoscroll[@"lastPoint"][@"y"] doubleValue],
                               initial.contentOffset.y + CGRectGetHeight(editor.frame) * 0.96,
                               0.5, @"status=%@", statusElement.value);
    XCTAssertGreaterThanOrEqual(observation.samples.count, 3U, @"status=%@", statusElement.value);
    XCTAssertTrue(observation.preLiftEdgeMarker);
    XCTAssertLessThan(observation.markerTime, holdWindow.end);
    XCTAssertNotNil(observation.heldScreenshot);
    XCTAssertLessThan(observation.screenshotTime, holdWindow.end);
    XCTAssertLessThan(holdWindow.end, holdWindow.scheduledLift);
    if (observation.heldScreenshot != nil) {
        [self attachScreenshot:observation.heldScreenshot name:@"stock-edge-autoscroll-bottom-held"];
    }
    XCTAttachment *stockHandleStatusAttachment = [XCTAttachment attachmentWithString:
        observation.activeHandleStatus ?: @"<no atomic held snapshot>"];
    stockHandleStatusAttachment.name = @"stock-edge-autoscroll-bottom-atomic-status";
    stockHandleStatusAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:stockHandleStatusAttachment];
    XCTAssertLessThanOrEqual(observation.activeHandleEdgeDistance, 12.0,
                             @"Stock atomic active trailing-handle distance; status=%@",
                             observation.activeHandleStatus);
    IDTouchSelectionStatus previous = initial;
    for (NSValue *sampleValue in observation.samples) {
        IDTouchSelectionStatus sample = [self touchSelectionStatusFromValue:sampleValue];
        XCTAssertGreaterThanOrEqual(sample.contentOffset.y + 0.01, previous.contentOffset.y);
        XCTAssertGreaterThanOrEqual(NSMaxRange(sample.selection),
                                    NSMaxRange(previous.selection));
        previous = sample;
    }
    XCTAssertGreaterThan(previous.contentOffset.y, initial.contentOffset.y,
                         @"initial=%@ final=%@", NSStringFromCGPoint(initial.contentOffset),
                         NSStringFromCGPoint(final.contentOffset));
    XCTAssertGreaterThan(NSMaxRange(previous.selection), NSMaxRange(initial.selection));
    [self waitForHalfSecondQuiescence];
    IDTouchSelectionStatus settled =
        [self statusFromElement:statusElement selectionRects:NULL];
    XCTAssertEqualWithAccuracy(settled.contentOffset.y, final.contentOffset.y, 0.01);
    XCTAssertTrue(NSEqualRanges(settled.selection, final.selection));
    [app terminate];
}

- (void)runLeadingHandleHeldAtTopAutoscrollsAndExtendsSelectionMinimal:
    (BOOL)minimal {
    XCUIApplication *app =
        [self launchTouchScenario:@"touch-autoscroll"
                         minimal:minimal];
    XCUIElement *editor = [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *statusElement =
        [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);

    for (NSUInteger index = 0; index < 5; index += 1) {
        [editor swipeUp];
    }
    IDTouchSelectionStatus scrolled =
        [self waitForStableContentOffsetInStatusElement:statusElement];
    XCTAssertGreaterThan(scrolled.contentOffset.y, CGRectGetHeight(editor.frame));
    XCUICoordinate *selectionCoordinate =
        [editor coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.12)];
    [selectionCoordinate tap];
    [self waitForCollapsedPhysicalTapStatus:statusElement];
    [self waitForTapSequenceQuiescence];
    [selectionCoordinate doubleTap];
    NSArray<NSDictionary<NSString *, id> *> *initialRects = nil;
    IDTouchSelectionStatus initial =
        [self waitForNonemptySelectionStatus:statusElement selectionRects:&initialRects];
    if (initial.selection.length == 0) return;
    XCTAssertGreaterThan(initial.selection.location, 0U);
    XCTAssertEqual(initial.containerCreations, 1U);
    XCTAssertTrue(initial.containerStable);

    [NSThread sleepForTimeInterval:0.3];
    XCUIScreenshot *initialScreenshot = XCUIScreen.mainScreen.screenshot;
    CGRect leading = [self matchedHandleForLogicalStart:YES
                                                  rects:initialRects
                                                 status:initial
                                                 editor:editor
                                             screenshot:initialScreenshot];
    XCTAssertFalse(CGRectIsNull(leading));
    if (CGRectIsNull(leading)) return;
    CGPoint screenHandlePoint = [self screenGrabPointForHandle:leading logicalStart:YES];
    XCUICoordinate *edge = [editor coordinateWithNormalizedOffset:CGVectorMake(0.25, 0.04)];
    CGPoint calibratedEndpoint = CGPointMake(
        edge.screenPoint.x - IDStockLeadingHandleGrabOffset.dx,
        edge.screenPoint.y - IDStockLeadingHandleGrabOffset.dy -
            (minimal
                ? IDMinimalLeadingHandleEndpointCalibration
                : 0.0));

    dispatch_queue_t observationQueue = dispatch_queue_create(
        "com.inputdec.tests.top-edge-autoscroll", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t observed = dispatch_semaphore_create(0);
    IDEdgeHoldObservation *observation = [IDEdgeHoldObservation new];
    CFTimeInterval synthesisEpoch = CACurrentMediaTime();
    IDEdgeHoldWindow holdWindow = [self holdWindowStartingAt:synthesisEpoch
        holdDuration:IDEdgePhysicalHoldDuration];
    dispatch_async(observationQueue, ^{
        [self observeStatusElement:statusElement initial:initial bottom:NO logicalStart:YES
                            window:holdWindow observation:observation];
        dispatch_semaphore_signal(observed);
    });
    IDHIDTouchPath *path = [self edgeTouchPathFromScreenPoint:screenHandlePoint
                                                toScreenPoint:calibratedEndpoint
                                                 holdDuration:IDEdgePhysicalHoldDuration];
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, app, @[path], &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(observed,
                                           dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    XCTAssertEqual(observation.parseFailures, 0U, @"Every sampled custom snapshot must parse");
    [self attachNormalizedAutoscrollTrace:observation
        name:minimal
            ? @"edge-autoscroll-top-minimal-trace"
            : @"edge-autoscroll-top-reference-trace"];
    XCTAttachment *heldStatusAttachment = [XCTAttachment attachmentWithString:
        observation.activeHandleStatus ?: @"<no held status>"];
    heldStatusAttachment.name = minimal
        ? @"edge-autoscroll-top-minimal-atomic-status"
        : @"edge-autoscroll-top-reference-atomic-status";
    heldStatusAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:heldStatusAttachment];
    XCTAttachment *postGestureStatusAttachment =
        [XCTAttachment attachmentWithString:
            [statusElement.value isKindOfClass:NSString.class]
                ? statusElement.value
                : [statusElement.value description]];
    postGestureStatusAttachment.name = minimal
        ? @"edge-autoscroll-top-minimal-post-gesture-status"
        : @"edge-autoscroll-top-reference-post-gesture-status";
    postGestureStatusAttachment.lifetime =
        XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:postGestureStatusAttachment];
    XCTAssertGreaterThanOrEqual(observation.samples.count, 3U, @"status=%@", statusElement.value);
    XCTAssertTrue(observation.preLiftEdgeMarker);
    XCTAssertLessThan(observation.markerTime, holdWindow.end);
    XCTAssertNotNil(observation.heldScreenshot);
    XCTAssertLessThan(observation.screenshotTime, holdWindow.end);
    XCTAssertLessThan(holdWindow.end, holdWindow.scheduledLift);
    if (observation.samples.count < 3 || observation.heldScreenshot == nil) return;

    IDTouchSelectionStatus previous = initial;
    NSUInteger fixedEnd = NSMaxRange(initial.selection);
    for (NSValue *value in observation.samples) {
        IDTouchSelectionStatus candidate = [self touchSelectionStatusFromValue:value];
        XCTAssertLessThanOrEqual(candidate.contentOffset.y, previous.contentOffset.y + 0.01);
        XCTAssertLessThanOrEqual(candidate.selection.location, previous.selection.location);
        XCTAssertEqual(NSMaxRange(candidate.selection), fixedEnd,
                       @"Leading-handle autoscroll must preserve the logical end");
        XCTAssertGreaterThanOrEqual(candidate.presentationUpdates, previous.presentationUpdates);
        XCTAssertEqualWithAccuracy(candidate.visible.origin.y - candidate.contentOffset.y,
                                   initial.visible.origin.y - initial.contentOffset.y,
                                   0.01);
        XCTAssertEqual(candidate.containerCreations, 1U);
        XCTAssertTrue(candidate.containerStable);
        previous = candidate;
    }
    XCTAssertLessThan(previous.contentOffset.y, initial.contentOffset.y);
    XCTAssertLessThan(previous.selection.location, initial.selection.location);
    XCTAssertGreaterThan(previous.presentationUpdates, initial.presentationUpdates);
    [self attachEdgeSamples:observation initial:initial name:@"edge-autoscroll-top-samples"];
    [self attachScreenshot:observation.heldScreenshot name:@"edge-autoscroll-top-held"];
    XCTAssertLessThanOrEqual(observation.activeHandleEdgeDistance, 12.0,
                             @"Atomic visible handle edge distance");

    IDTouchSelectionStatus released =
        [self statusFromElement:statusElement selectionRects:NULL];
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                      name:@"edge-autoscroll-top-released"];
    [self waitForHalfSecondQuiescence];
    IDTouchSelectionStatus settled =
        [self statusFromElement:statusElement selectionRects:NULL];
    XCTAssertEqualWithAccuracy(settled.contentOffset.y, released.contentOffset.y, 0.01);
    XCTAssertTrue(NSEqualRanges(settled.selection, released.selection));
}

- (void)testLeadingHandleHeldAtTopAutoscrollsAndExtendsSelection {
    [self
        runLeadingHandleHeldAtTopAutoscrollsAndExtendsSelectionMinimal:NO];
}

- (void)testMinimalLeadingHandleHeldAtTopAutoscrollsAndExtendsSelection {
    [self
        runLeadingHandleHeldAtTopAutoscrollsAndExtendsSelectionMinimal:YES];
}

- (void)testStockProbeLeadingHandleHeldAtTopAutoscrolls {
    XCUIApplication *probe = [self launchTouchScenario:@"touch-autoscroll"];
    XCUIElement *probeEditor =
        [probe descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCTAssertTrue([probeEditor waitForExistenceWithTimeout:4.0]);
    CGRect frame = probeEditor.frame;
    [probe terminate];

    XCUIElement *editor = nil;
    XCUIElement *statusElement = nil;
    XCUIApplication *app = [self launchStockApplicationForFrame:frame
                                                       scenario:@"touch-autoscroll"
                                                         editor:&editor
                                                         status:&statusElement];
    for (NSUInteger index = 0; index < 5; index += 1) [editor swipeUp];
    IDTouchSelectionStatus scrolled =
        [self waitForStableContentOffsetInStatusElement:statusElement];
    XCTAssertGreaterThan(scrolled.contentOffset.y, CGRectGetHeight(editor.frame));
    XCUICoordinate *selectionCoordinate =
        [editor coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.12)];
    [selectionCoordinate doubleTap];
    NSArray<NSDictionary<NSString *, id> *> *rects = nil;
    IDTouchSelectionStatus initial =
        [self waitForNonemptySelectionStatus:statusElement selectionRects:&rects];
    [NSThread sleepForTimeInterval:0.3];
    CGRect leading = [self matchedHandleForLogicalStart:YES
                                                  rects:rects
                                                 status:initial
                                                 editor:editor
                                             screenshot:XCUIScreen.mainScreen.screenshot];
    if (CGRectIsNull(leading)) {
        [app terminate];
        return;
    }
    CGPoint handlePoint = [self screenGrabPointForHandle:leading logicalStart:YES];
    XCUICoordinate *edge =
        [editor coordinateWithNormalizedOffset:CGVectorMake(0.25, 0.04)];
    CGPoint calibratedEndpoint = CGPointMake(
        edge.screenPoint.x - IDStockLeadingHandleGrabOffset.dx,
        edge.screenPoint.y - IDStockLeadingHandleGrabOffset.dy);
    dispatch_queue_t observationQueue = dispatch_queue_create(
        "com.inputdec.tests.stock-top-edge-autoscroll", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t observationFinished = dispatch_semaphore_create(0);
    IDEdgeHoldObservation *observation = [IDEdgeHoldObservation new];
    CFTimeInterval synthesisEpoch = CACurrentMediaTime();
    IDEdgeHoldWindow holdWindow = [self holdWindowStartingAt:synthesisEpoch
        holdDuration:IDEdgePhysicalHoldDuration];
    dispatch_async(observationQueue, ^{
        [self observeStatusElement:statusElement initial:initial bottom:NO logicalStart:YES
                            window:holdWindow observation:observation];
        dispatch_semaphore_signal(observationFinished);
    });
    IDHIDTouchPath *path = [self edgeTouchPathFromScreenPoint:handlePoint
                                                toScreenPoint:calibratedEndpoint
                                                 holdDuration:IDEdgePhysicalHoldDuration];
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, app, @[path], &error), @"%@", error);
    XCTAssertEqual(dispatch_semaphore_wait(observationFinished,
        dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0L);
    XCTAssertEqual(observation.parseFailures, 0U, @"Every sampled stock snapshot must parse");
    [self attachNormalizedAutoscrollTrace:observation
                                     name:@"edge-autoscroll-top-stock-trace"];
    NSData *statusData = [statusElement.value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *rawStatus = [NSJSONSerialization JSONObjectWithData:statusData
                                                               options:0 error:nil];
    NSDictionary *autoscroll = rawStatus[@"autoscroll"];
    XCTAssertGreaterThan([autoscroll[@"startCount"] unsignedIntegerValue], 0U,
                         @"status=%@", statusElement.value);
    CGFloat expectedAssistantX = edge.screenPoint.x - CGRectGetMinX(editor.frame);
    CGFloat expectedAssistantY = initial.contentOffset.y +
        edge.screenPoint.y - CGRectGetMinY(editor.frame);
    XCTAssertEqualWithAccuracy([autoscroll[@"lastPoint"][@"x"] doubleValue],
                               expectedAssistantX, 0.5,
                               @"status=%@", statusElement.value);
    // UIKit's leading-handle adjustment quantizes the vertical callback point
    // after a long upward scroll.  iOS 26.5 has varied by 2.07 points from the
    // unadjusted editor-space prediction while preserving the edge direction,
    // terminal selection, and quiescence; keep this diagnostic below 3 points.
    XCTAssertEqualWithAccuracy([autoscroll[@"lastPoint"][@"y"] doubleValue],
                               expectedAssistantY, 3.0,
                               @"status=%@", statusElement.value);
    XCTAssertGreaterThanOrEqual(observation.samples.count, 3U, @"status=%@", statusElement.value);
    XCTAssertTrue(observation.preLiftEdgeMarker);
    XCTAssertLessThan(observation.markerTime, holdWindow.end);
    XCTAssertNotNil(observation.heldScreenshot);
    XCTAssertLessThan(observation.screenshotTime, holdWindow.end);
    XCTAssertLessThan(holdWindow.end, holdWindow.scheduledLift);
    if (observation.heldScreenshot != nil) {
        [self attachScreenshot:observation.heldScreenshot name:@"stock-edge-autoscroll-top-held"];
    }
    XCTAssertLessThanOrEqual(observation.activeHandleEdgeDistance, 12.0,
                             @"Stock atomic active leading-handle distance");
    IDTouchSelectionStatus previous = initial;
    NSUInteger fixedEnd = NSMaxRange(initial.selection);
    for (NSValue *sampleValue in observation.samples) {
        IDTouchSelectionStatus sample = [self touchSelectionStatusFromValue:sampleValue];
        XCTAssertLessThanOrEqual(sample.contentOffset.y, previous.contentOffset.y + 0.01);
        XCTAssertLessThanOrEqual(sample.selection.location, previous.selection.location);
        XCTAssertEqual(NSMaxRange(sample.selection), fixedEnd);
        previous = sample;
    }
    XCTAssertLessThan(previous.contentOffset.y, initial.contentOffset.y);
    XCTAssertLessThan(previous.selection.location, initial.selection.location);
    [self attachEdgeSamples:observation initial:initial
                       name:@"stock-edge-autoscroll-top-samples"];
    IDTouchSelectionStatus final =
        [self statusFromElement:statusElement selectionRects:NULL];
    [self waitForHalfSecondQuiescence];
    IDTouchSelectionStatus settled =
        [self statusFromElement:statusElement selectionRects:NULL];
    XCTAssertEqualWithAccuracy(settled.contentOffset.y, final.contentOffset.y, 0.01);
    XCTAssertTrue(NSEqualRanges(settled.selection, final.selection));
    [app terminate];
}

- (void)testLongPressShowsNativeLoupeAndTracksCanonicalInsertion {
    XCUIApplication *app = [self launchTouchScenario:@"touch-ltr"];
    XCUIElement *editor = [app descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *statusElement = [app descendantsMatchingType:XCUIElementTypeAny][@"touch-status"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([statusElement waitForExistenceWithTimeout:4.0]);

    UITextView *stock = [self stockOracleForEditor:editor];
    NSRange word = [stock.text rangeOfString:@"constellation"];
    XCTAssertNotEqual(word.location, NSNotFound);
    CGPoint startPoint = [self pointInsideCharacterAtOffset:word.location + 1 inStock:stock];
    CGPoint firstPoint = [self pointInsideCharacterAtOffset:word.location + 5 inStock:stock];
    CGPoint secondPoint = [self pointInsideCharacterAtOffset:word.location + 9 inStock:stock];
    XCUICoordinate *start = [self coordinateForLocalPoint:startPoint editor:editor];
    XCUICoordinate *first = [self coordinateForLocalPoint:firstPoint editor:editor];
    XCUICoordinate *second = [self coordinateForLocalPoint:secondPoint editor:editor];

    [editor tap];
    IDTouchSelectionStatus focus = [self waitForCollapsedPhysicalTapStatus:statusElement];
    [self waitForTapSequenceQuiescence];
    [start tap];
    IDTouchSelectionStatus initial = [self waitForCollapsedPhysicalTapStatus:statusElement
                                                          differentFromRange:focus.selection];
    XCUIScreenshot *baseline = XCUIScreen.mainScreen.screenshot;
    [self attachScreenshot:baseline name:@"loupe-baseline"];
    CGRect firstSearch = [self loupeSearchRectAboveCoordinate:first screenshot:baseline];

    dispatch_queue_t observationQueue = dispatch_queue_create(
        "com.inputdec.tests.held-loupe-observation", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t firstObserved = dispatch_semaphore_create(0);
    __block IDTouchSelectionStatus firstStatus = {0};
    __block XCUIScreenshot *firstHeld = nil;
    dispatch_async(observationQueue, ^{
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:4.0];
        do {
            IDTouchSelectionStatus candidate = {0};
            if (IDTouchSelectionParseStatus(statusElement.value, &candidate, NULL) &&
                candidate.selection.length == 0 &&
                !NSEqualRanges(candidate.selection, initial.selection)) {
                firstStatus = candidate;
                for (NSUInteger attempt = 0; attempt < 10; attempt += 1) {
                    XCUIScreenshot *candidateScreenshot = XCUIScreen.mainScreen.screenshot;
                    CGRect candidateRegion = IDTouchSelectionLargestChangedRegion(
                        baseline, candidateScreenshot, firstSearch, 12);
                    if (IDTouchSelectionIsLoupeSizedRegion(candidateRegion)) {
                        firstHeld = candidateScreenshot;
                        break;
                    }
                    [NSThread sleepForTimeInterval:0.1];
                }
                break;
            }
            [NSThread sleepForTimeInterval:0.05];
        } while (deadline.timeIntervalSinceNow > 0.0);
        dispatch_semaphore_signal(firstObserved);
    });
    [start pressForDuration:0.8
       thenDragToCoordinate:first
                withVelocity:XCUIGestureVelocitySlow
         thenHoldForDuration:2.0];
    XCTAssertEqual(dispatch_semaphore_wait(firstObserved,
                                           dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    XCTAssertNotNil(firstHeld);
    if (firstHeld == nil) return;
    XCTAssertFalse(NSEqualRanges(firstStatus.selection, initial.selection));
    [self attachScreenshot:firstHeld name:@"loupe-held"];
    CGRect firstRegion = IDTouchSelectionLargestChangedRegion(baseline, firstHeld, firstSearch, 12);
    [self assertLoupeRegion:firstRegion];

    [self waitForHalfSecondQuiescence];
    IDTouchSelectionStatus secondBaselineStatus =
        [self statusFromElement:statusElement selectionRects:NULL];
    XCUIScreenshot *secondBaseline = XCUIScreen.mainScreen.screenshot;
    CGRect secondSearch = [self loupeSearchRectAboveCoordinate:second
                                                     screenshot:secondBaseline];
    dispatch_semaphore_t secondObserved = dispatch_semaphore_create(0);
    __block IDTouchSelectionStatus secondStatus = {0};
    __block XCUIScreenshot *secondHeld = nil;
    dispatch_async(observationQueue, ^{
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:4.0];
        do {
            IDTouchSelectionStatus candidate = {0};
            if (IDTouchSelectionParseStatus(statusElement.value, &candidate, NULL) &&
                candidate.selection.length == 0 &&
                !NSEqualRanges(candidate.selection, firstStatus.selection)) {
                secondStatus = candidate;
                for (NSUInteger attempt = 0; attempt < 10; attempt += 1) {
                    XCUIScreenshot *candidateScreenshot = XCUIScreen.mainScreen.screenshot;
                    CGRect candidateRegion = IDTouchSelectionLargestChangedRegion(
                        secondBaseline, candidateScreenshot, secondSearch, 12);
                    if (IDTouchSelectionIsLoupeSizedRegion(candidateRegion)) {
                        secondHeld = candidateScreenshot;
                        break;
                    }
                    [NSThread sleepForTimeInterval:0.1];
                }
                break;
            }
            [NSThread sleepForTimeInterval:0.05];
        } while (deadline.timeIntervalSinceNow > 0.0);
        dispatch_semaphore_signal(secondObserved);
    });
    [first pressForDuration:0.8
      thenDragToCoordinate:second
               withVelocity:XCUIGestureVelocitySlow
        thenHoldForDuration:2.0];
    XCTAssertEqual(dispatch_semaphore_wait(secondObserved,
                                           dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    XCTAssertNotNil(secondHeld);
    if (secondHeld == nil) return;
    XCTAssertFalse(NSEqualRanges(secondStatus.selection, firstStatus.selection));
    [self attachScreenshot:secondHeld name:@"loupe-moved"];
    CGRect secondRegion = IDTouchSelectionLargestChangedRegion(secondBaseline, secondHeld,
                                                               secondSearch, 12);
    [self assertLoupeRegion:secondRegion];
    CGFloat loupeMovementX = CGRectGetMidX(secondRegion) - CGRectGetMidX(firstRegion);
    CGFloat caretMovementX = CGRectGetMidX(secondStatus.caret) - CGRectGetMidX(firstStatus.caret);
    XCTAssertGreaterThan(loupeMovementX, 0.0);
    XCTAssertGreaterThan(caretMovementX, 0.0);
    XCTAssertGreaterThan(loupeMovementX * caretMovementX, 0.0,
                         @"Loupe and canonical caret must move in the same direction");
    XCTAssertGreaterThan(secondStatus.selection.location, firstStatus.selection.location);
    XCTAssertEqual(secondStatus.containerCreations, initial.containerCreations);

    IDTouchSelectionStatus endedStatus =
        [self statusFromElement:statusElement selectionRects:NULL];
    CGRect baselineCaretScreenRect = [self screenCaretRectForStatus:secondBaselineStatus
                                                             editor:editor
                                                 textContainerInset:stock.textContainerInset];
    CGRect endedCaretScreenRect = [self screenCaretRectForStatus:endedStatus
                                                          editor:editor
                                              textContainerInset:stock.textContainerInset];
    NSArray<NSValue *> *allowedCaretRects = @[
        [NSValue valueWithCGRect:baselineCaretScreenRect],
        [NSValue valueWithCGRect:endedCaretScreenRect],
    ];
    XCUIScreenshot *ended = nil;
    NSArray<NSValue *> *endedRegions = nil;
    for (NSUInteger attempt = 0; attempt < 20; attempt += 1) {
        XCUIScreenshot *candidate = XCUIScreen.mainScreen.screenshot;
        NSArray<NSValue *> *candidateRegions = IDTouchSelectionChangedRegions(
            secondBaseline, candidate, CGRectInset(secondRegion, -4.0, -4.0), 12);
        ended = candidate;
        endedRegions = candidateRegions;
        if (IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(
                candidateRegions, allowedCaretRects)) break;
        [NSThread sleepForTimeInterval:0.1];
    }
    [self attachScreenshot:ended name:@"loupe-ended"];
    XCTAssertTrue(IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(
                      endedRegions, allowedCaretRects),
                  @"Loupe must be dismissed; residuals must be confined to carets %@, changed=%@",
                  allowedCaretRects, endedRegions);
    XCTAssertTrue(editor.exists);
    XCTAssertTrue(statusElement.exists);
    XCTAssertEqual(endedStatus.selection.length, 0U);
    XCTAssertEqual(endedStatus.containerCreations, initial.containerCreations);
}

- (void)testScreenshotHelpersRespectAsymmetricUIKitTopOriginROI {
    XCUIApplication *app = [self launchDefaultApplication];
    XCUIElement *reset = app.buttons[@"reset-button"];
    XCUIElement *editable = app.buttons[@"editable-toggle"];
    XCTAssertTrue([reset waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([editable waitForExistenceWithTimeout:4.0]);

    CGRect blueROI = CGRectInset(reset.frame, -2.0, -2.0);
    CGRect changedROI = CGRectInset(editable.frame, -2.0, -2.0);
    XCUIScreenshot *before = XCUIScreen.mainScreen.screenshot;
    CGRect screenBounds = before.image.size.width > 0
        ? (CGRect){CGPointZero, before.image.size}
        : CGRectNull;
    XCTAssertLessThan(CGRectGetMidY(blueROI), CGRectGetMidY(screenBounds));
    XCTAssertLessThan(CGRectGetMidY(changedROI), CGRectGetMidY(screenBounds));

    NSArray<NSValue *> *blueComponents =
        IDTouchSelectionBlueComponents(before, blueROI);

    [editable tap];
    NSPredicate *off = [NSPredicate predicateWithFormat:@"value == 'Off'"];
    XCTNSPredicateExpectation *offExpectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:off object:editable];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[offExpectation] timeout:3.0],
                   XCTWaiterResultCompleted);
    XCUIScreenshot *after = XCUIScreen.mainScreen.screenshot;
    CGRect changedRegion =
        IDTouchSelectionLargestChangedRegion(before, after, changedROI, 4);

    XCTAssertGreaterThan(blueComponents.count, 0U,
                         @"Expected system-blue title pixels inside top ROI %@",
                         NSStringFromCGRect(blueROI));
    XCTAssertFalse(CGRectIsNull(changedRegion),
                   @"Expected toggle-title changes inside top ROI %@",
                   NSStringFromCGRect(changedROI));
}

- (void)testLoupeDismissalResidualClassifierAcceptsOnlyCaretConfinedChanges {
    NSArray<NSValue *> *carets = @[
        [NSValue valueWithCGRect:CGRectMake(62.3333333333, 237.0, 2.0, 25.3333333333)],
        [NSValue valueWithCGRect:CGRectMake(98.0, 237.0, 2.0, 25.3333333333)],
    ];
    NSArray<NSValue *> *caretOnly = @[
        [NSValue valueWithCGRect:CGRectMake(62.3333333333, 237.0, 2.0, 1.3333333333)],
        [NSValue valueWithCGRect:CGRectMake(98.0, 237.0, 2.0, 1.3333333333)],
    ];
    XCTAssertTrue(IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(
        caretOnly, carets));
    XCTAssertTrue(IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(@[
        [NSValue valueWithCGRect:CGRectMake(62.333333333333329, 237.0,
                                             2.0, 1.6666666667)],
    ], @[
        [NSValue valueWithCGRect:CGRectMake(62.333333333333343, 237.0,
                                             2.0, 25.6666666667)],
    ]));

    NSArray<NSValue *> *loupeAndCaret = @[
        caretOnly.firstObject,
        [NSValue valueWithCGRect:CGRectMake(30.0, 80.0, 72.0, 64.0)],
    ];
    XCTAssertFalse(IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(
        loupeAndCaret, carets));
    XCTAssertFalse(IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(@[
        [NSValue valueWithCGRect:CGRectMake(80.0, 237.0, 2.0, 1.3333333333)],
    ], carets));
    XCTAssertFalse(IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(@[
        [NSValue valueWithCGRect:CGRectMake(62.3323333333, 237.0, 2.0, 1.3333333333)],
    ], carets));
}

- (void)testStatusParserPreservesNSUIntegerMaxAndRejectsItsSuccessor {
    IDTouchSelectionStatus parsed = {0};
    XCTAssertTrue(IDTouchSelectionParseStatus(
        [self statusJSONWithBlockCount:@"18446744073709551614"], &parsed, NULL));
    XCTAssertEqual(parsed.blockCount, NSUIntegerMax - 1);

    parsed = (IDTouchSelectionStatus){0};
    XCTAssertTrue(IDTouchSelectionParseStatus(
        [self statusJSONWithBlockCount:@"18446744073709551615"], &parsed, NULL));
    XCTAssertEqual(parsed.blockCount, NSUIntegerMax);

    XCTAssertFalse(IDTouchSelectionParseStatus(
        [self statusJSONWithBlockCount:@"18446744073709551616"], NULL, NULL));
}

- (void)testActiveHandleDistanceClipsToAtomicInsetVisibleRect {
    NSString *(^status)(BOOL, CGFloat, CGFloat) = ^NSString *(BOOL start,
                                                              CGFloat handleY,
                                                              CGFloat endpointY) {
        return [NSString stringWithFormat:
            @"{\"selectionRects\":[{\"containsStart\":%@,\"containsEnd\":%@,"
             "\"direction\":0,\"x\":10,\"y\":%.3f,\"width\":0,\"height\":0}],"
             "\"visibleHandles\":[{\"x\":5,\"y\":%.3f,\"width\":20,\"height\":15}],"
             "\"visible\":{\"x\":0,\"y\":120,\"width\":100,\"height\":60}}",
            start ? @"true" : @"false", start ? @"false" : @"true", endpointY,
            handleY];
    };
    XCTAssertEqualWithAccuracy(
        [self activeHandleEdgeDistanceFromStatusValue:status(YES, 110, 120)
                                         logicalStart:YES], 0.0, 0.001);
    XCTAssertEqualWithAccuracy(
        [self activeHandleEdgeDistanceFromStatusValue:status(NO, 175, 180)
                                         logicalStart:NO], 0.0, 0.001);
    XCTAssertEqual([self activeHandleEdgeDistanceFromStatusValue:status(NO, 181, 181)
                                                    logicalStart:NO], CGFLOAT_MAX);
}

- (void)testPrivateXCTestHIDRuntimeABIsAreCompatible {
    XCTAssertTrue(IDHIDAssertRuntimeCompatible(self));
}

- (void)testHIDEventRecordBuilderAddsEveryPathAndWaypointInOrder {
    IDHIDTouchPath *first = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:CGPointMake(10, 20)
                 startOffset:0.0
                   waypoints:@[
        [IDHIDTouchWaypoint moveTo:CGPointMake(30, 40) offset:0.2],
        [IDHIDTouchWaypoint liftAtOffset:0.3],
    ]];
    IDHIDTouchPath *second = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:CGPointMake(50, 60)
                 startOffset:0.1
                   waypoints:@[
        [IDHIDTouchWaypoint moveTo:CGPointMake(70, 80) offset:0.4],
        [IDHIDTouchWaypoint liftAtOffset:0.5],
    ]];
    IDHIDFakeRecord *record = IDHIDBuildEventRecord(
        self, @[first, second], IDHIDFakePath.class, IDHIDFakeRecord.class);
    XCTAssertNotNil(record);
    XCTAssertEqual(record.paths.count, 2U);
    XCTAssertEqualObjects(record.paths[0].operations,
        (@[@"start {10, 20} 0.00", @"move {30, 40} 0.20", @"lift 0.30"]));
    XCTAssertEqualObjects(record.paths[1].operations,
        (@[@"start {50, 60} 0.10", @"move {70, 80} 0.40", @"lift 0.50"]));
}

- (void)testHIDEventRecordBuilderRejectsNonterminalLift {
    IDHIDFailureCapturingTestCase *capture =
        [[IDHIDFailureCapturingTestCase alloc] initWithInvocation:nil];
    IDHIDTouchPath *invalid = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:CGPointZero
                 startOffset:0.0
                   waypoints:@[
        [IDHIDTouchWaypoint moveTo:CGPointMake(1, 1) offset:0.1],
        [IDHIDTouchWaypoint liftAtOffset:0.2],
        [IDHIDTouchWaypoint moveTo:CGPointMake(2, 2) offset:0.3],
    ]];
    XCTAssertNil(IDHIDBuildEventRecord(capture, @[invalid], IDHIDFakePath.class,
                                       IDHIDFakeRecord.class));
    XCTAssertEqual(capture.capturedIssues.count, 1U);
    XCTAssertTrue([capture.capturedIssues.firstObject.compactDescription
        containsString:@"terminal lift"]);
}

- (void)testHIDEventRecordBuilderRejectsNonIncreasingOffsets {
    IDHIDFailureCapturingTestCase *capture =
        [[IDHIDFailureCapturingTestCase alloc] initWithInvocation:nil];
    IDHIDTouchPath *invalid = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:CGPointZero
                 startOffset:0.0
                   waypoints:@[
        [IDHIDTouchWaypoint moveTo:CGPointMake(1, 1) offset:0.2],
        [IDHIDTouchWaypoint liftAtOffset:0.2],
    ]];
    XCTAssertNil(IDHIDBuildEventRecord(capture, @[invalid], IDHIDFakePath.class,
                                       IDHIDFakeRecord.class));
    XCTAssertEqual(capture.capturedIssues.count, 1U);
    XCTAssertTrue([capture.capturedIssues.firstObject.compactDescription
        containsString:@"strictly increasing"]);
}

- (void)testHIDEventRecordBuilderRejectsNonfinitePoint {
    IDHIDFailureCapturingTestCase *capture =
        [[IDHIDFailureCapturingTestCase alloc] initWithInvocation:nil];
    IDHIDTouchPath *invalid = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:CGPointMake(NAN, 0)
                 startOffset:0.0
                   waypoints:@[[IDHIDTouchWaypoint liftAtOffset:0.1]]];
    XCTAssertNil(IDHIDBuildEventRecord(capture, @[invalid], IDHIDFakePath.class,
                                       IDHIDFakeRecord.class));
    XCTAssertEqual(capture.capturedIssues.count, 1U);
    XCTAssertTrue([capture.capturedIssues.firstObject.compactDescription
        containsString:@"finite start point"]);
}

- (void)testHIDEventRecordBuilderRejectsNonfiniteOffset {
    IDHIDFailureCapturingTestCase *capture =
        [[IDHIDFailureCapturingTestCase alloc] initWithInvocation:nil];
    IDHIDTouchPath *invalid = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:CGPointZero
                 startOffset:0.0
                   waypoints:@[[IDHIDTouchWaypoint liftAtOffset:INFINITY]]];
    XCTAssertNil(IDHIDBuildEventRecord(capture, @[invalid], IDHIDFakePath.class,
                                       IDHIDFakeRecord.class));
    XCTAssertEqual(capture.capturedIssues.count, 1U);
    XCTAssertTrue([capture.capturedIssues.firstObject.compactDescription
        containsString:@"finite and strictly increasing"]);
}

- (void)testHIDEventRecordBuilderRejectsEqualSizedWrongPointABI {
    IDHIDFailureCapturingTestCase *capture =
        [[IDHIDFailureCapturingTestCase alloc] initWithInvocation:nil];
    IDHIDTouchPath *path = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:CGPointZero
                 startOffset:0.0
                   waypoints:@[[IDHIDTouchWaypoint liftAtOffset:0.1]]];
    XCTAssertNil(IDHIDBuildEventRecord(capture, @[path], IDHIDWrongPointABIPath.class,
                                       IDHIDFakeRecord.class));
    XCTAssertGreaterThan(capture.capturedIssues.count, 0U);
}

- (void)testEdgeHoldWindowEndsBeforeScheduledLiftWithSafetyMargin {
    IDEdgeHoldWindow window = [self holdWindowStartingAt:100.0 holdDuration:2.0];
    XCTAssertEqualWithAccuracy(window.start, 101.05, 0.001);
    XCTAssertEqualWithAccuracy(window.end, 102.75, 0.001);
    XCTAssertEqualWithAccuracy(window.scheduledLift, 102.95, 0.001);
    XCTAssertGreaterThanOrEqual(window.end - window.start, 20.0 * 0.075);
    XCTAssertLessThan(window.end, window.scheduledLift);
}

@end
