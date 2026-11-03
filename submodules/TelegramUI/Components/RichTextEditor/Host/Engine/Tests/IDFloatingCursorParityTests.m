@import XCTest;

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDBlockDocument.h"
#import "IDBlockStackCanvasView.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextPosition.h"

#import <objc/message.h>

static CGRect IDFloatingCursorUnionSelectionRects(NSArray<UITextSelectionRect *> *rects) {
    CGRect result = CGRectNull;
    for (UITextSelectionRect *rect in rects) {
        result = CGRectIsNull(result) ? rect.rect : CGRectUnion(result, rect.rect);
    }
    return result;
}

static BOOL IDFloatingCursorIsComposedCharacterBoundary(NSString *text,
                                                         NSUInteger offset) {
    if (offset == 0 || offset == text.length) return YES;
    if (offset > text.length) return NO;
    return [text rangeOfComposedCharacterSequenceAtIndex:offset].location == offset;
}

@interface IDFloatingCursorParityTests : XCTestCase
@end

@implementation IDFloatingCursorParityTests

- (void)assertFloatingFixtureBlocks:(NSArray<NSString *> *)strings
                    canonicalStops:(NSArray<NSNumber *> *)canonicalStops
                        anchorOffset:(NSUInteger)anchorOffset {
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    id stockController = ((id (*)(id, SEL))objc_msgSend)(
        stock, NSSelectorFromString(@"_internalTextLayoutController"));
    id customController = custom.id_richLayoutController;
    SEL positionSelector = NSSelectorFromString(@"positionWithOffset:affinity:");
    SEL affinitySelector = NSSelectorFromString(@"affinityForPosition:");
    XCTAssertTrue([stockController respondsToSelector:positionSelector]);
    XCTAssertTrue([stockController respondsToSelector:affinitySelector]);
    XCTAssertTrue([customController respondsToSelector:positionSelector]);
    XCTAssertTrue([customController respondsToSelector:affinitySelector]);
    UITextPosition *stockAnchor = ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
        stockController, positionSelector, (NSInteger)anchorOffset,
        (NSInteger)UITextStorageDirectionForward);
    UITextPosition *customAnchor = ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
        customController, positionSelector, (NSInteger)anchorOffset,
        (NSInteger)UITextStorageDirectionForward);
    XCTAssertNotNil(stockAnchor);
    XCTAssertNotNil(customAnchor);

    for (NSNumber *stop in canonicalStops) {
        for (NSNumber *affinityValue in @[
            @(UITextStorageDirectionBackward), @(UITextStorageDirectionForward)]) {
            NSInteger offset = stop.integerValue;
            NSInteger requestedAffinity = affinityValue.integerValue;
            UITextPosition *stockPosition =
                ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
                    stockController, positionSelector, offset, requestedAffinity);
            UITextPosition *customPosition =
                ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
                    customController, positionSelector, offset, requestedAffinity);
            XCTAssertNotNil(stockPosition, @"offset=%ld affinity=%ld",
                            (long)offset, (long)requestedAffinity);
            XCTAssertNotNil(customPosition, @"offset=%ld affinity=%ld",
                            (long)offset, (long)requestedAffinity);
            NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                                   toPosition:stockPosition];
            NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                     toPosition:customPosition];
            XCTAssertEqual(customOffset, stockOffset, @"offset=%ld affinity=%ld",
                           (long)offset, (long)requestedAffinity);
            NSInteger stockAffinity = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                stockController, affinitySelector, stockPosition);
            NSInteger customAffinity = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                customController, affinitySelector, customPosition);
            XCTAssertEqual(customAffinity, stockAffinity, @"offset=%ld affinity=%ld",
                           (long)offset, (long)requestedAffinity);
            XCTAssertEqual([custom comparePosition:customPosition toPosition:customAnchor],
                           [stock comparePosition:stockPosition toPosition:stockAnchor],
                           @"offset=%ld affinity=%ld", (long)offset,
                           (long)requestedAffinity);
            CGRect stockCaret = [stock caretRectForPosition:stockPosition];
            CGRect customCaret = [custom caretRectForPosition:customPosition];
            XCTAssertEqualWithAccuracy(CGRectGetMinX(customCaret),
                                       CGRectGetMinX(stockCaret), 0.5,
                                       @"offset=%ld affinity=%ld stock=%@ custom=%@",
                                       (long)offset, (long)requestedAffinity,
                                       NSStringFromCGRect(stockCaret),
                                       NSStringFromCGRect(customCaret));
            XCTAssertEqualWithAccuracy(CGRectGetMinY(customCaret),
                                       CGRectGetMinY(stockCaret), 0.5,
                                       @"offset=%ld affinity=%ld stock=%@ custom=%@",
                                       (long)offset, (long)requestedAffinity,
                                       NSStringFromCGRect(stockCaret),
                                       NSStringFromCGRect(customCaret));
        }

        UITextPosition *stockCapturePosition =
            ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
                stockController, positionSelector, stop.integerValue,
                (NSInteger)UITextStorageDirectionForward);
        CGRect stockCaptureCaret = [stock caretRectForPosition:stockCapturePosition];
        CGPoint center = CGPointMake(CGRectGetMidX(stockCaptureCaret),
                                     CGRectGetMidY(stockCaptureCaret));
        for (NSNumber *deltaX in @[@-0.25, @0.25]) {
            CGPoint point = CGPointMake(center.x + deltaX.doubleValue, center.y);
            UITextPosition *stockPosition = [stock closestPositionToPoint:point];
            UITextPosition *customPosition = [custom closestPositionToPoint:point];
            NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                                   toPosition:stockPosition];
            NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                     toPosition:customPosition];
            NSInteger stockAffinity = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                stockController, affinitySelector, stockPosition);
            NSInteger customAffinity = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                customController, affinitySelector, customPosition);
            XCTAssertEqual(customOffset, stockOffset, @"capturedPoint=%@ stop=%@",
                           NSStringFromCGPoint(point), stop);
            XCTAssertEqual(customAffinity, stockAffinity,
                           @"capturedPoint=%@ stop=%@", NSStringFromCGPoint(point), stop);
            XCTAssertEqual([custom comparePosition:customPosition toPosition:customAnchor],
                           [stock comparePosition:stockPosition toPosition:stockAnchor],
                           @"capturedPoint=%@ stop=%@", NSStringFromCGPoint(point), stop);
            CGRect stockCaret = [stock caretRectForPosition:stockPosition];
            CGRect customCaret = [custom caretRectForPosition:customPosition];
            XCTAssertEqualWithAccuracy(CGRectGetMinX(customCaret),
                                       CGRectGetMinX(stockCaret), 0.5);
            XCTAssertEqualWithAccuracy(CGRectGetMinY(customCaret),
                                       CGRectGetMinY(stockCaret), 0.5);
        }
    }
}

- (void)testFloatingCursorFixtureGeometryMapsHorizontalAndVerticalPointsLikeStock {
    NSArray<NSString *> *strings = @[
        @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
        @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
        @"Third paragraph provides a stable lower destination without leaving the viewport.",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string
            attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor}]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(24, 24)],
        [NSValue valueWithCGPoint:CGPointMake(48, 24)],
        [NSValue valueWithCGPoint:CGPointMake(72, 42)],
    ];
    for (NSValue *value in points) {
        UITextPosition *customPosition = [custom closestPositionToPoint:value.CGPointValue];
        UITextPosition *stockPosition = [stock closestPositionToPoint:value.CGPointValue];
        NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                 toPosition:customPosition];
        NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                               toPosition:stockPosition];
        XCTAssertEqual(customOffset, stockOffset, @"point=%@", value);
    }
    UIView *firstContainer = [custom.id_selectionPresentationBackend id_selectionContainerView];
    UIView *secondContainer = [custom.id_selectionPresentationBackend id_selectionContainerView];
    XCTAssertEqual(firstContainer, secondContainer);
    XCTAssertEqual(custom.id_selectionPresentationBackend.selectionContainerCreationCount, 1U);
}

- (void)testSelectionExtensionCapturedHorizontalPointsMatchPositionAffinityAndGeometry {
    NSArray<NSString *> *strings = @[
        @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
        @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
        @"Third paragraph provides a stable lower destination without leaving the viewport.",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    UITextPosition *stockAnchor = [stock positionFromPosition:stock.beginningOfDocument offset:46];
    UITextPosition *customAnchor =
        [custom positionFromPosition:custom.beginningOfDocument offset:46];
    CGRect anchorCaret = [stock caretRectForPosition:stockAnchor];
    CGPoint anchorPoint = CGPointMake(CGRectGetMidX(anchorCaret), CGRectGetMidY(anchorCaret));
    NSArray<NSValue *> *capturedDeltas = @[
        [NSValue valueWithCGPoint:CGPointZero],
        [NSValue valueWithCGPoint:CGPointMake(-21.41, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(-34.51, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(-48.0, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(-31.33, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(-14.67, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(2.0, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(18.67, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(35.33, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(52.0, 0.0)],
    ];
    id stockController = ((id (*)(id, SEL))objc_msgSend)(
        stock, NSSelectorFromString(@"_internalTextLayoutController"));
    SEL affinitySelector = NSSelectorFromString(@"affinityForPosition:");
    XCTAssertNotNil(stockController);
    XCTAssertTrue([stockController respondsToSelector:affinitySelector]);

    for (NSValue *deltaValue in capturedDeltas) {
        CGPoint delta = deltaValue.CGPointValue;
        CGPoint point = CGPointMake(anchorPoint.x + delta.x, anchorPoint.y + delta.y);
        UITextPosition *stockPosition = [stock closestPositionToPoint:point];
        UITextPosition *customPosition = [custom closestPositionToPoint:point];
        NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                               toPosition:stockPosition];
        NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                 toPosition:customPosition];
        XCTAssertEqual(customOffset, stockOffset, @"point=%@", NSStringFromCGPoint(point));
        NSInteger stockAffinity = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
            stockController, affinitySelector, stockPosition);
        NSInteger customAffinity =
            [custom.id_richLayoutController id_affinityForPosition:customPosition];
        XCTAssertEqual(customAffinity, stockAffinity, @"point=%@", NSStringFromCGPoint(point));
        XCTAssertEqual([custom comparePosition:customPosition toPosition:customAnchor],
                       [stock comparePosition:stockPosition toPosition:stockAnchor],
                       @"point=%@", NSStringFromCGPoint(point));

        CGRect stockCaret = [stock caretRectForPosition:stockPosition];
        CGRect customCaret = [custom caretRectForPosition:customPosition];
        XCTAssertEqualWithAccuracy(customCaret.origin.x, stockCaret.origin.x, 0.5);
        XCTAssertEqualWithAccuracy(customCaret.origin.y, stockCaret.origin.y, 0.5);
        XCTAssertEqualWithAccuracy(customCaret.size.width, stockCaret.size.width, 0.5);
        XCTAssertEqualWithAccuracy(customCaret.size.height, stockCaret.size.height, 0.5);
        if (stockOffset == 46) continue;
        UITextRange *stockRange = [stock textRangeFromPosition:stockAnchor
                                                    toPosition:stockPosition];
        UITextRange *customRange = [custom textRangeFromPosition:customAnchor
                                                      toPosition:customPosition];
        CGRect stockSelection = IDFloatingCursorUnionSelectionRects(
            [stock selectionRectsForRange:stockRange]);
        CGRect customSelection = IDFloatingCursorUnionSelectionRects(
            [custom selectionRectsForRange:customRange]);
        if (CGRectIsNull(stockSelection)) {
            XCTAssertTrue(CGRectIsNull(customSelection));
        } else {
            XCTAssertEqualWithAccuracy(customSelection.origin.x, stockSelection.origin.x, 1.0);
            XCTAssertEqualWithAccuracy(customSelection.origin.y, stockSelection.origin.y, 1.0);
            XCTAssertEqualWithAccuracy(customSelection.size.width, stockSelection.size.width, 1.0);
            XCTAssertEqualWithAccuracy(customSelection.size.height, stockSelection.size.height, 1.0);
        }
    }
}

- (void)testFloatingCursorStructuralBoundaryStopsMatchStockOffsetAffinityOrderAndGeometry {
    [self assertFloatingFixtureBlocks:@[
        @"alpha beta omega",
        @"delta epsilon zeta",
        @"eta theta iota",
    ] canonicalStops:@[@0, @12, @15, @16, @17, @18, @31, @34, @35, @36, @37]
          anchorOffset:35];
}

- (void)testFloatingCursorStructuralBoundaryCapturedVerticalPointsMatchStock {
    NSArray<NSString *> *strings = @[
        @"alpha beta omega", @"delta epsilon zeta", @"eta theta iota",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];
    id stockController = ((id (*)(id, SEL))objc_msgSend)(
        stock, NSSelectorFromString(@"_internalTextLayoutController"));
    id customController = custom.id_richLayoutController;
    SEL positionSelector = NSSelectorFromString(@"positionWithOffset:affinity:");
    SEL affinitySelector = NSSelectorFromString(@"affinityForPosition:");
    UITextPosition *stockStart = ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
        stockController, positionSelector, 50, UITextStorageDirectionForward);
    CGRect startCaret = [stock caretRectForPosition:stockStart];
    CGPoint startPoint = CGPointMake(CGRectGetMidX(startCaret), CGRectGetMidY(startCaret));
    for (NSNumber *deltaY in @[@-24, @-52, @-82]) {
        CGPoint point = CGPointMake(startPoint.x, startPoint.y + deltaY.doubleValue);
        UITextPosition *stockPosition = [stock closestPositionToPoint:point];
        UITextPosition *customPosition = [custom closestPositionToPoint:point];
        XCTAssertNotNil(stockPosition);
        XCTAssertNotNil(customPosition);
        NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                               toPosition:stockPosition];
        NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                 toPosition:customPosition];
        XCTAssertEqual(customOffset, stockOffset, @"point=%@", NSStringFromCGPoint(point));
        XCTAssertEqual(((NSInteger (*)(id, SEL, id))objc_msgSend)(
                           customController, affinitySelector, customPosition),
                       ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                           stockController, affinitySelector, stockPosition));
        CGRect stockCaret = [stock caretRectForPosition:stockPosition];
        CGRect customCaret = [custom caretRectForPosition:customPosition];
        XCTAssertEqualWithAccuracy(CGRectGetMinX(customCaret),
                                   CGRectGetMinX(stockCaret), 0.5);
        XCTAssertEqualWithAccuracy(CGRectGetMinY(customCaret),
                                   CGRectGetMinY(stockCaret), 0.5);
    }
}

- (void)testFloatingCursorStructuralBoundaryVisualSelectionCallbackMatchesStock {
    NSArray<NSString *> *strings = @[
        @"alpha beta omega", @"delta epsilon zeta", @"eta theta iota",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];
    SEL selector = NSSelectorFromString(
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    XCTAssertTrue([stock respondsToSelector:selector]);
    UITextPosition *stockEnd = [stock positionFromPosition:stock.beginningOfDocument offset:50];
    UITextPosition *customEnd = [custom positionFromPosition:custom.beginningOfDocument offset:50];
    CGPoint point = CGPointMake(124.33333333333333, 5.9192592592592916);
    UITextPosition *stockStart = [stock closestPositionToPoint:point];
    UITextPosition *customStart = [custom closestPositionToPoint:point];
    UITextRange *stockRange = ((id (*)(id, SEL, id, CGPoint, id, NSInteger))objc_msgSend)(
        stock, selector, stockStart, point, stockEnd, UITextStorageDirectionForward);
    UITextRange *customRange = [custom.id_richLayoutController
        id_visualSelectionRangeForExtent:customStart
                              forPoint:point
                          fromPosition:customEnd
                           inDirection:UITextStorageDirectionForward];
    NSRange stockCanonical = NSMakeRange(
        [stock offsetFromPosition:stock.beginningOfDocument toPosition:stockRange.start],
        [stock offsetFromPosition:stockRange.start toPosition:stockRange.end]);
    NSRange customCanonical = NSMakeRange(
        [custom offsetFromPosition:custom.beginningOfDocument toPosition:customRange.start],
        [custom offsetFromPosition:customRange.start toPosition:customRange.end]);
    XCTAssertTrue(NSEqualRanges(customCanonical, stockCanonical),
                  @"stock=%@ custom=%@", NSStringFromRange(stockCanonical),
                  NSStringFromRange(customCanonical));
}

- (void)testRichVisualSelectionNeutralCasesMatchStockWithoutMutatingDocument {
    NSArray<NSDictionary<NSString *, id> *> *rows = @[
        @{ @"blocks": @[@"abc", @"", @"def"], @"anchor": @1, @"extent": @6 },
        @{ @"blocks": @[@"A👩‍👩‍👧‍👦B", @"C"], @"anchor": @1, @"extent": @13 },
        @{ @"blocks": @[@"left אבג", @"שלום right"], @"anchor": @6, @"extent": @12 },
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    CGRect frame = CGRectMake(0, 0, 370, 360);
    SEL selector = NSSelectorFromString(
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    SEL affinitySelector = NSSelectorFromString(@"affinityForPosition:");

    for (NSDictionary<NSString *, id> *row in rows) {
        NSArray<NSString *> *strings = row[@"blocks"];
        NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
        for (NSString *string in strings) {
            [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
                NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
            }]];
        }
        IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                       attributedBlocks:blocks];
        custom.font = font;
        custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
        UITextView *stock = [[UITextView alloc] initWithFrame:frame];
        stock.font = font;
        stock.textContainerInset = custom.textContainerInset;
        stock.textContainer.lineFragmentPadding = 5.0;
        stock.text = [strings componentsJoinedByString:@"\n"];
        [custom layoutIfNeeded];
        [stock layoutIfNeeded];
        XCTAssertTrue([stock respondsToSelector:selector]);

        NSUInteger anchorOffset = [row[@"anchor"] unsignedIntegerValue];
        NSUInteger extentOffset = [row[@"extent"] unsignedIntegerValue];
        UITextPosition *stockAnchor = [stock positionFromPosition:stock.beginningOfDocument
                                                           offset:anchorOffset];
        UITextPosition *customAnchor = [custom positionFromPosition:custom.beginningOfDocument
                                                              offset:anchorOffset];
        UITextPosition *stockExtent = [stock positionFromPosition:stock.beginningOfDocument
                                                           offset:extentOffset];
        UITextPosition *customExtent = [custom positionFromPosition:custom.beginningOfDocument
                                                              offset:extentOffset];
        CGRect stockCaret = [stock caretRectForPosition:stockExtent];
        CGRect customCaret = [custom caretRectForPosition:customExtent];
        id stockController = ((id (*)(id, SEL))objc_msgSend)(
            stock, NSSelectorFromString(@"_internalTextLayoutController"));
        NSUInteger revision = custom.id_document.documentRevision;

        for (NSNumber *deltaValue in @[@-0.25, @0.25]) {
            CGPoint stockPoint = CGPointMake(CGRectGetMidX(stockCaret) + deltaValue.doubleValue,
                                             CGRectGetMidY(stockCaret));
            CGPoint customPoint = CGPointMake(CGRectGetMidX(customCaret) + deltaValue.doubleValue,
                                              CGRectGetMidY(customCaret));
            for (NSNumber *directionValue in @[
                @(UITextStorageDirectionForward), @(UITextStorageDirectionBackward)]) {
                NSInteger direction = directionValue.integerValue;
                UITextRange *stockRange =
                    ((id (*)(id, SEL, id, CGPoint, id, NSInteger))objc_msgSend)(
                        stock, selector, stockExtent, stockPoint, stockAnchor, direction);
                UITextRange *customRange = [custom.id_richLayoutController
                    id_visualSelectionRangeForExtent:customExtent
                                          forPoint:customPoint
                                      fromPosition:customAnchor
                                       inDirection:direction];
                XCTAssertNotNil(stockRange, @"row=%@ delta=%@ direction=%ld",
                                row, deltaValue, (long)direction);
                XCTAssertNotNil(customRange, @"row=%@ delta=%@ direction=%ld",
                                row, deltaValue, (long)direction);
                if (stockRange == nil || customRange == nil) continue;
                NSRange stockCanonical = NSMakeRange(
                    [stock offsetFromPosition:stock.beginningOfDocument
                                    toPosition:stockRange.start],
                    [stock offsetFromPosition:stockRange.start toPosition:stockRange.end]);
                NSRange customCanonical = NSMakeRange(
                    [custom offsetFromPosition:custom.beginningOfDocument
                                     toPosition:customRange.start],
                    [custom offsetFromPosition:customRange.start toPosition:customRange.end]);
                XCTAssertTrue(NSEqualRanges(customCanonical, stockCanonical),
                    @"row=%@ delta=%@ direction=%ld stock=%@ custom=%@", row,
                    deltaValue, (long)direction, NSStringFromRange(stockCanonical),
                    NSStringFromRange(customCanonical));
                XCTAssertTrue(IDFloatingCursorIsComposedCharacterBoundary(
                    stock.text, customCanonical.location));
                XCTAssertTrue(IDFloatingCursorIsComposedCharacterBoundary(
                    stock.text, NSMaxRange(customCanonical)));
                XCTAssertEqual([custom.id_richLayoutController
                                    id_affinityForPosition:customRange.start],
                               ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                                   stockController, affinitySelector, stockRange.start));
                XCTAssertEqual([custom.id_richLayoutController
                                    id_affinityForPosition:customRange.end],
                               ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                                   stockController, affinitySelector, stockRange.end));
                XCTAssertEqual(custom.id_document.documentRevision, revision);
            }
        }
    }
}

- (void)testFloatingCursorControllerConsumesContainerLocalPointsWithoutViewConversion {
    NSArray<NSString *> *strings = @[
        @"alpha beta omega", @"delta epsilon zeta", @"eta theta iota",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    id stockController = ((id (*)(id, SEL))objc_msgSend)(
        stock, NSSelectorFromString(@"_internalTextLayoutController"));
    id customController = custom.id_richLayoutController;
    SEL firstContainerSelector = NSSelectorFromString(@"firstTextContainer");
    SEL cursorSelector = NSSelectorFromString(@"cursorPositionAtPoint:inContainer:");
    id stockContainer = ((id (*)(id, SEL))objc_msgSend)(
        stockController, firstContainerSelector);
    id customContainer = ((id (*)(id, SEL))objc_msgSend)(
        customController, firstContainerSelector);
    NSArray<NSValue *> *containerLocalPoints = @[
        [NSValue valueWithCGPoint:CGPointMake(119.33333333333333,
                                              6.5933333333333266)],
        [NSValue valueWithCGPoint:CGPointMake(119.33333333333333, 5.5)],
    ];
    NSArray<NSNumber *> *expectedOffsets = @[@12, @12];
    [containerLocalPoints enumerateObjectsUsingBlock:^(NSValue *value,
                                                       NSUInteger index,
                                                       BOOL *stop) {
        UITextPosition *stockPosition =
            ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(
                stockController, cursorSelector, value.CGPointValue, stockContainer);
        // The fixture points are CONTAINER-LOCAL, which is stock's convention. Ours takes points in
        // the view's space — the block stack carries `textContainerInset` internally so that its own
        // origin can equal the host's, which is what makes UIKit draw the caret on the glyphs — so
        // the same place is that point plus the inset.
        CGPoint customLocalPoint = CGPointMake(
            value.CGPointValue.x + custom.textContainerInset.left,
            value.CGPointValue.y + custom.textContainerInset.top);
        UITextPosition *customPosition =
            ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(
                customController, cursorSelector, customLocalPoint, customContainer);
        XCTAssertNotNil(stockPosition);
        XCTAssertNotNil(customPosition);
        NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                               toPosition:stockPosition];
        NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                 toPosition:customPosition];
        XCTAssertEqual(customOffset, stockOffset, @"phase=%lu",
                       (unsigned long)index);
        XCTAssertEqual(customOffset, expectedOffsets[index].integerValue,
                       @"phase=%lu", (unsigned long)index);
    }];
}

- (void)testFloatingCursorStructuralBoundaryNilContainerInsertionGeometryMatchesStock {
    NSArray<NSString *> *strings = @[
        @"alpha beta omega", @"delta epsilon zeta", @"eta theta iota",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    id stockController = ((id (*)(id, SEL))objc_msgSend)(
        stock, NSSelectorFromString(@"_internalTextLayoutController"));
    id customController = custom.id_richLayoutController;
    SEL positionSelector = NSSelectorFromString(@"positionWithOffset:affinity:");
    UITextPosition *stockPosition =
        ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
            stockController, positionSelector, 12, UITextStorageDirectionForward);
    UITextPosition *customPosition =
        ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
            customController, positionSelector, 12, UITextStorageDirectionForward);
    SEL insertionSelector = NSSelectorFromString(
        @"insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:");
    CGRect stockRect = ((CGRect (*)(id, SEL, id, id, id, NSTextContainer **))objc_msgSend)(
        stockController, insertionSelector, stockPosition, @{}, nil, NULL);
    CGRect customRect = ((CGRect (*)(id, SEL, id, id, id, NSTextContainer **))objc_msgSend)(
        customController, insertionSelector, customPosition, @{}, nil, NULL);
    // Our insertion rect is in the view's space and stock's is container-local, so the comparison
    // removes our container inset. See the note on `customPoint` above.
    XCTAssertEqualWithAccuracy(CGRectGetMinX(customRect) - custom.textContainerInset.left,
                               CGRectGetMinX(stockRect), 0.5,
                               @"stock=%@ custom=%@", NSStringFromCGRect(stockRect),
                               NSStringFromCGRect(customRect));
    XCTAssertEqualWithAccuracy(CGRectGetMinY(customRect) - custom.textContainerInset.top,
                               CGRectGetMinY(stockRect), 0.5,
                               @"stock=%@ custom=%@", NSStringFromCGRect(stockRect),
                               NSStringFromCGRect(customRect));
}

- (void)testFloatingCursorControllerLocalPointDoesNotSubtractHorizontalInsetOrigin {
    NSArray<NSValue *> *insets = @[
        [NSValue valueWithUIEdgeInsets:UIEdgeInsetsZero],
        [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(13, 11, 7, 3)],
    ];
    for (NSValue *insetValue in insets) {
        UIEdgeInsets inset = insetValue.UIEdgeInsetsValue;
        UIFont *font = [UIFont systemFontOfSize:20.0];
        NSArray *blocks = @[
            [[NSAttributedString alloc] initWithString:@"alpha beta omega" attributes:@{
                NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
            }],
            [[NSAttributedString alloc] initWithString:@"delta epsilon zeta" attributes:@{
                NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
            }],
        ];
        CGRect frame = CGRectMake(0, 0, 370, 180);
        IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                       attributedBlocks:blocks];
        custom.font = font;
        custom.textContainerInset = inset;
        UITextView *stock = [[UITextView alloc] initWithFrame:frame];
        stock.font = font;
        stock.textContainerInset = inset;
        stock.textContainer.lineFragmentPadding = 5.0;
        stock.text = @"alpha beta omega\ndelta epsilon zeta";
        [custom layoutIfNeeded];
        [stock layoutIfNeeded];

        id stockController = ((id (*)(id, SEL))objc_msgSend)(
            stock, NSSelectorFromString(@"_internalTextLayoutController"));
        id customController = custom.id_richLayoutController;
        SEL positionSelector = NSSelectorFromString(@"positionWithOffset:affinity:");
        UITextPosition *stockPosition =
            ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
                stockController, positionSelector, 12, UITextStorageDirectionForward);
        SEL insertionSelector = NSSelectorFromString(
            @"insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:");
        CGRect stockInsertion =
            ((CGRect (*)(id, SEL, id, id, id, NSTextContainer **))objc_msgSend)(
                stockController, insertionSelector, stockPosition, @{}, nil, NULL);
        CGPoint stockPoint = CGPointMake(CGRectGetMidX(stockInsertion),
                                         CGRectGetMidY(stockInsertion));
        // Our controller takes points in the SAME space our own geometry answers use — the view's,
        // which includes `textContainerInset` because the block stack carries it internally so its
        // origin can equal the host's. Stock's controller takes container-local points, which exclude
        // it. Same place, two conventions, so the point is offset when handed to ours.
        CGPoint customPoint = CGPointMake(stockPoint.x + inset.left, stockPoint.y + inset.top);
        SEL firstContainerSelector = NSSelectorFromString(@"firstTextContainer");
        SEL cursorSelector = NSSelectorFromString(@"cursorPositionAtPoint:inContainer:");
        id stockContainer = ((id (*)(id, SEL))objc_msgSend)(
            stockController, firstContainerSelector);
        id customContainer = ((id (*)(id, SEL))objc_msgSend)(
            customController, firstContainerSelector);
        UITextPosition *stockResult = ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(
            stockController, cursorSelector, stockPoint, stockContainer);
        UITextPosition *customResult = ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(
            customController, cursorSelector, customPoint, customContainer);
        NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                               toPosition:stockResult];
        NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                 toPosition:customResult];
        XCTAssertEqual(customOffset, stockOffset, @"inset=%@ stockPoint=%@ customPoint=%@",
                       NSStringFromUIEdgeInsets(inset), NSStringFromCGPoint(stockPoint),
                       NSStringFromCGPoint(customPoint));
        XCTAssertEqual(customOffset, 12, @"inset=%@", NSStringFromUIEdgeInsets(inset));
    }
}

- (void)testFloatingCursorMixedBiDiVisualSelectionUsesPointDerivedExtentAndAnchor {
    NSArray<NSString *> *strings = @[
        @"left alpha אבגדה right omega",
        @"second שלום mixed tail",
        @"third paragraph final",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    SEL selector = NSSelectorFromString(
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    XCTAssertTrue([stock respondsToSelector:selector]);
    UITextPosition *stockAnchor =
        [stock positionFromPosition:stock.beginningOfDocument offset:16];
    UITextPosition *customAnchor =
        [custom positionFromPosition:custom.beginningOfDocument offset:16];
    id stockController = ((id (*)(id, SEL))objc_msgSend)(
        stock, NSSelectorFromString(@"_internalTextLayoutController"));
    SEL affinitySelector = NSSelectorFromString(@"affinityForPosition:");
    for (NSNumber *offsetValue in @[@10, @11, @12, @13, @14, @15, @16, @17]) {
        UITextPosition *capture = [stock positionFromPosition:stock.beginningOfDocument
                                                      offset:offsetValue.integerValue];
        CGRect caret = [stock caretRectForPosition:capture];
        for (NSNumber *deltaX in @[@-0.25, @0.25]) {
            CGPoint point = CGPointMake(CGRectGetMidX(caret) + deltaX.doubleValue,
                                        CGRectGetMidY(caret));
            UITextPosition *stockExtent = [stock closestPositionToPoint:point];
            UITextPosition *customExtent = [custom closestPositionToPoint:point];
            for (NSNumber *directionValue in @[
                @(UITextStorageDirectionForward), @(UITextStorageDirectionBackward)]) {
                NSInteger direction = directionValue.integerValue;
                UITextRange *stockRange =
                    ((id (*)(id, SEL, id, CGPoint, id, NSInteger))objc_msgSend)(
                        stock, selector, stockExtent, point, stockAnchor, direction);
                UITextRange *customRange = [custom.id_richLayoutController
                    id_visualSelectionRangeForExtent:customExtent
                                          forPoint:point
                                      fromPosition:customAnchor
                                       inDirection:direction];
                XCTAssertNotNil(stockRange, @"offset=%@ point=%@ direction=%ld",
                                offsetValue, NSStringFromCGPoint(point), (long)direction);
                XCTAssertNotNil(customRange, @"offset=%@ point=%@ direction=%ld",
                                offsetValue, NSStringFromCGPoint(point), (long)direction);
                NSRange stockCanonical = NSMakeRange(
                    [stock offsetFromPosition:stock.beginningOfDocument
                                    toPosition:stockRange.start],
                    [stock offsetFromPosition:stockRange.start toPosition:stockRange.end]);
                NSRange customCanonical = NSMakeRange(
                    [custom offsetFromPosition:custom.beginningOfDocument
                                     toPosition:customRange.start],
                    [custom offsetFromPosition:customRange.start toPosition:customRange.end]);
                XCTAssertTrue(NSEqualRanges(customCanonical, stockCanonical),
                    @"offset=%@ point=%@ direction=%ld stock=%@ custom=%@",
                    offsetValue, NSStringFromCGPoint(point), (long)direction,
                    NSStringFromRange(stockCanonical), NSStringFromRange(customCanonical));
                XCTAssertEqual([custom.id_richLayoutController
                                    id_affinityForPosition:customRange.start],
                               ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                                   stockController, affinitySelector, stockRange.start));
                XCTAssertEqual([custom.id_richLayoutController
                                    id_affinityForPosition:customRange.end],
                               ((NSInteger (*)(id, SEL, id))objc_msgSend)(
                                   stockController, affinitySelector, stockRange.end));
            }
        }
    }
}

- (void)testFloatingCursorMixedBiDiGestureDeltaPointsMatchStockVisualRanges {
    NSArray<NSString *> *strings = @[
        @"left alpha אבגדה right omega",
        @"second שלום mixed tail",
        @"third paragraph final",
    ];
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor,
        }]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    SEL selector = NSSelectorFromString(
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    UITextPosition *stockAnchor = [stock positionFromPosition:stock.beginningOfDocument offset:16];
    UITextPosition *customAnchor = [custom positionFromPosition:custom.beginningOfDocument offset:16];
    CGRect stockCaret = [stock caretRectForPosition:stockAnchor];
    CGRect customCaret = [custom caretRectForPosition:customAnchor];
    XCTAssertEqualWithAccuracy(CGRectGetMidX(customCaret), CGRectGetMidX(stockCaret), 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMidY(customCaret), CGRectGetMidY(stockCaret), 0.5);
    for (NSNumber *deltaValue in @[@-52, @68, @-120]) {
        CGPoint point = CGPointMake(CGRectGetMidX(stockCaret) + deltaValue.doubleValue,
                                    CGRectGetMidY(stockCaret));
        UITextPosition *stockExtent = [stock closestPositionToPoint:point];
        UITextPosition *customExtent = [custom closestPositionToPoint:point];
        XCTAssertEqual([custom offsetFromPosition:custom.beginningOfDocument toPosition:customExtent],
                       [stock offsetFromPosition:stock.beginningOfDocument toPosition:stockExtent],
                       @"delta=%@", deltaValue);
        for (NSNumber *directionValue in @[@(UITextStorageDirectionBackward),
                                            @(UITextStorageDirectionForward)]) {
            NSInteger direction = directionValue.integerValue;
            UITextRange *stockRange = ((id (*)(id, SEL, id, CGPoint, id, NSInteger))objc_msgSend)(
                stock, selector, stockExtent, point, stockAnchor, direction);
            UITextRange *customRange = [custom.id_richLayoutController
                id_visualSelectionRangeForExtent:customExtent
                                      forPoint:point
                                  fromPosition:customAnchor
                                   inDirection:direction];
            NSRange stockCanonical = NSMakeRange(
                [stock offsetFromPosition:stock.beginningOfDocument toPosition:stockRange.start],
                [stock offsetFromPosition:stockRange.start toPosition:stockRange.end]);
            NSRange customCanonical = NSMakeRange(
                [custom offsetFromPosition:custom.beginningOfDocument toPosition:customRange.start],
                [custom offsetFromPosition:customRange.start toPosition:customRange.end]);
            XCTAssertTrue(NSEqualRanges(customCanonical, stockCanonical),
                          @"delta=%@ direction=%ld stock=%@ custom=%@", deltaValue,
                          (long)direction, NSStringFromRange(stockCanonical),
                          NSStringFromRange(customCanonical));
        }
    }
}

- (void)testFloatingCursorMixedBiDiStopsMatchStockOffsetAffinityOrderAndGeometry {
    [self assertFloatingFixtureBlocks:@[
        @"left alpha אבגדה right omega",
        @"second שלום mixed tail",
        @"third paragraph final",
    ] canonicalStops:@[@10, @11, @12, @15, @16, @17, @28, @29, @30, @36, @40]
          anchorOffset:16];
}

@end
