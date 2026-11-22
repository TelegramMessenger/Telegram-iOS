@import XCTest;
@import UniformTypeIdentifiers;

#include <math.h>

#import <objc/message.h>
#import <objc/runtime.h>

#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockStackCanvasViewInternal.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDPrivateUIKit.h"
#import "IDUIKitInputControllerCapability.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextPosition.h"
#import "IDRichTextRange.h"
#import "IDTextLayoutCanvasView.h"

@interface IDBoundedDocumentLayoutSnapshotSource : NSObject
    <IDDocumentLayoutSnapshotSource>
@property(nonatomic, strong) IDBlockStackCanvasView *stack;
@property(nonatomic, copy) NSSet<NSUUID *> *availableIdentifiers;
@property(nonatomic, strong)
    NSMutableArray<NSUUID *> *snapshotRequestIdentifiers;
- (instancetype)initWithStack:(IDBlockStackCanvasView *)stack
          availableIdentifiers:(NSArray<NSUUID *> *)availableIdentifiers;
@end

@implementation IDBoundedDocumentLayoutSnapshotSource

- (instancetype)initWithStack:(IDBlockStackCanvasView *)stack
          availableIdentifiers:(NSArray<NSUUID *> *)availableIdentifiers {
    self = [super init];
    if (self != nil) {
        _stack = stack;
        _availableIdentifiers = [NSSet setWithArray:availableIdentifiers];
        _snapshotRequestIdentifiers = [NSMutableArray array];
    }
    return self;
}

- (NSArray<NSUUID *> *)orderedBlockIdentifiers {
    NSMutableArray<NSUUID *> *identifiers = [NSMutableArray array];
    for (NSUUID *identifier in [self.stack orderedBlockIdentifiers]) {
        if ([self.availableIdentifiers containsObject:identifier]) {
            [identifiers addObject:identifier];
        }
    }
    return identifiers.copy;
}

- (IDDocumentGeometryEligibilitySnapshot *)
    selectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision {
    (void)documentRevision;
    IDDocumentGeometryEligibilitySnapshot *stackEligibility = [self.stack
        selectionGeometryEligibilityForDocumentRevision:
            self.stack.id_document.documentRevision];
    return [[IDDocumentGeometryEligibilitySnapshot alloc]
        initWithGeometryGeneration:stackEligibility.geometryGeneration
              orderedBlockIdentifiers:self.orderedBlockIdentifiers];
}

- (id<IDBlockLayoutSnapshot>)snapshotForBlockIdentifier:(NSUUID *)identifier
                                       documentRevision:(NSUInteger)documentRevision {
    [self.snapshotRequestIdentifiers addObject:identifier];
    if (![self.availableIdentifiers containsObject:identifier]) {
        return nil;
    }
    return [self.stack snapshotForBlockIdentifier:identifier
                                 documentRevision:documentRevision];
}

- (CGPoint)documentOriginForBlockIdentifier:(NSUUID *)identifier {
    return [self.stack documentOriginForBlockIdentifier:identifier];
}

- (NSUUID *)nearestBlockIdentifierForDocumentPoint:(CGPoint)point {
    return [self.stack nearestBlockIdentifierForDocumentPoint:point];
}

@end

@interface IDBlockTextViewTests : XCTestCase
@end

static BOOL IDTestClassDeclaresInstanceSelector(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index++) {
        if (method_getName(methods[index]) == selector) {
            found = YES;
            break;
        }
    }
    free(methods);
    return found;
}

static BOOL IDTestInvokeUIKitForwardDeleteManager(void) {
    Class keyboardClass = NSClassFromString(@"UIKeyboardImpl");
    SEL activeSelector = NSSelectorFromString(
        [@"active" stringByAppendingString:@"Instance"]);
    id keyboard = keyboardClass == Nil ? nil :
        ((id (*)(id, SEL))objc_msgSend)(keyboardClass, activeSelector);
    SEL deleteSelector = NSSelectorFromString(
        [@"deleteForwardAndNotify:" stringByAppendingString:
            @"producedByDeleteInput:"]);
    Method method = keyboard == nil ? NULL :
        class_getInstanceMethod([keyboard class], deleteSelector);
    if (method == NULL) return NO;
    return ((BOOL (*)(id, SEL, BOOL, BOOL))objc_msgSend)(
        keyboard, deleteSelector, YES, YES);
}

@interface IDOrderingBlockTextView : IDBlockTextView
@property(nonatomic) NSMutableArray<NSString *> *callbackEvents;
@end

@interface IDDeleteOrderingStockTextView : UITextView
@property(nonatomic) NSMutableArray<NSString *> *callbackEvents;
@end

@interface UITextView (IDDeleteNotificationTesting)
- (void)textInputDidChange:(id)input;
- (void)textInputDidChangeSelection:(id)input;
- (void)_deleteBackwardAndNotify:(BOOL)notify;
- (void)_expandSelectionToBackwardDeletionClusterWithReinsertionOut:(NSString **)reinsertion;
@end

@implementation IDOrderingBlockTextView

- (NSMutableArray<NSString *> *)callbackEvents {
    if (_callbackEvents == nil) {
        _callbackEvents = [NSMutableArray array];
    }
    return _callbackEvents;
}

- (void)id_selectionStateDidChange {
    [self.callbackEvents addObject:@"selection"];
    [super id_selectionStateDidChange];
}

- (void)id_reconcileDerivedState {
    [self.callbackEvents addObject:@"text"];
    [super id_reconcileDerivedState];
}

@end

@implementation IDDeleteOrderingStockTextView

- (NSMutableArray<NSString *> *)callbackEvents {
    if (_callbackEvents == nil) {
        _callbackEvents = [NSMutableArray array];
    }
    return _callbackEvents;
}

- (void)textInputDidChange:(id)input {
    [self.callbackEvents addObject:@"text"];
    [super textInputDidChange:input];
}

- (void)textInputDidChangeSelection:(id)input {
    [self.callbackEvents addObject:@"selection"];
    [super textInputDidChangeSelection:input];
}

@end

@interface IDBlockTextView (IDPostRefreshOrderingTesting)
- (void)textInputDidChange:(id)input;
- (void)textInputDidChangeSelection:(id)input;
- (BOOL)keyboardInput:(id)input
    shouldReplaceTextInRange:(NSRange)range
             replacementText:(NSString *)text;
- (BOOL)isContinuousSpellCheckingEnabled;
- (void)setAttributedMarkedText:(NSAttributedString *)text
                  selectedRange:(NSRange)range;
- (void)_deleteBackwardAndNotify:(BOOL)notify;
- (void)_expandSelectionToBackwardDeletionClusterWithReinsertionOut:(NSString **)reinsertion;
@end

@interface NSTextLayoutManager (IDPostRefreshTemporaryReplayTesting)
- (void)addTemporaryAttribute:(id)attribute
                        value:(id)value
                 forTextRange:(NSTextRange *)range;
@end

@interface IDPostRefreshTemporaryReplayLayoutManager : NSTextLayoutManager
@property(nonatomic, readonly) NSUInteger id_postRefreshTemporaryAddCount;
@end

@implementation IDPostRefreshTemporaryReplayLayoutManager

- (void)addTemporaryAttribute:(id)attribute
                        value:(id)value
                 forTextRange:(NSTextRange *)range {
    NSNumber *count = objc_getAssociatedObject(
        self,
        @selector(id_postRefreshTemporaryAddCount));
    objc_setAssociatedObject(self,
                             @selector(id_postRefreshTemporaryAddCount),
                             @(count.unsignedIntegerValue + 1),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [super addTemporaryAttribute:attribute value:value forTextRange:range];
}

- (NSUInteger)id_postRefreshTemporaryAddCount {
    return [objc_getAssociatedObject(self, _cmd) unsignedIntegerValue];
}

@end

@interface IDPostRefreshOrderingBlockTextView : IDBlockTextView
@property(nonatomic) NSMutableArray<NSString *> *orderingEvents;
@property(nonatomic) NSMutableArray<NSDictionary<NSString *, id> *> *scrollAttempts;
@property(nonatomic) NSMutableArray<NSDictionary<NSString *, id> *> *interactionAttempts;
@property(nonatomic) NSUInteger externalTextChangeCount;
@property(nonatomic) NSUInteger externalSelectionChangeCount;
@end

@implementation IDPostRefreshOrderingBlockTextView

- (void)id_reconcileDerivedState {
    [super id_reconcileDerivedState];
    for (IDBlockLayout *layout in self.id_blockStack.blockLayouts) {
        if (![layout.layoutManager isKindOfClass:
                IDPostRefreshTemporaryReplayLayoutManager.class]) {
            object_setClass(layout.layoutManager,
                            IDPostRefreshTemporaryReplayLayoutManager.class);
        }
    }
}

- (NSMutableArray<NSString *> *)orderingEvents {
    if (_orderingEvents == nil) {
        _orderingEvents = [NSMutableArray array];
    }
    return _orderingEvents;
}

- (NSMutableArray<NSDictionary<NSString *,id> *> *)scrollAttempts {
    if (_scrollAttempts == nil) {
        _scrollAttempts = [NSMutableArray array];
    }
    return _scrollAttempts;
}

- (NSMutableArray<NSDictionary<NSString *,id> *> *)interactionAttempts {
    if (_interactionAttempts == nil) {
        _interactionAttempts = [NSMutableArray array];
    }
    return _interactionAttempts;
}

- (NSDictionary<NSString *, id> *)id_geometrySnapshot {
    IDBlockLayout *layout = self.id_blockStack.blockLayouts.firstObject;
    NSString *derivedString = layout.contentStorage.textStorage.string ?: @"";
    NSString *canonicalString = self.id_textStorageAdapter.string ?: @"";
    UITextRange *selection = self.selectedTextRange;
    NSInteger selectionOffset = selection == nil
        ? NSNotFound
        : [self offsetFromPosition:self.beginningOfDocument toPosition:selection.end];
    CGFloat verticalInset = self.textContainerInset.top + self.textContainerInset.bottom;
    CGFloat expectedContentHeight = ceil(MAX(CGRectGetHeight(self.bounds),
                                             self.id_blockStack.documentContentSize.height +
                                                 verticalInset));
    BOOL canonicalEqualsDerived = [canonicalString isEqualToString:derivedString];
    BOOL selectionFitsDerived = selectionOffset >= 0 &&
        (NSUInteger)selectionOffset <= derivedString.length;
    BOOL contentSizeIsFresh =
        fabs(self.contentSize.height - expectedContentHeight) <= 0.5;
    return @{
        @"canonicalEqualsDerived": @(canonicalEqualsDerived),
        @"selectionOffset": @(selectionOffset),
        @"derivedLength": @(derivedString.length),
        @"documentHeight": @(self.id_blockStack.documentContentSize.height),
        @"contentSizeIsFresh": @(contentSizeIsFresh),
        @"geometryIsFinal": @(canonicalEqualsDerived && selectionFitsDerived &&
                               contentSizeIsFresh),
        @"temporaryAddCount": @(
            ((IDPostRefreshTemporaryReplayLayoutManager *)layout.layoutManager)
                .id_postRefreshTemporaryAddCount),
    };
}

- (void)textInputDidChange:(id)input {
    self.externalTextChangeCount += 1;
    [self.orderingEvents addObject:@"external-text"];
    [super textInputDidChange:input];
}

- (void)textInputDidChangeSelection:(id)input {
    self.externalSelectionChangeCount += 1;
    [self.orderingEvents addObject:@"external-selection"];
    [super textInputDidChangeSelection:input];
}

- (void)id_scrollCaretToVisibleIfNeeded {
    [self.orderingEvents addObject:@"scroll"];
    [self.scrollAttempts addObject:[self id_geometrySnapshot]];
    [super id_scrollCaretToVisibleIfNeeded];
}

- (void)id_updateInteractionGeometry {
    [self.orderingEvents addObject:@"interaction"];
    [self.interactionAttempts addObject:[self id_geometrySnapshot]];
    [super id_updateInteractionGeometry];
}

@end

@implementation IDBlockTextViewTests

- (NSArray<NSAttributedString *> *)blocks:(NSArray<NSString *> *)strings {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    UIColor *color = UIColor.labelColor;
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc]
            initWithString:string
                attributes:@{NSFontAttributeName: font,
                             NSForegroundColorAttributeName: color}]];
    }
    return blocks.copy;
}

- (IDBlockTextView *)viewWithStrings:(NSArray<NSString *> *)strings {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:[self blocks:strings]];
    [view layoutIfNeeded];
    return view;
}

- (void)setSelection:(NSRange)range inView:(IDBlockTextView *)view {
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument
                                                offset:(NSInteger)range.location];
    UITextPosition *end = [view positionFromPosition:start
                                               offset:(NSInteger)range.length];
    XCTAssertNotNil(start);
    XCTAssertNotNil(end);
    view.selectedTextRange = [view textRangeFromPosition:start toPosition:end];
}

- (NSRange)selectionInView:(IDBlockTextView *)view {
    UITextRange *selection = view.selectedTextRange;
    XCTAssertNotNil(selection);
    NSInteger location = [view offsetFromPosition:view.beginningOfDocument
                                        toPosition:selection.start];
    NSInteger length = [view offsetFromPosition:selection.start
                                      toPosition:selection.end];
    XCTAssertGreaterThanOrEqual(location, 0);
    XCTAssertGreaterThanOrEqual(length, 0);
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (void)testBlockActionAvailabilityMatchesStockAcrossEditableSelectionStates {
    [self addTeardownBlock:^{
        UIPasteboard.generalPasteboard.items = @[];
    }];
    UIPasteboard.generalPasteboard.items = @[
        @{UTTypePlainText.identifier: @"paste"},
    ];

    NSString *text = @"alpha beta gamma";
    UITextView *stock = [[UITextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 160)];
    stock.text = text;
    IDBlockTextView *custom = [self viewWithStrings:@[text]];
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
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    [controller.view addSubview:stock];
    [controller.view addSubview:custom];
    [window makeKeyAndVisible];
    [self addTeardownBlock:^{
        [stock removeFromSuperview];
        [custom removeFromSuperview];
        window.hidden = YES;
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
    }];
    NSArray<NSDictionary<NSString *, id> *> *states = @[
        @{@"editable": @YES, @"selectable": @YES,
          @"selection": [NSValue valueWithRange:NSMakeRange(0, 0)]},
        @{@"editable": @YES, @"selectable": @YES,
          @"selection": [NSValue valueWithRange:NSMakeRange(0, 5)]},
        @{@"editable": @NO, @"selectable": @YES,
          @"selection": [NSValue valueWithRange:NSMakeRange(0, 0)]},
        @{@"editable": @NO, @"selectable": @YES,
          @"selection": [NSValue valueWithRange:NSMakeRange(0, 5)]},
        @{@"editable": @NO, @"selectable": @NO,
          @"selection": [NSValue valueWithRange:NSMakeRange(0, 0)]},
    ];
    NSArray<NSString *> *actionNames = @[
        @"copy:", @"cut:", @"paste:", @"select:", @"selectAll:",
    ];

    for (NSDictionary<NSString *, id> *state in states) {
        BOOL selectable = [state[@"selectable"] boolValue];
        BOOL editable = [state[@"editable"] boolValue];
        NSRange selection = [state[@"selection"] rangeValue];
        stock.selectable = selectable;
        custom.selectable = selectable;
        stock.editable = editable;
        custom.editable = editable;
        stock.selectedRange = selection;
        [self setSelection:selection inView:custom];

        XCTAssertTrue(NSEqualRanges([self selectionInView:custom],
                                    stock.selectedRange), @"%@", state);
        NSMutableDictionary<NSString *, NSNumber *> *stockActions =
            [NSMutableDictionary dictionary];
        if (stock.canBecomeFirstResponder) {
            XCTAssertTrue([stock becomeFirstResponder], @"%@", state);
        }
        for (NSString *actionName in actionNames) {
            SEL action = NSSelectorFromString(actionName);
            stockActions[actionName] = @([stock canPerformAction:action
                                                         withSender:nil]);
        }
        if (custom.canBecomeFirstResponder) {
            XCTAssertTrue([custom becomeFirstResponder], @"%@", state);
        }
        for (NSString *actionName in actionNames) {
            SEL action = NSSelectorFromString(actionName);
            XCTAssertEqual([custom canPerformAction:action withSender:nil],
                           stockActions[actionName].boolValue,
                           @"state=%@ action=%@", state, actionName);
        }
    }
}

- (void)testProgrammaticSelectAllMatchesStockWithoutFirstResponder {
    NSString *text = @"alpha beta gamma";
    UITextView *stock = [[UITextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 160)];
    stock.text = text;
    stock.selectedRange = NSMakeRange(0, 0);
    IDBlockTextView *custom = [self viewWithStrings:@[text]];
    [self setSelection:NSMakeRange(0, 0) inView:custom];

    XCTAssertFalse(stock.isFirstResponder);
    XCTAssertFalse(custom.isFirstResponder);
    XCTAssertEqual([custom canPerformAction:@selector(selectAll:) withSender:nil],
                   [stock canPerformAction:@selector(selectAll:) withSender:nil]);
    [stock selectAll:nil];
    [custom selectAll:nil];

    XCTAssertTrue(NSEqualRanges(stock.selectedRange,
                                NSMakeRange(0, text.length)));
    XCTAssertTrue(NSEqualRanges([self selectionInView:custom],
                                stock.selectedRange));
}

- (NSRange)markedRangeInView:(IDBlockTextView *)view {
    UITextRange *marked = view.markedTextRange;
    if (marked == nil) {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger location = [view offsetFromPosition:view.beginningOfDocument
                                        toPosition:marked.start];
    NSInteger length = [view offsetFromPosition:marked.start toPosition:marked.end];
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (NSArray<NSUUID *> *)identifiersInView:(IDBlockTextView *)view {
    return [view.id_document.blocks valueForKey:@"identifier"];
}

- (NSArray<IDBlockLayout *> *)layoutsInView:(IDBlockTextView *)view {
    return view.id_blockStack.blockLayouts;
}

- (void)assertView:(IDBlockTextView *)view
              text:(NSString *)text
      blockStrings:(NSArray<NSString *> *)blockStrings {
    [view setNeedsLayout];
    [view layoutIfNeeded];
    XCTAssertEqualObjects(view.text, text);
    XCTAssertEqualObjects(view.id_textStorageAdapter.string, text);
    XCTAssertEqualObjects(view.id_richLayoutController.textStorageAdapter,
                          view.id_textStorageAdapter);
    XCTAssertEqual(view.id_richLayoutController.document, view.id_document);
    XCTAssertEqual(view.id_document.canonicalLength, text.length);
    XCTAssertEqual(view.attributedBlocks.count, blockStrings.count);
    XCTAssertEqual(view.id_document.blocks.count, blockStrings.count);
    XCTAssertEqual(view.id_blockStack.blockLayouts.count, blockStrings.count);

    for (NSUInteger index = 0; index < blockStrings.count; index += 1) {
        IDBlock *block = view.id_document.blocks[index];
        IDBlockLayout *layout = view.id_blockStack.blockLayouts[index];
        XCTAssertEqualObjects(view.attributedBlocks[index].string, blockStrings[index]);
        XCTAssertEqualObjects(block.attributedText.string, blockStrings[index]);
        XCTAssertEqualObjects(layout.contentStorage.textStorage.string, blockStrings[index]);
        XCTAssertEqualObjects(layout.blockIdentifier, block.identifier);
        XCTAssertEqual([view.id_blockStack layoutForBlockIdentifier:block.identifier], layout);
        XCTAssertEqual(layout.canvasView.superview, view.id_blockStack);
    }

    XCTAssertEqual(view.id_blockStack.superview, view);
    // The stack sits at the ORIGIN and carries `textContainerInset` internally rather than being
    // positioned at it — load-bearing, because the stack is `-textInputView` and UIKit interprets
    // every geometry answer relative to it.
    XCTAssertEqualWithAccuracy(view.id_blockStack.frame.origin.x, 0.0, 0.5);
    XCTAssertEqualWithAccuracy(view.id_blockStack.frame.origin.y, 0.0, 0.5);
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(view.id_blockStack.contentInsets,
                                                view.textContainerInset));
    // …and the inset is still APPLIED, or the above would pass for a view that ignores it.
    if (view.id_blockStack.blockLayouts.count > 0) {
        CGRect firstCanvas = view.id_blockStack.blockLayouts.firstObject.canvasView.frame;
        XCTAssertEqualWithAccuracy(CGRectGetMinX(firstCanvas), view.textContainerInset.left, 0.5);
        XCTAssertEqualWithAccuracy(CGRectGetMinY(firstCanvas), view.textContainerInset.top, 0.5);
    }
    XCTAssertEqualWithAccuracy(view.contentSize.width, CGRectGetWidth(view.bounds), 0.5);
    XCTAssertGreaterThanOrEqual(view.contentSize.height, CGRectGetHeight(view.bounds));
    XCTAssertFalse([view isKindOfClass:UITextView.class]);
    for (UIView *subview in view.subviews) {
        XCTAssertFalse([subview isKindOfClass:UITextView.class]);
    }
}

- (void)testConstructionExposesCanonicalAndDerivedGraphWithoutNativeTextView {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];

    XCTAssertTrue([IDBlockTextView conformsToProtocol:@protocol(UITextInput)]);
    XCTAssertEqualObjects(view.text, @"alpha\nbeta");
    XCTAssertEqual(view.id_textStorageAdapter.document, view.id_document);
    XCTAssertEqual(view.id_blockStack.id_document, view.id_document);
    XCTAssertEqual(view.id_richLayoutController.id_blockStack, view.id_blockStack);
    XCTAssertNotNil(view.id_inputController);
    XCTAssertEqual(view.id_richLayoutController.inputController, view.id_inputController);
    XCTAssertNotNil(view.id_behaviorInput);
    XCTAssertIdentical(view.id_behaviorInput.privateController,
                       view.id_inputController);
    XCTAssertIdentical(
        [view performSelector:NSSelectorFromString(@"_inputController")],
        view.id_inputController);
    XCTAssertNotNil(view.undoManager);
    [self assertView:view text:@"alpha\nbeta" blockStrings:@[@"alpha", @"beta"]];
}

- (void)testCharacterClusterCallbackMatchesIOS265ComposedRangeContract {
    IDBlockTextView *view = [self viewWithStrings:@[@"A👩🏽‍💻", @"B"]];
    IDRichTextLayoutController *controller = view.id_richLayoutController;
    for (NSNumber *type in @[@1, @2, @3, @4]) {
        XCTAssertTrue(NSEqualRanges(
            [controller id_rangeOfCharacterClusterAtIndex:0 type:type.integerValue],
            NSMakeRange(0, 1)));
        XCTAssertTrue(NSEqualRanges(
            [controller id_rangeOfCharacterClusterAtIndex:4 type:type.integerValue],
            NSMakeRange(1, 7)));
        XCTAssertTrue(NSEqualRanges(
            [controller id_rangeOfCharacterClusterAtIndex:8 type:type.integerValue],
            NSMakeRange(8, 1)));
        XCTAssertTrue(NSEqualRanges(
            [controller id_rangeOfCharacterClusterAtIndex:10 type:type.integerValue],
            NSMakeRange(10, 0)));
        XCTAssertTrue(NSEqualRanges(
            [controller id_rangeOfCharacterClusterAtIndex:11 type:type.integerValue],
            NSMakeRange(9, 1)));
    }
    XCTAssertThrowsSpecificNamed(
        [controller id_rangeOfCharacterClusterAtIndex:0 type:0],
        NSException,
        NSInternalInconsistencyException);
    IDBlockTextView *emptyView = [self viewWithStrings:@[@""]];
    XCTAssertTrue(NSEqualRanges(
        [emptyView.id_richLayoutController id_rangeOfCharacterClusterAtIndex:0 type:4],
        NSMakeRange(0, 0)));
}

- (void)testTask8GeometryHonorsContainerPredicateAndReturnsSynchronousResults {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = view.id_richLayoutController;
    UITextRange *range = [controller rangeForCanonicalRange:NSMakeRange(2, 2)];
    NSMutableArray *containers = [NSMutableArray array];
    NSArray *rects = [controller id_selectionRectsForRange:range
                                                  fromView:view
                                   forContainerPassingTest:^BOOL(id container) {
        [containers addObject:container];
        return YES;
    }];
    XCTAssertGreaterThan(rects.count, 0U);
    XCTAssertEqualObjects(containers, (@[controller.id_interactionTextContainer]));

    __block BOOL called = NO;
    __block CGRect rect = CGRectNull;
    __block CGFloat baseline = -1.0;
    __block NSTextContainer *container = nil;
    __block UITextPosition *reported = nil;
    [controller id_requestTextGeometryAtPosition:range.start
                                typingAttributes:@{}
                                     resultBlock:^(NSTextContainer *resultContainer,
                                                   CGRect result,
                                                   CGFloat resultBaseline,
                                                   UITextPosition *resultPosition) {
        called = YES;
        rect = result;
        baseline = resultBaseline;
        container = resultContainer;
        reported = resultPosition;
    }];
    XCTAssertTrue(called);
    XCTAssertTrue(isfinite(rect.origin.x));
    XCTAssertTrue(isfinite(rect.origin.y));
    XCTAssertTrue(isfinite(rect.size.width));
    XCTAssertTrue(isfinite(rect.size.height));
    XCTAssertGreaterThan(rect.size.width, 0.0);
    XCTAssertGreaterThan(rect.size.height, 0.0);
    // UIKit stamps this baseline on every selection rect for the range ending here, and an
    // accepted autocorrection's underline is placed at it; the block has four arguments.
    XCTAssertEqual(container, controller.id_interactionTextContainer);
    XCTAssertEqual([view offsetFromPosition:view.beginningOfDocument toPosition:reported], 2);
    XCTAssertTrue(isfinite(baseline), @"%g", baseline);
    XCTAssertGreaterThan(baseline, 0.0);
    XCTAssertLessThan(baseline, rect.size.height);
    XCTAssertEqualWithAccuracy(baseline, [UIFont systemFontOfSize:17.0].ascender, 1.0);

    UITextRange *secondBlockCaret =
        [controller rangeForCanonicalRange:NSMakeRange(6, 0)];
    [containers removeAllObjects];
    [controller id_selectionRectsForRange:secondBlockCaret
                                 fromView:view
                  forContainerPassingTest:^BOOL(id container) {
        [containers addObject:container];
        return YES;
    }];
    XCTAssertEqualObjects(containers, (@[controller.id_interactionTextContainer]));
}

- (void)testTask7AnnotationPlaceholderReturnsNilForOracleAlternativesKey {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = view.id_richLayoutController;
    UITextPosition *position = [controller positionForCanonicalOffset:0
                                                              affinity:UITextStorageDirectionForward];

    XCTAssertNil([controller id_annotationAttribute:@"NSTextAlternativesDisplayStyle"
                                         atPosition:position]);
}

- (void)testCompleteInputTraitsUseUIKitDefaultsAndRoundTrip {
    IDBlockTextView *view = [self viewWithStrings:@[@""]];

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

    UITextInputPasswordRules *rules =
        [UITextInputPasswordRules passwordRulesWithDescriptor:@"required: upper;"];
    UIConversationContext *context = [UIConversationContext new];
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
    view.passwordRules = rules;
    view.writingToolsBehavior = UIWritingToolsBehaviorLimited;
    view.allowedWritingToolsResultOptions = UIWritingToolsResultPlainText;
    view.conversationContext = context;
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
    XCTAssertEqualObjects(view.passwordRules, rules);
    XCTAssertEqual(view.writingToolsBehavior, UIWritingToolsBehaviorLimited);
    XCTAssertEqual(view.allowedWritingToolsResultOptions, UIWritingToolsResultPlainText);
    XCTAssertEqual(view.conversationContext, context);
    XCTAssertFalse(view.allowsNumberPadPopover);
}

- (void)testUIKitTextInputTraitsObjectIsControllerOwnedAndSynchronized {
    IDBlockTextView *view = [self viewWithStrings:@[@""]];
    SEL internalTraitsSelector = NSSelectorFromString(@"_textInputTraits");
    SEL publicTraitsSelector = NSSelectorFromString(@"textInputTraits");

    XCTAssertTrue([view respondsToSelector:internalTraitsSelector]);
    XCTAssertTrue([view respondsToSelector:publicTraitsSelector]);
    if (![view respondsToSelector:internalTraitsSelector] ||
        ![view respondsToSelector:publicTraitsSelector]) {
        return;
    }

    id controllerTraits =
        IDPrivateObject0(view.id_inputController, internalTraitsSelector);
    XCTAssertNotNil(controllerTraits);
    XCTAssertEqual(IDPrivateObject0(view, internalTraitsSelector), controllerTraits);
    XCTAssertEqual(IDPrivateObject0(view, publicTraitsSelector), controllerTraits);

    view.autocorrectionType = UITextAutocorrectionTypeYes;
    view.keyboardType = UIKeyboardTypeEmailAddress;
    view.textContentType = UITextContentTypeEmailAddress;
    XCTAssertEqual(
        ((NSInteger (*)(id, SEL))[controllerTraits methodForSelector:
            @selector(autocorrectionType)])(
                controllerTraits, @selector(autocorrectionType)),
        UITextAutocorrectionTypeYes);
    XCTAssertEqual(
        ((NSInteger (*)(id, SEL))[controllerTraits methodForSelector:
            @selector(keyboardType)])(
                controllerTraits, @selector(keyboardType)),
        UIKeyboardTypeEmailAddress);
    XCTAssertEqualObjects(
        IDPrivateObject0(controllerTraits, @selector(textContentType)),
        UITextContentTypeEmailAddress);
    XCTAssertEqualObjects([controllerTraits valueForKey:@"autocapitalizationType"],
                          @(UITextAutocapitalizationTypeSentences));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"spellCheckingType"],
                          @(UITextSpellCheckingTypeDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"smartQuotesType"],
                          @(UITextSmartQuotesTypeDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"smartDashesType"],
                          @(UITextSmartDashesTypeDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"smartInsertDeleteType"],
                          @(UITextSmartInsertDeleteTypeDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"inlinePredictionType"],
                          @(UITextInlinePredictionTypeDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"mathExpressionCompletionType"],
                          @(UITextMathExpressionCompletionTypeDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"keyboardAppearance"],
                          @(UIKeyboardAppearanceDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"returnKeyType"],
                          @(UIReturnKeyDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"enablesReturnKeyAutomatically"],
                          @NO);
    XCTAssertEqualObjects([controllerTraits valueForKey:@"secureTextEntry"], @NO);
    XCTAssertNil([controllerTraits valueForKey:@"passwordRules"]);
    XCTAssertEqualObjects([controllerTraits valueForKey:@"writingToolsBehavior"],
                          @(UIWritingToolsBehaviorDefault));
    XCTAssertEqualObjects([controllerTraits valueForKey:@"allowedWritingToolsResultOptions"],
                          @(UIWritingToolsResultDefault));
    XCTAssertNil([controllerTraits valueForKey:@"conversationContext"]);
    XCTAssertEqualObjects([controllerTraits valueForKey:@"allowsNumberPadPopover"], @YES);

    SEL privateTraitSelector = NSSelectorFromString(@"learnsCorrections");
    XCTAssertTrue([view respondsToSelector:privateTraitSelector]);
    XCTAssertEqual([view forwardingTargetForSelector:privateTraitSelector],
                   controllerTraits);
    XCTAssertEqualObjects(
        [view methodSignatureForSelector:privateTraitSelector],
        [controllerTraits methodSignatureForSelector:privateTraitSelector]);
}

- (void)testFontColorAndTextSetterUpdateCanonicalDefaultsAndDerivedBlocks {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    UIFont *font = [UIFont systemFontOfSize:23.0 weight:UIFontWeightSemibold];
    UIColor *color = UIColor.systemPurpleColor;

    view.font = font;
    view.textColor = color;
    view.text = @"one\ntwo";

    [self assertView:view text:@"one\ntwo" blockStrings:@[@"one", @"two"]];
    XCTAssertEqualObjects(view.id_document.defaultAttributes[NSFontAttributeName], font);
    XCTAssertEqualObjects(view.id_document.defaultAttributes[NSForegroundColorAttributeName], color);
    for (NSAttributedString *block in view.attributedBlocks) {
        [block enumerateAttributesInRange:NSMakeRange(0, block.length)
                                 options:0
                              usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
            XCTAssertEqualObjects(attributes[NSFontAttributeName], font);
            XCTAssertEqualObjects(attributes[NSForegroundColorAttributeName], color);
        }];
    }
}

- (void)testEmptyBlockExposesConfiguredDefaultsToNativeTypingAndInsertion {
    IDBlockTextView *view = [self viewWithStrings:@[@""]];
    UIFont *font = [UIFont systemFontOfSize:23.0 weight:UIFontWeightSemibold];
    UIColor *color = UIColor.systemPurpleColor;
    view.font = font;
    view.textColor = color;

    NSDictionary<NSAttributedStringKey, id> *typingContext =
        [view.id_richLayoutController
            id_attributesAtPosition:view.beginningOfDocument
                        inDirection:UITextStorageDirectionForward];
    XCTAssertEqualObjects(typingContext[NSFontAttributeName], font);
    XCTAssertEqualObjects(typingContext[NSForegroundColorAttributeName], color);
    NSDictionary<NSAttributedStringKey, id> *controllerTypingAttributes =
        view.id_behaviorInput.typingAttributes;
    XCTAssertEqualObjects(
        controllerTypingAttributes[NSFontAttributeName],
        font);
    XCTAssertEqualObjects(
        controllerTypingAttributes[NSForegroundColorAttributeName],
        color);
    XCTAssertEqualWithAccuracy(
        view.id_blockStack.blockLayouts.firstObject.usedSize.height,
        font.lineHeight,
        0.5);

    [view insertText:@"X"];

    NSDictionary<NSAttributedStringKey, id> *inserted =
        [view.attributedBlocks.firstObject attributesAtIndex:0
                                              effectiveRange:NULL];
    XCTAssertEqualObjects(inserted[NSFontAttributeName], font);
    XCTAssertEqualObjects(inserted[NSForegroundColorAttributeName], color);
}

- (void)testSingularKeyboardReplacementApprovalRemainsAndPluralCallbackIsAbsent {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    SEL singularSelector = @selector(
        keyboardInput:shouldReplaceTextInRange:replacementText:);
    SEL pluralSelector = NSSelectorFromString([
        @"keyboardInput:shouldReplaceTextIn" stringByAppendingString:
        @"Ranges:replacementText:"]);

    XCTAssertNotEqual(class_getInstanceMethod(view.class, singularSelector),
                      NULL);
    XCTAssertEqual(class_getInstanceMethod(view.class, pluralSelector), NULL);
    XCTAssertFalse([view respondsToSelector:pluralSelector]);
    XCTAssertNil([view forwardingTargetForSelector:pluralSelector]);
    XCTAssertFalse(IDTestClassDeclaresInstanceSelector(
        view.class, @selector(forwardInvocation:)));
    XCTAssertFalse(IDTestClassDeclaresInstanceSelector(
        object_getClass(view.class), @selector(resolveInstanceMethod:)));
    XCTAssertThrowsSpecificNamed(
        ((BOOL (*)(id, SEL, id, id, id))objc_msgSend)(
            view, pluralSelector, nil, @[], @"x"),
        NSException, NSInvalidArgumentException);

    XCTAssertTrue([view keyboardInput:nil
             shouldReplaceTextInRange:NSMakeRange(1, 2)
                      replacementText:@"x"]);

    view.editable = NO;
    XCTAssertFalse([view keyboardInput:nil
              shouldReplaceTextInRange:NSMakeRange(1, 2)
                       replacementText:@"x"]);
}

- (void)testUIKitForwardDeleteManagerMatchesStockAndUndo {
    NSString *original =
        @"A quiet  lantern waits.\nSecond block stays unchanged.";
    NSString *deleted =
        @"A quiet lantern waits.\nSecond block stays unchanged.";
    UITextView *stock = [[UITextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 180)];
    stock.text = original;
    stock.selectedRange = NSMakeRange(8, 0);
    IDBlockTextView *custom = [self viewWithStrings:
        [original componentsSeparatedByString:@"\n"]];
    [self setSelection:NSMakeRange(8, 0) inView:custom];

    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class]) {
            scene = (UIWindowScene *)candidate;
            break;
        }
    }
    XCTAssertNotNil(scene);
    UIWindow *priorKeyWindow = scene.keyWindow;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    [controller.view addSubview:stock];
    [controller.view addSubview:custom];
    [window makeKeyAndVisible];
    [self addTeardownBlock:^{
        [stock resignFirstResponder];
        [custom resignFirstResponder];
        [stock removeFromSuperview];
        [custom removeFromSuperview];
        window.hidden = YES;
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
    }];

    XCTAssertTrue([stock becomeFirstResponder]);
    [NSRunLoop.mainRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertTrue(IDTestInvokeUIKitForwardDeleteManager());
    XCTAssertEqualObjects(stock.text, deleted);
    XCTAssertTrue(NSEqualRanges(stock.selectedRange, NSMakeRange(8, 0)));
    [stock.undoManager undo];
    XCTAssertEqualObjects(stock.text, original);
    NSRange stockUndoSelection = stock.selectedRange;
    XCTAssertEqual(stockUndoSelection.length, 1U);
    XCTAssertLessThanOrEqual(stockUndoSelection.location, original.length);
    [stock resignFirstResponder];

    XCTAssertTrue([custom becomeFirstResponder]);
    [NSRunLoop.mainRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertTrue(IDTestInvokeUIKitForwardDeleteManager());
    XCTAssertEqualObjects(custom.text, deleted);
    XCTAssertTrue(NSEqualRanges([self selectionInView:custom],
                                NSMakeRange(8, 0)));
    [custom.undoManager undo];
    XCTAssertEqualObjects(custom.text, original);
    XCTAssertTrue(NSEqualRanges([self selectionInView:custom],
                                stockUndoSelection),
                  @"stock=%@ custom=%@",
                  NSStringFromRange(stockUndoSelection),
                  NSStringFromRange([self selectionInView:custom]));
}

- (void)testExplicitSpellCheckingTraitUpdatesInputControllerCheckingState {
    IDBlockTextView *view = [self viewWithStrings:@[@"mispelled"]];

    view.spellCheckingType = UITextSpellCheckingTypeYes;
    XCTAssertTrue(view.isContinuousSpellCheckingEnabled);

    view.spellCheckingType = UITextSpellCheckingTypeNo;
    XCTAssertFalse(view.isContinuousSpellCheckingEnabled);
}

- (void)testFontAndColorPreserveNondefaultAttributedRuns {
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.firstLineHeadIndent = 19.0;
    NSURL *link = [NSURL URLWithString:@"https://example.com"];
    NSAttributedString *source = [[NSAttributedString alloc]
        initWithString:@"alpha"
            attributes:@{
                NSParagraphStyleAttributeName: paragraph,
                NSLinkAttributeName: link,
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
            }];
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:@[source]];

    view.font = [UIFont boldSystemFontOfSize:21.0];
    view.textColor = UIColor.systemOrangeColor;

    NSDictionary *attributes = [view.attributedBlocks[0] attributesAtIndex:0
                                                             effectiveRange:NULL];
    XCTAssertEqualObjects(attributes[NSParagraphStyleAttributeName], paragraph);
    XCTAssertEqualObjects(attributes[NSLinkAttributeName], link);
    XCTAssertEqualObjects(attributes[NSUnderlineStyleAttributeName],
                          @(NSUnderlineStyleSingle));
    XCTAssertEqualObjects(attributes[NSFontAttributeName], view.font);
    XCTAssertEqualObjects(attributes[NSForegroundColorAttributeName], view.textColor);
}

- (void)testTypingWithinBlockPreservesBlockAndLayoutIdentities {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
    NSArray<IDBlockLayout *> *layouts = [self layoutsInView:view];
    [self setSelection:NSMakeRange(2, 0) inView:view];
    [view insertText:@"X"];

    [self assertView:view text:@"alXpha\nbeta" blockStrings:@[@"alXpha", @"beta"]];
    XCTAssertEqualObjects([self identifiersInView:view], identifiers);
    XCTAssertEqualObjects([self layoutsInView:view], layouts);
    NSRange actual = [self selectionInView:view];
    XCTAssertTrue(NSEqualRanges(actual, NSMakeRange(3, 0)), @"actual %@", NSStringFromRange(actual));
}

- (void)testReturnSplitsBlockAndPreservesUnaffectedLayoutIdentity {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
    NSArray<IDBlockLayout *> *layouts = [self layoutsInView:view];
    [self setSelection:NSMakeRange(2, 0) inView:view];

    [view insertText:@"\n"];

    [self assertView:view text:@"al\npha\nbeta" blockStrings:@[@"al", @"pha", @"beta"]];
    XCTAssertEqualObjects([self identifiersInView:view][0], identifiers[0]);
    XCTAssertEqualObjects([self identifiersInView:view][2], identifiers[1]);
    XCTAssertEqual([self layoutsInView:view][0], layouts[0]);
    XCTAssertEqual([self layoutsInView:view][2], layouts[1]);
    NSRange actual = [self selectionInView:view];
    XCTAssertTrue(NSEqualRanges(actual, NSMakeRange(3, 0)), @"actual %@", NSStringFromRange(actual));
}

- (void)testBackwardDeleteAtBlockStartMergesBlocksIntoLeadingIdentity {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    NSUUID *leadingIdentifier = [self identifiersInView:view][0];
    IDBlockLayout *leadingLayout = [self layoutsInView:view][0];
    [self setSelection:NSMakeRange(6, 0) inView:view];

    [view deleteBackward];

    [self assertView:view text:@"alphabeta" blockStrings:@[@"alphabeta"]];
    XCTAssertEqualObjects([self identifiersInView:view][0], leadingIdentifier);
    XCTAssertEqual([self layoutsInView:view][0], leadingLayout);
    XCTAssertTrue(NSEqualRanges([self selectionInView:view], NSMakeRange(5, 0)));
}

- (void)testReplacementSpanningFirstNewlineCollapsesToLeadingIdentity {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    NSUUID *leadingIdentifier = [self identifiersInView:view][0];
    IDBlockLayout *leadingLayout = [self layoutsInView:view][0];
    [self setSelection:NSMakeRange(3, 4) inView:view];

    [view replaceRange:view.selectedTextRange withText:@"X"];

    [self assertView:view text:@"alpXeta" blockStrings:@[@"alpXeta"]];
    XCTAssertEqualObjects([self identifiersInView:view][0], leadingIdentifier);
    XCTAssertEqual([self layoutsInView:view][0], leadingLayout);
    NSRange actual = [self selectionInView:view];
    XCTAssertTrue(NSEqualRanges(actual, NSMakeRange(4, 0)), @"actual %@", NSStringFromRange(actual));
}

- (void)testMarkedTextInsideBlockTracksSelectionAndUnmarks {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
    [self setSelection:NSMakeRange(2, 0) inView:view];

    [view setMarkedText:@"かな" selectedRange:NSMakeRange(1, 1)];

    [self assertView:view text:@"alかなpha\nbeta" blockStrings:@[@"alかなpha", @"beta"]];
    XCTAssertTrue(NSEqualRanges([self markedRangeInView:view], NSMakeRange(2, 2)));
    NSRange actual = [self selectionInView:view];
    XCTAssertTrue(NSEqualRanges(actual, NSMakeRange(3, 1)), @"actual %@", NSStringFromRange(actual));
    XCTAssertEqualObjects([self identifiersInView:view], identifiers);
    [view unmarkText];
    XCTAssertNil(view.markedTextRange);
    XCTAssertTrue(NSEqualRanges([self selectionInView:view], NSMakeRange(3, 0)));
    [self assertView:view text:@"alかなpha\nbeta" blockStrings:@[@"alかなpha", @"beta"]];
}

- (void)testAttributedMarkedTextUsesPrivateInputControllerPath {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    [self setSelection:NSMakeRange(2, 0) inView:view];

    [view setAttributedMarkedText:
        [[NSAttributedString alloc] initWithString:@" XY"]
                            selectedRange:NSMakeRange(0, 0)];

    [self assertView:view
                text:@"al XYpha\nbeta"
        blockStrings:@[@"al XYpha", @"beta"]];
    XCTAssertTrue(NSEqualRanges(
        [self markedRangeInView:view], NSMakeRange(2, 3)));
    XCTAssertTrue(NSEqualRanges(
        [self selectionInView:view], NSMakeRange(2, 0)));
    [view unmarkText];
    XCTAssertNil(view.markedTextRange);
}

- (void)testMarkedTextImmediatelyAfterNewlineBelongsToFollowingBlockAndUnmarks {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
    [self setSelection:NSMakeRange(6, 0) inView:view];

    [view setMarkedText:@"語" selectedRange:NSMakeRange(1, 0)];

    [self assertView:view text:@"alpha\n語beta" blockStrings:@[@"alpha", @"語beta"]];
    XCTAssertTrue(NSEqualRanges([self markedRangeInView:view], NSMakeRange(6, 1)));
    XCTAssertTrue(NSEqualRanges([self selectionInView:view], NSMakeRange(7, 0)));
    XCTAssertEqualObjects([self identifiersInView:view], identifiers);
    [view unmarkText];
    XCTAssertNil(view.markedTextRange);
    [self assertView:view text:@"alpha\n語beta" blockStrings:@[@"alpha", @"語beta"]];
}

- (void)testBoundaryMarkedUpdatesAndTerminalCommitsPreserveBlockOwnership {
    for (NSNumber *offsetValue in @[@5, @6]) {
        NSUInteger offset = offsetValue.unsignedIntegerValue;
        IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
        NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
        [self setSelection:NSMakeRange(offset, 0) inView:view];

        [view setMarkedText:@"n" selectedRange:NSMakeRange(1, 0)];
        [view setMarkedText:@"ni" selectedRange:NSMakeRange(2, 0)];

        NSArray<NSString *> *expectedBlocks = offset == 5
            ? @[@"alphani", @"beta"] : @[@"alpha", @"nibeta"];
        NSString *expectedText = offset == 5
            ? @"alphani\nbeta" : @"alpha\nnibeta";
        [self assertView:view text:expectedText blockStrings:expectedBlocks];
        XCTAssertTrue(NSEqualRanges(
            [self markedRangeInView:view], NSMakeRange(offset, 2)));
        XCTAssertTrue(NSEqualRanges(
            [self selectionInView:view], NSMakeRange(offset + 2, 0)));
        XCTAssertEqualObjects([self identifiersInView:view], identifiers);

        [view unmarkText];

        XCTAssertNil(view.markedTextRange);
        XCTAssertTrue(NSEqualRanges(
            [self selectionInView:view], NSMakeRange(offset + 2, 0)));
        XCTAssertEqualObjects([self identifiersInView:view], identifiers);
        [self assertView:view text:expectedText blockStrings:expectedBlocks];
    }
}

- (void)testBoundaryMarkedCancellationRestoresCanonicalBlocksAndAnchors {
    for (NSNumber *offsetValue in @[@5, @6]) {
        NSUInteger offset = offsetValue.unsignedIntegerValue;
        IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
        NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
        UITextPosition *startAnchor = [view positionFromPosition:
            view.beginningOfDocument offset:(NSInteger)offset];
        UITextPosition *secondBlockAnchor = [view positionFromPosition:
            view.beginningOfDocument offset:6];
        [self setSelection:NSMakeRange(offset, 0) inView:view];

        [view setMarkedText:@"n" selectedRange:NSMakeRange(1, 0)];
        [view setMarkedText:@"ni" selectedRange:NSMakeRange(2, 0)];
        [view setMarkedText:@"" selectedRange:NSMakeRange(0, 0)];
        [view unmarkText];

        [self assertView:view
                    text:@"alpha\nbeta"
            blockStrings:@[@"alpha", @"beta"]];
        XCTAssertNil(view.markedTextRange);
        XCTAssertTrue(NSEqualRanges(
            [self selectionInView:view], NSMakeRange(offset, 0)));
        XCTAssertEqualObjects([self identifiersInView:view], identifiers);
        XCTAssertEqual(
            [view offsetFromPosition:view.beginningOfDocument
                          toPosition:startAnchor],
            (NSInteger)offset);
        XCTAssertEqual(
            [view offsetFromPosition:view.beginningOfDocument
                          toPosition:secondBlockAnchor],
            6);
    }
}

- (void)testBoundaryCandidateReplacementTerminalChronologyMatchesStock {
    for (NSNumber *offsetValue in @[@5, @6]) {
        NSUInteger offset = offsetValue.unsignedIntegerValue;
        IDOrderingBlockTextView *view = [[IDOrderingBlockTextView alloc]
            initWithFrame:CGRectMake(0, 0, 320, 240)
            attributedBlocks:[self blocks:@[@"alpha", @"beta"]]];
        IDDeleteOrderingStockTextView *stock =
            [[IDDeleteOrderingStockTextView alloc]
                initWithFrame:CGRectMake(0, 0, 320, 240)];
        stock.text = @"alpha\nbeta";
        NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
        [self setSelection:NSMakeRange(offset, 0) inView:view];
        stock.selectedRange = NSMakeRange(offset, 0);
        [view setMarkedText:@"n" selectedRange:NSMakeRange(1, 0)];
        [stock setMarkedText:@"n" selectedRange:NSMakeRange(1, 0)];
        [view setMarkedText:@"ni" selectedRange:NSMakeRange(2, 0)];
        [stock setMarkedText:@"ni" selectedRange:NSMakeRange(2, 0)];
        [view.callbackEvents removeAllObjects];
        [stock.callbackEvents removeAllObjects];

        [view setMarkedText:@"你好" selectedRange:NSMakeRange(2, 0)];
        [stock setMarkedText:@"你好" selectedRange:NSMakeRange(2, 0)];
        [view unmarkText];
        [stock unmarkText];

        NSArray<NSString *> *expectedBlocks = offset == 5
            ? @[@"alpha你好", @"beta"] : @[@"alpha", @"你好beta"];
        NSString *expectedText = offset == 5
            ? @"alpha你好\nbeta" : @"alpha\n你好beta";
        [self assertView:view text:expectedText blockStrings:expectedBlocks];
        XCTAssertNil(view.markedTextRange);
        XCTAssertTrue(NSEqualRanges(
            [self selectionInView:view], NSMakeRange(offset + 2, 0)));
        XCTAssertEqualObjects([self identifiersInView:view], identifiers);
        XCTAssertEqualObjects(view.text, stock.text);
        XCTAssertTrue(NSEqualRanges(
            [self selectionInView:view], stock.selectedRange));
        XCTAssertEqualObjects(view.callbackEvents, stock.callbackEvents);
    }
}

- (void)testBoundaryCompositionCommitUndoRestoresIdentitySelectionAndAnchors {
    for (NSNumber *offsetValue in @[@5, @6]) {
        NSUInteger offset = offsetValue.unsignedIntegerValue;
        IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
        NSArray<NSUUID *> *identifiers = [self identifiersInView:view];
        UITextPosition *compositionAnchor = [view positionFromPosition:
            view.beginningOfDocument offset:(NSInteger)offset];
        UITextPosition *secondBlockAnchor = [view positionFromPosition:
            view.beginningOfDocument offset:6];
        [self setSelection:NSMakeRange(offset, 0) inView:view];

        NSUndoManager *undoManager = view.undoManager;
        [undoManager beginUndoGrouping];
        [view setMarkedText:@"n" selectedRange:NSMakeRange(1, 0)];
        [view setMarkedText:@"ni" selectedRange:NSMakeRange(2, 0)];
        [view unmarkText];
        [undoManager endUndoGrouping];

        XCTAssertNil(view.markedTextRange);
        XCTAssertTrue(undoManager.canUndo);
        [undoManager undo];

        [self assertView:view
                    text:@"alpha\nbeta"
            blockStrings:@[@"alpha", @"beta"]];
        XCTAssertNil(view.markedTextRange);
        XCTAssertTrue(NSEqualRanges(
            [self selectionInView:view], NSMakeRange(offset, 0)));
        XCTAssertEqualObjects([self identifiersInView:view], identifiers);
        XCTAssertEqual(
            [view offsetFromPosition:view.beginningOfDocument
                          toPosition:compositionAnchor],
            (NSInteger)offset);
        XCTAssertEqual(
            [view offsetFromPosition:view.beginningOfDocument
                          toPosition:secondBlockAnchor],
            6);
    }
}

- (void)assertUndoRedoInView:(IDBlockTextView *)view
                 editedText:(NSString *)editedText
               editedBlocks:(NSArray<NSString *> *)editedBlocks
            editedSelection:(NSRange)editedSelection
                originalText:(NSString *)originalText
              originalBlocks:(NSArray<NSString *> *)originalBlocks
           originalSelection:(NSRange)originalSelection
             stableIdentifier:(NSUUID *)stableIdentifier
                 stableLayout:(IDBlockLayout *)stableLayout
          originalContentSize:(CGSize)originalContentSize
       originalDocumentHeight:(CGFloat)originalDocumentHeight
             originalUsedSize:(CGSize)originalUsedSize
           originalCanvasFrame:(CGRect)originalCanvasFrame {
    NSUndoManager *manager = view.undoManager;
    CGSize editedContentSize = view.contentSize;
    CGFloat editedDocumentHeight = view.id_blockStack.documentContentSize.height;
    CGSize editedUsedSize = stableLayout.usedSize;
    CGRect editedCanvasFrame = stableLayout.canvasView.frame;
    IDTextLayoutCanvasView *stableCanvas = stableLayout.canvasView;
    XCTAssertEqualObjects([self identifiersInView:view].firstObject, stableIdentifier);
    XCTAssertEqual([self layoutsInView:view].firstObject, stableLayout);
    XCTAssertNotNil(manager);
    XCTAssertTrue(manager.canUndo);
    [manager undo];
    [self assertView:view text:originalText blockStrings:originalBlocks];
    NSRange actualOriginalSelection = [self selectionInView:view];
    XCTAssertTrue(NSEqualRanges(actualOriginalSelection, originalSelection),
                  @"actual %@ expected %@",
                  NSStringFromRange(actualOriginalSelection),
                  NSStringFromRange(originalSelection));
    XCTAssertEqualObjects([self identifiersInView:view].firstObject, stableIdentifier);
    XCTAssertEqual([self layoutsInView:view].firstObject, stableLayout);
    XCTAssertEqual(stableLayout.canvasView, stableCanvas);
    XCTAssertTrue(CGSizeEqualToSize(view.contentSize, originalContentSize));
    XCTAssertEqualWithAccuracy(view.id_blockStack.documentContentSize.height,
                               originalDocumentHeight,
                               0.5);
    XCTAssertTrue(CGSizeEqualToSize(stableLayout.usedSize, originalUsedSize));
    XCTAssertTrue(CGRectEqualToRect(stableCanvas.frame, originalCanvasFrame));
    XCTAssertTrue(manager.canRedo);
    [manager redo];
    [self assertView:view text:editedText blockStrings:editedBlocks];
    XCTAssertTrue(NSEqualRanges([self selectionInView:view], editedSelection));
    XCTAssertEqualObjects([self identifiersInView:view].firstObject, stableIdentifier);
    XCTAssertEqual([self layoutsInView:view].firstObject, stableLayout);
    XCTAssertEqual(stableLayout.canvasView, stableCanvas);
    XCTAssertTrue(CGSizeEqualToSize(view.contentSize, editedContentSize));
    XCTAssertEqualWithAccuracy(view.id_blockStack.documentContentSize.height,
                               editedDocumentHeight,
                               0.5);
    XCTAssertTrue(CGSizeEqualToSize(stableLayout.usedSize, editedUsedSize));
    XCTAssertTrue(CGRectEqualToRect(stableCanvas.frame, editedCanvasFrame));
}

- (void)testNativeUndoRedoRestoresTypingAndSelection {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    [view layoutIfNeeded];
    NSUUID *stableIdentifier = [self identifiersInView:view].firstObject;
    IDBlockLayout *stableLayout = [self layoutsInView:view].firstObject;
    CGSize originalContentSize = view.contentSize;
    CGFloat originalDocumentHeight = view.id_blockStack.documentContentSize.height;
    CGSize originalUsedSize = stableLayout.usedSize;
    CGRect originalCanvasFrame = stableLayout.canvasView.frame;
    [self setSelection:NSMakeRange(2, 0) inView:view];
    [view insertText:@"X"];
    [self assertUndoRedoInView:view
                   editedText:@"alXpha\nbeta"
                 editedBlocks:@[@"alXpha", @"beta"]
              editedSelection:NSMakeRange(3, 0)
                 originalText:@"alpha\nbeta"
               originalBlocks:@[@"alpha", @"beta"]
            originalSelection:NSMakeRange(2, 0)
              stableIdentifier:stableIdentifier
                  stableLayout:stableLayout
           originalContentSize:originalContentSize
       originalDocumentHeight:originalDocumentHeight
             originalUsedSize:originalUsedSize
           originalCanvasFrame:originalCanvasFrame];
}

- (void)testNativeUndoRedoRestoresSplitAndSelection {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    [view layoutIfNeeded];
    NSUUID *stableIdentifier = [self identifiersInView:view].firstObject;
    IDBlockLayout *stableLayout = [self layoutsInView:view].firstObject;
    CGSize originalContentSize = view.contentSize;
    CGFloat originalDocumentHeight = view.id_blockStack.documentContentSize.height;
    CGSize originalUsedSize = stableLayout.usedSize;
    CGRect originalCanvasFrame = stableLayout.canvasView.frame;
    [self setSelection:NSMakeRange(2, 0) inView:view];
    [view insertText:@"\n"];
    [self assertUndoRedoInView:view
                   editedText:@"al\npha\nbeta"
                 editedBlocks:@[@"al", @"pha", @"beta"]
              editedSelection:NSMakeRange(3, 0)
                 originalText:@"alpha\nbeta"
               originalBlocks:@[@"alpha", @"beta"]
            originalSelection:NSMakeRange(2, 0)
              stableIdentifier:stableIdentifier
                  stableLayout:stableLayout
           originalContentSize:originalContentSize
       originalDocumentHeight:originalDocumentHeight
             originalUsedSize:originalUsedSize
           originalCanvasFrame:originalCanvasFrame];
}

- (void)testNativeUndoRedoRestoresMergeAndSelection {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    [view layoutIfNeeded];
    NSUUID *stableIdentifier = [self identifiersInView:view].firstObject;
    IDBlockLayout *stableLayout = [self layoutsInView:view].firstObject;
    CGSize originalContentSize = view.contentSize;
    CGFloat originalDocumentHeight = view.id_blockStack.documentContentSize.height;
    CGSize originalUsedSize = stableLayout.usedSize;
    CGRect originalCanvasFrame = stableLayout.canvasView.frame;
    [self setSelection:NSMakeRange(6, 0) inView:view];
    [view deleteBackward];
    [self assertUndoRedoInView:view
                   editedText:@"alphabeta"
                 editedBlocks:@[@"alphabeta"]
              editedSelection:NSMakeRange(5, 0)
                 originalText:@"alpha\nbeta"
               originalBlocks:@[@"alpha", @"beta"]
            originalSelection:NSMakeRange(5, 1)
              stableIdentifier:stableIdentifier
                  stableLayout:stableLayout
           originalContentSize:originalContentSize
       originalDocumentHeight:originalDocumentHeight
             originalUsedSize:originalUsedSize
           originalCanvasFrame:originalCanvasFrame];
}

- (void)testNativeUndoRedoRestoresSpanningReplacementAndSelection {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta"]];
    [view layoutIfNeeded];
    NSUUID *stableIdentifier = [self identifiersInView:view].firstObject;
    IDBlockLayout *stableLayout = [self layoutsInView:view].firstObject;
    CGSize originalContentSize = view.contentSize;
    CGFloat originalDocumentHeight = view.id_blockStack.documentContentSize.height;
    CGSize originalUsedSize = stableLayout.usedSize;
    CGRect originalCanvasFrame = stableLayout.canvasView.frame;
    [self setSelection:NSMakeRange(3, 4) inView:view];
    [view replaceRange:view.selectedTextRange withText:@"X"];
    [self assertUndoRedoInView:view
                   editedText:@"alpXeta"
                 editedBlocks:@[@"alpXeta"]
              editedSelection:NSMakeRange(4, 0)
                 originalText:@"alpha\nbeta"
               originalBlocks:@[@"alpha", @"beta"]
            originalSelection:NSMakeRange(3, 4)
              stableIdentifier:stableIdentifier
                  stableLayout:stableLayout
           originalContentSize:originalContentSize
       originalDocumentHeight:originalDocumentHeight
             originalUsedSize:originalUsedSize
           originalCanvasFrame:originalCanvasFrame];
}

- (void)testNativeControllerNotifiesSelectionBeforeDerivedTextRefresh {
    IDOrderingBlockTextView *view = [[IDOrderingBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:[self blocks:@[@"alpha", @"beta"]]];
    [self setSelection:NSMakeRange(2, 0) inView:view];
    [view.callbackEvents removeAllObjects];

    [view insertText:@"X"];

    XCTAssertEqualObjects(view.callbackEvents, (@[@"selection", @"text"]));
}

- (void)testBlockTextViewAdoptsUIKitLegacyKeyboardInputRoutingProtocol {
    Protocol *protocol = NSProtocolFromString(@"UIKeyboardInput");
    XCTAssertNotNil(protocol);
    XCTAssertTrue([UITextView.class conformsToProtocol:protocol]);
    XCTAssertTrue([IDBlockTextView.class conformsToProtocol:protocol]);
}

- (void)testSuppressedBackwardDeleteMatchesUITextViewCallbackChronology {
    IDDeleteOrderingStockTextView *stock = [[IDDeleteOrderingStockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)];
    stock.text = @"alpha";
    stock.selectedRange = NSMakeRange(stock.text.length, 0);
    [stock.callbackEvents removeAllObjects];

    IDOrderingBlockTextView *custom = [[IDOrderingBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:[self blocks:@[@"alpha"]]];
    [self setSelection:NSMakeRange(custom.text.length, 0) inView:custom];
    [custom.callbackEvents removeAllObjects];

    [stock _deleteBackwardAndNotify:NO];
    [custom _deleteBackwardAndNotify:NO];

    XCTAssertEqualObjects(custom.text, stock.text);
    XCTAssertEqualObjects(custom.callbackEvents, stock.callbackEvents);
}

- (void)testBackwardDeletionClusterExpansionMatchesUITextViewSelectionChronology {
    IDDeleteOrderingStockTextView *stock = [[IDDeleteOrderingStockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)];
    stock.text = @"A quiet address  lantern";
    stock.selectedRange = NSMakeRange(16, 0);
    [stock.callbackEvents removeAllObjects];

    IDOrderingBlockTextView *custom = [[IDOrderingBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:[self blocks:@[@"A quiet address  lantern"]]];
    [self setSelection:NSMakeRange(16, 0) inView:custom];
    [custom.callbackEvents removeAllObjects];

    NSString *stockReinsertion = nil;
    NSString *customReinsertion = nil;
    [stock _expandSelectionToBackwardDeletionClusterWithReinsertionOut:&stockReinsertion];
    [custom _expandSelectionToBackwardDeletionClusterWithReinsertionOut:&customReinsertion];

    XCTAssertEqualObjects(customReinsertion, stockReinsertion);
    XCTAssertTrue(NSEqualRanges([self selectionInView:custom], stock.selectedRange));
    XCTAssertEqualObjects(custom.callbackEvents, stock.callbackEvents);
}

- (void)testExpandedBackwardDeleteMatchesUITextViewCallbackChronology {
    IDDeleteOrderingStockTextView *stock = [[IDDeleteOrderingStockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)];
    stock.text = @"A quiet address  lantern";
    stock.selectedRange = NSMakeRange(16, 0);
    [stock.callbackEvents removeAllObjects];

    IDOrderingBlockTextView *custom = [[IDOrderingBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:[self blocks:@[@"A quiet address  lantern"]]];
    [self setSelection:NSMakeRange(16, 0) inView:custom];
    [custom.callbackEvents removeAllObjects];

    [stock _expandSelectionToBackwardDeletionClusterWithReinsertionOut:NULL];
    [custom _expandSelectionToBackwardDeletionClusterWithReinsertionOut:NULL];
    [stock _deleteBackwardAndNotify:YES];
    [custom _deleteBackwardAndNotify:YES];

    XCTAssertEqualObjects(custom.text, stock.text);
    XCTAssertTrue(NSEqualRanges([self selectionInView:custom], stock.selectedRange));
    XCTAssertEqualObjects(custom.callbackEvents, stock.callbackEvents);
}

- (void)testCanonicalEditPublishesCaretAndSelectionGeometryOnlyAfterDerivedRefresh {
    IDPostRefreshOrderingBlockTextView *view =
        [[IDPostRefreshOrderingBlockTextView alloc]
            initWithFrame:CGRectMake(0, 0, 92, 28)
            attributedBlocks:[self blocks:@[@"a"]]];
    [view layoutIfNeeded];
    IDBlockLayout *layout = view.id_blockStack.blockLayouts.firstObject;
    object_setClass(layout.layoutManager,
                    IDPostRefreshTemporaryReplayLayoutManager.class);
    UITextRange *annotatedRange =
        [view textRangeFromPosition:view.beginningOfDocument
                         toPosition:view.endOfDocument];
    [view.id_richLayoutController
        id_addRenderingAttributes:@{@"IDPostRefreshTemporary": @YES}
                         forRange:annotatedRange];
    NSUInteger temporaryAddCount =
        ((IDPostRefreshTemporaryReplayLayoutManager *)layout.layoutManager)
            .id_postRefreshTemporaryAddCount;
    CGFloat initialDocumentHeight = view.id_blockStack.documentContentSize.height;
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view.orderingEvents removeAllObjects];
    [view.scrollAttempts removeAllObjects];
    [view.interactionAttempts removeAllObjects];
    view.externalTextChangeCount = 0;
    view.externalSelectionChangeCount = 0;

    [view insertText:@" zero one two three four five six seven eight nine ten"];

    XCTAssertEqual(view.externalSelectionChangeCount, 1U);
    XCTAssertEqual(view.externalTextChangeCount, 1U);
    NSPredicate *externalEvent = [NSPredicate predicateWithBlock:^BOOL(
        NSString *event,
        __unused NSDictionary *bindings) {
        return [event hasPrefix:@"external-"];
    }];
    XCTAssertEqualObjects([view.orderingEvents filteredArrayUsingPredicate:externalEvent],
                          (@[@"external-selection", @"external-text"]));

    NSPredicate *staleAttempt = [NSPredicate predicateWithBlock:^BOOL(
        NSDictionary<NSString *, id> *attempt,
        __unused NSDictionary *bindings) {
        return ![attempt[@"canonicalEqualsDerived"] boolValue] &&
            [attempt[@"selectionOffset"] integerValue] >
                [attempt[@"derivedLength"] integerValue];
    }];
    NSArray<NSDictionary<NSString *, id> *> *staleAttempts =
        [view.scrollAttempts filteredArrayUsingPredicate:staleAttempt];
    XCTAssertEqual(staleAttempts.count, 0U);
    XCTAssertGreaterThan(view.scrollAttempts.count, 0U);

    NSDictionary<NSString *, id> *finalScroll = view.scrollAttempts.lastObject;
    XCTAssertTrue([finalScroll[@"canonicalEqualsDerived"] boolValue]);
    XCTAssertTrue([finalScroll[@"contentSizeIsFresh"] boolValue]);
    XCTAssertTrue([finalScroll[@"geometryIsFinal"] boolValue]);
    XCTAssertGreaterThan([finalScroll[@"documentHeight"] doubleValue],
                         initialDocumentHeight);

    XCTAssertEqual(view.interactionAttempts.count, 1U);
    NSDictionary<NSString *, id> *selectionRefresh =
        view.interactionAttempts.firstObject;
    XCTAssertTrue([selectionRefresh[@"geometryIsFinal"] boolValue]);
    XCTAssertGreaterThan([selectionRefresh[@"temporaryAddCount"] unsignedIntegerValue],
                         temporaryAddCount);
    NSUInteger interactionIndex = [view.orderingEvents indexOfObject:@"interaction"];
    XCTAssertNotEqual(interactionIndex, NSNotFound);
    XCTAssertGreaterThan(interactionIndex, 0U);
    XCTAssertEqualObjects(view.orderingEvents[interactionIndex - 1], @"scroll");
}

- (void)testNonemptySelectionQueriesOnlyEligibleBlocksAndKeepsOffscreenEndpointsUnclaimed {
    IDBlockTextView *view = [self viewWithStrings:@[
        @"zero", @"one", @"two", @"three", @"four",
    ]];
    NSArray<NSUUID *> *availableIdentifiers = @[
        view.id_document.blocks[1].identifier,
        view.id_document.blocks[2].identifier,
        view.id_document.blocks[3].identifier,
    ];
    IDBoundedDocumentLayoutSnapshotSource *source =
        [[IDBoundedDocumentLayoutSnapshotSource alloc]
            initWithStack:view.id_blockStack
       availableIdentifiers:availableIdentifiers];
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:view.id_document
                                                       source:source];
    SEL eligibilitySelector =
        NSSelectorFromString(@"selectionGeometryEligibilityForDocumentRevision:");
    SEL geometrySelector =
        NSSelectorFromString(@"selectionGeometryForCanonicalRange:");
    XCTAssertTrue([source respondsToSelector:eligibilitySelector],
                  @"bounded sources need an explicit geometry-eligibility contract");
    XCTAssertTrue([coordinator respondsToSelector:geometrySelector],
                  @"the coordinator needs a neutral selection result");
    if (![source respondsToSelector:eligibilitySelector] ||
        ![coordinator respondsToSelector:geometrySelector]) return;

    typedef id (*IDSelectionGeometrySend)(id, SEL, NSRange);
    id geometry = ((IDSelectionGeometrySend)objc_msgSend)(
        coordinator, geometrySelector, NSMakeRange(0, view.text.length));
    XCTAssertNotNil(geometry);
    NSArray *segments = [geometry valueForKey:@"segments"];
    XCTAssertGreaterThan(segments.count, 0U);
    XCTAssertEqualObjects(source.snapshotRequestIdentifiers,
                          availableIdentifiers);
    for (id segment in segments) {
        XCTAssertFalse([[segment valueForKey:@"containsLogicalStart"] boolValue]);
        XCTAssertFalse([[segment valueForKey:@"containsLogicalEnd"] boolValue]);
    }
}

- (void)testBoundedSourceEligibilityDoesNotExpandForSelectAll {
    IDBlockTextView *view = [self viewWithStrings:@[
        @"zero", @"one", @"two", @"three", @"four",
    ]];
    NSArray<NSUUID *> *availableIdentifiers = @[
        view.id_document.blocks[1].identifier,
        view.id_document.blocks[3].identifier,
    ];
    IDBoundedDocumentLayoutSnapshotSource *source =
        [[IDBoundedDocumentLayoutSnapshotSource alloc]
            initWithStack:view.id_blockStack
       availableIdentifiers:availableIdentifiers];

    IDDocumentGeometryEligibilitySnapshot *before = [source
        selectionGeometryEligibilityForDocumentRevision:
            view.id_document.documentRevision];
    [view selectAll:nil];
    IDDocumentGeometryEligibilitySnapshot *after = [source
        selectionGeometryEligibilityForDocumentRevision:
            view.id_document.documentRevision];

    XCTAssertEqualObjects(before.orderedBlockIdentifiers,
                          availableIdentifiers);
    XCTAssertEqualObjects(after.orderedBlockIdentifiers,
                          availableIdentifiers);
    XCTAssertEqual(after.geometryGeneration, before.geometryGeneration);
    XCTAssertTrue(NSEqualRanges(
        [view id_NSRangeForTextRange:view.selectedTextRange],
        NSMakeRange(0, view.text.length)));
}

- (void)testWhollyOffscreenSelectionPublishesExactEmptyGeometry {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha", @"beta", @"gamma"]];
    IDBoundedDocumentLayoutSnapshotSource *source =
        [[IDBoundedDocumentLayoutSnapshotSource alloc]
            initWithStack:view.id_blockStack availableIdentifiers:@[]];
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:view.id_document
                                                       source:source];
    SEL eligibilitySelector =
        NSSelectorFromString(@"selectionGeometryEligibilityForDocumentRevision:");
    SEL geometrySelector =
        NSSelectorFromString(@"selectionGeometryForCanonicalRange:");
    XCTAssertTrue([source respondsToSelector:eligibilitySelector],
                  @"bounded sources need an explicit geometry-eligibility contract");
    XCTAssertTrue([coordinator respondsToSelector:geometrySelector],
                  @"the coordinator needs a neutral selection result");
    if (![source respondsToSelector:eligibilitySelector] ||
        ![coordinator respondsToSelector:geometrySelector]) return;

    typedef id (*IDSelectionGeometrySend)(id, SEL, NSRange);
    id geometry = ((IDSelectionGeometrySend)objc_msgSend)(
        coordinator, geometrySelector, NSMakeRange(0, view.text.length));
    XCTAssertNotNil(geometry, @"valid wholly offscreen geometry is exact, not failure");
    XCTAssertEqual([[geometry valueForKey:@"segments"] count], 0U);
    XCTAssertEqual(source.snapshotRequestIdentifiers.count, 0U);
}

- (void)testSelectAllEditingStillUsesCompleteCanonicalRangeWithBoundedGeometry {
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (NSUInteger index = 0; index < 120; index += 1) {
        [strings addObject:[NSString stringWithFormat:@"block %03lu",
            (unsigned long)index]];
    }
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
      attributedBlocks:[self blocks:strings]];
    NSArray<NSUUID *> *availableIdentifiers = @[
        view.id_document.blocks[50].identifier,
        view.id_document.blocks[60].identifier,
        view.id_document.blocks[70].identifier,
    ];
    IDBoundedDocumentLayoutSnapshotSource *source =
        [[IDBoundedDocumentLayoutSnapshotSource alloc]
            initWithStack:view.id_blockStack
       availableIdentifiers:availableIdentifiers];
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:view.id_document
                                                       source:source];
    [view.id_richLayoutController
        setValue:coordinator forKey:@"id_documentLayoutCoordinator"];

    void (^assertOnlyBoundedGeometryWasQueried)(void) = ^{
        NSArray<NSUUID *> *requests = source.snapshotRequestIdentifiers.copy;
        XCTAssertGreaterThan(requests.count, 0U);
        XCTAssertEqual(requests.count % availableIdentifiers.count, 0U);
        for (NSUInteger index = 0; index < requests.count; index += 1) {
            XCTAssertEqualObjects(requests[index],
                                  availableIdentifiers[index %
                                      availableIdentifiers.count]);
        }
    };

    [view selectAll:nil];

    NSRange range = [view id_NSRangeForTextRange:view.selectedTextRange];
    XCTAssertTrue(NSEqualRanges(range, NSMakeRange(0, view.text.length)));
    assertOnlyBoundedGeometryWasQueried();
    XCTAssertEqualObjects([view textInRange:view.selectedTextRange], view.text);

    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    for (NSAttributedString *block in view.attributedBlocks) {
        if (block.length == 0) continue;
        __block BOOL allBold = YES;
        [block enumerateAttribute:IDInlineTextBoldAttributeName
                          inRange:NSMakeRange(0, block.length)
                          options:0
                       usingBlock:^(id value, NSRange attributeRange, BOOL *stop) {
            (void)attributeRange;
            if (![value boolValue]) {
                allBold = NO;
                *stop = YES;
            }
        }];
        XCTAssertTrue(allBold);
    }
    assertOnlyBoundedGeometryWasQueried();

    [view.undoManager undo];
    [view selectAll:nil];
    [view deleteBackward];

    XCTAssertEqualObjects(view.text, @"");
    assertOnlyBoundedGeometryWasQueried();
}

@end
