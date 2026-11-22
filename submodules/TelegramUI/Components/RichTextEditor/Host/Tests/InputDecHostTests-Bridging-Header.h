// Exposes the calibrated pixel instrument and upstream's spelling-readiness probe to the Swift
// hosted tests. Both come from `Tests/StockParitySupport/`, compiled here BY REFERENCE (see
// `Host/project.yml`) so the predicate, the render call and the thresholds are literally the same
// bytes the SwiftPM suite measured a zero with.
#import "IDStockParityPixels.h"
#import "IDSpellingReadinessProbe.h"
#import "IDStockParityRuntime.h"

#import <UIKit/UIKit.h>

/// UIKit's private tap-to-caret boundary snap, implemented by `UIResponder` and called from exactly
/// one place: `-[_UIKeyboardTextSelectionController selectPositionAtPoint:granularity:completionHandler:]`.
/// It is the seam `TGIDObservingBlockTextView` overrides. Declared here so a test can call it with
/// real types on the engine AND on a stock text view — the second is the control that proves what
/// UIKit's own rule is. See `EngineTapCaretPlacementTests`.
@interface UIResponder (TGIDTapCaretPlacementTesting)
- (nullable UITextPosition *)_findBoundaryPositionClosestToPosition:(nullable UITextPosition *)position
                                                    withGranularity:(UITextGranularity)granularity;
@end
