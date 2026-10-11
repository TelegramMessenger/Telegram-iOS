#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "IDVerticalAutoscroll.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(
    NSUInteger,
    IDVerticalAutoscrollSelectionEndpoint) {
    IDVerticalAutoscrollSelectionEndpointStart,
    IDVerticalAutoscrollSelectionEndpointEnd,
};

typedef struct {
    CGFloat normalizationDistance;
    NSUInteger rampTicks;
} IDVerticalAutoscrollRampState;

typedef struct {
    BOOL shouldContinue;
    CGFloat targetOffsetY;
    NSTimeInterval animationDuration;
} IDVerticalAutoscrollStep;

FOUNDATION_EXPORT CGRect IDVerticalAutoscrollSafeRect(
    CGRect bounds,
    UIEdgeInsets adjustedContentInset,
    UIEdgeInsets layoutInset,
    CGFloat edgeInset);

FOUNDATION_EXPORT IDVerticalAutoscrollDirection
IDVerticalAutoscrollDirectionsForPoint(
    CGPoint point,
    CGRect safeRect,
    CGFloat currentOffsetY,
    CGFloat minimumOffsetY,
    CGFloat maximumOffsetY);

/// The edge band, in points, in which the stock text view STARTS an autoscroll session (its
/// `AutoscrollEdgeBuffer` default). Not the band this engine scrolls in — that is the caller's
/// `edgeInset` above, 8 on a phone — only the band in which a stock session would exist at all.
FOUNDATION_EXPORT const CGFloat IDVerticalAutoscrollStockSessionEdgeBuffer;

/// Whether the stock text view would start an autoscroll session for `point` (scroll-view
/// coordinates), measured from its disassembly (iOS 27, 2026-09-24): the interior is `bounds` less
/// the adjusted content inset and the text-container inset; no session when that interior is at
/// least `contentHeight` tall; otherwise a session when the point lies in the top or bottom
/// `IDVerticalAutoscrollStockSessionEdgeBuffer` band of the interior — which is EVERY point when the
/// interior is shorter than two bands, as a chat composer of up to about three lines is.
///
/// It decides nothing about scrolling. A stock session that cannot scroll still ticks once before it
/// cancels itself, and that tick is what tells the text interaction the finger has left the caret's
/// neighbourhood (`IDUIKitInteractionCapability.autoscrollDidTick`): without it, a loupe that began
/// within 40pt of the caret returns the caret to where it was on release.
FOUNDATION_EXPORT BOOL IDVerticalAutoscrollStockSessionWouldStart(
    CGPoint point,
    CGRect bounds,
    UIEdgeInsets adjustedContentInset,
    UIEdgeInsets layoutInset,
    CGFloat contentHeight);

FOUNDATION_EXPORT IDVerticalAutoscrollStep
IDVerticalAutoscrollMakeStep(
    CGFloat currentOffsetY,
    CGFloat minimumOffsetY,
    CGFloat maximumOffsetY,
    IDVerticalAutoscrollDirection direction,
    NSUInteger count,
    IDVerticalAutoscrollRampState *state);

FOUNDATION_EXPORT IDVerticalAutoscrollSelectionEndpoint
IDVerticalAutoscrollResolveActiveEndpoint(
    NSRange previousSelection,
    NSRange currentSelection,
    CGPoint dragPoint,
    CGRect logicalStartRect,
    CGRect logicalEndRect,
    IDVerticalAutoscrollSelectionEndpoint fallback);

NS_ASSUME_NONNULL_END

#endif
