@import XCTest;

typedef struct {
    NSRange selection;
    CGRect caret;
    CGRect visible;
    CGPoint contentOffset;
    NSUInteger blockCount;
    NSUInteger presentationUpdates;
    NSUInteger containerCreations;
    BOOL containerStable;
} IDTouchSelectionStatus;

FOUNDATION_EXPORT BOOL IDTouchSelectionParseStatus(
    id value,
    IDTouchSelectionStatus *status,
    NSArray<NSDictionary<NSString *, id> *> **selectionRects);

FOUNDATION_EXPORT NSArray<NSValue *> *IDTouchSelectionBlueComponents(
    XCUIScreenshot *screenshot,
    CGRect screenRect);

FOUNDATION_EXPORT NSArray<NSValue *> *IDTouchSelectionHandleComponents(
    XCUIScreenshot *screenshot,
    CGRect screenRect);

FOUNDATION_EXPORT CGRect IDTouchSelectionMatchedHandle(
    BOOL logicalStart,
    NSArray<NSDictionary<NSString *, id> *> *selectionRects,
    IDTouchSelectionStatus status,
    CGRect editorFrame,
    XCUIScreenshot *screenshot,
    CGFloat maximumDistance);

FOUNDATION_EXPORT BOOL IDTouchSelectionIsLoupeSizedRegion(CGRect region);

FOUNDATION_EXPORT BOOL IDTouchSelectionHighlightIsVisible(
    XCUIScreenshot *screenshot,
    NSArray<NSDictionary<NSString *, id> *> *selectionRects,
    IDTouchSelectionStatus status,
    CGRect editorFrame);

FOUNDATION_EXPORT CGRect IDTouchSelectionLargestChangedRegion(
    XCUIScreenshot *before,
    XCUIScreenshot *during,
    CGRect screenRect,
    NSUInteger minimumChangedPixels);

FOUNDATION_EXPORT NSArray<NSValue *> *IDTouchSelectionChangedRegions(
    XCUIScreenshot *before,
    XCUIScreenshot *during,
    CGRect screenRect,
    NSUInteger minimumChangedPixels);

FOUNDATION_EXPORT BOOL IDTouchSelectionResidualRegionsAreConfinedToCaretsAndNotLoupeSized(
    NSArray<NSValue *> *regions,
    NSArray<NSValue *> *caretScreenRects);
