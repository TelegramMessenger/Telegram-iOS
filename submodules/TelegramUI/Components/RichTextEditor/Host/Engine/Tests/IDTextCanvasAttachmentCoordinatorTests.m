@import XCTest;

#import "IDTextCanvasTestSupport.h"
#import "IDTextCanvasAttachmentCoordinator.h"
#import "IDTextCanvasAttachmentLifecycle.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextRenderingSurfaceView.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"

#import <dlfcn.h>
#include <math.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface IDTextLayoutCanvasView (IDCompositionTesting)
- (void)setTextEmphasisBackgroundView:(UIView *)backgroundView
                         withTextView:(UIView *)textView;
- (BOOL)textViewportLayoutController:(NSTextViewportLayoutController *)controller
                 addRenderingSurface:(UIView *)surface
                               group:(NSInteger)group
                           placement:(NSInteger)placement;
- (UIView *)id_renderingSurfaceForTextParagraphAnchoredAttachment:(id)attachment
                                         associatedLayoutFragment:(NSTextLayoutFragment *)fragment;
- (CGRect)id_frameForParagraphAnchoredAttachment:(id)attachment
                                  layoutFragment:(NSTextLayoutFragment *)fragment;
- (void)id_updateRenderingSurfaceViewsForTextRange:(id)textRange
                                         inTextView:(UIView *)textView
                                             bounds:(CGRect)bounds;
@property(nonatomic, strong, nullable) id uniqueWritingToolsAnimatedLayoutInfo;
@property(nonatomic, strong, readonly) CALayer *hoverEffectContainerLayer;
@end

@interface IDTextView (IDCompositionTesting)
- (UIView *)selectionContainerView;
@end

@interface IDTask5Attachment : NSTextAttachment
@property(nonatomic, strong) UIView *providedView;
@property(nonatomic) NSUInteger providerCreationCount;
@property(nonatomic) NSUInteger providerBoundsRequestCount;
@end

@interface IDTask5AttachmentProvider : NSTextAttachmentViewProvider
@end

static NSString * const IDDemoAttachmentUTI = @"com.inputdec.demo.attachment";

static void IDTask5DrawView(UIView *view) {
    CGSize size = CGSizeMake(MAX(CGRectGetWidth(view.bounds), 1),
                             MAX(CGRectGetHeight(view.bounds), 1));
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    [view drawRect:view.bounds];
    UIGraphicsEndImageContext();
}

@interface IDTask5WindowHost : NSObject
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, weak) UIWindow *priorKeyWindow;
- (instancetype)initWithView:(UIView *)view size:(CGSize)size;
- (void)tearDown;
@end

@implementation IDTask5WindowHost
- (instancetype)initWithView:(UIView *)view size:(CGSize)size {
    self = [super init];
    if (self == nil) return nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        self.priorKeyWindow = windowScene.keyWindow;
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
        self.window.frame = (CGRect){CGPointZero, size};
        UIViewController *controller = [UIViewController new];
        controller.view = view;
        self.window.rootViewController = controller;
        [self.window makeKeyAndVisible];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        [view setNeedsLayout];
        [view layoutIfNeeded];
        return self;
    }
    return nil;
}
- (void)tearDown {
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    [self.priorKeyWindow makeKeyWindow];
    self.window = nil;
    self.priorKeyWindow = nil;
}
@end

@implementation IDTask5AttachmentProvider
- (BOOL)tracksTextAttachmentViewBounds {
    return YES;
}
- (instancetype)initWithTextAttachment:(NSTextAttachment *)textAttachment
                              parentView:(UIView *)parentView
                       textLayoutManager:(NSTextLayoutManager *)textLayoutManager
                               location:(id<NSTextLocation>)location {
    self = [super initWithTextAttachment:textAttachment
                              parentView:parentView
                       textLayoutManager:textLayoutManager
                               location:location];
    if (self != nil) {
        ((IDTask5Attachment *)textAttachment).providerCreationCount += 1;
    }
    return self;
}
- (void)loadView {
    IDTask5Attachment *attachment = (IDTask5Attachment *)self.textAttachment;
    self.view = attachment.providedView;
}
- (CGRect)attachmentBoundsForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                                location:(id<NSTextLocation>)location
                           textContainer:(NSTextContainer *)textContainer
                    proposedLineFragment:(CGRect)proposedLineFragment
                                position:(CGPoint)position {
    ((IDTask5Attachment *)self.textAttachment).providerBoundsRequestCount += 1;
    return CGRectMake(0, -3, 28, 18);
}
@end

@implementation IDTask5Attachment
- (instancetype)init {
    [NSTextAttachment registerTextAttachmentViewProviderClass:IDTask5AttachmentProvider.class
                                                  forFileType:IDDemoAttachmentUTI];
    self = [super initWithData:[@"attachment" dataUsingEncoding:NSUTF8StringEncoding]
                       ofType:IDDemoAttachmentUTI];
    if (self != nil) {
        self.fileType = IDDemoAttachmentUTI;
        _providedView = [[UIView alloc] initWithFrame:CGRectZero];
        _providedView.backgroundColor = UIColor.systemRedColor;
        self.allowsTextAttachmentView = YES;
    }
    return self;
}
@end

@interface IDTask5CanvasContextProbe : NSObject <IDTextCanvasAttachmentLifecycleSink>
@property(nonatomic, strong) NSMutableArray<NSSet<UIView *> *> *addedAttachmentBatches;
@property(nonatomic, strong) NSMutableArray<NSSet<UIView *> *> *removedAttachmentBatches;
@property(nonatomic, strong) NSMutableArray<UIView *> *laidOutAttachmentViews;
@property(nonatomic, strong) NSMutableArray<NSString *> *attachmentEvents;
@property(nonatomic, strong) NSMutableArray<NSValue *> *framesObservedAtLayout;
@property(nonatomic, strong) NSMutableArray<NSSet<UIView *> *> *rawAddedBatches;
@property(nonatomic, strong) NSMutableArray<NSSet<UIView *> *> *rawRemovedBatches;
@property(nonatomic, strong) NSMutableArray<NSString *> *postLayoutEvents;
@property(nonatomic) BOOL editing;
@property(nonatomic) BOOL editable;
@property(nonatomic, strong, nullable) id customRenderer;
@property(nonatomic) CGPoint containerOrigin;
@end

@implementation IDTask5CanvasContextProbe
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _addedAttachmentBatches = [NSMutableArray array];
        _removedAttachmentBatches = [NSMutableArray array];
        _laidOutAttachmentViews = [NSMutableArray array];
        _attachmentEvents = [NSMutableArray array];
        _framesObservedAtLayout = [NSMutableArray array];
        _rawAddedBatches = [NSMutableArray array];
        _rawRemovedBatches = [NSMutableArray array];
        _postLayoutEvents = [NSMutableArray array];
    }
    return self;
}
- (id)customRenderController { return self.customRenderer; }
- (CGPoint)textContainerOrigin { return self.containerOrigin; }
- (UIColor *)textColor { return UIColor.labelColor; }
- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views {
    [self.attachmentEvents addObject:@"add"];
    [self.rawAddedBatches addObject:views];
    [self.addedAttachmentBatches addObject:views.copy];
}
- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views {
    [self.attachmentEvents addObject:@"remove"];
    [self.rawRemovedBatches addObject:views];
    [self.removedAttachmentBatches addObject:views.copy];
}
- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)rect {
    [self.attachmentEvents addObject:@"layout"];
    [self.framesObservedAtLayout addObject:[NSValue valueWithCGRect:view.frame]];
    [self.laidOutAttachmentViews addObject:view];
}
- (void)_textKit2CanvasDidLayout {
    [self.postLayoutEvents addObject:@"canvas"];
}
- (void)_updateInteractionGeometry {
    [self.postLayoutEvents addObject:@"interaction"];
}
- (BOOL)isEditing { return self.editing; }
- (BOOL)isEditable { return self.editable; }
@end

@interface IDTask5EmphasisView : UIView
@property(nonatomic, strong, nullable) id probeTextRange;
@property(nonatomic) CGPoint probeOrigin;
@property(nonatomic) NSUInteger textRangeUpdateCount;
@property(nonatomic) NSUInteger originUpdateCount;
@end

@implementation IDTask5EmphasisView
- (void)setTextRange:(id)textRange {
    self.probeTextRange = textRange;
    self.textRangeUpdateCount += 1;
}
- (void)setOrigin:(CGPoint)origin {
    self.probeOrigin = origin;
    self.originUpdateCount += 1;
}
@end

@interface IDTask5TextRangeHost : UIView
@property(nonatomic, strong) NSTextStorage *textStorage;
@property(nonatomic) NSRange probeRange;
@property(nonatomic) NSUInteger rangeConversionCount;
@end

@implementation IDTask5TextRangeHost
- (NSRange)_nsRangeForTextKitRanges:(NSArray *)ranges {
    self.rangeConversionCount += 1;
    return self.probeRange;
}
@end

@interface IDTask5AnchoredContentStorage : NSTextContentStorage
- (BOOL)supportsAnchoredTextAttachments;
@end

@implementation IDTask5AnchoredContentStorage
- (BOOL)supportsAnchoredTextAttachments {
    return YES;
}
@end

static IDPrivateCanvasPlatformSurfaceUpdater IDTask5PlatformSurfaceUpdater(
    NSTextViewportLayoutController *controller) {
    return ((id (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(@"_platformRenderingSurfaceUpdater"));
}

@interface IDTask5TextRangeProbe : NSObject
@property(nonatomic) BOOL empty;
@end

@implementation IDTask5TextRangeProbe
- (BOOL)isEmpty { return self.empty; }
@end

@interface IDTask5AnchoredProvider : NSObject
@property(nonatomic, strong) UIView *view;
@end
@implementation IDTask5AnchoredProvider
@end

@interface NSTextLayoutFragment (IDParagraphAnchoredBoundsOracle)
- (CGRect)boundsForTextParagraphAnchoredAttachment:(id)attachment;
- (NSArray *)anchoredTextAttachments;
- (CGPoint)layoutFragmentFrameOrigin;
@end

@interface IDAnchoredBoundsOracleAttachment : NSObject
@property(nonatomic) CGRect frame;
@end

@implementation IDAnchoredBoundsOracleAttachment
@end

@interface IDAnchoredBoundsOracleFragment : NSTextLayoutFragment
@property(nonatomic, copy) NSArray *probeAnchoredAttachments;
@property(nonatomic) CGPoint probeLayoutFragmentFrameOrigin;
- (instancetype)initForAnchoredBoundsOracle;
@end

@implementation IDAnchoredBoundsOracleFragment
- (instancetype)initForAnchoredBoundsOracle {
    NSTextParagraph *paragraph = [[NSTextParagraph alloc]
        initWithAttributedString:[[NSAttributedString alloc]
            initWithString:@"anchor"]];
    return [super initWithTextElement:paragraph range:nil];
}
- (NSArray *)anchoredTextAttachments {
    return self.probeAnchoredAttachments ?: @[];
}
- (CGPoint)layoutFragmentFrameOrigin {
    return self.probeLayoutFragmentFrameOrigin;
}
@end

@interface IDTask5AnchoredFragment : NSTextLayoutFragment
@property(nonatomic) CGRect probeFragmentFrame;
@property(nonatomic) CGRect probeSurfaceBounds;
@property(nonatomic) CGRect probeAnchoredBounds;
@property(nonatomic, strong) IDTask5AnchoredProvider *probeProvider;
@property(nonatomic) NSUInteger providerRequestCount;
@property(nonatomic) NSUInteger drawCount;
- (instancetype)initForTesting;
@end

@implementation IDTask5AnchoredFragment
- (instancetype)initForTesting {
    NSTextParagraph *paragraph = [[NSTextParagraph alloc]
        initWithAttributedString:[[NSAttributedString alloc] initWithString:@"anchor"]];
    self = [super initWithTextElement:paragraph range:nil];
    if (self != nil) {
        _probeFragmentFrame = CGRectMake(0, 24, 200, 40);
        _probeSurfaceBounds = CGRectMake(0, 0, 200, 40);
        _probeAnchoredBounds = CGRectMake(12, 6, 36, 20);
        _probeProvider = [IDTask5AnchoredProvider new];
        _probeProvider.view = [UIView new];
    }
    return self;
}
- (NSTextLayoutFragmentState)state { return NSTextLayoutFragmentStateLayoutAvailable; }
- (CGRect)layoutFragmentFrame { return self.probeFragmentFrame; }
- (CGRect)renderingSurfaceBounds { return self.probeSurfaceBounds; }
- (NSArray<NSTextLineFragment *> *)textLineFragments { return @[]; }
- (NSArray<NSTextAttachmentViewProvider *> *)textAttachmentViewProviders { return @[]; }
- (CGRect)boundsForTextParagraphAnchoredAttachment:(id)attachment {
    return self.probeAnchoredBounds;
}
- (id)textAttachmentViewProviderForTextParagraphAnchoredAttachment:(id)attachment {
    self.providerRequestCount += 1;
    return self.probeProvider;
}
- (void)drawTextParagraphAnchoredAttachment:(id)attachment
                                      bounds:(CGRect)bounds
                                     context:(CGContextRef)context {
    self.drawCount += 1;
}
@end

@interface IDTask5BoundsProbeCanvas : IDTextLayoutCanvasView
@property(nonatomic) CGRect probeBounds;
@property(nonatomic) BOOL usesProbeBounds;
@end

@implementation IDTask5BoundsProbeCanvas
- (CGRect)bounds {
    return self.usesProbeBounds ? self.probeBounds : super.bounds;
}
@end

@interface IDTextCanvasAttachmentCoordinatorTests : XCTestCase
@end

@implementation IDTextCanvasAttachmentCoordinatorTests

- (void)testAttachmentLifecycleProtocolDefinesExactProjectOwnedMethodFamily {
    Protocol *protocol = NSProtocolFromString(@"IDTextCanvasAttachmentLifecycleSink");
    XCTAssertNotNil(protocol);
    NSDictionary<NSString *, NSString *> *required = @{
        @"id_attachmentView:didLayoutInFragmentFrame:":
            @"v56@0:8@16{CGRect={CGPoint=dd}{CGSize=dd}}24",
        @"id_attachmentViewsDidEnterViewport:": @"v24@0:8@16",
        @"id_attachmentViewsDidLeaveViewport:": @"v24@0:8@16",
    };
    for (NSString *name in required) {
        SEL selector = NSSelectorFromString(name);
        struct objc_method_description description =
            protocol_getMethodDescription(protocol, selector, YES, YES);
        XCTAssertNotEqual(description.name, NULL, @"%@", name);
        XCTAssertNotEqual(description.types, NULL, @"%@", name);
        if (description.types != NULL) {
            XCTAssertEqualObjects(@(description.types), required[name], @"%@", name);
        }
    }
}

- (IDTextView *)viewWithViewAttachment:(IDTask5Attachment **)attachmentOut {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 220, 80)];
    IDTask5Attachment *attachment = [IDTask5Attachment new];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"prefix "];
    [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:@" suffix"]];
    [view.id_textContentStorage performEditingTransactionUsingBlock:^{
        [view.id_textContentStorage.textStorage setAttributedString:text];
    }];
    [view setNeedsLayout];
    if (attachmentOut != NULL) {
        *attachmentOut = attachment;
    }
    return view;
}

- (void)testVisibleAttachmentProviderViewIsPlacedInItsFragmentSurface {
    IDTask5Attachment *attachment = nil;
    IDTextView *view = [self viewWithViewAttachment:&attachment];
    IDTask5WindowHost *host = [[IDTask5WindowHost alloc] initWithView:view
                                                                size:view.bounds.size];
    XCTAssertNotNil(host.window);
    [self addTeardownBlock:^{ [host tearDown]; }];
    IDTextRenderingSurfaceView *surface =
        (IDTextRenderingSurfaceView *)view.id_canvasView.visibleSurfaces.firstObject;
    XCTAssertTrue(attachment.usesTextAttachmentView);
    XCTAssertTrue(CGRectEqualToRect(attachment.bounds, CGRectZero));
    XCTAssertEqualObjects(attachment.fileType, IDDemoAttachmentUTI);
    XCTAssertEqual([NSTextAttachment textAttachmentViewProviderClassForFileType:
        IDDemoAttachmentUTI], IDTask5AttachmentProvider.class);
    IDTask5DrawView(surface);
    [view.id_canvasView performViewportLayout];

    XCTAssertEqual(IDPrivateTextContainerTextView(view.id_textContainer),
                   view.id_canvasView);
    XCTAssertTrue([surface isKindOfClass:IDTextRenderingSurfaceView.class]);
    XCTAssertFalse([surface respondsToSelector:
        NSSelectorFromString(@"isLayoutFragmentView")]);
    XCTAssertNotNil(attachment.providedView.superview);
    XCTAssertTrue([attachment.providedView.superview
        isKindOfClass:IDTextRenderingSurfaceView.class]);
    XCTAssertFalse(CGRectIsEmpty(attachment.providedView.frame));
    XCTAssertGreaterThan(attachment.providerCreationCount, 0U);
    XCTAssertGreaterThan(attachment.providerBoundsRequestCount, 0U);
}

- (void)testAttachmentSetDiffNotifiesAddThenRemoveExactlyOnce {
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    IDTask5Attachment *attachment = nil;
    IDTextView *view = [self viewWithViewAttachment:&attachment];
    view.id_canvasView.context = context;
    IDTask5WindowHost *host = [[IDTask5WindowHost alloc] initWithView:view
                                                                size:view.bounds.size];
    XCTAssertNotNil(host.window);
    [self addTeardownBlock:^{ [host tearDown]; }];
    IDTask5DrawView(view.id_canvasView.visibleSurfaces.firstObject);
    [view.id_canvasView performViewportLayout];
    XCTAssertEqual(context.addedAttachmentBatches.count, 1U);
    NSUInteger addIndex = [context.attachmentEvents indexOfObject:@"add"];
    XCTAssertNotEqual(addIndex, NSNotFound);
    // RETURN, not just assert. An Objective-C XCTAssert does not leave the method, so when no "add"
    // arrives `addIndex` is NSNotFound — NSUIntegerMax — and the loop below runs that many times,
    // failing an assertion and logging a line on every pass. Measured when this suite was imported
    // (2026-09-15): on the certified 26.5 runtime it spun past 3.3 MILLION iterations and a 3.3
    // million-line log before it was killed, taking the whole target's run with it. The one-line
    // guard turns an unbounded hang into the clean failure the assertion above already reported.
    if (addIndex == NSNotFound) { return; }
    XCTAssertGreaterThan(addIndex, 0U);
    for (NSUInteger index = 0; index < addIndex; index += 1) {
        XCTAssertEqualObjects(context.attachmentEvents[index], @"layout");
    }
    XCTAssertEqualObjects(context.addedAttachmentBatches.firstObject,
                          [NSSet setWithObject:attachment.providedView]);
    XCTAssertGreaterThanOrEqual(context.laidOutAttachmentViews.count, 1U);
    XCTAssertEqualObjects([NSSet setWithArray:context.laidOutAttachmentViews],
                          [NSSet setWithObject:attachment.providedView]);

    view.id_canvasView.viewportOverride = CGRectMake(0, 1000, 220, 80);
    [view.id_canvasView performViewportLayout];
    XCTAssertEqual(context.removedAttachmentBatches.count, 1U);
    XCTAssertEqualObjects(context.removedAttachmentBatches.firstObject,
                          [NSSet setWithObject:attachment.providedView]);
    XCTAssertEqual(context.addedAttachmentBatches.count, 1U);
    XCTAssertEqualObjects(context.attachmentEvents.lastObject, @"remove");
    XCTAssertEqual(context.addedAttachmentBatches.firstObject.anyObject,
                   context.removedAttachmentBatches.firstObject.anyObject);
}

- (void)testRepeatedAttachmentLayoutPreservesFrameAndDoesNotDuplicateEnter {
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    IDTask5Attachment *attachment = nil;
    IDTextView *view = [self viewWithViewAttachment:&attachment];
    view.id_canvasView.context = context;
    IDTask5WindowHost *host = [[IDTask5WindowHost alloc]
        initWithView:view size:view.bounds.size];
    XCTAssertNotNil(host.window);
    [self addTeardownBlock:^{ [host tearDown]; }];

    [view.id_canvasView performViewportLayout];
    CGRect firstFrame = attachment.providedView.frame;
    NSUInteger firstLayoutCount = context.laidOutAttachmentViews.count;
    XCTAssertEqual(context.addedAttachmentBatches.count, 1U);
    XCTAssertTrue(CGRectEqualToRect(context.framesObservedAtLayout.lastObject.CGRectValue,
                                    firstFrame));

    [view.id_canvasView performViewportLayout];

    XCTAssertGreaterThan(context.laidOutAttachmentViews.count, firstLayoutCount);
    XCTAssertEqual(context.addedAttachmentBatches.count, 1U);
    XCTAssertEqual(context.removedAttachmentBatches.count, 0U);
    XCTAssertTrue(CGRectEqualToRect(attachment.providedView.frame, firstFrame));
}

- (void)testCoordinatorPublishesImmutableSnapshotBatches {
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    IDTextCanvasAttachmentCoordinator *coordinator =
        [IDTextCanvasAttachmentCoordinator new];
    coordinator.lifecycleSink = context;
    UIView *first = [UIView new];
    UIView *second = [UIView new];

    [coordinator beginViewportLayout];
    [coordinator recordAttachmentView:first fragmentFrame:CGRectMake(1, 2, 3, 4)];
    [coordinator finishViewportLayout];
    NSSet<UIView *> *firstPublished = context.rawAddedBatches.lastObject;

    [coordinator beginViewportLayout];
    [coordinator recordAttachmentView:second fragmentFrame:CGRectMake(5, 6, 7, 8)];
    [coordinator finishViewportLayout];

    XCTAssertEqualObjects(firstPublished, [NSSet setWithObject:first]);
    XCTAssertFalse([firstPublished isKindOfClass:NSMutableSet.class]);
    XCTAssertEqualObjects(context.rawRemovedBatches.lastObject,
                          [NSSet setWithObject:first]);
    XCTAssertEqualObjects(context.rawAddedBatches.lastObject,
                          [NSSet setWithObject:second]);
    XCTAssertEqualObjects([context.attachmentEvents subarrayWithRange:
        NSMakeRange(context.attachmentEvents.count - 2, 2)],
                          (@[@"remove", @"add"]));
}

- (void)testCoordinatorDoesNotRetainLifecycleSinkAndFlushAfterDeallocationStillRemovesViews {
    IDTextCanvasAttachmentCoordinator *coordinator =
        [IDTextCanvasAttachmentCoordinator new];
    __weak IDTask5CanvasContextProbe *weakContext = nil;
    @autoreleasepool {
        IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
        weakContext = context;
        coordinator.lifecycleSink = context;
    }
    XCTAssertNil(weakContext);

    UIView *host = [UIView new];
    UIView *view = [UIView new];
    [host addSubview:view];
    [coordinator beginViewportLayout];
    [coordinator recordAttachmentView:view fragmentFrame:CGRectMake(1, 2, 3, 4)];
    [coordinator flush];

    XCTAssertNil(view.superview);
    XCTAssertEqual(coordinator.visibleAttachmentViews.count, 0U);
}

- (void)testCoordinatorFlushDuringTransactionRemovesPreviousAndCurrentViews {
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    IDTextCanvasAttachmentCoordinator *coordinator =
        [IDTextCanvasAttachmentCoordinator new];
    coordinator.lifecycleSink = context;
    UIView *previous = [UIView new];
    UIView *current = [UIView new];
    UIView *host = [UIView new];
    [host addSubview:previous];
    [host addSubview:current];

    [coordinator beginViewportLayout];
    [coordinator recordAttachmentView:previous
                        fragmentFrame:CGRectMake(1, 2, 3, 4)];
    [coordinator finishViewportLayout];
    [context.addedAttachmentBatches removeAllObjects];
    [coordinator beginViewportLayout];
    [coordinator recordAttachmentView:current
                        fragmentFrame:CGRectMake(5, 6, 7, 8)];

    [coordinator flush];

    XCTAssertNil(previous.superview);
    XCTAssertNil(current.superview);
    XCTAssertEqualObjects(context.removedAttachmentBatches.lastObject,
                          ([NSSet setWithObjects:previous, current, nil]));
    XCTAssertEqual(coordinator.visibleAttachmentViews.count, 0U);
}

- (void)testRetainedCanvasEditingSelectorAndProjectEditableGetterForwardExactlyToContext {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"editing" size:CGSizeMake(220, 80)];
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    fixture.canvas.context = context;
    SEL editingSelector = NSSelectorFromString(@"isEditing");

    context.editable = YES;
    context.editing = NO;
    XCTAssertTrue([fixture.canvas id_isEditable]);
    XCTAssertFalse(((BOOL (*)(id, SEL))objc_msgSend)(fixture.canvas, editingSelector));

    context.editable = NO;
    context.editing = YES;
    XCTAssertFalse([fixture.canvas id_isEditable]);
    XCTAssertTrue(((BOOL (*)(id, SEL))objc_msgSend)(fixture.canvas, editingSelector));
}

- (void)testSelectionContainerIdentityAndGeometrySurviveSurfaceChurn {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 220, 100)];
    view.text = [@"row\n" stringByPaddingToLength:2000
                                      withString:@"row\n"
                                 startingAtIndex:0];
    UIView *selection = [view selectionContainerView];
    [view layoutIfNeeded];
    // Read after the first pass has placed the canvas: the container tracks the canvas, which is
    // where the text container inset puts it.
    CGRect frame = selection.frame;
    view.contentOffset = CGPointMake(0, 600);
    [view layoutIfNeeded];

    XCTAssertEqual([view selectionContainerView], selection);
    XCTAssertTrue(CGRectEqualToRect(selection.frame, frame));
    XCTAssertGreaterThan([view.subviews indexOfObject:selection],
                         [view.subviews indexOfObject:view.id_canvasView]);
}

- (void)testTextEmphasisBackgroundRemainsBelowSelectionAndAboveText {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"emphasis"
                size:CGSizeMake(220, 80)];
    UIView *selection = [UIView new];
    IDTask5EmphasisView *emphasis = [IDTask5EmphasisView new];
    IDTask5TextRangeHost *textView = [IDTask5TextRangeHost new];
    textView.textStorage = [[NSTextStorage alloc] initWithString:@"emphasis"];
    textView.probeRange = NSMakeRange(0, textView.textStorage.length);
    [textView.textStorage addAttribute:NSTextHighlightStyleAttributeName
                                 value:@1
                                 range:textView.probeRange];
    fixture.canvas.id_selectionContainerView = selection;
    [fixture.canvas setTextEmphasisBackgroundView:emphasis withTextView:textView];
    [fixture.canvas id_updateRenderingSurfaceViewsForTextRange:[IDTask5TextRangeProbe new]
                                                     inTextView:textView
                                                         bounds:CGRectMake(0, 0, 80, 20)];
    [fixture.canvas performViewportLayout];

    XCTAssertGreaterThan([fixture.canvas.subviews indexOfObject:emphasis],
                         [fixture.canvas.subviews
                             indexOfObject:fixture.canvas.visibleSurfaces.firstObject]);
    XCTAssertLessThan([fixture.canvas.subviews indexOfObject:emphasis],
                      [fixture.canvas.subviews indexOfObject:selection]);
}

- (void)testHighlightedTextRangeShowsAndConfiguresEmphasisSurface {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"emphasis" size:CGSizeMake(220, 80)];
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    fixture.canvas.context = context;
    IDTask5EmphasisView *emphasis = [IDTask5EmphasisView new];
    IDTask5TextRangeHost *textView = [IDTask5TextRangeHost new];
    textView.textStorage = [[NSTextStorage alloc] initWithString:@"emphasis"];
    textView.probeRange = NSMakeRange(1, 4);
    [textView.textStorage addAttribute:NSTextHighlightStyleAttributeName
                                 value:@1
                                 range:textView.probeRange];
    IDTask5TextRangeProbe *textRange = [IDTask5TextRangeProbe new];
    CGRect bounds = CGRectMake(3, 4, 50, 20);
    [fixture.canvas setTextEmphasisBackgroundView:emphasis withTextView:textView];

    [fixture.canvas id_updateRenderingSurfaceViewsForTextRange:textRange
                                                     inTextView:textView
                                                         bounds:bounds];

    XCTAssertEqual(emphasis.superview, fixture.canvas);
    XCTAssertFalse(emphasis.hidden);
    XCTAssertTrue(CGRectEqualToRect(emphasis.frame, bounds));
    XCTAssertEqual(emphasis.probeTextRange, textRange);
    XCTAssertTrue(CGPointEqualToPoint(emphasis.probeOrigin, CGPointMake(-3, -4)));
    XCTAssertEqual(emphasis.textRangeUpdateCount, 1U);
    XCTAssertEqual(emphasis.originUpdateCount, 1U);
}

- (void)testNonHighlightedTextRangeDoesNotShowEmphasisSurface {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"plain" size:CGSizeMake(220, 80)];
    IDTask5EmphasisView *emphasis = [IDTask5EmphasisView new];
    IDTask5TextRangeHost *textView = [IDTask5TextRangeHost new];
    textView.textStorage = [[NSTextStorage alloc] initWithString:@"plain"];
    textView.probeRange = NSMakeRange(0, textView.textStorage.length);
    [fixture.canvas setTextEmphasisBackgroundView:emphasis withTextView:textView];

    [fixture.canvas id_updateRenderingSurfaceViewsForTextRange:[IDTask5TextRangeProbe new]
                                                     inTextView:textView
                                                         bounds:CGRectMake(2, 3, 40, 18)];

    XCTAssertNil(emphasis.superview);
    XCTAssertEqual(emphasis.textRangeUpdateCount, 0U);
    XCTAssertEqual(emphasis.originUpdateCount, 0U);
}

- (void)testClearedHighlightHidesExistingEmphasisSurface {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"clear" size:CGSizeMake(220, 80)];
    IDTask5EmphasisView *emphasis = [IDTask5EmphasisView new];
    IDTask5TextRangeHost *textView = [IDTask5TextRangeHost new];
    textView.textStorage = [[NSTextStorage alloc] initWithString:@"clear"];
    textView.probeRange = NSMakeRange(0, textView.textStorage.length);
    [textView.textStorage addAttribute:NSTextHighlightStyleAttributeName
                                 value:@1
                                 range:textView.probeRange];
    IDTask5TextRangeProbe *textRange = [IDTask5TextRangeProbe new];
    [fixture.canvas setTextEmphasisBackgroundView:emphasis withTextView:textView];
    [fixture.canvas id_updateRenderingSurfaceViewsForTextRange:textRange
                                                     inTextView:textView
                                                         bounds:CGRectMake(2, 3, 40, 18)];
    [textView.textStorage removeAttribute:NSTextHighlightStyleAttributeName
                                    range:textView.probeRange];

    [fixture.canvas id_updateRenderingSurfaceViewsForTextRange:textRange
                                                     inTextView:textView
                                                         bounds:CGRectMake(2, 3, 40, 18)];

    XCTAssertEqual(emphasis.superview, fixture.canvas);
    XCTAssertTrue(emphasis.hidden);
}

- (void)testEmphasisBoundsIncludeNonzeroTextContainerOrigin {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"origin" size:CGSizeMake(220, 80)];
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    context.containerOrigin = CGPointMake(11, 13);
    fixture.canvas.context = context;
    IDTask5EmphasisView *emphasis = [IDTask5EmphasisView new];
    IDTask5TextRangeHost *textView = [IDTask5TextRangeHost new];
    textView.textStorage = [[NSTextStorage alloc] initWithString:@"origin"];
    textView.probeRange = NSMakeRange(0, textView.textStorage.length);
    [textView.textStorage addAttribute:NSTextHighlightStyleAttributeName
                                 value:@1
                                 range:textView.probeRange];
    [fixture.canvas setTextEmphasisBackgroundView:emphasis withTextView:textView];

    [fixture.canvas id_updateRenderingSurfaceViewsForTextRange:[IDTask5TextRangeProbe new]
                                                     inTextView:textView
                                                         bounds:CGRectMake(5, 7, 60, 22)];

    XCTAssertTrue(CGRectEqualToRect(emphasis.frame, CGRectMake(16, 20, 60, 22)));
    XCTAssertTrue(CGPointEqualToPoint(emphasis.probeOrigin, CGPointMake(-5, -7)));
}

- (void)testRemovingEmphasisClearsUpdaterBeforeInstallingForDifferentTextView {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"updater" size:CGSizeMake(220, 80)];
    XCTAssertFalse(IDPrivateCanvasSupportsAnchoredTextAttachments(
        fixture.layoutManager.textContentManager));
    IDTask5EmphasisView *firstEmphasis = [IDTask5EmphasisView new];
    IDTask5TextRangeHost *firstTextView = [IDTask5TextRangeHost new];
    firstTextView.textStorage = [[NSTextStorage alloc] initWithString:@"first"];
    firstTextView.probeRange = NSMakeRange(0, firstTextView.textStorage.length);
    [firstTextView.textStorage addAttribute:NSTextHighlightStyleAttributeName
                                      value:@1
                                      range:firstTextView.probeRange];
    [fixture.canvas setTextEmphasisBackgroundView:firstEmphasis
                                     withTextView:firstTextView];
    IDPrivateCanvasPlatformSurfaceUpdater firstUpdater =
        IDTask5PlatformSurfaceUpdater(fixture.canvas.textViewportLayoutController);
    XCTAssertNotNil(firstUpdater);

    [fixture.canvas setTextEmphasisBackgroundView:nil withTextView:firstTextView];

    XCTAssertNil(IDTask5PlatformSurfaceUpdater(
        fixture.canvas.textViewportLayoutController));

    IDTask5EmphasisView *secondEmphasis = [IDTask5EmphasisView new];
    IDTask5TextRangeHost *secondTextView = [IDTask5TextRangeHost new];
    secondTextView.textStorage = [[NSTextStorage alloc] initWithString:@"second"];
    secondTextView.probeRange = NSMakeRange(0, secondTextView.textStorage.length);
    [secondTextView.textStorage addAttribute:NSTextHighlightStyleAttributeName
                                       value:@1
                                       range:secondTextView.probeRange];
    [fixture.canvas setTextEmphasisBackgroundView:secondEmphasis
                                     withTextView:secondTextView];
    IDPrivateCanvasPlatformSurfaceUpdater secondUpdater =
        IDTask5PlatformSurfaceUpdater(fixture.canvas.textViewportLayoutController);
    XCTAssertNotNil(secondUpdater);
    XCTAssertNotEqual(firstUpdater, secondUpdater);

    secondUpdater(fixture.canvas.textViewportLayoutController,
                  [IDTask5TextRangeProbe new],
                  CGRectMake(0, 0, 60, 20));

    XCTAssertEqual(firstTextView.rangeConversionCount, 0U);
    XCTAssertEqual(secondTextView.rangeConversionCount, 1U);
    XCTAssertEqual(secondEmphasis.textRangeUpdateCount, 1U);
}

- (void)testRemovingEmphasisPreservesUpdaterWhenAnchoredAttachmentsAreSupported {
    IDTask5AnchoredContentStorage *contentStorage =
        [IDTask5AnchoredContentStorage new];
    contentStorage.textStorage = [[NSTextStorage alloc] initWithString:@"anchored"];
    NSTextLayoutManager *layoutManager = [NSTextLayoutManager new];
    [contentStorage addTextLayoutManager:layoutManager];
    NSTextContainer *textContainer =
        [[NSTextContainer alloc] initWithSize:CGSizeMake(220, CGFLOAT_MAX)];
    layoutManager.textContainer = textContainer;
    IDTextLayoutCanvasView *canvas = [[IDTextLayoutCanvasView alloc]
        initWithTextLayoutManager:layoutManager
                    textContainer:textContainer];
    XCTAssertTrue(IDPrivateCanvasSupportsAnchoredTextAttachments(
        layoutManager.textContentManager));
    IDTask5TextRangeHost *textView = [IDTask5TextRangeHost new];
    textView.textStorage = [[NSTextStorage alloc] initWithString:@"anchored"];
    textView.probeRange = NSMakeRange(0, textView.textStorage.length);
    [canvas setTextEmphasisBackgroundView:[IDTask5EmphasisView new]
                            withTextView:textView];
    IDPrivateCanvasPlatformSurfaceUpdater updater =
        IDTask5PlatformSurfaceUpdater(canvas.textViewportLayoutController);
    XCTAssertNotNil(updater);

    [canvas setTextEmphasisBackgroundView:nil withTextView:textView];

    XCTAssertEqual(IDTask5PlatformSurfaceUpdater(
        canvas.textViewportLayoutController), updater);
}

- (void)testExternalRenderingSurfaceGroupAndPlacementMatrixMatchesRecoveredContract {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"matrix"
                size:CGSizeMake(220, 80)];
    UIView *selection = [UIView new];
    fixture.canvas.id_selectionContainerView = selection;
    UIView *backgroundBack = [UIView new];
    UIView *backgroundFront = [UIView new];
    UIView *contentsBack = [UIView new];
    UIView *contentsFront = [UIView new];

    XCTAssertTrue([fixture.canvas textViewportLayoutController:fixture.canvas.textViewportLayoutController
                                            addRenderingSurface:backgroundBack
                                                          group:1
                                                      placement:1]);
    XCTAssertTrue([fixture.canvas textViewportLayoutController:fixture.canvas.textViewportLayoutController
                                            addRenderingSurface:backgroundFront
                                                          group:1
                                                      placement:0]);
    XCTAssertTrue([fixture.canvas textViewportLayoutController:fixture.canvas.textViewportLayoutController
                                            addRenderingSurface:contentsBack
                                                          group:0
                                                      placement:1]);
    XCTAssertTrue([fixture.canvas textViewportLayoutController:fixture.canvas.textViewportLayoutController
                                            addRenderingSurface:contentsFront
                                                          group:0
                                                      placement:0]);

    NSArray<UIView *> *subviews = fixture.canvas.subviews;
    XCTAssertLessThan([subviews indexOfObject:backgroundBack],
                      [subviews indexOfObject:backgroundFront]);
    XCTAssertLessThan([subviews indexOfObject:backgroundFront],
                      [subviews indexOfObject:selection]);
    XCTAssertLessThan([subviews indexOfObject:selection],
                      [subviews indexOfObject:contentsBack]);
    XCTAssertLessThan([subviews indexOfObject:contentsBack],
                      [subviews indexOfObject:contentsFront]);
    XCTAssertTrue(CGRectEqualToRect(backgroundBack.frame, fixture.canvas.bounds));
    XCTAssertEqual(backgroundBack.autoresizingMask,
                   UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
}

- (void)testExternalRenderingSurfaceRejectsNilAndUnsupportedGroupOrPlacementByStage {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"invalid"
                size:CGSizeMake(220, 80)];
    XCTAssertThrowsSpecificNamed(
        [fixture.canvas textViewportLayoutController:fixture.canvas.textViewportLayoutController
                                  addRenderingSurface:nil
                                                group:0
                                            placement:0],
        NSException,
        NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(
        [fixture.canvas textViewportLayoutController:fixture.canvas.textViewportLayoutController
                                  addRenderingSurface:[UIView new]
                                                group:2
                                            placement:0],
        NSException,
        NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(
        [fixture.canvas textViewportLayoutController:fixture.canvas.textViewportLayoutController
                                  addRenderingSurface:[UIView new]
                                                group:0
                                            placement:2],
        NSException,
        NSInternalInconsistencyException);
}

- (void)testUIKitParagraphAnchoredBoundsOracleOffsetsMemberFrameByFragmentOrigin {
    IDAnchoredBoundsOracleAttachment *attachment =
        [IDAnchoredBoundsOracleAttachment new];
    attachment.frame = CGRectMake(31, 47, 36, 20);
    IDAnchoredBoundsOracleFragment *fragment =
        [[IDAnchoredBoundsOracleFragment alloc] initForAnchoredBoundsOracle];
    fragment.probeAnchoredAttachments = @[attachment];
    fragment.probeLayoutFragmentFrameOrigin = CGPointMake(11, 17);

    CGRect result =
        [fragment boundsForTextParagraphAnchoredAttachment:attachment];

    XCTAssertTrue(CGRectEqualToRect(result, CGRectMake(20, 30, 36, 20)));
}

- (void)testUIKitParagraphAnchoredBoundsOracleReturnsZeroForNonmember {
    IDAnchoredBoundsOracleAttachment *member =
        [IDAnchoredBoundsOracleAttachment new];
    member.frame = CGRectMake(31, 47, 36, 20);
    IDAnchoredBoundsOracleFragment *fragment =
        [[IDAnchoredBoundsOracleFragment alloc] initForAnchoredBoundsOracle];
    fragment.probeAnchoredAttachments = @[member];
    fragment.probeLayoutFragmentFrameOrigin = CGPointMake(11, 17);

    CGRect result = [fragment
        boundsForTextParagraphAnchoredAttachment:
            [IDAnchoredBoundsOracleAttachment new]];

    XCTAssertTrue(CGRectEqualToRect(result, CGRectZero));
}

- (void)testUIKitParagraphAnchoredBoundsOracleMatchesRealTextKit2Fragment {
    Class anchoredClass = NSClassFromString(@"NSTextParagraphAnchoredAttachment");
    void *symbol = dlsym(RTLD_DEFAULT,
                         "NSTextParagraphAnchoredAttachmentAttributeName");
    XCTAssertNotNil(anchoredClass);
    XCTAssertNotEqual(symbol, NULL);
    if (anchoredClass == Nil || symbol == NULL) return;

    NSString *attributeName =
        *(__unsafe_unretained NSString **)symbol;
    SEL initializer = NSSelectorFromString(@"initWithTextAttachment:position:");
    XCTAssertNotNil(attributeName);
    XCTAssertTrue([anchoredClass instancesRespondToSelector:initializer]);
    if (attributeName == nil ||
        ![anchoredClass instancesRespondToSelector:initializer]) return;

    id anchored = ((id (*)(id, SEL, id, NSInteger))objc_msgSend)(
        [anchoredClass alloc], initializer, [IDTask5Attachment new], 0);
    XCTAssertNotNil(anchored);
    if (anchored == nil) return;

    NSMutableAttributedString *text =
        [[NSMutableAttributedString alloc] initWithString:@"\uFFFC"];
    [text addAttribute:attributeName value:anchored range:NSMakeRange(0, 1)];
    NSTextContentStorage *contentStorage = [NSTextContentStorage new];
    NSTextLayoutManager *layoutManager = [NSTextLayoutManager new];
    NSTextContainer *textContainer =
        [[NSTextContainer alloc] initWithSize:CGSizeMake(240, 200)];
    [contentStorage addTextLayoutManager:layoutManager];
    layoutManager.textContainer = textContainer;
    [contentStorage performEditingTransactionUsingBlock:^{
        [contentStorage.textStorage setAttributedString:text];
    }];
    [layoutManager ensureLayoutForRange:contentStorage.documentRange];

    __block NSTextLayoutFragment *fragment = nil;
    [layoutManager
        enumerateTextLayoutFragmentsFromLocation:contentStorage.documentRange.location
                                         options:0
                                      usingBlock:^BOOL(NSTextLayoutFragment *candidate) {
        if ([[candidate anchoredTextAttachments] containsObject:anchored]) {
            fragment = candidate;
            return NO;
        }
        return YES;
    }];
    XCTAssertNotNil(fragment);
    if (fragment == nil) return;

    XCTAssertTrue([[fragment anchoredTextAttachments] containsObject:anchored]);
    CGRect oracle =
        [fragment boundsForTextParagraphAnchoredAttachment:anchored];
    XCTAssertTrue(isfinite(oracle.origin.x));
    XCTAssertTrue(isfinite(oracle.origin.y));
    XCTAssertTrue(isfinite(oracle.size.width));
    XCTAssertTrue(isfinite(oracle.size.height));
    CGRect globalFrame = ((CGRect (*)(id, SEL))objc_msgSend)(
        anchored, NSSelectorFromString(@"frame"));
    CGPoint origin = fragment.layoutFragmentFrame.origin;
    CGFloat tolerance =
        1.0 / MAX(UITraitCollection.currentTraitCollection.displayScale, 1.0);
    XCTAssertEqualWithAccuracy(oracle.origin.x,
                               globalFrame.origin.x - origin.x,
                               tolerance);
    XCTAssertEqualWithAccuracy(oracle.origin.y,
                               globalFrame.origin.y - origin.y,
                               tolerance);
    XCTAssertEqualWithAccuracy(oracle.size.width,
                               globalFrame.size.width,
                               tolerance);
    XCTAssertEqualWithAccuracy(oracle.size.height,
                               globalFrame.size.height,
                               tolerance);
}

- (void)testParagraphAnchoredProviderFrameSurvivesScrollAndRemovesWhenFragmentLeavesViewport {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor"
                size:CGSizeMake(220, 80)];
    IDTask5AnchoredFragment *fragment = [[IDTask5AnchoredFragment alloc] initForTesting];
    (void)[fixture.canvas id_renderingSurfaceForTextLayoutFragment:fragment];
    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];
    NSObject *attachment = [NSObject new];

    UIView *anchored = [fixture.canvas
        id_renderingSurfaceForTextParagraphAnchoredAttachment:attachment
                                     associatedLayoutFragment:fragment];
    [anchored setNeedsLayout];
    [anchored layoutIfNeeded];
    CGRect initialFrame = anchored.frame;
    XCTAssertEqual(fragment.providerRequestCount, 1U);
    XCTAssertEqual(fragment.probeProvider.view.superview, anchored);
    XCTAssertTrue(CGRectEqualToRect(fragment.probeProvider.view.frame, anchored.bounds));
    XCTAssertFalse(CGRectIsEmpty(initialFrame));

    fixture.canvas.viewportOverride = CGRectMake(0, 12, 220, 80);
    [fixture.canvas id_viewportWillLayout];
    UIView *sameAnchored = [fixture.canvas
        id_renderingSurfaceForTextParagraphAnchoredAttachment:attachment
                                     associatedLayoutFragment:fragment];
    [sameAnchored setNeedsLayout];
    [sameAnchored layoutIfNeeded];
    [fixture.canvas id_viewportDidLayout];
    XCTAssertEqual(sameAnchored, anchored);
    XCTAssertTrue(CGRectEqualToRect(sameAnchored.frame, initialFrame));
    XCTAssertEqual(fragment.providerRequestCount, 1U);
    XCTAssertEqual(fragment.probeProvider.view.superview, sameAnchored);
    XCTAssertTrue(CGRectEqualToRect(fragment.probeProvider.view.frame,
                                    sameAnchored.bounds));

    fixture.canvas.viewportOverride = CGRectMake(0, 1000, 220, 80);
    [fixture.canvas id_viewportWillLayout];
    [fixture.canvas id_viewportDidLayout];
    XCTAssertNil(anchored.superview);
    XCTAssertNil(fragment.probeProvider.view.superview);
}

- (void)testParagraphAnchoredFrameConvertsRealizedFragmentSurfaceIntoCanvasCoordinates {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor" size:CGSizeMake(220, 80)];
    IDTask5AnchoredFragment *fragment = [[IDTask5AnchoredFragment alloc] initForTesting];
    UIView *surface = [fixture.canvas id_renderingSurfaceForTextLayoutFragment:fragment];
    surface.frame = CGRectMake(17, 29, 200, 40);
    fragment.probeAnchoredBounds = CGRectMake(12, 6, 36, 20);

    CGRect frame = [fixture.canvas
        id_frameForParagraphAnchoredAttachment:[NSObject new]
                                layoutFragment:fragment];

    XCTAssertTrue(CGRectEqualToRect(frame, CGRectMake(29, 35, 36, 20)));
}

- (void)testParagraphAnchoredFrameClampsHorizontalGeometryToCanvasWidth {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor" size:CGSizeMake(220, 80)];
    NSArray<NSDictionary *> *cases = @[
        @{@"bounds": [NSValue valueWithCGRect:CGRectMake(-10, 6, 40, 20)],
          @"expected": [NSValue valueWithCGRect:CGRectMake(0, 30, 30, 20)]},
        @{@"bounds": [NSValue valueWithCGRect:CGRectMake(210, 6, 40, 20)],
          @"expected": [NSValue valueWithCGRect:CGRectMake(210, 30, 10, 20)]},
        @{@"bounds": [NSValue valueWithCGRect:CGRectMake(-10, 6, 250, 20)],
          @"expected": [NSValue valueWithCGRect:CGRectMake(0, 30, 220, 20)]},
    ];

    for (NSDictionary *testCase in cases) {
        IDTask5AnchoredFragment *fragment =
            [[IDTask5AnchoredFragment alloc] initForTesting];
        fragment.probeFragmentFrame = CGRectMake(0, 24, 200, 40);
        fragment.probeAnchoredBounds = [testCase[@"bounds"] CGRectValue];
        CGRect frame = [fixture.canvas
            id_frameForParagraphAnchoredAttachment:[NSObject new]
                                    layoutFragment:fragment];
        XCTAssertTrue(CGRectEqualToRect(frame,
                                        [testCase[@"expected"] CGRectValue]));
    }
}

- (void)testParagraphAnchoredFrameUsesStandardizedCanvasWidthWithoutChangingVerticalGeometry {
    NSArray<NSDictionary *> *cases = @[
        @{@"boundsWidth": @0, @"expectedWidth": @0},
        @{@"boundsWidth": @(-10), @"expectedWidth": @10},
    ];
    for (NSDictionary *testCase in cases) {
        IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
            initWithText:@"anchor" size:CGSizeMake(220, 80)];
        IDTask5BoundsProbeCanvas *canvas = [[IDTask5BoundsProbeCanvas alloc]
            initWithTextLayoutManager:fixture.layoutManager
                        textContainer:fixture.textContainer];
        canvas.probeBounds = CGRectMake(
            0, 0, [testCase[@"boundsWidth"] doubleValue], 80);
        canvas.usesProbeBounds = YES;
        IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
        context.containerOrigin = CGPointMake(0, 9);
        canvas.context = context;
        IDTask5AnchoredFragment *fragment =
            [[IDTask5AnchoredFragment alloc] initForTesting];
        fragment.probeFragmentFrame = CGRectMake(0, 24, 200, 40);
        fragment.probeAnchoredBounds = CGRectMake(-10, -7, 40, 31);

        CGRect frame = [canvas
            id_frameForParagraphAnchoredAttachment:[NSObject new]
                                    layoutFragment:fragment];

        XCTAssertEqual(frame.origin.x, 0);
        XCTAssertEqual(frame.size.width,
                       [testCase[@"expectedWidth"] doubleValue]);
        XCTAssertEqual(frame.origin.y, 26);
        XCTAssertEqual(frame.size.height, 31);
    }
}

- (void)testParagraphAnchoredFrameRejectsNonfiniteBoundsAndFallbackGeometry {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor" size:CGSizeMake(220, 80)];
    NSObject *attachment = [NSObject new];

    IDTask5AnchoredFragment *nonfiniteBounds =
        [[IDTask5AnchoredFragment alloc] initForTesting];
    nonfiniteBounds.probeAnchoredBounds = CGRectMake(NAN, 0, 10, 10);
    XCTAssertThrowsSpecificNamed(
        [fixture.canvas id_frameForParagraphAnchoredAttachment:attachment
                                               layoutFragment:nonfiniteBounds],
        NSException, NSInternalInconsistencyException);

    IDTask5AnchoredFragment *nonfiniteFallback =
        [[IDTask5AnchoredFragment alloc] initForTesting];
    nonfiniteFallback.probeFragmentFrame = CGRectMake(INFINITY, 0, 10, 10);
    XCTAssertThrowsSpecificNamed(
        [fixture.canvas id_frameForParagraphAnchoredAttachment:attachment
                                               layoutFragment:nonfiniteFallback],
        NSException, NSInternalInconsistencyException);
}

- (void)testParagraphAnchoredProviderViewIsRemovedOnFlush {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor" size:CGSizeMake(220, 80)];
    IDTask5AnchoredFragment *fragment =
        [[IDTask5AnchoredFragment alloc] initForTesting];
    (void)[fixture.canvas id_renderingSurfaceForTextLayoutFragment:fragment];
    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];
    UIView *anchored = [fixture.canvas
        id_renderingSurfaceForTextParagraphAnchoredAttachment:[NSObject new]
                                     associatedLayoutFragment:fragment];
    [anchored layoutIfNeeded];
    UIView *providerView = fragment.probeProvider.view;

    XCTAssertEqual(providerView.superview, anchored);
    [fixture.canvas id_flushElementViews];

    XCTAssertNil(anchored.superview);
    XCTAssertNil(providerView.superview);
}

- (void)testParagraphAnchoredFallbackFrameIncludesNonzeroTextContainerOrigin {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor" size:CGSizeMake(220, 80)];
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    context.containerOrigin = CGPointMake(7, 9);
    fixture.canvas.context = context;
    IDTask5AnchoredFragment *fragment = [[IDTask5AnchoredFragment alloc] initForTesting];
    fragment.probeFragmentFrame = CGRectMake(10, 24, 200, 40);
    NSObject *attachment = [NSObject new];

    CGRect frame = [fixture.canvas
        id_frameForParagraphAnchoredAttachment:attachment
                                layoutFragment:fragment];

    XCTAssertTrue(CGRectEqualToRect(frame, CGRectMake(29, 39, 36, 20)));
}

- (void)testParagraphAnchoredProviderViewSuppressesFallbackDrawing {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor" size:CGSizeMake(220, 80)];
    IDTask5AnchoredFragment *fragment = [[IDTask5AnchoredFragment alloc] initForTesting];
    (void)[fixture.canvas id_renderingSurfaceForTextLayoutFragment:fragment];
    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];
    NSObject *attachment = [NSObject new];
    UIView *anchored = [fixture.canvas
        id_renderingSurfaceForTextParagraphAnchoredAttachment:attachment
                                     associatedLayoutFragment:fragment];
    [anchored layoutSubviews];
    IDTask5DrawView(anchored);

    XCTAssertEqual(fragment.probeProvider.view.superview, anchored);
    XCTAssertEqual(fragment.drawCount, 0U);
}

- (void)testParagraphAnchoredNilProviderUsesFallbackDrawing {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"anchor" size:CGSizeMake(220, 80)];
    IDTask5AnchoredFragment *fragment = [[IDTask5AnchoredFragment alloc] initForTesting];
    fragment.probeProvider = nil;
    (void)[fixture.canvas id_renderingSurfaceForTextLayoutFragment:fragment];
    [fixture.canvas id_configureRenderingSurfaceForTextLayoutFragment:fragment];
    NSObject *attachment = [NSObject new];
    UIView *anchored = [fixture.canvas
        id_renderingSurfaceForTextParagraphAnchoredAttachment:attachment
                                     associatedLayoutFragment:fragment];
    [anchored layoutSubviews];
    IDTask5DrawView(anchored);

    XCTAssertGreaterThan(fragment.drawCount, 0U);
}

- (void)testWritingToolsStateSurvivesViewportLayoutButClearsOnFlush {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"writing tools"
                size:CGSizeMake(220, 80)];
    NSObject *info = [NSObject new];
    fixture.canvas.uniqueWritingToolsAnimatedLayoutInfo = info;
    [fixture.canvas performViewportLayout];
    XCTAssertEqual(fixture.canvas.uniqueWritingToolsAnimatedLayoutInfo, info);

    [fixture.canvas id_flushElementViews];
    XCTAssertNil(fixture.canvas.uniqueWritingToolsAnimatedLayoutInfo);
}

- (void)testHoverEffectContainerTracksCanvasBounds {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"hover"
                size:CGSizeMake(220, 80)];
    [fixture.canvas layoutIfNeeded];
    CALayer *hoverLayer = fixture.canvas.hoverEffectContainerLayer;
    XCTAssertTrue(hoverLayer == nil ||
                  CGRectEqualToRect(hoverLayer.frame, fixture.canvas.layer.bounds));
}

- (void)testPostLayoutContextCallbacksObserveCanvasBeforeInteractionGeometry {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"callbacks"
                size:CGSizeMake(220, 80)];
    IDTask5CanvasContextProbe *context = [IDTask5CanvasContextProbe new];
    fixture.canvas.context = context;
    [fixture.canvas performViewportLayout];
    XCTAssertEqualObjects(context.postLayoutEvents, (@[@"canvas"]));
}

@end
