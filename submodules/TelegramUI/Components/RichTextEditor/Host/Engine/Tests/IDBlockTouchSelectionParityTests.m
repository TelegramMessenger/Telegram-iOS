@import XCTest;

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"

#import <objc/message.h>

typedef CGPoint (^IDLoupePointProvider)(void);

static void IDSendTestLoupeGesture(id assistant,
                                   UIGestureRecognizerState state,
                                   CGPoint location,
                                   CGPoint translation,
                                   CGPoint velocity) {
    IDLoupePointProvider locationProvider = ^CGPoint { return location; };
    IDLoupePointProvider translationProvider = ^CGPoint { return translation; };
    IDLoupePointProvider velocityProvider = ^CGPoint { return velocity; };
    BOOL shouldCancel = NO;
    ((void (*)(id, SEL, NSInteger, id, id, id, NSInteger, BOOL *))objc_msgSend)(
        assistant,
        NSSelectorFromString(
            @"loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:"),
        state,
        locationProvider,
        translationProvider,
        velocityProvider,
        0,
        &shouldCancel);
    NSCAssert(!shouldCancel, @"Test-only loupe sequence was cancelled");
}

static UIImage *IDCaptureWindowScene(UIWindowScene *scene) {
    CGSize size = scene.screen.bounds.size;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        for (UIWindow *window in scene.windows) {
            if (window.hidden || window.alpha <= 0.0) continue;
            CGContextSaveGState(context.CGContext);
            CGContextTranslateCTM(context.CGContext, window.frame.origin.x, window.frame.origin.y);
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
            CGContextRestoreGState(context.CGContext);
        }
    }];
}

static void IDWaitForLoupePresentation(void) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.4];
    while (deadline.timeIntervalSinceNow > 0.0) {
        [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:deadline];
    }
}

static UIView *IDVisibleSubviewOfClass(UIView *root, Class viewClass) {
    if ([root isKindOfClass:viewClass] && !root.hidden && root.alpha > 0.0 && root.window != nil) {
        return root;
    }
    for (UIView *subview in root.subviews) {
        UIView *match = IDVisibleSubviewOfClass(subview, viewClass);
        if (match != nil) return match;
    }
    return nil;
}

static UIView *IDVisibleLoupeViewInScene(UIWindowScene *scene) {
    Class loupeClass = NSClassFromString(@"_UITextMagnifiedGlassLoupeView");
    if (loupeClass == Nil) return nil;
    for (UIWindow *window in scene.windows.reverseObjectEnumerator) {
        UIView *loupe = IDVisibleSubviewOfClass(window, loupeClass);
        if (loupe != nil) return loupe;
    }
    return nil;
}

static UIView *IDWaitForLoupeInScene(UIWindowScene *scene, BOOL visible) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    UIView *loupe = nil;
    do {
        loupe = IDVisibleLoupeViewInScene(scene);
        if ((loupe != nil) == visible) return loupe;
        NSDate *step = [NSDate dateWithTimeIntervalSinceNow:0.05];
        [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:step];
    } while (deadline.timeIntervalSinceNow > 0.0);
    return IDVisibleLoupeViewInScene(scene);
}

static CGRect IDScreenRectForView(UIView *view) {
    return [view convertRect:view.bounds toView:nil];
}

@interface IDBlockTouchSelectionParityTests : XCTestCase
@end

@implementation IDBlockTouchSelectionParityTests

- (NSArray<NSString *> *)fixtureBlocks {
    return @[
        @"First wrapped paragraph contains constellation and punctuation for precise taps.",
        @"Second wrapped paragraph provides selection handles across independent blocks.",
        @"Third wrapped paragraph keeps the viewport tall enough for 👨‍👩‍👧‍👦 taps.",
    ];
}

- (NSArray<NSAttributedString *> *)attributedBlocks:(NSArray<NSString *> *)strings
                                                font:(UIFont *)font {
    NSMutableArray<NSAttributedString *> *result = [NSMutableArray array];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: UIColor.blackColor,
    };
    for (NSString *string in strings) {
        [result addObject:[[NSAttributedString alloc] initWithString:string
                                                          attributes:attributes]];
    }
    return result.copy;
}

- (UIWindow *)hostCustom:(IDBlockTextView *)custom stock:(UITextView *)stock {
    UIWindowScene *windowScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    XCTAssertNotNil(windowScene);
    UIWindow *priorKeyWindow = windowScene.keyWindow;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.frame = CGRectMake(0, 0, 520, 440);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    custom.frame = CGRectMake(0, 0, 240, 420);
    stock.frame = CGRectMake(260, 0, 240, 420);
    [controller.view addSubview:custom];
    [controller.view addSubview:stock];
    [window makeKeyAndVisible];
    [controller.view layoutIfNeeded];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];
    [self addTeardownBlock:^{
        [custom removeFromSuperview];
        [stock removeFromSuperview];
        window.hidden = YES;
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
    }];
    return window;
}

- (void)makeCustom:(IDBlockTextView * __strong *)customResult
              stock:(UITextView * __strong *)stockResult {
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSArray<NSString *> *blocks = [self fixtureBlocks];
    IDBlockTextView *custom = [[IDBlockTextView alloc]
        initWithFrame:CGRectZero
      attributedBlocks:[self attributedBlocks:blocks font:font]];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    custom.backgroundColor = UIColor.whiteColor;

    UITextView *stock = [[UITextView alloc] initWithFrame:CGRectZero];
    stock.font = font;
    stock.textColor = UIColor.blackColor;
    stock.backgroundColor = UIColor.whiteColor;
    stock.textContainerInset = custom.textContainerInset;
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [blocks componentsJoinedByString:@"\n"];

    __unused UIWindow *window = [self hostCustom:custom stock:stock];
    *customResult = custom;
    *stockResult = stock;
}

- (NSUInteger)offsetForPosition:(UITextPosition *)position input:(id<UITextInput>)input {
    NSInteger offset = [input offsetFromPosition:input.beginningOfDocument
                                      toPosition:position];
    XCTAssertGreaterThanOrEqual(offset, 0);
    return (NSUInteger)MAX(offset, 0);
}

- (NSRange)canonicalRange:(UITextRange *)range input:(id<UITextInput>)input {
    XCTAssertNotNil(range);
    NSUInteger location = [self offsetForPosition:range.start input:input];
    NSInteger length = [input offsetFromPosition:range.start toPosition:range.end];
    XCTAssertGreaterThanOrEqual(length, 0);
    return NSMakeRange(location, (NSUInteger)MAX(length, 0));
}

- (UITextRange *)rangeForInput:(id<UITextInput>)input
                         offset:(NSUInteger)offset
                    granularity:(UITextGranularity)granularity {
    UITextPosition *position = [input positionFromPosition:input.beginningOfDocument
                                                    offset:(NSInteger)offset];
    XCTAssertNotNil(position);
    return [input.tokenizer rangeEnclosingPosition:position
                                    withGranularity:granularity
                                        inDirection:UITextStorageDirectionForward];
}

- (BOOL)offset:(NSUInteger)offset isInsideComposedClusterOfString:(NSString *)string {
    if (offset == 0 || offset >= string.length) return NO;
    NSRange cluster = [string rangeOfComposedCharacterSequenceAtIndex:offset];
    return offset > cluster.location && offset < NSMaxRange(cluster);
}

- (void)testClosestPositionsMatchStockAtWrappedLineStartMiddleAndEnd {
    IDBlockTextView *custom = nil;
    UITextView *stock = nil;
    [self makeCustom:&custom stock:&stock];

    CGRect firstCaret = [stock caretRectForPosition:stock.beginningOfDocument];
    CGFloat lineY = CGRectGetMidY(firstCaret);
    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(CGRectGetMinX(firstCaret) + 1.0, lineY)],
        [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(stock.bounds), lineY)],
        [NSValue valueWithCGPoint:CGPointMake(CGRectGetWidth(stock.bounds) -
                                                  stock.textContainerInset.right -
                                                  stock.textContainer.lineFragmentPadding - 1.0,
                                              lineY)],
    ];
    for (NSValue *value in points) {
        CGPoint point = value.CGPointValue;
        NSUInteger customOffset = [self offsetForPosition:
            [custom closestPositionToPoint:point] input:custom];
        NSUInteger stockOffset = [self offsetForPosition:
            [stock closestPositionToPoint:point] input:stock];
        XCTAssertEqual(customOffset, stockOffset, @"point=%@", value);
    }
}

- (void)testClosestPositionMatchesStockAtConstellationPointForLiveWidth {
    IDBlockTextView *custom = nil;
    UITextView *stock = nil;
    [self makeCustom:&custom stock:&stock];
    custom.frame = CGRectMake(0, 0, 370, 360);
    stock.frame = CGRectMake(390, 0, 370, 360);
    [custom setNeedsLayout];
    [custom layoutIfNeeded];
    [stock setNeedsLayout];
    [stock layoutIfNeeded];

    NSRange word = [stock.text rangeOfString:@"constellation"];
    XCTAssertNotEqual(word.location, NSNotFound);
    UITextPosition *stockStart = [stock positionFromPosition:stock.beginningOfDocument
                                                     offset:(NSInteger)word.location + 2];
    UITextPosition *stockEnd = [stock positionFromPosition:stockStart offset:1];
    CGRect startCaret = [stock caretRectForPosition:stockStart];
    CGRect endCaret = [stock caretRectForPosition:stockEnd];
    CGPoint point = CGPointMake((CGRectGetMidX(startCaret) + CGRectGetMidX(endCaret)) * 0.5,
                                CGRectGetMidY(startCaret));
    NSUInteger customOffset = [self offsetForPosition:
        [custom closestPositionToPoint:point] input:custom];
    NSUInteger stockOffset = [self offsetForPosition:
        [stock closestPositionToPoint:point] input:stock];
    XCTAssertEqual(customOffset, stockOffset,
                   @"point=%@ custom=%lu stock=%lu stockContainer=%@",
                   NSStringFromCGPoint(point), (unsigned long)customOffset,
                   (unsigned long)stockOffset, NSStringFromCGSize(stock.textContainer.size));
}

- (void)testWordAndParagraphTokenizerRangesMatchStockAcrossStructuralNewline {
    IDBlockTextView *custom = nil;
    UITextView *stock = nil;
    [self makeCustom:&custom stock:&stock];
    NSString *text = stock.text;

    NSRange constellation = [text rangeOfString:@"constellation"];
    XCTAssertNotEqual(constellation.location, NSNotFound);
    NSUInteger wordProbe = constellation.location + 2;
    NSRange customWord = [self canonicalRange:
        [self rangeForInput:custom offset:wordProbe granularity:UITextGranularityWord]
                                         input:custom];
    NSRange stockWord = [self canonicalRange:
        [self rangeForInput:stock offset:wordProbe granularity:UITextGranularityWord]
                                        input:stock];
    XCTAssertTrue(NSEqualRanges(customWord, stockWord));
    XCTAssertTrue(NSEqualRanges(customWord, constellation));

    NSUInteger structuralNewline = [[self fixtureBlocks].firstObject length];
    for (NSNumber *probe in @[@(structuralNewline), @(structuralNewline + 1)]) {
        NSRange customParagraph = [self canonicalRange:
            [self rangeForInput:custom
                         offset:probe.unsignedIntegerValue
                    granularity:UITextGranularityParagraph]
                                                  input:custom];
        NSRange stockParagraph = [self canonicalRange:
            [self rangeForInput:stock
                         offset:probe.unsignedIntegerValue
                    granularity:UITextGranularityParagraph]
                                                 input:stock];
        XCTAssertTrue(NSEqualRanges(customParagraph, stockParagraph),
                      @"probe=%@ custom=%@ stock=%@",
                      probe, NSStringFromRange(customParagraph), NSStringFromRange(stockParagraph));
    }
}

- (void)testClosestPositionNeverReturnsComposedClusterInteriorOffset {
    IDBlockTextView *custom = nil;
    UITextView *stock = nil;
    [self makeCustom:&custom stock:&stock];
    NSString *text = stock.text;
    NSRange cluster = [text rangeOfString:@"👨‍👩‍👧‍👦"];
    XCTAssertNotEqual(cluster.location, NSNotFound);
    UITextPosition *startPosition = [stock positionFromPosition:stock.beginningOfDocument
                                                        offset:(NSInteger)cluster.location];
    UITextPosition *endPosition = [stock positionFromPosition:startPosition
                                                      offset:(NSInteger)cluster.length];
    CGRect startCaret = [stock caretRectForPosition:startPosition];
    CGRect endCaret = [stock caretRectForPosition:endPosition];
    CGPoint point = CGPointMake((CGRectGetMidX(startCaret) + CGRectGetMidX(endCaret)) * 0.5,
                                CGRectGetMidY(startCaret));

    NSUInteger customOffset = [self offsetForPosition:
        [custom closestPositionToPoint:point] input:custom];
    NSUInteger stockOffset = [self offsetForPosition:
        [stock closestPositionToPoint:point] input:stock];
    XCTAssertEqual(customOffset, stockOffset);
    XCTAssertFalse([self offset:customOffset isInsideComposedClusterOfString:text]);
}

- (void)testTask5ClosestPositionBelowIndependentBlocksMatchesStockDocumentEnd {
    IDBlockTextView *custom = nil;
    UITextView *stock = nil;
    [self makeCustom:&custom stock:&stock];
    CGPoint point = CGPointMake(132.0, CGRectGetHeight(custom.bounds) - 24.0);
    NSUInteger customOffset = [self offsetForPosition:
        [custom closestPositionToPoint:point] input:custom];
    NSUInteger stockOffset = [self offsetForPosition:
        [stock closestPositionToPoint:point] input:stock];
    XCTAssertEqual(stockOffset, stock.text.length);
    XCTAssertEqual(customOffset, stockOffset,
                   @"point=%@ custom=%lu stock=%lu",
                   NSStringFromCGPoint(point), (unsigned long)customOffset,
                   (unsigned long)stockOffset);
}

- (void)testTestOnlyLoupeSequenceMatchesStockSizeOffsetAndMovement {
    IDBlockTextView *custom = nil;
    UITextView *stock = nil;
    [self makeCustom:&custom stock:&stock];
    UIWindowScene *scene = custom.window.windowScene;
    XCTAssertNotNil(scene);
    custom.window.frame = scene.screen.bounds;
    CGRect editorFrame = CGRectMake(16.0, 198.0, 370.0, 360.0);
    custom.frame = editorFrame;
    stock.frame = editorFrame;
    custom.hidden = YES;
    stock.hidden = NO;
    [custom.window layoutIfNeeded];
    [stock layoutIfNeeded];
    CGPoint initialPoint = CGPointMake(72.0, 42.0);
    CGPoint movedPoint = CGPointMake(112.0, 42.0);

    id stockAssistant = ((id (*)(id, SEL))objc_msgSend)(
        stock, NSSelectorFromString(@"interactionAssistant"));
    XCTAssertNotNil(stockAssistant);
    [stock becomeFirstResponder];
    IDSendTestLoupeGesture(stockAssistant, UIGestureRecognizerStateBegan,
                           initialPoint, CGPointZero, CGPointZero);
    IDSendTestLoupeGesture(stockAssistant, UIGestureRecognizerStateChanged,
                           initialPoint, CGPointZero, CGPointZero);
    IDWaitForLoupePresentation();
    UIImage *stockHeld = IDCaptureWindowScene(scene);
    XCTAssertTrue(stockHeld.CGImage != NULL);
    UIView *stockFirstLoupeView = IDWaitForLoupeInScene(scene, YES);
    XCTAssertNotNil(stockFirstLoupeView);
    CGRect stockFirstLoupe = IDScreenRectForView(stockFirstLoupeView);
    UIView *stockCaretView = ((id (*)(id, SEL))objc_msgSend)(
        stockAssistant, NSSelectorFromString(@"_caretView"));
    XCTAssertNotNil(stockCaretView);
    CGRect stockCaret = IDScreenRectForView(stockCaretView);
    IDSendTestLoupeGesture(stockAssistant, UIGestureRecognizerStateChanged,
                           movedPoint, CGPointMake(40.0, 0.0), CGPointZero);
    IDWaitForLoupePresentation();
    UIImage *stockMoved = IDCaptureWindowScene(scene);
    XCTAssertTrue(stockMoved.CGImage != NULL);
    UIView *stockSecondLoupeView = IDWaitForLoupeInScene(scene, YES);
    XCTAssertNotNil(stockSecondLoupeView);
    CGRect stockSecondLoupe = IDScreenRectForView(stockSecondLoupeView);
    IDSendTestLoupeGesture(stockAssistant, UIGestureRecognizerStateEnded,
                           movedPoint, CGPointMake(40.0, 0.0), CGPointZero);
    IDWaitForLoupePresentation();
    XCTAssertNil(IDWaitForLoupeInScene(scene, NO));

    id customAssistant = custom.id_interactionAssistant;
    XCTAssertNotNil(customAssistant);
    stock.hidden = YES;
    custom.hidden = NO;
    [custom.window layoutIfNeeded];
    [custom layoutIfNeeded];
    [custom becomeFirstResponder];
    IDSendTestLoupeGesture(customAssistant, UIGestureRecognizerStateBegan,
                           initialPoint, CGPointZero, CGPointZero);
    IDSendTestLoupeGesture(customAssistant, UIGestureRecognizerStateChanged,
                           initialPoint, CGPointZero, CGPointZero);
    IDWaitForLoupePresentation();
    UIImage *customHeld = IDCaptureWindowScene(scene);
    XCTAssertTrue(customHeld.CGImage != NULL);
    UIView *customFirstLoupeView = IDWaitForLoupeInScene(scene, YES);
    XCTAssertNotNil(customFirstLoupeView);
    CGRect customFirstLoupe = IDScreenRectForView(customFirstLoupeView);
    UIView *customCaretView = ((id (*)(id, SEL))objc_msgSend)(
        customAssistant, NSSelectorFromString(@"_caretView"));
    XCTAssertNotNil(customCaretView);
    CGRect customCaret = IDScreenRectForView(customCaretView);
    IDSendTestLoupeGesture(customAssistant, UIGestureRecognizerStateChanged,
                           movedPoint, CGPointMake(40.0, 0.0), CGPointZero);
    IDWaitForLoupePresentation();
    UIImage *customMoved = IDCaptureWindowScene(scene);
    XCTAssertTrue(customMoved.CGImage != NULL);
    UIView *customSecondLoupeView = IDWaitForLoupeInScene(scene, YES);
    XCTAssertNotNil(customSecondLoupeView);
    CGRect customSecondLoupe = IDScreenRectForView(customSecondLoupeView);
    IDSendTestLoupeGesture(customAssistant, UIGestureRecognizerStateEnded,
                           movedPoint, CGPointMake(40.0, 0.0), CGPointZero);
    IDWaitForLoupePresentation();
    XCTAssertNil(IDWaitForLoupeInScene(scene, NO));

    XCTAssertEqualWithAccuracy(customFirstLoupe.size.width,
                               stockFirstLoupe.size.width, 4.0);
    XCTAssertEqualWithAccuracy(customFirstLoupe.size.height,
                               stockFirstLoupe.size.height, 4.0);
    CGPoint stockOffset = CGPointMake(CGRectGetMidX(stockFirstLoupe) - CGRectGetMidX(stockCaret),
                                      CGRectGetMidY(stockFirstLoupe) - CGRectGetMidY(stockCaret));
    CGPoint customOffset = CGPointMake(CGRectGetMidX(customFirstLoupe) - CGRectGetMidX(customCaret),
                                       CGRectGetMidY(customFirstLoupe) - CGRectGetMidY(customCaret));
    XCTAssertEqualWithAccuracy(customOffset.x, stockOffset.x, 2.0,
                               @"stock loupe=%@ caret=%@ custom loupe=%@ caret=%@",
                               NSStringFromCGRect(stockFirstLoupe), NSStringFromCGRect(stockCaret),
                               NSStringFromCGRect(customFirstLoupe), NSStringFromCGRect(customCaret));
    XCTAssertEqualWithAccuracy(customOffset.y, stockOffset.y, 2.0,
                               @"stock loupe=%@ caret=%@ custom loupe=%@ caret=%@",
                               NSStringFromCGRect(stockFirstLoupe), NSStringFromCGRect(stockCaret),
                               NSStringFromCGRect(customFirstLoupe), NSStringFromCGRect(customCaret));
    CGPoint stockMovement = CGPointMake(
        CGRectGetMidX(stockSecondLoupe) - CGRectGetMidX(stockFirstLoupe),
        CGRectGetMidY(stockSecondLoupe) - CGRectGetMidY(stockFirstLoupe));
    CGPoint customMovement = CGPointMake(
        CGRectGetMidX(customSecondLoupe) - CGRectGetMidX(customFirstLoupe),
        CGRectGetMidY(customSecondLoupe) - CGRectGetMidY(customFirstLoupe));
    XCTAssertEqualWithAccuracy(customMovement.x, stockMovement.x, 2.0);
    XCTAssertEqualWithAccuracy(customMovement.y, stockMovement.y, 2.0);
}

@end
