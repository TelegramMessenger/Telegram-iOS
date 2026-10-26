#import "IDFloatingCursorTestSupport.h"
#import "IDHIDEventTestSupport.h"
#import "IDTouchSelectionTestSupport.h"

#import <QuartzCore/QuartzCore.h>

@interface IDSelectionCallbackFloatingBatch : NSObject
@property(nonatomic) IDFloatingCursorStatus initial;
@property(nonatomic) IDFloatingCursorStatus normalEnd;
@property(nonatomic) IDFloatingCursorStatus extensionFirst;
@property(nonatomic) IDFloatingCursorStatus extensionCrossed;
@property(nonatomic) IDFloatingCursorStatus extensionEnd;
@property(nonatomic) IDFloatingCursorStatus quiesced;
@property(nonatomic, copy) NSString *canonical;
@property(nonatomic) BOOL complete;
@end

@implementation IDSelectionCallbackFloatingBatch
@end

@interface IDSelectionCallbackReductionUITests : XCTestCase
@end

@implementation IDSelectionCallbackReductionUITests

- (NSString *)expectedInteractionInstallationHost {
    return @"outer";
}

- (void)attachScreenshot:(XCUIScreenshot *)screenshot name:(NSString *)name {
    if (screenshot == nil) return;
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)attachString:(NSString *)string name:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:string ?: @""];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (NSDictionary<NSString *, id> *)dictionaryFromElement:(XCUIElement *)element {
    NSString *string = [element.value isKindOfClass:NSString.class]
        ? element.value : nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    id object = data == nil ? nil
        : [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:NSDictionary.class] ? object : @{};
}

- (void)assertInteractionHostTopology:(XCUIElement *)status
                          expectedHost:(NSString *)expectedHost {
    [self assertInteractionHostTopology:status
                           expectedHost:expectedHost
                         requireStable:YES];
}

- (void)assertInteractionHostTopology:(XCUIElement *)status
                          expectedHost:(NSString *)expectedHost
                        requireStable:(BOOL)requireStable {
    NSDictionary<NSString *, id> *payload = [self dictionaryFromElement:status];
    NSDictionary<NSString *, id> *topology = payload[@"interactionHostTopology"];
    XCTAssertNotNil(topology, @"status=%@", status.value);
    XCTAssertEqualObjects(topology[@"schema"], @1);
    XCTAssertEqualObjects(topology[@"installationHost"], expectedHost);
    XCTAssertEqualObjects(topology[@"liveHostCount"], @1);
    XCTAssertEqualObjects(topology[@"duplicateRecognizerIdentityCount"], @0);
    XCTAssertEqualObjects(topology[@"duplicateInteractionIdentityCount"], @0);
    if (requireStable) {
        XCTAssertEqualObjects(topology[@"stableForEpoch"], @YES);
    }
}

- (UITextView *)stockGeometryForEditor:(XCUIElement *)editor {
    UITextView *stock = [[UITextView alloc]
        initWithFrame:(CGRect){CGPointZero, editor.frame.size}];
    stock.font = [UIFont systemFontOfSize:20.0];
    stock.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [@[
        @"First wrapped paragraph contains constellation and punctuation for precise taps.",
        @"Second wrapped paragraph provides selection handles across independent blocks.",
        @"Third wrapped paragraph keeps the viewport tall enough for controlled scrolling."
    ] componentsJoinedByString:@"\n"];
    [stock layoutIfNeeded];
    return stock;
}

- (CGPoint)pointAtOffset:(NSUInteger)offset inStock:(UITextView *)stock {
    UITextPosition *start = [stock positionFromPosition:stock.beginningOfDocument
                                                 offset:(NSInteger)offset];
    UITextPosition *end = [stock positionFromPosition:start offset:1];
    CGRect startCaret = [stock caretRectForPosition:start];
    CGRect endCaret = [stock caretRectForPosition:end];
    return CGPointMake((CGRectGetMidX(startCaret) + CGRectGetMidX(endCaret)) * 0.5,
                       CGRectGetMidY(startCaret));
}

- (XCUICoordinate *)coordinateInEditor:(XCUIElement *)editor point:(CGPoint)point {
    return [[editor coordinateWithNormalizedOffset:CGVectorMake(0, 0)]
        coordinateWithOffset:CGVectorMake(point.x, point.y)];
}

- (BOOL)waitForTouchStatus:(XCUIElement *)element
                   timeout:(NSTimeInterval)timeout
                 predicate:(BOOL (^)(IDTouchSelectionStatus status))predicate
                    result:(IDTouchSelectionStatus *)result
                     rects:(NSArray<NSDictionary<NSString *, id> *> **)rects {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        IDTouchSelectionStatus status = {0};
        NSArray<NSDictionary<NSString *, id> *> *parsedRects = nil;
        if (IDTouchSelectionParseStatus(element.value, &status, &parsedRects) &&
            predicate(status)) {
            if (result != NULL) *result = status;
            if (rects != NULL) *rects = parsedRects;
            return YES;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0.0);
    return NO;
}

- (NSDictionary<NSString *, id> *)selectionCallbackAuthorizationFixture {
    NSString *uitests = [@(__FILE__) stringByDeletingLastPathComponent];
    NSString *root = [uitests stringByDeletingLastPathComponent];
    NSString *path = [root stringByAppendingPathComponent:
        @"Tests/Fixtures/SelectionCallbackAuthorization-iOS26.5.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    return data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (void)assertReducedSurfaceStatus:(XCUIElement *)status
                           refresh:(XCUIElement *)refresh {
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([refresh waitForExistenceWithTimeout:4.0]);
    if (!status.exists || !refresh.exists) return;
    NSDictionary<NSString *, id> *before = [self dictionaryFromElement:status];
    [self attachString:status.value name:@"selection-callback-reduced-surface-status"];
    XCTAssertEqualObjects(before[@"schema"], @5);
    XCTAssertEqualObjects([NSSet setWithArray:before.allKeys],
        ([NSSet setWithArray:@[
            @"schema", @"responds", @"container", @"editingLookup",
            @"visualSelectionLookup", @"internalControllerLookup",
            @"editorState"
        ]]));
    NSDictionary<NSString *, NSNumber *> *responds = before[@"responds"];
    NSDictionary<NSString *, id> *fixture =
        [self selectionCallbackAuthorizationFixture];
    XCTAssertNotNil(fixture);
    for (NSDictionary<NSString *, id> *row in fixture[@"callbacks"]) {
        NSString *name = row[@"selector"];
        BOOL expected = ![row[@"authorization"] isEqual:@"safeFallback"];
        XCTAssertEqual([responds[name] boolValue], expected, @"selector=%@", name);
    }
    XCTAssertEqualObjects(before[@"container"][@"created"], @1);
    XCTAssertEqualObjects(before[@"container"][@"stable"], @YES);
    NSDictionary<NSString *, id> *editingLookup = before[@"editingLookup"];
    XCTAssertEqualObjects([NSSet setWithArray:editingLookup.allKeys],
        ([NSSet setWithArray:@[
            @"selector", @"localProvider", @"responds",
            @"resolvedMatchesDirectSuperclass", @"resolvedOwner"
        ]]));
    XCTAssertEqualObjects(editingLookup[@"selector"], @"isEditing");
    XCTAssertEqualObjects(editingLookup[@"localProvider"], @NO);
    XCTAssertEqualObjects(editingLookup[@"resolvedMatchesDirectSuperclass"], @YES);
    XCTAssertEqualObjects(editingLookup[@"resolvedOwner"], @"directSuperclass");
    XCTAssertEqualObjects(editingLookup[@"responds"], @YES);

    NSDictionary<NSString *, id> *visualLookup = before[@"visualSelectionLookup"];
    XCTAssertEqualObjects([NSSet setWithArray:visualLookup.allKeys],
        ([NSSet setWithArray:@[
            @"selector", @"localProvider", @"responds",
            @"resolvedMatchesDirectSuperclass", @"resolvedOwner",
            @"richControllerLocalProvider"
        ]]));
    XCTAssertEqualObjects(visualLookup[@"selector"],
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    XCTAssertEqualObjects(visualLookup[@"localProvider"], @NO);
    XCTAssertEqualObjects(visualLookup[@"responds"], @NO);
    XCTAssertEqualObjects(visualLookup[@"resolvedMatchesDirectSuperclass"], @NO);
    XCTAssertEqualObjects(visualLookup[@"resolvedOwner"], @"none");
    XCTAssertEqualObjects(visualLookup[@"richControllerLocalProvider"], @YES);

    NSDictionary<NSString *, id> *internalLookup =
        before[@"internalControllerLookup"];
    XCTAssertEqualObjects([NSSet setWithArray:internalLookup.allKeys],
        ([NSSet setWithArray:@[
            @"selector", @"localProvider", @"responds",
            @"resolvedMatchesDirectSuperclass", @"resolvedOwner",
            @"textLayoutControllerLocalProvider"
        ]]));
    XCTAssertEqualObjects(internalLookup[@"selector"],
                          @"_internalTextLayoutController");
    XCTAssertEqualObjects(internalLookup[@"localProvider"], @NO);
    XCTAssertEqualObjects(internalLookup[@"responds"], @NO);
    XCTAssertEqualObjects(internalLookup[@"resolvedMatchesDirectSuperclass"],
                          @NO);
    XCTAssertEqualObjects(internalLookup[@"resolvedOwner"], @"none");
    XCTAssertEqualObjects(internalLookup[@"textLayoutControllerLocalProvider"],
                          @YES);

    NSDictionary<NSString *, id> *editorState = before[@"editorState"];
    XCTAssertEqualObjects([NSSet setWithArray:editorState.allKeys],
        ([NSSet setWithArray:@[
            @"firstResponder", @"editable", @"selectable",
            @"selectionLocation", @"selectionLength", @"scenario", @"phase"
        ]]));
    XCTAssertTrue([editorState[@"firstResponder"] isKindOfClass:NSNumber.class]);
    XCTAssertTrue([editorState[@"editable"] isKindOfClass:NSNumber.class]);
    XCTAssertTrue([editorState[@"selectable"] isKindOfClass:NSNumber.class]);
    XCTAssertGreaterThanOrEqual([editorState[@"selectionLocation"] integerValue], 0);
    XCTAssertGreaterThanOrEqual([editorState[@"selectionLength"] integerValue], 0);
    XCTAssertFalse([editorState[@"scenario"] isEqualToString:@"none"]);
    NSString *expectedPhase = [editorState[@"firstResponder"] boolValue]
        ? @"focused"
        : @"attached";
    XCTAssertEqualObjects(editorState[@"phase"], expectedPhase);
    [refresh tap];
    NSDictionary<NSString *, id> *after = [self dictionaryFromElement:status];
    XCTAssertEqualObjects(after, before);
}

- (void)assertReducedSurfaceLifecycleStatus:(XCUIElement *)status
                                     refresh:(XCUIElement *)refresh
                                 touchStatus:(XCUIElement *)touchStatus
                                       phase:(NSString *)phase
                               refreshStatus:(BOOL)refreshStatus
                              firstResponder:(BOOL)firstResponder
                                    editable:(BOOL)editable
                                  selectable:(BOOL)selectable {
    XCTAssertTrue([status waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([refresh waitForExistenceWithTimeout:4.0]);
    if (!status.exists || !refresh.exists) return;
    if (refreshStatus) [refresh tap];

    NSDictionary<NSString *, id> *snapshot = [self dictionaryFromElement:status];
    [self attachString:status.value
                  name:[NSString stringWithFormat:
                      @"selection-callback-reduced-surface-%@", phase]];
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                     name:[NSString stringWithFormat:
                         @"selection-callback-reduced-surface-%@", phase]];
    XCTAssertEqualObjects(snapshot[@"schema"], @5, @"phase=%@", phase);
    NSDictionary<NSString *, id> *lookup = snapshot[@"editingLookup"];
    XCTAssertEqualObjects(lookup[@"selector"], @"isEditing", @"phase=%@", phase);
    XCTAssertEqualObjects(lookup[@"responds"], @YES, @"phase=%@", phase);
    XCTAssertEqualObjects(lookup[@"localProvider"], @NO, @"phase=%@", phase);
    XCTAssertEqualObjects(lookup[@"resolvedMatchesDirectSuperclass"], @YES,
                          @"phase=%@", phase);
    XCTAssertEqualObjects(lookup[@"resolvedOwner"], @"directSuperclass",
                          @"phase=%@", phase);
    NSDictionary<NSString *, id> *visualLookup =
        snapshot[@"visualSelectionLookup"];
    XCTAssertEqualObjects(visualLookup[@"selector"],
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:",
        @"phase=%@", phase);
    XCTAssertEqualObjects(visualLookup[@"localProvider"], @NO,
                          @"phase=%@", phase);
    XCTAssertEqualObjects(visualLookup[@"responds"], @NO,
                          @"phase=%@", phase);
    XCTAssertEqualObjects(visualLookup[@"resolvedOwner"], @"none",
                          @"phase=%@", phase);
    XCTAssertEqualObjects(visualLookup[@"richControllerLocalProvider"], @YES,
                          @"phase=%@", phase);
    NSDictionary<NSString *, id> *internalLookup =
        snapshot[@"internalControllerLookup"];
    XCTAssertEqualObjects(internalLookup[@"selector"],
                          @"_internalTextLayoutController", @"phase=%@", phase);
    XCTAssertEqualObjects(internalLookup[@"localProvider"], @NO,
                          @"phase=%@", phase);
    XCTAssertEqualObjects(internalLookup[@"responds"], @NO,
                          @"phase=%@", phase);
    XCTAssertEqualObjects(internalLookup[@"resolvedOwner"], @"none",
                          @"phase=%@", phase);
    XCTAssertEqualObjects(internalLookup[@"textLayoutControllerLocalProvider"],
                          @YES, @"phase=%@", phase);

    NSDictionary<NSString *, id> *editorState = snapshot[@"editorState"];
    XCTAssertEqualObjects(editorState[@"firstResponder"], @(firstResponder),
                          @"phase=%@ state=%@", phase, editorState);
    XCTAssertEqualObjects(editorState[@"editable"], @(editable),
                          @"phase=%@ state=%@", phase, editorState);
    XCTAssertEqualObjects(editorState[@"selectable"], @(selectable),
                          @"phase=%@ state=%@", phase, editorState);
    XCTAssertEqualObjects(editorState[@"scenario"], @"touch-ltr",
                          @"phase=%@", phase);
    XCTAssertEqualObjects(editorState[@"phase"],
                          firstResponder ? @"focused" : @"attached",
                          @"phase=%@ state=%@", phase, editorState);

    IDTouchSelectionStatus touch = {0};
    XCTAssertTrue(IDTouchSelectionParseStatus(touchStatus.value, &touch, NULL),
                  @"phase=%@ touch=%@", phase, touchStatus.value);
    XCTAssertEqual([editorState[@"selectionLocation"] unsignedIntegerValue],
                   touch.selection.location, @"phase=%@", phase);
    XCTAssertEqual([editorState[@"selectionLength"] unsignedIntegerValue],
                   touch.selection.length, @"phase=%@", phase);
    [self assertInteractionHostTopology:touchStatus
                           expectedHost:self.expectedInteractionInstallationHost
                         requireStable:NO];
}

- (BOOL)waitForKeyboardCount:(NSUInteger)count
                 application:(XCUIApplication *)application
                     timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        if (application.keyboards.count == count) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0.0);
    return application.keyboards.count == count;
}

- (XCUIApplication *)launchTouchReducedSurfaceApplication {
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", @"touch-ltr",
        @"--id-selection-callback-reduced-surface"
    ];
    [application launch];
    return application;
}

- (void)testBatchedTouchChromeForReducedPrivateSurface {
    XCUIApplication *application = [self launchTouchReducedSurfaceApplication];
    XCUIElementQuery *elements =
        [application descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *editor = elements[@"block-text-view"];
    XCUIElement *touchStatus = elements[@"touch-status"];
    XCUIElement *reducedSurfaceStatus =
        elements[@"selection-callback-reduced-surface-status"];
    XCUIElement *refresh = elements[@"selection-callback-reduced-surface-refresh"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([touchStatus waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([reducedSurfaceStatus waitForExistenceWithTimeout:1.0]);
    if (!editor.exists || !touchStatus.exists || !reducedSurfaceStatus.exists) return;
    [self attachString:touchStatus.value name:@"reduced-surface-touch-topology-initial"];
    [self assertInteractionHostTopology:touchStatus
                           expectedHost:self.expectedInteractionInstallationHost];

    UITextView *stock = [self stockGeometryForEditor:editor];
    NSRange word = [stock.text rangeOfString:@"constellation"];
    XCTAssertNotEqual(word.location, NSNotFound);
    NSUInteger probeOffset = word.location + 2;
    CGPoint wordPoint = [self pointAtOffset:probeOffset inStock:stock];
    UITextPosition *probe = [stock positionFromPosition:stock.beginningOfDocument
                                                 offset:(NSInteger)probeOffset];
    UITextRange *token = [stock.tokenizer
        rangeEnclosingPosition:probe
               withGranularity:UITextGranularityWord
                   inDirection:UITextStorageDirectionForward];
    NSInteger expectedLocation = [stock offsetFromPosition:stock.beginningOfDocument
                                                toPosition:token.start];
    NSInteger expectedLength = [stock offsetFromPosition:token.start
                                               toPosition:token.end];
    NSRange expected = NSMakeRange((NSUInteger)expectedLocation,
                                   (NSUInteger)expectedLength);

    [editor tap];
    IDTouchSelectionStatus focused = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return status.selection.length == 0 && status.containerStable;
        } result:&focused rects:NULL]);
    [[self coordinateInEditor:editor point:wordPoint] tap];
    IDTouchSelectionStatus inserted = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return status.selection.length == 0 &&
                !NSEqualRanges(status.selection, focused.selection);
        } result:&inserted rects:NULL]);

    [NSThread sleepForTimeInterval:1.0];
    [[self coordinateInEditor:editor point:wordPoint] doubleTap];
    IDTouchSelectionStatus selected = {0};
    NSArray<NSDictionary<NSString *, id> *> *rects = nil;
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return NSEqualRanges(status.selection, expected);
        } result:&selected rects:&rects], @"status=%@", touchStatus.value);
    [NSThread sleepForTimeInterval:0.3];
    XCUIScreenshot *handlesScreenshot = XCUIScreen.mainScreen.screenshot;
    [self attachScreenshot:handlesScreenshot name:@"reduced-surface-touch-handles"];
    XCTAssertTrue(IDTouchSelectionHighlightIsVisible(
                      handlesScreenshot, rects, selected, editor.frame),
                  @"Native selection highlight must remain visible");
    CGRect leading = IDTouchSelectionMatchedHandle(
        YES, rects, selected, editor.frame, handlesScreenshot, 8.0);
    CGRect trailing = IDTouchSelectionMatchedHandle(
        NO, rects, selected, editor.frame, handlesScreenshot, 8.0);
    XCTAssertFalse(CGRectIsNull(leading));
    XCTAssertFalse(CGRectIsNull(trailing));
    XCTAssertFalse(CGRectEqualToRect(leading, trailing));
    [self assertInteractionHostTopology:touchStatus
                           expectedHost:self.expectedInteractionInstallationHost];

    CGFloat trailingRadius = CGRectGetWidth(trailing) * 0.5;
    CGPoint trailingScreen = CGPointMake(
        CGRectGetMidX(trailing), CGRectGetMaxY(trailing) - trailingRadius);
    XCUICoordinate *trailingCoordinate =
        [[editor coordinateWithNormalizedOffset:CGVectorMake(0, 0)]
            coordinateWithOffset:CGVectorMake(
                trailingScreen.x - CGRectGetMinX(editor.frame),
                trailingScreen.y - CGRectGetMinY(editor.frame))];
    CGPoint targetPoint = [self pointAtOffset:NSMaxRange(expected) + 8 inStock:stock];
    [trailingCoordinate pressForDuration:0.1
                   thenDragToCoordinate:[self coordinateInEditor:editor point:targetPoint]
                            withVelocity:XCUIGestureVelocitySlow
                     thenHoldForDuration:0.3];
    IDTouchSelectionStatus dragged = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return status.selection.length > 0 &&
                !NSEqualRanges(status.selection, selected.selection);
        } result:&dragged rects:NULL]);
    XCTAssertEqual(dragged.selection.location, selected.selection.location);
    XCTAssertTrue(dragged.containerStable);
    [refresh tap];

    XCUICoordinate *collapse = [self coordinateInEditor:editor point:targetPoint];
    [collapse tap];
    IDTouchSelectionStatus collapsed = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return status.selection.length == 0;
        } result:&collapsed rects:NULL]);
    [self assertInteractionHostTopology:touchStatus
                           expectedHost:self.expectedInteractionInstallationHost];
    XCUIScreenshot *loupeBaseline = XCUIScreen.mainScreen.screenshot;
    CGPoint loupePoint = [self pointAtOffset:NSMaxRange(expected) + 12 inStock:stock];
    XCUICoordinate *loupeDestination =
        [self coordinateInEditor:editor point:loupePoint];
    CGPoint destinationScreen = loupeDestination.screenPoint;
    CGRect loupeSearch = CGRectIntersection(
        (CGRect){CGPointZero, loupeBaseline.image.size},
        CGRectMake(destinationScreen.x - 100.0,
                   destinationScreen.y - 200.0, 200.0, 200.0));
    dispatch_semaphore_t observed = dispatch_semaphore_create(0);
    __block XCUIScreenshot *heldLoupe = nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:4.0];
        do {
            XCUIScreenshot *candidate = XCUIScreen.mainScreen.screenshot;
            CGRect region = IDTouchSelectionLargestChangedRegion(
                loupeBaseline, candidate, loupeSearch, 12);
            if (IDTouchSelectionIsLoupeSizedRegion(region)) {
                heldLoupe = candidate;
                break;
            }
            [NSThread sleepForTimeInterval:0.1];
        } while (deadline.timeIntervalSinceNow > 0.0);
        dispatch_semaphore_signal(observed);
    });
    [collapse pressForDuration:0.8
         thenDragToCoordinate:loupeDestination
                  withVelocity:XCUIGestureVelocitySlow
           thenHoldForDuration:1.5];
    XCTAssertEqual(dispatch_semaphore_wait(
        observed, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    XCTAssertNotNil(heldLoupe);
    if (heldLoupe != nil) {
        [self attachScreenshot:heldLoupe name:@"reduced-surface-touch-loupe"];
        XCTAssertTrue(IDTouchSelectionIsLoupeSizedRegion(
            IDTouchSelectionLargestChangedRegion(
                loupeBaseline, heldLoupe, loupeSearch, 12)));
    }

    [NSThread sleepForTimeInterval:0.5];
    [[self coordinateInEditor:editor point:wordPoint] doubleTap];
    IDTouchSelectionStatus beforeScroll = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return status.selection.length > 0;
        } result:&beforeScroll rects:NULL]);
    [editor swipeUp];
    IDTouchSelectionStatus afterScroll = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return status.containerStable && status.containerCreations == 1;
        } result:&afterScroll rects:NULL]);
    XCTAssertEqual(afterScroll.containerCreations, beforeScroll.containerCreations);
    [self assertReducedSurfaceStatus:reducedSurfaceStatus refresh:refresh];
    [self attachString:touchStatus.value name:@"reduced-surface-touch-topology-refreshed"];
    [self assertInteractionHostTopology:touchStatus
                           expectedHost:self.expectedInteractionInstallationHost];
}

- (IDSelectionCallbackFloatingBatch *)runFloatingBatch:
        (XCUIApplication *)application
                                                     editor:(XCUIElement *)editor
                                                     status:(XCUIElement *)status
                                                       host:(NSString *)host {
    IDSelectionCallbackFloatingBatch *batch =
        [IDSelectionCallbackFloatingBatch new];
    NSString *canonical = nil;
    IDFloatingCursorStatus initial = {0};
    BOOL initialReady = IDFloatingCursorWaitForStatus(status, 4.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.firstResponder && sample.selection.length == 0 &&
                sample.containerStable && sample.containerCreations == 1;
        }, &initial, &canonical);
    XCTAssertTrue(initialReady, @"host=%@ status=%@", host, status.value);
    if (!initialReady) {
        [self attachString:[status.value description]
                      name:[host stringByAppendingString:
                          @"-reduced-surface-floating-initial-divergence"]];
        return batch;
    }
    batch.initial = initial;
    batch.canonical = canonical;
    CGRect spacebar = IDFloatingCursorSpacebarFrame(self, application);
    XCTAssertFalse(CGRectIsNull(spacebar));
    if (CGRectIsNull(spacebar)) return batch;
    CGPoint center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    CGPoint normalDestination = CGPointMake(center.x + 48.0, center.y - 18.0);
    IDHIDTouchPath *normal = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:center startOffset:0.0 waypoints:@[
            [IDHIDTouchWaypoint moveTo:center offset:0.55],
            [IDHIDTouchWaypoint moveTo:normalDestination offset:1.15],
            [IDHIDTouchWaypoint moveTo:normalDestination offset:1.55],
            [IDHIDTouchWaypoint liftAtOffset:1.80]
        ]];
    NSError *error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(self, application, @[normal], &error),
                  @"%@ host=%@", error, host);
    NSString *normalCanonical = nil;
    IDFloatingCursorStatus normalEnd = {0};
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 3.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.selection.length == 0 && sample.containerStable &&
                !NSEqualRanges(sample.selection, batch.initial.selection);
        }, &normalEnd, &normalCanonical), @"host=%@ status=%@", host,
        status.value);
    batch.normalEnd = normalEnd;
    XCTAssertEqualObjects(normalCanonical, canonical);

    spacebar = IDFloatingCursorSpacebarFrame(self, application);
    center = CGPointMake(CGRectGetMidX(spacebar), CGRectGetMidY(spacebar));
    CGPoint secondary = CGPointMake(
        center.x - MIN(60.0, CGRectGetWidth(spacebar) * 0.25), center.y);
    CGPoint left = CGPointMake(center.x - 48.0, center.y);
    CGPoint right = CGPointMake(center.x + 52.0, center.y);
    IDHIDTouchPath *primary = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:center startOffset:0.0 waypoints:@[
            [IDHIDTouchWaypoint moveTo:center offset:0.55],
            [IDHIDTouchWaypoint moveTo:left offset:2.40],
            [IDHIDTouchWaypoint moveTo:left offset:4.00],
            [IDHIDTouchWaypoint moveTo:right offset:5.00],
            [IDHIDTouchWaypoint moveTo:right offset:7.00],
            [IDHIDTouchWaypoint liftAtOffset:8.20]
        ]];
    IDHIDTouchPath *extension = [[IDHIDTouchPath alloc]
        initWithStartScreenPoint:secondary startOffset:0.85 waypoints:@[
            [IDHIDTouchWaypoint moveTo:secondary offset:7.80],
            [IDHIDTouchWaypoint liftAtOffset:8.00]
        ]];
    dispatch_semaphore_t captured = dispatch_semaphore_create(0);
    __block BOOL firstParsed = NO;
    __block BOOL crossedParsed = NO;
    __block IDFloatingCursorStatus first = {0};
    __block IDFloatingCursorStatus crossed = {0};
    __block XCUIScreenshot *firstScreenshot = nil;
    __block XCUIScreenshot *crossedScreenshot = nil;
    CFTimeInterval epoch = CACurrentMediaTime();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (CACurrentMediaTime() < epoch + 3.50)
            [NSThread sleepForTimeInterval:0.01];
        firstParsed = IDFloatingCursorParseStatus(status.value, &first);
        firstScreenshot = XCUIScreen.mainScreen.screenshot;
        while (CACurrentMediaTime() < epoch + 6.50)
            [NSThread sleepForTimeInterval:0.01];
        crossedParsed = IDFloatingCursorParseStatus(status.value, &crossed);
        crossedScreenshot = XCUIScreen.mainScreen.screenshot;
        dispatch_semaphore_signal(captured);
    });
    error = nil;
    XCTAssertTrue(IDHIDSynthesizeTouchPaths(
        self, application, @[primary, extension], &error), @"%@ host=%@", error,
        host);
    XCTAssertEqual(dispatch_semaphore_wait(
        captured, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)), 0L);
    XCTAssertTrue(firstParsed);
    XCTAssertTrue(crossedParsed);
    [self attachScreenshot:firstScreenshot
                     name:[host stringByAppendingString:@"-reduced-surface-floating-left"]];
    [self attachScreenshot:crossedScreenshot
                     name:[host stringByAppendingString:@"-reduced-surface-floating-crossed"]];
    batch.extensionFirst = first;
    batch.extensionCrossed = crossed;
    XCTAssertGreaterThan(first.selection.length, 0U);
    XCTAssertGreaterThan(crossed.selection.length, 0U);
    XCTAssertFalse(NSEqualRanges(first.selection, crossed.selection));
    NSString *endedCanonical = nil;
    IDFloatingCursorStatus extensionEnd = {0};
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 3.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.selection.length > 0 && sample.containerStable;
        }, &extensionEnd, &endedCanonical));
    batch.extensionEnd = extensionEnd;
    XCTAssertEqualObjects(endedCanonical, canonical);
    [NSThread sleepForTimeInterval:0.5];
    IDFloatingCursorStatus quiesced = {0};
    XCTAssertTrue(IDFloatingCursorParseStatus(status.value, &quiesced));
    batch.quiesced = quiesced;
    XCTAssertTrue(NSEqualRanges(batch.extensionEnd.selection,
                                batch.quiesced.selection));
    XCTAssertTrue(batch.quiesced.containerStable);
    batch.complete = YES;
    return batch;
}

- (void)assertFloatingBatch:(IDSelectionCallbackFloatingBatch *)custom
                equalsStock:(IDSelectionCallbackFloatingBatch *)stock {
    XCTAssertEqualObjects(custom.canonical, stock.canonical);
    NSArray<NSValue *> *customValues = @[
        IDFloatingCursorStatusValue(custom.initial),
        IDFloatingCursorStatusValue(custom.normalEnd),
        IDFloatingCursorStatusValue(custom.extensionFirst),
        IDFloatingCursorStatusValue(custom.extensionCrossed),
        IDFloatingCursorStatusValue(custom.extensionEnd),
        IDFloatingCursorStatusValue(custom.quiesced)
    ];
    NSArray<NSValue *> *stockValues = @[
        IDFloatingCursorStatusValue(stock.initial),
        IDFloatingCursorStatusValue(stock.normalEnd),
        IDFloatingCursorStatusValue(stock.extensionFirst),
        IDFloatingCursorStatusValue(stock.extensionCrossed),
        IDFloatingCursorStatusValue(stock.extensionEnd),
        IDFloatingCursorStatusValue(stock.quiesced)
    ];
    for (NSUInteger index = 0; index < stockValues.count; index += 1) {
        IDFloatingCursorStatus expected =
            IDFloatingCursorStatusFromValue(stockValues[index]);
        IDFloatingCursorStatus actual =
            IDFloatingCursorStatusFromValue(customValues[index]);
        XCTAssertTrue(NSEqualRanges(actual.selection, expected.selection),
                      @"phase=%lu stock=%@ custom=%@", (unsigned long)index,
                      NSStringFromRange(expected.selection),
                      NSStringFromRange(actual.selection));
        XCTAssertEqual(actual.startAffinity, expected.startAffinity,
                       @"phase=%lu", (unsigned long)index);
        XCTAssertEqual(actual.endAffinity, expected.endAffinity,
                       @"phase=%lu", (unsigned long)index);
        XCTAssertTrue(actual.containerStable, @"phase=%lu", (unsigned long)index);
        XCTAssertEqual(actual.containerCreations, 1U,
                       @"phase=%lu", (unsigned long)index);
    }
}

- (XCUIApplication *)launchFloatingReducedSurfaceApplication {
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", @"floating-ltr",
        @"--id-selection-callback-reduced-surface"
    ];
    [application launch];
    return application;
}

- (void)testBatchedFloatingChromeForReducedPrivateSurface {
    XCUIApplication *custom = [self launchFloatingReducedSurfaceApplication];
    XCUIElementQuery *customElements =
        [custom descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *customEditor = customElements[@"block-text-view"];
    XCUIElement *customStatus = customElements[@"floating-status"];
    XCUIElement *reducedSurfaceStatus =
        customElements[@"selection-callback-reduced-surface-status"];
    XCUIElement *refresh =
        customElements[@"selection-callback-reduced-surface-refresh"];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([customStatus waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([reducedSurfaceStatus waitForExistenceWithTimeout:1.0]);
    if (!customEditor.exists || !customStatus.exists || !reducedSurfaceStatus.exists) {
        return;
    }
    [self attachString:customStatus.value
                  name:@"reduced-surface-floating-topology-initial"];
    [self assertInteractionHostTopology:customStatus
                           expectedHost:self.expectedInteractionInstallationHost];
    CGRect editorFrame = customEditor.frame;
    IDSelectionCallbackFloatingBatch *customBatch =
        [self runFloatingBatch:custom editor:customEditor status:customStatus
                          host:@"custom"];
    [self assertReducedSurfaceStatus:reducedSurfaceStatus refresh:refresh];
    [self attachString:customStatus.value
                  name:@"reduced-surface-floating-topology-refreshed"];
    [self assertInteractionHostTopology:customStatus
                           expectedHost:self.expectedInteractionInstallationHost];
    if (!customBatch.complete) {
        [custom terminate];
        return;
    }
    [custom terminate];

    XCUIApplication *stock =
        IDFloatingCursorLaunchStock(self, @"floating-ltr", editorFrame);
    XCUIElementQuery *stockElements =
        [stock descendantsMatchingType:XCUIElementTypeAny];
    IDSelectionCallbackFloatingBatch *stockBatch =
        [self runFloatingBatch:stock
                        editor:stockElements[@"stock-text-view"]
                        status:stockElements[@"floating-status"]
                          host:@"stock"];
    [stock terminate];
    [self assertFloatingBatch:customBatch equalsStock:stockBatch];
}

- (void)testSelectableNoneditableCopyMenuCancellationAndReentryForReducedPrivateSurface {
    XCUIApplication *application = [self launchTouchReducedSurfaceApplication];
    XCUIElementQuery *elements =
        [application descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *editor = elements[@"block-text-view"];
    XCUIElement *touchStatus = elements[@"touch-status"];
    XCUIElement *reducedSurfaceStatus =
        elements[@"selection-callback-reduced-surface-status"];
    XCUIElement *refresh =
        elements[@"selection-callback-reduced-surface-refresh"];
    XCUIElement *editable = application.buttons[@"editable-toggle"];
    XCUIElement *selectable = application.buttons[@"selectable-toggle"];
    XCTAssertTrue([editor waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([touchStatus waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([editable waitForExistenceWithTimeout:4.0]);
    XCTAssertTrue([selectable waitForExistenceWithTimeout:4.0]);
    if (!editor.exists || !touchStatus.exists || !editable.exists ||
        !selectable.exists) return;

    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"initial"
                                refreshStatus:YES
                               firstResponder:YES
                                     editable:YES
                                   selectable:YES];
    XCTAssertTrue([self waitForKeyboardCount:1
                                 application:application
                                     timeout:3.0]);

    UITextView *stock = [self stockGeometryForEditor:editor];
    NSRange word = [stock.text rangeOfString:@"constellation"];
    NSUInteger probeOffset = word.location + 2;
    CGPoint wordPoint = [self pointAtOffset:probeOffset inStock:stock];
    UITextPosition *probe = [stock positionFromPosition:stock.beginningOfDocument
                                                 offset:(NSInteger)probeOffset];
    UITextRange *token = [stock.tokenizer
        rangeEnclosingPosition:probe
               withGranularity:UITextGranularityWord
                   inDirection:UITextStorageDirectionForward];
    NSRange expected = NSMakeRange(
        (NSUInteger)[stock offsetFromPosition:stock.beginningOfDocument
                                   toPosition:token.start],
        (NSUInteger)[stock offsetFromPosition:token.start toPosition:token.end]);

    [editor tap];
    [NSThread sleepForTimeInterval:1.0];
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"focused"
                                refreshStatus:YES
                               firstResponder:YES
                                     editable:YES
                                   selectable:YES];
    [[self coordinateInEditor:editor point:wordPoint] doubleTap];
    IDTouchSelectionStatus selected = {0};
    NSArray<NSDictionary<NSString *, id> *> *rects = nil;
    BOOL initiallySelected = [self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return NSEqualRanges(status.selection, expected);
        } result:&selected rects:&rects];
    XCTAssertTrue(initiallySelected, @"status=%@ expected=%@",
                  touchStatus.value, NSStringFromRange(expected));
    if (!initiallySelected) return;

    [editable tap];
    NSPredicate *off = [NSPredicate predicateWithFormat:@"value == 'Off'"];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[
        [[XCTNSPredicateExpectation alloc] initWithPredicate:off object:editable]
    ] timeout:3.0], XCTWaiterResultCompleted);
    XCTAssertEqualObjects(selectable.value, @"On");
    BOOL preservedSelection = [self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return NSEqualRanges(status.selection, expected);
        } result:&selected rects:&rects];
    XCTAssertTrue(preservedSelection, @"status=%@ expected=%@",
                  touchStatus.value, NSStringFromRange(expected));
    if (!preservedSelection) return;
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"editable-off"
                                refreshStatus:YES
                               firstResponder:NO
                                     editable:NO
                                   selectable:YES];
    XCUIScreenshot *noneditable = XCUIScreen.mainScreen.screenshot;
    [self attachScreenshot:noneditable
                     name:@"reduced-surface-noneditable-selection-preserved"];
    XCTAssertTrue(CGRectIsNull(IDTouchSelectionMatchedHandle(
        YES, rects, selected, editor.frame, noneditable, 8.0)));
    XCTAssertTrue(CGRectIsNull(IDTouchSelectionMatchedHandle(
        NO, rects, selected, editor.frame, noneditable, 8.0)));

    [[self coordinateInEditor:editor point:wordPoint] doubleTap];
    [NSThread sleepForTimeInterval:0.5];
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return NSEqualRanges(status.selection, expected);
        } result:&selected rects:&rects]);
    XCUIScreenshot *reactivated = XCUIScreen.mainScreen.screenshot;
    XCTAssertTrue(IDTouchSelectionHighlightIsVisible(
        reactivated, rects, selected, editor.frame));
    XCTAssertFalse(CGRectIsNull(IDTouchSelectionMatchedHandle(
        YES, rects, selected, editor.frame, reactivated, 8.0)));
    XCTAssertFalse(CGRectIsNull(IDTouchSelectionMatchedHandle(
        NO, rects, selected, editor.frame, reactivated, 8.0)));

    // UIKit presents the edit menu as part of reactivating the preserved
    // noneditable selection. A subsequent long press starts a new interaction
    // and can dismiss that menu before XCTest observes it.
    XCUIElement *copy = application.menuItems[@"Copy"];
    XCTAssertTrue([copy waitForExistenceWithTimeout:3.0]);
    XCTAssertTrue(copy.hittable);
    // The status element is backed by a live provider. Do not tap the refresh
    // control while the menu is visible because that tap is itself UIKit's
    // cancellation action.
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"menu-visible"
                                refreshStatus:NO
                               firstResponder:YES
                                     editable:NO
                                   selectable:YES];
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                     name:@"reduced-surface-noneditable-copy-menu"];

    CGPoint outsidePoint = [self pointAtOffset:NSMaxRange(expected) + 16
                                       inStock:stock];
    [[self coordinateInEditor:editor point:outsidePoint] tap];
    IDTouchSelectionStatus cancelled = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return status.selection.length == 0;
        } result:&cancelled rects:NULL]);
    XCTAssertFalse(copy.exists);
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"cancelled"
                                refreshStatus:YES
                               firstResponder:YES
                                     editable:NO
                                   selectable:YES];
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                     name:@"reduced-surface-noneditable-copy-cancelled"];

    [[self coordinateInEditor:editor point:wordPoint] doubleTap];
    IDTouchSelectionStatus reentered = {0};
    XCTAssertTrue([self waitForTouchStatus:touchStatus timeout:4.0
        predicate:^BOOL(IDTouchSelectionStatus status) {
            return NSEqualRanges(status.selection, expected);
        } result:&reentered rects:NULL]);
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"reentered"
                                refreshStatus:YES
                               firstResponder:YES
                                     editable:NO
                                   selectable:YES];
    [self assertInteractionHostTopology:touchStatus
                           expectedHost:self.expectedInteractionInstallationHost
                         requireStable:NO];
    [self attachString:touchStatus.value
                  name:@"reduced-surface-noneditable-copy-reentered-status"];
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                     name:@"reduced-surface-noneditable-copy-reentered"];

    [editable tap];
    NSPredicate *on = [NSPredicate predicateWithFormat:@"value == 'On'"];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[
        [[XCTNSPredicateExpectation alloc] initWithPredicate:on object:editable]
    ] timeout:3.0], XCTWaiterResultCompleted);
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"editable-restored"
                                refreshStatus:YES
                               firstResponder:NO
                                     editable:YES
                                   selectable:YES];
    XCTAssertTrue([self waitForKeyboardCount:0
                                 application:application
                                     timeout:3.0]);

    [editor tap];
    XCTAssertTrue([self waitForKeyboardCount:1
                                 application:application
                                     timeout:3.0]);
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"editable-restored-refocused"
                                refreshStatus:YES
                               firstResponder:YES
                                     editable:YES
                                   selectable:YES];

    [editable tap];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[
        [[XCTNSPredicateExpectation alloc] initWithPredicate:off object:editable]
    ] timeout:3.0], XCTWaiterResultCompleted);
    XCTAssertTrue([self waitForKeyboardCount:0
                                 application:application
                                     timeout:3.0]);
    [self assertReducedSurfaceLifecycleStatus:reducedSurfaceStatus
                                      refresh:refresh
                                  touchStatus:touchStatus
                                        phase:@"resigned"
                                refreshStatus:YES
                               firstResponder:NO
                                     editable:NO
                                   selectable:YES];
    [application terminate];
}

- (void)testStockSelectableNoneditableCopyMenuBaseline {
    XCUIApplication *custom = [self launchTouchReducedSurfaceApplication];
    XCUIElement *customEditor =
        [custom descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCTAssertTrue([customEditor waitForExistenceWithTimeout:4.0]);
    CGRect editorFrame = customEditor.frame;
    [custom terminate];

    editorFrame.size.height -= 19.0;

    XCUIApplication *stock =
        IDFloatingCursorLaunchStock(self, @"floating-ltr", editorFrame);
    XCUIElementQuery *elements =
        [stock descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *editor = elements[@"stock-text-view"];
    XCUIElement *status = elements[@"floating-status"];
    XCUIElement *editable = stock.buttons[@"floating-editable-off"];
    XCTAssertTrue([editable waitForExistenceWithTimeout:4.0]);
    if (!editor.exists || !status.exists || !editable.exists) return;

    UITextView *geometry = [self stockGeometryForEditor:editor];
    NSRange word = [geometry.text rangeOfString:@"constellation"];
    CGPoint wordPoint = [self pointAtOffset:word.location + 2 inStock:geometry];
    [editor tap];
    [NSThread sleepForTimeInterval:1.0];
    [[self coordinateInEditor:editor point:wordPoint] doubleTap];
    IDFloatingCursorStatus selected = {0};
    NSString *canonical = nil;
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 4.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return sample.selection.length > 0;
        }, &selected, &canonical));

    [editable tap];
    IDFloatingCursorStatus noneditable = {0};
    XCTAssertTrue(IDFloatingCursorWaitForStatus(status, 4.0,
        ^BOOL(IDFloatingCursorStatus sample) {
            return NSEqualRanges(sample.selection, selected.selection) &&
                !sample.firstResponder;
        }, &noneditable, &canonical));
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                     name:@"stock-noneditable-selection"];
    [[self coordinateInEditor:editor point:wordPoint] doubleTap];
    [NSThread sleepForTimeInterval:0.5];
    XCUIElement *copy = stock.menuItems[@"Copy"];
    XCTAssertTrue([copy waitForExistenceWithTimeout:3.0]);
    XCTAssertTrue(copy.hittable);
    [self attachScreenshot:XCUIScreen.mainScreen.screenshot
                     name:@"stock-noneditable-copy-menu"];
    [stock terminate];
}

@end
