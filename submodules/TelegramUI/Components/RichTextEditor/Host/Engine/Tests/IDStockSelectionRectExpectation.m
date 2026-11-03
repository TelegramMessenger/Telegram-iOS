#import "IDStockSelectionRectExpectation.h"

CGRect IDSelectionRectExpectedFromStock(CGRect stockRect,
                                        CGRect containerBounds,
                                        NSWritingDirection writingDirection,
                                        BOOL coveredFromLineStart,
                                        BOOL coveredToLineEnd) {
    // A line's beginning is its leading edge, which is the RIGHT one when the line runs
    // right-to-left. Everything else about the rule is direction-free.
    BOOL rightToLeft = (writingDirection == NSWritingDirectionRightToLeft);
    BOOL fillsMinX = rightToLeft ? coveredToLineEnd : coveredFromLineStart;
    BOOL fillsMaxX = rightToLeft ? coveredFromLineStart : coveredToLineEnd;

    CGFloat minX = fillsMinX ? CGRectGetMinX(containerBounds) : CGRectGetMinX(stockRect);
    CGFloat maxX = fillsMaxX ? CGRectGetMaxX(containerBounds) : CGRectGetMaxX(stockRect);
    return CGRectMake(minX, CGRectGetMinY(stockRect),
                      MAX(maxX - minX, 0.0), CGRectGetHeight(stockRect));
}
