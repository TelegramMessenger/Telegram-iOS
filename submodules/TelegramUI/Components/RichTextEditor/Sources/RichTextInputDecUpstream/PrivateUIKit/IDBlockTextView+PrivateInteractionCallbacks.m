#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"

#import "TGPrivateMethodAliases.h"

#import "IDBlockTextViewInternal.h"
#import "IDBlockStackCanvasView.h"

#import "IDPrivateUIKit.h"
#import "IDVerticalAutoscroll.h"
#import "IDVerticalAutoscrollGeometry.h"
#import "IDUIKitInteractionCapability.h"
#import "IDUIKitBehaviorReport.h"

#include <math.h>

static BOOL IDBlockTextViewHasActiveBehaviorCapability(
    IDBlockTextView *view,
    NSString *identifier) {
    for (IDUIKitCapabilityReport *report
         in view.id_behaviorReport.capabilities) {
        if ([report.identifier isEqualToString:identifier]) {
            return report.state == IDUIKitCapabilityStateActive;
        }
    }
    return view.id_behaviorKernel == nil;
}

static BOOL IDBlockTextViewCanonicalRangeIsValid(
    NSRange range) {
    return range.location != NSNotFound;
}

static CGFloat IDBlockTextViewAutoscrollPointDistance(
    UIScrollView *container,
    CGPoint first,
    CGPoint second) {
    CGPoint firstGlobal =
        [container convertPoint:first toView:nil];
    CGPoint secondGlobal =
        [container convertPoint:second toView:nil];
    return hypot(secondGlobal.x - firstGlobal.x,
                 secondGlobal.y - firstGlobal.y);
}

@interface IDBlockTextView (PrivateInteractionCallbacks)
    <IDVerticalAutoscrollTarget>
@end

@implementation IDBlockTextView (PrivateInteractionCallbacks)

- (id)tgpn_interactionAssistant {
    return self.id_interactionCapability.privateAssistant;
}

- (UIView *)tgpn__textInputViewForAddingGestureRecognizers {
    return self;
}

- (UIView *)tgpn_selectionContainerView {
    return [self.id_selectionPresentationBackend id_selectionContainerView];
}

- (CGPoint)id_scrollHostAutoscrollPointForAssistantPoint:(CGPoint)point {
    return [self convertPoint:point fromView:self.id_blockStack];
}

- (void)tgpn_startAutoscroll:(CGPoint)point {
    if (!IDBlockTextViewHasActiveBehaviorCapability(
            self, @"autoscrollEntry")) {
        [self.id_interactionCapability id_autoscrollWillNotStart];
        [self cancelAutoscroll];
        return;
    }
    // UITextInteractionAssistant expresses the adjustment point in the proxy
    // textInputView's coordinates. Translate once from the document-level
    // block stack into the outer scroll host before applying edge policy.
    CGPoint scrollPoint = [self id_scrollHostAutoscrollPointForAssistantPoint:point];
    if (self.id_behaviorBackend == IDUIKitBehaviorBackendReference &&
        self.id_textAutoscroll == nil) {
        // The reference implementation materializes its retained legacy
        // engine before deciding whether this point can start a session.
        self.id_textAutoscroll = IDPrivateNewTextAutoscroll();
    }
    UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;
    CGFloat edgeInset = (idiom == UIUserInterfaceIdiomPad || idiom == UIUserInterfaceIdiomMac)
        ? 32.0
        : 8.0;
    UIEdgeInsets adjustedInsets = self.adjustedContentInset;
    CGFloat minimumOffsetY = -adjustedInsets.top;
    CGFloat maximumOffsetY = MAX(
        minimumOffsetY,
        self.contentSize.height - CGRectGetHeight(self.bounds) +
            adjustedInsets.bottom);
    CGRect visible = IDVerticalAutoscrollSafeRect(
        self.bounds, adjustedInsets, self.textContainerInset, 0.0);
    CGRect safe = IDVerticalAutoscrollSafeRect(
        self.bounds, adjustedInsets, self.textContainerInset, edgeInset);
    IDVerticalAutoscrollDirection directions =
        IDVerticalAutoscrollDirectionsForPoint(
            scrollPoint,
            safe,
            self.contentOffset.y,
            minimumOffsetY,
            maximumOffsetY);
    NSString *engine =
        self.id_behaviorBackend == IDUIKitBehaviorBackendReference
            ? @"uikit"
            : @"project";
    IDPrivateRecordTextAutoscrollStartForUITesting(
        self, point, scrollPoint, visible, safe, directions, engine);
    if (directions == 0) {
        // Nothing for THIS engine to scroll here, but the stock session is decided by a different
        // rule (`IDVerticalAutoscrollStockSessionWouldStart`), and where it would have started, its
        // first tick — which fires at once and then cancels, having nothing to scroll either — is
        // what tells the text interaction the finger has left the caret. Without it a long press
        // within 40pt of the caret moved the caret under the loupe and put it back on release (the
        // edit menu then rose over the unmoved caret), where the stock composer leaves it at the
        // finger: in a composer of up to about three lines EVERY point is in the stock band
        // (composer harness, 2026-09-24, `HarnessLongPressCaretUITests`).
        //
        // The "will not start" notice still goes first, exactly as before: it is what releases the
        // magnifiers, and it leaves the bit alone, so the tick reported after it survives.
        [self.id_interactionCapability id_autoscrollWillNotStart];
        if (IDVerticalAutoscrollStockSessionWouldStart(
                scrollPoint, self.bounds, adjustedInsets,
                self.textContainerInset, self.contentSize.height)) {
            [self.id_interactionCapability autoscrollDidTick];
        }
        [self cancelAutoscroll];
        return;
    }
    if (self.id_behaviorBackend == IDUIKitBehaviorBackendReference) {
        IDPrivateTextAutoscrollStart(
            self.id_textAutoscroll,
            self.id_interactionCapability.privateAssistant,
            self,
            scrollPoint,
            directions,
            0.075);
        return;
    }

    if (self.id_verticalAutoscroll == nil) {
        self.id_verticalAutoscroll = [IDVerticalAutoscroll new];
    }
    BOOL coalesces =
        self.id_verticalAutoscroll.isActive &&
        self.id_verticalAutoscroll.id_scrollContainer == self &&
        self.id_verticalAutoscroll.directions == directions &&
        self.id_verticalAutoscroll.repeatInterval == 0.075 &&
        IDBlockTextViewAutoscrollPointDistance(
            self,
            self.id_verticalAutoscroll.point,
            scrollPoint) < 70.0;
    if (!coalesces) {
        self.id_autoscrollRampState =
            (IDVerticalAutoscrollRampState){0};
        NSRange current =
            [self id_NSRangeForTextRange:self.selectedTextRange];
        NSRange latest =
            IDBlockTextViewCanonicalRangeIsValid(
                self.id_latestCanonicalSelection)
                ? self.id_latestCanonicalSelection
                : current;
        NSRange previous =
            IDBlockTextViewCanonicalRangeIsValid(
                self.id_previousCanonicalSelection)
                ? self.id_previousCanonicalSelection
                : latest;
        if (previous.length == 0 || latest.length == 0) {
            previous = latest;
        }
        UITextRange *selection = self.selectedTextRange;
        CGRect startRect = selection == nil
            ? CGRectNull
            : [self caretRectForPosition:selection.start];
        CGRect endRect = selection == nil
            ? CGRectNull
            : [self caretRectForPosition:selection.end];
        CGPoint documentPoint =
            [self.id_blockStack convertPoint:scrollPoint
                                    fromView:self];
        self.id_activeAutoscrollEndpoint =
            IDVerticalAutoscrollResolveActiveEndpoint(
                previous,
                latest,
                documentPoint,
                startRect,
                endRect,
                self.id_activeAutoscrollEndpoint);
    }
    self.id_autoscrollPointReferenceOffsetY =
        self.contentOffset.y;
    [self.id_verticalAutoscroll
        startWithTarget:self
        scrollContainer:self
        point:scrollPoint
        directions:directions
        repeatInterval:0.075];
}

- (void)cancelAutoscroll {
    IDPrivateRecordTextAutoscrollCancelForUITesting(self);
    if (self.id_behaviorBackend == IDUIKitBehaviorBackendReference) {
        IDPrivateTextAutoscrollInvalidate(self.id_textAutoscroll);
    } else {
        [self id_cancelVerticalAutoscrollSession];
    }
}

- (void)id_cancelVerticalAutoscrollSession {
    if (!NSThread.isMainThread) {
        __weak IDBlockTextView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf id_cancelVerticalAutoscrollSession];
        });
        return;
    }
    IDVerticalAutoscroll *session =
        self.id_verticalAutoscroll;
    self.id_verticalAutoscroll = nil;
    self.id_autoscrollRampState =
        (IDVerticalAutoscrollRampState){0};
    self.id_isPublishingAutoscrollSelection = NO;
    [session invalidate];
}

- (void)updateVerticalAutoscroll:
    (IDVerticalAutoscroll *)autoscroll {
    if (autoscroll == nil ||
        autoscroll != self.id_verticalAutoscroll ||
        autoscroll.id_scrollContainer != self) {
        return;
    }
    // Every tick of the stock session reports itself before deciding whether to scroll; see
    // `-[IDUIKitInteractionCapability autoscrollDidTick]`.
    [self.id_interactionCapability autoscrollDidTick];
    UIEdgeInsets insets = self.adjustedContentInset;
    CGFloat minimumOffsetY = -insets.top;
    CGFloat maximumOffsetY = MAX(
        minimumOffsetY,
        self.contentSize.height - CGRectGetHeight(self.bounds) +
            insets.bottom);
    CALayer *presentationLayer =
        (CALayer *)self.layer.presentationLayer;
    CGFloat currentOffsetY = presentationLayer == nil
        ? self.contentOffset.y
        : presentationLayer.bounds.origin.y;
    IDVerticalAutoscrollRampState rampState =
        self.id_autoscrollRampState;
    IDVerticalAutoscrollStep step =
        IDVerticalAutoscrollMakeStep(
            currentOffsetY,
            minimumOffsetY,
            maximumOffsetY,
            autoscroll.directions,
            autoscroll.count,
            &rampState);
    self.id_autoscrollRampState = rampState;
    if (!step.shouldContinue) {
        [self id_cancelVerticalAutoscrollSession];
        return;
    }

    CGPoint targetOffset =
        CGPointMake(self.contentOffset.x, step.targetOffsetY);
    [self id_setVerticalAutoscrollContentOffset:targetOffset
                                       duration:step.animationDuration];
    [self id_reconcileDerivedState];

    CGPoint reprojectedPoint = autoscroll.point;
    // AGAINST THE OFFSET THIS TICK MEASURED, not the one it has just scrolled to.
    //
    // The autoscroll point is in the scroll view's CONTENT coordinates, captured when the session
    // began, so reprojecting it by the scroll travelled since is what keeps it under the finger —
    // the finger holds a screen position while the content moves beneath it. But the travel has to
    // be measured to what is ON SCREEN. `id_setVerticalAutoscrollContentOffset:duration:` above
    // assigns `contentOffset` synchronously and lets the presentation follow over the next 75ms, so
    // reading it back here reports a scroll the user cannot see yet: the endpoint is placed a line
    // ahead every tick and the content then slides up to meet it, which is what the handle being
    // dragged appeared to animate on its own (device, 2026-09-15; measured 959 against 978, about
    // one line, every 75ms).
    //
    // `currentOffsetY` is that same measurement — the presentation layer's, read before the step —
    // and using it here is what makes the step and the reprojection agree about where the view is.
    reprojectedPoint.y +=
        currentOffsetY - self.id_autoscrollPointReferenceOffsetY;
    CGPoint documentPoint =
        [self.id_blockStack convertPoint:reprojectedPoint
                                fromView:self];
    UITextPosition *position =
        [self closestPositionToPoint:documentPoint];
    UITextRange *selection = self.selectedTextRange;
    if (position == nil || selection == nil) {
        [self id_cancelVerticalAutoscrollSession];
        return;
    }
    NSInteger startValue =
        [self offsetFromPosition:self.beginningOfDocument
                     toPosition:selection.start];
    NSInteger endValue =
        [self offsetFromPosition:self.beginningOfDocument
                     toPosition:selection.end];
    NSInteger candidateValue =
        [self offsetFromPosition:self.beginningOfDocument
                     toPosition:position];
    if (startValue < 0 || endValue < 0 ||
        candidateValue < 0) {
        [self id_cancelVerticalAutoscrollSession];
        return;
    }
    NSUInteger startOffset = (NSUInteger)startValue;
    NSUInteger endOffset = (NSUInteger)endValue;
    NSUInteger candidate = (NSUInteger)candidateValue;
    if (self.id_activeAutoscrollEndpoint ==
        IDVerticalAutoscrollSelectionEndpointStart) {
        startOffset = MIN(candidate, endOffset);
    } else {
        endOffset = MAX(candidate, startOffset);
    }
    UITextPosition *newStart =
        [self positionFromPosition:self.beginningOfDocument
                           offset:(NSInteger)startOffset];
    UITextPosition *newEnd =
        [self positionFromPosition:self.beginningOfDocument
                           offset:(NSInteger)endOffset];
    if (newStart == nil || newEnd == nil) {
        [self id_cancelVerticalAutoscrollSession];
        return;
    }
    self.id_isPublishingAutoscrollSelection = YES;
    @try {
        self.selectedTextRange =
            [self textRangeFromPosition:newStart
                             toPosition:newEnd];
    } @finally {
        self.id_isPublishingAutoscrollSelection = NO;
    }
    [self layoutIfNeeded];
}

@end

// This file's callbacks, added under their private names (`IDBlockTextViewInstallPrivateCallbacks`).
void IDBlockTextViewInstallPrivateInteractionCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_interactionAssistant, @selector(tgpn_interactionAssistant) },
        { TGPN__textInputViewForAddingGestureRecognizers, @selector(tgpn__textInputViewForAddingGestureRecognizers) },
        { TGPN_selectionContainerView, @selector(tgpn_selectionContainerView) },
        { TGPN_startAutoscroll_, @selector(tgpn_startAutoscroll:) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

#endif
