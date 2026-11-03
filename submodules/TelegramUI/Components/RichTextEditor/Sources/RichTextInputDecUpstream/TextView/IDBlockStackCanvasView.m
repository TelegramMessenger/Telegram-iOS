#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockStackCanvasView.h"
#import "IDBlockStackCanvasViewInternal.h"

#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextKit2BlockLayoutProvider.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

#include <math.h>

@interface IDBlockLayout (IDBlockStackCanvasHost)
- (void)id_setCanvasHost:(nullable id)host;
- (CGPoint)id_canvasBoundsOrigin;
- (BOOL)updateContentFromBlock:(IDBlock *)block;
- (BOOL)updateLayoutFromBlock:(IDBlock *)block width:(CGFloat)width;
- (void)id_advanceRevisionsForContentChange:(BOOL)contentChanged
                               layoutChange:(BOOL)layoutChanged;
@end

/// A placed run's own horizontal scroller. Horizontal only — its content height equals its bounds
/// height, so a vertical pan passes through to whatever scrolls the document. Its content view is
/// what a host parents chrome into; the run's block canvases sit above that chrome.
/// One frame of slack either side of the transient in which UIKit clears `isDecelerating` to take a
/// touch. 0.05s is three frames at 60Hz: long enough to cover a dropped frame, short enough that a
/// run which has genuinely settled is not still "in flight" when the next touch lands.
static const CFTimeInterval id_animationGraceInterval = 0.05;

@interface IDPlacedRunScrollView : UIScrollView
@property(nonatomic, strong, readonly) UIView *runContentView;
@property(nonatomic, copy) NSArray<NSUUID *> *memberIdentifiers;
/// The touch that CAUGHT this run mid-flight, while it is still down. A scroll view caught under a
/// finger is TRACKING until that finger lifts, and this run cannot be: it never receives the touch,
/// so UIKit never puts it in that state. Weak, and reassigned for every touch the pan is offered, so
/// a recycled `UITouch` cannot be mistaken for a catch that is still held.
@property(nonatomic, weak, nullable) UITouch *caughtTouch;
/// Dragging, coasting, or held by the finger that caught it.
@property(nonatomic, readonly) BOOL id_isInFlight;
/// Still under the finger that caught this run mid-flight.
@property(nonatomic, readonly) BOOL id_isHeldByCatchingTouch;
/// A touch ended: settle back into range, but ONLY if it is the touch that caught this run.
- (void)id_settleIfCaughtByEndedTouches:(nullable NSSet<UITouch *> *)touches;
/// When this run last MOVED under its own animation, in `CACurrentMediaTime()`.
///
/// `isDecelerating` cannot answer "is this run in flight" at the moment a touch arrives: UIKit
/// clears it as the pan receives the touch and sets it again on the next frame (measured below), so
/// a gate that reads it there is false exactly when it matters. Motion is the durable fact.
@property(nonatomic) CFTimeInterval id_lastAnimatedMotionTime;
/// Where a catch pinned this run, held while the catching finger is down.
@property(nonatomic) CGFloat id_heldOffsetX;
/// Moving under its own animation right now — `isDecelerating`, or motion within the grace window.
@property(nonatomic, readonly) BOOL id_isAnimatingNow;
@end

/// Watches for the END of a touch, and nothing else.
///
/// A run catches itself through its pan's per-touch delegate callback, which is delivered only when
/// a touch BEGINS — so a run caught mid-rubber-band, held where the finger stopped it, has no way to
/// learn that the finger has gone and to spring back. This recogniser is that signal: it recognises
/// nothing, stays out of every arbitration, and exists to report the end of a touch to the runs.
@interface IDRunCatchReleaseObserver : UIGestureRecognizer
@property(nonatomic, copy, nullable) void (^onTouchesEnded)(NSSet<UITouch *> *touches);
@end

@implementation IDRunCatchReleaseObserver
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (self.onTouchesEnded != nil) {
        self.onTouchesEnded(touches);
    }
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    if (self.onTouchesEnded != nil) {
        self.onTouchesEnded(touches);
    }
}
@end

@implementation IDPlacedRunScrollView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _runContentView = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_runContentView];
        self.clipsToBounds = YES;
        self.delaysContentTouches = NO;
        // Invisible infrastructure: a host draws whatever it wants around a run (a table's grips
        // and outline), so the scroller shows no indicator of its own.
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.alwaysBounceVertical = NO;
        self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    return self;
}

/// Touches fall THROUGH the run, as every block canvas already lets them, so the text interaction
/// sees a cell exactly as it sees a stacked block: the touch's view is the stack canvas. Measured
/// on device before this: a tap inside a run went to the scroll view and never placed the caret.
/// Scrolling survives because the stack canvas hosts this run's pan recognizer on its behalf.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    return (hitView == self || hitView == self.runContentView) ? nil : hitView;
}

/// A FINGER DOWN ON A DECELERATING RUN STOPS IT, which UIScrollView does for itself and cannot do
/// here: every touch in this tree lands on the stack canvas — the block canvases and this view let
/// them fall through so the text interaction sees a cell — so the run is not in the touch's
/// responder chain and `-[UIScrollView touchesBegan:withEvent:]` is never called on it. Measured
/// from a point over a cell: canvas → text view → host, with the run nowhere in it.
///
/// This callback is UIKit's own, delivered as the PAN receives each touch — the same moment a scroll
/// view would normally catch itself — so it does not depend on where the pan is hosted, on the
/// delivery delay the enclosing scroll view imposes on content touches, or on a recogniser of our
/// own competing for the touch. The answer is always YES: this decides nothing about the gesture.
///
/// Settling at the CLAMPED offset matters for a touch during the rubber band: left where it is, the
/// run would rest outside its own range with nothing to bring it back, since the bounce it
/// interrupted is what would have.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == self.panGestureRecognizer) {
        BOOL catching = self.id_isAnimatingNow &&
            CGRectContainsPoint(self.bounds, [touch locationInView:self]);
        // Assigned either way: every touch the pan is offered decides afresh whether this run is
        // being held, so a touch that catches nothing clears a stale one.
        self.caughtTouch = catching ? touch : nil;
        if (catching) {
            // WHERE IT IS, not where it was heading: `-setContentOffset:` below pins it here for as
            // long as the finger is down, and the release springs it back into range.
            self.id_heldOffsetX = self.contentOffset.x;
            [self setContentOffset:self.contentOffset animated:NO];
        }
    }
    return YES;
}

/// Is this run moving under its own animation RIGHT NOW — asked at the one moment `isDecelerating`
/// cannot answer it.
///
/// Traced on device (K3, iOS 27.0, a table 25pt into its rubber band): the frame before the touch
/// reads `decel=1`, the `shouldReceiveTouch:` callback reads `decel=0 drag=0 track=1`, and the frame
/// 16ms LATER reads `decel=1` again, after which the run springs home under the finger. So UIKit
/// clears the flag as its pan takes the touch and restores it when nothing stops the animation —
/// and the gate that read `isDecelerating` there declined every catch that has ever been attempted.
/// One frame of slack either side of that transient is what `id_animationGraceInterval` is.
- (BOOL)id_isAnimatingNow {
    if (self.isDecelerating) {
        return YES;
    }
    return (CACurrentMediaTime() - self.id_lastAnimatedMotionTime) < id_animationGraceInterval;
}

/// A caught run does not move until the finger lets go.
///
/// The single assignment in the catch cannot do this: at that instant the scroll view does not
/// consider itself to be decelerating, so there is no animation for it to cancel, and UIKit resumes
/// the bounce on the next frame regardless. Pinning every frame is what "held where the finger
/// stopped it" means, and it ends by itself — a catch the user then DRAGS sets `isDragging`, which
/// releases the pin and hands the run back to its own pan.
- (void)setContentOffset:(CGPoint)contentOffset {
    if (self.id_isHeldByCatchingTouch && !self.isDragging) {
        contentOffset.x = self.id_heldOffsetX;
    } else if (self.isDecelerating || self.isDragging) {
        // Only motion the run drives itself counts. A host assigning an offset during a layout pass
        // is not this run in flight, and counting it would let a touch right after one read as a
        // catch.
        if (fabs(contentOffset.x - self.contentOffset.x) > 0.01) {
            self.id_lastAnimatedMotionTime = CACurrentMediaTime();
        }
    }
    [super setContentOffset:contentOffset];
}

/// In flight: being dragged, coasting from a drag, or STILL HELD by the finger that caught it.
///
/// The last of those is what a caught scroll view would report as `isTracking`, and this one cannot:
/// it never receives the touch. Without it a catch is in flight for one instant and then not, and an
/// outer gesture watching for its moment takes the very next movement — which is the sheet-dismiss
/// defect this exists for.
- (BOOL)id_isInFlight {
    return self.isDragging || self.isDecelerating || self.isTracking ||
           self.id_isHeldByCatchingTouch || self.id_isAnimatingNow;
}

- (BOOL)id_isHeldByCatchingTouch {
    UITouch *held = self.caughtTouch;
    if (held == nil) {
        return NO;
    }
    UITouchPhase phase = held.phase;
    return phase == UITouchPhaseBegan || phase == UITouchPhaseMoved ||
           phase == UITouchPhaseStationary;
}

/// The finger that caught this run has lifted: if the catch left it outside its own range — caught
/// mid-rubber-band — bring it back, which is what the bounce it interrupted would have done.
///
/// **Only for the touch that CAUGHT it.** Applied to every touch that ends, this ate the ordinary
/// rubber band: the finger that pulled a run past its edge lifts, UIKit has not started its own
/// bounce yet, and the run would be clamped home in one frame — leaving no bounce to catch at all,
/// which is what "the bounce is still not catching" turned out to be (K3, 2026-09-11).
///
/// Nothing to do if the run is moving under its own gesture again: a catch the user then DRAGS ends
/// as any drag does, with UIKit's own bounce.
- (void)id_settleIfCaughtByEndedTouches:(NSSet<UITouch *> *)touches {
    UITouch *held = self.caughtTouch;
    if (held == nil || (touches != nil && ![touches containsObject:held])) {
        return;
    }
    self.caughtTouch = nil;
    if (self.isTracking || self.isDragging || self.isDecelerating) {
        return;
    }
    CGFloat settled = [IDBlockStackCanvasView
        id_caughtRunOffsetForCurrent:self.contentOffset.x
                             maximum:self.contentSize.width - CGRectGetWidth(self.bounds)];
    if (fabs(settled - self.contentOffset.x) > 0.5) {
        [self setContentOffset:CGPointMake(settled, self.contentOffset.y) animated:YES];
    }
}

/// The pan lives on the stack canvas, so it must decline every touch that is not a horizontal drag
/// inside this run — a vertical drag belongs to whatever scrolls the document, a drag elsewhere to
/// another run or to nothing.
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGestureRecognizer) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        if (!CGRectContainsPoint(self.bounds, [pan locationInView:self])) {
            return NO;
        }
        // A run CAUGHT under this finger keeps the gesture, whichever way it then goes — which is
        // what catching a scroll view means everywhere else in iOS: the finger that stops a coast
        // owns the drag that follows it. Without this the direction test sends that drag to whatever
        // encloses the editor, so a catch reads as "the table cannot be grabbed".
        CGPoint velocity = [pan velocityInView:self];
        if (!self.id_isHeldByCatchingTouch && fabs(velocity.x) <= fabs(velocity.y)) {
            return NO;
        }
    }
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}
@end

@interface IDBlockStackCanvasView () <UIScrollViewDelegate>
@property(nonatomic) BOOL displayDecorationNeedsUpdate;

@property(nonatomic, strong) IDBlockDocument *document;
@property(nonatomic, copy, readwrite) NSArray<IDBlockLayout *> *blockLayouts;
@property(nonatomic, readwrite) CGSize documentContentSize;
@property(nonatomic, strong) NSDictionary<NSUUID *, IDBlockLayout *> *layoutsByIdentifier;
@property(nonatomic, strong)
    NSDictionary<NSUUID *, IDTextKit2BlockLayoutProvider *> *providersByIdentifier;
@property(nonatomic, strong) NSDictionary<NSUUID *, NSValue *> *originsByIdentifier;
@property(nonatomic, copy) NSDictionary<NSUUID *, NSValue *> *hitRectsByIdentifier;
@property(nonatomic, copy) NSDictionary<NSUUID *, NSValue *> *selectionSlotsByIdentifier;
@property(nonatomic, strong) NSMutableDictionary<NSUUID *, IDPlacedRunScrollView *> *runScrollViewsByFirstIdentifier;
@property(nonatomic, weak, nullable) id canvasHost;
@property(nonatomic, weak, nullable) NSTextContainer *textContainer;
@property(nonatomic) NSUInteger geometryGeneration;
@property(nonatomic) CGFloat lastLayoutWidth;
@property(nonatomic) BOOL hasLayoutWidth;

@end

/// Whether a hit rect's vertical extent holds the probe line `y`.
static BOOL IDCanvasRectSpansY(CGRect rect, CGFloat y) {
    return y >= CGRectGetMinY(rect) && y < CGRectGetMaxY(rect);
}

// `IDBlockTextView+PrivateCallbacks.m`: adds `textContainerOrigin`, which UIKit sends under a private name.
FOUNDATION_EXTERN void IDBlockStackCanvasViewInstallPrivateCallbacks(Class cls);

@implementation IDBlockStackCanvasView

+ (void)initialize {
    IDBlockStackCanvasViewInstallPrivateCallbacks(self);
}

- (IDBlockDocument *)id_document {
    return self.document;
}

- (instancetype)initWithDocument:(IDBlockDocument *)document {
    if (document == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDBlockStackCanvasView requires a document."];
    }

    self = [super initWithFrame:CGRectZero];
    if (self == nil) {
        return nil;
    }
    _document = document;
    _lineFragmentPadding = 5.0;  // NSTextContainer's own default
    _blockLayouts = @[];
    _layoutsByIdentifier = @{};
    _providersByIdentifier = @{};
    _originsByIdentifier = @{};
    _hitRectsByIdentifier = @{};
    _selectionSlotsByIdentifier = @{};
    _runScrollViewsByFirstIdentifier = [NSMutableDictionary dictionary];
    _geometryGeneration = 0;
    _hasLayoutWidth = NO;
    self.opaque = NO;
    __weak __typeof(self) weakSelf = self;
    IDRunCatchReleaseObserver *release = [[IDRunCatchReleaseObserver alloc] initWithTarget:nil action:NULL];
    // Part of nothing: it never recognises, so it cancels no touch and blocks no gesture, and it
    // must not hold the view's own touch callbacks back while it sits in Possible.
    release.cancelsTouchesInView = NO;
    release.delaysTouchesBegan = NO;
    release.delaysTouchesEnded = NO;
    release.onTouchesEnded = ^(NSSet<UITouch *> *touches) {
        for (IDPlacedRunScrollView *run in weakSelf.runScrollViewsByFirstIdentifier.allValues) {
            [run id_settleIfCaughtByEndedTouches:touches];
        }
    };
    [self addGestureRecognizer:release];
    [self updateForDocumentChange:nil width:0];
    return self;
}

- (void)setDisplayDecorator:(IDBlockTextDisplayDecorator)displayDecorator {
    _displayDecorator = [displayDecorator copy];
    self.displayDecorationNeedsUpdate = YES;
}

- (void)id_setDisplayDecorationNeedsUpdate {
    self.displayDecorationNeedsUpdate = YES;
}

- (void)setEmptyLineAttributesByBlock:
    (NSDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *)attributes {
    if (_emptyLineAttributesByBlock == attributes ||
        [_emptyLineAttributesByBlock isEqualToDictionary:attributes ?: @{}]) {
        return;
    }
    _emptyLineAttributesByBlock = [attributes copy];
    // No invalidation here: these are read by the per-block pass in `-updateForDocumentChange:`,
    // which `setNeedsLayout` does not run. The text view reconciles after setting this, the way it
    // does for `lineFragmentPadding` — the same reason, and the same remedy.
}

- (void)setLineFragmentPadding:(CGFloat)lineFragmentPadding {
    if (_lineFragmentPadding == lineFragmentPadding) {
        return;
    }
    _lineFragmentPadding = lineFragmentPadding;
    // Applied on CHANGE and at layout CREATION, never on every reconcile: a caller may set a single
    // layout's container padding directly (the layout tests drive a negative value through one block
    // to produce a negative usage origin), and re-asserting this on every pass would silently undo it.
    for (IDBlockLayout *layout in self.blockLayouts) {
        layout.textContainer.lineFragmentPadding = lineFragmentPadding;
    }
}

- (NSDictionary<NSAttributedStringKey, id> *)id_emptyLineAttributesForIdentifier:(NSUUID *)identifier {
    NSDictionary<NSAttributedStringKey, id> *provided =
        self.emptyLineAttributesProvider != nil ? self.emptyLineAttributesProvider(identifier) : nil;
    return provided != nil ? provided : self.emptyLineAttributesByBlock[identifier];
}

- (CGFloat)id_emptyLineCaretOffsetForIdentifier:(NSUUID *)identifier {
    NSNumber *provided =
        self.emptyLineCaretOffsetProvider != nil ? self.emptyLineCaretOffsetProvider(identifier) : nil;
    return provided != nil ? provided.doubleValue : self.emptyLineCaretOffsetsByBlock[identifier].doubleValue;
}

- (void)updateForDocumentChange:(IDBlockDocumentChange *)change width:(CGFloat)width {
    CGFloat layoutWidth = isfinite(width) ? MAX(width, 0) : 0;
    CGFloat canvasWidth = ceil(layoutWidth);
    BOOL decorationWasDirty = self.displayDecorationNeedsUpdate;
    NSArray<NSUUID *> *oldOrderedIdentifiers = self.orderedBlockIdentifiers;
    NSDictionary<NSUUID *, NSValue *> *oldOrigins = self.originsByIdentifier;
    CGSize oldContentSize = self.documentContentSize;
    NSMutableDictionary<NSUUID *, NSArray<NSNumber *> *> *oldRevisions =
        [NSMutableDictionary dictionary];
    for (IDBlockLayout *layout in self.blockLayouts) {
        oldRevisions[layout.blockIdentifier] = @[
            @(layout.contentRevision), @(layout.layoutGeneration),
        ];
    }
    NSDictionary<NSUUID *, IDBlockLayout *> *oldLayouts = self.layoutsByIdentifier;
    NSDictionary<NSUUID *, IDTextKit2BlockLayoutProvider *> *oldProviders =
        self.providersByIdentifier;
    NSMutableDictionary<NSUUID *, IDBlockLayout *> *newLayouts = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSUUID *, IDTextKit2BlockLayoutProvider *> *newProviders =
        [NSMutableDictionary dictionary];
    NSMutableArray<IDBlockLayout *> *orderedLayouts = [NSMutableArray array];
    NSSet<NSUUID *> *affectedIdentifiers = change == nil
        ? [NSSet set]
        : [NSSet setWithArray:change.affectedBlockIdentifiers];

    for (IDBlock *block in self.document.blocks) {
        UIEdgeInsets blockInset = UIEdgeInsetsZero;
        NSValue *blockInsetValue = self.blockInsets[block.identifier];
        if (blockInsetValue != nil) {
            blockInset = blockInsetValue.UIEdgeInsetsValue;
        }
        // A block's horizontal insets narrow its text MEASURE, stacked or placed. The placed branch
        // always did; a stacked block laid out at the full column and then had its canvas moved and
        // sized by the same insets, so text wrapped at the column and was drawn starting one `left`
        // in — running `left` past the column's trailing edge. Reserving space horizontally and not
        // taking it out of the measure is half an inset.
        CGFloat blockLayoutWidth = MAX(layoutWidth - blockInset.left - blockInset.right, 0);
        NSValue *placedFrame = self.blockFrames[block.identifier];
        if (placedFrame != nil) {
            blockLayoutWidth = MAX(placedFrame.CGRectValue.size.width - blockInset.left - blockInset.right, 0);
        }
        IDBlockLayout *layout = oldLayouts[block.identifier];
        if (layout == nil) {
            layout = [[IDBlockLayout alloc] initWithBlock:block width:blockLayoutWidth];
            layout.displayDecorator = self.displayDecorator;
            [layout updateContentFromBlock:block];
            // AFTER the initializer, which has already laid out at the container's default padding,
            // so the layout has to be redone at the host's value.
            layout.textContainer.lineFragmentPadding = self.lineFragmentPadding;
            layout.id_hostEmptyLineAttributes = [self id_emptyLineAttributesForIdentifier:block.identifier];
            layout.id_hostEmptyLineCaretOffset = [self id_emptyLineCaretOffsetForIdentifier:block.identifier];
            [layout updateLayoutFromBlock:block width:blockLayoutWidth];
        } else {
            layout.displayDecorator = self.displayDecorator;
            layout.id_hostEmptyLineAttributes = [self id_emptyLineAttributesForIdentifier:block.identifier];
            layout.id_hostEmptyLineCaretOffset = [self id_emptyLineCaretOffsetForIdentifier:block.identifier];
            BOOL textActuallyChanged =
                ![layout.contentStorage.textStorage
                    isEqualToAttributedString:block.attributedText];
            BOOL contentChanged = NO;
            // `|| displayDecorationNeedsUpdate` is the decoration-only path: a spoiler reveals
            // because the SELECTION moved, which produces no document change at all, so without it
            // the rendered text would never be recomputed. `updateContentFromBlock:` compares the
            // decorated text itself and no-ops when nothing actually changed.
            if ((change != nil &&
                 ([affectedIdentifiers containsObject:block.identifier] ||
                  textActuallyChanged)) ||
                self.displayDecorationNeedsUpdate) {
                contentChanged = [layout updateContentFromBlock:block];
            }
            BOOL layoutChanged =
                [layout updateLayoutFromBlock:block width:blockLayoutWidth];
            [layout id_advanceRevisionsForContentChange:contentChanged
                                           layoutChange:layoutChanged];
        }
        IDTextKit2BlockLayoutProvider *provider = oldProviders[block.identifier];
        if (provider == nil || oldLayouts[block.identifier] != layout) {
            provider = [[IDTextKit2BlockLayoutProvider alloc]
                initWithBlockLayout:layout];
        }
        newProviders[block.identifier] = provider;
        [layout id_setCanvasHost:self.canvasHost];
        if (layout.canvasView.superview != self) {
            [self addSubview:layout.canvasView];
        }
        newLayouts[block.identifier] = layout;
        [orderedLayouts addObject:layout];
    }

    for (NSUUID *identifier in oldLayouts) {
        if (newLayouts[identifier] != nil) {
            continue;
        }
        IDBlockLayout *deleted = oldLayouts[identifier];
        [deleted.canvasView removeFromSuperview];
        [deleted id_setCanvasHost:nil];
    }

    NSMutableDictionary<NSUUID *, NSValue *> *origins = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSUUID *, NSValue *> *hitRects = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSUUID *, NSValue *> *slots = [NSMutableDictionary dictionary];
    NSMutableSet<NSUUID *> *liveRunStarts = [NSMutableSet set];
    __block CGFloat y = self.contentInsets.top;
    __block CGFloat documentWidth = canvasWidth;
    __block NSUInteger subviewIndex = 0;
    // `self.subviews.count`, kept by hand through the pass below. `-subviews` builds a fresh array on
    // every call once an insert has invalidated UIKit's cache, and the pass inserted and then asked
    // for it once per block: O(n²) in the block count, ~30% of a 200-paragraph paste (composer
    // harness, 2026-09-23, `HarnessLargeRichPasteScalingTests`). Read once here, then adjusted at
    // each of the pass's three hierarchy changes.
    //
    // `hierarchy` is `subviews` as it stands before the pass reorders anything, and holds while
    // `hierarchyUnchanged` does. A view already at its index is then not re-inserted:
    // `insertSubview:atIndex:` looks the view up in `subviews` (O(n)) even when nothing moves, so
    // re-inserting every canvas made each pass O(n²) (composer harness, 2026-09-25: Select All ▸
    // Bold over media blocks runs ~20 passes; `HarnessAtomFormatScalingTests`). After the first real
    // change the pass inserts as before.
    NSArray<UIView *> *hierarchy = self.subviews;
    __block BOOL hierarchyUnchanged = YES;
    __block NSUInteger subviewCount = hierarchy.count;
    const CGFloat blockOriginX = self.contentInsets.left;
    // A run of consecutive placed blocks shares an anchor: the cursor where the run began. The
    // cursor does not move inside the run; it advances past the run's extent once, after it. The
    // run's canvases live inside its own horizontal scroll view; the origin map and hit rects
    // carry VISUAL positions, so every geometry consumer sees the scroll without knowing of it.
    __block BOOL inPlacedRun = NO;
    __block CGPoint runAnchor = CGPointZero;
    __block CGFloat runExtent = 0;
    __block CGFloat runWidth = 0;
    __block IDPlacedRunScrollView *runScroll = nil;
    __block NSMutableArray<NSUUID *> *runMembers = nil;
    void (^closeRun)(void) = ^{
        if (!inPlacedRun) {
            return;
        }
        inPlacedRun = NO;
        // The run's LEADING RHYTHM belongs to its first row. A host reserves the gap above a table
        // by starting the run's placed frames below its anchor, so that space is inside the run and
        // inside no block's slot — the one place a document of slots would still have a hole. Giving
        // it to the blocks that sit at the top of the run is the same rule every stacked block
        // follows in reaching its neighbour.
        CGFloat runSlotTop = CGFLOAT_MAX;
        for (NSUUID *member in runMembers) {
            NSValue *slot = slots[member];
            if (slot != nil) {
                runSlotTop = MIN(runSlotTop, CGRectGetMinY(slot.CGRectValue));
            }
        }
        if (runSlotTop > runAnchor.y) {
            for (NSUUID *member in runMembers) {
                NSValue *slot = slots[member];
                if (slot == nil) continue;
                CGRect box = slot.CGRectValue;
                // The first row only: a lower row's gap to the row above it is the grid's border,
                // which is the table's to draw and not a hole in the rhythm.
                if (CGRectGetMinY(box) > runSlotTop + 0.5) continue;
                box.size.height += CGRectGetMinY(box) - runAnchor.y;
                box.origin.y = runAnchor.y;
                slots[member] = [NSValue valueWithCGRect:box];
            }
        }
        CGFloat contentWidth = MAX(runWidth, canvasWidth);
        // Where this run's clip ends. The scroll view grows by the outsets and its content view
        // shifts right by the leading one, so the run's content stays exactly where it was laid out
        // and only the window onto it changes. The scrollable RANGE is unchanged too: the content
        // size grows by both outsets, which is what the frame grew by.
        UIEdgeInsets clipOutset = UIEdgeInsetsZero;
        NSValue *clipValue = runMembers.firstObject == nil
            ? nil : self.placedRunClipOutsets[runMembers.firstObject];
        if (clipValue != nil) {
            clipOutset = clipValue.UIEdgeInsetsValue;
        }
        // WHERE THE RUN MAY REST is its COLUMN, and that is a different question from where it is
        // clipped: the clip is what is visible, the column is what the run belongs to. They are the
        // same rect for a run the host draws nothing around, and they are not for one inside a
        // container — a host may show content through a margin it does not let the run rest in.
        //
        // Defaults to the text column, which is what every run had before this existed.
        UIEdgeInsets columnOutset = UIEdgeInsetsZero;
        NSValue *columnValue = runMembers.firstObject == nil
            ? nil : self.placedRunColumnOutsets[runMembers.firstObject];
        if (columnValue != nil) {
            columnOutset = columnValue.UIEdgeInsetsValue;
        }
        // The travel: enough for the run's right edge to reach its COLUMN's right edge, and no more.
        // A narrower column adds travel (the part beyond it must still be reachable); a wider one
        // takes it away. The CLIP does not enter into it — a window wider than the column is what a
        // scrolling run passes under, never somewhere it comes to rest.
        CGFloat travel = MAX(contentWidth - canvasWidth - columnOutset.right, 0);
        CGRect runFrame = CGRectMake(runAnchor.x - clipOutset.left, runAnchor.y,
                                     canvasWidth + clipOutset.left + clipOutset.right, runExtent);
        CGSize contentSize = CGSizeMake(CGRectGetWidth(runFrame) + travel, runExtent);
        // The pass owns the offset only when it CHANGES the run's geometry. UIScrollView holds an
        // out-of-range offset on purpose while it rubber-bands, and every scroll tick re-runs this
        // pass (`scrollViewDidScroll:` marks the text view for layout) — so a clamp on every run
        // cancelled the band one frame at a time, and a run wider than the canvas never
        // overscrolled. A run that narrows under an offset still clamps: that offset is out of range
        // for good, not mid-band.
        BOOL geometryChanged = !CGRectEqualToRect(runScroll.frame, runFrame)
            || !CGSizeEqualToSize(runScroll.contentSize, contentSize);
        // Assigned only on a change: a scroll view re-adjusts its offset into range on a frame or
        // content-size assignment, the same value or not, which is the clamp by another route.
        if (geometryChanged) {
            runScroll.frame = runFrame;
            runScroll.contentSize = contentSize;
        }
        CGRect contentFrame = CGRectMake(clipOutset.left, 0, contentWidth, runExtent);
        if (!CGRectEqualToRect(runScroll.runContentView.frame, contentFrame)) {
            runScroll.runContentView.frame = contentFrame;
        }
        // Against the COLUMN, not the clip: a run that fits its column does not scroll because its
        // clip happens to be narrower, and one that does not fit scrolls the same distance whatever
        // the clip is.
        runScroll.scrollEnabled = runWidth > canvasWidth + 0.5;
        runScroll.memberIdentifiers = runMembers;
        if (geometryChanged) {
            CGFloat maxOffset = travel;
            CGFloat clamped = MIN(MAX(runScroll.contentOffset.x, 0), maxOffset);
            if (clamped != runScroll.contentOffset.x) {
                runScroll.contentOffset = CGPointMake(clamped, 0);
            }
        }
        y = runAnchor.y + runExtent;
        runScroll = nil;
        runMembers = nil;
    };
    [orderedLayouts enumerateObjectsUsingBlock:^(IDBlockLayout *layout,
                                                 NSUInteger index,
                                                 BOOL *stop) {
        UIEdgeInsets blockInset = UIEdgeInsetsZero;
        NSValue *blockInsetValue = self.blockInsets[layout.blockIdentifier];
        if (blockInsetValue != nil) {
            blockInset = blockInsetValue.UIEdgeInsetsValue;
        }
        NSValue *frameValue = self.blockFrames[layout.blockIdentifier];
        if (frameValue != nil) {
            CGRect frame = frameValue.CGRectValue;
            // A host-declared boundary ends the run in progress, so the next group anchors itself,
            // scrolls by itself and is clipped by its own entry. Without one, adjacency alone
            // decides — and adjacency cannot see where one table stops and the next begins.
            if (inPlacedRun && [self.placedRunStarts containsObject:layout.blockIdentifier]) {
                closeRun();
            }
            if (!inPlacedRun) {
                inPlacedRun = YES;
                runAnchor = CGPointMake(blockOriginX, y);
                runExtent = 0;
                runWidth = 0;
                runMembers = [NSMutableArray array];
                runScroll = self.runScrollViewsByFirstIdentifier[layout.blockIdentifier];
                if (runScroll == nil) {
                    runScroll = [[IDPlacedRunScrollView alloc] initWithFrame:CGRectZero];
                    runScroll.delegate = self;
                    self.runScrollViewsByFirstIdentifier[layout.blockIdentifier] = runScroll;
                    [self addGestureRecognizer:runScroll.panGestureRecognizer];
                }
                BOOL runScrollWasChild = runScroll.superview == self;
                if (!(hierarchyUnchanged && subviewIndex < hierarchy.count
                      && hierarchy[subviewIndex] == runScroll)) {
                    [self insertSubview:runScroll atIndex:MIN(subviewIndex, subviewCount)];
                    hierarchyUnchanged = NO;
                }
                if (!runScrollWasChild) {
                    subviewCount += 1;
                }
                subviewIndex += 1;
                [liveRunStarts addObject:layout.blockIdentifier];
            }
            CGFloat dx = runScroll.contentOffset.x;
            CGFloat textWidth = MAX(frame.size.width - blockInset.left - blockInset.right, 0);
            CGFloat height = MAX(layout.usedSize.height, frame.size.height - blockInset.top);
            // Inside the run's content view: no anchor, no offset — the scroll view carries both.
            layout.canvasView.frame = CGRectMake(frame.origin.x + blockInset.left,
                                                 frame.origin.y + blockInset.top,
                                                 MAX(textWidth, layout.usedSize.width), height);
            layout.canvasView.bounds = (CGRect){[layout id_canvasBoundsOrigin],
                                                layout.canvasView.frame.size};
            if (layout.canvasView.superview != runScroll.runContentView) {
                if (layout.canvasView.superview == self) {
                    subviewCount -= 1;
                    hierarchyUnchanged = NO;
                }
                [runScroll.runContentView addSubview:layout.canvasView];
            }
            [runMembers addObject:layout.blockIdentifier];
            CGPoint origin = CGPointMake(runAnchor.x + frame.origin.x + blockInset.left - dx,
                                         runAnchor.y + frame.origin.y + blockInset.top);
            origins[layout.blockIdentifier] = [NSValue valueWithCGPoint:origin];
            CGFloat cellHeight = MAX(frame.size.height, height + blockInset.top);
            CGRect hitRect = CGRectMake(runAnchor.x + frame.origin.x - dx, runAnchor.y + frame.origin.y,
                                        frame.size.width, cellHeight);
            hitRects[layout.blockIdentifier] = [NSValue valueWithCGRect:hitRect];
            // The cell IS the slot: the host's frame already holds the padding (`blockInsets`
            // apply inside it) and `hitRect` already carries the run's horizontal offset, so a
            // cell's wash scrolls with its table for free.
            slots[layout.blockIdentifier] = [NSValue valueWithCGRect:hitRect];
            runExtent = MAX(runExtent, frame.origin.y + cellHeight + blockInset.bottom);
            runWidth = MAX(runWidth, CGRectGetMaxX(frame));
            return;
        }
        closeRun();
        if (layout.canvasView.superview != self) {
            [self addSubview:layout.canvasView];
            subviewCount += 1;
            hierarchyUnchanged = NO;
        }
        // Where this block's reserved space BEGINS — before its top inset, not after it. The
        // pass advances `y` by top inset, canvas, bottom inset, so capturing here and again
        // below makes consecutive slots meet exactly, with nothing between them for a
        // selection to miss.
        CGFloat slotTop = y;
        y += blockInset.top;
        CGPoint origin = CGPointMake(blockOriginX + blockInset.left, y);
        origins[layout.blockIdentifier] = [NSValue valueWithCGPoint:origin];
        CGFloat blockCanvasWidth = MAX(canvasWidth - blockInset.left - blockInset.right,
                                       layout.usedSize.width);
        layout.canvasView.frame = CGRectMake(blockOriginX + blockInset.left,
                                             y,
                                             blockCanvasWidth,
                                             layout.usedSize.height);
        layout.canvasView.bounds = (CGRect){[layout id_canvasBoundsOrigin],
                                            layout.canvasView.frame.size};
        if (!(hierarchyUnchanged && subviewIndex < hierarchy.count
              && hierarchy[subviewIndex] == layout.canvasView)) {
            [self insertSubview:layout.canvasView atIndex:MIN(subviewIndex, subviewCount)];
            hierarchyUnchanged = NO;
        }
        subviewIndex += 1;
        documentWidth = MAX(documentWidth, blockCanvasWidth + blockInset.left + blockInset.right);
        y += layout.usedSize.height + blockInset.bottom;
        slots[layout.blockIdentifier] = [NSValue valueWithCGRect:
            CGRectMake(blockOriginX, slotTop, canvasWidth, y - slotTop)];
    }];
    closeRun();
    for (NSUUID *key in self.runScrollViewsByFirstIdentifier.allKeys) {
        if (![liveRunStarts containsObject:key]) {
            [self removeGestureRecognizer:self.runScrollViewsByFirstIdentifier[key].panGestureRecognizer];
            [self.runScrollViewsByFirstIdentifier[key] removeFromSuperview];
            [self.runScrollViewsByFirstIdentifier removeObjectForKey:key];
        }
    }
    self.hitRectsByIdentifier = hitRects.copy;
    self.selectionSlotsByIdentifier = slots.copy;

    if (decorationWasDirty) {
        self.displayDecorationNeedsUpdate = NO;
    }
    self.layoutsByIdentifier = newLayouts.copy;
    self.providersByIdentifier = newProviders.copy;
    self.originsByIdentifier = origins.copy;
    self.blockLayouts = orderedLayouts.copy;
    // CONTENT only, excluding this view's own `contentInsets`: `y` began at the top inset, and the
    // host adds the vertical inset itself when sizing its scroll content.
    self.documentContentSize =
        CGSizeMake(ceil(documentWidth), ceil(MAX(y - self.contentInsets.top, 0.0)));

    BOOL geometryChanged = !self.hasLayoutWidth ||
        self.lastLayoutWidth != layoutWidth ||
        ![oldOrderedIdentifiers isEqual:self.orderedBlockIdentifiers] ||
        ![oldOrigins isEqual:self.originsByIdentifier] ||
        !CGSizeEqualToSize(oldContentSize, self.documentContentSize);
    if (!geometryChanged) {
        for (IDBlockLayout *layout in self.blockLayouts) {
            NSArray<NSNumber *> *revisions = oldRevisions[layout.blockIdentifier];
            if (revisions == nil ||
                revisions[0].unsignedIntegerValue != layout.contentRevision ||
                revisions[1].unsignedIntegerValue != layout.layoutGeneration) {
                geometryChanged = YES;
                break;
            }
        }
    }
    self.lastLayoutWidth = layoutWidth;
    self.hasLayoutWidth = YES;
    if (geometryChanged) {
        self.geometryGeneration += 1;
        if (self.geometryGeneration == 0) {
            self.geometryGeneration = 1;
        }
    }
}

- (IDBlockLayout *)layoutForBlockIdentifier:(NSUUID *)identifier {
    return self.layoutsByIdentifier[identifier];
}

- (NSArray<NSUUID *> *)orderedBlockIdentifiers {
    return [self.blockLayouts valueForKey:@"blockIdentifier"];
}

- (IDDocumentGeometryEligibilitySnapshot *)
    selectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision {
    (void)documentRevision;
    return [[IDDocumentGeometryEligibilitySnapshot alloc]
        initWithGeometryGeneration:self.geometryGeneration
              orderedBlockIdentifiers:self.orderedBlockIdentifiers];
}

- (id<IDBlockLayoutSnapshot>)snapshotForBlockIdentifier:(NSUUID *)identifier
                                        documentRevision:(NSUInteger)documentRevision {
    return [self.providersByIdentifier[identifier]
        snapshotForDocumentRevision:documentRevision];
}

- (CGPoint)documentOriginForBlockIdentifier:(NSUUID *)identifier {
    NSValue *origin = self.originsByIdentifier[identifier];
    return origin == nil ? CGPointZero : origin.CGPointValue;
}

- (CGRect)selectionSlotForBlockIdentifier:(NSUUID *)identifier {
    NSValue *slot = self.selectionSlotsByIdentifier[identifier];
    if (slot == nil) {
        return CGRectNull;
    }
    CGRect box = slot.CGRectValue;
    NSValue *declaredValue = self.selectionBoxes[identifier];
    if (declaredValue != nil) {
        CGRect declared = declaredValue.CGRectValue;
        box.origin.x = CGRectGetMinX(declared);
        box.size.width = CGRectGetWidth(declared);
    }
    return box;
}

- (CGRect)selectionBoxForBlockIdentifier:(NSUUID *)identifier {
    NSValue *declared = self.selectionBoxes[identifier];
    if (declared == nil) {
        return CGRectNull;
    }
    CGRect slot = [self selectionSlotForBlockIdentifier:identifier];
    if (CGRectIsNull(slot)) {
        return CGRectNull;
    }
    return CGRectIntersection(declared.CGRectValue, slot);
}

- (IDBlockLayout *)nearestBlockLayoutForDocumentPoint:(CGPoint)point {
    NSArray<IDBlockLayout *> *layouts = self.blockLayouts;
    if (layouts.count == 0) {
        return nil;
    }
    // The y-scan the stack always had, with one change: a run of placed blocks is ONE unit of it,
    // entered at the run's topmost edge. Inside a run the answer is by rect.
    IDBlockLayout *nearest = layouts.firstObject;
    NSArray<IDBlockLayout *> *nearestRun = nil;
    NSUInteger index = 0;
    while (index < layouts.count) {
        IDBlockLayout *layout = layouts[index];
        if (self.hitRectsByIdentifier[layout.blockIdentifier] == nil) {
            if (point.y < [self documentOriginForBlockIdentifier:layout.blockIdentifier].y) {
                break;
            }
            nearest = layout;
            nearestRun = nil;
            index += 1;
            continue;
        }
        NSUInteger end = index;
        CGFloat top = CGFLOAT_MAX;
        while (end < layouts.count &&
               self.hitRectsByIdentifier[layouts[end].blockIdentifier] != nil) {
            top = MIN(top, CGRectGetMinY(self.hitRectsByIdentifier[layouts[end].blockIdentifier].CGRectValue));
            end += 1;
        }
        if (point.y < top) {
            break;
        }
        nearest = layout;
        nearestRun = [layouts subarrayWithRange:NSMakeRange(index, end - index)];
        index = end;
    }
    if (nearestRun == nil) {
        return nearest;
    }
    IDBlockLayout *best = nearestRun.firstObject;
    CGFloat bestDistance = CGFLOAT_MAX;
    for (IDBlockLayout *member in nearestRun) {
        CGRect rect = self.hitRectsByIdentifier[member.blockIdentifier].CGRectValue;
        if (CGRectContainsPoint(rect, point)) {
            return member;
        }
        CGFloat dx = MAX(MAX(CGRectGetMinX(rect) - point.x, point.x - CGRectGetMaxX(rect)), 0);
        CGFloat dy = MAX(MAX(CGRectGetMinY(rect) - point.y, point.y - CGRectGetMaxY(rect)), 0);
        CGFloat distance = hypot(dx, dy);
        if (distance < bestDistance) {
            bestDistance = distance;
            best = member;
        }
    }
    return best;
}

- (NSUUID *)nearestBlockIdentifierForDocumentPoint:(CGPoint)point {
    return [self nearestBlockLayoutForDocumentPoint:point].blockIdentifier;
}

- (IDPlacedRunScrollView *)id_runScrollViewContaining:(NSUUID *)identifier {
    for (IDPlacedRunScrollView *scroll in self.runScrollViewsByFirstIdentifier.allValues) {
        if ([scroll.memberIdentifiers containsObject:identifier]) {
            return scroll;
        }
    }
    return nil;
}

- (UIView *)placedRunContentViewForBlockIdentifier:(NSUUID *)identifier {
    return [self id_runScrollViewContaining:identifier].runContentView;
}

- (CGFloat)placedRunContentOffsetForBlockIdentifier:(NSUUID *)identifier {
    return [self id_runScrollViewContaining:identifier].contentOffset.x;
}

- (void)setPlacedRunContentOffset:(CGFloat)offset forBlockIdentifier:(NSUUID *)identifier {
    IDPlacedRunScrollView *scroll = [self id_runScrollViewContaining:identifier];
    if (scroll == nil) {
        return;
    }
    CGFloat maxX = MAX(scroll.contentSize.width - CGRectGetWidth(scroll.bounds), 0);
    scroll.contentOffset = CGPointMake(MIN(MAX(offset, 0), maxX), 0);
}

/// Whether any placed run is IN FLIGHT — being dragged, or coasting from a drag.
///
/// A host that puts this view inside something with a drag of its own — a sheet that dismisses on a
/// downward pan — needs this: that outer gesture recognises simultaneously with everything, and a
/// finger landing on a coasting run would otherwise start the dismiss instead of catching the run
/// (K3, 2026-09-11). A run in flight is the editor's, and the host says so on its behalf.
- (BOOL)id_hasPlacedRunInFlight {
    for (IDPlacedRunScrollView *run in self.runScrollViewsByFirstIdentifier.allValues) {
        if (run.id_isInFlight) {
            return YES;
        }
    }
    return NO;
}

/// Is the placed run that OWNS this view in flight? NO for a view that is inside no run.
///
/// The per-view question, where `id_hasPlacedRunInFlight` is the per-editor one. A host draws its
/// own interactive chrome inside a run — a button pill, a formula's tap target — and a tap that
/// CATCHES a moving run must not also press what is under the finger, which is what every scroll
/// view in iOS does for its own content and what a run cannot do for itself: it never receives the
/// touch, so `touchesShouldBegin:withEvent:inContentView:` is never called on it either.
///
/// The walk stops at this canvas, so a view somewhere else in the host's tree answers NO rather
/// than walking out into the window.
- (BOOL)id_isPlacedRunInFlightForView:(UIView *)view {
    UIView *candidate = view;
    while (candidate != nil && candidate != self) {
        if ([candidate isKindOfClass:[IDPlacedRunScrollView class]]) {
            return ((IDPlacedRunScrollView *)candidate).id_isInFlight;
        }
        candidate = candidate.superview;
    }
    return NO;
}

/// Where a run caught under a finger settles — see `-[IDPlacedRunScrollView
/// gestureRecognizer:shouldReceiveTouch:]`, which is what catches it.
+ (CGFloat)id_caughtRunOffsetForCurrent:(CGFloat)current maximum:(CGFloat)maximum {
    return MIN(MAX(current, 0), MAX(maximum, 0));
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // The pass derives every visual origin from the run's offset, and the text view's own layout
    // re-runs the pass and refreshes the interaction geometry — so a scroll only asks for one.
    [self.superview setNeedsLayout];
}

- (NSUUID *)verticallyAdjacentBlockIdentifierFromBlockIdentifier:(NSUUID *)identifier
                                                         downward:(BOOL)downward
                                             anchorPositionOffset:(CGFloat)anchorX {
    NSArray<NSUUID *> *ordered = self.orderedBlockIdentifiers;
    NSUInteger sourceIndex = [ordered indexOfObject:identifier];
    if (sourceIndex == NSNotFound) {
        return nil;
    }
    NSInteger step = downward ? 1 : -1;
    NSValue *sourceRect = self.hitRectsByIdentifier[identifier];
    if (sourceRect != nil) {
        // Leaving a placed block: the ROW of placed blocks just past its edge, and within it the
        // member NEAREST the caret's x. Candidates are the placed blocks adjacent to the source in
        // document order (its run, and a run placed straight after it); the row is the nearest
        // beyond the edge, whatever border separates it. A point probe under the goal x found
        // nothing whenever the x lay outside every cell — left of the first column, or in the
        // border between two — and a probe one point past the TOP edge landed in the border above
        // it, so the walk stepped out of the run and skipped every row between (composer harness
        // p17, `HarnessVerticalMoveAtDocumentEdgeTests`).
        CGRect rect = sourceRect.CGRectValue;
        NSInteger first = (NSInteger)sourceIndex;
        while (first > 0 && self.hitRectsByIdentifier[ordered[first - 1]] != nil) {
            first -= 1;
        }
        NSInteger last = (NSInteger)sourceIndex;
        while (last + 1 < (NSInteger)ordered.count && self.hitRectsByIdentifier[ordered[last + 1]] != nil) {
            last += 1;
        }
        const CGFloat tolerance = 0.5;
        CGFloat nearestEdge = downward ? CGFLOAT_MAX : -CGFLOAT_MAX;
        for (NSInteger index = first; index <= last; index += 1) {
            CGRect candidate = self.hitRectsByIdentifier[ordered[index]].CGRectValue;
            if (downward && CGRectGetMinY(candidate) >= CGRectGetMaxY(rect) - tolerance) {
                nearestEdge = MIN(nearestEdge, CGRectGetMinY(candidate));
            } else if (!downward && CGRectGetMaxY(candidate) <= CGRectGetMinY(rect) + tolerance) {
                nearestEdge = MAX(nearestEdge, CGRectGetMaxY(candidate));
            }
        }
        NSMutableArray<NSUUID *> *row = [NSMutableArray array];
        for (NSInteger index = first; index <= last; index += 1) {
            CGRect candidate = self.hitRectsByIdentifier[ordered[index]].CGRectValue;
            CGFloat candidateEdge = downward ? CGRectGetMinY(candidate) : CGRectGetMaxY(candidate);
            BOOL beyond = downward
                ? CGRectGetMinY(candidate) >= CGRectGetMaxY(rect) - tolerance
                : CGRectGetMaxY(candidate) <= CGRectGetMinY(rect) + tolerance;
            if (beyond && fabs(candidateEdge - nearestEdge) <= tolerance) {
                [row addObject:ordered[index]];
            }
        }
        NSUUID *nearest = [self id_memberOf:row nearestToX:anchorX];
        if (nearest != nil) {
            return nearest;
        }
        // Nothing placed there: step out of the run in document order.
        NSInteger index = (NSInteger)sourceIndex;
        while (index >= 0 && index < (NSInteger)ordered.count &&
               self.hitRectsByIdentifier[ordered[index]] != nil) {
            index += step;
        }
        return (index >= 0 && index < (NSInteger)ordered.count) ? ordered[index] : nil;
    }
    NSInteger adjacent = (NSInteger)sourceIndex + step;
    if (adjacent < 0 || adjacent >= (NSInteger)ordered.count) {
        return nil;
    }
    NSUUID *neighbour = ordered[adjacent];
    if (self.hitRectsByIdentifier[neighbour] == nil) {
        return neighbour;
    }
    // Entering a run: the member on the run's near edge under the caret's x, else the edge member.
    NSMutableArray<NSUUID *> *run = [NSMutableArray array];
    CGFloat runTop = CGFLOAT_MAX;
    CGFloat runBottom = -CGFLOAT_MAX;
    NSInteger index = adjacent;
    while (index >= 0 && index < (NSInteger)ordered.count &&
           self.hitRectsByIdentifier[ordered[index]] != nil) {
        CGRect rect = self.hitRectsByIdentifier[ordered[index]].CGRectValue;
        [run addObject:ordered[index]];
        runTop = MIN(runTop, CGRectGetMinY(rect));
        runBottom = MAX(runBottom, CGRectGetMaxY(rect));
        index += step;
    }
    // Entering a run: the member on its NEAR edge nearest the caret's x. `run` is collected walking
    // in the direction of travel, so its first object is the near edge's FIRST member only going
    // down; going up it is the run's LAST cell, and a goal x left of the first column (the start
    // of the line under a table) landed in the last column.
    CGFloat probeY = downward ? runTop + 1 : runBottom - 1;
    NSMutableArray<NSUUID *> *edge = [NSMutableArray array];
    for (NSUUID *member in run) {
        if (IDCanvasRectSpansY(self.hitRectsByIdentifier[member].CGRectValue, probeY)) {
            [edge addObject:member];
        }
    }
    NSUUID *nearest = [self id_memberOf:edge nearestToX:anchorX];
    return nearest ?: run.firstObject;
}

/// The member whose hit rect is horizontally nearest `x` (zero inside it), the earliest in document
/// order on a tie; nil for no members.
- (nullable NSUUID *)id_memberOf:(NSArray<NSUUID *> *)members nearestToX:(CGFloat)x {
    NSUUID *best = nil;
    CGFloat bestDistance = CGFLOAT_MAX;
    NSArray<NSUUID *> *ordered = self.orderedBlockIdentifiers;
    NSUInteger bestIndex = NSNotFound;
    for (NSUUID *member in members) {
        CGRect rect = self.hitRectsByIdentifier[member].CGRectValue;
        CGFloat distance = x < CGRectGetMinX(rect) ? CGRectGetMinX(rect) - x
            : (x > CGRectGetMaxX(rect) ? x - CGRectGetMaxX(rect) : 0.0);
        NSUInteger index = [ordered indexOfObject:member];
        if (distance < bestDistance || (distance == bestDistance && index < bestIndex)) {
            best = member;
            bestDistance = distance;
            bestIndex = index;
        }
    }
    return best;
}

- (void)id_setCanvasHost:(id)host {
    self.canvasHost = host;
    for (IDBlockLayout *layout in self.blockLayouts) {
        [layout id_setCanvasHost:host];
    }
}

@end

#endif
