@import XCTest;

#import "IDBlockStackCanvasView.h"
#import "IDBlockLayout.h"
#import "IDBlockTextTestSupport.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDDocumentLayoutCoordinator.h"
#import "IDNativeSelectionPresentationBackend.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextSelectionRect.h"
#import "IDSelectionPresentation.h"
#import "IDVerticalAutoscroll.h"
#import "IDUIKitInteractionCapability.h"

@interface IDRecordingSelectionPresentationBackend : NSObject
    <IDSelectionPresentationBackend>
@property(nonatomic, weak) IDBlockTextView *hostView;
@property(nonatomic, strong, nullable) UIView *existingSelectionContainerView;
@property(nonatomic) NSUInteger presentationUpdateCount;
@property(nonatomic) NSUInteger selectionContainerCreationCount;
@property(nonatomic, strong, nullable) IDSelectionPresentationSnapshot *lastSnapshot;
@property(nonatomic, strong) NSMutableArray<IDSelectionPresentationSnapshot *> *snapshots;
@property(nonatomic, strong, nullable) NSMutableArray<NSString *> *eventSink;
@property(nonatomic) BOOL didTearDown;
- (instancetype)initWithHostView:(IDBlockTextView *)hostView;
@end

@interface IDFailingSelectionPresentationBlockTextView : IDBlockTextView
@end

@implementation IDFailingSelectionPresentationBlockTextView
- (void)id_installInteractionAssistant {
    [NSException raise:NSInternalInconsistencyException
                format:@"Injected failure after backend creation"];
}
@end

@interface IDPresentationSelectionCoordinator : IDDocumentLayoutCoordinator
@property(nonatomic, strong, nullable) IDDocumentSelectionGeometry *selectionResult;
@property(nonatomic) NSUInteger selectionRequestCount;
@end

@implementation IDPresentationSelectionCoordinator
- (IDDocumentSelectionGeometry *)selectionGeometryForCanonicalRange:(NSRange)range {
    (void)range;
    self.selectionRequestCount += 1;
    return self.selectionResult;
}
@end

@implementation IDRecordingSelectionPresentationBackend

- (instancetype)initWithHostView:(IDBlockTextView *)hostView {
    self = [super init];
    if (self != nil) {
        _hostView = hostView;
        _snapshots = [NSMutableArray array];
    }
    return self;
}

- (UIView *)id_selectionContainerView {
    if (self.existingSelectionContainerView == nil) {
        UIView *container = [[UIView alloc] initWithFrame:self.hostView.bounds];
        container.userInteractionEnabled = NO;
        container.backgroundColor = UIColor.clearColor;
        self.existingSelectionContainerView = container;
        [self.hostView addSubview:container];
        self.selectionContainerCreationCount += 1;
    }
    return self.existingSelectionContainerView;
}

- (void)placeSelectionContainerView {
    UIView *container = self.existingSelectionContainerView;
    if (container != nil) {
        container.frame = self.hostView.bounds;
        [self.hostView bringSubviewToFront:container];
    }
}

- (void)updateWithSnapshot:(IDSelectionPresentationSnapshot *)snapshot {
    self.lastSnapshot = snapshot;
    [self.snapshots addObject:snapshot];
    [self.eventSink addObject:@"presentation"];
    self.presentationUpdateCount += 1;
    [self placeSelectionContainerView];
}

- (void)tearDown {
    [self.existingSelectionContainerView removeFromSuperview];
    self.existingSelectionContainerView = nil;
    self.didTearDown = YES;
}

@end

@interface IDEdgeScrollOrderingBlockTextView : IDBlockTextView
@property(nonatomic, strong) NSMutableArray<NSString *> *orderingEvents;
@property(nonatomic, copy) NSArray<NSValue *> *completedLayoutOrigins;
@property(nonatomic) CGRect visibleBoundsAtInteractionInvalidation;
@property(nonatomic) NSTimeInterval lastAutoscrollDuration;
@end

@interface IDVerticalAutoscrollTickFixture : IDVerticalAutoscroll
@property(nonatomic, weak) UIScrollView *fixtureContainer;
@property(nonatomic) CGPoint fixturePoint;
@property(nonatomic) IDVerticalAutoscrollDirection fixtureDirections;
@property(nonatomic) NSUInteger fixtureCount;
@property(nonatomic) BOOL fixtureInvalidated;
@end

@implementation IDVerticalAutoscrollTickFixture
- (UIScrollView *)id_scrollContainer { return self.fixtureContainer; }
- (CGPoint)point { return self.fixturePoint; }
- (IDVerticalAutoscrollDirection)directions {
    return self.fixtureDirections;
}
- (NSUInteger)count { return self.fixtureCount; }
- (void)invalidate {
    self.fixtureInvalidated = YES;
    [super invalidate];
}
@end

@interface IDInteractionInvalidationRecordingProxy : NSProxy
@property(nonatomic, strong) id target;
@property(nonatomic, strong) NSMutableArray<NSString *> *eventSink;
+ (instancetype)proxyWithTarget:(id)target
                      eventSink:(NSMutableArray<NSString *> *)eventSink;
@end

@implementation IDInteractionInvalidationRecordingProxy
+ (instancetype)proxyWithTarget:(id)target
                      eventSink:(NSMutableArray<NSString *> *)eventSink {
    IDInteractionInvalidationRecordingProxy *proxy = [self alloc];
    proxy.target = target;
    proxy.eventSink = eventSink;
    return proxy;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.target methodSignatureForSelector:selector];
}
- (BOOL)respondsToSelector:(SEL)selector {
    return [self.target respondsToSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    // The capability's own method (it no longer shares UIKit's private name, `TGPrivateRuntimeNames.h`).
    if (invocation.selector == @selector(id_setNeedsSelectionDisplayUpdate)) {
        [self.eventSink addObject:@"interaction"];
    }
    [invocation invokeWithTarget:self.target];
}
@end

@implementation IDEdgeScrollOrderingBlockTextView
- (void)setContentOffset:(CGPoint)contentOffset {
    BOOL changed = !CGPointEqualToPoint(self.contentOffset, contentOffset);
    [super setContentOffset:contentOffset];
    if (changed && self.orderingEvents != nil) {
        [self.orderingEvents addObject:@"offset"];
    }
}
- (void)id_canvasDidLayout {
    NSMutableArray<NSValue *> *origins = [NSMutableArray array];
    for (IDBlockLayout *layout in self.id_blockStack.blockLayouts) {
        [origins addObject:[NSValue valueWithCGPoint:
            [self.id_blockStack documentOriginForBlockIdentifier:layout.blockIdentifier]]];
    }
    self.completedLayoutOrigins = origins.copy;
    [self.orderingEvents addObject:@"layout"];
    UIEdgeInsets insets = self.adjustedContentInset;
    self.visibleBoundsAtInteractionInvalidation = CGRectMake(
        self.contentOffset.x + insets.left,
        self.contentOffset.y + insets.top,
        MAX(CGRectGetWidth(self.bounds) - insets.left - insets.right, 0),
        MAX(CGRectGetHeight(self.bounds) - insets.top - insets.bottom, 0));
    [self.orderingEvents addObject:@"visible"];
    [super id_canvasDidLayout];
}
- (void)id_setVerticalAutoscrollContentOffset:(CGPoint)contentOffset
                                      duration:(NSTimeInterval)duration {
    self.lastAutoscrollDuration = duration;
    [super id_setVerticalAutoscrollContentOffset:contentOffset
                                        duration:duration];
}
@end

@interface IDBlockTextView (IDVerticalAutoscrollTickTestInspection)
- (void)updateVerticalAutoscroll:(IDVerticalAutoscroll *)autoscroll;
- (void)id_setVerticalAutoscrollContentOffset:(CGPoint)contentOffset
                                      duration:(NSTimeInterval)duration;
@end

@interface IDSelectionPresentationBackendTests : XCTestCase
@end

@implementation IDSelectionPresentationBackendTests

- (IDRichTextSelectionRect *)selectionRectWithGeometry:(CGRect)rect {
    return [[IDRichTextSelectionRect alloc]
        initWithRect:rect
        containsStart:YES
        containsEnd:YES
        isVertical:NO
        writingDirection:NSWritingDirectionLeftToRight];
}

- (IDSelectionPresentationSnapshot *)snapshotWithSelection:(NSRange)selection
                                                  caretRect:(CGRect)caretRect
                                             selectionRects:(NSArray<UITextSelectionRect *> *)rects {
    return [[IDSelectionPresentationSnapshot alloc]
        initWithCanonicalSelection:selection
        caretRect:caretRect
        selectionRects:rects
        visibleBounds:CGRectMake(0, 0, 240, 120)
        contentOffset:CGPointZero];
}

- (NSArray<NSAttributedString *> *)blocks {
    return @[
        IDBlockTextTestAttributedString(@"alpha"),
        IDBlockTextTestAttributedString(@"beta gamma"),
    ];
}

- (NSRange)canonicalRangeForView:(IDBlockTextView *)view
                       textRange:(UITextRange *)range {
    NSInteger location = [view offsetFromPosition:view.beginningOfDocument
                                        toPosition:range.start];
    NSInteger length = [view offsetFromPosition:range.start toPosition:range.end];
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (void)installSelection:(NSRange)selection inView:(IDBlockTextView *)view {
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument
                                               offset:(NSInteger)selection.location];
    UITextPosition *end = [view positionFromPosition:start
                                             offset:(NSInteger)selection.length];
    view.selectedTextRange = [view textRangeFromPosition:start toPosition:end];
}

- (void)testNativeBackendCreatesOneStableContainerAndPlacesItAboveBlockStack {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks];
    IDNativeSelectionPresentationBackend *backend =
        (IDNativeSelectionPresentationBackend *)view.id_selectionPresentationBackend;

    UIView *first = [backend id_selectionContainerView];
    UIView *second = [backend id_selectionContainerView];
    [backend placeSelectionContainerView];

    XCTAssertEqual(first, second);
    XCTAssertEqual(backend.selectionContainerCreationCount, 1U);
    XCTAssertEqual(first.superview, view);
    XCTAssertGreaterThan([view.subviews indexOfObject:first],
                         [view.subviews indexOfObject:view.id_blockStackCanvasView]);
    XCTAssertTrue(CGRectEqualToRect(first.frame, view.bounds));
}

// The container hosts UIKit's underline view, and UIKit reads a rect it converted INTO that
// container back as if it were in `-textInputView`'s space when it places the autocorrection
// prompt. Anchoring the container to the host's BOUNDS put those two spaces one content offset
// apart the moment the editor scrolled — the prompt for a corrected word came up that far below it.
- (void)testTheSelectionContainerKeepsTheBlockStacksOriginWhileTheViewIsScrolled {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks];
    view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    view.contentInset = UIEdgeInsetsMake(48, 0, 0, 0);
    view.contentOffset = CGPointMake(0, -48);
    [view layoutIfNeeded];
    IDNativeSelectionPresentationBackend *backend =
        (IDNativeSelectionPresentationBackend *)view.id_selectionPresentationBackend;

    UIView *container = [backend id_selectionContainerView];
    [backend placeSelectionContainerView];

    IDBlockStackCanvasView *stack = view.id_blockStackCanvasView;
    XCTAssertNotNil(stack);
    // Without this the assertions below hold for the wrong reason.
    XCTAssertNotEqual(CGRectGetMinY(view.bounds), 0.0);
    CGPoint origin = [container convertPoint:CGPointZero toView:stack];
    XCTAssertTrue(CGPointEqualToPoint(origin, CGPointZero), @"%@", NSStringFromCGPoint(origin));
    CGRect word = CGRectMake(16, 37, 25, 24);
    CGRect converted = [container convertRect:word fromView:stack];
    XCTAssertTrue(CGRectEqualToRect(converted, word), @"%@", NSStringFromCGRect(converted));
    XCTAssertTrue(CGSizeEqualToSize(container.bounds.size, view.bounds.size));
}

- (void)testRecordingBackendReceivesCanonicalSelectionAndComposedGeometry {
    __block IDRecordingSelectionPresentationBackend *recording = nil;
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                recording = [[IDRecordingSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
                return recording;
            }];
    [self installSelection:NSMakeRange(3, 7) inView:view];
    NSUInteger updateCount = recording.presentationUpdateCount;

    [view id_updateSelectionPresentation];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

    IDSelectionPresentationSnapshot *snapshot = recording.lastSnapshot;
    XCTAssertNotNil(snapshot);
    XCTAssertTrue(NSEqualRanges(snapshot.canonicalSelection, NSMakeRange(3, 7)));
    XCTAssertTrue(CGRectIsNull(snapshot.caretRect));
    XCTAssertGreaterThan(snapshot.selectionRects.count, 0U);
    XCTAssertTrue(CGRectEqualToRect(
        snapshot.visibleBounds,
        CGRectMake(view.contentOffset.x + view.adjustedContentInset.left,
                   view.contentOffset.y + view.adjustedContentInset.top,
                   MAX(CGRectGetWidth(view.bounds) - view.adjustedContentInset.left -
                       view.adjustedContentInset.right, 0),
                   MAX(CGRectGetHeight(view.bounds) - view.adjustedContentInset.top -
                       view.adjustedContentInset.bottom, 0))));
    XCTAssertTrue(CGPointEqualToPoint(snapshot.contentOffset, view.contentOffset));
    XCTAssertEqual(recording.presentationUpdateCount, updateCount + 1);
}

- (void)testEdgeScrollLayoutPublishesSynchronizedGeometryAfterInteractionInvalidation {
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSUInteger index = 0; index < 12; index += 1) {
        [blocks addObject:IDBlockTextTestAttributedString(
            [NSString stringWithFormat:@"block %02lu has wrapped selection text",
                                       (unsigned long)index])];
    }
    __block IDRecordingSelectionPresentationBackend *recording = nil;
    IDEdgeScrollOrderingBlockTextView *view = [[IDEdgeScrollOrderingBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 180, 90)
        attributedBlocks:blocks
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                recording = [[IDRecordingSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
                return recording;
            }];
    view.orderingEvents = [NSMutableArray array];
    recording.eventSink = view.orderingEvents;
    view.id_interactionCapability =
        (IDUIKitInteractionCapability *)
        [IDInteractionInvalidationRecordingProxy
            proxyWithTarget:view.id_interactionCapability
                  eventSink:view.orderingEvents];
    [view layoutIfNeeded];
    [self installSelection:NSMakeRange(12, 72) inView:view];
    [view.id_selectionPresentationBackend id_selectionContainerView];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    NSUInteger updateCount = recording.presentationUpdateCount;
    NSRange unchangedSelection = [self canonicalRangeForView:view
                                                   textRange:view.selectedTextRange];
    NSArray<UITextSelectionRect *> *initialRects = recording.lastSnapshot.selectionRects;
    [view.orderingEvents removeAllObjects];

    view.contentOffset = CGPointMake(0, 40);
    [view setNeedsLayout];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];

    IDSelectionPresentationSnapshot *snapshot = recording.lastSnapshot;
    XCTAssertGreaterThan(recording.presentationUpdateCount, updateCount);
    XCTAssertEqual(recording.selectionContainerCreationCount, 1U);
    XCTAssertTrue(CGPointEqualToPoint(snapshot.contentOffset, view.contentOffset));
    XCTAssertTrue(CGRectEqualToRect(
        snapshot.visibleBounds,
        CGRectMake(view.contentOffset.x + view.adjustedContentInset.left,
                   view.contentOffset.y + view.adjustedContentInset.top,
                   MAX(CGRectGetWidth(view.bounds) - view.adjustedContentInset.left -
                       view.adjustedContentInset.right, 0),
                   MAX(CGRectGetHeight(view.bounds) - view.adjustedContentInset.top -
                       view.adjustedContentInset.bottom, 0))));
    XCTAssertTrue(NSEqualRanges(snapshot.canonicalSelection, unchangedSelection));
    XCTAssertEqual(view.completedLayoutOrigins.count, view.id_blockStack.blockLayouts.count);
    for (NSUInteger index = 0; index < view.completedLayoutOrigins.count; index += 1) {
        IDBlockLayout *layout = view.id_blockStack.blockLayouts[index];
        XCTAssertTrue(CGPointEqualToPoint(
            view.completedLayoutOrigins[index].CGPointValue,
            [view.id_blockStack documentOriginForBlockIdentifier:layout.blockIdentifier]));
    }
    XCTAssertTrue(CGRectEqualToRect(view.visibleBoundsAtInteractionInvalidation,
                                    snapshot.visibleBounds));
    XCTAssertEqual(snapshot.selectionRects.count, initialRects.count,
                   @"Block-origin composition must remain current across viewport movement");
    for (NSUInteger index = 0; index < snapshot.selectionRects.count; index += 1) {
        XCTAssertTrue(CGRectEqualToRect(snapshot.selectionRects[index].rect,
                                        initialRects[index].rect));
    }
    XCTAssertEqualObjects(view.orderingEvents,
                          (@[@"offset", @"layout", @"visible", @"interaction",
                             @"presentation"]));
}

- (void)testCleanAutoscrollTickMovesOnlyTrailingEndpointAndPublishesInOrder {
    NSMutableArray<NSAttributedString *> *blocks =
        [NSMutableArray array];
    for (NSUInteger index = 0; index < 20; index += 1) {
        [blocks addObject:IDBlockTextTestAttributedString(
            [NSString stringWithFormat:
                @"block %02lu has enough wrapped words for edge selection",
                (unsigned long)index])];
    }
    __block IDRecordingSelectionPresentationBackend *recording = nil;
    IDEdgeScrollOrderingBlockTextView *view =
        [[IDEdgeScrollOrderingBlockTextView alloc]
            initWithFrame:CGRectMake(0, 0, 180, 90)
            attributedBlocks:blocks
            selectionPresentationBackendFactory:
                ^id<IDSelectionPresentationBackend>(
                    IDBlockTextView *hostView) {
                    recording =
                        [[IDRecordingSelectionPresentationBackend alloc]
                            initWithHostView:hostView];
                    return recording;
                }];
    view.orderingEvents = [NSMutableArray array];
    recording.eventSink = view.orderingEvents;
    view.id_interactionCapability =
        (IDUIKitInteractionCapability *)
        [IDInteractionInvalidationRecordingProxy
            proxyWithTarget:view.id_interactionCapability
                  eventSink:view.orderingEvents];
    [view layoutIfNeeded];
    [self installSelection:NSMakeRange(12, 18) inView:view];
    view.id_activeAutoscrollEndpoint =
        IDVerticalAutoscrollSelectionEndpointEnd;
    UIView *container =
        [view.id_selectionPresentationBackend id_selectionContainerView];
    [NSRunLoop.mainRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    NSUInteger presentationCount =
        recording.presentationUpdateCount;
    [view.orderingEvents removeAllObjects];

    IDVerticalAutoscrollTickFixture *fixture =
        [IDVerticalAutoscrollTickFixture new];
    fixture.fixtureContainer = view;
    fixture.fixturePoint =
        CGPointMake(100, CGRectGetMaxY(view.bounds) + 500);
    fixture.fixtureDirections =
        IDVerticalAutoscrollDirectionDown;
    fixture.fixtureCount = 1;
    view.id_verticalAutoscroll = fixture;
    [view updateVerticalAutoscroll:fixture];
    [NSRunLoop.mainRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

    NSRange selection = [self canonicalRangeForView:view
                                           textRange:view.selectedTextRange];
    XCTAssertEqual(selection.location, 12U);
    XCTAssertGreaterThan(NSMaxRange(selection), 30U);
    XCTAssertGreaterThan(view.contentOffset.y, 0.0);
    XCTAssertGreaterThan(view.lastAutoscrollDuration, 0.0);
    XCTAssertEqual(
        container,
        view.id_selectionPresentationBackend.existingSelectionContainerView);
    XCTAssertEqual(
        view.id_selectionPresentationBackend.selectionContainerCreationCount,
        1U);
    XCTAssertEqual(recording.presentationUpdateCount,
                   presentationCount + 1);
    XCTAssertEqualObjects(
        view.orderingEvents,
        (@[@"offset", @"layout", @"visible", @"interaction",
           @"presentation"]));
    NSUInteger interactionIndex =
        [view.orderingEvents indexOfObject:@"interaction"];
    NSUInteger presentationIndex =
        [view.orderingEvents indexOfObject:@"presentation"];
    XCTAssertNotEqual(interactionIndex, NSNotFound);
    XCTAssertNotEqual(presentationIndex, NSNotFound);
    XCTAssertLessThan(interactionIndex, presentationIndex);
}

- (void)testCleanAutoscrollTickMovesOnlyLeadingEndpointAcrossBlocks {
    NSMutableArray<NSAttributedString *> *blocks =
        [NSMutableArray array];
    for (NSUInteger index = 0; index < 20; index += 1) {
        [blocks addObject:IDBlockTextTestAttributedString(
            [NSString stringWithFormat:
                @"block %02lu has enough wrapped words for edge selection",
                (unsigned long)index])];
    }
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 180, 90)
        attributedBlocks:blocks];
    [view layoutIfNeeded];
    CGFloat maximumOffsetY =
        view.contentSize.height - CGRectGetHeight(view.bounds) +
        view.adjustedContentInset.bottom;
    view.contentOffset = CGPointMake(0, maximumOffsetY);
    [self installSelection:NSMakeRange(120, 45) inView:view];
    view.id_activeAutoscrollEndpoint =
        IDVerticalAutoscrollSelectionEndpointStart;
    view.id_autoscrollPointReferenceOffsetY =
        view.contentOffset.y;

    IDVerticalAutoscrollTickFixture *fixture =
        [IDVerticalAutoscrollTickFixture new];
    fixture.fixtureContainer = view;
    fixture.fixturePoint = CGPointMake(50, -500);
    fixture.fixtureDirections = IDVerticalAutoscrollDirectionUp;
    fixture.fixtureCount = 1;
    view.id_verticalAutoscroll = fixture;
    [view updateVerticalAutoscroll:fixture];

    NSRange selection = [self canonicalRangeForView:view
                                           textRange:view.selectedTextRange];
    XCTAssertLessThan(selection.location, 120U);
    XCTAssertEqual(NSMaxRange(selection), 165U);
    XCTAssertLessThan(view.contentOffset.y, maximumOffsetY);
    XCTAssertGreaterThan(
        view.contentOffset.y,
        -view.adjustedContentInset.top);
}

- (void)testAutoscrollTickReprojectsTheFingerAgainstTheOffsetItMeasured {
    // The finger does not move between ticks; the CONTENT moves under it. So the document position
    // under the finger must be computed against the scroll offset the tick measured — the one the
    // user is looking at — and not against the offset the tick has just scrolled to.
    //
    // `-id_setVerticalAutoscrollContentOffset:duration:` assigns `contentOffset` synchronously
    // (inside an animation block, so the screen follows over the next 75ms). Reprojecting from
    // `self.contentOffset.y` afterwards therefore reads a position the screen has not reached, and
    // the dragged handle is placed there and then overtaken by the content sliding under it — which
    // is what "the handle I am dragging animates" looks like (reported 2026-09-15).
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSUInteger index = 0; index < 20; index += 1) {
        [blocks addObject:IDBlockTextTestAttributedString(
            [NSString stringWithFormat:
                @"block %02lu has enough wrapped words for edge selection",
                (unsigned long)index])];
    }
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 180, 90)
        attributedBlocks:blocks];
    [view layoutIfNeeded];
    CGFloat maximumOffsetY =
        view.contentSize.height - CGRectGetHeight(view.bounds) +
        view.adjustedContentInset.bottom;
    view.contentOffset = CGPointMake(0, maximumOffsetY);
    // The selection sits in what is VISIBLE, so the endpoint being dragged actually lands on the
    // reprojected point instead of collapsing onto the other end.
    NSInteger documentLength =
        [view offsetFromPosition:view.beginningOfDocument
                      toPosition:view.endOfDocument];
    XCTAssertGreaterThan(documentLength, 60);
    [self installSelection:NSMakeRange((NSUInteger)documentLength - 30, 20)
                    inView:view];
    view.id_activeAutoscrollEndpoint =
        IDVerticalAutoscrollSelectionEndpointStart;
    view.id_autoscrollPointReferenceOffsetY = view.contentOffset.y;

    IDVerticalAutoscrollTickFixture *fixture =
        [IDVerticalAutoscrollTickFixture new];
    fixture.fixtureContainer = view;
    // The finger at the TOP EDGE of what is visible, not far off in space. The autoscroll point is
    // in the scroll view's CONTENT coordinates, so a point hundreds of points above the document
    // resolves to offset 0 whichever scroll offset is used to reproject it, and proves nothing.
    fixture.fixturePoint = CGPointMake(50, maximumOffsetY);
    fixture.fixtureDirections = IDVerticalAutoscrollDirectionUp;
    fixture.fixtureCount = 1;
    view.id_verticalAutoscroll = fixture;

    // The oracle: what the finger is over as the screen looks NOW, before the tick scrolls.
    CGPoint asSeen = fixture.fixturePoint;
    asSeen.y += view.contentOffset.y - view.id_autoscrollPointReferenceOffsetY;
    UITextPosition *expectedPosition = [view closestPositionToPoint:
        [view.id_blockStack convertPoint:asSeen fromView:view]];
    XCTAssertNotNil(expectedPosition);
    NSInteger expected = [view offsetFromPosition:view.beginningOfDocument
                                       toPosition:expectedPosition];
    CGFloat offsetBefore = view.contentOffset.y;

    [view updateVerticalAutoscroll:fixture];

    XCTAssertNotEqual(view.contentOffset.y, offsetBefore,
                      @"the tick is expected to scroll, or this proves nothing");
    NSRange selection = [self canonicalRangeForView:view
                                           textRange:view.selectedTextRange];
    XCTAssertEqual((NSInteger)selection.location, expected);
}

- (void)testCleanAutoscrollTickAtExhaustedBoundaryInvalidatesOnlySession {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 180, 90)
        attributedBlocks:self.blocks];
    [view layoutIfNeeded];
    [self installSelection:NSMakeRange(2, 4) inView:view];
    view.contentOffset = CGPointMake(
        0, view.contentSize.height - CGRectGetHeight(view.bounds) +
               view.adjustedContentInset.bottom);
    NSRange before = [self canonicalRangeForView:view
                                        textRange:view.selectedTextRange];

    IDVerticalAutoscrollTickFixture *fixture =
        [IDVerticalAutoscrollTickFixture new];
    fixture.fixtureContainer = view;
    fixture.fixturePoint = CGPointMake(50, 500);
    fixture.fixtureDirections =
        IDVerticalAutoscrollDirectionDown;
    fixture.fixtureCount = 2;
    view.id_verticalAutoscroll = fixture;
    [view updateVerticalAutoscroll:fixture];

    XCTAssertTrue(fixture.fixtureInvalidated);
    XCTAssertTrue(NSEqualRanges(
        [self canonicalRangeForView:view
                          textRange:view.selectedTextRange],
        before));
    XCTAssertNotNil(view.id_document);
    XCTAssertNotNil(view.id_richLayoutController);
    XCTAssertNotNil(view.id_behaviorInput);
    XCTAssertNotNil(view.id_selectionPresentationBackend);
}

- (void)testPureSettledBoundsLayoutPublishesOnceWithoutPendingRequest {
    __block IDRecordingSelectionPresentationBackend *recording = nil;
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                recording = [[IDRecordingSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
                return recording;
            }];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    NSUInteger updateCount = recording.presentationUpdateCount;
    view.bounds = CGRectMake(0, 0, 200, 90);

    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

    XCTAssertEqual(recording.presentationUpdateCount, updateCount + 1);
    XCTAssertTrue(CGSizeEqualToSize(recording.lastSnapshot.visibleBounds.size,
                                    CGSizeMake(200, 90)));
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    XCTAssertEqual(recording.presentationUpdateCount, updateCount + 1);
}

- (void)testEquivalentEditorsWithNativeAndRecordingBackendsKeepSelectionSemantics {
    IDBlockTextView *native = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks];
    IDBlockTextView *recorded = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                return [[IDRecordingSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
            }];
    [self installSelection:NSMakeRange(3, 7) inView:native];
    [self installSelection:NSMakeRange(3, 7) inView:recorded];

    XCTAssertEqualObjects(native.text, recorded.text);
    XCTAssertTrue(NSEqualRanges(
        [self canonicalRangeForView:native textRange:native.selectedTextRange],
        [self canonicalRangeForView:recorded textRange:recorded.selectedTextRange]));
    XCTAssertEqual(native.markedTextRange == nil, recorded.markedTextRange == nil);
    XCTAssertEqual(native.undoManager.canUndo, recorded.undoManager.canUndo);
}

- (void)testBackendTearDownRemovesContainerWithoutChangingDocument {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks];
    id<IDSelectionPresentationBackend> backend = view.id_selectionPresentationBackend;
    UIView *container = [backend id_selectionContainerView];
    NSString *text = view.text;
    [self installSelection:NSMakeRange(3, 7) inView:view];
    NSRange selection = [self canonicalRangeForView:view
                                         textRange:view.selectedTextRange];

    [backend tearDown];

    XCTAssertNil(container.superview);
    XCTAssertNil(backend.existingSelectionContainerView);
    XCTAssertEqualObjects(view.text, text);
    XCTAssertTrue(NSEqualRanges(
        [self canonicalRangeForView:view textRange:view.selectedTextRange], selection));
}

- (void)testPublicationWaitsForOutstandingStorageEdits {
    __block IDRecordingSelectionPresentationBackend *recording = nil;
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                recording = [[IDRecordingSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
                return recording;
            }];
    [self installSelection:NSMakeRange(3, 7) inView:view];
    [view.id_textStorageAdapter beginEditing];
    [view.id_textStorageAdapter replaceCharactersInRange:NSMakeRange(0, 1)
                                              withString:@"A"];
    NSUInteger updateCount = recording.presentationUpdateCount;

    [view id_updateSelectionPresentation];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

    XCTAssertEqual(recording.presentationUpdateCount, updateCount);
    [view.id_textStorageAdapter endEditing];
    XCTAssertEqual(recording.presentationUpdateCount, updateCount);
    [view setNeedsLayout];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    XCTAssertEqual(recording.presentationUpdateCount, updateCount + 1);
    [view layoutIfNeeded];
    XCTAssertEqual(recording.presentationUpdateCount, updateCount + 1);
}

- (void)testInternalInitializerRejectsNilFactory {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrowsSpecificNamed(
        [[IDBlockTextView alloc]
            initWithFrame:CGRectMake(0, 0, 240, 120)
            attributedBlocks:self.blocks
            selectionPresentationBackendFactory:
                (IDSelectionPresentationBackendFactory)nil],
        NSException,
        NSInvalidArgumentException);
#pragma clang diagnostic pop
}

- (void)testInternalInitializerRejectsNilFactoryResult {
    XCTAssertThrowsSpecificNamed(
        [[IDBlockTextView alloc]
            initWithFrame:CGRectMake(0, 0, 240, 120)
            attributedBlocks:self.blocks
            selectionPresentationBackendFactory:
                ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                    return (id<IDSelectionPresentationBackend>)nil;
                }],
        NSException,
        NSInvalidArgumentException);
}

- (void)testConstructionFailureAfterBackendCreationTearsBackendDown {
    __block IDRecordingSelectionPresentationBackend *recording = nil;

    XCTAssertThrowsSpecificNamed(
        [[IDFailingSelectionPresentationBlockTextView alloc]
            initWithFrame:CGRectMake(0, 0, 240, 120)
            attributedBlocks:self.blocks
            selectionPresentationBackendFactory:
                ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                    recording = [[IDRecordingSelectionPresentationBackend alloc]
                        initWithHostView:hostView];
                    [recording id_selectionContainerView];
                    return recording;
                }],
        NSException,
        NSInternalInconsistencyException);
    XCTAssertTrue(recording.didTearDown);
    XCTAssertNil(recording.existingSelectionContainerView);
}

- (void)testSnapshotRejectsNotFoundSelectionAndNilRectangles {
    XCTAssertThrowsSpecificNamed(
        [self snapshotWithSelection:NSMakeRange(NSNotFound, 0)
                          caretRect:CGRectMake(0, 0, 2, 20)
                     selectionRects:@[]],
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [self snapshotWithSelection:NSMakeRange(0, 0)
                          caretRect:CGRectMake(0, 0, 2, 20)
                     selectionRects:(NSArray<UITextSelectionRect *> *)nil],
        NSException,
        NSInvalidArgumentException);
}

- (void)testSnapshotRejectsNonfiniteVisibleBoundsAndContentOffset {
    XCTAssertThrowsSpecificNamed(
        [[IDSelectionPresentationSnapshot alloc]
            initWithCanonicalSelection:NSMakeRange(0, 0)
            caretRect:CGRectMake(0, 0, 2, 20)
            selectionRects:@[]
            visibleBounds:CGRectNull
            contentOffset:CGPointZero],
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDSelectionPresentationSnapshot alloc]
            initWithCanonicalSelection:NSMakeRange(0, 0)
            caretRect:CGRectMake(0, 0, 2, 20)
            selectionRects:@[]
            visibleBounds:CGRectInfinite
            contentOffset:CGPointZero],
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDSelectionPresentationSnapshot alloc]
            initWithCanonicalSelection:NSMakeRange(0, 0)
            caretRect:CGRectMake(0, 0, 2, 20)
            selectionRects:@[]
            visibleBounds:CGRectMake(0, 0, 240, 120)
            contentOffset:CGPointMake(NAN, 0)],
        NSException,
        NSInvalidArgumentException);
}

- (void)testSnapshotEnforcesCollapsedAndNonemptyCaretRules {
    XCTAssertNoThrow([self snapshotWithSelection:NSMakeRange(0, 0)
                                       caretRect:CGRectMake(0, 0, 2, 20)
                                  selectionRects:@[]]);
    XCTAssertThrowsSpecificNamed(
        [self snapshotWithSelection:NSMakeRange(0, 0)
                          caretRect:CGRectNull
                     selectionRects:@[]],
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [self snapshotWithSelection:NSMakeRange(0, 0)
                          caretRect:CGRectInfinite
                     selectionRects:@[]],
        NSException,
        NSInvalidArgumentException);
    XCTAssertNoThrow([self snapshotWithSelection:NSMakeRange(0, 4)
                                       caretRect:CGRectNull
                                  selectionRects:@[]]);
    XCTAssertThrowsSpecificNamed(
        [self snapshotWithSelection:NSMakeRange(0, 4)
                          caretRect:CGRectMake(0, 0, 2, 20)
                     selectionRects:@[]],
        NSException,
        NSInvalidArgumentException);
}

- (void)testSnapshotRejectsInvalidSelectionRectangleGeometry {
    for (NSValue *value in @[
        [NSValue valueWithCGRect:CGRectNull],
        [NSValue valueWithCGRect:CGRectInfinite],
        [NSValue valueWithCGRect:CGRectMake(NAN, 0, 10, 10)],
    ]) {
        UITextSelectionRect *rect = [self selectionRectWithGeometry:value.CGRectValue];
        XCTAssertThrowsSpecificNamed(
            [self snapshotWithSelection:NSMakeRange(0, 4)
                              caretRect:CGRectNull
                         selectionRects:@[rect]],
            NSException,
            NSInvalidArgumentException);
    }
}

- (void)testSnapshotDefensivelyCopiesSelectionRectangles {
    UITextSelectionRect *rect = [self selectionRectWithGeometry:CGRectMake(1, 2, 30, 20)];
    NSMutableArray<UITextSelectionRect *> *rects = [NSMutableArray arrayWithObject:rect];
    IDSelectionPresentationSnapshot *snapshot =
        [self snapshotWithSelection:NSMakeRange(0, 4)
                          caretRect:CGRectNull
                     selectionRects:rects];

    [rects removeAllObjects];

    XCTAssertEqual(snapshot.selectionRects.count, 1U);
    XCTAssertEqual(snapshot.selectionRects.firstObject, rect);
}

- (void)testPresentationRetainsPriorSnapshotOnGeometryFailureButPublishesExactEmptyResult {
    __block IDRecordingSelectionPresentationBackend *recording = nil;
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:self.blocks
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                recording = [[IDRecordingSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
                return recording;
            }];
    NSRange selection = NSMakeRange(1, 7);
    [self installSelection:selection inView:view];
    [view id_updateSelectionPresentation];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow:0.01]];
    IDSelectionPresentationSnapshot *prior = recording.lastSnapshot;
    XCTAssertNotNil(prior);

    IDDocumentLayoutCoordinator *real =
        view.id_richLayoutController.id_documentLayoutCoordinator;
    IDDocumentSelectionGeometry *exact =
        [real selectionGeometryForCanonicalRange:selection];
    IDPresentationSelectionCoordinator *scripted =
        [[IDPresentationSelectionCoordinator alloc]
            initWithDocument:view.id_document source:view.id_blockStack];
    [view.id_richLayoutController setValue:scripted
                                    forKey:@"id_documentLayoutCoordinator"];

    NSUInteger priorCount = recording.presentationUpdateCount;
    scripted.selectionResult = nil;
    [view id_updateSelectionPresentation];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow:0.01]];
    XCTAssertEqual(recording.presentationUpdateCount, priorCount);
    XCTAssertEqual(recording.lastSnapshot, prior);

    [exact setValue:@[] forKey:@"segments"];
    scripted.selectionResult = exact;
    [view id_updateSelectionPresentation];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow:0.01]];
    XCTAssertEqual(recording.presentationUpdateCount, priorCount + 1);
    XCTAssertEqual(recording.lastSnapshot.selectionRects.count, 0U);
}

@end
