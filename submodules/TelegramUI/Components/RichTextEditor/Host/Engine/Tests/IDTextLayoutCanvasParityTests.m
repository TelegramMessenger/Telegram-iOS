@import XCTest;

#import "IDTextCanvasTestSupport.h"
#import "IDSpellingReadinessProbe.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextRenderingSurfaceView.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"

static NSString * const IDParityAttachmentUTI = @"com.inputdec.demo.attachment";

@interface IDTextView (IDParityContinuousSpelling)
- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled;
@end

@interface IDParityAttachment : NSTextAttachment
@property(nonatomic, strong) UIView *providedView;
@end

@interface IDParityAttachmentProvider : NSTextAttachmentViewProvider
@end

@implementation IDParityAttachmentProvider

- (BOOL)tracksTextAttachmentViewBounds {
    return YES;
}

- (void)loadView {
    self.view = ((IDParityAttachment *)self.textAttachment).providedView;
}

- (CGRect)attachmentBoundsForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                                location:(id<NSTextLocation>)location
                           textContainer:(NSTextContainer *)textContainer
                    proposedLineFragment:(CGRect)proposedLineFragment
                                position:(CGPoint)position {
    return CGRectMake(0, -2, 31, 19);
}

@end

@implementation IDParityAttachment

- (instancetype)init {
    [NSTextAttachment registerTextAttachmentViewProviderClass:IDParityAttachmentProvider.class
                                                  forFileType:IDParityAttachmentUTI];
    self = [super initWithData:[@"parity" dataUsingEncoding:NSUTF8StringEncoding]
                       ofType:IDParityAttachmentUTI];
    if (self != nil) {
        self.fileType = IDParityAttachmentUTI;
        self.allowsTextAttachmentView = YES;
        _providedView = [[UIView alloc] initWithFrame:CGRectZero];
        _providedView.backgroundColor = UIColor.systemBlueColor;
    }
    return self;
}

@end

@interface IDTextLayoutCanvasParityTests : XCTestCase
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIViewController *rootController;
@property(nonatomic) BOOL animationsWereEnabled;
@end

@implementation IDTextLayoutCanvasParityTests

- (void)setUp {
    [super setUp];
    self.animationsWereEnabled = UIView.areAnimationsEnabled;
    [UIView setAnimationsEnabled:NO];

    UIWindowScene *windowScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    XCTAssertNotNil(windowScene);
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.frame = CGRectMake(0, 0, 320, 400);
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.rootController = [UIViewController new];
    self.rootController.view.backgroundColor = UIColor.whiteColor;
    self.window.rootViewController = self.rootController;
    [self.window makeKeyAndVisible];
}

- (void)tearDown {
    [self.window resignKeyWindow];
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    self.rootController = nil;
    self.window = nil;
    [UIView setAnimationsEnabled:self.animationsWereEnabled];
    [super tearDown];
}

- (NSString *)longText {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSUInteger index = 0; index < 36; index++) {
        [lines addObject:[NSString stringWithFormat:
            @"Line %02lu has stable wrapped TextKit geometry for viewport parity.",
            (unsigned long)index]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

- (CGFloat)displayPixelTolerance {
    return 1.0 / MAX(self.window.traitCollection.displayScale, 1.0);
}

- (void)configureCommonEditor:(UIScrollView *)editor {
    editor.frame = CGRectMake(20, 20, 240, 120);
    editor.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    editor.backgroundColor = UIColor.whiteColor;
    editor.tintColor = UIColor.systemBlueColor;
    editor.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    editor.alwaysBounceHorizontal = NO;
    editor.alwaysBounceVertical = NO;
}

- (void)configureCustomEditor:(IDTextView *)editor spellChecking:(BOOL)spellChecking {
    [self configureCommonEditor:editor];
    editor.font = [UIFont systemFontOfSize:17.0];
    editor.textColor = UIColor.blackColor;
    editor.textAlignment = NSTextAlignmentNatural;
    editor.textContainerInset = UIEdgeInsetsMake(8, 7, 8, 7);
    editor.id_textContainer.lineFragmentPadding = 5;
    editor.autocorrectionType = UITextAutocorrectionTypeNo;
    editor.spellCheckingType = spellChecking ? UITextSpellCheckingTypeYes
                                             : UITextSpellCheckingTypeNo;
    editor.smartQuotesType = UITextSmartQuotesTypeNo;
    editor.smartDashesType = UITextSmartDashesTypeNo;
    editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    editor.inlinePredictionType = UITextInlinePredictionTypeNo;
}

- (void)configureStockEditor:(UITextView *)editor spellChecking:(BOOL)spellChecking {
    [self configureCommonEditor:editor];
    editor.font = [UIFont systemFontOfSize:17.0];
    editor.textColor = UIColor.blackColor;
    editor.textAlignment = NSTextAlignmentNatural;
    editor.textContainerInset = UIEdgeInsetsMake(8, 7, 8, 7);
    editor.textContainer.lineFragmentPadding = 5;
    editor.autocorrectionType = UITextAutocorrectionTypeNo;
    editor.spellCheckingType = spellChecking ? UITextSpellCheckingTypeYes
                                             : UITextSpellCheckingTypeNo;
    editor.smartQuotesType = UITextSmartQuotesTypeNo;
    editor.smartDashesType = UITextSmartDashesTypeNo;
    editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    editor.inlinePredictionType = UITextInlinePredictionTypeNo;
    XCTAssertNotNil(editor.textLayoutManager, @"The stock oracle must use TextKit 2");
}

- (IDTextView *)customEditorWithText:(NSString *)text {
    IDTextView *editor = [[IDTextView alloc] initWithFrame:CGRectZero];
    [self configureCustomEditor:editor spellChecking:NO];
    editor.text = text;
    [self.rootController.view addSubview:editor];
    [self pumpEditor:editor];
    return editor;
}

- (UITextView *)stockEditorWithText:(NSString *)text {
    UITextView *editor = [[UITextView alloc] initWithFrame:CGRectZero
                                             textContainer:nil];
    [self configureStockEditor:editor spellChecking:NO];
    editor.text = text;
    [self.rootController.view addSubview:editor];
    [self pumpEditor:editor];
    return editor;
}

- (void)pumpEditor:(UIScrollView *)editor {
    [self.rootController.view setNeedsLayout];
    [self.rootController.view layoutIfNeeded];
    [editor setNeedsLayout];
    [editor layoutIfNeeded];
    if ([editor isKindOfClass:IDTextView.class]) {
        IDTextView *custom = (IDTextView *)editor;
        [custom.id_canvasView performViewportLayout];
        [custom.id_canvasView layoutIfNeeded];
    } else {
        UITextView *stock = (UITextView *)editor;
        [stock.textLayoutManager.textViewportLayoutController layoutViewport];
        [stock layoutIfNeeded];
    }
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static BOOL IDParityIsFragmentSurface(UIView *view, BOOL inspectingInputDec) {
    if (inspectingInputDec) {
        return [view isKindOfClass:IDTextRenderingSurfaceView.class];
    }
    SEL selector = NSSelectorFromString(@"isLayoutFragmentView");
    if (![view respondsToSelector:selector]) {
        return NO;
    }
    BOOL (*implementation)(id, SEL) = (BOOL (*)(id, SEL))[view methodForSelector:selector];
    return implementation(view, selector);
}

static void IDParityCollectFragmentViews(UIView *view,
                                         BOOL inspectingInputDec,
                                         NSMutableArray<UIView *> *result) {
    if (IDParityIsFragmentSurface(view, inspectingInputDec) &&
        !view.hidden &&
        view.alpha > 0) {
        [result addObject:view];
    }
    for (UIView *subview in view.subviews) {
        IDParityCollectFragmentViews(subview, inspectingInputDec, result);
    }
}

static NSComparisonResult IDParityCompareRects(NSValue *leftValue, NSValue *rightValue) {
    CGRect left = leftValue.CGRectValue;
    CGRect right = rightValue.CGRectValue;
    const CGFloat leftValues[] = {
        CGRectGetMinY(left), CGRectGetMinX(left), CGRectGetWidth(left), CGRectGetHeight(left)
    };
    const CGFloat rightValues[] = {
        CGRectGetMinY(right), CGRectGetMinX(right), CGRectGetWidth(right), CGRectGetHeight(right)
    };
    for (NSUInteger index = 0; index < 4; index++) {
        if (leftValues[index] < rightValues[index]) return NSOrderedAscending;
        if (leftValues[index] > rightValues[index]) return NSOrderedDescending;
    }
    return NSOrderedSame;
}

- (NSArray<NSValue *> *)fragmentFramesForEditor:(UIScrollView *)editor {
    NSMutableArray<UIView *> *fragmentViews = [NSMutableArray array];
    BOOL inspectingInputDec = [editor isKindOfClass:IDTextView.class];
    IDParityCollectFragmentViews(editor, inspectingInputDec, fragmentViews);
    NSMutableArray<NSValue *> *frames = [NSMutableArray arrayWithCapacity:fragmentViews.count];
    for (UIView *fragmentView in fragmentViews) {
        [frames addObject:[NSValue valueWithCGRect:
            [fragmentView convertRect:fragmentView.bounds toView:editor]]];
    }
    [frames sortUsingComparator:^NSComparisonResult(NSValue *left, NSValue *right) {
        return IDParityCompareRects(left, right);
    }];
    return frames;
}

- (NSArray<NSValue *> *)stabilizedFragmentFramesForEditor:(UIScrollView *)editor {
    NSArray<NSValue *> *previous = nil;
    for (NSUInteger attempt = 0; attempt < 8; attempt++) {
        [self pumpEditor:editor];
        NSArray<NSValue *> *current = [self fragmentFramesForEditor:editor];
        if (previous != nil && [previous isEqualToArray:current]) {
            return current;
        }
        previous = current;
    }
    return previous ?: @[];
}

- (void)assertRects:(NSArray<NSValue *> *)custom
          matchStock:(NSArray<NSValue *> *)stock
           tolerance:(CGFloat)tolerance {
    XCTAssertEqual(custom.count, stock.count);
    NSUInteger count = MIN(custom.count, stock.count);
    for (NSUInteger index = 0; index < count; index++) {
        CGRect customRect = custom[index].CGRectValue;
        CGRect stockRect = stock[index].CGRectValue;
        XCTAssertEqualWithAccuracy(CGRectGetMinX(customRect), CGRectGetMinX(stockRect), tolerance);
        XCTAssertEqualWithAccuracy(CGRectGetMinY(customRect), CGRectGetMinY(stockRect), tolerance);
        XCTAssertEqualWithAccuracy(CGRectGetWidth(customRect), CGRectGetWidth(stockRect), tolerance);
        XCTAssertEqualWithAccuracy(CGRectGetHeight(customRect), CGRectGetHeight(stockRect), tolerance);
    }
}

- (void)testVisibleFragmentSurfaceCountAndGeometryMatchStockWithinOneDisplayPixel {
    IDTextView *custom = [self customEditorWithText:self.longText];
    UITextView *stock = [self stockEditorWithText:self.longText];
    NSArray<NSValue *> *customFrames = [self stabilizedFragmentFramesForEditor:custom];
    NSArray<NSValue *> *stockFrames = [self stabilizedFragmentFramesForEditor:stock];

    XCTAssertGreaterThan(customFrames.count, 0U);
    XCTAssertGreaterThan(stockFrames.count, 0U);
    [self assertRects:customFrames
           matchStock:stockFrames
            tolerance:self.displayPixelTolerance];
}

- (void)testFragmentSurfaceSnapshotsMatchStockBeforeAndAfterFixedScroll {
    IDTextView *custom = [self customEditorWithText:self.longText];
    UITextView *stock = [self stockEditorWithText:self.longText];
    NSArray<NSValue *> *customBefore = [self stabilizedFragmentFramesForEditor:custom];
    NSArray<NSValue *> *stockBefore = [self stabilizedFragmentFramesForEditor:stock];
    CGFloat tolerance = self.displayPixelTolerance;
    [self assertRects:customBefore matchStock:stockBefore tolerance:tolerance];

    CGPoint fixedOffset = CGPointMake(0, 84);
    [custom setContentOffset:fixedOffset animated:NO];
    [stock setContentOffset:fixedOffset animated:NO];
    XCTAssertEqualWithAccuracy(custom.contentOffset.y, fixedOffset.y, tolerance);
    XCTAssertEqualWithAccuracy(stock.contentOffset.y, fixedOffset.y, tolerance);
    NSArray<NSValue *> *customAfter = [self stabilizedFragmentFramesForEditor:custom];
    NSArray<NSValue *> *stockAfter = [self stabilizedFragmentFramesForEditor:stock];

    [self assertRects:customAfter matchStock:stockAfter tolerance:tolerance];
    XCTAssertFalse([customBefore isEqualToArray:customAfter]);
    XCTAssertFalse([stockBefore isEqualToArray:stockAfter]);
}

- (void)testOverflowingContentSizeMatchesStockWithinOneDisplayPixel {
    IDTextView *custom = [self customEditorWithText:self.longText];
    UITextView *stock = [self stockEditorWithText:self.longText];
    CGFloat tolerance = self.displayPixelTolerance;

    XCTAssertGreaterThan(custom.contentSize.height, CGRectGetHeight(custom.bounds));
    XCTAssertGreaterThan(stock.contentSize.height, CGRectGetHeight(stock.bounds));
    XCTAssertEqualWithAccuracy(custom.contentSize.width, stock.contentSize.width, tolerance);
    XCTAssertEqualWithAccuracy(custom.contentSize.height, stock.contentSize.height, tolerance);
}

- (void)testCaretAtFixedUTF16OffsetMatchesStockWithinOneDisplayPixel {
    NSString *text = @"One wrapped left-to-right line has enough words for caret geometry parity.";
    IDTextView *custom = [self customEditorWithText:text];
    UITextView *stock = [self stockEditorWithText:text];
    NSInteger offset = 42;
    UITextPosition *customPosition = [custom positionFromPosition:custom.beginningOfDocument
                                                          offset:offset];
    UITextPosition *stockPosition = [stock positionFromPosition:stock.beginningOfDocument
                                                        offset:offset];
    XCTAssertNotNil(customPosition);
    XCTAssertNotNil(stockPosition);
    CGRect customCaret = [custom caretRectForPosition:customPosition];
    CGRect stockCaret = [stock caretRectForPosition:stockPosition];
    [self assertRects:@[[NSValue valueWithCGRect:customCaret]]
           matchStock:@[[NSValue valueWithCGRect:stockCaret]]
            tolerance:self.displayPixelTolerance];
}

static NSArray<UITextSelectionRect *> *IDParitySortedSelectionRects(
    NSArray<UITextSelectionRect *> *rects) {
    return [rects sortedArrayUsingComparator:^NSComparisonResult(
        UITextSelectionRect *left, UITextSelectionRect *right) {
        return IDParityCompareRects([NSValue valueWithCGRect:left.rect],
                                    [NSValue valueWithCGRect:right.rect]);
    }];
}

- (void)testTwoLineSelectionRectsAndFlagsMatchStock {
    NSString *text = @"alpha beta gamma\nsecond row text\nthird";
    IDTextView *custom = [self customEditorWithText:text];
    UITextView *stock = [self stockEditorWithText:text];
    NSRange selectedRange = NSMakeRange(6, 22);
    UITextPosition *customEnd = [custom positionFromPosition:custom.beginningOfDocument
                                                     offset:NSMaxRange(selectedRange)];
    UITextPosition *stockEnd = [stock positionFromPosition:stock.beginningOfDocument
                                                   offset:NSMaxRange(selectedRange)];
    UITextPosition *customStart = [custom positionFromPosition:custom.beginningOfDocument
                                                       offset:selectedRange.location];
    UITextPosition *stockStart = [stock positionFromPosition:stock.beginningOfDocument
                                                     offset:selectedRange.location];
    UITextRange *customRange = [custom textRangeFromPosition:customStart toPosition:customEnd];
    UITextRange *stockRange = [stock textRangeFromPosition:stockStart toPosition:stockEnd];
    NSArray<UITextSelectionRect *> *customRects =
        IDParitySortedSelectionRects([custom selectionRectsForRange:customRange]);
    NSArray<UITextSelectionRect *> *stockRects =
        IDParitySortedSelectionRects([stock selectionRectsForRange:stockRange]);

    XCTAssertEqual(stockRects.count, 2U);
    XCTAssertEqual(customRects.count, stockRects.count);
    CGFloat tolerance = self.displayPixelTolerance;
    for (NSUInteger index = 0; index < MIN(customRects.count, stockRects.count); index++) {
        UITextSelectionRect *customRect = customRects[index];
        UITextSelectionRect *stockRect = stockRects[index];
        [self assertRects:@[[NSValue valueWithCGRect:customRect.rect]]
               matchStock:@[[NSValue valueWithCGRect:stockRect.rect]]
                tolerance:tolerance];
        XCTAssertEqual(customRect.containsStart, stockRect.containsStart);
        XCTAssertEqual(customRect.containsEnd, stockRect.containsEnd);
        XCTAssertEqual(customRect.writingDirection, stockRect.writingDirection);
        XCTAssertEqual(customRect.isVertical, stockRect.isVertical);
    }
}

- (CGRect)expandedROIForTextLength:(NSUInteger)length editor:(id<UITextInput>)editor {
    UITextPosition *end = [editor positionFromPosition:editor.beginningOfDocument
                                                offset:(NSInteger)length];
    UITextRange *range = [editor textRangeFromPosition:editor.beginningOfDocument
                                            toPosition:end];
    CGRect rect = [editor firstRectForRange:range];
    return CGRectIntersection(CGRectInset(rect, -3, -5), ((UIView *)editor).bounds);
}

- (UIImage *)waitForMisspelledImageInEditor:(UIScrollView<UITextInput> *)editor
                                        word:(NSString *)word {
    __block UIImage *image = nil;
    BOOL appeared = IDWaitForCondition(3.0, ^BOOL{
        [self pumpEditor:editor];
        image = IDRenderView(editor);
        CGRect roi = [self expandedROIForTextLength:word.length editor:editor];
        return IDCountRedPixels(image, roi) > 0;
    });
    XCTAssertTrue(appeared);
    return image;
}

- (UIImage *)waitForCorrectedImageInEditor:(UIScrollView<UITextInput> *)editor
                                      word:(NSString *)word {
    __block UIImage *image = nil;
    BOOL disappeared = IDWaitForCondition(3.0, ^BOOL{
        [self pumpEditor:editor];
        image = IDRenderView(editor);
        CGRect roi = [self expandedROIForTextLength:word.length editor:editor];
        return IDCountRedPixels(image, roi) == 0;
    });
    XCTAssertTrue(disappeared);
    return image;
}

- (void)replaceInitialMisspellingInEditor:(id<UITextInput>)editor {
    UITextPosition *end = [editor positionFromPosition:editor.beginningOfDocument offset:9];
    UITextRange *range = [editor textRangeFromPosition:editor.beginningOfDocument
                                            toPosition:end];
    [editor replaceRange:range withText:@"misspelled"];
}

- (void)testSpellingMarkerPixelsAndRemovalMatchStockInTextRangeROI {
    if (!IDAssertEnglishCheckerAvailable(self)) return;
    UITextView *stock = [[UITextView alloc] initWithFrame:CGRectZero textContainer:nil];
    [self configureStockEditor:stock spellChecking:YES];
    [self.rootController.view addSubview:stock];
    [self pumpEditor:stock];
    XCTAssertTrue([stock becomeFirstResponder]);
    stock.text = @"";
    [stock insertText:@"mispelled "];
    UIImage *stockMisspelled = [self waitForMisspelledImageInEditor:stock word:@"mispelled"];
    CGRect stockMisspelledROI = [self expandedROIForTextLength:9 editor:stock];
    NSUInteger stockMisspelledRed = IDCountRedPixels(stockMisspelled, stockMisspelledROI);
    UITextPosition *stockWordEnd =
        [stock positionFromPosition:stock.beginningOfDocument offset:9];
    CGRect stockFirstRect = [stock firstRectForRange:
        [stock textRangeFromPosition:stock.beginningOfDocument
                          toPosition:stockWordEnd]];
    [self replaceInitialMisspellingInEditor:stock];
    UIImage *stockCorrected = [self waitForCorrectedImageInEditor:stock word:@"misspelled"];
    CGRect stockCorrectedROI = [self expandedROIForTextLength:10 editor:stock];
    IDAttachSpellingObservation(self, @"canvas-parity-stock", @{
        @"role": @"stock",
        @"text": @"mispelled ",
        @"wordRange": @{ @"location": @0, @"length": @9 },
        @"firstRect": NSStringFromCGRect(stockFirstRect),
        @"roi": NSStringFromCGRect(stockMisspelledROI),
        @"redTotal": @(stockMisspelledRed),
        @"redRows": IDRedPixelCountsByRow(stockMisspelled, stockMisspelledROI),
        @"temporaryRenderingAttributesObserved": @(stockMisspelledRed > 0),
    }, stockMisspelled);
    [stock resignFirstResponder];
    [stock removeFromSuperview];

    IDTextView *custom = [[IDTextView alloc] initWithFrame:CGRectZero];
    [self configureCustomEditor:custom spellChecking:YES];
    [self.rootController.view addSubview:custom];
    [self pumpEditor:custom];
    XCTAssertTrue([custom becomeFirstResponder]);
    [custom setContinuousSpellCheckingEnabled:YES];
    [custom insertText:@"mispelled "];
    UIImage *customMisspelled =
        [self waitForMisspelledImageInEditor:custom word:@"mispelled"];
    CGRect customMisspelledROI = [self expandedROIForTextLength:9 editor:custom];
    NSUInteger customMisspelledRed =
        IDCountRedPixels(customMisspelled, customMisspelledROI);
    UITextPosition *customWordEnd =
        [custom positionFromPosition:custom.beginningOfDocument offset:9];
    CGRect customFirstRect = [custom firstRectForRange:
        [custom textRangeFromPosition:custom.beginningOfDocument
                           toPosition:customWordEnd]];
    IDAttachSpellingObservation(self, @"canvas-parity-custom", @{
        @"role": @"custom",
        @"text": custom.text ?: @"",
        @"wordRange": @{ @"location": @0, @"length": @9 },
        @"firstRect": NSStringFromCGRect(customFirstRect),
        @"roi": NSStringFromCGRect(customMisspelledROI),
        @"redTotal": @(customMisspelledRed),
        @"redRows": IDRedPixelCountsByRow(customMisspelled,
                                           customMisspelledROI),
        @"temporaryRenderingAttributesObserved": @(customMisspelledRed > 0),
    }, customMisspelled);
    [self replaceInitialMisspellingInEditor:custom];
    UIImage *customCorrected =
        [self waitForCorrectedImageInEditor:custom word:@"misspelled"];
    CGRect customCorrectedROI = [self expandedROIForTextLength:10 editor:custom];
    [custom resignFirstResponder];
    [custom removeFromSuperview];

    XCTAssertGreaterThan(stockMisspelledRed, 0U);
    XCTAssertGreaterThan(customMisspelledRed, 0U);
    XCTAssertEqualWithAccuracy((double)customMisspelledRed, (double)stockMisspelledRed, 12.0);
    XCTAssertEqual(IDCountRedPixels(customCorrected, customCorrectedROI), 0U);
    XCTAssertEqual(IDCountRedPixels(stockCorrected, stockCorrectedROI), 0U);
}

- (NSAttributedString *)attachmentStringWithAttachment:(NSTextAttachment *)attachment {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"prefix "
             attributes:@{
                 NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                 NSForegroundColorAttributeName: UIColor.blackColor,
             }];
    [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
    [text appendAttributedString:[[NSAttributedString alloc]
        initWithString:@" suffix"
             attributes:@{
                 NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                 NSForegroundColorAttributeName: UIColor.blackColor,
             }]];
    return text;
}

- (void)testOrdinaryAttachmentProviderFrameMatchesStockInEditorCoordinates {
    IDParityAttachment *customAttachment = [IDParityAttachment new];
    XCTAssertTrue(customAttachment.usesTextAttachmentView);
    IDTextView *custom = [self customEditorWithText:@""];
    [custom.id_textContentStorage performEditingTransactionUsingBlock:^{
        [custom.id_textContentStorage.textStorage
            setAttributedString:[self attachmentStringWithAttachment:customAttachment]];
    }];
    XCTAssertTrue(IDWaitForCondition(2.0, ^BOOL{
        [self pumpEditor:custom];
        (void)IDRenderView(custom);
        return customAttachment.providedView.superview != nil &&
            !CGRectIsEmpty(customAttachment.providedView.bounds);
    }));
    CGRect customFrame = [customAttachment.providedView
        convertRect:customAttachment.providedView.bounds
          toView:custom];

    IDParityAttachment *stockAttachment = [IDParityAttachment new];
    XCTAssertTrue(stockAttachment.usesTextAttachmentView);
    UITextView *stock = [self stockEditorWithText:@""];
    stock.attributedText = [self attachmentStringWithAttachment:stockAttachment];
    XCTAssertTrue(IDWaitForCondition(2.0, ^BOOL{
        [self pumpEditor:stock];
        (void)IDRenderView(stock);
        return stockAttachment.providedView.superview != nil &&
            !CGRectIsEmpty(stockAttachment.providedView.bounds);
    }));
    CGRect stockFrame = [stockAttachment.providedView
        convertRect:stockAttachment.providedView.bounds
          toView:stock];

    [self assertRects:@[[NSValue valueWithCGRect:customFrame]]
           matchStock:@[[NSValue valueWithCGRect:stockFrame]]
            tolerance:self.displayPixelTolerance];
}

@end
