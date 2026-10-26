@import XCTest;

#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDNativeSelectionPresentationBackend.h"
#import "IDTextCanvasTestSupport.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextRenderingSurfaceView.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "IDUIKitBehaviorBackend.h"
#import "IDUIKitBehaviorCapabilities.h"
#import "IDUIKitCapabilityResolver.h"

#import <objc/runtime.h>

#include <math.h>

typedef struct {
    CGRect frame;
    CGRect bounds;
} IDExpectedSurfaceGeometry;

static CGRect IDTestOutwardPixelIntegralRect(CGRect rect, CGFloat scale) {
    CGFloat minimumX = floor(CGRectGetMinX(rect) * scale) / scale;
    CGFloat minimumY = floor(CGRectGetMinY(rect) * scale) / scale;
    CGFloat maximumX = ceil(CGRectGetMaxX(rect) * scale) / scale;
    CGFloat maximumY = ceil(CGRectGetMaxY(rect) * scale) / scale;
    return CGRectMake(minimumX,
                      minimumY,
                      maximumX - minimumX,
                      maximumY - minimumY);
}

static BOOL IDTestRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

static IDUIKitBehaviorCapabilities IDSurfaceTestCompleteCapabilities(void) {
    return IDUIKitBehaviorCapabilityInputController |
        IDUIKitBehaviorCapabilityIncomingCallbacks |
        IDUIKitBehaviorCapabilityTypingAttributes |
        IDUIKitBehaviorCapabilityInteraction |
        IDUIKitBehaviorCapabilityFloatingCursor |
        IDUIKitBehaviorCapabilityAutoscroll |
        IDUIKitBehaviorCapabilityChecking |
        IDUIKitBehaviorCapabilityPrediction |
        IDUIKitBehaviorCapabilityPaste |
        IDUIKitBehaviorCapabilityDictation;
}

static IDExpectedSurfaceGeometry IDTestExpectedSurfaceGeometry(
    NSTextLayoutFragment *fragment,
    CGPoint containerOrigin,
    CGRect clipRect,
    CGFloat scale) {
    CGRect fragmentFrame = IDTestOutwardPixelIntegralRect(fragment.layoutFragmentFrame, scale);
    CGRect renderingBounds = CGRectIntegral(fragment.renderingSurfaceBounds);
    CGRect frame = CGRectOffset(renderingBounds,
                                CGRectGetMinX(fragmentFrame) + containerOrigin.x,
                                CGRectGetMinY(fragmentFrame) + containerOrigin.y);
    if (!CGRectIsNull(clipRect)) {
        CGFloat clippedMinimumX = MAX(CGRectGetMinX(frame), CGRectGetMinX(clipRect));
        CGFloat clippedMaximumX = MIN(CGRectGetMaxX(frame), CGRectGetMaxX(clipRect));
        CGFloat clippedWidth = clippedMaximumX - clippedMinimumX;
        if (clippedWidth > 0) {
            renderingBounds.origin.x += clippedMinimumX - CGRectGetMinX(frame);
            frame.origin.x = clippedMinimumX;
            frame.size.width = clippedWidth;
        }
    }
    frame = IDTestOutwardPixelIntegralRect(frame, scale);
    renderingBounds.size = frame.size;
    return (IDExpectedSurfaceGeometry){frame, renderingBounds};
}

@interface IDDisplayProbeSurface : IDTextRenderingSurfaceView
@property(nonatomic) NSUInteger displayCount;
@end

@implementation IDDisplayProbeSurface
- (void)setNeedsDisplay {
    self.displayCount += 1;
    [super setNeedsDisplay];
}
@end

@interface IDDrawPointProbeLayoutFragment : NSTextLayoutFragment
@property(nonatomic) BOOL didDraw;
@property(nonatomic) CGPoint drawPoint;
@property(nonatomic) NSTextLayoutFragmentState probeState;
@property(nonatomic) CGRect probeLayoutFragmentFrame;
@property(nonatomic) CGRect probeRenderingSurfaceBounds;
@property(nonatomic) BOOL rejectsGeometryAccessWhileIncomplete;
- (instancetype)initForTesting;
@end

@implementation IDDrawPointProbeLayoutFragment

- (instancetype)initForTesting {
    NSTextParagraph *paragraph = [[NSTextParagraph alloc]
        initWithAttributedString:[[NSAttributedString alloc] initWithString:@"probe"]];
    self = [super initWithTextElement:paragraph range:nil];
    if (self != nil) {
        _probeState = NSTextLayoutFragmentStateLayoutAvailable;
        _probeLayoutFragmentFrame = CGRectMake(0.125, 0.125, 20, 10);
        _probeRenderingSurfaceBounds = CGRectMake(-1, -1, 22, 12);
    }
    return self;
}

- (NSTextLayoutFragmentState)state {
    return self.probeState;
}

- (CGRect)layoutFragmentFrame {
    if (self.rejectsGeometryAccessWhileIncomplete &&
        self.probeState < NSTextLayoutFragmentStateLayoutAvailable) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Incomplete fragment frame was accessed"
                                     userInfo:nil];
    }
    return self.probeLayoutFragmentFrame;
}

- (CGRect)renderingSurfaceBounds {
    if (self.rejectsGeometryAccessWhileIncomplete &&
        self.probeState < NSTextLayoutFragmentStateLayoutAvailable) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Incomplete rendering bounds were accessed"
                                     userInfo:nil];
    }
    return self.probeRenderingSurfaceBounds;
}

- (NSArray<NSTextAttachmentViewProvider *> *)textAttachmentViewProviders {
    return @[];
}

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)context {
    self.didDraw = YES;
    self.drawPoint = point;
}

@end

@interface IDAttachmentGeometryProbeSurface : IDTextRenderingSurfaceView
@property(nonatomic, strong) UIView *probeAttachmentView;
@property(nonatomic) CGRect probeAttachmentFrame;
@end

@implementation IDAttachmentGeometryProbeSurface

- (void)enumerateTextAttachmentViewsUsingBlock:(IDTextAttachmentEnumerationBlock)block {
    if (self.layoutFragment.state >= NSTextLayoutFragmentStateLayoutAvailable &&
        self.probeAttachmentView != nil) {
        block(self.probeAttachmentView, self.probeAttachmentFrame);
    }
}

@end

@interface IDConfigurationOrderProbeSurface : IDTextRenderingSurfaceView
@property(nonatomic, strong) NSMutableArray<NSString *> *configurationEvents;
@end

@implementation IDConfigurationOrderProbeSurface
- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.superview != nil) {
        [self.configurationEvents addObject:@"insert"];
    }
}
- (void)performChanges:(dispatch_block_t)changes {
    [self.configurationEvents addObject:@"changes"];
    [super performChanges:changes];
}
- (void)layoutIfNeeded {
    [self.configurationEvents addObject:@"layout"];
    [super layoutIfNeeded];
}
- (void)enumerateTextAttachmentViewsUsingBlock:(IDTextAttachmentEnumerationBlock)block {
    [self.configurationEvents addObject:@"enumerate"];
}
@end

@interface IDEnumerationProviderProbe : NSObject
@property(nonatomic, strong, nullable) UIView *view;
@property(nonatomic, strong, nullable) id<NSTextLocation> location;
@end
@implementation IDEnumerationProviderProbe
@end

@interface IDEnumerationFragmentProbe : IDDrawPointProbeLayoutFragment
@property(nonatomic, strong) NSArray *probeProviders;
@property(nonatomic) CGRect probeAttachmentFrame;
@property(nonatomic) NSUInteger attachmentFrameRequestCount;
@property(nonatomic, strong, nullable) id lastRequestedLocation;
@end

@implementation IDEnumerationFragmentProbe
- (NSArray<NSTextAttachmentViewProvider *> *)textAttachmentViewProviders {
    return self.probeProviders;
}
- (CGRect)frameForTextAttachmentAtLocation:(id<NSTextLocation>)location {
    self.attachmentFrameRequestCount += 1;
    self.lastRequestedLocation = location;
    return self.probeAttachmentFrame;
}
@end

@interface IDCustomConfigurationOrderFragment : IDDrawPointProbeLayoutFragment
@property(nonatomic, strong) NSMutableArray<NSString *> *configurationEvents;
@end
@implementation IDCustomConfigurationOrderFragment
- (NSArray<NSTextAttachmentViewProvider *> *)textAttachmentViewProviders {
    [self.configurationEvents addObject:@"enumerate"];
    return @[];
}
@end

@interface IDFakeCustomSurface : NSObject
@property(nonatomic, strong) CALayer *layer;
@end

@implementation IDFakeCustomSurface
@end

@interface IDFakeCustomRenderer : NSObject

@property(nonatomic, strong) NSMutableArray<NSString *> *events;
@property(nonatomic, strong) NSMutableArray<NSTextLayoutFragment *> *fragments;
@property(nonatomic, strong) NSMapTable<NSTextLayoutFragment *, IDFakeCustomSurface *> *surfaces;
@property(nonatomic, strong, nullable) NSMutableArray<NSString *> *configurationEvents;

@end

@implementation IDFakeCustomRenderer

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _events = [NSMutableArray array];
        _fragments = [NSMutableArray array];
        _surfaces = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self;
}

- (void)setContentsScale:(CGFloat)contentsScale {
    [self.events addObject:@"scale"];
}

- (void)beginLayout {
    [self.events addObject:@"begin"];
    [self.fragments removeAllObjects];
}

- (void)preLayoutNotify {
    [self.events addObject:@"pre"];
}

- (void)didLayoutFragment:(NSTextLayoutFragment *)fragment {
    [self.events addObject:@"did"];
    [self.configurationEvents addObject:@"did"];
    [self.fragments addObject:fragment];
}

- (void)endLayoutWithConsumer:(void (^)(NSTextLayoutFragment *, id))consumer {
    [self.events addObject:@"end"];
    [self.surfaces removeAllObjects];
    for (NSTextLayoutFragment *fragment in self.fragments) {
        IDFakeCustomSurface *surface = [IDFakeCustomSurface new];
        surface.layer = [CALayer layer];
        surface.layer.backgroundColor = UIColor.systemBlueColor.CGColor;
        [self.surfaces setObject:surface forKey:fragment];
        consumer(fragment, surface);
    }
}

- (void)setNeedsDisplay {
    [self.events addObject:@"display"];
}

- (void)postLayoutNotify {
    [self.events addObject:@"post"];
}

@end

@interface IDFakeCustomContext : NSObject

@property(nonatomic, strong) IDFakeCustomRenderer *customRenderController;
@property(nonatomic) CGRect fadedEdgesClipRect;

@end


@implementation IDFakeCustomContext
- (void)_textKit2CanvasDidLayout {
}
- (void)_updateInteractionGeometry {
}
- (CGRect)_clipRectForFadedEdges {
    return self.fadedEdgesClipRect;
}
@end

@interface IDTextRenderingSurfaceViewTests : XCTestCase
@end

@implementation IDTextRenderingSurfaceViewTests

- (void)testProjectFragmentSurfaceExposesNoPrivateLayoutFragmentMarker {
    SEL marker = NSSelectorFromString(@"isLayoutFragmentView");
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDTextRenderingSurfaceView *surface =
        [[IDTextRenderingSurfaceView alloc]
            initWithLayoutFragment:fragment
                   containerOrigin:CGPointZero
                    containerSize:CGSizeMake(100, 40)
                         clipRect:CGRectNull];

    XCTAssertFalse([surface respondsToSelector:marker]);
    XCTAssertEqual(class_getInstanceMethod(
        IDTextRenderingSurfaceView.class, marker), NULL);
}

- (void)testRedPixelRowsPreserveEmptyRowsAndShareTheRedPredicate {
    UIGraphicsImageRendererFormat *format =
        [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    UIImage *image = [[[UIGraphicsImageRenderer alloc]
        initWithSize:CGSizeMake(6, 4)
              format:format]
        imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [UIColor.redColor setFill];
            CGContextFillRect(context.CGContext, CGRectMake(1, 1, 1, 1));
            CGContextFillRect(context.CGContext, CGRectMake(4, 1, 1, 1));
            CGContextFillRect(context.CGContext, CGRectMake(3, 3, 1, 1));
        }];

    XCTAssertEqualObjects(
        IDRedPixelCountsByRow(image, CGRectMake(0, 0, 6, 4)),
        (@[@0, @2, @0, @1]));
    XCTAssertEqual(
        IDCountRedPixels(image, CGRectMake(0, 0, 6, 4)),
        3U);
}

- (void)testConfigureInsertsSurfaceBeforeGeometryLayoutAndAttachmentEnumeration {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"order" size:CGSizeMake(220, 80)];
    fixture.canvas.nativeSurfaceViewClass = IDConfigurationOrderProbeSurface.class;
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDConfigurationOrderProbeSurface *surface =
        (IDConfigurationOrderProbeSurface *)[fixture.canvas
            id_renderingSurfaceForTextLayoutFragment:fragment];
    surface.configurationEvents = [NSMutableArray array];
    [fixture.canvas.unusedFragmentKeys addObject:fragment];

    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];

    XCTAssertLessThan([surface.configurationEvents indexOfObject:@"insert"],
                      [surface.configurationEvents indexOfObject:@"changes"]);
    XCTAssertLessThan([surface.configurationEvents indexOfObject:@"changes"],
                      [surface.configurationEvents indexOfObject:@"layout"]);
    XCTAssertLessThan([surface.configurationEvents indexOfObject:@"layout"],
                      [surface.configurationEvents indexOfObject:@"enumerate"]);
    XCTAssertFalse([fixture.canvas.unusedFragmentKeys containsObject:fragment]);
}

- (void)testAttachmentEnumerationGatesOnlyOnTextElementAndNilProviderView {
    IDEnumerationFragmentProbe *fragment =
        [[IDEnumerationFragmentProbe alloc] initForTesting];
    fragment.probeState = NSTextLayoutFragmentStateNone;
    fragment.probeAttachmentFrame = CGRectNull;
    IDEnumerationProviderProbe *nilViewProvider = [IDEnumerationProviderProbe new];
    IDEnumerationProviderProbe *provider = [IDEnumerationProviderProbe new];
    provider.view = [UIView new];
    provider.location = nil;
    fragment.probeProviders = @[nilViewProvider, provider];
    IDTextRenderingSurfaceView *surface = [[IDTextRenderingSurfaceView alloc]
        initWithLayoutFragment:fragment
                containerOrigin:CGPointZero
                 containerSize:CGSizeMake(220, 80)
                      clipRect:CGRectMake(0, 0, 220, 80)];
    __block NSUInteger callbackCount = 0;
    __block CGRect callbackFrame = CGRectZero;

    [surface enumerateTextAttachmentViewsUsingBlock:^(UIView *view, CGRect frame) {
        callbackCount += 1;
        callbackFrame = frame;
        XCTAssertEqual(view, provider.view);
    }];

    XCTAssertEqual(callbackCount, 1U);
    XCTAssertEqual(fragment.attachmentFrameRequestCount, 1U);
    XCTAssertNil(fragment.lastRequestedLocation);
    XCTAssertTrue(CGRectIsNull(callbackFrame));
}

- (void)testCustomRendererFragmentCallbackPrecedesLayoutAttachmentEnumeration {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"custom order" size:CGSizeMake(220, 80)];
    IDFakeCustomRenderer *renderer = [IDFakeCustomRenderer new];
    IDFakeCustomContext *context = [IDFakeCustomContext new];
    context.customRenderController = renderer;
    fixture.canvas.context = context;
    [fixture.canvas id_viewportWillLayout];
    IDCustomConfigurationOrderFragment *fragment =
        [[IDCustomConfigurationOrderFragment alloc] initForTesting];
    NSMutableArray<NSString *> *events = [NSMutableArray array];
    fragment.configurationEvents = events;
    renderer.configurationEvents = events;
    (void)[fixture.canvas id_renderingSurfaceForTextLayoutFragment:fragment];
    [events removeAllObjects];

    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];

    XCTAssertGreaterThan([events indexOfObject:@"enumerate"],
                         [events indexOfObject:@"did"]);
}

- (void)testOneSurfaceIsReusedForTheSameVisibleFragmentKey {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"alpha beta gamma" size:CGSizeMake(180, 80)];
    [fixture.canvas performViewportLayout];
    NSTextLayoutFragment *fragment = fixture.canvas.visibleFragments.firstObject;
    UIView *first = [fixture.canvas surfaceForFragment:fragment];

    [fixture.canvas performViewportLayout];

    XCTAssertNotNil(first);
    XCTAssertEqual([fixture.canvas surfaceForFragment:fragment], first);
}

- (void)testConfigureRefreshesGeometryWhenTheStableFragmentKeyReflows {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"stable key" size:CGSizeMake(220, 80)];
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDTextRenderingSurfaceView *surface =
        (IDTextRenderingSurfaceView *)[fixture.canvas
            id_renderingSurfaceForTextLayoutFragment:fragment];
    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];
    CGRect originalFrame = surface.frame;

    fragment.probeLayoutFragmentFrame = CGRectMake(40.125, 12.125, 30, 14);
    fragment.probeRenderingSurfaceBounds = CGRectMake(-2, -3, 34, 20);
    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];

    IDExpectedSurfaceGeometry expected = IDTestExpectedSurfaceGeometry(
        fragment,
        CGPointZero,
        fixture.canvas.bounds,
        surface.traitCollection.displayScale);
    XCTAssertEqual([fixture.canvas surfaceForFragment:fragment], surface);
    XCTAssertFalse(CGRectEqualToRect(surface.frame, originalFrame));
    XCTAssertTrue(CGRectEqualToRect(surface.frame, expected.frame));
    XCTAssertTrue(CGRectEqualToRect(surface.bounds, expected.bounds));
}

- (void)testNestedChangeTransactionsRefreshGeometryOnlyOnceAtTheOutermostBoundary {
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDDisplayProbeSurface *surface = [[IDDisplayProbeSurface alloc]
        initWithLayoutFragment:fragment
                containerOrigin:CGPointZero
                 containerSize:CGSizeMake(220, 80)
                      clipRect:CGRectMake(0, 0, 220, 80)];
    surface.displayCount = 0;

    [surface performChanges:^{
        [surface performChanges:^{}];
    }];

    XCTAssertEqual(surface.displayCount, 1U);
}

- (void)testIncompleteFragmentClearsGeometryAttachmentsAndRecoversOnConfigure {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"transient fragment" size:CGSizeMake(220, 80)];
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDAttachmentGeometryProbeSurface *surface = [[IDAttachmentGeometryProbeSurface alloc]
        initWithLayoutFragment:fragment
                containerOrigin:CGPointZero
                 containerSize:fixture.textContainer.size
                      clipRect:fixture.canvas.bounds];
    surface.probeAttachmentView = [UIView new];
    surface.probeAttachmentFrame = CGRectMake(2, 3, 4, 5);
    [fixture.canvas.fragmentSurfaces setObject:surface forKey:fragment];
    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];
    XCTAssertEqual(surface.probeAttachmentView.superview, surface);

    fragment.probeState = NSTextLayoutFragmentStateNone;
    fragment.rejectsGeometryAccessWhileIncomplete = YES;
    fragment.didDraw = NO;
    XCTAssertNoThrow([fixture.canvas
        id_configureRenderingSurfaceForTextLayoutFragment:fragment]);

    XCTAssertTrue(surface.hidden);
    XCTAssertTrue(CGRectEqualToRect(surface.frame, CGRectZero));
    XCTAssertTrue(CGRectEqualToRect(surface.bounds, CGRectZero));
    XCTAssertNil(surface.probeAttachmentView.superview);
    (void)IDRenderView(surface);
    XCTAssertFalse(fragment.didDraw);

    fragment.probeState = NSTextLayoutFragmentStateLayoutAvailable;
    fragment.rejectsGeometryAccessWhileIncomplete = NO;
    fragment.probeLayoutFragmentFrame = CGRectMake(10.125, 4.125, 25, 12);
    fragment.probeRenderingSurfaceBounds = CGRectMake(-1, -2, 28, 16);
    [fixture.canvas.fragmentSurfaces setObject:surface forKey:fragment];
    XCTAssertNoThrow([fixture.canvas
        id_configureRenderingSurfaceForTextLayoutFragment:fragment]);

    XCTAssertFalse(surface.hidden);
    XCTAssertTrue(IDTestRectIsFinite(surface.frame));
    XCTAssertTrue(IDTestRectIsFinite(surface.bounds));
    XCTAssertFalse(CGRectIsEmpty(surface.frame));
}

- (void)testNonFiniteFragmentRectScalarsInstallSafeHiddenGeometry {
    for (NSUInteger scalarIndex = 0; scalarIndex < 8; scalarIndex += 1) {
        IDDrawPointProbeLayoutFragment *fragment =
            [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
        IDTextRenderingSurfaceView *surface = [[IDTextRenderingSurfaceView alloc]
            initWithLayoutFragment:fragment
                    containerOrigin:CGPointZero
                     containerSize:CGSizeMake(220, 80)
                          clipRect:CGRectMake(0, 0, 220, 80)];
        CGRect frame = fragment.probeLayoutFragmentFrame;
        CGRect bounds = fragment.probeRenderingSurfaceBounds;
        CGFloat *components = scalarIndex < 4
            ? (CGFloat *)&frame
            : (CGFloat *)&bounds;
        components[scalarIndex % 4] = NAN;
        fragment.probeLayoutFragmentFrame = frame;
        fragment.probeRenderingSurfaceBounds = bounds;

        XCTAssertNoThrow([surface performChanges:^{}], @"scalar %lu",
                         (unsigned long)scalarIndex);
        XCTAssertTrue(surface.hidden, @"scalar %lu", (unsigned long)scalarIndex);
        XCTAssertTrue(IDTestRectIsFinite(surface.frame), @"scalar %lu",
                      (unsigned long)scalarIndex);
        XCTAssertTrue(IDTestRectIsFinite(surface.bounds), @"scalar %lu",
                      (unsigned long)scalarIndex);
        XCTAssertTrue(CGRectEqualToRect(surface.frame, CGRectZero), @"scalar %lu",
                      (unsigned long)scalarIndex);
        XCTAssertTrue(CGRectEqualToRect(surface.bounds, CGRectZero), @"scalar %lu",
                      (unsigned long)scalarIndex);
    }
}

- (void)testValidEmptyRenderingBoundsRemainAVisibleTransientGeometry {
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDTextRenderingSurfaceView *surface = [[IDTextRenderingSurfaceView alloc]
        initWithLayoutFragment:fragment
                containerOrigin:CGPointZero
                 containerSize:CGSizeMake(220, 80)
                      clipRect:CGRectMake(0, 0, 220, 80)];
    fragment.probeRenderingSurfaceBounds = CGRectZero;

    XCTAssertNoThrow([surface performChanges:^{}]);

    XCTAssertFalse(surface.hidden);
    XCTAssertTrue(IDTestRectIsFinite(surface.frame));
    XCTAssertTrue(IDTestRectIsFinite(surface.bounds));
    XCTAssertTrue(CGSizeEqualToSize(surface.frame.size, CGSizeZero));
}

- (void)testAFragmentThatLeavesTheViewportIsTornDownAndRemovedFromTheMap {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:[@"row\n" stringByPaddingToLength:4000
                                           withString:@"row\n"
                                      startingAtIndex:0]
                  size:CGSizeMake(180, 80)];
    [fixture.canvas performViewportLayout];
    IDTextRenderingSurfaceView *first =
        (IDTextRenderingSurfaceView *)fixture.canvas.visibleSurfaces.firstObject;

    fixture.canvas.viewportOverride = CGRectMake(0, 2000, 180, 80);
    [fixture.canvas viewportBoundsDidChange];
    [fixture.canvas performViewportLayout];

    XCTAssertNil(first.layoutFragment);
    XCTAssertNil(first.superview);
}

- (void)testNativeSurfaceUsesRecoveredOutwardHorizontalClipFrameAndBounds {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"pixel geometry" size:CGSizeMake(183.5, 80)];
    [fixture.canvas performViewportLayout];
    IDTextRenderingSurfaceView *surface =
        (IDTextRenderingSurfaceView *)fixture.canvas.visibleSurfaces.firstObject;
    CGPoint containerOrigin = CGPointMake(0.125, 0.125);
    CGSize containerSize = CGSizeMake(2, 0.25);
    CGRect clipRect = CGRectMake(0.25, 6.25, 20.5, 0.5);
    [surface performChanges:^{
        [surface setContainerOrigin:containerOrigin];
        [surface setContainerSize:containerSize];
        [surface setClipRect:clipRect];
    }];
    CGFloat scale = surface.traitCollection.displayScale;
    IDExpectedSurfaceGeometry expected = IDTestExpectedSurfaceGeometry(
        surface.layoutFragment, containerOrigin, clipRect, scale);

    XCTAssertNotNil(surface);
    XCTAssertTrue(CGRectEqualToRect(surface.frame, expected.frame));
    XCTAssertTrue(CGRectEqualToRect(surface.bounds, expected.bounds));
    XCTAssertEqualWithAccuracy(CGRectGetMinX(surface.frame) * scale,
                               round(CGRectGetMinX(surface.frame) * scale), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(surface.frame) * scale,
                               round(CGRectGetMaxX(surface.frame) * scale), 0.001);
    XCTAssertNotEqualWithAccuracy(CGRectGetMinX(surface.frame),
                                  CGRectGetMinX(surface.bounds), 0.001);
}

- (void)testNativeSurfaceGeometryIgnoresContainerSizeAndVerticalClipEdges {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"vertical geometry" size:CGSizeMake(183.5, 80)];
    [fixture.canvas performViewportLayout];
    IDTextRenderingSurfaceView *surface =
        (IDTextRenderingSurfaceView *)fixture.canvas.visibleSurfaces.firstObject;
    CGPoint containerOrigin = CGPointMake(0.125, 0.125);
    CGRect clipRect = CGRectMake(-100, 6.25, 700, 0.5);
    [surface performChanges:^{
        [surface setContainerOrigin:containerOrigin];
        [surface setContainerSize:CGSizeMake(0.25, 0.25)];
        [surface setClipRect:clipRect];
    }];
    IDExpectedSurfaceGeometry expected = IDTestExpectedSurfaceGeometry(
        surface.layoutFragment,
        containerOrigin,
        clipRect,
        surface.traitCollection.displayScale);

    XCTAssertEqualWithAccuracy(CGRectGetMinY(surface.frame),
                               CGRectGetMinY(expected.frame), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(surface.frame),
                               CGRectGetMaxY(expected.frame), 0.001);
    XCTAssertLessThan(CGRectGetMinY(surface.frame), CGRectGetMinY(clipRect));
    XCTAssertGreaterThan(CGRectGetHeight(surface.frame), 0.25);
}

- (void)testHorizontalClipWithNoOverlapPreservesOriginalSurfaceGeometry {
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    CGRect clipRect = CGRectMake(1000.25, 0, 20.5, 100);
    IDTextRenderingSurfaceView *surface = [[IDTextRenderingSurfaceView alloc]
        initWithLayoutFragment:fragment
                containerOrigin:CGPointMake(0.125, 0.125)
                 containerSize:CGSizeMake(1, 1)
                      clipRect:clipRect];
    IDExpectedSurfaceGeometry expected = IDTestExpectedSurfaceGeometry(
        fragment,
        CGPointMake(0.125, 0.125),
        clipRect,
        surface.traitCollection.displayScale);

    XCTAssertTrue(CGRectEqualToRect(surface.frame, expected.frame));
    XCTAssertTrue(CGRectEqualToRect(surface.bounds, expected.bounds));
}

- (void)testUnclippedNativeSurfaceUsesPixelIntegralRenderingFrame {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"pixel geometry" size:CGSizeMake(183.5, 80)];
    [fixture.canvas performViewportLayout];
    IDTextRenderingSurfaceView *surface =
        (IDTextRenderingSurfaceView *)fixture.canvas.visibleSurfaces.firstObject;
    [surface performChanges:^{
        [surface setContainerSize:CGSizeMake(500, 500)];
        [surface setClipRect:CGRectMake(-100, -100, 700, 700)];
    }];
    CGFloat scale = surface.traitCollection.displayScale;

    XCTAssertEqualWithAccuracy(CGRectGetMinX(surface.frame) * scale,
                               round(CGRectGetMinX(surface.frame) * scale), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(surface.frame) * scale,
                               round(CGRectGetMinY(surface.frame) * scale), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(surface.frame) * scale,
                               round(CGRectGetMaxX(surface.frame) * scale), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(surface.frame) * scale,
                               round(CGRectGetMaxY(surface.frame) * scale), 0.001);
}

- (void)testCustomSurfaceHostUsesNativeGeometryAndPositionsLayerAtBoundsOrigin {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"custom pixel geometry" size:CGSizeMake(220, 80)];
    IDFakeCustomContext *context = [IDFakeCustomContext new];
    context.customRenderController = [IDFakeCustomRenderer new];
    fixture.canvas.context = context;
    CGRect clipRect = CGRectMake(0.25, 6.25, 20.5, 0.5);
    context.fadedEdgesClipRect = clipRect;
    fixture.canvas.bounds = clipRect;

    [fixture.canvas performViewportLayout];

    NSTextLayoutFragment *fragment = fixture.canvas.visibleFragments.firstObject;
    UIView *hostingView = fixture.canvas.visibleSurfaces.firstObject;
    IDFakeCustomSurface *customSurface =
        [context.customRenderController.surfaces objectForKey:fragment];
    IDExpectedSurfaceGeometry expected = IDTestExpectedSurfaceGeometry(
        fragment, CGPointZero, clipRect, hostingView.traitCollection.displayScale);
    XCTAssertNotNil(hostingView);
    XCTAssertTrue(CGRectEqualToRect(hostingView.frame, expected.frame));
    XCTAssertTrue(CGRectEqualToRect(hostingView.bounds, expected.bounds));
    XCTAssertTrue(CGRectEqualToRect(customSurface.layer.bounds, hostingView.bounds));
    XCTAssertTrue(CGPointEqualToPoint(customSurface.layer.position,
                                      hostingView.bounds.origin));
}

- (void)testNativeSurfaceDrawsTextKitFragmentInsteadOfEnumeratingTheDocument {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"native fragment" size:CGSizeMake(220, 80)];
    [fixture.canvas performViewportLayout];
    UIImage *image = IDRenderView(fixture.canvas.visibleSurfaces.firstObject);
    CGRect extent = CGRectMake(0, 0, image.size.width, image.size.height);

    XCTAssertGreaterThan(IDCountNontransparentPixels(image, extent), 0U);
    XCTAssertFalse([fixture.canvas respondsToSelector:@selector(drawTextInRect:)]);
}

- (void)testNativeSurfaceDrawsFragmentAtRecoveredZeroPoint {
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDTextRenderingSurfaceView *surface = [[IDTextRenderingSurfaceView alloc]
        initWithLayoutFragment:fragment
                containerOrigin:CGPointMake(0.125, 0.125)
                 containerSize:CGSizeMake(1, 1)
                      clipRect:CGRectMake(0.25, 6.25, 20.5, 0.5)];

    (void)IDRenderView(surface);

    XCTAssertTrue(fragment.didDraw);
    XCTAssertTrue(CGPointEqualToPoint(fragment.drawPoint, CGPointZero));
}

- (void)testNativeSurfaceKeepsAttachmentFrameInFragmentCoordinates {
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    IDAttachmentGeometryProbeSurface *surface = [[IDAttachmentGeometryProbeSurface alloc]
        initWithLayoutFragment:fragment
                containerOrigin:CGPointMake(0.125, 0.125)
                 containerSize:CGSizeMake(1, 1)
                      clipRect:CGRectMake(0.25, 0, 20.5, 100)];
    surface.probeAttachmentView = [UIView new];
    surface.probeAttachmentFrame = CGRectMake(2, 3, 4, 5);

    [surface setClipRect:CGRectMake(0.5, 0, 20, 100)];
    [surface setNeedsLayout];
    [surface layoutIfNeeded];
    XCTAssertNil(surface.probeAttachmentView.superview);

    UIView *host = [UIView new];
    [host addSubview:surface];

    XCTAssertEqual(surface.probeAttachmentView.superview, surface);
    XCTAssertTrue(CGRectEqualToRect(surface.probeAttachmentView.frame,
                                    surface.probeAttachmentFrame));
}

- (void)testRecoveredDisplayFlagInvalidatesMappedNativeSurfaces {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"display flag" size:CGSizeMake(220, 80)];
    fixture.canvas.nativeSurfaceViewClass = IDDisplayProbeSurface.class;
    [fixture.canvas performViewportLayout];
    IDDisplayProbeSurface *surface = (IDDisplayProbeSurface *)fixture.canvas.visibleSurfaces.firstObject;
    surface.displayCount = 0;

    fixture.canvas.layoutFragmentViewsNeedDisplay = YES;
    [fixture.canvas performViewportLayout];

    XCTAssertFalse(fixture.canvas.layoutFragmentViewsNeedDisplay);
    XCTAssertGreaterThan(surface.displayCount, 0U);
}

- (void)testCustomRendererDisplayInvalidationRequiresRecoveredSelectorContract {
    NSException *caught = nil;
    @try {
        IDPrivateCanvasSetNeedsDisplay([NSObject new]);
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Custom renderer display invalidation contract"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:@"setNeedsDisplay"], @"%@", caught.reason);
    XCTAssertTrue([caught.reason containsString:IDPrivateUIKit.compatibilityReport],
                  @"%@",
                  caught.reason);
}

- (void)testChangingCustomRendererIdentityFlushesIncompatibleKeyedSurfaces {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"renderer change" size:CGSizeMake(220, 80)];
    [fixture.canvas performViewportLayout];
    IDTextRenderingSurfaceView *nativeSurface =
        (IDTextRenderingSurfaceView *)fixture.canvas.visibleSurfaces.firstObject;

    IDFakeCustomContext *firstContext = [IDFakeCustomContext new];
    firstContext.customRenderController = [IDFakeCustomRenderer new];
    fixture.canvas.context = firstContext;
    [fixture.canvas performViewportLayout];
    UIView *firstHostingView = fixture.canvas.visibleSurfaces.firstObject;

    XCTAssertNil(nativeSurface.layoutFragment);
    XCTAssertNil(nativeSurface.superview);
    XCTAssertNotEqual(firstHostingView, nativeSurface);

    IDFakeCustomContext *secondContext = [IDFakeCustomContext new];
    secondContext.customRenderController = [IDFakeCustomRenderer new];
    fixture.canvas.context = secondContext;
    [fixture.canvas performViewportLayout];

    XCTAssertNil(firstHostingView.superview);
    XCTAssertNotEqual(fixture.canvas.visibleSurfaces.firstObject, firstHostingView);
}

- (void)testCustomRendererLifecycleAndHostedLayerReplacementFollowRecoveredOrder {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"custom fragment" size:CGSizeMake(220, 80)];
    IDFakeCustomRenderer *renderer = [IDFakeCustomRenderer new];
    IDFakeCustomContext *context = [IDFakeCustomContext new];
    context.customRenderController = renderer;
    fixture.canvas.context = context;

    [fixture.canvas performViewportLayout];

    NSTextLayoutFragment *fragment = fixture.canvas.visibleFragments.firstObject;
    UIView *hostingView = [fixture.canvas surfaceForFragment:fragment];
    IDFakeCustomSurface *firstSurface = [renderer.surfaces objectForKey:fragment];
    CALayer *firstLayer = firstSurface.layer;
    NSArray<NSString *> *firstEvents = renderer.events.copy;
    XCTAssertEqualObjects(firstEvents.firstObject, @"scale");
    XCTAssertLessThan([firstEvents indexOfObject:@"scale"],
                      [firstEvents indexOfObject:@"begin"]);
    XCTAssertLessThan([firstEvents indexOfObject:@"begin"],
                      [firstEvents indexOfObject:@"pre"]);
    XCTAssertLessThan([firstEvents indexOfObject:@"pre"],
                      [firstEvents indexOfObject:@"did"]);
    XCTAssertLessThan([firstEvents indexOfObject:@"did"],
                      [firstEvents indexOfObject:@"end"]);
    XCTAssertLessThan([firstEvents indexOfObject:@"end"],
                      [firstEvents indexOfObject:@"post"]);
    XCTAssertEqual(firstLayer.superlayer, hostingView.layer);
    XCTAssertTrue(CGRectEqualToRect(firstLayer.bounds, hostingView.bounds));
    XCTAssertTrue(CGPointEqualToPoint(firstLayer.anchorPoint, CGPointZero));

    [renderer.events removeAllObjects];
    fixture.canvas.layoutFragmentViewsNeedDisplay = YES;
    [fixture.canvas performViewportLayout];

    IDFakeCustomSurface *replacementSurface = [renderer.surfaces objectForKey:fragment];
    CALayer *replacementLayer = replacementSurface.layer;
    XCTAssertEqual([fixture.canvas surfaceForFragment:fragment], hostingView);
    XCTAssertNotEqual(replacementSurface, firstSurface);
    XCTAssertNotEqual(replacementLayer, firstLayer);
    XCTAssertNil(firstLayer.superlayer);
    XCTAssertEqual(replacementLayer.superlayer, hostingView.layer);
    XCTAssertLessThan([renderer.events indexOfObject:@"end"],
                      [renderer.events indexOfObject:@"display"]);
    XCTAssertLessThan([renderer.events indexOfObject:@"display"],
                      [renderer.events indexOfObject:@"post"]);
}

- (void)testCustomEndConsumerRejectsAMissingExactFragmentKey {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"missing custom host" size:CGSizeMake(220, 80)];
    IDFakeCustomRenderer *renderer = [IDFakeCustomRenderer new];
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    [renderer.fragments addObject:fragment];
    fixture.canvas.currentCustomRenderController = renderer;

    NSException *caught = nil;
    @try {
        [fixture.canvas id_notifyCustomRendererPostLayout];
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Custom renderer end-consumer stage"],
                  @"%@", caught.reason);
    XCTAssertTrue([caught.reason containsString:IDPrivateUIKit.compatibilityReport],
                  @"%@", caught.reason);
}

- (void)testCustomEndConsumerRejectsAWrongMappedSurfaceClass {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"wrong custom host" size:CGSizeMake(220, 80)];
    IDFakeCustomRenderer *renderer = [IDFakeCustomRenderer new];
    IDDrawPointProbeLayoutFragment *fragment =
        [[IDDrawPointProbeLayoutFragment alloc] initForTesting];
    [renderer.fragments addObject:fragment];
    [fixture.canvas.fragmentSurfaces setObject:[UIView new] forKey:fragment];
    fixture.canvas.currentCustomRenderController = renderer;

    NSException *caught = nil;
    @try {
        [fixture.canvas id_notifyCustomRendererPostLayout];
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Custom renderer end-consumer stage"],
                  @"%@", caught.reason);
    XCTAssertTrue([caught.reason containsString:IDPrivateUIKit.compatibilityReport],
                  @"%@", caught.reason);
}

- (void)testNativeSurfacePassesThroughSelfHitsButPreservesDescendantHits {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"native hit testing" size:CGSizeMake(220, 80)];
    [fixture.canvas performViewportLayout];
    UIView *surface = fixture.canvas.visibleSurfaces.firstObject;
    CGPoint point = CGPointMake(2, 2);

    XCTAssertNil([surface hitTest:point withEvent:nil]);

    UIButton *descendant = [UIButton buttonWithType:UIButtonTypeSystem];
    descendant.frame = CGRectMake(0, 0, 10, 10);
    [surface addSubview:descendant];
    XCTAssertEqual([surface hitTest:point withEvent:nil], descendant);
}

- (void)testCustomSurfaceHostPassesThroughSelfHitsButPreservesDescendantHits {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"custom hit testing" size:CGSizeMake(220, 80)];
    IDFakeCustomContext *context = [IDFakeCustomContext new];
    context.customRenderController = [IDFakeCustomRenderer new];
    fixture.canvas.context = context;
    [fixture.canvas performViewportLayout];
    UIView *hostingView = fixture.canvas.visibleSurfaces.firstObject;
    CGPoint point = CGPointMake(2, 2);

    XCTAssertNil([hostingView hitTest:point withEvent:nil]);

    UIButton *descendant = [UIButton buttonWithType:UIButtonTypeSystem];
    descendant.frame = CGRectMake(0, 0, 10, 10);
    [hostingView addSubview:descendant];
    XCTAssertEqual([hostingView hitTest:point withEvent:nil], descendant);
}

- (void)testCanvasPassesThroughSelfHitsButPreservesDescendantHits {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"canvas hit testing" size:CGSizeMake(220, 80)];
    CGPoint point = CGPointMake(2, 2);

    XCTAssertNil([fixture.canvas hitTest:point withEvent:nil]);

    UIButton *descendant = [UIButton buttonWithType:UIButtonTypeSystem];
    descendant.frame = CGRectMake(0, 0, 10, 10);
    [fixture.canvas addSubview:descendant];
    XCTAssertEqual([fixture.canvas hitTest:point withEvent:nil], descendant);
}

- (void)testMinimalBackendUsesMarkerFreeProjectSurfaces {
    NSAttributedString *block =
        [[NSAttributedString alloc] initWithString:@"minimal surface"];
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 260, 140)
        attributedBlocks:@[block]
        behaviorBackend:IDUIKitBehaviorBackendMinimalKernel
        resolver:[IDUIKitCapabilityResolver systemResolver]
        requestedCapabilities:IDSurfaceTestCompleteCapabilities()
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                return [[IDNativeSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
            }];
    [view layoutIfNeeded];

    NSUInteger surfaceCount = 0;
    for (IDBlockLayout *layout in view.id_blockStack.blockLayouts) {
        [layout.canvasView performViewportLayout];
        for (UIView *surface in layout.canvasView.visibleSurfaces) {
            surfaceCount += 1;
            XCTAssertEqual(surface.class, IDTextRenderingSurfaceView.class);
            XCTAssertFalse([surface respondsToSelector:
                NSSelectorFromString(@"isLayoutFragmentView")]);
        }
    }
    XCTAssertGreaterThan(surfaceCount, 0U);
}

@end
