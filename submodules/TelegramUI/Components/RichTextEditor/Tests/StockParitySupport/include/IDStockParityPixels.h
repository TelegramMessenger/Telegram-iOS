// PORTED from /Users/isaac/Documents/InputDec/Tests/IDTextCanvasTestSupport.h
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369. See ../PROVENANCE.md (StockParity) for the
// per-symbol origin and every deviation.
//
// DROPPED from the upstream header: `IDTextCanvasFixture`, whose designated initializer builds an
// `IDTextLayoutCanvasView` — upstream PRODUCT source, which Global Constraint 12 forbids porting.
// Nothing else in the file touches product source, so the rest is a verbatim carry-over.

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/// Spins the main run loop until `condition` answers YES or `timeout` elapses. Upstream verbatim.
FOUNDATION_EXPORT BOOL IDWaitForCondition(NSTimeInterval timeout, BOOL (^condition)(void));

/// Renders `view` through `-[CALayer renderInContext:]`.
///
/// **`layer.renderInContext:` and NOT `drawViewHierarchyInRect:afterScreenUpdates:`** — that is
/// upstream's choice and it is load-bearing here for a reason upstream never had to write down:
/// `drawHierarchy(afterScreenUpdates: true)` renders NOTHING for a view whose window is not on a
/// real screen, which is every window in an xctest process. Task P1 measured it returning zero red
/// pixels for a *known* red underline.
FOUNDATION_EXPORT UIImage *IDRenderView(UIView *view);

/// Counts pixels matching upstream's misspelling-marker red predicate inside `rect` (view points).
FOUNDATION_EXPORT NSUInteger IDCountRedPixels(UIImage *image, CGRect rect);

/// Per-row breakdown of `IDCountRedPixels`, for diagnosing a marker that landed outside the ROI.
FOUNDATION_EXPORT NSArray<NSNumber *> *IDRedPixelCountsByRow(UIImage *image, CGRect rect);

/// Counts pixels with any alpha inside `rect`. Distinguishes "the render is blank" from
/// "the render happened and contains no red" — the difference between an instrument bug and a
/// finding.
FOUNDATION_EXPORT NSUInteger IDCountNontransparentPixels(UIImage *image, CGRect rect);

NS_ASSUME_NONNULL_END
