@import XCTest;
@import UniformTypeIdentifiers;

#import "IDBlockTextTestSupport.h"
#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockStackCanvasViewInternal.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDCanonicalTextStorageAdapterInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+Testing.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDTextView.h"
#import "IDUIKitInteractionCapability.h"
#import "IDUIKitInputControllerCapability.h"
#import "IDEngineSourceLayout.h"


static BOOL IDBlockIntegrationClassLocallyImplementsSelector(
    Class cls,
    SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index += 1) {
        if (method_getName(methods[index]) == selector) {
            found = YES;
            break;
        }
    }
    free(methods);
    return found;
}

static id IDFloatingIntegrationIvar(id object, const char *name) {
    Ivar ivar = class_getInstanceVariable([object class], name);
    return ivar == NULL ? nil : object_getIvar(object, ivar);
}

static id IDFloatingIntegrationSession(id assistant) {
    id session = IDFloatingIntegrationIvar(assistant, "_floatingCursorSession");
    if (session != nil) return session;
    id display = IDFloatingIntegrationIvar(assistant, "_selectionViewManager");
    return IDFloatingIntegrationIvar(display, "_activeFloatingCursorSession");
}

static const void *IDFloatingIntegrationAssistantTokenKey =
    &IDFloatingIntegrationAssistantTokenKey;

static NSString *IDBlockExpectedInteractionInstallationHost(void) {
    return @"outer";
}

static NSSet<NSString *> *IDBlockTopologyAllInteractionIdentities(
    NSDictionary *topology) {
    NSMutableSet<NSString *> *identities = [NSMutableSet set];
    for (NSString *host in @[@"outer", @"blockStack", @"external"]) {
        [identities addObjectsFromArray:
            topology[@"hosts"][host][@"interactionIdentitySignature"] ?: @[]];
    }
    return identities.copy;
}

static NSSet<NSString *> *IDBlockTopologyInstalledInteractionIdentities(
    NSDictionary *topology) {
    NSString *host = topology[@"installationHost"];
    return [NSSet setWithArray:
        topology[@"hosts"][host][@"interactionIdentitySignature"] ?: @[]];
}

static BOOL IDBlockTopologyHasOneActiveOwner(NSDictionary *topology) {
    return [topology[@"installationHost"] isEqualToString:
                IDBlockExpectedInteractionInstallationHost()] &&
        [topology[@"liveHostCount"] isEqual:@1] &&
        [topology[@"duplicateRecognizerIdentityCount"] isEqual:@0] &&
        [topology[@"duplicateInteractionIdentityCount"] isEqual:@0];
}

static BOOL IDBlockTopologyIsStableActive(NSDictionary *topology) {
    return IDBlockTopologyHasOneActiveOwner(topology) &&
        [topology[@"stableForEpoch"] isEqual:@YES];
}

static NSRange IDBlockIntegrationSelection(id<UITextInput> editor) {
    UITextRange *selection = editor.selectedTextRange;
    if (selection == nil) return NSMakeRange(NSNotFound, 0);
    NSInteger location = [editor offsetFromPosition:editor.beginningOfDocument
                                         toPosition:selection.start];
    NSInteger length = [editor offsetFromPosition:selection.start
                                       toPosition:selection.end];
    return NSMakeRange((NSUInteger)MAX(location, 0),
                       (NSUInteger)MAX(length, 0));
}

static void IDBlockIntegrationSetSelection(id<UITextInput> editor,
                                           NSRange range) {
    UITextPosition *start = [editor positionFromPosition:editor.beginningOfDocument
                                                  offset:(NSInteger)range.location];
    UITextPosition *end = [editor positionFromPosition:start
                                                offset:(NSInteger)range.length];
    editor.selectedTextRange = [editor textRangeFromPosition:start
                                                  toPosition:end];
}

static NSDictionary<NSString *, id> *IDBlockIntegrationPublicState(
    id editor,
    NSString *name) {
    NSRange selection = IDBlockIntegrationSelection(editor);
    return @{
        @"state": name,
        @"firstResponder": @([editor isFirstResponder]),
        @"editable": @([editor isEditable]),
        @"selectable": @([editor isSelectable]),
        @"selectionLocation": @(selection.location),
        @"selectionLength": @(selection.length),
        @"copy": @([editor canPerformAction:@selector(copy:) withSender:nil]),
        @"cut": @([editor canPerformAction:@selector(cut:) withSender:nil]),
        @"paste": @([editor canPerformAction:@selector(paste:) withSender:nil]),
    };
}

static NSString *IDBlockIntegrationSourceRoot(void) {
    return IDEngineSourceRoot();
}

static NSString *IDBlockIntegrationMethodRegion(
    NSString *source,
    NSString *signature) {
    NSRange signatureRange = [source rangeOfString:signature];
    if (signatureRange.location == NSNotFound) return nil;
    NSRange openingRange = [source rangeOfString:@"{"
                                        options:0
                                          range:NSMakeRange(
                                              NSMaxRange(signatureRange),
                                              source.length - NSMaxRange(signatureRange))];
    if (openingRange.location == NSNotFound) return nil;
    NSUInteger depth = 0;
    for (NSUInteger index = openingRange.location; index < source.length; index += 1) {
        unichar character = [source characterAtIndex:index];
        if (character == '{') depth += 1;
        if (character == '}') {
            depth -= 1;
            if (depth == 0) {
                return [source substringWithRange:NSMakeRange(
                    signatureRange.location, index - signatureRange.location + 1)];
            }
        }
    }
    return nil;
}

static BOOL IDFloatingReconstructionCycleIsQuiescent(NSDictionary *state,
                                                      BOOL oldAssistantAlive,
                                                      BOOL oldSessionAlive,
                                                      NSUInteger transitionCount,
                                                      NSUInteger responderCount,
                                                      NSUInteger containerCreations,
                                                      NSUInteger expectedContainerCreations) {
    if (oldAssistantAlive || oldSessionAlive ||
        containerCreations != expectedContainerCreations ||
        [state[@"selectableOffActionCount"] unsignedIntegerValue] != transitionCount ||
        [state[@"selectableOffCount"] unsignedIntegerValue] != transitionCount ||
        [state[@"responderLossCount"] unsignedIntegerValue] != responderCount) return NO;
    for (NSString *key in @[@"assistantSessionObject", @"displaySessionObject",
                             @"sessionObject", @"sessionOwnersMatch", @"sessionActive",
                             @"autoscrollActive"]) {
        if ([state[key] boolValue]) return NO;
    }
    return YES;
}

@interface IDBlockLayout (InteractionTestInspection)
- (id)id_canvasHost;
@end

@interface IDBlockStackCanvasView (InteractionContainerTestInspection)
- (NSTextContainer *)textContainer;
- (void)setTextContainer:(NSTextContainer *)textContainer;
- (CGPoint)textContainerOrigin;
@end

@interface IDBlockTextView (InteractionTestInspection)
- (CGPoint)textContainerOrigin;
- (UIView *)textInputView;
- (id)textLayoutController;
- (UIView *)selectionContainerView;
- (CGPoint)id_scrollHostAutoscrollPointForAssistantPoint:(CGPoint)point;
- (void)beginFloatingCursorAtPoint:(CGPoint)point;
- (void)updateFloatingCursorAtPoint:(CGPoint)point;
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated;
- (void)endFloatingCursor;
- (void)keyboardInputChangedSelection:(id)input;
@end

@interface IDBlockKeyboardSelectionDelegateSpy : NSObject <UIScrollViewDelegate>
@property(nonatomic) NSUInteger keyboardSelectionCount;
@property(nonatomic) NSUInteger assistantSelectionCount;
@property(nonatomic, strong, nullable) id forwardingTarget;
@end

@interface IDUIKitInteractionCapability (IntegrationTestInspection)
@property(nonatomic, strong, readwrite, nullable) id privateAssistant;
@end

@implementation IDBlockKeyboardSelectionDelegateSpy
- (void)keyboardInputChangedSelection:(id)input {
    self.keyboardSelectionCount += 1;
}
- (void)selectionChanged {
    self.assistantSelectionCount += 1;
}
- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] ||
        [self.forwardingTarget respondsToSelector:selector];
}
- (id)forwardingTargetForSelector:(SEL)selector {
    return [self.forwardingTarget respondsToSelector:selector]
        ? self.forwardingTarget
        : [super forwardingTargetForSelector:selector];
}
@end

@interface IDBlockTextViewIntegrationTests : XCTestCase
@end

@implementation IDBlockTextViewIntegrationTests

/// Text geometry for an arbitrary canonical range, in the VIEW's coordinates.
///
/// A host that draws over text — spoiler dust, and anything after it — needs this and had no way to
/// get it: `selectionRectsForLocalRange:` is per-block and block-local, and mapping a canonical range
/// onto blocks plus converting each block's coordinates is engine knowledge, not host knowledge.
- (void)testRectsForCanonicalRangeAreInViewCoordinates {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha beta"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}]]];
    [view layoutIfNeeded];

    NSArray<NSValue *> *rects = [view id_rectsForCanonicalRange:NSMakeRange(0, 5)];
    XCTAssertGreaterThan(rects.count, 0, @"no geometry for a range that plainly has some");

    CGRect first = rects.firstObject.CGRectValue;
    XCTAssertGreaterThan(CGRectGetWidth(first), 0.0);
    XCTAssertGreaterThan(CGRectGetHeight(first), 0.0);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(view.bounds, -1.0, -1.0), first),
                  @"the rect is outside the view, so it was not converted into view coordinates");
}

/// THE CONTROL: a different range must give different geometry, or the method could be returning
/// something fixed and the assertions above would not notice.
- (void)testRectsForDifferentRangesDiffer {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha beta"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}]]];
    [view layoutIfNeeded];

    CGRect head = [view id_rectsForCanonicalRange:NSMakeRange(0, 5)].firstObject.CGRectValue;
    CGRect tail = [view id_rectsForCanonicalRange:NSMakeRange(6, 4)].firstObject.CGRectValue;
    XCTAssertNotEqualWithAccuracy(CGRectGetMinX(head), CGRectGetMinX(tail), 0.5,
                                  @"two different ranges reported the same origin");
}

- (void)testBlockInternalTextLayoutControllerUsesClassifiedPermanentState {
    IDBlockTextView *view = [self viewWithStrings:@[@"controller authority"]
                                            frame:CGRectMake(0, 0, 240, 120)];
    __unused UIWindow *window = [self hostView:view];
    SEL selector = NSSelectorFromString(
        [@"_internalTextLayout" stringByAppendingString:@"Controller"]);
    XCTAssertEqual(IDBlockIntegrationClassLocallyImplementsSelector(
                       IDBlockTextView.class, selector),
                   NO);
    XCTAssertFalse([view respondsToSelector:selector]);
    XCTAssertTrue(class_getInstanceMethod(IDBlockTextView.class, selector) == NULL);
    XCTAssertNil([view forwardingTargetForSelector:selector]);
    XCTAssertFalse(IDBlockIntegrationClassLocallyImplementsSelector(
        IDBlockTextView.class, NSSelectorFromString(@"forwardInvocation:")));
    XCTAssertFalse(IDBlockIntegrationClassLocallyImplementsSelector(
        object_getClass(IDBlockTextView.class),
        NSSelectorFromString(@"resolveInstanceMethod:")));
    XCTAssertEqual([view textLayoutController], view.id_richLayoutController);
    XCTAssertTrue(IDBlockIntegrationClassLocallyImplementsSelector(
        IDTextView.class, selector));
}

- (NSDictionary *)topologyForBlockView:(IDBlockTextView *)view {
    return IDPrivateCopyInteractionHostTopologyForUITesting(
        view, view.id_blockStack, nil);
}

- (void)resetTopologyForBlockView:(IDBlockTextView *)view {
    IDPrivateResetInteractionHostTopologyBaselineForUITesting(
        view, view.id_blockStack, nil);
}

- (void)testGestureInteractionTopologySurvivesEditableSelectableAndResponderTransitions {
    IDBlockTextView *view = [self viewWithStrings:@[@"topology transitions"]
                                            frame:CGRectMake(0, 0, 280, 180)];
    __unused UIWindow *window = [self hostView:view];
    [self resetTopologyForBlockView:view];
    NSDictionary *initial = [self topologyForBlockView:view];
    XCTAssertTrue(IDBlockTopologyIsStableActive(initial), @"%@", initial);

    XCTAssertTrue([view becomeFirstResponder]);
    XCTAssertTrue(IDBlockTopologyIsStableActive(
        [self topologyForBlockView:view]));
    view.editable = NO;
    NSDictionary *editableOff = [self topologyForBlockView:view];
    XCTAssertTrue(IDBlockTopologyHasOneActiveOwner(editableOff), @"%@", editableOff);
    [self resetTopologyForBlockView:view];
    XCTAssertTrue(IDBlockTopologyIsStableActive([self topologyForBlockView:view]));
    view.editable = YES;
    XCTAssertTrue([view becomeFirstResponder]);
    XCTAssertTrue([view resignFirstResponder]);
    NSDictionary *resigned = [self topologyForBlockView:view];
    XCTAssertTrue(IDBlockTopologyHasOneActiveOwner(resigned), @"%@", resigned);
    [self resetTopologyForBlockView:view];
    XCTAssertTrue(IDBlockTopologyIsStableActive([self topologyForBlockView:view]));

    NSDictionary *preSelectableOff = [self topologyForBlockView:view];
    NSSet *activeIdentities =
        IDBlockTopologyInstalledInteractionIdentities(preSelectableOff);
    view.selectable = NO;
    NSDictionary *cleared = [self topologyForBlockView:view];
    NSMutableSet *removed = [activeIdentities mutableCopy];
    [removed minusSet:IDBlockTopologyAllInteractionIdentities(cleared)];
    XCTAssertGreaterThan(removed.count, 0U, @"active=%@ cleared=%@",
                         preSelectableOff, cleared);

    view.selectable = YES;
    [self resetTopologyForBlockView:view];
    NSDictionary *restored = [self topologyForBlockView:view];
    XCTAssertTrue(IDBlockTopologyIsStableActive(restored), @"%@", restored);
}

- (void)testGestureInteractionTopologyReconstructsThreeEpochsWithoutLeaks {
    IDBlockTextView *view = [self viewWithStrings:@[@"topology epochs"]
                                            frame:CGRectMake(0, 0, 280, 180)];
    __unused UIWindow *window = [self hostView:view];
    view.selectable = NO;

    for (NSUInteger cycle = 0; cycle < 3; cycle += 1) {
        view.selectable = YES;
        XCTAssertTrue([view becomeFirstResponder]);
        [self resetTopologyForBlockView:view];
        NSDictionary *active = [self topologyForBlockView:view];
        XCTAssertTrue(IDBlockTopologyIsStableActive(active),
                      @"cycle=%lu %@", (unsigned long)cycle, active);
        NSSet *activeIdentities =
            IDBlockTopologyInstalledInteractionIdentities(active);
        __weak id weakAssistant = view.id_interactionAssistant;

        view.selectable = NO;
        NSDictionary *cleared = [self topologyForBlockView:view];
        NSMutableSet *removed = [activeIdentities mutableCopy];
        [removed minusSet:IDBlockTopologyAllInteractionIdentities(cleared)];
        XCTAssertGreaterThan(removed.count, 0U, @"cycle=%lu active=%@ cleared=%@",
                             (unsigned long)cycle, active, cleared);
        XCTAssertNil(weakAssistant, @"cycle=%lu", (unsigned long)cycle);
    }
}

- (void)testGestureInteractionTopologyIsQuiescentAfterWindowDetachAndDeallocation {
    __weak IDBlockTextView *weakView = nil;
    __weak id weakAssistant = nil;
    @autoreleasepool {
        IDBlockTextView *view = [self viewWithStrings:@[@"topology teardown"]
                                                frame:CGRectMake(0, 0, 280, 180)];
        weakView = view;
        weakAssistant = view.id_interactionAssistant;
        UIViewController *controller = [UIViewController new];
        UIWindow *window = [[UIWindow alloc]
            initWithFrame:CGRectMake(0, 0, 280, 180)];
        window.rootViewController = controller;
        [controller.view addSubview:view];
        [window makeKeyAndVisible];
        [self resetTopologyForBlockView:view];
        NSDictionary *active = [self topologyForBlockView:view];
        XCTAssertTrue(IDBlockTopologyIsStableActive(active), @"%@", active);
        NSSet *activeIdentities =
            IDBlockTopologyInstalledInteractionIdentities(active);

        [view removeFromSuperview];
        [view id_tearDownEditorGraph];
        NSDictionary *cleared = [self topologyForBlockView:view];
        NSMutableSet *removed = [activeIdentities mutableCopy];
        [removed minusSet:IDBlockTopologyAllInteractionIdentities(cleared)];
        XCTAssertGreaterThan(removed.count, 0U, @"active=%@ cleared=%@",
                             active, cleared);
        XCTAssertTrue(IDBlockTopologyHasOneActiveOwner(cleared), @"%@", cleared);
        XCTAssertNil(weakAssistant);
        window.hidden = YES;
        window.rootViewController = nil;
    }
    XCTAssertNil(weakView);
    XCTAssertNil(weakAssistant);
}

- (void)testProjectGestureAndCanvasLifecycleDoesNotCallPrivateAliases {
    NSString *root = IDBlockIntegrationSourceRoot();
    NSString *viewSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDBlockTextView.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSString *canvasSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDBlockLayout+PrivateCanvasCallbacks.m")
        encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNotNil(viewSource);
    XCTAssertNotNil(canvasSource);

    NSArray<NSString *> *gestureSignatures = @[
        @"- (void)setEditable:(BOOL)editable",
        @"- (void)setSelectable:(BOOL)selectable",
        @"- (BOOL)becomeFirstResponder",
        @"- (BOOL)resignFirstResponder",
    ];
    for (NSString *signature in gestureSignatures) {
        NSString *region = IDBlockIntegrationMethodRegion(viewSource, signature);
        XCTAssertNotNil(region, @"%@", signature);
        XCTAssertFalse([region containsString:@"[self _updateSelectionGestures]"],
                       @"%@", signature);
    }
    XCTAssertTrue([(IDBlockIntegrationMethodRegion(
        viewSource, @"- (void)setEditable:(BOOL)editable") ?: @"")
        containsString:@"id_updateSelectionGestures"]);
    XCTAssertTrue([(IDBlockIntegrationMethodRegion(
        viewSource, @"- (void)setSelectable:(BOOL)selectable") ?: @"")
        containsString:@"id_updateSelectionGestures"]);
    XCTAssertTrue([(IDBlockIntegrationMethodRegion(
        viewSource, @"- (BOOL)resignFirstResponder") ?: @"")
        containsString:@"id_updateSelectionGestures"]);

    NSString *layout = IDBlockIntegrationMethodRegion(
        viewSource, @"- (void)layoutSubviews");
    XCTAssertTrue([layout containsString:@"[self id_canvasDidLayout]"]);
    XCTAssertFalse([layout containsString:@"_textKit2CanvasDidLayout"]);
    NSString *contextCompletion = IDBlockIntegrationMethodRegion(
        canvasSource, @"- (void)tgpn__textKit2CanvasDidLayout {");
    XCTAssertNotNil(contextCompletion);
    XCTAssertTrue([contextCompletion containsString:@"respondsToSelector:"]);
    XCTAssertFalse([contextCompletion containsString:@"NSSelectorFromString"]);
    XCTAssertFalse([contextCompletion containsString:@"objc_msgSend"]);

    for (NSString *source in @[viewSource, canvasSource]) {
        XCTAssertFalse([source containsString:
            @"_updateSelection" @"Gestures"] &&
            [source containsString:@"stringByAppendingString"]);
        XCTAssertFalse([source containsString:
            @"_textKit2Canvas" @"DidLayout"] &&
            [source containsString:@"stringByAppendingString"]);
    }
}

- (void)testScrolledInteractionContainerDistinguishesValidCaretAndOffViewportPoint {
    NSMutableArray<NSString *> *strings = [@[
        @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
        @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
        @"Third paragraph provides a stable lower destination without leaving the viewport.",
    ] mutableCopy];
    for (NSUInteger index = 0; index < 30; index += 1) {
        [strings addObject:[NSString stringWithFormat:
            @"Floating cursor block %02lu carries enough words to wrap.",
            (unsigned long)index]];
    }
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
    custom.contentOffset = CGPointMake(0, 715);
    stock.contentOffset = CGPointMake(0, 715);
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];

    id customController = custom.id_richLayoutController;
    CGPoint rawInteractionPoint = CGPointMake(327.6666666666667, 603.0);
    id stockContainer = nil;
    id customContainer = nil;
    UITextPosition *stockPosition = IDPrivateTestingCursorPositionAtPoint(
        stock, nil, rawInteractionPoint, &stockContainer);
    UITextPosition *customPosition = IDPrivateTestingCursorPositionAtPoint(
        custom, customController, rawInteractionPoint, &customContainer);
    UITextPosition *stockPublicPosition = [stock closestPositionToPoint:rawInteractionPoint];
    UITextPosition *customPublicPosition = [custom closestPositionToPoint:rawInteractionPoint];
    NSInteger stockOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                           toPosition:stockPosition];
    NSInteger customOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                             toPosition:customPosition];
    NSInteger stockPublicOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                                 toPosition:stockPublicPosition];
    NSInteger customPublicOffset = [custom offsetFromPosition:custom.beginningOfDocument
                                                   toPosition:customPublicPosition];
    CGPoint customOrigin = [custom.id_blockStackCanvasView textContainerOrigin];
    CGRect stockResolvedCaret = [stock caretRectForPosition:stockPosition];
    CGRect customResolvedCaret = [custom caretRectForPosition:customPosition];
    UIView *stockContainerView = IDPrivateTextContainerTextView(stockContainer);
    CGPoint stockOrigin = IDPrivateTestingTextContainerOrigin(stockContainerView);
    id stockRenderController = IDPrivateTestingCustomRenderController(stock);
    CGPoint stockConverted = IDPrivateTestingConvertPointFromRenderSpace(
        stock, rawInteractionPoint);
    NSString *conversionName =
        [@"_convertPointFromRender" stringByAppendingString:@"Space:"];
    SEL conversionSelector = NSSelectorFromString(conversionName);
    XCTAssertFalse([custom respondsToSelector:conversionSelector]);
    NSString *customConversionEvidence = @"absent";
    UITextPosition *stockInitial = [stock positionFromPosition:stock.beginningOfDocument
                                                        offset:900];
    UITextPosition *customInitial = [custom positionFromPosition:custom.beginningOfDocument
                                                          offset:900];
    CGRect stockInitialCaret = [stock caretRectForPosition:stockInitial];
    CGRect customInitialCaret = [custom caretRectForPosition:customInitial];
    NSInteger stockRoundTrip = [stock offsetFromPosition:stock.beginningOfDocument
        toPosition:[stock closestPositionToPoint:CGPointMake(
            CGRectGetMidX(stockInitialCaret), CGRectGetMidY(stockInitialCaret))]];
    NSInteger customRoundTrip = [custom offsetFromPosition:custom.beginningOfDocument
        toPosition:[custom closestPositionToPoint:CGPointMake(
            CGRectGetMidX(customInitialCaret), CGRectGetMidY(customInitialCaret))]];
    XCTAttachment *evidence = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
        @"point=%@ stockOffset=%ld customOffset=%ld stockPublic=%ld customPublic=%ld "
         "stockRender=%@ stockConverted=%@ customConverted=%@ "
         "stockInitialCaret=%@ customInitialCaret=%@ stockRoundTrip=%ld customRoundTrip=%ld "
         "stockFrame=%@ stockBounds=%@ "
         "stockContainerFrame=%@ stockContainerBounds=%@ stockOrigin=%@ "
         "customFrame=%@ customBounds=%@ customOrigin=%@ stockContentOffset=%@ "
         "customContentOffset=%@ stockResolvedCaret=%@ customResolvedCaret=%@",
        NSStringFromCGPoint(rawInteractionPoint), (long)stockOffset, (long)customOffset,
        (long)stockPublicOffset, (long)customPublicOffset,
        stockRenderController == nil ? @"nil" : NSStringFromClass([stockRenderController class]),
        NSStringFromCGPoint(stockConverted), customConversionEvidence,
        NSStringFromCGRect(stockInitialCaret), NSStringFromCGRect(customInitialCaret),
        (long)stockRoundTrip, (long)customRoundTrip,
        NSStringFromCGRect(stock.frame), NSStringFromCGRect(stock.bounds),
        NSStringFromCGRect(stockContainerView.frame), NSStringFromCGRect(stockContainerView.bounds),
        NSStringFromCGPoint(stockOrigin),
        NSStringFromCGRect(custom.id_blockStackCanvasView.frame),
        NSStringFromCGRect(custom.id_blockStackCanvasView.bounds),
        NSStringFromCGPoint(customOrigin), NSStringFromCGPoint(stock.contentOffset),
        NSStringFromCGPoint(custom.contentOffset), NSStringFromCGRect(stockResolvedCaret),
        NSStringFromCGRect(customResolvedCaret)]];
    evidence.name = @"scrolled-cursor-point-boundary";
    evidence.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:evidence];

    XCTAssertNotEqual(customPublicOffset, stockPublicOffset);
    XCTAssertEqual(customRoundTrip, 900);
    XCTAssertEqual(stockRoundTrip, 900);
    XCTAssertNotEqual(customOffset, stockOffset);
}

- (void)testDocumentInteractionContainerUsesWeakInnerViewBinding {
    NSDictionary<NSString *, NSString *> *returnTypes = @{
        @"textContainer": @(@encode(id)),
        @"setTextContainer:": @(@encode(void)),
    };
    for (NSString *selectorName in returnTypes) {
        NSMethodSignature *signature = [IDBlockStackCanvasView
            instanceMethodSignatureForSelector:NSSelectorFromString(selectorName)];
        XCTAssertNotNil(signature, @"%@", selectorName);
        if (signature == nil) return;
        XCTAssertEqual(strcmp(signature.methodReturnType,
                              returnTypes[selectorName].UTF8String), 0,
                       @"%@", selectorName);
    }
    NSMethodSignature *setter = [IDBlockStackCanvasView
        instanceMethodSignatureForSelector:@selector(setTextContainer:)];
    XCTAssertEqual(setter.numberOfArguments, 3U);
    XCTAssertEqual(strcmp([setter getArgumentTypeAtIndex:2], @encode(id)), 0);
    NSMethodSignature *originSignature = [IDBlockStackCanvasView
        instanceMethodSignatureForSelector:@selector(textContainerOrigin)];
    XCTAssertNotNil(originSignature);
    if (originSignature == nil) return;
    XCTAssertEqual(strcmp(originSignature.methodReturnType, @encode(CGPoint)), 0);
    XCTAssertFalse([IDBlockTextView instancesRespondToSelector:
        @selector(setTextContainer:)]);

    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    NSTextContainer *interaction = view.id_richLayoutController.id_interactionTextContainer;
    IDBlockStackCanvasView *stack = view.id_blockStackCanvasView;
    XCTAssertNoThrow(IDPrivateRequireTextContainerHost(
        stack, @"Document interaction-container host test"));
    XCTAssertEqual([stack textContainer], interaction);
    XCTAssertEqual(IDPrivateTextContainerTextView(interaction), stack);
    XCTAssertTrue(CGPointEqualToPoint(
        [stack textContainerOrigin], [stack convertPoint:CGPointZero toView:view]));
    view.textContainerInset = UIEdgeInsetsMake(17, 13, 9, 7);
    [view layoutIfNeeded];
    XCTAssertTrue(CGPointEqualToPoint(
        [stack textContainerOrigin], [stack convertPoint:CGPointZero toView:view]));

    CGRect frame = stack.frame;
    UIView *superview = stack.superview;
    NSArray<UIView *> *subviews = [stack.subviews copy];
    XCTAssertNoThrow([stack setTextContainer:interaction]);
    NSTextContainer *foreign = [NSTextContainer new];
    XCTAssertNoThrow([stack setTextContainer:foreign]);
    XCTAssertEqual([stack textContainer], foreign);
    XCTAssertNoThrow([stack setTextContainer:nil]);
    XCTAssertNil([stack textContainer]);
    XCTAssertTrue(CGRectEqualToRect(stack.frame, frame));
    XCTAssertEqual(stack.superview, superview);
    XCTAssertEqualObjects(stack.subviews, subviews);
    [stack setTextContainer:interaction];

    __weak NSTextContainer *weakForeign = nil;
    @autoreleasepool {
        NSTextContainer *temporary = [NSTextContainer new];
        weakForeign = temporary;
        [stack setTextContainer:temporary];
    }
    XCTAssertNil(weakForeign);
    XCTAssertNil([stack textContainer]);
    [stack setTextContainer:interaction];
}

- (void)testAutoscrollPointIsInterpretedInTextInputViewSpace {
    IDBlockTextView *view = [self viewWithStrings:@[@"one", @"two"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    view.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    [view layoutIfNeeded];

    // The assistant expresses its point in `-textInputView`'s coordinates, which is the block stack.
    // That view now sits at the ORIGIN and carries `textContainerInset` internally, so the conversion
    // into the scroll host is the identity — this used to hardcode the (5, 8) it was translating by,
    // which pinned the old positioning rather than the relationship.
    CGPoint assistantPoint = CGPointMake(90, 120);
    CGPoint expected = [view convertPoint:assistantPoint fromView:view.id_blockStackCanvasView];
    CGPoint actual = [view id_scrollHostAutoscrollPointForAssistantPoint:assistantPoint];

    XCTAssertEqualWithAccuracy(actual.x, expected.x, 0.001);
    XCTAssertEqualWithAccuracy(actual.y, expected.y, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(view.id_blockStackCanvasView.frame), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(view.id_blockStackCanvasView.frame), 0.0, 0.001);
}

- (void)testSelectionChangesMaintainRollingCanonicalAutoscrollPair {
    IDBlockTextView *view = [self viewWithStrings:@[
        @"alpha beta gamma", @"delta epsilon"
    ] frame:CGRectMake(0, 0, 240, 160)];
    view.id_previousCanonicalSelection =
        NSMakeRange(NSNotFound, 0);
    view.id_latestCanonicalSelection =
        NSMakeRange(NSNotFound, 0);

    void (^installSilently)(NSRange) = ^(NSRange selection) {
        UITextPosition *start =
            [view positionFromPosition:view.beginningOfDocument
                               offset:(NSInteger)selection.location];
        UITextPosition *end =
            [view positionFromPosition:start
                               offset:(NSInteger)selection.length];
        UITextRange *range =
            [view textRangeFromPosition:start toPosition:end];
        [view.id_behaviorInput
            performWhileSuppressingDelegateNotifications:^{
                view.id_behaviorInput.selectedTextRange = range;
            }];
        [view id_selectionStateDidChange];
    };

    installSilently(NSMakeRange(4, 8));
    installSilently(NSMakeRange(4, 14));

    XCTAssertTrue(NSEqualRanges(
        view.id_previousCanonicalSelection,
        NSMakeRange(4, 8)));
    XCTAssertTrue(NSEqualRanges(
        view.id_latestCanonicalSelection,
        NSMakeRange(4, 14)));
}

- (NSArray<NSAttributedString *> *)blocksForStrings:(NSArray<NSString *> *)strings {
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:IDBlockTextTestAttributedString(string)];
    }
    return blocks.copy;
}

- (IDBlockTextView *)viewWithStrings:(NSArray<NSString *> *)strings frame:(CGRect)frame {
    return [[IDBlockTextView alloc] initWithFrame:frame
                                 attributedBlocks:[self blocksForStrings:strings]];
}

- (UIWindow *)hostView:(IDBlockTextView *)view {
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
    window.frame = CGRectMake(0, 0, CGRectGetWidth(view.frame), CGRectGetHeight(view.frame));
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];
    [controller.view layoutIfNeeded];
    [view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    [self addTeardownBlock:^{
        [view resignFirstResponder];
        [view removeFromSuperview];
        window.hidden = YES;
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
    }];
    return window;
}

- (UIView *)interactionInstallationViewForBlockView:(IDBlockTextView *)view {
    NSDictionary *topology = [self topologyForBlockView:view];
    return [topology[@"installationHost"] isEqualToString:@"blockStack"]
        ? (UIView *)view.id_blockStack
        : view;
}

- (NSArray<UIGestureRecognizer *> *)nativeSelectionGesturesInView:(IDBlockTextView *)view {
    NSSet<NSString *> *classes = [NSSet setWithArray:@[
        @"UITextMultiTapRecognizer",
        @"UITapAndAHalfRecognizer",
        @"UIVariableDelayLoupeGesture",
        @"_UIPanOrFlickGestureRecognizer",
        @"UITextTapRecognizer",
        @"UITextRangeAdjustmentGestureRecognizer",
    ]];
    UIView *installationView = [self interactionInstallationViewForBlockView:view];
    return [installationView.gestureRecognizers filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(UIGestureRecognizer *gesture,
                                               NSDictionary *bindings) {
            return [classes containsObject:NSStringFromClass(gesture.class)];
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

- (void)installCanonicalSelection:(NSRange)selection inView:(IDBlockTextView *)view {
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument
                                               offset:(NSInteger)selection.location];
    UITextPosition *end = [view positionFromPosition:start
                                             offset:(NSInteger)selection.length];
    view.selectedTextRange = [view textRangeFromPosition:start toPosition:end];
}

- (BOOL)waitUntil:(BOOL (^)(void))condition
          timeout:(NSTimeInterval)timeout
      layingOutView:(IDBlockTextView *)view {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!condition() && deadline.timeIntervalSinceNow > 0.0) {
        [view layoutIfNeeded];
        NSDate *slice = [NSDate dateWithTimeIntervalSinceNow:0.01];
        if ([slice compare:deadline] == NSOrderedDescending) slice = deadline;
        [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:slice];
    }
    return condition();
}

- (void)flushSettledLayoutForView:(IDBlockTextView *)view {
    [view setNeedsLayout];
    [view layoutIfNeeded];
    XCTAssertTrue([self waitUntil:^BOOL{
        return !view.id_selectionPresentationUpdatePending &&
            !view.id_selectionPresentationUpdateScheduled;
    } timeout:0.5 layingOutView:view],
                  @"Selection presentation did not settle");
}

- (void)assertSelectionCallbackPublishesAfterSettlementForView:(IDBlockTextView *)view {
    [self flushSettledLayoutForView:view];
    NSUInteger updateCount =
        view.id_selectionPresentationBackend.presentationUpdateCount;

    [view id_selectionStateDidChange];

    XCTAssertEqual(view.id_selectionPresentationBackend.presentationUpdateCount,
                   updateCount);
    [view setNeedsLayout];
    [view layoutIfNeeded];
    XCTAssertTrue([self waitUntil:^BOOL{
        return view.id_selectionPresentationBackend.presentationUpdateCount >= updateCount + 1 &&
            !view.id_selectionPresentationUpdatePending &&
            !view.id_selectionPresentationUpdateScheduled;
    } timeout:0.5 layingOutView:view],
                  @"Selection presentation did not publish after settled layout");
    XCTAssertEqual(view.id_selectionPresentationBackend.presentationUpdateCount,
                   updateCount + 1);
    [view layoutIfNeeded];
    XCTAssertEqual(view.id_selectionPresentationBackend.presentationUpdateCount,
                   updateCount + 1);
}

- (void)testHostedGraphUsesNativeAssistantAndBlockLayoutOwner {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];

    XCTAssertEqualObjects(NSStringFromClass([view.id_interactionAssistant class]),
                          @"UITextInteractionAssistant");
    XCTAssertEqual(view.id_richLayoutController, view.id_layoutController);
    XCTAssertEqual([view textLayoutController], view.id_richLayoutController);
    XCTAssertFalse([NSStringFromClass([view.id_layoutController class])
        containsString:@"_UITextKit2LayoutController"]);
    XCTAssertEqual([view textInputView], view.id_blockStackCanvasView);
    XCTAssertNotNil([view selectionContainerView]);
    XCTAssertNoThrow([IDPrivateUIKit requireInteractionHost:view
                                                      stage:@"Task 9 host ABI"]);
    XCTAssertNoThrow([IDPrivateUIKit requireInteractionAssistant:view.id_interactionAssistant
                                                           stage:@"Task 9 assistant ABI"]);
    for (IDBlockLayout *layout in view.id_blockStackCanvasView.blockLayouts) {
        XCTAssertEqual([layout id_canvasHost], view);
    }
    for (NSString *name in @[
             @"customRenderController",
             [@"_convertPointFromRender" stringByAppendingString:@"Space:"],
         ]) {
        XCTAssertFalse([view respondsToSelector:NSSelectorFromString(name)], @"%@", name);
    }
}

- (void)testAssistantInstallsOneUIKitOwnedRecognizerOfEveryExpectedClass {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];

    NSArray<UIGestureRecognizer *> *gestures = [self nativeSelectionGesturesInView:view];
    NSDictionary<NSString *, NSNumber *> *counts = [self gestureClassCounts:gestures];
    for (NSString *className in @[
        @"UITextMultiTapRecognizer",
        @"UITapAndAHalfRecognizer",
        @"UIVariableDelayLoupeGesture",
        @"_UIPanOrFlickGestureRecognizer",
        @"UITextTapRecognizer",
        @"UITextRangeAdjustmentGestureRecognizer",
    ]) {
        XCTAssertEqual(counts[className].unsignedIntegerValue, 1U, @"%@", className);
    }
    UIView *installationView = [self interactionInstallationViewForBlockView:view];
    for (UIGestureRecognizer *gesture in gestures) {
        XCTAssertEqual(gesture.view, installationView);
        XCTAssertEqualObjects([NSBundle bundleForClass:gesture.class],
                              [NSBundle bundleForClass:UIView.class]);
    }
}

- (void)testRepeatedGestureAdoptionAndLayoutDoNotDuplicateRecognizers {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    NSDictionary *initial = [self gestureClassCounts:
        [self nativeSelectionGesturesInView:view]];

    [view id_updateSelectionGestures];
    [view id_updateSelectionGestures];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    [view setNeedsLayout];
    [view layoutIfNeeded];

    NSArray *finalGestures = [self nativeSelectionGesturesInView:view];
    XCTAssertEqualObjects([self gestureClassCounts:finalGestures], initial);
    XCTAssertEqual([NSSet setWithArray:finalGestures].count, finalGestures.count);
}

- (void)testSelectionContainerIsReusedAndStaysAboveBlockStack {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]
                                            frame:CGRectMake(0, 0, 240, 120)];
    __unused UIWindow *window = [self hostView:view];
    UIView *selectionContainer = [view selectionContainerView];
    id<IDSelectionPresentationBackend> backend =
        view.id_selectionPresentationBackend;

    [backend placeSelectionContainerView];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    view.contentOffset = CGPointMake(0, MIN(10, view.contentSize.height));
    [view setNeedsLayout];
    [view layoutIfNeeded];

    XCTAssertEqual([view selectionContainerView], selectionContainer);
    XCTAssertEqual(backend.existingSelectionContainerView, selectionContainer);
    XCTAssertEqual(backend.selectionContainerCreationCount, 1U);
    XCTAssertEqual(selectionContainer.superview, view);
    XCTAssertGreaterThan([view.subviews indexOfObject:selectionContainer],
                         [view.subviews indexOfObject:view.id_blockStackCanvasView]);
    // The container starts where the block stack starts — one coordinate space with
    // `-textInputView` — and covers the viewport. Scrolling moves neither.
    XCTAssertTrue(CGRectEqualToRect(selectionContainer.frame,
                                    (CGRect){view.id_blockStackCanvasView.frame.origin,
                                             view.bounds.size}),
                  @"%@", NSStringFromCGRect(selectionContainer.frame));
}

- (void)testAtomicFloatingSnapshotUsesLiteralBackendContainerCreationCount {
    IDBlockTextView *view = [self viewWithStrings:@[@"literal container count"]
                                            frame:CGRectMake(0, 0, 240, 120)];
    __unused UIWindow *window = [self hostView:view];
    id<IDSelectionPresentationBackend> backend = view.id_selectionPresentationBackend;
    [view selectionContainerView];
    [backend tearDown];
    [view selectionContainerView];
    XCTAssertEqual(backend.selectionContainerCreationCount, 2U);

    IDPrivateFloatingLifecycleWeakReferences *references =
        [[IDPrivateFloatingLifecycleWeakReferences alloc]
            initWithEditor:view layoutController:view.id_richLayoutController];
    NSDictionary *snapshot = [references copyAtomicFloatingSnapshot];
    XCTAssertEqual([snapshot[@"containerCreations"] unsignedIntegerValue], 2U);
}

- (void)testSelectionCrossingStructuralNewlineProducesBothBlockRects {
    NSString *first = @"first block";
    NSString *second = @"second block";
    IDBlockTextView *view = [self viewWithStrings:@[first, second]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument offset:6];
    UITextPosition *end = [view positionFromPosition:view.beginningOfDocument
                                              offset:(NSInteger)first.length + 4];
    UITextRange *range = [view textRangeFromPosition:start toPosition:end];

    XCTAssertNoThrow(view.selectedTextRange = range);
    XCTAssertEqual([view offsetFromPosition:view.selectedTextRange.start
                                  toPosition:view.selectedTextRange.end],
                   (NSInteger)(first.length - 6 + 1 + 3));
    NSArray<UITextSelectionRect *> *rects = [view selectionRectsForRange:range];
    XCTAssertGreaterThanOrEqual(rects.count, 2U);
    CGFloat minimumY = CGFLOAT_MAX;
    CGFloat maximumY = -CGFLOAT_MAX;
    for (UITextSelectionRect *rect in rects) {
        minimumY = MIN(minimumY, CGRectGetMinY(rect.rect));
        maximumY = MAX(maximumY, CGRectGetMinY(rect.rect));
    }
    XCTAssertGreaterThan(maximumY, minimumY);
    XCTAssertEqual([view selectionContainerView].superview, view);
}

- (void)testInsertionDrivenCaretAutoscrollHonorsAdjustedInsets {
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (NSUInteger index = 0; index < 40; index += 1) {
        [strings addObject:[NSString stringWithFormat:@"line %lu", (unsigned long)index]];
    }
    IDBlockTextView *view = [self viewWithStrings:strings
                                            frame:CGRectMake(0, 0, 220, 180)];
    view.contentInset = UIEdgeInsetsMake(3, 0, 19, 0);
    __unused UIWindow *window = [self hostView:view];
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];
    [view layoutIfNeeded];
    view.contentOffset = CGPointZero;

    XCTAssertTrue([view becomeFirstResponder]);
    XCTAssertNoThrow([view insertText:@"x"]);
    [view layoutIfNeeded];

    XCTAssertGreaterThan(view.contentOffset.y, 0.0);
    CGRect caret = [view caretRectForPosition:view.selectedTextRange.end];
    UIEdgeInsets insets = view.adjustedContentInset;
    CGRect visible = CGRectMake(view.contentOffset.x + insets.left,
                                view.contentOffset.y + insets.top,
                                MAX(CGRectGetWidth(view.bounds) - insets.left - insets.right, 0),
                                MAX(CGRectGetHeight(view.bounds) - insets.top - insets.bottom, 0));
    XCTAssertTrue(CGRectContainsRect(CGRectInset(visible, -1, -1), caret),
                  @"visible=%@ caret=%@",
                  NSStringFromCGRect(visible),
                  NSStringFromCGRect(caret));
}

- (void)testTallFloatingScrollFixtureMatchesStockDocumentGeometryAtCanonicalOffset {
    NSMutableArray<NSString *> *strings = [@[
        @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
        @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
        @"Third paragraph provides a stable lower destination without leaving the viewport.",
    ] mutableCopy];
    for (NSUInteger index = 0; index < 30; index += 1) {
        [strings addObject:[NSString stringWithFormat:
            @"Floating cursor block %02lu carries enough words to wrap.",
            (unsigned long)index]];
    }
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string
            attributes:@{NSFontAttributeName: font,
                         NSForegroundColorAttributeName: UIColor.blackColor}]];
    }
    CGRect frame = CGRectMake(0, 0, 370, 360);
    IDBlockTextView *custom = [[IDBlockTextView alloc] initWithFrame:frame
                                                   attributedBlocks:blocks];
    custom.font = font;
    custom.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    UITextView *stock = [[UITextView alloc] initWithFrame:frame];
    stock.font = font;
    stock.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    stock.textContainer.lineFragmentPadding = 5.0;
    stock.text = [strings componentsJoinedByString:@"\n"];
    [custom layoutIfNeeded];
    [stock layoutIfNeeded];
    UITextPosition *customPosition = [custom positionFromPosition:custom.beginningOfDocument
                                                           offset:900];
    UITextPosition *stockPosition = [stock positionFromPosition:stock.beginningOfDocument
                                                         offset:900];
    CGRect customCaret = [custom caretRectForPosition:customPosition];
    CGRect stockCaret = [stock caretRectForPosition:stockPosition];
    IDBlockLayout *containingLayout = custom.id_blockStack.blockLayouts[14];
    CGPoint containingOrigin = [custom.id_blockStack
        documentOriginForBlockIdentifier:containingLayout.blockIdentifier];
    XCTAttachment *geometryEvidence = [XCTAttachment attachmentWithString:
        [NSString stringWithFormat:
            @"customCaret=%@ stockCaret=%@ customContent=%@ stockContent=%@ "
             "block14Origin=%@ customInsets=%@ stockInsets=%@",
            NSStringFromCGRect(customCaret), NSStringFromCGRect(stockCaret),
            NSStringFromCGSize(custom.contentSize), NSStringFromCGSize(stock.contentSize),
            NSStringFromCGPoint(containingOrigin),
            NSStringFromUIEdgeInsets(custom.textContainerInset),
            NSStringFromUIEdgeInsets(stock.textContainerInset)]];
    geometryEvidence.name = @"floating-scroll-direct-geometry";
    geometryEvidence.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:geometryEvidence];

    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(custom.textContainerInset,
                                                stock.textContainerInset));
    XCTAssertEqualWithAccuracy(CGRectGetMidY(customCaret), CGRectGetMidY(stockCaret), 0.5,
        @"customCaret=%@ stockCaret=%@ customContent=%@ stockContent=%@ block14Origin=%@",
        NSStringFromCGRect(customCaret), NSStringFromCGRect(stockCaret),
        NSStringFromCGSize(custom.contentSize), NSStringFromCGSize(stock.contentSize),
        NSStringFromCGPoint(containingOrigin));
    XCTAssertEqualWithAccuracy(custom.contentSize.height, stock.contentSize.height, 0.5,
        @"customContent=%@ stockContent=%@ block14Origin=%@",
        NSStringFromCGSize(custom.contentSize), NSStringFromCGSize(stock.contentSize),
        NSStringFromCGPoint(containingOrigin));

    CGFloat customOffset = CGRectGetMidY(customCaret) - 45.0;
    CGFloat stockOffset = CGRectGetMidY(stockCaret) - 45.0;
    XCTAssertEqualWithAccuracy(CGRectGetMidY(customCaret) - customOffset,
                               CGRectGetMidY(stockCaret) - stockOffset, 0.001);
}

- (void)testFloatingCursorLifecycleUsesInstalledAssistantWithoutExceptions {
    IDBlockTextView *view = [self viewWithStrings:@[@"floating cursor"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];

    XCTAssertNoThrow([view beginFloatingCursorAtPoint:CGPointMake(20, 20)]);
    XCTAssertNoThrow([view updateFloatingCursorAtPoint:CGPointMake(24, 22)]);
    XCTAssertNoThrow([view updateFloatingCursorAtPoint:CGPointMake(28, 24) animated:YES]);
    XCTAssertNoThrow([view endFloatingCursor]);
}

- (void)testSelectableReconstructionSurvivesThreeFreshAssistantSessionCycles {
    IDBlockTextView *view = [self viewWithStrings:@[@"selectable reconstruction stress"]
                                            frame:CGRectMake(0, 0, 280, 180)];
    __unused UIWindow *window = [self hostView:view];
    UIView *container = [view selectionContainerView];
    NSUInteger containerCreations =
        view.id_selectionPresentationBackend.selectionContainerCreationCount;
    NSMutableSet *assistantTokens = [NSMutableSet set];

    IDPrivateTestingRequestSelectableOff(view);
    for (NSUInteger cycle = 0; cycle < 3; cycle += 1) {
        view.selectable = YES;
        XCTAssertTrue([view becomeFirstResponder]);
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.2]];
        id assistant = view.id_interactionAssistant;
        XCTAssertNotNil(assistant);
        XCTAssertNil(objc_getAssociatedObject(assistant,
                                               IDFloatingIntegrationAssistantTokenKey));
        NSObject *assistantToken = [NSObject new];
        objc_setAssociatedObject(assistant, IDFloatingIntegrationAssistantTokenKey,
                                 assistantToken, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [assistantTokens addObject:assistantToken];
        XCTAssertEqual(assistantTokens.count, cycle + 1);

        IDPrivateResetRecognizerBaselineForUITesting(view);
        NSDictionary *before = IDPrivateTestingFloatingCursorLifecycleSnapshot(view);
        NSSet *identities = [NSSet setWithArray:before[@"recognizerIdentitySignature"]];
        NSSet *baseline = [NSSet setWithArray:
            before[@"recognizerBaselineIdentitySignature"]];
        XCTAssertEqual(identities.count, [before[@"recognizerCount"] unsignedIntegerValue]);
        XCTAssertEqual(identities.count, [before[@"recognizerSignature"] count]);
        XCTAssertTrue([identities isSubsetOfSet:baseline]);
        XCTAssertEqual([before[@"recognizerUnexpectedNewCount"] unsignedIntegerValue], 0U);
        XCTAssertTrue([before[@"recognizerSubsetOfBaseline"] boolValue]);

        XCTAssertNoThrow([view beginFloatingCursorAtPoint:CGPointMake(30, 30)]);
        XCTAssertNoThrow([view updateFloatingCursorAtPoint:CGPointMake(45, 30)]);
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.01]];
        __weak id weakSession = IDFloatingIntegrationSession(assistant);
        __weak id weakAssistant = assistant;
        assistant = nil;

        IDPrivateTestingRequestSelectableOff(view);
        [NSRunLoop.mainRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:0.05]];
        XCTAssertNil(weakAssistant, @"cycle=%lu", (unsigned long)cycle);
        XCTAssertNil(weakSession, @"cycle=%lu", (unsigned long)cycle);
        NSDictionary *after =
            IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting(
                view, view.id_richLayoutController);
        XCTAssertTrue(IDFloatingReconstructionCycleIsQuiescent(
            after, weakAssistant != nil, weakSession != nil, cycle + 2, cycle + 1,
            view.id_selectionPresentationBackend.selectionContainerCreationCount,
            containerCreations));
        XCTAssertFalse(IDFloatingReconstructionCycleIsQuiescent(
            after, NO, YES, cycle + 2, cycle + 1,
            view.id_selectionPresentationBackend.selectionContainerCreationCount,
            containerCreations), @"accepted lingering weak session");
        XCTAssertFalse(IDFloatingReconstructionCycleIsQuiescent(
            after, NO, NO, cycle + 2, cycle + 1, containerCreations + 1,
            containerCreations), @"accepted delayed extra container creation");
        NSMutableDictionary *duplicate = [after mutableCopy];
        duplicate[@"selectableOffCount"] = @(cycle + 3);
        XCTAssertFalse(IDFloatingReconstructionCycleIsQuiescent(
            duplicate, NO, NO, cycle + 2, cycle + 1,
            view.id_selectionPresentationBackend.selectionContainerCreationCount,
            containerCreations), @"accepted duplicate terminal");
        XCTAssertEqual([view selectionContainerView], container);
        XCTAssertEqual(view.id_selectionPresentationBackend.selectionContainerCreationCount,
                       containerCreations);
    }
    XCTAssertEqual(assistantTokens.count, 3U);
}

- (void)testEditableAndSelectableInterruptionTransitionsMatchStockImmediately {
    IDBlockTextView *editable = [self viewWithStrings:@[@"editable interruption"]
                                                 frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *editableWindow = [self hostView:editable];
    XCTAssertTrue([editable becomeFirstResponder]);
    editable.editable = NO;
    XCTAssertFalse(editable.isFirstResponder);
    XCTAssertFalse(editable.isEditable);
    XCTAssertTrue(editable.isSelectable);
    XCTAssertTrue([editable becomeFirstResponder]);
    editable.editable = YES;
    XCTAssertFalse(editable.isFirstResponder);
    XCTAssertTrue(editable.isEditable);
    XCTAssertTrue(editable.isSelectable);

    IDBlockTextView *selectable = [self viewWithStrings:@[@"selectable interruption"]
                                                   frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *selectableWindow = [self hostView:selectable];
    XCTAssertTrue([selectable becomeFirstResponder]);
    selectable.selectable = NO;
    XCTAssertFalse(selectable.isFirstResponder);
    XCTAssertFalse(selectable.isEditable);
    XCTAssertFalse(selectable.isSelectable);
}

- (void)testKeyboardSelectionCallbackIsOneWayToExternalDelegate {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    IDBlockKeyboardSelectionDelegateSpy *spy = [IDBlockKeyboardSelectionDelegateSpy new];
    view.delegate = spy;
    id assistant = view.id_interactionAssistant;
    view.id_interactionAssistant = spy;

    [view keyboardInputChangedSelection:view.id_inputController];

    XCTAssertEqual(spy.keyboardSelectionCount, 1U);
    XCTAssertEqual(spy.assistantSelectionCount, 0U);
    view.id_interactionAssistant = assistant;
}

- (void)testFocusedCollapsedSelectionPublishesOnceAfterSettledLayout {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    XCTAssertTrue([view becomeFirstResponder]);
    IDBlockKeyboardSelectionDelegateSpy *spy = [IDBlockKeyboardSelectionDelegateSpy new];
    id assistant = view.id_interactionCapability.privateAssistant;
    spy.forwardingTarget = assistant;
    view.id_interactionCapability.privateAssistant = spy;

    [self assertSelectionCallbackPublishesAfterSettlementForView:view];
    XCTAssertEqual(spy.assistantSelectionCount, 1U);
    view.id_interactionCapability.privateAssistant = assistant;
}

- (void)testFocusedNonemptySelectionPublishesOnceAfterSettledLayout {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    [self installCanonicalSelection:NSMakeRange(1, 3) inView:view];
    XCTAssertTrue([view becomeFirstResponder]);

    [self assertSelectionCallbackPublishesAfterSettlementForView:view];
}

- (void)testUnfocusedCollapsedSelectionPublishesOnceAfterSettledLayout {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    XCTAssertFalse(view.isFirstResponder);

    [self assertSelectionCallbackPublishesAfterSettlementForView:view];
}

- (void)testNoneditableCollapsedSelectionPublishesOnceAfterSettledLayout {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    view.editable = NO;
    XCTAssertTrue([view becomeFirstResponder]);

    [self assertSelectionCallbackPublishesAfterSettlementForView:view];
}

- (void)testNonscrollableCollapsedSelectionPublishesOnceAfterSettledLayout {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    view.scrollEnabled = NO;
    XCTAssertTrue([view becomeFirstResponder]);

    [self assertSelectionCallbackPublishesAfterSettlementForView:view];
}

- (void)testResponderTransitionDoesNotConsumePendingPresentationBeforeLayout {
    IDBlockTextView *view = [self viewWithStrings:@[@"selection"]
                                            frame:CGRectMake(0, 0, 240, 160)];
    __unused UIWindow *window = [self hostView:view];
    [self flushSettledLayoutForView:view];
    NSUInteger updateCount =
        view.id_selectionPresentationBackend.presentationUpdateCount;
    [view id_updateSelectionPresentation];

    XCTAssertTrue([view becomeFirstResponder]);

    XCTAssertEqual(view.id_selectionPresentationBackend.presentationUpdateCount,
                   updateCount);
    [self flushSettledLayoutForView:view];
    XCTAssertEqual(view.id_selectionPresentationBackend.presentationUpdateCount,
                   updateCount + 1);
}

- (void)testHostedInteractionGraphTearsDownWithoutRetainingTheEditor {
    __weak IDBlockTextView *weakView = nil;
    __weak id weakAssistant = nil;
    __weak id weakInputController = nil;
    __weak id weakPresentationBackend = nil;
    __weak UIView *weakSelectionContainer = nil;
    NSTextContainer *interactionContainer = nil;
    @autoreleasepool {
        IDBlockTextView *view = [self viewWithStrings:@[@"teardown"]
                                                frame:CGRectMake(0, 0, 240, 160)];
        weakView = view;
        weakAssistant = view.id_interactionAssistant;
        weakInputController = view.id_inputController;
        weakPresentationBackend = view.id_selectionPresentationBackend;
        weakSelectionContainer = [view selectionContainerView];
        interactionContainer = view.id_richLayoutController.id_interactionTextContainer;
        XCTAssertEqual(IDPrivateTextContainerTextView(interactionContainer),
                       view.id_blockStackCanvasView);
    }

    XCTAssertNil(weakView);
    XCTAssertNil(weakAssistant);
    XCTAssertNil(weakInputController);
    XCTAssertNil(weakPresentationBackend);
    XCTAssertNil(weakSelectionContainer);
    XCTAssertNil(IDPrivateTextContainerTextView(interactionContainer));
}

- (void)testFloatingLifecycleCleanupIsIdempotentAndReleasesEndedAndInterruptedGraphs {
    for (NSNumber *normallyEnded in @[@YES, @NO]) {
        __weak IDBlockTextView *weakView = nil;
        __weak id weakAssistant = nil;
        __weak id weakBackend = nil;
        __weak UIView *weakContainer = nil;
        @autoreleasepool {
            IDBlockTextView *view = [self viewWithStrings:@[@"floating lifecycle release"]
                                                    frame:CGRectMake(0, 0, 240, 160)];
            weakView = view;
            weakAssistant = view.id_interactionAssistant;
            weakBackend = view.id_selectionPresentationBackend;
            weakContainer = [view selectionContainerView];
            [view beginFloatingCursorAtPoint:CGPointMake(30, 30)];
            [view updateFloatingCursorAtPoint:CGPointMake(50, 30)];
            if (normallyEnded.boolValue) {
                [view endFloatingCursor];
            } else {
                IDPrivateInteractionResignedFirstResponder(view.id_interactionAssistant);
            }
            XCTAssertNoThrow([view id_tearDownEditorGraph]);
            XCTAssertNoThrow([view id_tearDownEditorGraph]);
        }
        XCTAssertNil(weakView, @"normallyEnded=%@", normallyEnded);
        XCTAssertNil(weakAssistant, @"normallyEnded=%@", normallyEnded);
        XCTAssertNil(weakBackend, @"normallyEnded=%@", normallyEnded);
        XCTAssertNil(weakContainer, @"normallyEnded=%@", normallyEnded);
    }
}

- (void)testWindowDetachInterruptsHostedFloatingCursorAndRemainsQuiescent {
    IDBlockTextView *view = [self viewWithStrings:@[@"hosted floating interruption"]
                                            frame:CGRectMake(0, 0, 280, 180)];
    UIWindowScene *scene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];
    XCTAssertTrue([view becomeFirstResponder]);
    UITextPosition *selectionPosition =
        [view positionFromPosition:view.beginningOfDocument offset:8];
    view.selectedTextRange = [view textRangeFromPosition:selectionPosition
                                              toPosition:selectionPosition];
    [view beginFloatingCursorAtPoint:CGPointMake(40, 40)];
    [view updateFloatingCursorAtPoint:CGPointMake(65, 40)];
    NSRange interruptedSelection = [view id_NSRangeForTextRange:view.selectedTextRange];
    NSUInteger containerCreations =
        view.id_selectionPresentationBackend.selectionContainerCreationCount;

    [view removeFromSuperview];
    XCTAssertFalse(view.isFirstResponder);
    XCTAssertTrue(NSEqualRanges(
        [view id_NSRangeForTextRange:view.selectedTextRange], interruptedSelection));
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertFalse(view.isFirstResponder);
    XCTAssertTrue(NSEqualRanges(
        [view id_NSRangeForTextRange:view.selectedTextRange], interruptedSelection));
    XCTAssertEqual(view.id_selectionPresentationBackend.selectionContainerCreationCount,
                   containerCreations);
    XCTAssertTrue(view.id_selectionPresentationBackend.id_selectionContainerView.superview == view);
    window.hidden = YES;
}

- (void)testDisablingSelectableResignsFocusedAlreadyNoneditableEditor {
    IDBlockTextView *view = [self viewWithStrings:@[@"selectable responder transition"]
                                            frame:CGRectMake(0, 0, 280, 180)];
    UIWindowScene *scene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];
    view.editable = NO;
    XCTAssertTrue(view.isSelectable);
    XCTAssertTrue([view becomeFirstResponder]);
    NSRange selection = [view id_NSRangeForTextRange:view.selectedTextRange];

    view.selectable = NO;

    XCTAssertFalse(view.isFirstResponder);
    XCTAssertFalse(view.isEditable);
    XCTAssertFalse(view.isSelectable);
    XCTAssertTrue(NSEqualRanges(
        [view id_NSRangeForTextRange:view.selectedTextRange], selection));
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertFalse(view.isFirstResponder);
    XCTAssertTrue(NSEqualRanges(
        [view id_NSRangeForTextRange:view.selectedTextRange], selection));
    window.hidden = YES;
}

- (void)testBlockIsEditingWithdrawalPublicStateMatrixMatchesStockWithoutSelectorObservation {
    [self addTeardownBlock:^{
        UIPasteboard.generalPasteboard.items = @[];
    }];
    UIPasteboard.generalPasteboard.items = @[
        @{UTTypePlainText.identifier: @"paste"},
    ];

    NSString *text = @"alpha beta gamma";
    NSRange wordSelection = [text rangeOfString:@"beta"];
    UITextView *stock = [[UITextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 160)];
    stock.text = text;
    IDBlockTextView *custom = [self viewWithStrings:@[text]
                                              frame:CGRectMake(0, 180, 320, 160)];

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
    window.frame = CGRectMake(0, 0, 320, 360);
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    [controller.view addSubview:stock];
    [controller.view addSubview:custom];
    [window makeKeyAndVisible];
    [controller.view layoutIfNeeded];
    [self addTeardownBlock:^{
        [stock resignFirstResponder];
        [custom resignFirstResponder];
        [stock removeFromSuperview];
        [custom removeFromSuperview];
        window.hidden = YES;
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
    }];

    NSMutableArray<NSDictionary<NSString *, id> *> *customTopologies =
        [NSMutableArray array];
    NSArray<NSDictionary<NSString *, id> *> *(^runLifecycle)(id, BOOL) =
        ^NSArray<NSDictionary<NSString *, id> *> *(id editor,
                                                    BOOL inspectTopology) {
        NSMutableArray<NSDictionary<NSString *, id> *> *states =
            [NSMutableArray array];
        void (^capture)(NSString *) = ^(NSString *name) {
            [states addObject:IDBlockIntegrationPublicState(editor, name)];
            if (!inspectTopology) return;
            NSDictionary *topology = [self topologyForBlockView:editor];
            [customTopologies addObject:@{
                @"state": name,
                @"topology": topology,
            }];
            XCTAssertTrue(IDBlockTopologyHasOneActiveOwner(topology),
                          @"state=%@ topology=%@", name, topology);
        };

        [editor setEditable:YES];
        [editor setSelectable:YES];
        IDBlockIntegrationSetSelection(editor, NSMakeRange(0, 0));
        [editor resignFirstResponder];
        capture(@"attached nonresponder");

        XCTAssertTrue([editor becomeFirstResponder]);
        capture(@"focused editable/selectable");

        [editor setEditable:NO];
        capture(@"focused after editable off");

        IDBlockIntegrationSetSelection(editor, wordSelection);
        XCTAssertTrue([editor becomeFirstResponder]);
        capture(@"selectable/noneditable word selection");

        XCTAssertTrue([editor resignFirstResponder]);
        capture(@"resigned selectable/noneditable");

        [editor setEditable:YES];
        XCTAssertTrue([editor becomeFirstResponder]);
        capture(@"editable restored and refocused");

        [editor setSelectable:NO];
        capture(@"selectable off while focused");

        [editor setSelectable:YES];
        XCTAssertTrue([editor becomeFirstResponder]);
        capture(@"selectable restored and refocused");

        [editor removeFromSuperview];
        capture(@"window detached");

        [controller.view addSubview:editor];
        [controller.view layoutIfNeeded];
        [editor layoutIfNeeded];
        XCTAssertTrue([editor becomeFirstResponder]);
        capture(@"reattached and refocused");
        return states.copy;
    };

    __block NSArray<NSDictionary<NSString *, id> *> *stockStates = nil;
    __block NSArray<NSDictionary<NSString *, id> *> *customStates = nil;
    XCTAssertNoThrow(stockStates = runLifecycle(stock, NO));
    XCTAssertTrue([stock resignFirstResponder]);
    XCTAssertNoThrow(customStates = runLifecycle(custom, YES));

    XCTAssertEqualObjects(customStates, stockStates);
    XCTAssertEqual(customTopologies.count, customStates.count);

    NSDictionary *payload = @{
        @"stock": stockStates ?: @[],
        @"custom": customStates ?: @[],
        @"customTopologies": customTopologies,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    XCTAttachment *attachment = [XCTAttachment attachmentWithData:data
                                                      uniformTypeIdentifier:@"public.json"];
    attachment.name = @"block-is-editing-withdrawal-public-state-matrix";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testInheritedBlockIsEditingIMPReturnsExactPublicStateWithoutSwizzleOrSubclass {
    IDBlockTextView *view = [self viewWithStrings:@[@"inherited editing provider"]
                                            frame:CGRectMake(0, 0, 280, 180)];
    __unused UIWindow *window = [self hostView:view];
    SEL selector = NSSelectorFromString(@"isEditing");
    XCTAssertFalse(IDBlockIntegrationClassLocallyImplementsSelector(
        IDBlockTextView.class, selector));
    Method method = class_getInstanceMethod(IDBlockTextView.class, selector);
    XCTAssertNotEqual(method, NULL);
    if (method == NULL) return;
    XCTAssertEqual(method_getImplementation(method),
                   class_getMethodImplementation(
                       class_getSuperclass(IDBlockTextView.class), selector));
    BOOL (*invoke)(id, SEL) =
        (BOOL (*)(id, SEL))method_getImplementation(method);
    __block NSUInteger invocationCount = 0;
    NSMutableArray<NSNumber *> *values = [NSMutableArray array];
    NSMutableArray<NSNumber *> *expectedValues = [NSMutableArray array];
    void (^record)(void) = ^{
        BOOL expected = view.isFirstResponder && view.isEditable;
        invocationCount += 1;
        [expectedValues addObject:@(expected)];
        [values addObject:@(invoke(view, selector))];
    };

    XCTAssertFalse(view.isFirstResponder);
    record();
    XCTAssertTrue([view becomeFirstResponder]);
    record();
    view.editable = NO;
    record();
    XCTAssertFalse(view.isFirstResponder);
    view.editable = YES;
    XCTAssertTrue([view becomeFirstResponder]);
    record();

    XCTAssertEqual(invocationCount, 4U);
    XCTAssertEqualObjects(values, expectedValues);
    XCTAssertEqualObjects(values, (@[@NO, @YES, @NO, @YES]));
    NSDictionary *payload = @{
        @"invocationCount": @(invocationCount),
        @"values": values,
        @"receiverClass": NSStringFromClass(view.class),
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    XCTAttachment *attachment = [XCTAttachment attachmentWithData:data
                                                      uniformTypeIdentifier:@"public.json"];
    attachment.name = @"inherited-block-is-editing-resolved-imp";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

#pragma mark - Per-block frames (host decoration views)

/// A BLOCK's box, in the view's coordinates.
///
/// A host that draws decoration AROUND a block rather than over its glyphs — a code block's
/// background band, a quote's accent bar — needs the block's own frame. Every existing accessor
/// answers about TEXT (`id_rectsForCanonicalRange:`) or about one inline atom
/// (`id_attachmentFrameForCanonicalOffset:`); neither describes the box a decoration has to line up
/// with, and computing it host-side would mean reaching through `blockLayouts` into each block's
/// canvas view and redoing the coordinate conversion — engine knowledge, not host knowledge, which
/// is the same argument that put the two accessors above on this surface.
- (void)testBlockFrameEnclosesTheTextGeometryOfThatBlock {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}],
                        [[NSAttributedString alloc] initWithString:@"beta"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}]]];
    [view layoutIfNeeded];

    // "beta" is the second block: block 0 is 5 long, plus the one canonical position between them.
    NSArray<NSValue *> *rects = [view id_rectsForCanonicalRange:NSMakeRange(6, 4)];
    XCTAssertGreaterThan(rects.count, 0, @"no text geometry to compare the frame against");

    CGRect frame = [view id_frameForBlockAtIndex:1];
    XCTAssertFalse(CGRectIsNull(frame), @"a valid block index must answer a real frame");
    for (NSValue *value in rects) {
        XCTAssertTrue(CGRectContainsRect(CGRectInset(frame, -1.0, -1.0), value.CGRectValue),
                      @"the block's own text falls outside its frame, so the two accessors are not "
                      @"in the same coordinate space — decoration drawn from this would not line up "
                      @"with anything the host positions from the text rects");
    }
}

/// THE CONTROL. Without it, an implementation returning one fixed rect — the view's bounds, say —
/// would satisfy the containment assertion above for every block and look correct.
- (void)testBlockFramesAreDistinctAndStackedInDocumentOrder {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}],
                        [[NSAttributedString alloc] initWithString:@"beta"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}]]];
    [view layoutIfNeeded];

    CGRect first = [view id_frameForBlockAtIndex:0];
    CGRect second = [view id_frameForBlockAtIndex:1];
    XCTAssertGreaterThan(CGRectGetHeight(first), 0.0);
    XCTAssertGreaterThan(CGRectGetWidth(first), 0.0);
    XCTAssertGreaterThan(CGRectGetMinY(second), CGRectGetMinY(first),
                         @"the second block must sit below the first; equal origins mean the frame "
                         @"is not per-block at all");
}

/// An out-of-range index answers CGRectNull, matching `id_attachmentFrameForCanonicalOffset:`.
///
/// CGRectZero would be the dangerous answer: it is a perfectly plausible rect, so a host would park
/// its decoration view at the origin at full transparency and see nothing wrong until a real
/// document put a block there.
- (void)testOutOfRangeBlockIndexIsNullRatherThanZero {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}]]];
    [view layoutIfNeeded];

    XCTAssertTrue(CGRectIsNull([view id_frameForBlockAtIndex:99]),
                  @"an unknown block index must be CGRectNull, never a plausible zero rect");
}

#pragma mark - Line fragment padding

/// `lineFragmentPadding` is host-controllable, because 5pt on each side is UIKit's default for a text
/// container and not every host wants it.
///
/// A chat composer in particular owns its own horizontal padding — the panel insets the field, and the
/// host passes what remains as `textContainerInset` — so the container's own 5pt lands on top of that
/// and reads as the text being inset 5pt more than asked on both sides.
///
/// Behavioural, not a property read-back: it asserts the glyphs actually move.
- (void)testLineFragmentPaddingMovesTheText {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}]]];
    [view layoutIfNeeded];
    CGRect defaultRect = [view id_rectsForCanonicalRange:NSMakeRange(0, 5)].firstObject.CGRectValue;

    XCTAssertEqualWithAccuracy(view.lineFragmentPadding, 5.0, 0.001,
                               @"the default must match NSTextContainer's, so existing hosts are "
                               @"unaffected");
    view.lineFragmentPadding = 0.0;
    [view layoutIfNeeded];
    CGRect zeroedRect = [view id_rectsForCanonicalRange:NSMakeRange(0, 5)].firstObject.CGRectValue;

    XCTAssertEqualWithAccuracy(CGRectGetMinX(defaultRect) - CGRectGetMinX(zeroedRect), 5.0, 0.5,
                               @"zeroing the padding must move the text 5pt toward the leading edge");
}
#pragma mark - Caret and selection land on the glyphs

/// THE CONTRACT, and the reason the block stack sits at the origin.
///
/// UIKit draws the cursor and the selection by interpreting every `UITextInput` geometry answer
/// relative to `-textInputView`, which is the block stack. Our answers are in THIS view's
/// coordinates. While the stack was POSITIONED at `textContainerInset`, UIKit added that inset a
/// second time and drew both one inset down and to the right of the glyphs they belong to — the
/// long-standing "the cursor is offset from the text" defect, visible in every view built on this
/// class.
///
/// The stack now carries the inset internally instead, so the two spaces coincide. Round-tripping an
/// answer through `textInputView` must therefore be the identity, which catches any reintroduction of
/// the split rather than this one instance.
///
/// Two other ways of closing the gap were tried and are ruled out by construction: pointing
/// `textInputView` at this view stops the editor becoming first responder at all, and converting the
/// vended geometry is impossible because our own caret path and UIKit's drawing share the same
/// private-controller callbacks, so no seam can tell them apart.
- (void)testCaretAndSelectionAreExpressedInTextInputViewCoordinates {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha"
                                                       attributes:@{NSFontAttributeName:
                                                           [UIFont systemFontOfSize:17.0]}]]];
    view.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    [view layoutIfNeeded];
    UIView *inputView = [(id<UITextInput>)view textInputView];
    XCTAssertNotNil(inputView);

    CGRect caret = [view caretRectForPosition:view.endOfDocument];
    XCTAssertTrue(CGRectEqualToRect([inputView convertRect:caret toView:view], caret),
                  @"the caret is not in textInputView's space, so UIKit draws the cursor away from "
                  @"the glyphs by the difference");

    UITextRange *whole = [view textRangeFromPosition:view.beginningOfDocument
                                          toPosition:view.endOfDocument];
    for (UITextSelectionRect *selectionRect in [view selectionRectsForRange:whole]) {
        XCTAssertTrue(CGRectEqualToRect(
            [inputView convertRect:selectionRect.rect toView:view], selectionRect.rect),
                      @"a selection rect is not in textInputView's space either");
    }

    // The inset is still APPLIED — otherwise the identity above is satisfied trivially by a view that
    // ignores it — and the caret sits on the text, not one inset away from it.
    CGRect glyph = [view id_rectsForCanonicalRange:NSMakeRange(0, 5)].firstObject.CGRectValue;
    XCTAssertEqualWithAccuracy(CGRectGetMinX(glyph),
                               view.textContainerInset.left + view.lineFragmentPadding, 1.5,
                               @"the text should start at the container inset plus the container's "
                               @"own padding");
    XCTAssertEqualWithAccuracy(CGRectGetMinY(caret), CGRectGetMinY(glyph), 2.0,
                               @"caret=%@ glyph=%@", NSStringFromCGRect(caret),
                               NSStringFromCGRect(glyph));
}
/// The same, with `lineFragmentPadding` ZERO — the composer's configuration, where the line starts
/// at the container's very edge. Reported from the device: the empty field's caret looks clipped
/// along its left side, while a caret moved to the same first position in typed text does not.
///
/// With no padding there is no slack to absorb a caret placed even slightly left of the line origin,
/// so a rect that is merely close enough at padding 5 is visibly wrong here.
- (void)testEmptyLineCaretMatchesATypedLineWithoutContainerPadding {
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName: UIColor.blackColor,
    };
    IDBlockTextView *typed = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 120)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"x" attributes:attributes]]];
    typed.lineFragmentPadding = 0.0;
    [typed layoutIfNeeded];
    CGRect typedStart = [typed caretRectForPosition:typed.beginningOfDocument];

    IDBlockTextView *empty = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 120)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"" attributes:attributes]]];
    empty.lineFragmentPadding = 0.0;
    empty.font = attributes[NSFontAttributeName];
    [empty layoutIfNeeded];
    CGRect emptyCaret = [empty caretRectForPosition:empty.endOfDocument];

    XCTAssertEqualWithAccuracy(CGRectGetMinX(emptyCaret), CGRectGetMinX(typedStart), 0.5,
                               @"empty=%@ typedStart=%@", NSStringFromCGRect(emptyCaret),
                               NSStringFromCGRect(typedStart));
    XCTAssertEqualWithAccuracy(CGRectGetWidth(emptyCaret), CGRectGetWidth(typedStart), 0.5,
                               @"empty=%@ typedStart=%@", NSStringFromCGRect(emptyCaret),
                               NSStringFromCGRect(typedStart));
    XCTAssertEqualWithAccuracy(CGRectGetHeight(emptyCaret), CGRectGetHeight(typedStart), 1.0,
                               @"empty=%@ typedStart=%@", NSStringFromCGRect(emptyCaret),
                               NSStringFromCGRect(typedStart));
}

/// A host can say what an EMPTY block's line should be, and the LAST block is why it must.
///
/// The engine reads an empty line's attributes off the block's SEPARATOR — the newline that follows
/// it — which works for every block but the last, where there is no following newline and the
/// document's defaults stand in. A trailing empty line was therefore measured in the default font
/// with its caret at the container's leading edge, whatever the line was going to be: in the
/// Telegram composer, an empty quote attribution came out taller than a filled one and its cursor
/// sat outside the quote bar.
///
/// Asserted against a line that HAS the text rather than against constants, because the right answer
/// is whatever those attributes actually produce.
- (void)testHostSuppliedEmptyLineAttributesReachATrailingEmptyBlock {
    NSMutableParagraphStyle *indented = [[NSMutableParagraphStyle alloc] init];
    indented.firstLineHeadIndent = 24.0;
    indented.headIndent = 24.0;
    NSDictionary *intended = @{
        NSFontAttributeName: [UIFont systemFontOfSize:11.0],
        NSParagraphStyleAttributeName: indented,
    };
    NSAttributedString *first =
        [[NSAttributedString alloc] initWithString:@"first"
                                        attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:17.0] }];

    // What those attributes produce when the trailing block is NOT empty.
    IDBlockTextView *filled = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 200)
     attributedBlocks:@[first, [[NSAttributedString alloc] initWithString:@"x" attributes:intended]]];
    [filled layoutIfNeeded];
    CGRect filledLine = [filled id_frameForBlockAtIndex:1];
    // The START of that line, not its end: the end sits one character further along, and the empty
    // line has no character to be past.
    UITextPosition *filledLineStart = [filled positionFromPosition:filled.beginningOfDocument
                                                            offset:(NSInteger)first.length + 1];
    CGRect filledCaret = [filled caretRectForPosition:filledLineStart];

    IDBlockTextView *empty = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 200)
     attributedBlocks:@[first, [[NSAttributedString alloc] initWithString:@""]]];
    [empty layoutIfNeeded];
    NSArray<IDBlock *> *blocks = empty.id_document.blocks;
    XCTAssertEqual(blocks.count, 2u);
    empty.id_emptyLineAttributesByBlock = @{ blocks[1].identifier: intended };
    [empty layoutIfNeeded];

    CGRect emptyLine = [empty id_frameForBlockAtIndex:1];
    CGRect emptyCaret = [empty caretRectForPosition:empty.endOfDocument];

    XCTAssertEqualWithAccuracy(CGRectGetHeight(emptyLine), CGRectGetHeight(filledLine), 0.5,
                               @"empty=%@ filled=%@", NSStringFromCGRect(emptyLine),
                               NSStringFromCGRect(filledLine));
    XCTAssertEqualWithAccuracy(CGRectGetMinX(emptyCaret), CGRectGetMinX(filledCaret), 0.5,
                               @"empty=%@ filled=%@", NSStringFromCGRect(emptyCaret),
                               NSStringFromCGRect(filledCaret));
}

/// The caret in an EMPTY block types in that block's attributes, not the document's defaults.
///
/// The same answers that say what an empty line is measured with have to say what is typed into it,
/// or the line looks right until it is used. Typing attributes are otherwise derived from the text
/// around the caret, and an empty block has none.
- (void)testTypingIntoAnEmptyBlockUsesItsHostSuppliedAttributes {
    NSMutableParagraphStyle *indented = [[NSMutableParagraphStyle alloc] init];
    indented.firstLineHeadIndent = 24.0;
    indented.headIndent = 24.0;
    NSDictionary *intended = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:11.0],
        NSParagraphStyleAttributeName: indented,
    };
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 200)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"first"],
                        [[NSAttributedString alloc] initWithString:@""]]];
    [view layoutIfNeeded];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    XCTAssertEqual(blocks.count, 2u);
    view.id_emptyLineAttributesByBlock = @{ blocks[1].identifier: intended };
    [view layoutIfNeeded];

    __unused UIWindow *window = [self hostView:view];
    XCTAssertTrue([view becomeFirstResponder]);
    view.selectedTextRange = [view textRangeFromPosition:view.endOfDocument
                                              toPosition:view.endOfDocument];
    [view insertText:@"x"];
    [view layoutIfNeeded];

    NSAttributedString *typed = [view id_renderedTextForBlockAtIndex:1];
    XCTAssertEqualObjects(typed.string, @"x");
    UIFont *font = [typed attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    NSParagraphStyle *style = [typed attribute:NSParagraphStyleAttributeName
                                       atIndex:0
                                effectiveRange:NULL];
    XCTAssertEqualWithAccuracy(font.pointSize, 11.0, 0.5, @"font=%@", font);
    XCTAssertEqualWithAccuracy(style.headIndent, 24.0, 0.5, @"style=%@", style);
}

/// A CENTRED line's caret sits on its glyphs, not where left-aligned text would have put it.
///
/// The caret x came from the `.standard` text segment, which reports a position measured from a left
/// origin and takes no account of the line's alignment displacement. The END of the line was right
/// by accident — that path already used the alignment-aware caret offsets — so a centred pull quote
/// placed its cursor correctly on the last character and at the left margin everywhere else.
- (void)testCaretInACentredLineSitsOnTheGlyphs {
    NSMutableParagraphStyle *centred = [[NSMutableParagraphStyle alloc] init];
    centred.alignment = NSTextAlignmentCenter;
    // Indented as well as centred, which is the shape a pull quote has: its pill reserves 30pt of
    // padding on each side and the text is centred within what is left.
    centred.firstLineHeadIndent = 30.0;
    centred.headIndent = 30.0;
    centred.tailIndent = -30.0;
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
        NSParagraphStyleAttributeName: centred,
    };
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 120)
     attributedBlocks:@[[[NSAttributedString alloc]
                             initWithString:@"the quick brown fox jumps over the lazy dog and keeps"
                                 attributes:attributes]]];
    [view layoutIfNeeded];

    // The LAST line, which is the short one. A wrapped line fills the width, so its centring
    // displacement is zero and the defect is invisible on it — only a short line shows it, which is
    // why a single-line case passed against this bug.
    NSUInteger length = (NSUInteger)[view offsetFromPosition:view.beginningOfDocument
                                                  toPosition:view.endOfDocument];
    NSUInteger probe = length - 3;
    NSArray<NSValue *> *rects = [view id_rectsForCanonicalRange:NSMakeRange(probe - 1, 1)];
    XCTAssertGreaterThan(rects.count, 0u);
    CGRect glyph = rects.firstObject.CGRectValue;

    UITextPosition *position = [view positionFromPosition:view.beginningOfDocument
                                                   offset:(NSInteger)probe];
    CGRect caret = [view caretRectForPosition:position];

    XCTAssertGreaterThan(CGRectGetMinY(glyph), 1.0, @"precondition: this IS a later line");
    XCTAssertEqualWithAccuracy(CGRectGetMinX(caret), CGRectGetMaxX(glyph), 2.0,
                               @"caret=%@ glyph=%@", NSStringFromCGRect(caret),
                               NSStringFromCGRect(glyph));
}

/// An empty line's caret can be moved along its line without moving what is typed into it.
///
/// A host drawing a CENTRED prompt in an empty line wants the caret at the prompt's start, not in
/// its middle. That cannot come from the empty-line attributes: those also decide what a first
/// keystroke inherits, so bending them would type the first character off-centre.
- (void)testEmptyLineCaretOffsetMovesTheCaretButNotTypedText {
    NSMutableParagraphStyle *centred = [[NSMutableParagraphStyle alloc] init];
    centred.alignment = NSTextAlignmentCenter;
    NSDictionary *intended = @{
        NSFontAttributeName: [UIFont systemFontOfSize:15.0],
        NSParagraphStyleAttributeName: centred,
    };
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 200)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@""]]];
    [view layoutIfNeeded];
    NSUUID *identifier = view.id_document.blocks.firstObject.identifier;
    view.id_emptyLineAttributesByBlock = @{ identifier: intended };
    [view layoutIfNeeded];
    CGFloat centredCaret = CGRectGetMinX([view caretRectForPosition:view.beginningOfDocument]);

    view.id_emptyLineCaretOffsetsByBlock = @{ identifier: @(-20.0) };
    [view layoutIfNeeded];
    CGFloat movedCaret = CGRectGetMinX([view caretRectForPosition:view.beginningOfDocument]);
    XCTAssertEqualWithAccuracy(movedCaret, centredCaret - 20.0, 0.5,
                               @"moved=%f centred=%f", movedCaret, centredCaret);

    // What is TYPED is unaffected: it takes the line's own attributes and centres.
    __unused UIWindow *window = [self hostView:view];
    XCTAssertTrue([view becomeFirstResponder]);
    view.selectedTextRange = [view textRangeFromPosition:view.beginningOfDocument
                                              toPosition:view.beginningOfDocument];
    [view insertText:@"x"];
    [view layoutIfNeeded];
    NSAttributedString *typed = [view id_renderedTextForBlockAtIndex:0];
    NSParagraphStyle *style = [typed attribute:NSParagraphStyleAttributeName
                                       atIndex:0
                                effectiveRange:NULL];
    XCTAssertEqual(style.alignment, NSTextAlignmentCenter, @"style=%@", style);
}

/// Changing `lineFragmentPadding` AFTER a layout must move the empty line's caret with it.
///
/// The empty caret is measured against a cached prototype, and the padding decides where a line
/// begins. Keyed on the attributes and width alone, a host that changed the padding later — the chat
/// composer sets it to zero — kept a stale prototype and drew the caret one padding to the right of
/// where a typed line's caret starts.
- (void)testEmptyLineCaretFollowsALaterLineFragmentPaddingChange {
    NSDictionary *attributes = @{ NSFontAttributeName: [UIFont systemFontOfSize:17.0] };
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 120)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"" attributes:attributes]]];
    view.font = attributes[NSFontAttributeName];
    [view layoutIfNeeded];
    CGRect padded = [view caretRectForPosition:view.endOfDocument];

    view.lineFragmentPadding = 0.0;
    [view layoutIfNeeded];
    CGRect unpadded = [view caretRectForPosition:view.endOfDocument];

    XCTAssertEqualWithAccuracy(CGRectGetMinX(padded) - CGRectGetMinX(unpadded), 5.0, 0.5,
                               @"padded=%@ unpadded=%@", NSStringFromCGRect(padded),
                               NSStringFromCGRect(unpadded));
}

/// An EMPTY line's caret must be the same size as a typed line's.
///
/// Reported from the device: "when the text field is empty the cursor is unusually small". It was
/// 15.7pt against 23.7pt — the caret is derived from the block's text storage, and an empty storage
/// carries no attributes at all, so neither the font nor the paragraph style's pinned line height
/// reaches it and TextKit falls back to a system default.
///
/// Asserted as EQUALITY with the typed caret rather than against a constant: the right height is
/// whatever a real line of the same attributes produces, which is also how the fix computes it.
- (void)testEmptyLineCaretMatchesATypedLine {
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName: UIColor.blackColor,
    };
    IDBlockTextView *typed = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 120)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"x" attributes:attributes]]];
    [typed layoutIfNeeded];
    CGRect typedCaret = [typed caretRectForPosition:typed.endOfDocument];

    IDBlockTextView *empty = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 120)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"" attributes:attributes]]];
    empty.font = attributes[NSFontAttributeName];
    [empty layoutIfNeeded];
    CGRect emptyCaret = [empty caretRectForPosition:empty.endOfDocument];

    XCTAssertEqualWithAccuracy(CGRectGetHeight(emptyCaret), CGRectGetHeight(typedCaret), 1.0,
                               @"empty=%@ typed=%@", NSStringFromCGRect(emptyCaret),
                               NSStringFromCGRect(typedCaret));
    XCTAssertEqualWithAccuracy(CGRectGetMinY(emptyCaret), CGRectGetMinY(typedCaret), 1.0,
                               @"the empty caret should sit on the same baseline box");

    // …and it must sit at the same PLACE and be the same WIDTH as a caret at the start of a typed
    // line. Comparing only the height let a zero-width rect at the wrong x pass, which on screen was
    // a caret clipped along its left edge.
    CGRect typedStart = [typed caretRectForPosition:typed.beginningOfDocument];
    XCTAssertEqualWithAccuracy(CGRectGetMinX(emptyCaret), CGRectGetMinX(typedStart), 0.5,
                               @"empty=%@ typedStart=%@", NSStringFromCGRect(emptyCaret),
                               NSStringFromCGRect(typedStart));
    XCTAssertEqualWithAccuracy(CGRectGetWidth(emptyCaret), CGRectGetWidth(typedStart), 0.5,
                               @"empty=%@ typedStart=%@", NSStringFromCGRect(emptyCaret),
                               NSStringFromCGRect(typedStart));
}
#pragma mark - Per-block insets

/// Space a host can reserve AROUND one block, addressed by the engine's own identity.
///
/// A host drawing a container across several blocks — a quote, a code band — needs interior padding
/// at the RUN's edges, and there is no way to express it in the text: TextKit ignores
/// `paragraphSpacingBefore` on the first paragraph of a container, and trailing spacing does not
/// extend the used height, so a block laid out alone gets neither. Measured, both times.
///
/// Reserved by the layout instead, which is also how the host's own canvas does it.
- (void)testPerBlockInsetsReserveSpaceAroundOneBlock {
    IDBlockTextView *view = [self viewWithStrings:@[@"first", @"second"]
                                            frame:CGRectMake(0, 0, 320, 240)];
    [view layoutIfNeeded];
    CGRect firstBefore = [view id_frameForBlockAtIndex:0];
    CGRect secondBefore = [view id_frameForBlockAtIndex:1];

    NSUUID *secondIdentifier = view.id_document.blocks[1].identifier;
    view.blockInsets = @{ secondIdentifier: [NSValue valueWithUIEdgeInsets:
        UIEdgeInsetsMake(12, 0, 7, 0)] };
    [view layoutIfNeeded];
    CGRect firstAfter = [view id_frameForBlockAtIndex:0];
    CGRect secondAfter = [view id_frameForBlockAtIndex:1];

    XCTAssertEqualWithAccuracy(CGRectGetMinY(firstAfter), CGRectGetMinY(firstBefore), 0.5,
                               @"a block BEFORE the inset one must not move");
    XCTAssertEqualWithAccuracy(CGRectGetMinY(secondAfter) - CGRectGetMinY(secondBefore), 12.0, 0.5,
                               @"the inset block should be pushed down by its top inset");
    XCTAssertEqualWithAccuracy(CGRectGetHeight(secondAfter), CGRectGetHeight(secondBefore), 0.5,
                               @"its own height is unchanged — the space is reserved AROUND it");
    XCTAssertGreaterThanOrEqual(view.contentSize.height,
                                CGRectGetMaxY(secondAfter) + 7.0 - 0.5,
                                @"the bottom inset must be inside the scrollable content");
}
/// A block's HORIZONTAL insets narrow its text measure, not only its canvas.
///
/// The placed branch always subtracted them; a stacked block laid out at the full column and was
/// then drawn one `left` in, so its wrapped text ran that far past the column's trailing edge —
/// invisible for the vertical-only insets every container uses, and immediately visible for a host
/// that reserves room on the left of one block (a wide list marker).
///
/// Measured on the line's own trailing edge rather than on `usedSize`, which reports the widest
/// LINE and so answers the same number either way for text that fills the column.
- (void)testHorizontalBlockInsetsNarrowTheTextMeasureOfAStackedBlock {
    NSString *filler = [@"" stringByPaddingToLength:400 withString:@"i " startingAtIndex:0];
    IDBlockTextView *view = [self viewWithStrings:@[filler, filler]
                                            frame:CGRectMake(0, 0, 320, 600)];
    [view layoutIfNeeded];
    CGRect plainBefore = [view id_frameForBlockAtIndex:0];

    NSUUID *secondIdentifier = view.id_document.blocks[1].identifier;
    view.blockInsets = @{ secondIdentifier: [NSValue valueWithUIEdgeInsets:
        UIEdgeInsetsMake(0, 40, 0, 0)] };
    [view layoutIfNeeded];
    CGRect insetAfter = [view id_frameForBlockAtIndex:1];

    XCTAssertEqualWithAccuracy(CGRectGetMinX(insetAfter) - CGRectGetMinX(plainBefore), 40.0, 0.5,
                               @"the inset block starts one left inset in");
    XCTAssertLessThanOrEqual(CGRectGetMaxX(insetAfter), CGRectGetMaxX(plainBefore) + 0.5,
                             @"and must not reach past where an un-inset block ends");
    XCTAssertEqualWithAccuracy(CGRectGetWidth(insetAfter),
                               CGRectGetWidth(plainBefore) - 40.0, 0.5,
                               @"so it is exactly that much narrower");
}

#pragma mark - Placed blocks

/// A host may PLACE a block instead of stacking it: `blockFrames` gives the block a frame relative
/// to the anchor of its run (consecutive placed blocks in document order), and the stack's cursor
/// does not advance for it. This is how a host lays a table out — one engine block per cell — on an
/// engine that otherwise stacks everything vertically.
- (void)testPlacedBlocksShareAnAnchorAndDoNotAdvanceTheStack {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"bottom"]
                                            frame:CGRectMake(0, 0, 320, 400)];
    [view layoutIfNeeded];
    CGRect topBefore = [view id_frameForBlockAtIndex:0];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{
        blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 150, 0)],
        blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(150, 0, 150, 0)],
    };
    [view layoutIfNeeded];
    CGRect top = [view id_frameForBlockAtIndex:0];
    CGRect a = [view id_frameForBlockAtIndex:1];
    CGRect b = [view id_frameForBlockAtIndex:2];
    CGRect bottom = [view id_frameForBlockAtIndex:3];
    XCTAssertTrue(CGRectEqualToRect(top, topBefore), @"a stacked block before the run must not move");
    XCTAssertEqualWithAccuracy(CGRectGetMinY(a), CGRectGetMaxY(top), 0.5, @"the run anchors at the cursor");
    XCTAssertEqualWithAccuracy(CGRectGetMinY(b), CGRectGetMinY(a), 0.5, @"siblings share the anchor");
    XCTAssertEqualWithAccuracy(CGRectGetMinX(a), CGRectGetMinX(top), 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(b), CGRectGetMinX(top) + 150.0, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(a), 150.0, 0.5, @"a placed block takes its frame's width");
    CGFloat extent = MAX(CGRectGetMaxY(a), CGRectGetMaxY(b));
    XCTAssertEqualWithAccuracy(CGRectGetMinY(bottom), extent, 0.5,
                               @"the block after the run sits below the run's extent");
}

- (void)testAPlacedBlockLaysOutAtItsFrameWidth {
    NSString *longText = @"one two three four five six seven eight nine ten eleven twelve thirteen";
    IDBlockTextView *stacked = [self viewWithStrings:@[longText] frame:CGRectMake(0, 0, 320, 400)];
    [stacked layoutIfNeeded];
    CGFloat fullWidthHeight = CGRectGetHeight([stacked id_frameForBlockAtIndex:0]);

    IDBlockTextView *view = [self viewWithStrings:@[longText] frame:CGRectMake(0, 0, 320, 400)];
    view.blockFrames = @{ view.id_document.blocks[0].identifier:
                              [NSValue valueWithCGRect:CGRectMake(0, 0, 100, 0)] };
    [view layoutIfNeeded];
    XCTAssertGreaterThan(CGRectGetHeight([view id_frameForBlockAtIndex:0]), fullWidthHeight + 1.0,
                         @"narrowed to 100pt the text must wrap onto more lines");
    XCTAssertEqualWithAccuracy([view id_usedSizeForBlockAtIndex:0].height,
                               CGRectGetHeight([view id_frameForBlockAtIndex:0]), 0.5,
                               @"with no frame height the canvas is exactly the used height");
}

- (void)testAPlacedFrameHeightIsAMinimum {
    IDBlockTextView *view = [self viewWithStrings:@[@"a", @"bottom"] frame:CGRectMake(0, 0, 320, 400)];
    view.blockFrames = @{ view.id_document.blocks[0].identifier:
                              [NSValue valueWithCGRect:CGRectMake(0, 0, 200, 120)] };
    [view layoutIfNeeded];
    CGRect a = [view id_frameForBlockAtIndex:0];
    XCTAssertEqualWithAccuracy(CGRectGetHeight(a), 120.0, 0.5, @"the frame's height is honoured as a minimum");
    XCTAssertLessThan([view id_usedSizeForBlockAtIndex:0].height, 120.0, @"(the text itself is shorter)");
    XCTAssertEqualWithAccuracy(CGRectGetMinY([view id_frameForBlockAtIndex:1]), CGRectGetMaxY(a), 0.5);
}

- (void)testLeftAndTopInsetsApplyInsideAPlacedFrameAndBottomExtendsTheRun {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"bottom"] frame:CGRectMake(0, 0, 320, 400)];
    NSUUID *aID = view.id_document.blocks[1].identifier;
    view.blockFrames = @{ aID: [NSValue valueWithCGRect:CGRectMake(0, 0, 200, 0)] };
    [view layoutIfNeeded];
    CGRect aPlain = [view id_frameForBlockAtIndex:1];
    view.blockInsets = @{ aID: [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(5, 7, 30, 0)] };
    [view layoutIfNeeded];
    CGRect a = [view id_frameForBlockAtIndex:1];
    CGRect bottom = [view id_frameForBlockAtIndex:2];
    XCTAssertEqualWithAccuracy(CGRectGetMinX(a) - CGRectGetMinX(aPlain), 7.0, 0.5, @"left inset is inside the frame");
    XCTAssertEqualWithAccuracy(CGRectGetMinY(a) - CGRectGetMinY(aPlain), 5.0, 0.5, @"top inset is inside the frame");
    XCTAssertEqualWithAccuracy(CGRectGetWidth(a), 200.0 - 7.0, 0.5, @"the text narrows by the side insets");
    XCTAssertEqualWithAccuracy(CGRectGetMinY(bottom) - CGRectGetMaxY(a), 30.0, 0.5,
                               @"bottom inset extends the run's extent below the block");
}

- (void)testClearingBlockFramesRestoresStacking {
    IDBlockTextView *view = [self viewWithStrings:@[@"a", @"b", @"c"] frame:CGRectMake(0, 0, 320, 400)];
    [view layoutIfNeeded];
    NSMutableArray<NSValue *> *before = [NSMutableArray array];
    for (NSUInteger i = 0; i < 3; i += 1) [before addObject:[NSValue valueWithCGRect:[view id_frameForBlockAtIndex:i]]];
    view.blockFrames = @{ view.id_document.blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 100, 0)] };
    [view layoutIfNeeded];
    view.blockFrames = nil;
    [view layoutIfNeeded];
    for (NSUInteger i = 0; i < 3; i += 1) {
        XCTAssertTrue(CGRectEqualToRect([view id_frameForBlockAtIndex:i], before[i].CGRectValue),
                      @"block %lu did not return to its stacked frame", (unsigned long)i);
    }
}

- (void)testAFrameOnlyChangeRepositionsWithoutRelayingOutText {
    IDBlockTextView *view = [self viewWithStrings:@[@"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    NSUUID *aID = view.id_document.blocks[0].identifier;
    view.blockFrames = @{ aID: [NSValue valueWithCGRect:CGRectMake(0, 0, 200, 0)] };
    [view layoutIfNeeded];
    NSUInteger generation = [view.id_blockStack layoutForBlockIdentifier:aID].layoutGeneration;
    view.blockFrames = @{ aID: [NSValue valueWithCGRect:CGRectMake(40, 25, 200, 0)] };
    [view layoutIfNeeded];
    XCTAssertEqual([view.id_blockStack layoutForBlockIdentifier:aID].layoutGeneration, generation,
                   @"moving a frame without changing its width must not re-lay-out the text");
    XCTAssertEqualWithAccuracy(CGRectGetMinX([view id_frameForBlockAtIndex:0]),
                               CGRectGetMinX([view id_frameForBlockAtIndex:1]) + 40.0, 0.5);
}

/// A row of cells shares one y, so the old y-scan answered the LAST cell of a row for any point in
/// it. Placed runs are hit-tested by rect instead; stacked blocks keep the scan.
- (void)testATapInsideAPlacedRunResolvesToTheCellUnderIt {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"c", @"d", @"bottom"]
                                            frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{
        blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 150, 40)],
        blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(150, 0, 150, 40)],
        blocks[3].identifier: [NSValue valueWithCGRect:CGRectMake(0, 40, 150, 40)],
        blocks[4].identifier: [NSValue valueWithCGRect:CGRectMake(150, 40, 150, 40)],
    };
    [view layoutIfNeeded];
    CGRect a = [view id_frameForBlockAtIndex:1];
    // Inside `a`'s frame but well to the right of its one-letter text: the EMPTY part of the cell.
    CGPoint inA = CGPointMake(CGRectGetMinX(a) + 120.0, CGRectGetMinY(a) + 20.0);
    CGPoint inB = CGPointMake(CGRectGetMinX(a) + 160.0, CGRectGetMinY(a) + 20.0);
    CGPoint inC = CGPointMake(CGRectGetMinX(a) + 20.0, CGRectGetMinY(a) + 60.0);
    NSArray<NSNumber *> *expected = @[@4, @6, @8];   // canonical starts of a, b, c ("top\n" is 4)
    NSArray<NSValue *> *points = @[[NSValue valueWithCGPoint:inA], [NSValue valueWithCGPoint:inB],
                                   [NSValue valueWithCGPoint:inC]];
    for (NSUInteger i = 0; i < 3; i += 1) {
        UITextPosition *hit = [view closestPositionToPoint:points[i].CGPointValue];
        NSInteger offset = [view offsetFromPosition:view.beginningOfDocument toPosition:hit];
        // Any position INSIDE that block is acceptable; the block starts at `expected` and is 1 char.
        XCTAssertTrue(offset >= expected[i].integerValue && offset <= expected[i].integerValue + 1,
                      @"point %lu landed at canonical offset %ld, expected inside block starting at %@",
                      (unsigned long)i, (long)offset, expected[i]);
    }
}

- (void)testDownFromACellLandsInTheCellBeneathAndLeavesTheRunFromItsLastRow {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"c", @"d", @"bottom"]
                                            frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{
        blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 150, 40)],
        blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(150, 0, 150, 40)],
        blocks[3].identifier: [NSValue valueWithCGRect:CGRectMake(0, 40, 150, 40)],
        blocks[4].identifier: [NSValue valueWithCGRect:CGRectMake(150, 40, 150, 40)],
    };
    [view layoutIfNeeded];
    __unused UIWindow *window = [self hostView:view];
    XCTAssertTrue([view becomeFirstResponder]);
    // Caret at the start of `b` (canonical 6: "top\n" 4 + "a\n" 2). Down must reach `d` (10), not `c` (8).
    UITextPosition *inB = [view positionFromPosition:view.beginningOfDocument offset:6];
    UITextPosition *down = [view positionFromPosition:inB inDirection:UITextLayoutDirectionDown offset:1];
    XCTAssertNotNil(down);
    NSInteger landed = [view offsetFromPosition:view.beginningOfDocument toPosition:down];
    XCTAssertTrue(landed >= 10 && landed <= 11, @"Down from b landed at %ld, expected inside d (10…11)", (long)landed);
    // From the last row, Down leaves the run into the stacked block after it ("bottom" starts at 12).
    UITextPosition *out = [view positionFromPosition:down inDirection:UITextLayoutDirectionDown offset:1];
    XCTAssertNotNil(out);
    NSInteger left = [view offsetFromPosition:view.beginningOfDocument toPosition:out];
    XCTAssertTrue(left >= 12, @"Down from the last row landed at %ld, expected in `bottom` (>= 12)", (long)left);
    // And Up from `bottom` enters the run's LAST row under the caret's x — `c` (8), not `d`.
    UITextPosition *bottomStart = [view positionFromPosition:view.beginningOfDocument offset:12];
    UITextPosition *up = [view positionFromPosition:bottomStart inDirection:UITextLayoutDirectionUp offset:1];
    XCTAssertNotNil(up);
    NSInteger entered = [view offsetFromPosition:view.beginningOfDocument toPosition:up];
    XCTAssertTrue(entered >= 8 && entered <= 9, @"Up from bottom landed at %ld, expected inside c (8…9)", (long)entered);
}

#pragma mark - Placed run scrolling

- (void)testARunWiderThanTheCanvasScrollsAndANarrowerOneDoesNot {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"bottom"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIView *content = [view id_placedRunContentViewForBlockAtIndex:1];
    XCTAssertNotNil(content, @"a placed run has a content view");
    XCTAssertNil([view id_placedRunContentViewForBlockAtIndex:0], @"a stacked block has none");
    XCTAssertTrue([content.superview isKindOfClass:UIScrollView.class]);
    UIScrollView *scroll = (UIScrollView *)content.superview;
    XCTAssertEqualWithAccuracy(scroll.contentSize.width, 600.0, 0.5);
    XCTAssertTrue(scroll.scrollEnabled);
    XCTAssertTrue(scroll.clipsToBounds);
    XCTAssertFalse(scroll.showsHorizontalScrollIndicator, @"invisible infrastructure: a host draws its own chrome");
    XCTAssertFalse(scroll.showsVerticalScrollIndicator);
    XCTAssertEqualWithAccuracy(scroll.contentSize.height, CGRectGetHeight(scroll.bounds), 0.5,
                               @"horizontal only: a vertical pan must pass through");

    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 100, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(100, 0, 100, 40)] };
    [view layoutIfNeeded];
    scroll = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    XCTAssertFalse(scroll.scrollEnabled, @"fits: no scrolling");
}

/// A content touch is not held back, which is what lets anything be caught at all.
///
/// UIScrollView delays a content touch by ~150ms while it decides whether the gesture is a scroll,
/// and everything this view's content does with a touch is then that late. A placed run's coast
/// (~800ms) survives that; its rubber band (~300ms) usually does not, so a bouncing run could not be
/// caught while a coasting one could (K3, 2026-09-12). The pan can still cancel a delivered touch
/// once it knows the gesture is a scroll — that is `canCancelContentTouches`, which stays on.
- (void)testAContentTouchIsDeliveredWithoutTheScrollViewsDelay {
    IDBlockTextView *view = [self viewWithStrings:@[@"one"] frame:CGRectMake(0, 0, 320, 400)];
    XCTAssertFalse(view.delaysContentTouches,
                   @"a delayed touch is a catch, a caret and a tap that all arrive 150ms late");
    XCTAssertTrue(view.canCancelContentTouches,
                  @"…and the pan still takes the touch away once it is a scroll");
}

/// A run caught mid-rubber-band is HELD where the finger stopped it, and springs back when the
/// finger lifts — the two halves of catching a bounce.
///
/// Clamping at the catch instead snapped the run home the instant it was touched, which is not
/// catching it: iOS holds the content out under the finger. The settle is the other half, and it has
/// to exist because a run is told about touches only when they BEGIN (its pan's delegate callback);
/// a canvas-hosted observer reports the end.
- (void)testACatchHoldsARunWhereItIsAndTheReleaseSettlesItBackIntoRange {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIScrollView *run = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    IDBlockStackCanvasView *canvas = (IDBlockStackCanvasView *)run.superview;
    CGFloat maxOffset = run.contentSize.width - CGRectGetWidth(run.bounds);
    XCTAssertGreaterThan(maxOffset, 0, @"precondition: this run scrolls");

    // The run's class is private to the engine, so these go through the runtime — which is also how
    // the canvas's release observer reaches it.
    SEL settle = NSSelectorFromString(@"id_settleIfCaughtByEndedTouches:");
    void (*settleRun)(id, SEL, id) = (void (*)(id, SEL, id))[run methodForSelector:settle];
    NSObject *catchingTouch = [NSObject new];   // stands in for the touch; held strongly here

    // A touch ending with NO catch behind it leaves the run alone — the ordinary rubber band is
    // UIKit's to animate, and clamping it here ate it in one frame (K3: "the bounce is still not
    // catching", because there was no bounce left to catch).
    run.contentOffset = CGPointMake(maxOffset + 30.0, 0.0);
    settleRun(run, settle, nil);
    XCTAssertEqualWithAccuracy(run.contentOffset.x, maxOffset + 30.0, 0.5,
                               @"an ordinary release keeps its bounce");

    // With a catch behind it, the same release brings the run back to its edge.
    [run setValue:catchingTouch forKey:@"caughtTouch"];
    settleRun(run, settle, nil);
    XCTAssertEqualWithAccuracy(run.contentOffset.x, maxOffset, 1.0,
                               @"the release brings a run CAUGHT outside its range back to the edge");

    CGFloat inRange = maxOffset / 2.0;
    run.contentOffset = CGPointMake(inRange, 0.0);
    [run setValue:catchingTouch forKey:@"caughtTouch"];
    settleRun(run, settle, nil);
    XCTAssertEqualWithAccuracy(run.contentOffset.x, inRange, 0.5,
                               @"a run caught inside its range is left exactly where it was caught");
}

/// A run is still IN FLIGHT at the one instant UIKit says it is not.
///
/// Traced on device (K3, iOS 27.0, a run 25pt into its rubber band): the frame before the touch
/// reads `decel=1`, the `gestureRecognizer:shouldReceiveTouch:` callback reads
/// `decel=0 drag=0 track=1`, and the frame 16ms later reads `decel=1` again — after which the run
/// springs home under a finger that is still down. So the catch's gate, which asked
/// `isDecelerating` inside that callback, declined EVERY catch: in a 164-line trace of six touches
/// it never once fired. This pins the durable fact it asks instead — that the run MOVED a moment
/// ago — and the pin that holds it, which the single offset assignment could not do (with no
/// deceleration in progress there is no animation for it to cancel, and UIKit resumes on the next
/// frame).
- (void)testARunIsCaughtInTheInstantUIKitReportsItIsNotDecelerating {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIScrollView *run = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    CGFloat maxOffset = run.contentSize.width - CGRectGetWidth(run.bounds);
    XCTAssertGreaterThan(maxOffset, 0, @"precondition: this run scrolls");

    SEL animating = NSSelectorFromString(@"id_isAnimatingNow");
    BOOL (*isAnimatingNow)(id, SEL) = (BOOL (*)(id, SEL))[run methodForSelector:animating];
    XCTAssertFalse(isAnimatingNow(run, animating), @"a run nobody has touched is not in flight");

    // A frame of the bounce: the run moved under its own animation a moment ago. `isDecelerating` is
    // NO right now — which is exactly the state the device reports inside the callback.
    [run setValue:@(CACurrentMediaTime()) forKey:@"id_lastAnimatedMotionTime"];
    XCTAssertFalse(run.isDecelerating, @"precondition: this is the instant the old gate read");
    XCTAssertTrue(isAnimatingNow(run, animating),
                  @"a run that moved a frame ago is in flight, whatever isDecelerating says");

    // And it stops being in flight once the motion is genuinely old, so a settled run is not caught
    // by the next touch that lands on it.
    [run setValue:@(CACurrentMediaTime() - 1.0) forKey:@"id_lastAnimatedMotionTime"];
    XCTAssertFalse(isAnimatingNow(run, animating), @"a settled run is not in flight");
}

/// A caught run does not move until the finger lets go, and a DRAG hands it back.
- (void)testACaughtRunIsPinnedUntilTheFingerLiftsAndADragReleasesIt {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIScrollView *run = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    CGFloat maxOffset = run.contentSize.width - CGRectGetWidth(run.bounds);
    XCTAssertGreaterThan(maxOffset, 0, @"precondition: this run scrolls");

    CGFloat caughtAt = maxOffset + 25.0;   // mid-rubber-band, where the device trace caught one
    // A REAL UITouch, held strongly (`caughtTouch` is weak): the hold predicate asks it for its
    // `phase`, and a bare stand-in object answers that with an unrecognised selector. A fresh
    // UITouch reports `UITouchPhaseBegan`, which is a finger that is down.
    UITouch *catchingTouch = [UITouch new];
    run.contentOffset = CGPointMake(caughtAt, 0.0);
    [run setValue:catchingTouch forKey:@"caughtTouch"];
    [run setValue:@(caughtAt) forKey:@"id_heldOffsetX"];

    // UIKit's own bounce, resuming on the next frame: every assignment is refused while the finger
    // is down. Without the pin the run walks home exactly like this, which is the reported defect.
    for (CGFloat x = caughtAt - 4.0; x > maxOffset; x -= 4.0) {
        run.contentOffset = CGPointMake(x, 0.0);
        XCTAssertEqualWithAccuracy(run.contentOffset.x, caughtAt, 0.5,
                                   @"a caught run is held where the finger stopped it");
    }

    // The catch is not a freeze: once the pan begins, the run is the drag's again.
    [run setValue:nil forKey:@"caughtTouch"];
    run.contentOffset = CGPointMake(maxOffset, 0.0);
    XCTAssertEqualWithAccuracy(run.contentOffset.x, maxOffset, 0.5,
                               @"a released run follows its offset again");
}

/// A host can ask whether a run is IN FLIGHT, which is what lets it keep an outer drag off one.
///
/// A sheet that dismisses on a downward pan recognises simultaneously with every other pan and
/// decides by walking up to the nearest vertical scroll view, so a finger put down to catch a
/// coasting run starts the dismiss instead of catching it (Telegram, K3, 2026-09-11). The run is not
/// in the touch's responder chain and cannot defend itself; the host does, and this is what it asks.
- (void)testAHostCanAskWhetherAPlacedRunIsInFlight {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    XCTAssertFalse(view.id_hasPlacedRunInFlight, @"a run at rest is not in flight");

    // A run scrolled programmatically is not in flight either: no finger, no momentum, nothing for an
    // outer gesture to take away.
    [view id_setPlacedRunContentOffset:40 forBlockAtIndex:1];
    [view layoutIfNeeded];
    XCTAssertEqualWithAccuracy([view id_placedRunContentOffsetForBlockAtIndex:1], 40, 0.5,
                               @"precondition: it did move");
    XCTAssertFalse(view.id_hasPlacedRunInFlight);

    // A document with no placed blocks at all has no runs to be in flight.
    view.blockFrames = nil;
    [view layoutIfNeeded];
    XCTAssertFalse(view.id_hasPlacedRunInFlight);
}

/// A finger down on a decelerating run stops it, and the run has to be told by UIKit's own per-touch
/// callback because a touch never reaches it.
///
/// Every touch in this tree lands on the stack canvas — the block canvases and the run let them fall
/// through so the text interaction sees a cell — so a run is not in the touch's responder chain at
/// all, and `-[UIScrollView touchesBegan:withEvent:]`, which is what stops a decelerating scroll
/// view under a finger, is never called on it. Measured: from a point over a cell the chain is
/// canvas → text view → host, with the run nowhere in it.
///
/// `gestureRecognizer:shouldReceiveTouch:` for the run's own pan is the hook, and it is UIKit's:
/// delivered as the pan receives the touch, wherever the pan is hosted, whatever delay the enclosing
/// scroll view puts on content touches, with no recogniser of ours competing for it.
- (void)testARunIsToldAboutTouchesThroughItsPansDelegateBecauseItNeverSeesThem {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIView *content = [view id_placedRunContentViewForBlockAtIndex:1];
    UIScrollView *run = (UIScrollView *)content.superview;
    IDBlockStackCanvasView *canvas = (IDBlockStackCanvasView *)run.superview;

    // The run really is out of reach — that is why the hook has to be the pan's.
    UIView *hit = [view hitTest:[view convertPoint:CGPointMake(CGRectGetMidX(run.frame),
                                                              CGRectGetMidY(run.frame))
                                          fromView:canvas]
                      withEvent:nil];
    UIResponder *step = hit;
    BOOL reachesRun = NO;
    for (NSUInteger depth = 0; step != nil && depth < 8; depth++) {
        reachesRun = reachesRun || step == run;
        step = step.nextResponder;
    }
    XCTAssertFalse(reachesRun, @"a touch over the run does not reach it");

    // The run answers its pan's per-touch callback, and answering it decides nothing about the
    // gesture: the pan's own gate is what accepts or declines a drag.
    XCTAssertTrue([run respondsToSelector:@selector(gestureRecognizer:shouldReceiveTouch:)]);
    XCTAssertEqual(run.panGestureRecognizer.delegate, (id<UIGestureRecognizerDelegate>)run,
                   @"the run is its own pan's delegate, wherever the pan is hosted");
    XCTAssertTrue([(id<UIGestureRecognizerDelegate>)run gestureRecognizer:run.panGestureRecognizer
                                                       shouldReceiveTouch:(UITouch *)[NSObject new]],
                  @"every touch is received; this callback only catches a deceleration in passing");

    // Where a caught run settles: where it is, clamped into its own range — a touch during the
    // rubber band must not leave it outside, because the bounce it interrupted is what would have
    // brought it back.
    XCTAssertEqualWithAccuracy([IDBlockStackCanvasView id_caughtRunOffsetForCurrent:40 maximum:280], 40, 0.5);
    XCTAssertEqualWithAccuracy([IDBlockStackCanvasView id_caughtRunOffsetForCurrent:-18 maximum:280], 0, 0.5,
                               @"bouncing off the leading edge");
    XCTAssertEqualWithAccuracy([IDBlockStackCanvasView id_caughtRunOffsetForCurrent:305 maximum:280], 280, 0.5,
                               @"bouncing off the trailing edge");
    XCTAssertEqualWithAccuracy([IDBlockStackCanvasView id_caughtRunOffsetForCurrent:9 maximum:-4], 0, 0.5,
                               @"a run with no range at all");
}

/// A run scrolls until its far edge reaches its COLUMN, and the CLIP has nothing to say about it.
///
/// The two questions are different — what is visible, and where the run belongs — and conflating
/// them broke both ways. Derived from the clip, a run whose window was narrower than the column
/// could not reach its own right edge at all (the last 22pt stayed unreachable and a host drawing
/// anything on that edge never saw it); derived from the clip the other way, a run whose window was
/// WIDER would come to rest out in that margin instead of in its column.
- (void)testARunScrollsToItsColumnsEdgeWhateverItsClipShows {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    view.textContainerInset = UIEdgeInsetsMake(8, 16, 8, 16);
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIScrollView *plain = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    CGFloat plainTravel = plain.contentSize.width - CGRectGetWidth(plain.bounds);

    // A narrower COLUMN adds travel: the part of the run beyond it must still be reachable.
    view.placedRunColumnOutsets = @{ blocks[1].identifier:
        [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(0, -16, 0, -22)] };
    [view layoutIfNeeded];
    UIScrollView *narrow = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    XCTAssertEqualWithAccuracy(narrow.contentSize.width - CGRectGetWidth(narrow.bounds),
                               plainTravel + 22, 0.5,
                               @"22 narrower on the right, 22 further to travel");

    // The CLIP does not move it. Opened 15 on each side — a host showing the run through a margin it
    // does not belong in — the travel is the column's, unchanged.
    view.placedRunClipOutsets = @{ blocks[1].identifier:
        [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(0, -1, 0, -7)] };
    [view layoutIfNeeded];
    UIScrollView *wideWindow = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    XCTAssertEqualWithAccuracy(wideWindow.contentSize.width - CGRectGetWidth(wideWindow.bounds),
                               plainTravel + 22, 0.5,
                               @"the clip is what is visible, not where the run rests");

    // …and at the end of that travel the run's right edge is in its COLUMN, with the window showing
    // the 15pt of margin beyond it — which is where a host draws a handle that hangs off the edge.
    wideWindow.contentOffset = CGPointMake(wideWindow.contentSize.width - CGRectGetWidth(wideWindow.bounds), 0);
    [view layoutIfNeeded];
    CGRect lastCell = [view id_frameForBlockAtIndex:2];
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(wideWindow.frame) - CGRectGetMaxX(lastCell), 15.0, 0.5,
                               @"the run rests in its column and the window reaches 15 past it");
}

/// Two GROUPS of placed blocks with nothing stacked between them are one run unless the host says
/// otherwise, and adjacency cannot tell them apart — only the host knows where one table ends.
///
/// Undeclared, the four blocks below share one scroll view: dragging either table scrolled both, and
/// the clip (keyed by the run's FIRST block) was the first table's, so a second table that wanted a
/// narrower window — one inside a host-drawn container — was cut at the first one's edge instead.
/// Declaring the second group's first block splits them, and nothing MOVES: each cell keeps the
/// absolute frame it had, because the second run's anchor is exactly where the first run's extent
/// left the stacking cursor.
- (void)testADeclaredRunStartSplitsTwoAdjacentGroupsOfPlacedBlocks {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"c", @"d"]
                                            frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)],
                          blocks[3].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[4].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    XCTAssertEqual([view id_placedRunContentViewForBlockAtIndex:1],
                   [view id_placedRunContentViewForBlockAtIndex:3],
                   @"precondition: adjacency alone makes these ONE run");
    CGRect firstBefore = [view id_frameForBlockAtIndex:1];
    CGRect secondBefore = [view id_frameForBlockAtIndex:3];

    view.placedRunStarts = [NSSet setWithObject:blocks[3].identifier];
    [view layoutIfNeeded];
    UIView *firstContent = [view id_placedRunContentViewForBlockAtIndex:1];
    UIView *secondContent = [view id_placedRunContentViewForBlockAtIndex:3];
    XCTAssertNotEqual(firstContent, secondContent, @"two runs now");
    XCTAssertNotEqual(firstContent.superview, secondContent.superview, @"and two scroll views");
    XCTAssertEqualWithAccuracy(CGRectGetMinX([view id_frameForBlockAtIndex:1]),
                               CGRectGetMinX(firstBefore), 0.5, @"the first group does not move");
    XCTAssertEqualWithAccuracy(CGRectGetMinY([view id_frameForBlockAtIndex:1]),
                               CGRectGetMinY(firstBefore), 0.5);
    // The second group's frames are relative to the SECOND run's anchor now, and that anchor is
    // where the first run's extent left the stacking cursor — so the same `y = 0` frames that used
    // to land ON TOP of the first table (both groups shared one anchor) now sit below it. A host
    // that was adding the first run's height to its own frames stops doing that; the two halves of
    // this change belong together.
    XCTAssertEqualWithAccuracy(CGRectGetMinY([view id_frameForBlockAtIndex:3]),
                               CGRectGetMinY(secondBefore) + 40, 0.5,
                               @"the second group anchors one run extent lower, not on top of the first");

    // Each run scrolls by itself, which is the reported defect: one finger moved both tables.
    UIScrollView *firstScroll = (UIScrollView *)firstContent.superview;
    UIScrollView *secondScroll = (UIScrollView *)secondContent.superview;
    firstScroll.contentOffset = CGPointMake(40, 0);
    [view layoutIfNeeded];
    XCTAssertEqualWithAccuracy(secondScroll.contentOffset.x, 0.0, 0.5,
                               @"scrolling one run leaves the other where it was");

    // …and each takes its OWN clip, which the shared run could not express.
    view.placedRunClipOutsets = @{ blocks[3].identifier:
        [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(0, -20, 0, 0)] };
    [view layoutIfNeeded];
    firstScroll = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    secondScroll = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:3].superview;
    XCTAssertEqualWithAccuracy(CGRectGetMinX(secondScroll.frame) - CGRectGetMinX(firstScroll.frame),
                               20.0, 0.5, @"the second run's window is narrowed and the first's is not");
}

/// A run's clip is a HOST decision, and the outset moves it without moving the run: the scroll view
/// grows on each side and its content view shifts by the leading amount, so the content is laid out
/// where it always was and only the window onto it changes. The scrollable range does not move
/// either — the content size grows by exactly what the frame grew by.
- (void)testAClipOutsetWidensARunsWindowWithoutMovingItsContentOrItsRange {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    view.textContainerInset = UIEdgeInsetsMake(8, 12, 8, 9);
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIView *content = [view id_placedRunContentViewForBlockAtIndex:1];
    UIScrollView *scroll = (UIScrollView *)content.superview;
    CGRect plainFrame = scroll.frame;
    CGFloat plainRange = scroll.contentSize.width - CGRectGetWidth(scroll.bounds);
    CGRect plainCell = [view id_frameForBlockAtIndex:1];

    view.placedRunClipOutsets = @{ blocks[1].identifier:
        [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(0, 12, 0, 9)] };
    [view layoutIfNeeded];
    content = [view id_placedRunContentViewForBlockAtIndex:1];
    scroll = (UIScrollView *)content.superview;
    XCTAssertEqualWithAccuracy(CGRectGetMinX(scroll.frame), CGRectGetMinX(plainFrame) - 12, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(scroll.frame), CGRectGetWidth(plainFrame) + 21, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(content.frame), 12, 0.5,
                               @"the content shifts by the leading outset, so it does not move");
    XCTAssertEqualWithAccuracy(scroll.contentSize.width - CGRectGetWidth(scroll.bounds), plainRange, 0.5,
                               @"the scrollable range is the run against its COLUMN either way");
    XCTAssertEqualWithAccuracy(CGRectGetMinX([view id_frameForBlockAtIndex:1]),
                               CGRectGetMinX(plainCell), 0.5, @"and the cell is where it was");

    // Negative narrows it, for a run inside a host-drawn container whose interior is inside the
    // column — the same arithmetic, the other way.
    view.placedRunClipOutsets = @{ blocks[1].identifier:
        [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(0, -20, 0, 0)] };
    [view layoutIfNeeded];
    scroll = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    XCTAssertEqualWithAccuracy(CGRectGetMinX(scroll.frame), CGRectGetMinX(plainFrame) + 20, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(scroll.frame), CGRectGetWidth(plainFrame) - 20, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMinX([view id_frameForBlockAtIndex:1]),
                               CGRectGetMinX(plainCell), 0.5, @"still where it was");
}

/// UIScrollView holds an out-of-range offset on purpose while it rubber-bands, and every scroll tick
/// re-runs the pass (`scrollViewDidScroll:` marks the text view for layout). A pass that clamped the
/// offset on every run cancelled the band one frame at a time — a run wider than the canvas never
/// overscrolled at all (Telegram, K3, 2026-09-10). The pass owns the offset only when it changes the
/// run's geometry.
- (void)testALayoutPassLeavesARubberBandedOffsetAloneUntilTheRunsGeometryChanges {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"bottom"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIScrollView *scroll = (UIScrollView *)[view id_placedRunContentViewForBlockAtIndex:1].superview;
    CGFloat maxOffset = scroll.contentSize.width - CGRectGetWidth(scroll.bounds);
    XCTAssertGreaterThan(maxOffset, 0);
    // The PASS is driven directly, at the width the text view's own layout hands it. An idle
    // `UIScrollView` clamps its offset in its own `layoutSubviews` (only a tracking or decelerating
    // one keeps an out-of-range value), so `-layoutIfNeeded` on the text view could never hold the
    // band here — and it is the pass, not UIKit, that clamped under a finger.
    CGFloat layoutWidth = CGRectGetWidth(view.bounds) - view.textContainerInset.left - view.textContainerInset.right;

    scroll.contentOffset = CGPointMake(-30, 0);              // past the leading edge, mid-band
    [view.id_blockStackCanvasView updateForDocumentChange:nil width:layoutWidth];
    XCTAssertEqualWithAccuracy(scroll.contentOffset.x, -30.0, 0.5, @"a pass that changes no geometry does not clamp");

    scroll.contentOffset = CGPointMake(maxOffset + 40, 0);   // past the trailing edge
    [view.id_blockStackCanvasView updateForDocumentChange:nil width:layoutWidth];
    XCTAssertEqualWithAccuracy(scroll.contentOffset.x, maxOffset + 40, 0.5);

    // A pass that NARROWS the run still clamps: the offset is out of range for good, not mid-band.
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 200, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(200, 0, 200, 40)] };
    [view layoutIfNeeded];
    XCTAssertEqualWithAccuracy(scroll.contentOffset.x, 400.0 - CGRectGetWidth(scroll.bounds), 0.5,
                               @"clamped to the new maximum once the geometry changed");
}

- (void)testScrollingARunShiftsItsBlocksGeometryAndHitTesting {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"bottom"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    CGRect aBefore = [view id_frameForBlockAtIndex:1];
    [view id_setPlacedRunContentOffset:250.0 forBlockAtIndex:1];
    [view layoutIfNeeded];
    XCTAssertEqualWithAccuracy([view id_placedRunContentOffsetForBlockAtIndex:1], 250.0, 0.5);
    CGRect aAfter = [view id_frameForBlockAtIndex:1];
    XCTAssertEqualWithAccuracy(CGRectGetMinX(aBefore) - CGRectGetMinX(aAfter), 250.0, 0.5, @"a moved left by the offset");
    // The point where `b` now is resolves to `b` (canonical 6), not to `a`.
    CGPoint inB = CGPointMake(CGRectGetMinX(aBefore) + 80.0, CGRectGetMinY(aBefore) + 10.0);   // 300 − 250 + 30
    UITextPosition *hit = [view closestPositionToPoint:inB];
    NSInteger offset = [view offsetFromPosition:view.beginningOfDocument toPosition:hit];
    XCTAssertTrue(offset >= 6 && offset <= 7, @"landed at %ld, expected inside b", (long)offset);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(aAfter), CGRectGetMinY(aBefore), 0.5, @"only x moves");
}

- (void)testATouchInsideAPlacedRunFallsThroughToTheStackCanvasAndThePanLivesThere {
    IDBlockTextView *view = [self viewWithStrings:@[@"top", @"a", @"b", @"bottom"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 40)],
                          blocks[2].identifier: [NSValue valueWithCGRect:CGRectMake(300, 0, 300, 40)] };
    [view layoutIfNeeded];
    UIView *content = [view id_placedRunContentViewForBlockAtIndex:1];
    UIScrollView *scroll = (UIScrollView *)content.superview;
    CGRect a = [view id_frameForBlockAtIndex:1];
    // A point in the EMPTY part of a cell (right of its one-letter text), in the stack's coordinates.
    CGPoint inCell = [view.id_blockStack convertPoint:CGPointMake(CGRectGetMinX(a) + 120.0, CGRectGetMidY(a)) fromView:view];
    UIView *hit = [view.id_blockStack hitTest:inCell withEvent:nil];
    XCTAssertEqual(hit, view.id_blockStack, @"the touch must reach the stack canvas, not %@", hit);
    XCTAssertEqual(scroll.panGestureRecognizer.view, view.id_blockStack, @"the run's pan is hosted by the stack canvas");
    view.blockFrames = nil;
    [view layoutIfNeeded];
    XCTAssertFalse([view.id_blockStack.gestureRecognizers containsObject:scroll.panGestureRecognizer],
                   @"a retired run takes its pan with it");
}

- (void)testTheContentViewAcceptsHostChildrenBehindTheCanvases {
    IDBlockTextView *view = [self viewWithStrings:@[@"a", @"b"] frame:CGRectMake(0, 0, 320, 400)];
    NSArray<IDBlock *> *blocks = view.id_document.blocks;
    view.blockFrames = @{ blocks[0].identifier: [NSValue valueWithCGRect:CGRectMake(0, 0, 100, 40)],
                          blocks[1].identifier: [NSValue valueWithCGRect:CGRectMake(100, 0, 100, 40)] };
    [view layoutIfNeeded];
    UIView *content = [view id_placedRunContentViewForBlockAtIndex:0];
    UIView *chrome = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
    [content insertSubview:chrome atIndex:0];
    [view layoutIfNeeded];   // a relayout must not evict or reorder the host's child
    XCTAssertEqual(chrome.superview, content);
    XCTAssertEqual([content.subviews indexOfObject:chrome], 0u, @"stays behind the canvases");
}

#pragma mark - Corrections inside the change notification

/// The contract the host's structural resolver rests on (spec §2): an edit the controller
/// requested is applied as requested, and a correction issued THROUGH THE CONTROLLER'S API from
/// inside the adapter's change notification lands in the same undo group. One undo then restores
/// the pre-keystroke text; redo re-applies both; the first block's identity is stable throughout.
/// Measured 2026-09-04: a correction from a run-loop block or `dispatch_async` makes TWO groups,
/// and a rejection at the storage seam corrupts undo (the controller records its request).
///
/// The one rule a correcting host must follow: NO correction while the undo manager is undoing or
/// redoing. An undo replays the group's inverse edits one at a time through the same storage, so
/// the change notification fires for each intermediate state — the first replay re-inserts what
/// the correction deleted, and a correction that fires there deletes it again and defeats the undo.
/// (Measured by swizzling `NSUndoManager`: the keystroke registers a typing operation and opens the
/// group, the nested correction registers a replace operation at grouping level 1 in that group,
/// and `undoNestedGroup` pops the replace first, then the typing operation.)
- (void)installCorrection:(void (^)(IDBlockTextView *view, IDBlockDocumentChange *change))correction
                   inView:(IDBlockTextView *)view {
    IDCanonicalTextStorageAdapter *adapter = view.id_textStorageAdapter;
    void (^engineHandler)(IDBlockDocumentChange *) = adapter.documentChangeHandler;
    __block BOOL correcting = NO;
    __weak IDBlockTextView *weakView = view;
    adapter.documentChangeHandler = ^(IDBlockDocumentChange *change) {
        if (engineHandler != nil) engineHandler(change);
        IDBlockTextView *v = weakView;
        if (v == nil || correcting) return;
        if (v.undoManager.isUndoing || v.undoManager.isRedoing) return;
        correcting = YES;
        correction(v, change);
        correcting = NO;
    };
}

- (NSString *)joinedTextOf:(IDBlockTextView *)view {
    return [view.id_textStorageAdapter.string stringByReplacingOccurrencesOfString:@"\n" withString:@"|"];
}

- (void)testACorrectionOfAnInsertGroupsWithTheKeystrokesUndo {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"] frame:CGRectMake(0, 0, 320, 400)];
    __unused UIWindow *window = [self hostView:view];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    NSUUID *firstID = view.id_document.blocks[0].identifier;
    UITextPosition *p = [view positionFromPosition:view.beginningOfDocument offset:2];
    view.selectedTextRange = [view textRangeFromPosition:p toPosition:p];
    // The correction: a "\n" inserted into the first block is deleted again (Return → caret move).
    [self installCorrection:^(IDBlockTextView *v, IDBlockDocumentChange *change) {
        if (change.replacementLength != 1 || change.replacedCanonicalRange.length != 0) return;
        NSRange inserted = NSMakeRange(change.replacedCanonicalRange.location, 1);
        if (![[v.id_textStorageAdapter.string substringWithRange:inserted] isEqualToString:@"\n"]) return;
        UITextPosition *a = [v positionFromPosition:v.beginningOfDocument offset:inserted.location];
        UITextPosition *b = [v positionFromPosition:a offset:1];
        [v replaceRange:[v textRangeFromPosition:a toPosition:b] withText:@""];
    } inView:view];
    [view insertText:@"\n"];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpha|beta", @"corrected synchronously");
    XCTAssertEqual(view.id_document.blocks.count, 2u);
    XCTAssertEqualObjects(view.id_document.blocks[0].identifier, firstID, @"a split re-merged keeps the first identity");
    XCTAssertTrue(view.undoManager.canUndo);
    [view.undoManager undo];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpha|beta", @"ONE undo reverts request and correction together");
    XCTAssertFalse(view.undoManager.canUndo, @"nothing is left on the stack");
    [view.undoManager redo];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpha|beta");
}

- (void)testACorrectionOfADeleteGroupsWithTheKeystrokesUndo {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"] frame:CGRectMake(0, 0, 320, 400)];
    __unused UIWindow *window = [self hostView:view];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    NSUUID *firstID = view.id_document.blocks[0].identifier;
    UITextPosition *p = [view positionFromPosition:view.beginningOfDocument offset:6];   // start of "beta"
    view.selectedTextRange = [view textRangeFromPosition:p toPosition:p];
    // The correction: a backspace that deleted the separator (merging the blocks) re-inserts it.
    [self installCorrection:^(IDBlockTextView *v, IDBlockDocumentChange *change) {
        if (change.replacementLength != 0 || change.replacedCanonicalRange.length != 1) return;
        if (v.id_document.blocks.count != 1) return;
        UITextPosition *a = [v positionFromPosition:v.beginningOfDocument offset:change.replacedCanonicalRange.location];
        [v replaceRange:[v textRangeFromPosition:a toPosition:a] withText:@"\n"];
    } inView:view];
    [view deleteBackward];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpha|beta");
    XCTAssertEqual(view.id_document.blocks.count, 2u);
    XCTAssertEqualObjects(view.id_document.blocks[0].identifier, firstID);
    [view.undoManager undo];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpha|beta");
    XCTAssertFalse(view.undoManager.canUndo);
}

- (void)testACorrectionOfASpanningReplaceGroupsWithTheKeystrokesUndo {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"] frame:CGRectMake(0, 0, 320, 400)];
    __unused UIWindow *window = [self hostView:view];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    NSUUID *firstID = view.id_document.blocks[0].identifier;
    UITextPosition *a = [view positionFromPosition:view.beginningOfDocument offset:3];   // "alp|ha"
    UITextPosition *b = [view positionFromPosition:view.beginningOfDocument offset:8];   // "be|ta"
    view.selectedTextRange = [view textRangeFromPosition:a toPosition:b];
    // The correction: the merged block is re-split with per-block texts — head + typed, then tail.
    [self installCorrection:^(IDBlockTextView *v, IDBlockDocumentChange *change) {
        if (v.id_document.blocks.count != 1) return;
        UITextPosition *s = v.beginningOfDocument;
        UITextPosition *e = v.endOfDocument;
        [v replaceRange:[v textRangeFromPosition:s toPosition:e] withText:@"alpX\nta"];
    } inView:view];
    [view insertText:@"X"];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpX|ta", @"legacy's head + typed / tail rule");
    XCTAssertEqual(view.id_document.blocks.count, 2u);
    XCTAssertEqualObjects(view.id_document.blocks[0].identifier, firstID);
    [view.undoManager undo];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpha|beta", @"one undo restores the original");
    XCTAssertFalse(view.undoManager.canUndo);
    [view.undoManager redo];
    XCTAssertEqualObjects([self joinedTextOf:view], @"alpX|ta");
}

#pragma mark - Empty-line providers and attribute-only edits

- (void)testAnEmptyBlockOutsideTheMapAdoptsTheProvidersAttributes {
    IDBlockTextView *view = [self viewWithStrings:@[@"first", @""] frame:CGRectMake(0, 0, 320, 400)];
    __unused UIWindow *window = [self hostView:view];
    [view layoutIfNeeded];
    NSUUID *emptyID = view.id_document.blocks[1].identifier;
    UIFont *big = [UIFont systemFontOfSize:31];
    __block NSUInteger asked = 0;
    view.id_emptyLineAttributesProvider = ^NSDictionary<NSAttributedStringKey, id> *(NSUUID *identifier) {
        asked += 1;
        return [identifier isEqual:emptyID] ? @{ NSFontAttributeName: big } : nil;
    };
    view.id_emptyLineCaretOffsetProvider = ^NSNumber *(NSUUID *identifier) {
        return [identifier isEqual:emptyID] ? @(40.0) : nil;
    };
    [view layoutIfNeeded];
    XCTAssertGreaterThan(asked, 0u, @"the provider is consulted by the layout pass");
    CGRect emptyFrame = [view id_frameForBlockAtIndex:1];
    XCTAssertGreaterThan(CGRectGetHeight(emptyFrame), 30.0, @"the empty line is measured with the provider's font");
    XCTAssertTrue([view becomeFirstResponder]);
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];
    CGRect caret = [view caretRectForPosition:end];
    XCTAssertGreaterThan(CGRectGetMinX(caret), CGRectGetMinX(emptyFrame) + 30.0, @"the caret sits at the provider's offset");
    [view insertText:@"q"];
    UIFont *typed = [view.id_document.blocks[1].attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    XCTAssertEqualWithAccuracy(typed.pointSize, 31.0, 0.5, @"typing adopts the provider's attributes");
}

/// A host learns what a FRESH block is only inside the change notification, and — as the host
/// chains the adapter's handler — after the engine's own handling of that change. The controller
/// has moved the selection into the fresh empty block by then, so the selection-change adoption
/// ran before the host could answer — or so a host that saw its answer ignored might think. Measured
/// 2026-09-04: the controller's selection change reaches the view AFTER the chained handlers, so the
/// adoption already sees the settled answer. This pins that order; a host that still types with the
/// wrong attributes is overwriting them itself.
- (void)testAFreshEmptyBlockTypesWithTheAttributesTheHostSettledInsideTheNotification {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"] frame:CGRectMake(0, 0, 320, 400)];
    __unused UIWindow *window = [self hostView:view];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    NSMutableDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *known = [NSMutableDictionary dictionary];
    view.id_emptyLineAttributesProvider = ^NSDictionary<NSAttributedStringKey, id> *(NSUUID *identifier) {
        return known[identifier];
    };
    IDCanonicalTextStorageAdapter *adapter = view.id_textStorageAdapter;
    void (^engineHandler)(IDBlockDocumentChange *) = adapter.documentChangeHandler;
    __weak IDBlockTextView *weakView = view;
    adapter.documentChangeHandler = ^(IDBlockDocumentChange *change) {
        if (engineHandler != nil) engineHandler(change);
        for (IDBlock *block in weakView.id_document.blocks) {
            if (block.attributedText.length == 0) {
                known[block.identifier] = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:30]};
            }
        }
    };
    UITextPosition *p = [view positionFromPosition:view.beginningOfDocument offset:5];   // alpha|
    view.selectedTextRange = [view textRangeFromPosition:p toPosition:p];
    [view insertText:@"\n"];
    XCTAssertEqual(view.id_document.blocks.count, 3u);
    XCTAssertEqual(view.id_document.blocks[1].attributedText.length, 0u, @"the caret's block is the fresh empty one");
    UIFont *typing = view.id_behaviorInput.typingAttributes[NSFontAttributeName];
    XCTAssertEqual(typing.pointSize, 30.0, @"adopted after the host settled its answer");
    [view insertText:@"x"];
    UIFont *typed = [view.id_document.blocks[1].attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    XCTAssertEqual(typed.pointSize, 30.0, @"what is typed wears the settled attributes");
}

/// A Return at the END of the document keeps the typing attributes it had (a heading stays a
/// heading in the paragraph it opens) — unless the host answers for the fresh block, in which case
/// its answer wins. A pull quote's author line ends the document, and a Return there once typed
/// the paragraph after the quote in the author's face because the preserved attributes overwrote
/// the adoption (measured 2026-09-04).
- (void)testAReturnAtTheEndOfTheDocumentStillAdoptsTheProvidersAnswerForTheFreshBlock {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha"] frame:CGRectMake(0, 0, 320, 400)];
    __unused UIWindow *window = [self hostView:view];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    NSMutableDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *known = [NSMutableDictionary dictionary];
    view.id_emptyLineAttributesProvider = ^NSDictionary<NSAttributedStringKey, id> *(NSUUID *identifier) {
        return known[identifier];
    };
    IDCanonicalTextStorageAdapter *adapter = view.id_textStorageAdapter;
    void (^engineHandler)(IDBlockDocumentChange *) = adapter.documentChangeHandler;
    __weak IDBlockTextView *weakView = view;
    adapter.documentChangeHandler = ^(IDBlockDocumentChange *change) {
        if (engineHandler != nil) engineHandler(change);
        for (IDBlock *block in weakView.id_document.blocks) {
            if (block.attributedText.length == 0) {
                known[block.identifier] = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:30]};
            }
        }
    };
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange = [view textRangeFromPosition:end toPosition:end];
    [view insertText:@"\n"];
    XCTAssertEqual(view.id_document.blocks.count, 2u);
    UIFont *typing = view.id_behaviorInput.typingAttributes[NSFontAttributeName];
    XCTAssertEqual(typing.pointSize, 30.0, @"the host's answer for the fresh block wins over the preserved attributes");
    [view insertText:@"x"];
    UIFont *typed = [view.id_document.blocks[1].attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    XCTAssertEqual(typed.pointSize, 30.0);
}

- (void)testAHostAttributeOnlyEditChangesStyleNotTextAndLeavesUndoAlone {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"] frame:CGRectMake(0, 0, 320, 400)];
    __unused UIWindow *window = [self hostView:view];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    [view insertText:@"x"];   // one real undo entry
    XCTAssertTrue(view.undoManager.canUndo);
    UIFont *big = [UIFont systemFontOfSize:29];
    [view id_setAttributes:@{ NSFontAttributeName: big } inCanonicalRange:NSMakeRange(0, 3)];
    XCTAssertEqualObjects([view.id_textStorageAdapter.string stringByReplacingOccurrencesOfString:@"\n" withString:@"|"], @"xalpha|beta");
    UIFont *styled = [view.id_document.blocks[0].attributedText attribute:NSFontAttributeName atIndex:1 effectiveRange:NULL];
    XCTAssertEqualWithAccuracy(styled.pointSize, 29.0, 0.5);
    [view.undoManager undo];
    XCTAssertEqualObjects([view.id_textStorageAdapter.string stringByReplacingOccurrencesOfString:@"\n" withString:@"|"], @"alpha|beta",
                          @"the controller's undo still reverts the keystroke; the attribute edit did not disturb its offsets");
}

/// The reported symptom, end to end: a selection that ends on an empty line is drawn.
///
/// Reported as "the selection is not visible if at least one of the selected lines is empty". The
/// mechanism is not about emptiness — it is that the selection's boundary lands on a paragraph
/// break — but an empty line has only one offset, so every selection touching one is bounded that
/// way and the symptom is total (2026-09-15).
- (void)testASelectionEndingOnAnEmptyLineIsStillDrawn {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"", @"beta"]
                                            frame:CGRectMake(0, 0, 240, 200)];
    __unused UIWindow *window = [self hostView:view];
    // "alpha\n" — the caret would sit on the empty line.
    UITextRange *range = [view
        textRangeFromPosition:view.beginningOfDocument
                   toPosition:[view positionFromPosition:view.beginningOfDocument offset:6]];

    NSArray<UITextSelectionRect *> *rects = [view selectionRectsForRange:range];

    XCTAssertGreaterThan(rects.count, 0U, @"no selection was drawn at all");
    CGFloat area = 0.0;
    for (UITextSelectionRect *rect in rects) {
        XCTAssertFalse(CGRectIsNull(rect.rect), @"%@", NSStringFromCGRect(rect.rect));
        XCTAssertTrue(isfinite(CGRectGetMinX(rect.rect)) && isfinite(CGRectGetMinY(rect.rect)),
                      @"a rect at infinity draws nowhere: %@", NSStringFromCGRect(rect.rect));
        area += CGRectGetWidth(rect.rect) * CGRectGetHeight(rect.rect);
    }
    XCTAssertGreaterThan(area, 0.0);

    // The selection through the empty line into the next paragraph keeps working, and now covers
    // three lines rather than two.
    UITextRange *whole = [view textRangeFromPosition:view.beginningOfDocument
                                          toPosition:view.endOfDocument];
    NSMutableSet<NSNumber *> *lineTops = [NSMutableSet set];
    for (UITextSelectionRect *rect in [view selectionRectsForRange:whole]) {
        [lineTops addObject:@(round(CGRectGetMinY(rect.rect)))];
    }
    XCTAssertEqual(lineTops.count, 3U, @"one highlight per line, empty line included");
}

@end
