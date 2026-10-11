@import XCTest;

#include <math.h>

#import "IDStockSelectionRectExpectation.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDSpellingReadinessProbe.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextRenderingSurfaceView.h"
#import "IDTextCanvasTestSupport.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface IDRichTextLayoutController (IDTask11SnapshotTesting)
- (IDRichTextRange *)id_nativeRangeForCanonicalRange:(NSRange)range;
@end

@interface IDBlockTextViewParityTests : XCTestCase
@end

@implementation IDBlockTextViewParityTests

static BOOL IDParityRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

- (NSArray<NSAttributedString *> *)blocksForStrings:(NSArray<NSString *> *)strings
                                                font:(UIFont *)font {
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    NSDictionary *attributes = @{NSFontAttributeName: font};
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string
                                                          attributes:attributes]];
    }
    return blocks.copy;
}

- (IDBlockTextView *)blockViewWithStrings:(NSArray<NSString *> *)strings
                                     frame:(CGRect)frame
                                      font:(UIFont *)font {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:frame
      attributedBlocks:[self blocksForStrings:strings font:font]];
    view.font = font;
    view.textContainerInset = UIEdgeInsetsMake(11, 9, 13, 9);
    [view layoutIfNeeded];
    return view;
}

- (UITextView *)stockViewWithText:(NSString *)text
                            frame:(CGRect)frame
                             font:(UIFont *)font {
    UITextView *view = [[UITextView alloc] initWithFrame:frame];
    view.font = font;
    view.textContainerInset = UIEdgeInsetsMake(11, 9, 13, 9);
    view.text = text;
    [view layoutIfNeeded];
    return view;
}

- (UIWindow *)hostBlockView:(IDBlockTextView *)blockView stockView:(UITextView *)stockView {
    UIWindowScene *scene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.frame = CGRectMake(0, 0, 700, 420);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    blockView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    stockView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    blockView.frame = CGRectMake(20, 30, 280, 250);
    stockView.frame = CGRectMake(360, 30, 280, 250);
    [controller.view addSubview:blockView];
    [controller.view addSubview:stockView];
    [window makeKeyAndVisible];
    [controller.view layoutIfNeeded];
    [blockView layoutIfNeeded];
    [stockView layoutIfNeeded];
    return window;
}

- (CGRect)visibleRect:(CGRect)rect fromView:(UIView *)view inWindow:(UIWindow *)window {
    return [view convertRect:rect toView:window];
}

- (CGRect)normalizedVisibleRect:(CGRect)rect
                       fromView:(UIView *)view
                       inWindow:(UIWindow *)window {
    CGRect visible = [self visibleRect:rect fromView:view inWindow:window];
    visible.origin.x -= CGRectGetMinX(view.frame);
    visible.origin.y -= CGRectGetMinY(view.frame);
    return visible;
}

- (void)assertRectOrigin:(CGRect)actual matches:(CGRect)expected tolerance:(CGFloat)tolerance {
    XCTAssertTrue(IDParityRectIsFinite(actual), @"%@", NSStringFromCGRect(actual));
    XCTAssertTrue(IDParityRectIsFinite(expected), @"%@", NSStringFromCGRect(expected));
    XCTAssertEqualWithAccuracy(CGRectGetMinX(actual), CGRectGetMinX(expected), tolerance);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(actual), CGRectGetMinY(expected), tolerance);
}

- (void)testEveryCaretOffsetMatchesStockInVisibleHostCoordinates {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *first = @"one two three four";
    NSString *second = @"אבגדה six";
    NSString *text = [NSString stringWithFormat:@"%@\n%@", first, second];
    IDBlockTextView *blockView = [self blockViewWithStrings:@[first, second]
                                                     frame:CGRectZero
                                                      font:font];
    UITextView *stockView = [self stockViewWithText:text frame:CGRectZero font:font];
    UIWindow *window = [self hostBlockView:blockView stockView:stockView];
    blockView.contentOffset = CGPointMake(0, 4);
    stockView.contentOffset = CGPointMake(0, 4);

    for (NSUInteger offset = 0; offset <= text.length; offset += 1) {
        UITextPosition *blockPosition = [blockView
            positionFromPosition:blockView.beginningOfDocument offset:(NSInteger)offset];
        UITextPosition *stockPosition = [stockView
            positionFromPosition:stockView.beginningOfDocument offset:(NSInteger)offset];
        CGRect blockRect = [self visibleRect:[blockView caretRectForPosition:blockPosition]
                                    fromView:blockView
                                    inWindow:window];
        CGRect stockRect = [self visibleRect:[stockView caretRectForPosition:stockPosition]
                                    fromView:stockView
                                    inWindow:window];
        // Compare within each editor's host-space origin so their side-by-side
        // placement does not participate in the geometry assertion.
        blockRect.origin.x -= CGRectGetMinX(blockView.frame);
        stockRect.origin.x -= CGRectGetMinX(stockView.frame);
        [self assertRectOrigin:blockRect matches:stockRect tolerance:1.0];
    }
}

- (void)testEveryCollapsedSelectionRectMatchesStockCaretGeometry {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *first = @"one two";
    NSString *second = @"אבג";
    NSString *text = [NSString stringWithFormat:@"%@\n%@", first, second];
    IDBlockTextView *blockView =
        [self blockViewWithStrings:@[first, second]
                             frame:CGRectZero
                              font:font];
    UITextView *stockView =
        [self stockViewWithText:text frame:CGRectZero font:font];
    UIWindow *window =
        [self hostBlockView:blockView stockView:stockView];

    for (NSUInteger offset = 0; offset <= text.length; offset += 1) {
        UITextPosition *blockPosition = [blockView
            positionFromPosition:blockView.beginningOfDocument
                           offset:(NSInteger)offset];
        UITextPosition *stockPosition = [stockView
            positionFromPosition:stockView.beginningOfDocument
                           offset:(NSInteger)offset];
        UITextRange *blockRange =
            [blockView textRangeFromPosition:blockPosition
                                  toPosition:blockPosition];
        UITextRange *stockRange =
            [stockView textRangeFromPosition:stockPosition
                                  toPosition:stockPosition];
        NSArray<UITextSelectionRect *> *blockRects =
            [blockView selectionRectsForRange:blockRange];
        NSArray<UITextSelectionRect *> *stockRects =
            [stockView selectionRectsForRange:stockRange];
        XCTAssertEqual(blockRects.count, stockRects.count,
                       @"offset=%lu", (unsigned long)offset);
        XCTAssertEqual(blockRects.count, 1U,
                       @"offset=%lu", (unsigned long)offset);
        if (blockRects.count != 1 || stockRects.count != 1) continue;
        CGRect blockRect = [self normalizedVisibleRect:blockRects[0].rect
                                              fromView:blockView
                                              inWindow:window];
        CGRect stockRect = [self normalizedVisibleRect:stockRects[0].rect
                                              fromView:stockView
                                              inWindow:window];
        [self assertRectOrigin:blockRect matches:stockRect tolerance:1.0];
        XCTAssertEqualWithAccuracy(CGRectGetWidth(blockRect),
                                   CGRectGetWidth(stockRect), 0.5);
        XCTAssertEqualWithAccuracy(CGRectGetHeight(blockRect),
                                   CGRectGetHeight(stockRect), 1.0);
        XCTAssertEqual(blockRects[0].containsStart,
                       stockRects[0].containsStart);
        XCTAssertEqual(blockRects[0].containsEnd,
                       stockRects[0].containsEnd);
        XCTAssertEqual(blockRects[0].writingDirection,
                       stockRects[0].writingDirection);
    }
}

- (void)testSelectionAcrossStructuralNewlineAndRTLBlockMatchesStockEdges {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *first = @"one two three four";
    NSString *second = @"אבגדה six";
    NSString *text = [NSString stringWithFormat:@"%@\n%@", first, second];
    IDBlockTextView *blockView = [self blockViewWithStrings:@[first, second]
                                                     frame:CGRectZero
                                                      font:font];
    UITextView *stockView = [self stockViewWithText:text frame:CGRectZero font:font];
    UIWindow *window = [self hostBlockView:blockView stockView:stockView];
    NSRange selection = NSMakeRange(first.length - 4, 8);
    UITextPosition *blockStart = [blockView positionFromPosition:blockView.beginningOfDocument
                                                         offset:(NSInteger)selection.location];
    UITextPosition *blockEnd = [blockView positionFromPosition:blockView.beginningOfDocument
                                                       offset:(NSInteger)NSMaxRange(selection)];
    UITextPosition *stockStart = [stockView positionFromPosition:stockView.beginningOfDocument
                                                         offset:(NSInteger)selection.location];
    UITextPosition *stockEnd = [stockView positionFromPosition:stockView.beginningOfDocument
                                                       offset:(NSInteger)NSMaxRange(selection)];
    NSArray<UITextSelectionRect *> *blockRects = [blockView selectionRectsForRange:
        [blockView textRangeFromPosition:blockStart toPosition:blockEnd]];
    NSArray<UITextSelectionRect *> *stockRects = [stockView selectionRectsForRange:
        [stockView textRangeFromPosition:stockStart toPosition:stockEnd]];
    XCTAssertEqual(blockRects.count, stockRects.count);
    for (NSUInteger index = 0; index < MIN(blockRects.count, stockRects.count); index += 1) {
        CGRect blockRect = [self visibleRect:blockRects[index].rect
                                    fromView:blockView
                                    inWindow:window];
        CGRect stockRect = [self visibleRect:stockRects[index].rect
                                    fromView:stockView
                                    inWindow:window];
        XCTAssertTrue(IDParityRectIsFinite(blockRect), @"%@", NSStringFromCGRect(blockRect));
        XCTAssertTrue(IDParityRectIsFinite(stockRect), @"%@", NSStringFromCGRect(stockRect));
        blockRect.origin.x -= CGRectGetMinX(blockView.frame);
        stockRect.origin.x -= CGRectGetMinX(stockView.frame);
        // Both views are laid out at the same width with the same insets, so the stock view's own
        // container is the line container for both — in the view-local space these rects are in.
        CGRect container = CGRectMake(stockView.textContainerInset.left, 0.0,
                                      stockView.textContainer.size.width, 0.0);
        // The selection is "four" + the separator + the first three Hebrew letters. So the Latin
        // line is covered to its END, and the Hebrew line from its BEGINNING — which on an RTL line
        // is the right-hand edge. Both fill toward the container's trailing side, for opposite
        // reasons; neither line is covered on its other side, so that side stays on stock's glyph.
        BOOL isRTLBlock = (index == 1);
        CGRect expected = IDSelectionRectExpectedFromStock(
            stockRect, container,
            isRTLBlock ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight,
            /* coveredFromLineStart */ isRTLBlock,
            /* coveredToLineEnd */ !isRTLBlock);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(blockRect), CGRectGetMinX(expected), 1.5);
        XCTAssertEqualWithAccuracy(CGRectGetMaxX(blockRect), CGRectGetMaxX(expected), 1.5);
        XCTAssertEqualWithAccuracy(CGRectGetMinY(blockRect), CGRectGetMinY(expected), 1.5);
        XCTAssertEqual(blockRects[index].writingDirection, stockRects[index].writingDirection);
    }
}

- (void)testVirtualNewlineSidesAndComposedClusterNavigation {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *first = @"one two three four";
    NSString *second = @"👩🏽‍💻 short";
    NSString *text = [NSString stringWithFormat:@"%@\n%@", first, second];
    IDBlockTextView *view = [self blockViewWithStrings:@[first, second]
                                                frame:CGRectZero
                                                 font:font];
    UITextView *stock = [self stockViewWithText:text frame:CGRectZero font:font];
    UIWindow *window = [self hostBlockView:view stockView:stock];
    XCTAssertEqualWithAccuracy(view.adjustedContentInset.top,
                               stock.adjustedContentInset.top,
                               0.001);
    XCTAssertEqualWithAccuracy(view.contentOffset.x, stock.contentOffset.x, 0.001);
    XCTAssertEqualWithAccuracy(view.contentOffset.y, stock.contentOffset.y, 0.001);
    NSUInteger leadingOffset = first.length;
    NSUInteger trailingOffset = first.length + 1;
    UITextPosition *leading = [view positionFromPosition:view.beginningOfDocument
                                                 offset:(NSInteger)leadingOffset];
    UITextPosition *trailing = [view positionFromPosition:view.beginningOfDocument
                                                  offset:(NSInteger)trailingOffset];
    CGRect leadingRect = [view caretRectForPosition:leading];
    CGRect trailingRect = [view caretRectForPosition:trailing];
    XCTAssertTrue(IDParityRectIsFinite(leadingRect), @"%@", NSStringFromCGRect(leadingRect));
    XCTAssertTrue(IDParityRectIsFinite(trailingRect), @"%@", NSStringFromCGRect(trailingRect));
    XCTAssertLessThan(CGRectGetMinY(leadingRect), CGRectGetMinY(trailingRect));

    UITextPosition *stockLeading = [stock positionFromPosition:stock.beginningOfDocument
                                                        offset:(NSInteger)leadingOffset];
    UITextPosition *stockTrailing = [stock positionFromPosition:stock.beginningOfDocument
                                                         offset:(NSInteger)trailingOffset];
    CGRect stockLeadingRect = [stock caretRectForPosition:stockLeading];
    CGRect stockTrailingRect = [stock caretRectForPosition:stockTrailing];
    [self assertRectOrigin:[self normalizedVisibleRect:leadingRect
                                                fromView:view
                                                inWindow:window]
                   matches:[self normalizedVisibleRect:stockLeadingRect
                                                fromView:stock
                                                inWindow:window]
                 tolerance:1.0];
    [self assertRectOrigin:[self normalizedVisibleRect:trailingRect
                                                fromView:view
                                                inWindow:window]
                   matches:[self normalizedVisibleRect:stockTrailingRect
                                                fromView:stock
                                                inWindow:window]
                 tolerance:1.0];

    NSArray<NSDictionary<NSString *, id> *> *sides = @[
        @{@"name": @"leading", @"custom": leading, @"stock": stockLeading,
          @"offset": @(leadingOffset)},
        @{@"name": @"trailing", @"custom": trailing, @"stock": stockTrailing,
          @"offset": @(trailingOffset)},
    ];
    for (NSDictionary<NSString *, id> *side in sides) {
        UITextPosition *customPosition = side[@"custom"];
        UITextPosition *stockPosition = side[@"stock"];
        CGRect customCaret = [view caretRectForPosition:customPosition];
        CGRect stockCaret = [stock caretRectForPosition:stockPosition];
        CGPoint customPoint = CGPointMake(CGRectGetMidX(customCaret),
                                          CGRectGetMidY(customCaret));
        CGPoint stockPoint = CGPointMake(CGRectGetMidX(stockCaret),
                                         CGRectGetMidY(stockCaret));
        UITextPosition *customHit = [view closestPositionToPoint:customPoint];
        UITextPosition *stockHit = [stock closestPositionToPoint:stockPoint];
        NSInteger customOffset = [view offsetFromPosition:view.beginningOfDocument
                                               toPosition:customHit];
        NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                               toPosition:stockHit];
        NSInteger expectedOffset = [side[@"offset"] integerValue];
        XCTAssertEqual(customOffset, expectedOffset, @"%@ side", side[@"name"]);
        XCTAssertEqual(stockOffset, expectedOffset, @"%@ side stock oracle", side[@"name"]);
        XCTAssertEqual(customOffset, stockOffset, @"%@ side parity", side[@"name"]);
    }

    UITextPosition *right = [view positionFromPosition:leading
                                          inDirection:UITextLayoutDirectionRight
                                               offset:1];
    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:right],
                   (NSInteger)trailingOffset);
    UITextPosition *afterEmoji = [view positionFromPosition:trailing
                                                inDirection:UITextLayoutDirectionRight
                                                     offset:1];
    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:afterEmoji],
                   (NSInteger)(trailingOffset + [@"👩🏽‍💻" length]));
}

- (void)testMixedBiDiHorizontalMovementUsesVisualClusterAdjacency {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *text = @"abc אבג def";
    IDBlockTextView *view = [self blockViewWithStrings:@[text]
                                                frame:CGRectMake(0, 0, 280, 250)
                                                 font:font];
    UITextView *stock = [self stockViewWithText:text
                                          frame:CGRectMake(0, 0, 280, 250)
                                           font:font];
    [view layoutIfNeeded];
    [stock layoutIfNeeded];

    // Offset 5 is within the Hebrew run. Visual right is logically backward
    // there, while visual left is logically forward.
    UITextPosition *middle = [view positionFromPosition:view.beginningOfDocument offset:5];
    UITextPosition *right = [view positionFromPosition:middle
                                           inDirection:UITextLayoutDirectionRight
                                                offset:1];
    UITextPosition *left = [view positionFromPosition:middle
                                          inDirection:UITextLayoutDirectionLeft
                                               offset:1];
    UITextPosition *stockMiddle = [stock positionFromPosition:stock.beginningOfDocument
                                                       offset:5];
    UITextPosition *stockRight = [stock positionFromPosition:stockMiddle
                                                 inDirection:UITextLayoutDirectionRight
                                                      offset:1];
    UITextPosition *stockLeft = [stock positionFromPosition:stockMiddle
                                                inDirection:UITextLayoutDirectionLeft
                                                     offset:1];
    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:right],
                   [stock offsetFromPosition:stock.beginningOfDocument toPosition:stockRight]);
    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:left],
                   [stock offsetFromPosition:stock.beginningOfDocument toPosition:stockLeft]);
    CGRect middleRect = [view caretRectForPosition:middle];
    CGRect rightRect = [view caretRectForPosition:right];
    CGRect leftRect = [view caretRectForPosition:left];
    XCTAssertTrue(IDParityRectIsFinite(middleRect));
    XCTAssertTrue(IDParityRectIsFinite(rightRect));
    XCTAssertTrue(IDParityRectIsFinite(leftRect));
    CGRect stockMiddleRect = [stock caretRectForPosition:stockMiddle];
    CGRect stockRightRect = [stock caretRectForPosition:stockRight];
    CGRect stockLeftRect = [stock caretRectForPosition:stockLeft];
    XCTAssertTrue(IDParityRectIsFinite(stockMiddleRect));
    XCTAssertTrue(IDParityRectIsFinite(stockRightRect));
    XCTAssertTrue(IDParityRectIsFinite(stockLeftRect));
    [self assertRectOrigin:middleRect matches:stockMiddleRect tolerance:1.0];
    [self assertRectOrigin:rightRect matches:stockRightRect tolerance:1.0];
    [self assertRectOrigin:leftRect matches:stockLeftRect tolerance:1.0];

    UITextPosition *runStart = [view positionFromPosition:view.beginningOfDocument offset:4];
    UITextPosition *runEnd = [view positionFromPosition:view.beginningOfDocument offset:7];
    NSArray<UITextSelectionRect *> *rects = [view selectionRectsForRange:
        [view textRangeFromPosition:runStart toPosition:runEnd]];
    UITextPosition *stockRunStart = [stock positionFromPosition:stock.beginningOfDocument offset:4];
    UITextPosition *stockRunEnd = [stock positionFromPosition:stock.beginningOfDocument offset:7];
    NSArray<UITextSelectionRect *> *stockRects = [stock selectionRectsForRange:
        [stock textRangeFromPosition:stockRunStart toPosition:stockRunEnd]];
    XCTAssertGreaterThan(rects.count, 0U);
    XCTAssertEqual(rects.count, stockRects.count);
    for (NSUInteger index = 0; index < MIN(rects.count, stockRects.count); index += 1) {
        UITextSelectionRect *rect = rects[index];
        XCTAssertTrue(IDParityRectIsFinite(rect.rect), @"%@", NSStringFromCGRect(rect.rect));
        XCTAssertEqual(rect.writingDirection, stockRects[index].writingDirection);
    }
}

- (void)testPointHitsNeverReturnInsideComposedCharacterCluster {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *text = @"A👩🏽‍💻B";
    IDBlockTextView *view = [self blockViewWithStrings:@[text]
                                                frame:CGRectMake(0, 0, 280, 250)
                                                 font:font];
    [view layoutIfNeeded];
    NSRange emoji = [text rangeOfComposedCharacterSequenceAtIndex:1];
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument
                                               offset:(NSInteger)emoji.location];
    UITextPosition *end = [view positionFromPosition:view.beginningOfDocument
                                             offset:(NSInteger)NSMaxRange(emoji)];
    CGRect startRect = [view caretRectForPosition:start];
    CGRect endRect = [view caretRectForPosition:end];
    XCTAssertTrue(IDParityRectIsFinite(startRect));
    XCTAssertTrue(IDParityRectIsFinite(endRect));

    CGFloat minimumX = MIN(CGRectGetMinX(startRect), CGRectGetMinX(endRect));
    CGFloat maximumX = MAX(CGRectGetMinX(startRect), CGRectGetMinX(endRect));
    for (UITextPosition *boundary in @[start, end]) {
        CGRect boundaryRect = [view caretRectForPosition:boundary];
        UITextPosition *hit = [view closestPositionToPoint:
            CGPointMake(CGRectGetMinX(boundaryRect), CGRectGetMidY(boundaryRect))];
        XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:hit],
                       [view offsetFromPosition:view.beginningOfDocument toPosition:boundary]);
    }
    for (NSUInteger sample = 1; sample < 8; sample += 1) {
        CGFloat x = minimumX + (maximumX - minimumX) * ((CGFloat)sample / 8.0);
        UITextPosition *hit = [view closestPositionToPoint:
            CGPointMake(x, CGRectGetMidY(startRect))];
        NSInteger offset = [view offsetFromPosition:view.beginningOfDocument toPosition:hit];
        XCTAssertTrue(offset == (NSInteger)emoji.location ||
                      offset == (NSInteger)NSMaxRange(emoji), @"offset=%ld", (long)offset);
    }
}

- (void)testVerticalMovementRetainsPreferredXAcrossShortLineAndReturn {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSArray<NSString *> *blocks = @[@"abcdefghijklmno", @"xy", @"abcdefghijklmno"];
    NSString *text = [blocks componentsJoinedByString:@"\n"];
    IDBlockTextView *view = [self blockViewWithStrings:blocks frame:CGRectZero font:font];
    UITextView *stock = [self stockViewWithText:text frame:CGRectZero font:font];
    UIWindow *window = [self hostBlockView:view stockView:stock];
    UITextPosition *customPosition = [view positionFromPosition:view.beginningOfDocument
                                                         offset:12];
    UITextPosition *stockPosition = [stock positionFromPosition:stock.beginningOfDocument
                                                         offset:12];
    NSArray<NSNumber *> *directions = @[
        @(UITextLayoutDirectionDown),
        @(UITextLayoutDirectionDown),
        @(UITextLayoutDirectionUp),
        @(UITextLayoutDirectionUp),
    ];
    NSMutableArray<NSString *> *steps = [@[@"start"] mutableCopy];
    [steps addObjectsFromArray:@[@"down short", @"down return", @"up short", @"up return"]];

    for (NSUInteger step = 0; step <= directions.count; step += 1) {
        CGRect customRect = [self normalizedVisibleRect:[view caretRectForPosition:customPosition]
                                               fromView:view
                                               inWindow:window];
        CGRect stockRect = [self normalizedVisibleRect:[stock caretRectForPosition:stockPosition]
                                              fromView:stock
                                              inWindow:window];
        XCTAssertTrue(IDParityRectIsFinite(customRect), @"%@ %@", steps[step],
                      NSStringFromCGRect(customRect));
        XCTAssertTrue(IDParityRectIsFinite(stockRect), @"%@ %@", steps[step],
                      NSStringFromCGRect(stockRect));
        [self assertRectOrigin:customRect matches:stockRect tolerance:1.0];
        XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument
                                     toPosition:customPosition],
                       [stock offsetFromPosition:stock.beginningOfDocument
                                      toPosition:stockPosition],
                       @"%@ canonical offset", steps[step]);
        if (step == directions.count) break;
        UITextLayoutDirection direction = directions[step].integerValue;
        customPosition = [view positionFromPosition:customPosition
                                        inDirection:direction
                                             offset:1];
        stockPosition = [stock positionFromPosition:stockPosition
                                       inDirection:direction
                                            offset:1];
        XCTAssertNotNil(customPosition, @"%@ custom", steps[step + 1]);
        XCTAssertNotNil(stockPosition, @"%@ stock", steps[step + 1]);
    }
}

- (void)testDirectSelectedTextRangeReplacementResetsPreferredVerticalX {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSArray<NSString *> *blocks = @[@"abcdefghijklmno", @"xy", @"abcdefghijklmno"];
    CGRect frame = CGRectMake(0, 0, 280, 250);
    IDBlockTextView *view = [self blockViewWithStrings:blocks frame:frame font:font];
    [view layoutIfNeeded];
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument offset:12];
    UITextPosition *downOne = [view positionFromPosition:start
                                             inDirection:UITextLayoutDirectionDown
                                                  offset:1];
    view.selectedTextRange = [view textRangeFromPosition:downOne toPosition:downOne];
    UITextPosition *downTwo = [view positionFromPosition:downOne
                                             inDirection:UITextLayoutDirectionDown
                                                  offset:1];

    IDBlockTextView *fresh = [self blockViewWithStrings:blocks frame:frame font:font];
    [fresh layoutIfNeeded];
    NSInteger sourceOffset = [view offsetFromPosition:view.beginningOfDocument
                                           toPosition:downOne];
    UITextPosition *freshSource = [fresh positionFromPosition:fresh.beginningOfDocument
                                                       offset:sourceOffset];
    UITextPosition *freshDown = [fresh positionFromPosition:freshSource
                                                inDirection:UITextLayoutDirectionDown
                                                     offset:1];
    CGRect downTwoRect = [view caretRectForPosition:downTwo];
    CGRect freshDownRect = [fresh caretRectForPosition:freshDown];
    XCTAssertTrue(IDParityRectIsFinite(downTwoRect));
    XCTAssertTrue(IDParityRectIsFinite(freshDownRect));
    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:downTwo],
                   [fresh offsetFromPosition:fresh.beginningOfDocument toPosition:freshDown]);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(downTwoRect),
                               CGRectGetMinX(freshDownRect), 1.0);
}

- (NSRange)canonicalRangeInInput:(id<UITextInput>)input range:(UITextRange *)range {
    if (range == nil) return NSMakeRange(NSNotFound, 0);
    NSInteger location = [input offsetFromPosition:input.beginningOfDocument
                                        toPosition:range.start];
    NSInteger length = [input offsetFromPosition:range.start toPosition:range.end];
    return location < 0 || length < 0
        ? NSMakeRange(NSNotFound, 0)
        : NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (void)testCanonicalRangesWordParagraphAndBoundaryNavigationMatchStock {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSArray<NSString *> *blocks = @[@"alpha beta", @"gamma delta"];
    NSString *text = [blocks componentsJoinedByString:@"\n"];
    IDBlockTextView *custom = [self blockViewWithStrings:blocks
                                                   frame:CGRectMake(0, 0, 280, 250)
                                                    font:font];
    UITextView *stock = [self stockViewWithText:text
                                          frame:CGRectMake(0, 0, 280, 250)
                                           font:font];
    UITextPosition *customPosition = [custom positionFromPosition:custom.beginningOfDocument
                                                           offset:8];
    UITextPosition *stockPosition = [stock positionFromPosition:stock.beginningOfDocument
                                                         offset:8];

    for (NSNumber *granularityValue in @[
        @(UITextGranularityWord), @(UITextGranularityParagraph),
    ]) {
        UITextGranularity granularity = granularityValue.integerValue;
        UITextRange *customRange = [custom.tokenizer rangeEnclosingPosition:customPosition
                                                            withGranularity:granularity
                                                                inDirection:UITextStorageDirectionForward];
        UITextRange *stockRange = [stock.tokenizer rangeEnclosingPosition:stockPosition
                                                          withGranularity:granularity
                                                              inDirection:UITextStorageDirectionForward];
        XCTAssertTrue(NSEqualRanges([self canonicalRangeInInput:custom range:customRange],
                                    [self canonicalRangeInInput:stock range:stockRange]));
    }

    for (NSNumber *granularityValue in @[
        @(UITextGranularityCharacter), @(UITextGranularityWord), @(UITextGranularityLine),
    ]) {
        UITextGranularity granularity = granularityValue.integerValue;
        UITextPosition *customBoundary = [custom.tokenizer
            positionFromPosition:customPosition
                      toBoundary:granularity
                     inDirection:UITextStorageDirectionForward];
        UITextPosition *stockBoundary = [stock.tokenizer
            positionFromPosition:stockPosition
                      toBoundary:granularity
                     inDirection:UITextStorageDirectionForward];
        XCTAssertEqual([custom offsetFromPosition:custom.beginningOfDocument
                                       toPosition:customBoundary],
                       [stock offsetFromPosition:stock.beginningOfDocument
                                      toPosition:stockBoundary]);
    }

    UITextPosition *customStart = [custom positionFromPosition:custom.beginningOfDocument offset:4];
    UITextPosition *customEnd = [custom positionFromPosition:custom.beginningOfDocument offset:14];
    UITextRange *customRange = [custom textRangeFromPosition:customStart toPosition:customEnd];
    XCTAssertEqualObjects([custom textInRange:customRange], [text substringWithRange:NSMakeRange(4, 10)]);
    XCTAssertTrue(NSEqualRanges([self canonicalRangeInInput:custom range:customRange],
                                NSMakeRange(4, 10)));
}

- (void)testNativeStructuralSplitMergeAndUndoPreserveRichAttributeRuns {
    NSAttributedStringKey style = @"IDTask11RichStyle";
    NSMutableAttributedString *rich = [[NSMutableAttributedString alloc]
        initWithString:@"abCD"
            attributes:@{style: @"left"}];
    [rich addAttribute:style value:@"right" range:NSMakeRange(2, 2)];
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 280, 250)
      attributedBlocks:@[rich]];
    UITextPosition *middle = [view positionFromPosition:view.beginningOfDocument offset:2];
    view.selectedTextRange = [view textRangeFromPosition:middle toPosition:middle];

    [view insertText:@"\n"];
    XCTAssertEqual(view.attributedBlocks.count, 2U);
    XCTAssertEqualObjects(view.attributedBlocks[0].string, @"ab");
    XCTAssertEqualObjects(view.attributedBlocks[1].string, @"CD");
    XCTAssertEqualObjects([view.attributedBlocks[0] attribute:style atIndex:1 effectiveRange:NULL],
                          @"left");
    XCTAssertEqualObjects([view.attributedBlocks[1] attribute:style atIndex:0 effectiveRange:NULL],
                          @"right");

    [view.undoManager undo];
    XCTAssertEqual(view.attributedBlocks.count, 1U);
    XCTAssertEqualObjects([view.attributedBlocks[0] attribute:style atIndex:1 effectiveRange:NULL],
                          @"left");
    XCTAssertEqualObjects([view.attributedBlocks[0] attribute:style atIndex:2 effectiveRange:NULL],
                          @"right");

    [view.undoManager redo];
    UITextPosition *secondStart = [view positionFromPosition:view.beginningOfDocument offset:3];
    view.selectedTextRange = [view textRangeFromPosition:secondStart toPosition:secondStart];
    [view deleteBackward];
    XCTAssertEqualObjects(view.text, @"abCD");
    XCTAssertEqualObjects([view.attributedBlocks[0] attribute:style atIndex:1 effectiveRange:NULL],
                          @"left");
    XCTAssertEqualObjects([view.attributedBlocks[0] attribute:style atIndex:2 effectiveRange:NULL],
                          @"right");
    [view.undoManager undo];
    XCTAssertEqualObjects(view.text, @"ab\nCD");
    XCTAssertEqualObjects([view.attributedBlocks[1] attribute:style atIndex:0 effectiveRange:NULL],
                          @"right");
}

- (void)testMarkedTextEditingAndUndoRangesMatchStock {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *text = @"alpha\nbeta";
    IDBlockTextView *custom = [self blockViewWithStrings:@[@"alpha", @"beta"]
                                                   frame:CGRectZero
                                                    font:font];
    UITextView *stock = [self stockViewWithText:text frame:CGRectZero font:font];
    __unused UIWindow *window = [self hostBlockView:custom stockView:stock];
    UITextPosition *customPosition = [custom positionFromPosition:custom.beginningOfDocument
                                                           offset:2];
    UITextPosition *stockPosition = [stock positionFromPosition:stock.beginningOfDocument
                                                         offset:2];
    custom.selectedTextRange = [custom textRangeFromPosition:customPosition
                                                 toPosition:customPosition];
    stock.selectedTextRange = [stock textRangeFromPosition:stockPosition
                                               toPosition:stockPosition];

    [custom setMarkedText:@"XY" selectedRange:NSMakeRange(1, 0)];
    [stock setMarkedText:@"XY" selectedRange:NSMakeRange(1, 0)];
    XCTAssertEqualObjects(custom.text, stock.text);
    XCTAssertTrue(NSEqualRanges([self canonicalRangeInInput:custom range:custom.markedTextRange],
                                [self canonicalRangeInInput:stock range:stock.markedTextRange]));
    XCTAssertTrue(NSEqualRanges([self canonicalRangeInInput:custom
                                                       range:custom.selectedTextRange],
                                [self canonicalRangeInInput:stock
                                                       range:stock.selectedTextRange]));
    [custom unmarkText];
    [stock unmarkText];
    XCTAssertNil(custom.markedTextRange);
    XCTAssertNil(stock.markedTextRange);

    UITextPosition *customStart = [custom positionFromPosition:custom.beginningOfDocument offset:4];
    UITextPosition *customEnd = [custom positionFromPosition:custom.beginningOfDocument offset:8];
    UITextPosition *stockStart = [stock positionFromPosition:stock.beginningOfDocument offset:4];
    UITextPosition *stockEnd = [stock positionFromPosition:stock.beginningOfDocument offset:8];
    [custom replaceRange:[custom textRangeFromPosition:customStart toPosition:customEnd]
                withText:@"Z"];
    [stock replaceRange:[stock textRangeFromPosition:stockStart toPosition:stockEnd]
               withText:@"Z"];
    XCTAssertEqualObjects(custom.text, stock.text);
    XCTAssertTrue(NSEqualRanges([self canonicalRangeInInput:custom
                                                       range:custom.selectedTextRange],
                                [self canonicalRangeInInput:stock
                                                       range:stock.selectedTextRange]));
    XCTAssertEqual(custom.undoManager.canUndo, stock.undoManager.canUndo);
    if (custom.undoManager.canUndo && stock.undoManager.canUndo) {
        [custom.undoManager undo];
        [stock.undoManager undo];
        XCTAssertEqualObjects(custom.text, stock.text);
        XCTAssertTrue(NSEqualRanges([self canonicalRangeInInput:custom
                                                           range:custom.selectedTextRange],
                                    [self canonicalRangeInInput:stock
                                                           range:stock.selectedTextRange]));
    }
}

- (void)testResponderLossCommitsBoundaryMarkedTextLikeStock {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    IDBlockTextView *custom = [self blockViewWithStrings:@[@"alpha", @"beta"]
                                                   frame:CGRectZero
                                                    font:font];
    UITextView *stock = [self stockViewWithText:@"alpha\nbeta"
                                          frame:CGRectZero
                                           font:font];
    __unused UIWindow *window = [self hostBlockView:custom stockView:stock];
    NSUInteger offset = 5;
    UITextPosition *customPosition = [custom
        positionFromPosition:custom.beginningOfDocument
                       offset:(NSInteger)offset];
    UITextPosition *stockPosition = [stock
        positionFromPosition:stock.beginningOfDocument
                       offset:(NSInteger)offset];
    custom.selectedTextRange = [custom
        textRangeFromPosition:customPosition toPosition:customPosition];
    stock.selectedTextRange = [stock
        textRangeFromPosition:stockPosition toPosition:stockPosition];

    XCTAssertTrue([custom becomeFirstResponder]);
    [custom setMarkedText:@"ni" selectedRange:NSMakeRange(2, 0)];
    XCTAssertTrue([custom resignFirstResponder]);
    XCTAssertTrue([stock becomeFirstResponder]);
    [stock setMarkedText:@"ni" selectedRange:NSMakeRange(2, 0)];
    XCTAssertTrue([stock resignFirstResponder]);

    XCTAssertFalse(custom.isFirstResponder);
    XCTAssertFalse(stock.isFirstResponder);
    XCTAssertEqualObjects(custom.text, stock.text);
    XCTAssertEqual(custom.markedTextRange == nil, stock.markedTextRange == nil);
    XCTAssertTrue(NSEqualRanges(
        [self canonicalRangeInInput:custom range:custom.selectedTextRange],
        [self canonicalRangeInInput:stock range:stock.selectedTextRange]));
}

- (CGRect)expandedSpellingROIForLength:(NSUInteger)length input:(id<UITextInput>)input {
    UITextPosition *end = [input positionFromPosition:input.beginningOfDocument
                                               offset:(NSInteger)length];
    UITextRange *range = [input textRangeFromPosition:input.beginningOfDocument
                                           toPosition:end];
    return CGRectIntersection(CGRectInset([input firstRectForRange:range], -3, -5),
                              ((UIView *)input).bounds);
}

- (NSArray<NSNumber *> *)nonemptyRedRows:(NSArray<NSNumber *> *)counts {
    NSMutableArray<NSNumber *> *rows = [NSMutableArray array];
    [counts enumerateObjectsUsingBlock:^(NSNumber *count,
                                         NSUInteger index,
                                         BOOL *stop) {
        if (count.unsignedIntegerValue > 0) {
            [rows addObject:@(index)];
        }
    }];
    return rows.copy;
}

- (void)attachSpellingImage:(UIImage *)image name:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithImage:image];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testReferenceBackendUsesMarkerFreeProjectSurfaces {
    IDBlockTextView *view = [self blockViewWithStrings:@[@"reference surface"]
                                                frame:CGRectMake(0, 0, 260, 140)
                                                 font:[UIFont systemFontOfSize:17.0]];

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

- (void)testNativeSpellingPixelCountsMatchStockInCanonicalWordROI {
    if (!IDAssertEnglishCheckerAvailable(self)) return;
    UIFont *font = [UIFont systemFontOfSize:17.0];
    IDBlockTextView *custom = [self blockViewWithStrings:@[@""]
                                                   frame:CGRectZero
                                                    font:font];
    UITextView *stock = [self stockViewWithText:@"" frame:CGRectZero font:font];
    __unused UIWindow *window = [self hostBlockView:custom stockView:stock];
    custom.backgroundColor = UIColor.whiteColor;
    custom.textColor = UIColor.blackColor;
    custom.contentInset = UIEdgeInsetsZero;
    custom.contentScaleFactor = UIScreen.mainScreen.scale;
    custom.spellCheckingType = UITextSpellCheckingTypeYes;
    custom.autocorrectionType = UITextAutocorrectionTypeNo;
    custom.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    stock.backgroundColor = UIColor.whiteColor;
    stock.textColor = UIColor.blackColor;
    stock.contentInset = UIEdgeInsetsZero;
    stock.contentScaleFactor = UIScreen.mainScreen.scale;
    stock.spellCheckingType = UITextSpellCheckingTypeYes;
    stock.autocorrectionType = UITextAutocorrectionTypeNo;
    stock.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;

    XCTAssertTrue([stock becomeFirstResponder]);
    [stock insertText:@"mispelled "];
    __block UIImage *stockImage = nil;
    __block NSUInteger stockRed = 0;
    __block NSUInteger previousStockRed = NSUIntegerMax;
    __block NSUInteger stableStockSamples = 0;
    XCTAssertTrue(IDWaitForCondition(5.0, ^BOOL{
        [stock setNeedsLayout];
        [stock layoutIfNeeded];
        stockImage = IDRenderView(stock);
        stockRed = IDCountRedPixels(stockImage,
            [self expandedSpellingROIForLength:9 input:stock]);
        stableStockSamples =
            stockRed > 0 && stockRed == previousStockRed
                ? stableStockSamples + 1
                : 0;
        previousStockRed = stockRed;
        return stableStockSamples >= 1;
    }));
    CGRect stockFirstRect =
        [stock firstRectForRange:[stock textRangeFromPosition:stock.beginningOfDocument
                                                   toPosition:[stock
            positionFromPosition:stock.beginningOfDocument offset:9]]];
    CGRect stockROI = [self expandedSpellingROIForLength:9 input:stock];
    NSArray<NSNumber *> *stockRows =
        IDRedPixelCountsByRow(stockImage, stockROI);
    [self attachSpellingImage:stockImage name:@"spelling-stock"];
    IDAttachSpellingObservation(self, @"block-parity-stock", @{
        @"role": @"stock",
        @"text": stock.text ?: @"",
        @"wordRange": @{ @"location": @0, @"length": @9 },
        @"firstRect": NSStringFromCGRect(stockFirstRect),
        @"roi": NSStringFromCGRect(stockROI),
        @"redTotal": @(stockRed),
        @"redRows": stockRows,
        @"temporaryRenderingAttributesObserved": @(stockRed > 0),
    }, stockImage);
    [stock resignFirstResponder];

    XCTAssertTrue([custom becomeFirstResponder]);
    IDPrivateSetContinuousSpellCheckingEnabled(custom.id_inputController, YES);
    [custom insertText:@"mispelled "];
    __block UIImage *customImage = nil;
    __block NSUInteger customRed = 0;
    __block NSUInteger previousCustomRed = NSUIntegerMax;
    __block NSUInteger stableCustomSamples = 0;
    XCTAssertTrue(IDWaitForCondition(5.0, ^BOOL{
        [custom setNeedsLayout];
        [custom layoutIfNeeded];
        customImage = IDRenderView(custom);
        customRed = IDCountRedPixels(customImage,
            [self expandedSpellingROIForLength:9 input:custom]);
        stableCustomSamples =
            customRed > 0 && customRed == previousCustomRed
                ? stableCustomSamples + 1
                : 0;
        previousCustomRed = customRed;
        return stableCustomSamples >= 1;
    }));
    CGRect customFirstRect =
        [custom firstRectForRange:[custom textRangeFromPosition:custom.beginningOfDocument
                                                     toPosition:[custom
            positionFromPosition:custom.beginningOfDocument offset:9]]];
    CGRect customROI = [self expandedSpellingROIForLength:9 input:custom];
    NSArray<NSNumber *> *customRows =
        IDRedPixelCountsByRow(customImage, customROI);
    UITextPosition *customWordEnd =
        [custom positionFromPosition:custom.beginningOfDocument offset:9];
    UITextRange *customWord =
        [custom textRangeFromPosition:custom.beginningOfDocument
                           toPosition:customWordEnd];
    NSAttributedString *customAnnotated =
        [custom.id_richLayoutController id_annotatedSubstringForRange:customWord];
    IDBlockLayout *customLayout = custom.id_blockStack.blockLayouts.firstObject;
    NSTextLayoutFragment *customFragment =
        customLayout.canvasView.visibleFragments.firstObject;
    IDTextRenderingSurfaceView *customSurface =
        (id)customLayout.canvasView.visibleSurfaces.firstObject;
    NSUInteger customSurfaceCount = 0;
    for (IDBlockLayout *layout in custom.id_blockStack.blockLayouts) {
        for (UIView *surface in layout.canvasView.visibleSurfaces) {
            customSurfaceCount += 1;
            XCTAssertEqual(surface.class, IDTextRenderingSurfaceView.class);
            XCTAssertFalse([surface respondsToSelector:
                NSSelectorFromString(@"isLayoutFragmentView")]);
        }
    }
    XCTAssertGreaterThan(customSurfaceCount, 0U);
    [self attachSpellingImage:customImage name:@"spelling-custom"];
    IDAttachSpellingObservation(self, @"block-parity-custom", @{
        @"role": @"custom",
        @"text": custom.text ?: @"",
        @"wordRange": @{ @"location": @0, @"length": @9 },
        @"firstRect": NSStringFromCGRect(customFirstRect),
        @"roi": NSStringFromCGRect(customROI),
        @"redTotal": @(customRed),
        @"redRows": customRows,
        @"temporaryRenderingAttributesObserved": @(customAnnotated.length > 0),
    }, customImage);
    [custom resignFirstResponder];

    NSDictionary *diagnostics = @{
        @"custom": @{
            @"text": custom.text ?: @"",
            @"selection": NSStringFromRange(
                [self canonicalRangeInInput:custom range:custom.selectedTextRange]),
            @"wordRange": NSStringFromRange(NSMakeRange(0, 9)),
            @"firstRect": NSStringFromCGRect(customFirstRect),
            @"roi": NSStringFromCGRect(customROI),
            @"redTotal": @(customRed),
            @"redRows": customRows,
            @"nonemptyRows": [self nonemptyRedRows:customRows],
            @"annotatedAttributesAt0":
                customAnnotated.length > 0
                    ? [customAnnotated attributesAtIndex:0 effectiveRange:NULL].description
                    : @"",
            @"annotatedAttributesAt8":
                customAnnotated.length > 8
                    ? [customAnnotated attributesAtIndex:8 effectiveRange:NULL].description
                    : @"",
            @"fragmentFrame": customFragment == nil
                ? @"nil"
                : NSStringFromCGRect(customFragment.layoutFragmentFrame),
            @"renderingSurfaceBounds": customFragment == nil
                ? @"nil"
                : NSStringFromCGRect(customFragment.renderingSurfaceBounds),
            @"canvasFrame": NSStringFromCGRect(customLayout.canvasView.frame),
            @"canvasBounds": NSStringFromCGRect(customLayout.canvasView.bounds),
            @"surfaceClass": customSurface == nil
                ? @"nil"
                : NSStringFromClass(customSurface.class),
            @"surfaceFrame": customSurface == nil
                ? @"nil"
                : NSStringFromCGRect(customSurface.frame),
            @"surfaceBounds": customSurface == nil
                ? @"nil"
                : NSStringFromCGRect(customSurface.bounds),
            @"surfaceClipRect": customSurface == nil
                ? @"nil"
                : NSStringFromCGRect(customSurface.clipRect),
        },
        @"stock": @{
            @"text": stock.text ?: @"",
            @"selection": NSStringFromRange(
                [self canonicalRangeInInput:stock range:stock.selectedTextRange]),
            @"wordRange": NSStringFromRange(NSMakeRange(0, 9)),
            @"firstRect": NSStringFromCGRect(stockFirstRect),
            @"roi": NSStringFromCGRect(stockROI),
            @"redTotal": @(stockRed),
            @"redRows": stockRows,
            @"nonemptyRows": [self nonemptyRedRows:stockRows],
        },
    };
    NSData *diagnosticData =
        [NSJSONSerialization dataWithJSONObject:diagnostics
                                        options:NSJSONWritingPrettyPrinted
                                          error:NULL];
    XCTAttachment *diagnosticAttachment =
        [XCTAttachment attachmentWithData:diagnosticData
                       uniformTypeIdentifier:@"public.json"];
    diagnosticAttachment.name = @"spelling-diagnostics";
    diagnosticAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:diagnosticAttachment];
    NSLog(@"IDSpellingParityDiagnostic %@",
          [[NSString alloc] initWithData:diagnosticData
                               encoding:NSUTF8StringEncoding]);

    XCTAssertGreaterThan(customRed, 0U);
    XCTAssertGreaterThan(stockRed, 0U);
    XCTAssertEqualWithAccuracy((double)customRed, (double)stockRed, 12.0);
}

- (void)testPublicLiveRangeRebasesWhileNativeSnapshotRangeStaysAtOriginalOffsets {
    IDBlockTextView *view = [self blockViewWithStrings:@[@"alpha", @"beta"]
                                                frame:CGRectMake(0, 0, 280, 250)
                                                 font:[UIFont systemFontOfSize:17.0]];
    IDRichTextLayoutController *controller = view.id_richLayoutController;
    IDRichTextRange *live = [controller rangeForCanonicalRange:NSMakeRange(2, 5)];
    IDRichTextRange *snapshot = [controller id_nativeRangeForCanonicalRange:NSMakeRange(2, 5)];

    [view.id_textStorageAdapter replaceCharactersInRange:NSMakeRange(0, 0) withString:@"XY"];
    [view id_reconcileDerivedState];

    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:live clipped:NO],
                                NSMakeRange(4, 5)));
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:snapshot clipped:NO],
                                NSMakeRange(2, 5)));
    XCTAssertEqualObjects([view textInRange:(UITextRange *)live], @"pha\nb");
    XCTAssertEqualObjects([view textInRange:(UITextRange *)snapshot], @"alpha");
}


// UIKit's text-choice assistant places an accepted autocorrection's underline at the selection
// rect's private `baselineOffset`, which the base class initialises to infinity and falls back
// from only when it reads 0. The engine's rects must therefore answer it with the line's real
// baseline — the same one UITextView's rects carry — or the underline lands at y = infinity.
- (void)testSelectionRectsReportTheSameBaselineOffsetAsUITextView {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *first = @"one two three four";
    NSString *second = @"five six seven";
    NSString *text = [NSString stringWithFormat:@"%@\n%@", first, second];
    IDBlockTextView *blockView = [self blockViewWithStrings:@[first, second]
                                                     frame:CGRectZero
                                                      font:font];
    UITextView *stockView = [self stockViewWithText:text frame:CGRectZero font:font];
    [self hostBlockView:blockView stockView:stockView];
    SEL baselineSelector = NSSelectorFromString(@"baselineOffset");
    NSArray<NSValue *> *selections = @[
        [NSValue valueWithRange:NSMakeRange(4, 3)],
        [NSValue valueWithRange:NSMakeRange(first.length + 1, 4)],
    ];
    for (NSValue *value in selections) {
        NSRange selection = value.rangeValue;
        UITextPosition *blockStart = [blockView positionFromPosition:blockView.beginningOfDocument
                                                             offset:(NSInteger)selection.location];
        UITextPosition *blockEnd = [blockView positionFromPosition:blockView.beginningOfDocument
                                                           offset:(NSInteger)NSMaxRange(selection)];
        UITextPosition *stockStart = [stockView positionFromPosition:stockView.beginningOfDocument
                                                             offset:(NSInteger)selection.location];
        UITextPosition *stockEnd = [stockView positionFromPosition:stockView.beginningOfDocument
                                                           offset:(NSInteger)NSMaxRange(selection)];
        NSArray<UITextSelectionRect *> *blockRects = [blockView selectionRectsForRange:
            [blockView textRangeFromPosition:blockStart toPosition:blockEnd]];
        NSArray<UITextSelectionRect *> *stockRects = [stockView selectionRectsForRange:
            [stockView textRangeFromPosition:stockStart toPosition:stockEnd]];
        XCTAssertEqual(blockRects.count, 1U, @"%@", NSStringFromRange(selection));
        XCTAssertEqual(stockRects.count, 1U, @"%@", NSStringFromRange(selection));
        if (blockRects.count != 1 || stockRects.count != 1) continue;
        XCTAssertTrue([blockRects[0] respondsToSelector:baselineSelector]);
        XCTAssertTrue([stockRects[0] respondsToSelector:baselineSelector]);
        CGFloat blockBaseline =
            ((CGFloat (*)(id, SEL))objc_msgSend)(blockRects[0], baselineSelector);
        CGFloat stockBaseline =
            ((CGFloat (*)(id, SEL))objc_msgSend)(stockRects[0], baselineSelector);
        XCTAssertTrue(isfinite(blockBaseline), @"%@ -> %g", NSStringFromRange(selection), blockBaseline);
        XCTAssertTrue(isfinite(stockBaseline), @"%@ -> %g", NSStringFromRange(selection), stockBaseline);
        XCTAssertGreaterThan(blockBaseline, 0.0);
        XCTAssertLessThan(blockBaseline, CGRectGetHeight(blockRects[0].rect));
        XCTAssertEqualWithAccuracy(blockBaseline, stockBaseline, 1.0,
                                   @"%@", NSStringFromRange(selection));
        XCTAssertEqualWithAccuracy(blockBaseline, font.ascender, 1.0,
                                   @"%@", NSStringFromRange(selection));
    }
}


// The value UIKit itself stamps: `-[UITextInputController selectionRectsForRange:]` asks the
// layout controller's `requestTextGeometryAtPosition:typingAttributes:resultBlock:` for the
// range's end and writes the block's baseline into every rect's `_baselineOffset`. The engine's
// block used to be invoked with the rect alone, so the stamped value was an unset register.
- (void)testTheControllerStampsTheSameBaselineOnTheEnginesRectsAsOnUITextViews {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSString *first = @"one two three four";
    NSString *second = @"five six seven";
    NSString *text = [NSString stringWithFormat:@"%@\n%@", first, second];
    IDBlockTextView *blockView = [self blockViewWithStrings:@[first, second]
                                                     frame:CGRectZero
                                                      font:font];
    UITextView *stockView = [self stockViewWithText:text frame:CGRectZero font:font];
    [self hostBlockView:blockView stockView:stockView];
    Ivar ivar = class_getInstanceVariable(UITextSelectionRect.class, "_baselineOffset");
    XCTAssertTrue(ivar != NULL);
    if (ivar == NULL) return;
    ptrdiff_t ivarOffset = ivar_getOffset(ivar);
    NSRange selection = NSMakeRange(first.length + 1, 4);
    UITextPosition *blockStart = [blockView positionFromPosition:blockView.beginningOfDocument
                                                         offset:(NSInteger)selection.location];
    UITextPosition *blockEnd = [blockView positionFromPosition:blockView.beginningOfDocument
                                                       offset:(NSInteger)NSMaxRange(selection)];
    UITextPosition *stockStart = [stockView positionFromPosition:stockView.beginningOfDocument
                                                         offset:(NSInteger)selection.location];
    UITextPosition *stockEnd = [stockView positionFromPosition:stockView.beginningOfDocument
                                                       offset:(NSInteger)NSMaxRange(selection)];
    NSArray<UITextSelectionRect *> *blockRects = [blockView selectionRectsForRange:
        [blockView textRangeFromPosition:blockStart toPosition:blockEnd]];
    NSArray<UITextSelectionRect *> *stockRects = [stockView selectionRectsForRange:
        [stockView textRangeFromPosition:stockStart toPosition:stockEnd]];
    XCTAssertEqual(blockRects.count, 1U);
    XCTAssertEqual(stockRects.count, 1U);
    if (blockRects.count != 1 || stockRects.count != 1) return;
    CGFloat blockStamped = *(CGFloat *)((uint8_t *)(__bridge void *)blockRects[0] + ivarOffset);
    CGFloat stockStamped = *(CGFloat *)((uint8_t *)(__bridge void *)stockRects[0] + ivarOffset);
    XCTAssertTrue(isfinite(blockStamped), @"%g", blockStamped);
    XCTAssertTrue(isfinite(stockStamped), @"%g", stockStamped);
    XCTAssertEqualWithAccuracy(blockStamped, stockStamped, 1.0);
    XCTAssertEqualWithAccuracy(blockStamped, font.ascender, 1.0);
}

// A stock UITextView's selection container and its `-textInputView` are ONE coordinate space,
// whatever the scroll offset. UIKit relies on that twice over for the autocorrection prompt: it
// converts the word's selection rect INTO the container (where the underline view lives) with
// `-[_UITextChoiceAccelerationAssistant convertedSelectionRect:]`, and then hands those same numbers
// to the bubble as `presentedFromRect:` alongside `referenceTextView:` = `-textInputView`, which
// reads them relative to the text input view. While the engine's container tracked the VIEWPORT
// instead of the block stack, the prompt for an autocorrected word came up one content offset below
// the word it belongs to (device, K3 2026-09-11: word at window y 269.3, prompt at 337.3, the
// editor's 68pt top inset).
- (void)testTheSelectionContainerSharesTheTextInputViewsCoordinateSpaceLikeUITextViewDoes {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    NSArray<NSString *> *strings = @[@"one two three", @"four five six", @"seven eight nine",
                                     @"ten eleven twelve", @"thirteen fourteen"];
    IDBlockTextView *blockView = [self blockViewWithStrings:strings frame:CGRectZero font:font];
    UITextView *stockView = [self stockViewWithText:[strings componentsJoinedByString:@"\n"]
                                              frame:CGRectZero
                                               font:font];
    UIWindow *window = [self hostBlockView:blockView stockView:stockView];
    (void)window;
    for (UIScrollView *view in @[blockView, stockView]) {
        view.contentInset = UIEdgeInsetsMake(60, 0, 0, 0);
        view.contentOffset = CGPointMake(0, -60);
        [view layoutIfNeeded];
    }
    SEL containerSelector = NSSelectorFromString(@"selectionContainerView");
    SEL inputSelector = NSSelectorFromString(@"textInputView");
    UIView *blockContainer = ((id (*)(id, SEL))objc_msgSend)(blockView, containerSelector);
    UIView *stockContainer = ((id (*)(id, SEL))objc_msgSend)(stockView, containerSelector);
    UIView *blockInput = ((id (*)(id, SEL))objc_msgSend)(blockView, inputSelector);
    UIView *stockInput = ((id (*)(id, SEL))objc_msgSend)(stockView, inputSelector);
    XCTAssertNotNil(blockContainer);
    XCTAssertNotNil(stockContainer);
    XCTAssertNotNil(blockInput);
    XCTAssertNotNil(stockInput);
    XCTAssertEqualWithAccuracy(blockView.contentOffset.y, -60.0, 0.5);
    CGPoint stockOrigin = [stockContainer convertPoint:CGPointZero toView:stockInput];
    CGPoint blockOrigin = [blockContainer convertPoint:CGPointZero toView:blockInput];
    XCTAssertTrue(CGPointEqualToPoint(stockOrigin, CGPointZero),
                  @"%@", NSStringFromCGPoint(stockOrigin));
    XCTAssertTrue(CGPointEqualToPoint(blockOrigin, stockOrigin),
                  @"engine %@ against stock %@", NSStringFromCGPoint(blockOrigin),
                  NSStringFromCGPoint(stockOrigin));
}

/// Whatever stock highlights, this editor highlights — swept over every range of documents that
/// contain empty paragraphs.
///
/// The bug this pins: a selection whose boundary lands on a paragraph break produced NO visible
/// selection at all. An empty line has exactly one offset, so every selection that touches one is
/// bounded by a separator — which is why it was reported as "the selection is invisible if one of
/// the selected lines is empty" rather than as the more general rule it is. The two-paragraph
/// document is in the sweep for that reason: `alpha|beta` selected 0..6 was equally dead, and a
/// test written only against empty lines would have left half the defect in place (2026-09-15).
///
/// The assertion is deliberately coarse — is anything drawn, and is it drawable — because the
/// decomposition into rects is legitimately ours to choose: this editor answers per block, stock
/// answers per line fragment. Where the rects themselves must agree, the tests above compare them
/// directly.
- (void)testEverySelectionStockHighlightsIsHighlightedHereToo {
    NSArray<NSArray<NSString *> *> *documents = @[
        @[@"alpha", @"beta"],
        @[@"alpha", @""],
        @[@"", @"beta"],
        @[@"alpha", @"", @"beta"],
        @[@"alpha", @"", @"", @"beta"],
    ];
    UIFont *font = [UIFont systemFontOfSize:17.0];
    for (NSArray<NSString *> *strings in documents) {
        NSString *text = [strings componentsJoinedByString:@"\n"];
        IDBlockTextView *blockView = [self blockViewWithStrings:strings
                                                          frame:CGRectZero
                                                           font:font];
        UITextView *stockView = [self stockViewWithText:text frame:CGRectZero font:font];
        __unused UIWindow *window = [self hostBlockView:blockView stockView:stockView];
        NSString *label = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"|"];
        for (NSUInteger from = 0; from <= text.length; from += 1) {
            for (NSUInteger to = from + 1; to <= text.length; to += 1) {
                CGFloat blockArea = [self highlightedAreaIn:blockView from:from to:to
                                                      label:label];
                CGFloat stockArea = [self highlightedAreaIn:stockView from:from to:to
                                                      label:label];
                if (stockArea <= 0.5) continue;
                XCTAssertGreaterThan(blockArea, 0.5,
                                     @"%@ selected %lu..%lu draws nothing while stock draws %.0f",
                                     label, (unsigned long)from, (unsigned long)to, stockArea);
            }
        }
    }
}

/// The area of the selection rects a text input vends for `from..to`, and 0 when it vends none.
/// A non-finite rect fails on the spot: UIKit takes it as drawable and the selection lands at
/// infinity, which is invisible in a way that reads exactly like no selection at all.
- (CGFloat)highlightedAreaIn:(UIView<UITextInput> *)input
                        from:(NSUInteger)from
                          to:(NSUInteger)to
                       label:(NSString *)label {
    UITextRange *range = [input
        textRangeFromPosition:[input positionFromPosition:input.beginningOfDocument
                                                   offset:(NSInteger)from]
                   toPosition:[input positionFromPosition:input.beginningOfDocument
                                                   offset:(NSInteger)to]];
    CGFloat area = 0.0;
    for (UITextSelectionRect *selectionRect in [input selectionRectsForRange:range]) {
        XCTAssertTrue(IDParityRectIsFinite(selectionRect.rect),
                      @"%@ selected %lu..%lu vended %@", label, (unsigned long)from,
                      (unsigned long)to, NSStringFromCGRect(selectionRect.rect));
        if (!IDParityRectIsFinite(selectionRect.rect)) continue;
        area += CGRectGetWidth(selectionRect.rect) * CGRectGetHeight(selectionRect.rect);
    }
    return area;
}

@end
