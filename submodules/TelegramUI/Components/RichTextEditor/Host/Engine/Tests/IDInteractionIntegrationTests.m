@import XCTest;

#import "IDTextView.h"
#import "IDTextViewInternal.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+Testing.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextCanvasTestSupport.h"

@interface IDTextView (InteractionTestInspection)
- (UIView *)selectionContainerView;
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated;
@end

@interface IDTask5InteractionAttachment : NSTextAttachment
@property(nonatomic, strong) UIView *providedView;
@end

@interface IDTask5InteractionAttachmentProvider : NSTextAttachmentViewProvider
@end

static NSString * const IDDemoInteractionAttachmentUTI =
    @"com.inputdec.demo.interaction-attachment";

@implementation IDTask5InteractionAttachmentProvider
- (BOOL)tracksTextAttachmentViewBounds {
    return YES;
}
- (instancetype)initWithTextAttachment:(NSTextAttachment *)textAttachment
                              parentView:(UIView *)parentView
                       textLayoutManager:(NSTextLayoutManager *)textLayoutManager
                               location:(id<NSTextLocation>)location {
    self = [super initWithTextAttachment:textAttachment
                              parentView:parentView
                       textLayoutManager:textLayoutManager
                               location:location];
    return self;
}
- (void)loadView {
    self.view = ((IDTask5InteractionAttachment *)self.textAttachment).providedView;
}
- (CGRect)attachmentBoundsForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                                location:(id<NSTextLocation>)location
                           textContainer:(NSTextContainer *)textContainer
                    proposedLineFragment:(CGRect)proposedLineFragment
                                position:(CGPoint)position {
    return CGRectMake(0, -3, 24, 18);
}
@end

@implementation IDTask5InteractionAttachment
- (instancetype)init {
    [NSTextAttachment
        registerTextAttachmentViewProviderClass:IDTask5InteractionAttachmentProvider.class
                                     forFileType:IDDemoInteractionAttachmentUTI];
    self = [super initWithData:[@"attachment" dataUsingEncoding:NSUTF8StringEncoding]
                       ofType:IDDemoInteractionAttachmentUTI];
    if (self != nil) {
        self.fileType = IDDemoInteractionAttachmentUTI;
        _providedView = [UIView new];
        self.allowsTextAttachmentView = YES;
    }
    return self;
}
@end

@interface IDInteractionIntegrationTests : XCTestCase
@end

@interface IDInvalidBackwardDeleteRangesController : NSObject
@end

@implementation IDInvalidBackwardDeleteRangesController
- (id)_rangesForBackwardsDelete {
    return [NSObject new];
}
@end

@interface IDSelectionDisplayInvalidationSpy : NSObject <IDTextViewDelegate>
@property(nonatomic) NSUInteger invalidationCount;
@property(nonatomic) NSUInteger selectionChangeCount;
@property(nonatomic) NSUInteger publicSelectionChangeCount;
@property(nonatomic, strong) id target;
@end

@implementation IDSelectionDisplayInvalidationSpy
- (void)setNeedsSelectionDisplayUpdate {
    self.invalidationCount += 1;
}
- (void)selectionChanged {
    self.selectionChangeCount += 1;
}
- (void)textViewDidChangeSelection:(IDTextView *)textView {
    self.publicSelectionChangeCount += 1;
}
- (id)forwardingTargetForSelector:(SEL)selector {
    return self.target;
}
- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [self.target respondsToSelector:selector];
}
@end

@implementation IDInteractionIntegrationTests

- (void)testStockAndCurrentBuildGestureInteractionTopologyHaveOneStableOwner {
    UITextView *stock = [[UITextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)];
    IDPrivateResetInteractionHostTopologyBaselineForUITesting(stock, nil, nil);
    NSDictionary *stockTopology =
        IDPrivateCopyInteractionHostTopologyForUITesting(stock, nil, nil);
    XCTAssertEqualObjects(stockTopology[@"installationHost"], @"outer");
    XCTAssertEqualObjects(stockTopology[@"liveHostCount"], @1);
    XCTAssertEqualObjects(stockTopology[@"duplicateRecognizerIdentityCount"], @0);
    XCTAssertEqualObjects(stockTopology[@"duplicateInteractionIdentityCount"], @0);
    XCTAssertEqualObjects(stockTopology[@"stableForEpoch"], @YES);

    IDBlockTextView *block = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:@[[[NSAttributedString alloc]
            initWithString:@"topology"]]];
    IDPrivateResetInteractionHostTopologyBaselineForUITesting(
        block, block.id_blockStack, nil);
    NSDictionary *blockTopology =
        IDPrivateCopyInteractionHostTopologyForUITesting(
            block, block.id_blockStack, nil);
    NSString *expectedHost = @"outer";
    XCTAssertEqualObjects(blockTopology[@"installationHost"], expectedHost);
    XCTAssertEqualObjects(blockTopology[@"liveHostCount"], @1);
    XCTAssertEqualObjects(blockTopology[@"duplicateRecognizerIdentityCount"], @0);
    XCTAssertEqualObjects(blockTopology[@"duplicateInteractionIdentityCount"], @0);
    XCTAssertEqualObjects(blockTopology[@"stableForEpoch"], @YES);
}

- (NSArray<UIGestureRecognizer *> *)nativeTextSelectionGesturesInView:(IDTextView *)view {
    return [view.gestureRecognizers filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(UIGestureRecognizer *gesture,
                                               NSDictionary *bindings) {
            NSString *className = NSStringFromClass(gesture.class);
            return [className containsString:@"Text"] ||
                   [className containsString:@"Selection"] ||
                   [className containsString:@"Loupe"] ||
                   [className containsString:@"RangeAdjustment"] ||
                   [className containsString:@"PanOrFlick"] ||
                   [className containsString:@"TapAndAHalf"];
        }]];
}

- (NSDictionary<NSString *, NSNumber *> *)gestureClassCounts:
    (NSArray<UIGestureRecognizer *> *)gestures {
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (UIGestureRecognizer *gesture in gestures) {
        NSString *className = NSStringFromClass(gesture.class);
        counts[className] = @(counts[className].unsignedIntegerValue + 1);
    }
    return counts.copy;
}

- (void)testEditorMirrorsUIKitControllerGraph {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];

    XCTAssertEqualObjects(NSStringFromClass([view.id_layoutController class]),
                          @"_UITextKit2LayoutController");
    XCTAssertEqualObjects(NSStringFromClass([view.id_inputController class]),
                          @"UITextInputController");
    XCTAssertEqualObjects(NSStringFromClass([view.id_interactionAssistant class]),
                          @"UITextInteractionAssistant");
}

- (void)testAssistantInstallsNativeGestureRecognizers {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];

    NSArray<UIGestureRecognizer *> *privateGestures =
        [self nativeTextSelectionGesturesInView:view];
    NSDictionary<NSString *, NSNumber *> *counts =
        [self gestureClassCounts:privateGestures];
    for (NSString *className in @[@"UITextMultiTapRecognizer",
                                  @"UITapAndAHalfRecognizer",
                                  @"UIVariableDelayLoupeGesture",
                                  @"_UIPanOrFlickGestureRecognizer",
                                  @"UITextTapRecognizer",
                                  @"UITextRangeAdjustmentGestureRecognizer"]) {
        XCTAssertEqual(counts[className].unsignedIntegerValue,
                       1U,
                       @"Expected exactly one %@, got %@",
                       className,
                       counts[className]);
        Class recognizerClass = NSClassFromString(className);
        XCTAssertNotNil(recognizerClass);
        XCTAssertEqualObjects([NSBundle bundleForClass:recognizerClass],
                              [NSBundle bundleForClass:UIView.class]);
    }
}

- (void)testSelectableLifecycleClearsAndRestoresNativeGesturesWithoutDuplicates {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    NSArray<UIGestureRecognizer *> *initialGestures =
        [self nativeTextSelectionGesturesInView:view];
    NSDictionary<NSString *, NSNumber *> *initialClassCounts =
        [self gestureClassCounts:initialGestures];
    for (NSString *className in @[@"UITextMultiTapRecognizer",
                                  @"UITapAndAHalfRecognizer",
                                  @"UIVariableDelayLoupeGesture",
                                  @"_UIPanOrFlickGestureRecognizer",
                                  @"UITextTapRecognizer",
                                  @"UITextRangeAdjustmentGestureRecognizer"]) {
        XCTAssertNotNil(initialClassCounts[className], @"%@ was not installed", className);
    }

    view.selectable = NO;
    view.selectable = NO;
    for (UIGestureRecognizer *gesture in initialGestures) {
        XCTAssertTrue(![view.gestureRecognizers containsObject:gesture] || !gesture.isEnabled,
                      @"%@ remained active after selection was disabled",
                      NSStringFromClass(gesture.class));
    }

    view.selectable = YES;
    view.selectable = YES;
    NSArray<UIGestureRecognizer *> *restoredGestures =
        [self nativeTextSelectionGesturesInView:view];
    XCTAssertEqualObjects([self gestureClassCounts:restoredGestures], initialClassCounts);
    XCTAssertEqual([NSSet setWithArray:restoredGestures].count, restoredGestures.count);
}

- (void)testSelectionContainerIsSeparateAndAboveCanvas {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    UIView *selection = view.selectionContainerView;

    XCTAssertNotNil(selection);
    XCTAssertNotEqual(selection, view.id_canvasView);
    XCTAssertGreaterThan([view.subviews indexOfObject:selection],
                         [view.subviews indexOfObject:view.id_canvasView]);
}

// The same one-space rule the block view keeps: UIKit converts a selection rect INTO this container
// and later reads those numbers back relative to `-textInputView` without converting again, so the
// container has to start where that view starts. Here it is the canvas — which sits AT the text
// container inset, not at the scroll host's origin.
- (void)testSelectionContainerSharesTheCanvasCoordinateSpace {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [view layoutIfNeeded];

    UIView *container = view.selectionContainerView;
    // Without an inset the assertions below would hold for the wrong reason.
    XCTAssertGreaterThan(view.textContainerInset.top, 0.0);
    CGPoint origin = [container convertPoint:CGPointZero toView:view.id_canvasView];
    XCTAssertTrue(CGPointEqualToPoint(origin, CGPointZero), @"%@", NSStringFromCGPoint(origin));

    view.textContainerInset = UIEdgeInsetsMake(21, 13, 21, 13);
    [view setNeedsLayout];
    [view layoutIfNeeded];
    CGPoint movedOrigin = [container convertPoint:CGPointZero toView:view.id_canvasView];
    XCTAssertTrue(CGPointEqualToPoint(movedOrigin, CGPointZero), @"%@", NSStringFromCGPoint(movedOrigin));
    XCTAssertTrue(CGSizeEqualToSize(container.bounds.size, view.bounds.size));
}

- (void)testFloatingCursorLifecycleUsesInstalledAssistant {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];

    XCTAssertNoThrow([view beginFloatingCursorAtPoint:CGPointMake(20, 20)]);
    XCTAssertNoThrow([view updateFloatingCursorAtPoint:CGPointMake(24, 22)]);
    XCTAssertNoThrow([view updateFloatingCursorAtPoint:CGPointMake(28, 24) animated:YES]);
    XCTAssertNoThrow([view endFloatingCursor]);
}

- (void)testCaretSelectionAndFloatingCursorSurviveFragmentAndAttachmentSurfaceChurn {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 220, 100)];
    IDTask5InteractionAttachment *attachment = [IDTask5InteractionAttachment new];
    NSMutableAttributedString *contents = [[NSMutableAttributedString alloc]
        initWithString:@"start "];
    [contents appendAttributedString:
        [NSAttributedString attributedStringWithAttachment:attachment]];
    for (NSUInteger index = 0; index < 160; index++) {
        [contents appendAttributedString:[[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"\nrow %lu", (unsigned long)index]]];
    }
    [view.id_textContentStorage performEditingTransactionUsingBlock:^{
        [view.id_textContentStorage.textStorage setAttributedString:contents];
    }];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    (void)IDRenderView(view.id_canvasView.visibleSurfaces.firstObject);
    [view.id_canvasView performViewportLayout];

    UIView *selectionContainer = [view selectionContainerView];
    UITextPosition *caretPosition =
        [view positionFromPosition:view.beginningOfDocument offset:1];
    view.selectedTextRange = [view textRangeFromPosition:caretPosition
                                               toPosition:caretPosition];
    CGRect caretBeforeChurn = [view caretRectForPosition:caretPosition];
    XCTAssertNotNil(attachment.providedView.superview);
    XCTAssertTrue(isfinite(caretBeforeChurn.origin.x));
    XCTAssertTrue(isfinite(caretBeforeChurn.origin.y));

    view.contentOffset = CGPointMake(0, 1200);
    [view layoutIfNeeded];
    XCTAssertEqual([view selectionContainerView], selectionContainer);
    XCTAssertNil(attachment.providedView.superview);

    view.contentOffset = CGPointZero;
    [view layoutIfNeeded];
    UITextPosition *selectionEnd =
        [view positionFromPosition:view.beginningOfDocument offset:5];
    UITextRange *selection = [view textRangeFromPosition:view.beginningOfDocument
                                               toPosition:selectionEnd];
    view.selectedTextRange = selection;
    CGRect selectionRect = [view firstRectForRange:selection];
    XCTAssertEqual([view selectionContainerView], selectionContainer);
    XCTAssertNotNil(attachment.providedView.superview);
    XCTAssertTrue(isfinite(selectionRect.origin.x));
    XCTAssertTrue(isfinite(selectionRect.origin.y));
    XCTAssertNoThrow([view beginFloatingCursorAtPoint:CGPointMake(20, 20)]);
    XCTAssertNoThrow([view updateFloatingCursorAtPoint:CGPointMake(24, 22)]);
    XCTAssertNoThrow([view endFloatingCursor]);
}

- (void)testSelectionMutationDoesNotReenterInstalledAssistant {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"selection";
    UITextPosition *end = view.endOfDocument;
    UITextRange *range = [view textRangeFromPosition:end toPosition:end];

    XCTAssertEqualObjects(NSStringFromClass([view.id_interactionAssistant class]),
                          @"UITextInteractionAssistant");
    XCTAssertNoThrow(view.selectedTextRange = range);
    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument
                                  toPosition:view.selectedTextRange.start],
                   (NSInteger)view.text.length);
}

- (void)testHostedControllerCaretGeometryIsAlreadyInEditorCoordinates {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    view.textContainerInset = UIEdgeInsetsMake(12, 9, 12, 9);
    view.text = @"first\nsecond\nthird";
    [view layoutIfNeeded];

    CGRect controllerCaret = IDPrivateRectObject(view.id_inputController,
                                                  @selector(caretRectForPosition:),
                                                  view.beginningOfDocument);
    CGRect caret = [view caretRectForPosition:view.beginningOfDocument];

    XCTAssertEqual(IDPrivateTextContainerTextView(view.id_textContainer),
                   view.id_canvasView);
    XCTAssertTrue(CGRectEqualToRect(caret, controllerCaret));
    XCTAssertEqualWithAccuracy(CGRectGetMinX(caret), view.textContainerInset.left + 4.0, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(caret), view.textContainerInset.top - 1.0, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(caret), 2.0, 0.5);
}

- (void)testSelectionGeometryUsesHostedTextContainerWithoutWrapping {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    view.textContainerInset = UIEdgeInsetsMake(12, 9, 12, 9);
    view.text = @"first\nsecond\nthird";
    [view layoutIfNeeded];

    [view caretRectForPosition:view.beginningOfDocument];
    UITextPosition *end = [view positionFromPosition:view.beginningOfDocument offset:5];
    UITextRange *firstWord = [view textRangeFromPosition:view.beginningOfDocument
                                              toPosition:end];
    CGRect controllerFirstRect = IDPrivateRectObject(view.id_inputController,
                                                      @selector(firstRectForRange:),
                                                      firstWord);
    NSArray *layoutRects = IDPrivateLayoutSelectionRects(view.id_layoutController,
                                                          firstWord,
                                                          view.id_canvasView);
    CGRect firstRect = [view firstRectForRange:firstWord];
    NSArray<UITextSelectionRect *> *selectionRects = [view selectionRectsForRange:firstWord];

    XCTAssertEqual(IDPrivateTextContainerTextView(view.id_textContainer),
                   view.id_canvasView);
    XCTAssertGreaterThan(IDPrivateTextKit2RangeCount(firstWord), 0U);
    XCTAssertGreaterThan(layoutRects.count, 0U);
    XCTAssertTrue(isfinite(controllerFirstRect.origin.x));
    XCTAssertTrue(isfinite(controllerFirstRect.origin.y));
    XCTAssertTrue(isfinite(firstRect.origin.x));
    XCTAssertTrue(isfinite(firstRect.origin.y));
    XCTAssertTrue(CGRectEqualToRect(firstRect, controllerFirstRect));
    XCTAssertEqualWithAccuracy(CGRectGetMinX(firstRect), view.textContainerInset.left + 5.0, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(firstRect), view.textContainerInset.top - 1.0, 0.5);
    XCTAssertGreaterThan(selectionRects.count, 0U);
    XCTAssertTrue(isfinite(selectionRects.firstObject.rect.origin.x));
    XCTAssertTrue(isfinite(selectionRects.firstObject.rect.origin.y));
    XCTAssertTrue(CGRectEqualToRect(firstRect, selectionRects.firstObject.rect));
}

- (void)testChangingTextContainerInsetMovesLiveCaretAndSelectionGeometryExactlyOnce {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    view.text = @"first second";
    [view layoutIfNeeded];
    UITextPosition *end = [view positionFromPosition:view.beginningOfDocument offset:5];
    UITextRange *range = [view textRangeFromPosition:view.beginningOfDocument toPosition:end];
    CGRect oldCaret = [view caretRectForPosition:view.beginningOfDocument];
    CGRect oldSelection = [view firstRectForRange:range];

    UIEdgeInsets oldInsets = view.textContainerInset;
    UIEdgeInsets newInsets = UIEdgeInsetsMake(20, 17, 13, 11);
    view.textContainerInset = newInsets;
    [view layoutIfNeeded];
    CGRect newCaret = [view caretRectForPosition:view.beginningOfDocument];
    CGRect newSelection = [view firstRectForRange:range];

    XCTAssertEqualWithAccuracy(newCaret.origin.x - oldCaret.origin.x,
                               newInsets.left - oldInsets.left,
                               0.5);
    XCTAssertEqualWithAccuracy(newCaret.origin.y - oldCaret.origin.y,
                               newInsets.top - oldInsets.top,
                               0.5);
    XCTAssertEqualWithAccuracy(newSelection.origin.x - oldSelection.origin.x,
                               newInsets.left - oldInsets.left,
                               0.5);
    XCTAssertEqualWithAccuracy(newSelection.origin.y - oldSelection.origin.y,
                               newInsets.top - oldInsets.top,
                               0.5);
}

- (void)testEveryTextContainerInsetAssignmentInvalidatesSelectionDisplay {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    IDSelectionDisplayInvalidationSpy *spy = [IDSelectionDisplayInvalidationSpy new];
    spy.target = view.id_interactionAssistant;
    view.id_interactionAssistant = spy;

    UIEdgeInsets changed = UIEdgeInsetsMake(20, 17, 13, 11);
    view.textContainerInset = changed;
    view.textContainerInset = changed;

    XCTAssertEqual(spy.invalidationCount, 2U);
}

- (void)testRepeatedSelectionCallbacksReachAssistantAndPublicDelegateEachTime {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    view.text = @"selection";
    IDSelectionDisplayInvalidationSpy *spy = [IDSelectionDisplayInvalidationSpy new];
    spy.target = view.id_interactionAssistant;
    view.id_interactionAssistant = spy;
    view.delegate = spy;
    [view id_notifySelectionChanged];
    [view id_notifySelectionChanged];

    XCTAssertEqual(spy.selectionChangeCount, 2U);
    XCTAssertEqual(spy.publicSelectionChangeCount, 2U);
}

- (void)testControllerSelectionChangeAutomaticallyKeepsInsertedCaretAboveBottomInset {
    UIViewController *controller = [UIViewController new];
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 80)];
    view.autoresizingMask = UIViewAutoresizingNone;
    view.contentInset = UIEdgeInsetsMake(0, 0, 24, 0);
    [controller.view addSubview:view];

    __block UIWindow *window = nil;
    __block UIWindow *priorKeyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        priorKeyWindow = windowScene.keyWindow;
        window = [[UIWindow alloc] initWithWindowScene:windowScene];
        window.frame = CGRectMake(0, 0, 180, 80);
        window.rootViewController = controller;
        [window makeKeyAndVisible];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        break;
    }
    XCTAssertNotNil(window);
    [self addTeardownBlock:^{
        [view resignFirstResponder];
        window.hidden = YES;
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
        window = nil;
    }];

    NSMutableString *lines = [NSMutableString string];
    for (NSUInteger index = 0; index < 40; index++) {
        [lines appendFormat:@"line %lu\n", (unsigned long)index];
    }
    view.text = lines;
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];
    [view layoutIfNeeded];
    view.contentOffset = CGPointZero;
    XCTAssertTrue([view becomeFirstResponder]);
    IDSelectionDisplayInvalidationSpy *spy = [IDSelectionDisplayInvalidationSpy new];
    view.delegate = spy;
    NSUInteger selectionCallbacksBeforeInsertion = spy.publicSelectionChangeCount;

    [view insertText:@"x"];

    CGRect caret = [view caretRectForPosition:view.selectedTextRange.end];
    CGFloat visibleBottom = view.contentOffset.y + CGRectGetHeight(view.bounds) -
                            view.adjustedContentInset.bottom;
    XCTAssertGreaterThan(view.contentOffset.y, 0.0);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(caret), visibleBottom + 0.5);
    XCTAssertEqual(spy.publicSelectionChangeCount - selectionCallbacksBeforeInsertion, 1U);
}

- (void)testNavigationOnlySelectionChangeAutomaticallyKeepsCaretVisibleWithoutExtraCallbacks {
    UIViewController *controller = [UIViewController new];
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 80)];
    view.contentInset = UIEdgeInsetsMake(0, 0, 24, 0);
    [controller.view addSubview:view];

    __block UIWindow *window = nil;
    __block UIWindow *priorKeyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        priorKeyWindow = windowScene.keyWindow;
        window = [[UIWindow alloc] initWithWindowScene:windowScene];
        window.frame = CGRectMake(0, 0, 180, 80);
        window.rootViewController = controller;
        [window makeKeyAndVisible];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        break;
    }
    XCTAssertNotNil(window);
    [self addTeardownBlock:^{
        [view resignFirstResponder];
        window.hidden = YES;
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
        window = nil;
    }];

    NSMutableString *lines = [NSMutableString string];
    for (NSUInteger index = 0; index < 40; index++) {
        [lines appendFormat:@"line %lu\n", (unsigned long)index];
    }
    view.text = lines;
    UITextPosition *start = view.beginningOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:start toPosition:start];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    IDSelectionDisplayInvalidationSpy *spy = [IDSelectionDisplayInvalidationSpy new];
    view.delegate = spy;
    view.contentOffset = CGPointZero;

    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];

    CGRect caret = [view caretRectForPosition:view.selectedTextRange.end];
    CGFloat visibleBottom = view.contentOffset.y + CGRectGetHeight(view.bounds) -
                            view.adjustedContentInset.bottom;
    XCTAssertGreaterThan(view.contentOffset.y, 0.0);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(caret), visibleBottom + 0.5);
    XCTAssertEqual(spy.publicSelectionChangeCount, 1U);
}

- (void)testBackwardDeleteAggregateRequiresUnionRangeBeforeTypedDispatch {
    NSException *caught = nil;
    @try {
        (void)IDPrivateInputBackwardDeleteRange([IDInvalidBackwardDeleteRangesController new]);
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Backward-delete ranges"]);
    XCTAssertTrue([caught.reason containsString:@"unionRange"]);
}

- (void)testSelectionAffinityGetterMatchesControllerAtWrapBoundary {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 82, 140)];
    view.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    view.text = @"one two three four five six";
    [view layoutIfNeeded];

    CGFloat firstY = [view caretRectForPosition:view.beginningOfDocument].origin.y;
    UITextPosition *boundary = nil;
    for (NSInteger offset = 1; offset < (NSInteger)view.text.length; offset++) {
        UITextPosition *candidate = [view positionFromPosition:view.beginningOfDocument
                                                        offset:offset];
        if ([view caretRectForPosition:candidate].origin.y > firstY + 1.0) {
            boundary = candidate;
            break;
        }
    }
    XCTAssertNotNil(boundary);
    view.selectedTextRange = [view textRangeFromPosition:boundary toPosition:boundary];
    NSRange selectedRange = [view id_NSRangeForTextRange:view.selectedTextRange];
    UITextStorageDirection controllerAffinity =
        IDPrivateInputSelectionAffinity(view.id_inputController);

    XCTAssertEqual(view.selectionAffinity, controllerAffinity);
    XCTAssertTrue(NSEqualRanges([view id_NSRangeForTextRange:view.selectedTextRange], selectedRange));
}

- (void)testScrollRangeToVisibleKeepsLastInsertionEdgeAboveBottomInset {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 80)];
    NSMutableString *lines = [NSMutableString string];
    for (NSUInteger index = 0; index < 40; index++) {
        [lines appendFormat:@"line %lu\n", (unsigned long)index];
    }
    view.text = lines;
    view.contentInset = UIEdgeInsetsMake(0, 0, 24, 0);
    view.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 24, 0);
    [view layoutIfNeeded];

    NSRange insertion = NSMakeRange(view.text.length, 0);
    [view scrollRangeToVisible:insertion];
    CGRect caret = [view caretRectForPosition:view.endOfDocument];
    CGFloat visibleBottom = view.contentOffset.y + CGRectGetHeight(view.bounds) -
                            view.adjustedContentInset.bottom;

    XCTAssertGreaterThan(view.contentOffset.y, 0.0);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(caret), visibleBottom + 0.5);
    XCTAssertEqualWithAccuracy(view.verticalScrollIndicatorInsets.bottom, 24.0, 0.5);
}

@end
