@import XCTest;

#import <objc/runtime.h>

#import "IDTextCanvasTestSupport.h"
#import "IDBlockLayout.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"

static NSArray<NSString *> *IDAllCanvasOriginSelectorNames(void) {
    return @[
        [@"invalidateTextContainer" stringByAppendingString:@"Origin"],
        [@"textContainer" stringByAppendingString:@"Origin"],
    ];
}

static NSArray<NSString *> *IDRemovableCanvasOriginSelectorNames(void) {
    return @[];
}

static NSArray<NSString *> *IDRetainedCanvasOriginSelectorNames(void) {
    NSMutableArray<NSString *> *retained =
        [IDAllCanvasOriginSelectorNames() mutableCopy];
    [retained removeObjectsInArray:IDRemovableCanvasOriginSelectorNames()];
    return retained.copy;
}

static NSArray<NSString *> *IDAllCanvasControllerGetterSelectorNames(void) {
    return @[
        [@"textLayout" stringByAppendingString:@"Controller"],
        [@"layout" stringByAppendingString:@"Manager"],
        [@"customRender" stringByAppendingString:@"Controller"],
    ];
}

static NSArray<NSString *> *IDRemovableCanvasControllerGetterSelectorNames(void) {
    return IDAllCanvasControllerGetterSelectorNames();
}

static NSArray<NSString *> *IDRetainedCanvasControllerGetterSelectorNames(void) {
    NSMutableArray<NSString *> *retained =
        [IDAllCanvasControllerGetterSelectorNames() mutableCopy];
    [retained
        removeObjectsInArray:IDRemovableCanvasControllerGetterSelectorNames()];
    return retained.copy;
}

static NSArray<NSString *> *IDAllCanvasStateGetterSelectorNames(void) {
    return @[
        [@"text" stringByAppendingString:@"Color"],
        [@"is" stringByAppendingString:@"Editable"],
        [@"is" stringByAppendingString:@"Editing"],
    ];
}

static NSArray<NSString *> *IDRemovableCanvasStateGetterSelectorNames(void) {
    return @[
        [@"text" stringByAppendingString:@"Color"],
        [@"is" stringByAppendingString:@"Editable"],
    ];
}

static NSArray<NSString *> *IDRetainedCanvasStateGetterSelectorNames(void) {
    NSMutableArray<NSString *> *retained =
        [IDAllCanvasStateGetterSelectorNames() mutableCopy];
    [retained
        removeObjectsInArray:IDRemovableCanvasStateGetterSelectorNames()];
    return retained.copy;
}

static BOOL IDClassDefinesInstanceMethod(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index++) {
        if (method_getName(methods[index]) == selector) {
            found = YES;
            break;
        }
    }
    free(methods);
    return found;
}

@interface IDUsageBoundsProbeLayoutManager : NSTextLayoutManager
@property(nonatomic) BOOL usesProbeUsageBounds;
@property(nonatomic) CGRect probeUsageBounds;
@end

@implementation IDUsageBoundsProbeLayoutManager

- (CGRect)usageBoundsForTextContainer {
    return self.usesProbeUsageBounds
        ? self.probeUsageBounds
        : super.usageBoundsForTextContainer;
}

@end

@interface IDLifecycleProbeCanvas : IDTextLayoutCanvasView
@property(nonatomic, strong) NSMutableArray<NSString *> *events;
@property(nonatomic, strong) NSTextContentStorage *retainedContentStorage;
@end

@implementation IDLifecycleProbeCanvas

- (instancetype)initWithTextLayoutManager:(NSTextLayoutManager *)layoutManager
                            textContainer:(NSTextContainer *)textContainer {
    self = [super initWithTextLayoutManager:layoutManager
                             textContainer:textContainer];
    if (self != nil) {
        _events = [NSMutableArray array];
    }
    return self;
}

- (void)id_viewportWillLayout {
    [self.events addObject:@"will"];
    [super id_viewportWillLayout];
}

- (void)id_removeUnusedElementViews {
    [self.events addObject:@"evict"];
    [super id_removeUnusedElementViews];
}

- (void)id_updateContentSizeIfNeeded {
    [self.events addObject:@"content"];
    [super id_updateContentSizeIfNeeded];
}

- (void)id_viewportDidLayout {
    [super id_viewportDidLayout];
    [self.events addObject:@"did"];
}

- (void)id_flushElementViews {
    [super id_flushElementViews];
    [self.events addObject:@"flush"];
}

@end

@interface IDTextContainerOriginContextProbe : NSObject
@property(nonatomic) CGPoint origin;
@end

@implementation IDTextContainerOriginContextProbe

- (CGPoint)textContainerOrigin {
    return self.origin;
}

@end

@interface IDCanvasTextLayoutDelegateProbe : NSObject <NSTextLayoutManagerDelegate>
@end

@implementation IDCanvasTextLayoutDelegateProbe
@end

@interface IDCanvasControllerGetterContextProbe : NSObject
@property(nonatomic, strong, nullable) id customRenderController;
@end

@implementation IDCanvasControllerGetterContextProbe
@end

@interface IDCanvasStateGetterContextProbe : NSObject
@property(nonatomic, strong) UIColor *textColor;
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, getter=isEditing) BOOL editing;
@end

@implementation IDCanvasStateGetterContextProbe
@end

@interface IDEnvironmentNotificationProbeCanvas : IDTextLayoutCanvasView
@property(nonatomic, strong) NSMutableArray<NSString *> *environmentEvents;
@property(nonatomic, assign) BOOL recordsEnvironmentEvents;
@property(nonatomic, strong) NSTextContentStorage *retainedContentStorage;
@property(nonatomic, strong) IDTextContainerOriginContextProbe *retainedOriginContext;
@end

@implementation IDEnvironmentNotificationProbeCanvas

- (void)setNeedsLayout {
    if (self.recordsEnvironmentEvents) {
        [self.environmentEvents addObject:@"layout"];
    }
    [super setNeedsLayout];
}

- (void)setNeedsDisplay {
    if (self.recordsEnvironmentEvents) {
        [self.environmentEvents addObject:@"display"];
    }
    [super setNeedsDisplay];
}

- (void)viewportBoundsDidChange {
    if (self.recordsEnvironmentEvents) {
        [self.environmentEvents addObject:@"viewport"];
    }
    [super viewportBoundsDidChange];
}

@end

@interface IDTextLayoutCanvasViewTests : XCTestCase
@end

@implementation IDTextLayoutCanvasViewTests

- (void)testClassifiedAttachmentCallbacksAreAbsentFromProjectReceivers {
    NSArray<NSString *> *names = @[
        [[@"didLayoutTextAttachmentView" stringByAppendingString:@":inFragment"]
            stringByAppendingString:@"Rect:"],
        [@"didAddTextAttachment" stringByAppendingString:@"Views:"],
        [@"didRemoveTextAttachment" stringByAppendingString:@"Views:"],
    ];
    NSArray<Class> *classes = @[
        IDTextLayoutCanvasView.class,
        IDTextView.class,
        IDBlockLayout.class,
    ];
    for (NSString *name in names) {
        SEL selector = NSSelectorFromString(name);
        for (Class cls in classes) {
            XCTAssertFalse(IDClassDefinesInstanceMethod(cls, selector),
                           @"%@ unexpectedly owns %@", cls, name);
        }
    }
}

- (void)testAnchoredAttachmentFrameCallbackIsAbsentFromCanvasReceiver {
    NSString *name = [[@"frameForAnchoredText" stringByAppendingString:@"Attachment:"]
        stringByAppendingString:@"associatedLayoutFragment:"];
    XCTAssertFalse(IDClassDefinesInstanceMethod(IDTextLayoutCanvasView.class,
                                                NSSelectorFromString(name)));
}

- (IDLifecycleProbeCanvas *)lifecycleProbeWithText:(NSString *)text
                                              size:(CGSize)size {
    NSTextContentStorage *contentStorage = [NSTextContentStorage new];
    contentStorage.textStorage = [[NSTextStorage alloc]
        initWithString:text
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                NSForegroundColorAttributeName: UIColor.labelColor,
            }];
    NSTextLayoutManager *layoutManager = [NSTextLayoutManager new];
    [contentStorage addTextLayoutManager:layoutManager];
    NSTextContainer *textContainer = [[NSTextContainer alloc]
        initWithSize:CGSizeMake(MAX(size.width, 0), CGFLOAT_MAX)];
    layoutManager.textContainer = textContainer;
    IDLifecycleProbeCanvas *canvas = [[IDLifecycleProbeCanvas alloc]
        initWithTextLayoutManager:layoutManager
                   textContainer:textContainer];
    canvas.frame = (CGRect){CGPointZero, size};
    canvas.retainedContentStorage = contentStorage;
    return canvas;
}

- (IDLifecycleProbeCanvas *)usageProbeWithLayoutManager:
        (IDUsageBoundsProbeLayoutManager * _Nullable * _Nullable)managerOut {
    NSTextContentStorage *contentStorage = [NSTextContentStorage new];
    contentStorage.textStorage =
        [[NSTextStorage alloc] initWithString:@"probe"
                                  attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:17.0],
            NSForegroundColorAttributeName: UIColor.labelColor,
        }];
    IDUsageBoundsProbeLayoutManager *layoutManager =
        [IDUsageBoundsProbeLayoutManager new];
    [contentStorage addTextLayoutManager:layoutManager];
    NSTextContainer *textContainer =
        [[NSTextContainer alloc] initWithSize:CGSizeMake(200, CGFLOAT_MAX)];
    layoutManager.textContainer = textContainer;
    IDLifecycleProbeCanvas *canvas = [[IDLifecycleProbeCanvas alloc]
        initWithTextLayoutManager:layoutManager
                   textContainer:textContainer];
    canvas.frame = CGRectMake(0, 0, 200, 80);
    canvas.retainedContentStorage = contentStorage;
    if (managerOut != NULL) {
        *managerOut = layoutManager;
    }
    return canvas;
}

- (IDEnvironmentNotificationProbeCanvas *)environmentProbeWithText:(NSString *)text
                                                               size:(CGSize)size {
    NSTextContentStorage *contentStorage = [NSTextContentStorage new];
    contentStorage.textStorage = [[NSTextStorage alloc]
        initWithString:text
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                NSForegroundColorAttributeName: UIColor.labelColor,
            }];
    NSTextLayoutManager *layoutManager = [NSTextLayoutManager new];
    [contentStorage addTextLayoutManager:layoutManager];
    NSTextContainer *textContainer = [[NSTextContainer alloc]
        initWithSize:CGSizeMake(MAX(size.width, 0), CGFLOAT_MAX)];
    layoutManager.textContainer = textContainer;
    IDEnvironmentNotificationProbeCanvas *canvas =
        [[IDEnvironmentNotificationProbeCanvas alloc]
            initWithTextLayoutManager:layoutManager
                       textContainer:textContainer];
    canvas.frame = (CGRect){CGPointZero, size};
    canvas.retainedContentStorage = contentStorage;
    canvas.environmentEvents = [NSMutableArray array];
    canvas.recordsEnvironmentEvents = YES;
    return canvas;
}

- (void)testProjectTextContainerOriginUsesExactContextValueAndNilFallback {
    IDEnvironmentNotificationProbeCanvas *canvas =
        [self environmentProbeWithText:@"origin" size:CGSizeMake(220, 80)];
    IDTextContainerOriginContextProbe *context =
        [IDTextContainerOriginContextProbe new];
    context.origin = CGPointMake(13.25, 17.75);
    canvas.retainedOriginContext = context;
    canvas.context = context;

    XCTAssertTrue(CGPointEqualToPoint([canvas id_textContainerOrigin],
                                      context.origin));

    canvas.context = nil;
    canvas.retainedOriginContext = nil;
    XCTAssertTrue(CGPointEqualToPoint([canvas id_textContainerOrigin],
                                      CGPointZero));
}

- (void)testProjectTextContainerOriginInvalidationRequestsOneLayout {
    IDEnvironmentNotificationProbeCanvas *canvas =
        [self environmentProbeWithText:@"invalidate" size:CGSizeMake(220, 80)];

    [canvas id_invalidateTextContainerOrigin];

    XCTAssertEqualObjects(canvas.environmentEvents, (@[@"layout"]));
}

- (void)testProjectTextLayoutControllerGetterTracksExactLayoutManagerDelegate {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"controller" size:CGSizeMake(220, 80)];
    IDCanvasTextLayoutDelegateProbe *delegate =
        [IDCanvasTextLayoutDelegateProbe new];

    fixture.layoutManager.delegate = delegate;
    XCTAssertEqual([fixture.canvas id_textLayoutController], delegate);
    XCTAssertEqual(fixture.canvas.textLayoutManager.delegate, delegate);

    fixture.layoutManager.delegate = nil;
    XCTAssertNil([fixture.canvas id_textLayoutController]);
}

- (void)testProjectLayoutManagerGetterRemainsNilWhileCanvasOwnsLiveManager {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"layout manager" size:CGSizeMake(220, 80)];

    XCTAssertNotNil(fixture.canvas.textLayoutManager);
    XCTAssertEqual(fixture.canvas.textLayoutManager, fixture.layoutManager);
    XCTAssertNil([fixture.canvas id_layoutManager]);

    [fixture.canvas performViewportLayout];

    XCTAssertEqual(fixture.canvas.textLayoutManager, fixture.layoutManager);
    XCTAssertNil([fixture.canvas id_layoutManager]);
}

- (void)testProjectCustomRenderControllerGetterTracksExactOptionalContextValue {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"renderer" size:CGSizeMake(220, 80)];
    IDCanvasControllerGetterContextProbe *context =
        [IDCanvasControllerGetterContextProbe new];
    NSObject *renderer = [NSObject new];
    context.customRenderController = renderer;
    fixture.canvas.context = context;

    XCTAssertEqual([fixture.canvas id_customRenderController], renderer);

    context.customRenderController = nil;
    XCTAssertNil([fixture.canvas id_customRenderController]);

    fixture.canvas.context = nil;
    XCTAssertNil([fixture.canvas id_customRenderController]);
}

- (void)testProjectTextColorGetterTracksExactContextValueAndNilFallback {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"color" size:CGSizeMake(220, 80)];
    IDCanvasStateGetterContextProbe *context =
        [IDCanvasStateGetterContextProbe new];
    context.textColor = UIColor.systemOrangeColor;
    fixture.canvas.context = context;

    XCTAssertEqualObjects([fixture.canvas id_textColor],
                          UIColor.systemOrangeColor);

    context.textColor = UIColor.systemPurpleColor;
    XCTAssertEqualObjects([fixture.canvas id_textColor],
                          UIColor.systemPurpleColor);

    fixture.canvas.context = nil;
    XCTAssertEqualObjects([fixture.canvas id_textColor], UIColor.labelColor);
}

- (void)testProjectEditableGetterTracksContextIndependentlyOfEditing {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"editable" size:CGSizeMake(220, 80)];
    IDCanvasStateGetterContextProbe *context =
        [IDCanvasStateGetterContextProbe new];
    context.textColor = UIColor.labelColor;
    context.editable = YES;
    context.editing = NO;
    fixture.canvas.context = context;

    XCTAssertTrue([fixture.canvas id_isEditable]);
    XCTAssertFalse([fixture.canvas id_isEditing]);

    context.editable = NO;
    context.editing = YES;
    XCTAssertFalse([fixture.canvas id_isEditable]);
    XCTAssertTrue([fixture.canvas id_isEditing]);

    fixture.canvas.context = nil;
    XCTAssertFalse([fixture.canvas id_isEditable]);
    XCTAssertFalse([fixture.canvas id_isEditing]);
}

- (void)testProjectEditingGetterAllowsNonparticipatingContextFallback {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"editing" size:CGSizeMake(220, 80)];
    IDCanvasControllerGetterContextProbe *context =
        [IDCanvasControllerGetterContextProbe new];
    fixture.canvas.context = context;

    XCTAssertFalse([fixture.canvas id_isEditing]);
}

- (void)testCanvasControllerGetterClassificationPartitionsExactTriple {
    NSSet<NSString *> *all =
        [NSSet setWithArray:IDAllCanvasControllerGetterSelectorNames()];
    NSSet<NSString *> *removable =
        [NSSet setWithArray:
            IDRemovableCanvasControllerGetterSelectorNames()];
    NSSet<NSString *> *retained =
        [NSSet setWithArray:
            IDRetainedCanvasControllerGetterSelectorNames()];
    NSMutableSet<NSString *> *intersection = [removable mutableCopy];
    [intersection intersectSet:retained];
    NSMutableSet<NSString *> *unionSet = [removable mutableCopy];
    [unionSet unionSet:retained];

    XCTAssertEqualObjects(intersection, [NSSet set]);
    XCTAssertEqualObjects(unionSet, all);
    XCTAssertEqual(all.count, 3U);
}

- (void)testCanvasExposesNoRemovableControllerGetterSelectors {
    for (NSString *name in
             IDRemovableCanvasControllerGetterSelectorNames()) {
        SEL selector = NSSelectorFromString(name);
        XCTAssertFalse([IDTextLayoutCanvasView
            instancesRespondToSelector:selector], @"%@", name);
        XCTAssertTrue(class_getInstanceMethod(IDTextLayoutCanvasView.class,
                                              selector) == NULL, @"%@", name);
    }
}

- (void)testRetainedCanvasControllerGetterSelectorsPreserveRuntimeABI {
    for (NSString *name in
             IDRetainedCanvasControllerGetterSelectorNames()) {
        SEL selector = NSSelectorFromString(name);
        NSMethodSignature *signature =
            [IDTextLayoutCanvasView
                instanceMethodSignatureForSelector:selector];
        XCTAssertNotNil(
            signature,
            @"Retained by UIKitCore/UIFoundation caller: %@",
            name);
        XCTAssertEqual(signature.numberOfArguments, 2U, @"%@", name);
        XCTAssertEqual(strcmp(signature.methodReturnType, @encode(id)),
                       0, @"%@", name);
    }
}

- (void)testCanvasStateGetterClassificationPartitionsExactTriple {
    NSSet<NSString *> *all =
        [NSSet setWithArray:IDAllCanvasStateGetterSelectorNames()];
    NSSet<NSString *> *removable =
        [NSSet setWithArray:IDRemovableCanvasStateGetterSelectorNames()];
    NSSet<NSString *> *retained =
        [NSSet setWithArray:IDRetainedCanvasStateGetterSelectorNames()];
    NSMutableSet<NSString *> *intersection = [removable mutableCopy];
    [intersection intersectSet:retained];
    NSMutableSet<NSString *> *unionSet = [removable mutableCopy];
    [unionSet unionSet:retained];

    XCTAssertEqualObjects(intersection, [NSSet set]);
    XCTAssertEqualObjects(unionSet, all);
    XCTAssertEqual(all.count, 3U);
}

- (void)testCanvasOwnsNoRemovableStateGetterSelectors {
    for (NSString *name in IDRemovableCanvasStateGetterSelectorNames()) {
        SEL selector = NSSelectorFromString(name);
        XCTAssertFalse(
            IDClassDefinesInstanceMethod(IDTextLayoutCanvasView.class,
                                         selector),
            @"%@", name);

        Method inherited = class_getInstanceMethod(
            class_getSuperclass(IDTextLayoutCanvasView.class), selector);
        Method resolved =
            class_getInstanceMethod(IDTextLayoutCanvasView.class, selector);
        if (inherited == NULL) {
            XCTAssertTrue(resolved == NULL, @"%@", name);
            XCTAssertFalse([IDTextLayoutCanvasView
                instancesRespondToSelector:selector], @"%@", name);
        } else {
            XCTAssertTrue(resolved != NULL, @"%@", name);
            XCTAssertEqual(method_getImplementation(resolved),
                           method_getImplementation(inherited), @"%@", name);
        }
    }
}

- (void)testRetainedCanvasStateGetterSelectorsPreserveRuntimeABI {
    NSSet<NSString *> *objectReturns =
        [NSSet setWithObject:[@"text" stringByAppendingString:@"Color"]];
    for (NSString *name in IDRetainedCanvasStateGetterSelectorNames()) {
        SEL selector = NSSelectorFromString(name);
        XCTAssertTrue(
            IDClassDefinesInstanceMethod(IDTextLayoutCanvasView.class,
                                         selector),
            @"Externally required canvas override: %@", name);
        NSMethodSignature *signature =
            [IDTextLayoutCanvasView
                instanceMethodSignatureForSelector:selector];
        XCTAssertNotNil(signature,
                       @"Retained by UIKitCore/UIFoundation caller: %@",
                       name);
        XCTAssertEqual(signature.numberOfArguments, 2U, @"%@", name);
        const char *expected = [objectReturns containsObject:name]
            ? @encode(id)
            : @encode(BOOL);
        XCTAssertEqual(strcmp(signature.methodReturnType, expected), 0,
                       @"%@", name);
    }
}

- (void)testCanvasOriginSelectorClassificationPartitionsExactPair {
    NSSet<NSString *> *all =
        [NSSet setWithArray:IDAllCanvasOriginSelectorNames()];
    NSSet<NSString *> *removable =
        [NSSet setWithArray:IDRemovableCanvasOriginSelectorNames()];
    NSSet<NSString *> *retained =
        [NSSet setWithArray:IDRetainedCanvasOriginSelectorNames()];
    NSMutableSet<NSString *> *intersection = [removable mutableCopy];
    [intersection intersectSet:retained];
    NSMutableSet<NSString *> *unionSet = [removable mutableCopy];
    [unionSet unionSet:retained];

    XCTAssertEqualObjects(intersection, [NSSet set]);
    XCTAssertEqualObjects(unionSet, all);
    XCTAssertEqual(all.count, 2U);
}

- (void)testRetainedCanvasOriginSelectorsPreserveRuntimeABI {
    NSString *invalidation =
        [@"invalidateTextContainer" stringByAppendingString:@"Origin"];
    for (NSString *name in IDRetainedCanvasOriginSelectorNames()) {
        SEL selector = NSSelectorFromString(name);
        NSMethodSignature *signature =
            [IDTextLayoutCanvasView
                instanceMethodSignatureForSelector:selector];
        XCTAssertNotNil(
            signature,
            @"Retained by UIFoundation/UIKit text geometry callers: %@",
            name);
        XCTAssertEqual(signature.numberOfArguments, 2U, @"%@", name);
        const char *expectedReturn =
            [name isEqualToString:invalidation]
                ? @encode(void)
                : @encode(CGPoint);
        XCTAssertEqual(strcmp(signature.methodReturnType, expectedReturn),
                       0, @"%@", name);
    }
}

- (void)testProjectEditingChangeInvalidatesLayoutOnlyWhenHoverStateExists {
    IDEnvironmentNotificationProbeCanvas *canvas =
        [self environmentProbeWithText:@"editing" size:CGSizeMake(220, 80)];

    [canvas id_isEditingDidChange];
    XCTAssertEqualObjects(canvas.environmentEvents, (@[]));

    canvas.id_hoverEffectContainerLayer = [CALayer layer];
    [canvas id_isEditingDidChange];
    XCTAssertEqualObjects(canvas.environmentEvents, (@[@"layout"]));
}

- (void)testProjectTraitChangeInvalidatesLayoutAndDisplay {
    IDEnvironmentNotificationProbeCanvas *canvas =
        [self environmentProbeWithText:@"traits" size:CGSizeMake(220, 80)];

    [canvas id_traitsChanged];

    XCTAssertEqualObjects(canvas.environmentEvents,
                          (@[@"layout", @"display", @"layout"]));
}

- (void)testDormantScrollObservationHookPublishesOneViewportChange {
    IDEnvironmentNotificationProbeCanvas *canvas =
        [self environmentProbeWithText:@"scroll" size:CGSizeMake(220, 80)];

    [canvas id_observeEnclosingScrollView];

    XCTAssertEqualObjects(canvas.environmentEvents,
                          (@[@"viewport", @"layout"]));
}

- (void)testDormantScrollObservationHookTracksAttachDetachAndReparent {
    UIScrollView *first = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0, 0, 220, 80)];
    UIScrollView *second = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0, 0, 180, 70)];
    IDEnvironmentNotificationProbeCanvas *canvas =
        [self environmentProbeWithText:@"scroll host" size:CGSizeMake(220, 160)];

    [first addSubview:canvas];
    [canvas id_observeEnclosingScrollView];
    CGRect firstViewport = canvas.viewportBounds;

    [canvas removeFromSuperview];
    [canvas id_observeEnclosingScrollView];
    CGRect detachedViewport = canvas.viewportBounds;

    [second addSubview:canvas];
    [canvas id_observeEnclosingScrollView];
    CGRect secondViewport = canvas.viewportBounds;

    XCTAssertEqual(canvas.superview, second);
    XCTAssertFalse(CGRectIsEmpty(firstViewport));
    XCTAssertTrue(CGRectEqualToRect(detachedViewport, canvas.bounds));
    XCTAssertEqualWithAccuracy(CGRectGetWidth(secondViewport), 180.0, 0.5);
    XCTAssertEqualObjects(canvas.environmentEvents,
                          (@[@"viewport", @"layout",
                             @"viewport", @"layout",
                             @"viewport", @"layout"]));

    __weak UIScrollView *weakFirst = first;
    first = nil;
    [NSRunLoop.mainRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    XCTAssertNil(weakFirst);
}

- (void)testProjectViewportLifecycleCompletesOnceInCanonicalOrder {
    IDLifecycleProbeCanvas *canvas =
        [self lifecycleProbeWithText:@"one\ntwo"
                               size:CGSizeMake(220, 80)];
    __weak IDLifecycleProbeCanvas *weakCanvas = canvas;
    canvas.contentSizeDidChange = ^(CGSize size) {
        [weakCanvas.events addObject:@"publish"];
    };

    [canvas performViewportLayout];

    XCTAssertEqualObjects(canvas.events,
                          (@[@"will", @"evict", @"content", @"publish", @"did"]));
    XCTAssertEqual(canvas.completedViewportLayoutCount, 1U);
    XCTAssertFalse(canvas.performingViewportLayout);
    XCTAssertGreaterThan(canvas.cachedContentSize.height, 0.0);
}

- (void)testProjectContentSizePublicationNormalizesDeduplicatesAndRejectsInvalidUsage {
    IDUsageBoundsProbeLayoutManager *layoutManager = nil;
    IDLifecycleProbeCanvas *canvas =
        [self usageProbeWithLayoutManager:&layoutManager];
    layoutManager.usesProbeUsageBounds = YES;
    NSMutableArray<NSValue *> *published = [NSMutableArray array];
    canvas.contentSizeDidChange = ^(CGSize size) {
        [published addObject:[NSValue valueWithCGSize:size]];
    };

    layoutManager.probeUsageBounds = CGRectMake(-12, -8, 40, 30);
    [canvas id_updateContentSizeIfNeeded];
    XCTAssertEqualObjects(published,
                          (@[[NSValue valueWithCGSize:CGSizeMake(28, 22)]]));
    XCTAssertTrue(CGSizeEqualToSize(canvas.cachedContentSize,
                                    CGSizeMake(28, 22)));

    [canvas id_updateContentSizeIfNeeded];
    XCTAssertEqual(published.count, 1U);

    layoutManager.probeUsageBounds = CGRectMake(NAN, 0, 40, 30);
    [canvas id_updateContentSizeIfNeeded];
    XCTAssertEqual(published.count, 1U);
    XCTAssertTrue(CGSizeEqualToSize(canvas.cachedContentSize,
                                    CGSizeMake(28, 22)));

    layoutManager.probeUsageBounds = CGRectMake(0, 0, 80, 60);
    [canvas id_updateContentSizeIfNeeded];
    XCTAssertEqual(published.count, 2U);
    XCTAssertTrue(CGSizeEqualToSize(published.lastObject.CGSizeValue,
                                    CGSizeMake(80, 60)));
}

- (void)testProjectContentSizePublicationRejectsNonfiniteDerivedExtent {
    IDUsageBoundsProbeLayoutManager *layoutManager = nil;
    IDLifecycleProbeCanvas *canvas =
        [self usageProbeWithLayoutManager:&layoutManager];
    layoutManager.usesProbeUsageBounds = YES;
    canvas.cachedContentSize = CGSizeMake(19, 23);
    __block NSUInteger publicationCount = 0;
    canvas.contentSizeDidChange = ^(CGSize size) {
        publicationCount += 1;
    };

    layoutManager.probeUsageBounds =
        CGRectMake(CGFLOAT_MAX, 0, CGFLOAT_MAX, 20);
    [canvas id_updateContentSizeIfNeeded];

    XCTAssertEqual(publicationCount, 0U);
    XCTAssertTrue(CGSizeEqualToSize(canvas.cachedContentSize,
                                    CGSizeMake(19, 23)));
}

- (void)testProjectFlushUsesProjectEvictionAndEndsQuiescent {
    IDLifecycleProbeCanvas *canvas =
        [self lifecycleProbeWithText:@"flush"
                               size:CGSizeMake(220, 80)];
    [canvas performViewportLayout];
    [canvas.events removeAllObjects];

    [canvas id_flushElementViews];

    XCTAssertEqualObjects(canvas.events, (@[@"evict", @"flush"]));
    XCTAssertEqual(canvas.visibleSurfaceCount, 0U);
    XCTAssertEqual(canvas.unusedFragmentKeys.count, 0U);
    XCTAssertEqual(canvas.unusedExternalSurfaces.count, 0U);
}

- (void)testCanvasExposesNoPrivateLifecycleSelectors {
    NSArray<NSString *> *selectors = @[
        [@"_perform" stringByAppendingString:@"ViewportLayout:"],
        [@"_viewport" stringByAppendingString:@"WillLayout"],
        [@"_viewport" stringByAppendingString:@"DidLayout"],
        [@"_removeUnused" stringByAppendingString:@"ElementViews"],
        [@"updateContentSize" stringByAppendingString:@"IfNeeded"],
        [@"flushElement" stringByAppendingString:@"Views"],
    ];
    for (NSString *name in selectors) {
        SEL selector = NSSelectorFromString(name);
        XCTAssertFalse([IDTextLayoutCanvasView
            instancesRespondToSelector:selector], @"%@", name);
        XCTAssertTrue(class_getInstanceMethod(IDTextLayoutCanvasView.class,
                                              selector) == NULL, @"%@", name);
    }
}

- (void)testCanvasExposesNoPrivateEnvironmentNotificationSelectors {
    NSArray<NSString *> *selectors = @[
        [@"isEditing" stringByAppendingString:@"DidChange"],
        [@"observeEnclosing" stringByAppendingString:@"ScrollView"],
        [@"_traits" stringByAppendingString:@"Changed"],
    ];
    for (NSString *name in selectors) {
        SEL selector = NSSelectorFromString(name);
        XCTAssertFalse([IDTextLayoutCanvasView
            instancesRespondToSelector:selector], @"%@", name);
        XCTAssertTrue(class_getInstanceMethod(IDTextLayoutCanvasView.class,
                                              selector) == NULL, @"%@", name);
    }
}

- (void)testCanvasDefinesNoPrivateContentSizeNotificationSelector {
    NSString *name =
        [@"textContainerUsage" stringByAppendingString:@"DidChangeToSize:"];
    SEL selector = NSSelectorFromString(name);
    Method inherited =
        class_getInstanceMethod(IDTextLayoutCanvasView.superclass, selector);

    XCTAssertFalse(IDClassDefinesInstanceMethod(IDTextLayoutCanvasView.class,
                                                selector));
    XCTAssertEqual(class_getInstanceMethod(IDTextLayoutCanvasView.class,
                                           selector),
                   inherited);
}

- (void)testCanvasOwnsTheLayoutManagersViewportController {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"one\ntwo\nthree" size:CGSizeMake(240, 120)];
    XCTAssertEqual(fixture.canvas.textLayoutManager, fixture.layoutManager);
    XCTAssertEqual(fixture.canvas.textContainer, fixture.textContainer);
    XCTAssertEqual(fixture.canvas.textViewportLayoutController,
                   fixture.layoutManager.textViewportLayoutController);
}

- (void)testViewportBoundsConvertVisibleHostBoundsIntoCanvasCoordinates {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 240, 120)];
    view.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    view.text = [@"line\n" stringByPaddingToLength:300
                                      withString:@"line\n"
                                 startingAtIndex:0];
    [view layoutIfNeeded];
    view.contentOffset = CGPointMake(0, 40);
    CGRect viewport = [view.id_canvasView viewportBounds];
    XCTAssertEqualWithAccuracy(CGRectGetMinY(viewport), 32.0, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(viewport), 230.0, 0.5);
}

- (void)testZeroSizeAndDetachedCanvasAreValidTransientStates {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"transient" size:CGSizeZero];
    XCTAssertNoThrow([fixture.canvas performViewportLayout]);
    XCTAssertTrue(CGRectIsEmpty(fixture.canvas.viewportBounds));
    XCTAssertEqual(fixture.canvas.visibleSurfaceCount, 0U);
}

- (void)testViewportTransactionRejectsRecursiveEntryWithoutThrowing {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"recursive" size:CGSizeMake(200, 80)];
    fixture.canvas.viewportLayoutTestHook = ^{
        [fixture.canvas performViewportLayout];
    };
    XCTAssertNoThrow([fixture.canvas performViewportLayout]);
    XCTAssertEqual(fixture.canvas.completedViewportLayoutCount, 1U);
}

- (void)testConfigureRenderingSurfaceRequiresTheEarlierKeyedSurfaceStage {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"callback contract" size:CGSizeMake(200, 80)];
    [fixture.canvas performViewportLayout];
    NSTextLayoutFragment *fragment = fixture.canvas.visibleFragments.firstObject;
    XCTAssertNotNil(fragment);

    [fixture.canvas.fragmentSurfaces removeObjectForKey:fragment];
    XCTAssertNil([fixture.canvas surfaceForFragment:fragment]);

    @try {
        [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];
        XCTFail(@"Expected configure to reject a missing keyed surface");
    } @catch (NSException *exception) {
        XCTAssertEqualObjects(exception.name, NSInternalInconsistencyException);
        XCTAssertEqualObjects(
            exception.reason,
            @"configureRenderingSurfaceForTextLayoutFragment: requires a keyed surface from "
             "renderingSurfaceForTextLayoutFragment:");
    }
}

@end
