@import XCTest;

#import "IDTextView.h"
#import "IDPrivateUIKit.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextViewInternal.h"

@interface IDTextViewTests : XCTestCase
@end

@interface IDTextView (PrivateInputDelegateTesting)
- (BOOL)textInput:(id)input
    shouldChangeCharactersInRanges:(NSArray<NSValue *> *)ranges
                   replacementText:(NSString *)text;
- (void)textInputDidChangeSelection:(id)input;
- (void)setAttributedMarkedText:(NSAttributedString *)text
                  selectedRange:(NSRange)range;
@end

@interface IDInitialSpellingProbeTextView : IDTextView
@property(nonatomic) NSMutableArray<NSNumber *> *id_initialSpellingValues;
@end

@implementation IDInitialSpellingProbeTextView

- (NSMutableArray<NSNumber *> *)id_initialSpellingValues {
    if (_id_initialSpellingValues == nil) {
        _id_initialSpellingValues = [NSMutableArray array];
    }
    return _id_initialSpellingValues;
}

- (void)id_setInitialContinuousSpellCheckingEnabled:(BOOL)enabled
                                  onInputController:(id)inputController {
    [self.id_initialSpellingValues addObject:@(enabled)];
}

@end

@interface UIResponder (IDUndoActionDeclarations)
- (void)undo:(nullable id)sender;
- (void)redo:(nullable id)sender;
@end

static BOOL IDWaitUntil(NSTimeInterval timeout, BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!condition() && [deadline timeIntervalSinceNow] > 0.0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
                              beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return condition();
}

@interface IDRecordingDelegate : NSObject <IDTextViewDelegate>
@property(nonatomic) NSMutableArray<NSString *> *events;
@property(nonatomic) NSMutableArray<NSString *> *selectionSnapshots;
@property(nonatomic) BOOL allowChange;
@end

@implementation IDRecordingDelegate

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _events = [NSMutableArray array];
        _selectionSnapshots = [NSMutableArray array];
        _allowChange = YES;
    }
    return self;
}

- (BOOL)textView:(IDTextView *)view
        shouldChangeTextInRange:(NSRange)range
        replacementText:(NSString *)text {
    [self.events addObject:@"should"];
    return self.allowChange;
}

- (void)textViewDidBeginEditing:(IDTextView *)view {
    [self.events addObject:@"begin"];
}

- (void)textViewDidChange:(IDTextView *)view {
    [self.events addObject:@"change"];
}

- (void)textViewDidChangeSelection:(IDTextView *)view {
    [self.events addObject:@"selection"];
    NSInteger location = [view offsetFromPosition:view.beginningOfDocument
                                        toPosition:view.selectedTextRange.start];
    NSInteger length = [view offsetFromPosition:view.selectedTextRange.start
                                      toPosition:view.selectedTextRange.end];
    [self.selectionSnapshots addObject:NSStringFromRange(
        NSMakeRange((NSUInteger)location, (NSUInteger)length))];
}

- (void)textViewDidEndEditing:(IDTextView *)view {
    [self.events addObject:@"end"];
}

@end

@interface IDTraitTrackingTextView : IDTextView
@property(nonatomic) BOOL id_reportsFirstResponder;
@property(nonatomic) NSUInteger id_reloadInputViewsCount;
@end

@implementation IDTraitTrackingTextView

- (BOOL)isFirstResponder {
    return self.id_reportsFirstResponder;
}

- (void)reloadInputViews {
    self.id_reloadInputViewsCount += 1;
}

@end

static UIWindow *IDTestWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
            window.frame = CGRectMake(0, 0, 320, 240);
            return window;
        }
    }
    return nil;
}

@interface IDTestDictationPhrase : UIDictationPhrase
@property(nonatomic, copy) NSString *id_text;
@end

@implementation IDTestDictationPhrase
- (NSString *)text {
    return self.id_text;
}
@end

@implementation IDTextViewTests

- (void)tearDown {
    UIPasteboard.generalPasteboard.items = @[];
    [super tearDown];
}

- (void)testPublicClassConformsToUITextInput {
    XCTAssertTrue([IDTextView conformsToProtocol:@protocol(UITextInput)]);
}

- (void)testNonzeroTextContainerInsetOwnsCanvasOriginAndViewportOnce {
    IDTextView *view =
        [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 240, 120)];
    view.textContainerInset = UIEdgeInsetsMake(17, 13, 11, 19);
    view.text = [@"line\n" stringByPaddingToLength:300
                                        withString:@"line\n"
                                   startingAtIndex:0];

    [view layoutIfNeeded];
    XCTAssertEqualWithAccuracy(CGRectGetMinX(view.id_canvasView.frame), 13, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(view.id_canvasView.frame), 17, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(view.id_canvasView.frame), 208, 0.5);
    XCTAssertTrue(CGPointEqualToPoint([view.id_canvasView id_textContainerOrigin],
                                      CGPointMake(13, 17)));

    view.contentOffset = CGPointMake(0, 40);
    CGRect viewport = view.id_canvasView.viewportBounds;
    XCTAssertEqualWithAccuracy(CGRectGetMinY(viewport), 23, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(viewport), 208, 0.5);
}

- (void)testInitialSpellCheckingNoSendsExactlyOneDisabledState {
    IDInitialSpellingProbeTextView *view = [[IDInitialSpellingProbeTextView alloc]
        initWithFrame:CGRectZero
        initialSpellCheckingType:UITextSpellCheckingTypeNo];

    XCTAssertEqual(view.spellCheckingType, UITextSpellCheckingTypeNo);
    XCTAssertEqualObjects(view.id_initialSpellingValues, (@[@NO]));
}

- (void)testInitialSpellCheckingYesSendsExactlyOneEnabledState {
    IDInitialSpellingProbeTextView *view = [[IDInitialSpellingProbeTextView alloc]
        initWithFrame:CGRectZero
        initialSpellCheckingType:UITextSpellCheckingTypeYes];

    XCTAssertEqual(view.spellCheckingType, UITextSpellCheckingTypeYes);
    XCTAssertEqualObjects(view.id_initialSpellingValues, (@[@YES]));
}

- (void)testInitialSpellCheckingDefaultLeavesControllerStateUnchanged {
    IDInitialSpellingProbeTextView *view = [[IDInitialSpellingProbeTextView alloc]
        initWithFrame:CGRectZero
        initialSpellCheckingType:UITextSpellCheckingTypeDefault];

    XCTAssertEqual(view.spellCheckingType, UITextSpellCheckingTypeDefault);
    XCTAssertEqual(view.id_initialSpellingValues.count, 0U);
}

- (void)testAutocorrectionMutationDoesNotMutateInitialSpellingState {
    IDInitialSpellingProbeTextView *view = [[IDInitialSpellingProbeTextView alloc]
        initWithFrame:CGRectZero
        initialSpellCheckingType:UITextSpellCheckingTypeNo];

    view.autocorrectionType = UITextAutocorrectionTypeYes;

    XCTAssertEqual(view.autocorrectionType, UITextAutocorrectionTypeYes);
    XCTAssertEqual(view.spellCheckingType, UITextSpellCheckingTypeNo);
    XCTAssertEqualObjects(view.id_initialSpellingValues, (@[@NO]));
}

- (void)testTraitsHaveUIKitDefaultsAndRoundTrip {
    IDTextView *view = [IDTextView new];

    XCTAssertEqual(view.autocapitalizationType, UITextAutocapitalizationTypeSentences);
    XCTAssertEqual(view.autocorrectionType, UITextAutocorrectionTypeDefault);
    XCTAssertEqual(view.spellCheckingType, UITextSpellCheckingTypeDefault);
    XCTAssertEqual(view.smartQuotesType, UITextSmartQuotesTypeDefault);
    XCTAssertEqual(view.smartDashesType, UITextSmartDashesTypeDefault);
    XCTAssertEqual(view.smartInsertDeleteType, UITextSmartInsertDeleteTypeDefault);
    XCTAssertEqual(view.inlinePredictionType, UITextInlinePredictionTypeDefault);
    XCTAssertEqual(view.mathExpressionCompletionType, UITextMathExpressionCompletionTypeDefault);
    XCTAssertEqual(view.keyboardType, UIKeyboardTypeDefault);
    XCTAssertEqual(view.keyboardAppearance, UIKeyboardAppearanceDefault);
    XCTAssertEqual(view.returnKeyType, UIReturnKeyDefault);
    XCTAssertFalse(view.enablesReturnKeyAutomatically);
    XCTAssertFalse(view.isSecureTextEntry);
    XCTAssertNil(view.textContentType);
    XCTAssertNil(view.passwordRules);
    XCTAssertEqual(view.writingToolsBehavior, UIWritingToolsBehaviorDefault);
    XCTAssertEqual(view.allowedWritingToolsResultOptions, UIWritingToolsResultDefault);
    XCTAssertNil(view.conversationContext);
    XCTAssertTrue(view.allowsNumberPadPopover);

    UITextInputPasswordRules *passwordRules =
        [UITextInputPasswordRules passwordRulesWithDescriptor:@"required: upper;"];
    UIConversationContext *conversationContext = [UIConversationContext new];
    view.autocapitalizationType = UITextAutocapitalizationTypeWords;
    view.autocorrectionType = UITextAutocorrectionTypeYes;
    view.spellCheckingType = UITextSpellCheckingTypeYes;
    view.smartQuotesType = UITextSmartQuotesTypeYes;
    view.smartDashesType = UITextSmartDashesTypeYes;
    view.smartInsertDeleteType = UITextSmartInsertDeleteTypeYes;
    view.inlinePredictionType = UITextInlinePredictionTypeYes;
    view.mathExpressionCompletionType = UITextMathExpressionCompletionTypeYes;
    view.keyboardType = UIKeyboardTypeEmailAddress;
    view.keyboardAppearance = UIKeyboardAppearanceDark;
    view.returnKeyType = UIReturnKeyDone;
    view.enablesReturnKeyAutomatically = YES;
    view.secureTextEntry = YES;
    view.textContentType = UITextContentTypeEmailAddress;
    view.passwordRules = passwordRules;
    view.writingToolsBehavior = UIWritingToolsBehaviorLimited;
    view.allowedWritingToolsResultOptions = UIWritingToolsResultPlainText;
    view.conversationContext = conversationContext;
    view.allowsNumberPadPopover = NO;

    XCTAssertEqual(view.autocapitalizationType, UITextAutocapitalizationTypeWords);
    XCTAssertEqual(view.autocorrectionType, UITextAutocorrectionTypeYes);
    XCTAssertEqual(view.spellCheckingType, UITextSpellCheckingTypeYes);
    XCTAssertEqual(view.smartQuotesType, UITextSmartQuotesTypeYes);
    XCTAssertEqual(view.smartDashesType, UITextSmartDashesTypeYes);
    XCTAssertEqual(view.smartInsertDeleteType, UITextSmartInsertDeleteTypeYes);
    XCTAssertEqual(view.inlinePredictionType, UITextInlinePredictionTypeYes);
    XCTAssertEqual(view.mathExpressionCompletionType, UITextMathExpressionCompletionTypeYes);
    XCTAssertEqual(view.keyboardType, UIKeyboardTypeEmailAddress);
    XCTAssertEqual(view.keyboardAppearance, UIKeyboardAppearanceDark);
    XCTAssertEqual(view.returnKeyType, UIReturnKeyDone);
    XCTAssertTrue(view.enablesReturnKeyAutomatically);
    XCTAssertTrue(view.isSecureTextEntry);
    XCTAssertEqualObjects(view.textContentType, UITextContentTypeEmailAddress);
    XCTAssertEqualObjects(view.passwordRules.passwordRulesDescriptor,
                          passwordRules.passwordRulesDescriptor);
    XCTAssertEqual(view.writingToolsBehavior, UIWritingToolsBehaviorLimited);
    XCTAssertEqual(view.allowedWritingToolsResultOptions, UIWritingToolsResultPlainText);
    XCTAssertEqual(view.conversationContext, conversationContext);
    XCTAssertFalse(view.allowsNumberPadPopover);
}

- (void)testChangedTraitsReloadOnlyForLiveFirstResponder {
    IDTraitTrackingTextView *view = [IDTraitTrackingTextView new];
    view.autocorrectionType = UITextAutocorrectionTypeNo;
    XCTAssertEqual(view.id_reloadInputViewsCount, 0U);

    view.id_reportsFirstResponder = YES;
    view.autocorrectionType = UITextAutocorrectionTypeNo;
    XCTAssertEqual(view.id_reloadInputViewsCount, 0U);

    view.autocorrectionType = UITextAutocorrectionTypeYes;
    view.spellCheckingType = UITextSpellCheckingTypeYes;
    view.smartQuotesType = UITextSmartQuotesTypeYes;
    view.smartDashesType = UITextSmartDashesTypeYes;
    view.smartInsertDeleteType = UITextSmartInsertDeleteTypeYes;
    view.inlinePredictionType = UITextInlinePredictionTypeYes;
    view.mathExpressionCompletionType = UITextMathExpressionCompletionTypeYes;
    view.keyboardType = UIKeyboardTypeEmailAddress;
    view.keyboardAppearance = UIKeyboardAppearanceDark;
    view.returnKeyType = UIReturnKeyDone;
    view.enablesReturnKeyAutomatically = YES;
    view.secureTextEntry = YES;
    view.textContentType = UITextContentTypeEmailAddress;
    view.passwordRules = [UITextInputPasswordRules
        passwordRulesWithDescriptor:@"required: upper;"];
    view.writingToolsBehavior = UIWritingToolsBehaviorLimited;
    view.allowedWritingToolsResultOptions = UIWritingToolsResultPlainText;
    view.conversationContext = [UIConversationContext new];
    view.allowsNumberPadPopover = NO;
    view.autocapitalizationType = UITextAutocapitalizationTypeWords;

    XCTAssertEqual(view.id_reloadInputViewsCount, 19U);
}

- (void)testSelectableReadOnlyViewCanBecomeFirstResponder {
    IDTextView *view = [IDTextView new];
    view.editable = NO;
    view.selectable = YES;
    XCTAssertTrue(view.canBecomeFirstResponder);

    view.selectable = NO;
    XCTAssertFalse(view.canBecomeFirstResponder);

    view.editable = YES;
    view.userInteractionEnabled = NO;
    XCTAssertFalse(view.canBecomeFirstResponder);
}

- (void)testEditableResponderNotifiesBeginAndEndExactlyOnce {
    UIWindow *window = IDTestWindow();
    XCTAssertNotNil(window);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    IDTextView *view = [[IDTextView alloc] initWithFrame:window.bounds];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];

    XCTAssertTrue([view becomeFirstResponder]);
    [view becomeFirstResponder];
    XCTAssertTrue([view resignFirstResponder]);
    [view resignFirstResponder];

    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"end"]));
    window.hidden = YES;
}

- (void)testResponderTransitionsKeepProjectEditingCanvasPathActive {
    UIWindow *window = IDTestWindow();
    XCTAssertNotNil(window);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    IDTextView *view = [[IDTextView alloc] initWithFrame:window.bounds];
    [controller.view addSubview:view];
    [window makeKeyAndVisible];
    view.id_canvasView.id_hoverEffectContainerLayer = [CALayer layer];

    XCTAssertTrue([view becomeFirstResponder]);
    [view.id_canvasView layoutIfNeeded];
    XCTAssertTrue(view.id_canvasView.id_hoverEffectContainerLayer.hidden);

    XCTAssertTrue([view resignFirstResponder]);
    [view.id_canvasView layoutIfNeeded];
    XCTAssertFalse(view.id_canvasView.id_hoverEffectContainerLayer.hidden);
    window.hidden = YES;
}

- (void)testSelectableReadOnlyResponderDoesNotSendEditingLifecycle {
    UIWindow *window = IDTestWindow();
    XCTAssertNotNil(window);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    IDTextView *view = [[IDTextView alloc] initWithFrame:window.bounds];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    view.editable = NO;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];

    XCTAssertTrue([view becomeFirstResponder]);
    XCTAssertTrue([view resignFirstResponder]);

    XCTAssertEqualObjects(delegate.events, (@[]));
    window.hidden = YES;
}

- (void)testDelegateCanRejectControllerEditBeforeMutation {
    IDTextView *view = [IDTextView new];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    view.text = @"a";
    delegate.allowChange = NO;

    BOOL accepted = [view textInput:nil
        shouldChangeCharactersInRanges:@[[NSValue valueWithRange:NSMakeRange(1, 0)]]
                       replacementText:@"b"];

    XCTAssertFalse(accepted);
    XCTAssertEqualObjects(view.text, @"a");
    XCTAssertEqualObjects(delegate.events, (@[@"should"]));
}

- (void)testAcceptedControllerEditNotifiesDelegateExactlyOnceInOrder {
    IDTextView *view = [IDTextView new];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    view.text = @"a";
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];
    [delegate.events removeAllObjects];

    BOOL accepted = [view textInput:nil
        shouldChangeCharactersInRanges:@[[NSValue valueWithRange:NSMakeRange(1, 0)]]
                       replacementText:@"b"];
    XCTAssertTrue(accepted);
    [view insertText:@"b"];

    XCTAssertEqualObjects(view.text, @"ab");
    XCTAssertEqualObjects(delegate.events, (@[@"should", @"selection", @"change"]));
}

- (void)testControllerSelectionChangeNotifiesDelegateOnlyForRealChanges {
    IDTextView *view = [IDTextView new];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    view.text = @"ab";
    UITextPosition *end = view.endOfDocument;
    UITextRange *range = [view textRangeFromPosition:end toPosition:end];

    view.selectedTextRange = range;
    XCTAssertEqualObjects(delegate.events, (@[@"selection"]));
    [delegate.events removeAllObjects];

    view.selectedTextRange = range;
    XCTAssertEqualObjects(delegate.events, (@[]));
}

- (void)testDelegateGatesEveryControllerEditRangeUntilRejection {
    IDTextView *view = [IDTextView new];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    delegate.allowChange = YES;
    NSArray<NSValue *> *ranges = @[
        [NSValue valueWithRange:NSMakeRange(0, 0)],
        [NSValue valueWithRange:NSMakeRange(1, 0)],
    ];

    BOOL accepted = [view textInput:nil
        shouldChangeCharactersInRanges:ranges
                       replacementText:@"x"];

    XCTAssertTrue(accepted);
    XCTAssertEqualObjects(delegate.events, (@[@"should", @"should"]));
}

- (void)testInsertAndDeleteUseSelectedRange {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"ac";
    UITextPosition *middle = [view positionFromPosition:view.beginningOfDocument offset:1];
    view.selectedTextRange = [view textRangeFromPosition:middle toPosition:middle];

    [view insertText:@"b"];
    XCTAssertEqualObjects(view.text, @"abc");

    [view deleteBackward];
    XCTAssertEqualObjects(view.text, @"ac");
}

- (void)testReturnThenBackspaceRestoresCompletedLayoutContentGeometry {
    IDTextView *view =
        [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 40)];
    view.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    view.text = @"one\ntwo\nthree";
    view.selectedTextRange =
        [view textRangeFromPosition:view.endOfDocument
                        toPosition:view.endOfDocument];
    [view layoutIfNeeded];
    CGSize originalContentSize = view.contentSize;
    CGRect originalCanvasFrame = view.id_canvasView.frame;

    [view insertText:@"\n"];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    XCTAssertGreaterThan(view.contentSize.height, originalContentSize.height);
    XCTAssertGreaterThan(CGRectGetHeight(view.id_canvasView.frame),
                         CGRectGetHeight(originalCanvasFrame));

    [view deleteBackward];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    XCTAssertEqualWithAccuracy(view.contentSize.height,
                               originalContentSize.height, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(view.id_canvasView.frame),
                               CGRectGetHeight(originalCanvasFrame), 0.5);
}

- (void)testWidthChangeReconcilesFinalCanvasAndScrollGeometry {
    IDTextView *view =
        [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 140, 40)];
    view.textContainerInset = UIEdgeInsetsMake(8, 6, 8, 6);
    view.text =
        @"alpha beta gamma delta epsilon zeta eta theta iota kappa lambda";
    [view layoutIfNeeded];
    CGFloat narrowHeight = view.contentSize.height;

    view.frame = CGRectMake(0, 0, 280, 40);
    [view setNeedsLayout];
    [view layoutIfNeeded];

    XCTAssertLessThan(view.contentSize.height, narrowHeight);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(view.id_canvasView.frame),
                               268.0, 0.5);
    XCTAssertEqualWithAccuracy(view.contentSize.width, 280.0, 0.5);
    XCTAssertTrue(isfinite(view.contentSize.height));
}

- (void)testOffsetsClampToDocumentAndCompareCorrectly {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"A👩🏽‍💻B";
    UITextPosition *start = view.beginningOfDocument;
    UITextPosition *end = view.endOfDocument;

    XCTAssertEqual([view comparePosition:start toPosition:end], NSOrderedAscending);
    XCTAssertEqual([view offsetFromPosition:start toPosition:end], view.text.length);
    XCTAssertNil([view positionFromPosition:start offset:-1]);
    XCTAssertNil([view positionFromPosition:end offset:1]);
}

- (void)testSelectedTextRangeRoundTripsThroughInputController {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"selection";
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument offset:2];
    UITextPosition *end = [view positionFromPosition:start offset:4];
    UITextRange *range = [view textRangeFromPosition:start toPosition:end];

    view.selectedTextRange = range;

    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument
                                 toPosition:view.selectedTextRange.start], 2);
    XCTAssertEqual([view offsetFromPosition:view.selectedTextRange.start
                                 toPosition:view.selectedTextRange.end], 4);
}

- (void)testMarkedTextOwnsSelectionWithinComposition {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];

    [view setMarkedText:@"かな" selectedRange:NSMakeRange(1, 1)];

    XCTAssertNotNil(view.markedTextRange);
    XCTAssertEqualObjects([view textInRange:view.markedTextRange], @"かな");
    [view unmarkText];
    XCTAssertNil(view.markedTextRange);
}

- (void)testAttributedMarkedTextUsesPrivateInputControllerPath {
    IDTextView *view =
        [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"alpha";
    view.selectedTextRange = [view textRangeFromPosition:view.endOfDocument
                                              toPosition:view.endOfDocument];

    [view setAttributedMarkedText:
        [[NSAttributedString alloc] initWithString:@" beta"]
                            selectedRange:NSMakeRange(0, 0)];

    XCTAssertEqualObjects(view.text, @"alpha beta");
    XCTAssertEqualObjects([view textInRange:view.markedTextRange], @" beta");
    [view unmarkText];
    XCTAssertNil(view.markedTextRange);
}

- (void)testCharacterOffsetOptionalsUseForwardedRangePrimitives {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"abcdef";
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument offset:1];
    UITextPosition *end = [view positionFromPosition:start offset:3];
    UITextRange *range = [view textRangeFromPosition:start toPosition:end];

    UITextPosition *position = [view positionWithinRange:range atCharacterOffset:2];

    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:position], 3);
    XCTAssertEqual([view characterOffsetOfPosition:position withinRange:range], 2);
    XCTAssertNil([view positionWithinRange:range atCharacterOffset:4]);
    XCTAssertEqual([view characterOffsetOfPosition:view.endOfDocument withinRange:range],
                   (NSInteger)NSNotFound);
}

- (void)testDictationFallbackInsertsConcatenatedPhraseText {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    IDTestDictationPhrase *first = [IDTestDictationPhrase new];
    first.id_text = @"hello ";
    IDTestDictationPhrase *second = [IDTestDictationPhrase new];
    second.id_text = @"world";

    [view insertDictationResult:@[first, second]];

    XCTAssertEqualObjects(view.text, @"hello world");
}

- (void)testCopyCutAndPasteAvailabilityAndMutations {
    UIWindow *window = IDTestWindow();
    XCTAssertNotNil(window);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    view.text = @"copy me";
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument offset:0];
    UITextPosition *end = [view positionFromPosition:start offset:4];
    view.selectedTextRange = [view textRangeFromPosition:start toPosition:end];
    UIPasteboard.generalPasteboard.string = @"copy";

    XCTAssertFalse([view canPerformAction:@selector(paste:) withSender:nil]);
    [controller.view addSubview:view];
    [window makeKeyAndVisible];
    XCTAssertTrue([view becomeFirstResponder]);
    [delegate.events removeAllObjects];
    [delegate.selectionSnapshots removeAllObjects];

    XCTAssertTrue([view canPerformAction:@selector(copy:) withSender:nil]);
    XCTAssertTrue([view canPerformAction:@selector(cut:) withSender:nil]);
    [view copy:nil];
    XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, @"copy");

    [view cut:nil];
    XCTAssertEqualObjects(view.text, @"me");
    XCTAssertEqualObjects(delegate.events,
                          (@[@"should", @"selection", @"selection", @"change"]));
    XCTAssertEqualObjects(delegate.selectionSnapshots, (@[@"{0, 5}", @"{0, 0}"]));
    XCTAssertEqualObjects(view.undoManager.undoActionName, @"Cut");
    XCTAssertTrue([view canPerformAction:@selector(paste:) withSender:nil]);
    XCTAssertNotNil(IDPrivateObject0(view.id_inputController,
                                     NSSelectorFromString(@"_pasteController")));
    XCTAssertEqual(IDPrivateObject0(view, NSSelectorFromString(@"_inputController")),
                   view.id_inputController);
    [delegate.events removeAllObjects];
    [delegate.selectionSnapshots removeAllObjects];
    [view paste:nil];
    XCTAssertTrue(IDWaitUntil(2.0, ^BOOL{
        return [view.text isEqualToString:@"copy me"];
    }));
    XCTAssertEqualObjects(view.text, @"copy me");
    XCTAssertEqualObjects(view.undoManager.undoActionName, @"Paste");
    XCTAssertEqualObjects(delegate.events, (@[@"should", @"selection", @"change"]));
    XCTAssertEqualObjects(delegate.selectionSnapshots, (@[@"{5, 0}"]));

    start = [view positionFromPosition:view.beginningOfDocument offset:0];
    end = [view positionFromPosition:start offset:4];
    view.selectedTextRange = [view textRangeFromPosition:start toPosition:end];
    view.editable = NO;
    XCTAssertTrue([view canPerformAction:@selector(copy:) withSender:nil]);
    XCTAssertFalse([view canPerformAction:@selector(cut:) withSender:nil]);
    XCTAssertFalse([view canPerformAction:@selector(paste:) withSender:nil]);
    [view resignFirstResponder];
    window.hidden = YES;
}

- (void)testSelectAndSelectAllAvailabilityAndMutations {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    view.text = @"one two";
    UITextPosition *middle = [view positionFromPosition:view.beginningOfDocument offset:5];
    view.selectedTextRange = [view textRangeFromPosition:middle toPosition:middle];

    XCTAssertTrue([view canPerformAction:@selector(select:) withSender:nil]);
    XCTAssertTrue([view canPerformAction:@selector(selectAll:) withSender:nil]);
    [delegate.events removeAllObjects];
    [delegate.selectionSnapshots removeAllObjects];
    [view select:nil];
    XCTAssertFalse(view.selectedTextRange.empty);
    XCTAssertEqualObjects(delegate.events, (@[@"selection"]));
    XCTAssertEqualObjects(delegate.selectionSnapshots, (@[@"{4, 3}"]));

    [delegate.events removeAllObjects];
    [delegate.selectionSnapshots removeAllObjects];
    [view selectAll:nil];
    XCTAssertEqualObjects([view textInRange:view.selectedTextRange], @"one two");
    XCTAssertEqualObjects(delegate.events, (@[@"selection"]));
    XCTAssertEqualObjects(delegate.selectionSnapshots, (@[@"{0, 7}"]));

    view.selectable = NO;
    XCTAssertFalse([view canPerformAction:@selector(select:) withSender:nil]);
    XCTAssertFalse([view canPerformAction:@selector(selectAll:) withSender:nil]);
}

- (void)testWindowResponderChainUndoAndRedoUseControllerHistoryAndNotifications {
    UIWindow *window = IDTestWindow();
    XCTAssertNotNil(window);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    IDTextView *view = [[IDTextView alloc] initWithFrame:window.bounds];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];
    XCTAssertTrue([view becomeFirstResponder]);

    view.text = @"a";
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];
    [view insertText:@"b"];
    [delegate.events removeAllObjects];
    [delegate.selectionSnapshots removeAllObjects];

    [window undo:nil];
    XCTAssertEqualObjects(view.text, @"a");
    XCTAssertEqualObjects(delegate.events,
                          (@[@"should", @"selection", @"selection", @"change"]));
    XCTAssertEqualObjects(delegate.selectionSnapshots, (@[@"{1, 0}", @"{1, 0}"]));
    XCTAssertTrue(view.undoManager.canRedo);

    [delegate.events removeAllObjects];
    [delegate.selectionSnapshots removeAllObjects];
    [window redo:nil];
    XCTAssertEqualObjects(view.text, @"ab");
    XCTAssertEqualObjects(delegate.events,
                          (@[@"should", @"selection", @"selection", @"change"]));
    XCTAssertEqualObjects(delegate.selectionSnapshots, (@[@"{2, 0}", @"{2, 0}"]));

    [view resignFirstResponder];
    window.hidden = YES;
}

- (void)testMarkedTextDoesNotCollapseRepeatedControllerSelectionCallbacks {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    IDRecordingDelegate *delegate = [IDRecordingDelegate new];
    view.delegate = delegate;
    view.text = @"abc";
    UITextPosition *position = [view positionFromPosition:view.beginningOfDocument offset:1];
    view.selectedTextRange = [view textRangeFromPosition:position toPosition:position];
    [view setMarkedText:@"x" selectedRange:NSMakeRange(1, 0)];
    XCTAssertNotNil(view.markedTextRange);
    [delegate.events removeAllObjects];
    [delegate.selectionSnapshots removeAllObjects];

    [view textInputDidChangeSelection:view];
    [view textInputDidChangeSelection:view];

    XCTAssertEqualObjects(delegate.events, (@[@"selection", @"selection"]));
    XCTAssertEqual(delegate.selectionSnapshots.count, 2U);
    XCTAssertEqualObjects(delegate.selectionSnapshots.firstObject,
                          delegate.selectionSnapshots.lastObject);
}

- (void)testControllerOwnedUndoAndRedoRestoreEdits {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"a";
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];
    [view insertText:@"b"];

    NSUndoManager *undoManager = view.undoManager;
    XCTAssertNotNil(undoManager);
    XCTAssertTrue(undoManager.canUndo);
    XCTAssertTrue([view canPerformAction:@selector(undo:) withSender:nil]);
    [undoManager undo];
    XCTAssertEqualObjects(view.text, @"a");

    XCTAssertTrue(undoManager.canRedo);
    XCTAssertTrue([view canPerformAction:@selector(redo:) withSender:nil]);
    [undoManager redo];
    XCTAssertEqualObjects(view.text, @"ab");
}

@end
