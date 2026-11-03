@import XCTest;
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+Testing.h"
#import "IDPrivateUIKit+RichTextLayout.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "IDBlockDocument.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextSelectionRect.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import "IDEngineSourceLayout.h"

@interface IDPrivateUIKitTests : XCTestCase
@end

static NSUInteger IDWrongSuppressedNotificationABICallCount;
static NSUInteger IDInlinePredictionDismissProbeCallCount;
static NSUInteger IDWrongObjectRangeABICallCount;
static NSUInteger IDWrongTextInputTraitsGetterCallCount;
static NSUInteger IDWrongTextInputTraitsSetterCallCount;
static NSUInteger IDVisualSelectionFallbackCandidateCallCount;

@interface IDVisualSelectionFallbackDocument : IDTextView
@end

@implementation IDVisualSelectionFallbackDocument
- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == NSSelectorFromString(
            @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:")) {
        return NO;
    }
    return [super respondsToSelector:selector];
}
- (UITextRange *)_visualSelectionRangeForExtent:(UITextPosition *)extent
                                        forPoint:(CGPoint)point
                                    fromPosition:(UITextPosition *)position
                                     inDirection:(UITextStorageDirection)direction {
    (void)extent; (void)point; (void)position; (void)direction;
    IDVisualSelectionFallbackCandidateCallCount += 1;
    return nil;
}
@end

@interface IDWrongTextInputTraitsGetterABIProbe : NSObject
- (NSInteger)_textInputTraits;
@end

@implementation IDWrongTextInputTraitsGetterABIProbe
- (NSInteger)_textInputTraits {
    IDWrongTextInputTraitsGetterCallCount += 1;
    return 0;
}
@end

@interface IDTextInputTraitsControllerProbe : NSObject
@property(nonatomic, strong) id traits;
- (id)_textInputTraits;
@end

@implementation IDTextInputTraitsControllerProbe
- (id)_textInputTraits {
    return self.traits;
}
@end

static NSInteger IDWrongTextInputTraitsSetter(
    id self,
    SEL selector,
    NSInteger value) {
    (void)self;
    (void)selector;
    (void)value;
    IDWrongTextInputTraitsSetterCallCount += 1;
    return 0;
}

@interface IDWrongObjectRangeABIProbe : NSObject
- (NSInteger)setAttributedMarkedText:(id)value selectedRange:(NSRange)range;
@end

@implementation IDWrongObjectRangeABIProbe
- (NSInteger)setAttributedMarkedText:(id)value selectedRange:(NSRange)range {
    (void)value;
    (void)range;
    IDWrongObjectRangeABICallCount += 1;
    return 0;
}
@end

@interface IDInlinePredictionDismissGoodProbe : NSObject
+ (id)activeInstance;
- (void)removeInlineTextCompletionPrompt;
@end

@implementation IDInlinePredictionDismissGoodProbe
+ (id)activeInstance {
    static IDInlinePredictionDismissGoodProbe *probe;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        probe = [IDInlinePredictionDismissGoodProbe new];
    });
    return probe;
}
- (void)removeInlineTextCompletionPrompt {
    IDInlinePredictionDismissProbeCallCount += 1;
}
@end

@interface IDInlinePredictionDismissMissingProbe : NSObject
+ (id)activeInstance;
@end

@implementation IDInlinePredictionDismissMissingProbe
+ (id)activeInstance {
    return [IDInlinePredictionDismissMissingProbe new];
}
@end

@interface IDInlinePredictionDismissWrongABIProbe : NSObject
+ (id)activeInstance;
- (id)removeInlineTextCompletionPrompt;
@end

@implementation IDInlinePredictionDismissWrongABIProbe
+ (id)activeInstance {
    return [IDInlinePredictionDismissWrongABIProbe new];
}
- (id)removeInlineTextCompletionPrompt {
    IDInlinePredictionDismissProbeCallCount += 1;
    return self;
}
@end

@interface IDWrongSuppressedNotificationABIProbe : NSObject
@end

@implementation IDWrongSuppressedNotificationABIProbe
- (void)_performWhileSuppressingDelegateNotifications:(NSInteger)value {
    (void)value;
    IDWrongSuppressedNotificationABICallCount += 1;
}
@end

static NSUInteger IDThrowingInteractionAssistantClearCount;
static NSException *IDThrowingInteractionAssistantCause;
static BOOL IDThrowingInteractionAssistantThrowsFromInitializer;
static NSInteger const IDThrowingInteractionAssistantTransientTag = 0x1D26;

@interface IDThrowingInteractionAssistant : NSObject
@property(nonatomic, weak) UIView *hostView;
@property(nonatomic, strong) UIGestureRecognizer *installedRecognizer;
@property(nonatomic, strong) UIView *transientView;
+ (void)resetProbe;
+ (void)prepareForPostInitPreflightFailure;
@end

@implementation IDThrowingInteractionAssistant

+ (void)resetProbe {
    IDThrowingInteractionAssistantClearCount = 0;
    IDThrowingInteractionAssistantCause = nil;
    IDThrowingInteractionAssistantThrowsFromInitializer = YES;
}

+ (void)prepareForPostInitPreflightFailure {
    IDThrowingInteractionAssistantClearCount = 0;
    IDThrowingInteractionAssistantCause = nil;
    IDThrowingInteractionAssistantThrowsFromInitializer = NO;
}

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if (self) {
        self.hostView = view;
        self.installedRecognizer = [UITapGestureRecognizer new];
        [view addGestureRecognizer:self.installedRecognizer];
        self.transientView = [[UIView alloc] initWithFrame:CGRectMake(1, 1, 2, 2)];
        self.transientView.tag = IDThrowingInteractionAssistantTransientTag;
        [view addSubview:self.transientView];
        if (IDThrowingInteractionAssistantThrowsFromInitializer) {
            IDThrowingInteractionAssistantCause =
                [NSException exceptionWithName:@"IDSyntheticAssistantInitFailure"
                                        reason:@"synthetic initializer failed after adopting host state"
                                      userInfo:nil];
            @throw IDThrowingInteractionAssistantCause;
        }
    }
    return self;
}

- (void)selectionChanged {}
- (void)activateSelection {}
- (void)deactivateSelection {}
- (void)setSelectionDisplayVisible:(BOOL)visible { (void)visible; }
- (void)setNeedsSelectionDisplayUpdate {}
- (void)setGestureRecognizers {}
- (void)clearGestureRecognizers:(BOOL)force {
    (void)force;
    IDThrowingInteractionAssistantClearCount += 1;
    [self.hostView removeGestureRecognizer:self.installedRecognizer];
    [self.transientView removeFromSuperview];
}
- (void)beginFloatingCursorAtPoint:(CGPoint)point { (void)point; }
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    (void)point;
    (void)animated;
}
- (void)endFloatingCursor {}
- (void)resignedFirstResponder {}
- (void)detach:(BOOL)force { (void)force; }

@end

@interface IDPreflightFailingInteractionAssistant : IDThrowingInteractionAssistant
@end

@implementation IDPreflightFailingInteractionAssistant

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if (selector == @selector(selectionChanged)) return nil;
    return [super methodSignatureForSelector:selector];
}

@end

@interface IDInteractionABIValidationProbe : NSObject
@end

@implementation IDInteractionABIValidationProbe

- (id)interactionAssistant { return self; }
- (id)customRenderController { return nil; }
- (CGPoint)_convertPointFromRenderSpace:(CGPoint)point { return point; }
- (id)_textInputViewForAddingGestureRecognizers { return self; }
- (id)selectionContainerView { return self; }
- (BOOL)_isInteractiveTextSelectionDisabled { return NO; }
- (void)_updateSelectionGestures {}
- (void)_textKit2CanvasDidLayout {}
- (BOOL)isEditing { return YES; }
- (BOOL)hasEditableSelection { return YES; }
- (id)_visualSelectionRangeForExtent:(id)extent
                            forPoint:(CGPoint)point
                        fromPosition:(id)position
                         inDirection:(NSInteger)direction {
    (void)extent; (void)point; (void)position; (void)direction;
    return nil;
}

- (void)selectionChanged {}
- (void)activateSelection {}
- (void)deactivateSelection {}
- (void)setSelectionDisplayVisible:(BOOL)visible { (void)visible; }
- (void)setNeedsSelectionDisplayUpdate {}
- (void)setGestureRecognizers {}
- (void)clearGestureRecognizers:(BOOL)force { (void)force; }
- (void)beginFloatingCursorAtPoint:(CGPoint)point { (void)point; }
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    (void)point;
    (void)animated;
}
- (void)endFloatingCursor {}
- (void)resignedFirstResponder {}
- (void)detach:(BOOL)force { (void)force; }

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    for (NSUInteger index = 0; index < 256; index += 1) {
        __unused NSArray *pressure = @[
            [NSString stringWithFormat:@"argument-%lu", (unsigned long)index],
            [NSMutableData dataWithLength:64],
        ];
    }
    return signature;
}

@end

@interface IDFloatingContainerStockProbe : UIView
@property(nonatomic, strong, nullable) UIView *observedContainer;
@end

@implementation IDFloatingContainerStockProbe
- (UIView *)selectionContainerView { return self.observedContainer; }
@end

@interface IDFloatingContainerWrongBackendABIProbe : UIView
@end

@implementation IDFloatingContainerWrongBackendABIProbe
- (BOOL)id_selectionPresentationBackend { return YES; }
@end

@interface IDTextView (IDPrivateContainerValidationTesting)
- (void)setTextContainer:(NSTextContainer *)textContainer;
- (void)id_preflightInputController:(id)controller;
@end

@interface IDRichTextSelectionRect (IDPrivateMutableRectTesting)
- (void)setRect:(CGRect)rect fromView:(nullable UIView *)view;
- (void)setContainsStart:(BOOL)containsStart;
- (void)setContainsEnd:(BOOL)containsEnd;
@end

@interface IDPreflightProbeTextView : IDTextView
@property(nonatomic) NSUInteger inputControllerPreflightCount;
@end

@implementation IDPreflightProbeTextView
- (void)id_preflightInputController:(id)controller {
    self.inputControllerPreflightCount += 1;
    [super id_preflightInputController:controller];
}
@end

@interface IDBackwardDeleteAggregateProbe : NSObject
@property(nonatomic) NSUInteger unionRangeCallCount;
@end

@implementation IDBackwardDeleteAggregateProbe
- (NSRange)unionRange {
    self.unionRangeCallCount += 1;
    return NSMakeRange(0, 0);
}
@end

@interface IDBackwardDeleteControllerProbe : NSObject
@property(nonatomic) NSUInteger rangesQueryCount;
@property(nonatomic, strong) id rangesResult;
@end

@implementation IDBackwardDeleteControllerProbe
- (id)_rangesForBackwardsDelete {
    self.rangesQueryCount += 1;
    return self.rangesResult;
}
@end

@interface IDBoolSetterProbe : NSObject
@property(nonatomic) BOOL continuousSpellCheckingEnabled;
@end

@implementation IDBoolSetterProbe
@end

@interface IDInputLayoutManagerDetachProbe : NSObject
@property(nonatomic) NSUInteger detachCallCount;
@end

@implementation IDInputLayoutManagerDetachProbe
- (void)_detachFromLayoutManager {
    self.detachCallCount += 1;
}
@end

static NSUInteger IDWrongInputInitializerCallCount;
static NSUInteger IDWrongInputDelegateSetterCallCount;

static NSInteger IDWrongAutoscrollStart(id self, SEL command, CGPoint point) {
    (void)self; (void)command; (void)point;
    return 0;
}

static void IDValidAutoscrollCancel(id self, SEL command) {
    (void)self; (void)command;
}

@interface IDWrongRichInputInitializerABI : NSObject
- (NSInteger)initWithTextLayoutController:(id)layoutController;
- (void)setDelegate:(id)delegate;
@end

@implementation IDWrongRichInputInitializerABI
- (NSInteger)initWithTextLayoutController:(id)layoutController {
    (void)layoutController;
    IDWrongInputInitializerCallCount += 1;
    return 0;
}
- (void)setDelegate:(id)delegate {
    (void)delegate;
}
@end

@interface IDWrongRichInputDelegateABI : NSObject
- (instancetype)initWithTextLayoutController:(id)layoutController;
- (id)setDelegate:(id)delegate;
@end

@implementation IDWrongRichInputDelegateABI
- (instancetype)initWithTextLayoutController:(id)layoutController {
    (void)layoutController;
    return [super init];
}
- (id)setDelegate:(id)delegate {
    (void)delegate;
    IDWrongInputDelegateSetterCallCount += 1;
    return self;
}
@end

@interface IDUIKitAutoscrollOracleTarget : NSObject
@property(nonatomic) NSUInteger callbackCount;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *callbackTimestamps;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *observedCounts;
@property(nonatomic, strong, nullable) XCTestExpectation *callbackExpectation;
- (void)updateAutoscroll:(id)autoscroll;
@end

@implementation IDUIKitAutoscrollOracleTarget
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _callbackTimestamps = [NSMutableArray array];
        _observedCounts = [NSMutableArray array];
    }
    return self;
}
- (void)updateAutoscroll:(id)autoscroll {
    (void)autoscroll;
    self.callbackCount += 1;
    [self.callbackTimestamps addObject:@(CACurrentMediaTime())];
    NSDictionary<NSString *, id> *snapshot =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    [self.observedCounts addObject:snapshot[@"count"]];
    if (self.callbackExpectation != nil) {
        [self.callbackExpectation fulfill];
    }
}
@end

@interface IDUIKitAutoscrollOracleContainer : UIScrollView
@property(nonatomic) BOOL permitsAutoscroll;
- (BOOL)shouldAutoscroll;
@end

@implementation IDUIKitAutoscrollOracleContainer
- (BOOL)shouldAutoscroll {
    return self.permitsAutoscroll;
}
@end

@interface IDInteractionHostTopologyTestInteraction : NSObject <UIInteraction>
@property(nonatomic, weak, readwrite, nullable) UIView *view;
@end

@implementation IDInteractionHostTopologyTestInteraction
- (void)willMoveToView:(UIView *)view {
    (void)view;
}
- (void)didMoveToView:(UIView *)view {
    self.view = view;
}
@end

@implementation IDPrivateUIKitTests

- (void)testInteractionHostTopologyReportsInnerOwnershipInsteadOfEmptyOuterSuccess {
    UIScrollView *outer = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0, 0, 200, 200)];
    UIView *inner = [[UIView alloc] initWithFrame:outer.bounds];
    [outer addSubview:inner];
    UITapGestureRecognizer *recognizer = [UITapGestureRecognizer new];
    [inner addGestureRecognizer:recognizer];
    IDInteractionHostTopologyTestInteraction *interaction =
        [IDInteractionHostTopologyTestInteraction new];
    [inner addInteraction:interaction];

    NSDictionary<NSString *, id> *snapshot =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, inner, nil);

    XCTAssertFalse([outer.gestureRecognizers containsObject:recognizer]);
    XCTAssertEqualObjects(snapshot[@"schema"], @1);
    XCTAssertEqualObjects(snapshot[@"installationHost"], @"blockStack");
    XCTAssertEqualObjects(snapshot[@"liveHostCount"], @1);
    XCTAssertEqualObjects(snapshot[@"duplicateRecognizerIdentityCount"], @0);
    XCTAssertEqualObjects(snapshot[@"duplicateInteractionIdentityCount"], @0);
    XCTAssertEqualObjects(snapshot[@"hosts"][@"outer"][@"present"], @YES);
    XCTAssertEqualObjects(snapshot[@"hosts"][@"blockStack"][@"interactionCount"], @1);
}

- (void)testInteractionHostTopologyReportsRawIdentityAndOwnerSignatures {
    UIView *outer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    UIView *inner = [[UIView alloc] initWithFrame:outer.bounds];
    [outer addSubview:inner];
    UITapGestureRecognizer *recognizer = [UITapGestureRecognizer new];
    [outer addGestureRecognizer:recognizer];
    IDInteractionHostTopologyTestInteraction *interaction =
        [IDInteractionHostTopologyTestInteraction new];
    [outer addInteraction:interaction];

    NSDictionary<NSString *, id> *snapshot =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, inner, nil);
    NSSet<NSString *> *expectedTopLevel = [NSSet setWithArray:@[
        @"schema", @"installationHost", @"liveHostCount",
        @"duplicateRecognizerIdentityCount", @"duplicateInteractionIdentityCount",
        @"stableForEpoch", @"epochInstallationHost", @"hosts",
    ]];
    NSSet<NSString *> *expectedHost = [NSSet setWithArray:@[
        @"present", @"viewToken", @"ancestry", @"recognizerCount",
        @"recognizerSignature", @"recognizerIdentitySignature",
        @"recognizerEnabledSignature", @"recognizerOwnerIdentitySignature",
        @"interactionCount", @"interactionSignature",
        @"interactionIdentitySignature", @"interactionOwnerIdentitySignature",
        @"baselineRecognizerIdentitySignature",
        @"baselineInteractionIdentitySignature",
        @"addedRecognizerIdentitySignature", @"addedInteractionIdentitySignature",
        @"removedRecognizerIdentitySignature", @"removedInteractionIdentitySignature",
    ]];

    XCTAssertEqualObjects([NSSet setWithArray:snapshot.allKeys], expectedTopLevel);
    XCTAssertEqualObjects([NSSet setWithArray:[snapshot[@"hosts"] allKeys]],
                          ([NSSet setWithArray:@[@"outer", @"blockStack", @"external"]]));
    XCTAssertEqualObjects(
        [NSSet setWithArray:[snapshot[@"hosts"][@"outer"] allKeys]], expectedHost);
    XCTAssertEqualObjects(snapshot[@"installationHost"], @"outer");
    XCTAssertEqualObjects(snapshot[@"stableForEpoch"], @YES);
    XCTAssertEqualObjects(snapshot[@"hosts"][@"outer"][@"recognizerCount"], @1);
    XCTAssertEqualObjects(snapshot[@"hosts"][@"outer"][@"interactionCount"], @1);
    XCTAssertEqual([snapshot[@"hosts"][@"outer"][@"recognizerIdentitySignature"] count], 1U);
    XCTAssertEqual([snapshot[@"hosts"][@"outer"][@"recognizerOwnerIdentitySignature"] count], 1U);
    XCTAssertEqual([snapshot[@"hosts"][@"outer"][@"interactionIdentitySignature"] count], 1U);
    XCTAssertEqual([snapshot[@"hosts"][@"outer"][@"interactionOwnerIdentitySignature"] count], 1U);
    XCTAssertEqualObjects(snapshot[@"hosts"][@"blockStack"][@"ancestry"], @"descendant");
    XCTAssertEqualObjects(snapshot[@"hosts"][@"external"][@"present"], @NO);
    XCTAssertEqualObjects(snapshot[@"hosts"][@"external"][@"ancestry"], @"none");
}

- (void)testInteractionHostTopologyRejectsTheSameObjectOnTwoLogicalHosts {
    UIView *shared = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    [shared addGestureRecognizer:[UITapGestureRecognizer new]];
    [shared addInteraction:[IDInteractionHostTopologyTestInteraction new]];

    NSDictionary<NSString *, id> *snapshot =
        IDPrivateCopyInteractionHostTopologyForUITesting(shared, shared, nil);

    XCTAssertEqualObjects(snapshot[@"installationHost"], @"multiple");
    XCTAssertEqualObjects(snapshot[@"liveHostCount"], @2);
    XCTAssertEqualObjects(snapshot[@"duplicateRecognizerIdentityCount"], @1);
    XCTAssertEqualObjects(snapshot[@"duplicateInteractionIdentityCount"], @1);
    XCTAssertEqualObjects(snapshot[@"stableForEpoch"], @YES);
}

- (void)testInteractionHostTopologyFreezesAndResetsActiveEpochBaseline {
    UIView *outer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    [outer addGestureRecognizer:[UITapGestureRecognizer new]];
    [outer addInteraction:[IDInteractionHostTopologyTestInteraction new]];

    NSDictionary<NSString *, id> *baseline =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, nil, nil);
    XCTAssertEqualObjects(baseline[@"stableForEpoch"], @YES);
    XCTAssertEqualObjects(
        baseline[@"hosts"][@"outer"][@"addedRecognizerIdentitySignature"], @[]);

    UITapGestureRecognizer *added = [UITapGestureRecognizer new];
    [outer addGestureRecognizer:added];
    NSDictionary<NSString *, id> *mutated =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, nil, nil);
    XCTAssertEqualObjects(mutated[@"stableForEpoch"], @NO);
    XCTAssertEqual(
        [mutated[@"hosts"][@"outer"][@"addedRecognizerIdentitySignature"] count], 1U);

    IDPrivateResetInteractionHostTopologyBaselineForUITesting(outer, nil, nil);
    NSDictionary<NSString *, id> *reset =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, nil, nil);
    XCTAssertEqualObjects(reset[@"stableForEpoch"], @YES);
    XCTAssertEqualObjects(
        reset[@"hosts"][@"outer"][@"addedRecognizerIdentitySignature"], @[]);
    XCTAssertEqualObjects(reset[@"hosts"][@"outer"][@"removedRecognizerIdentitySignature"], @[]);

    [outer removeGestureRecognizer:added];
    NSDictionary<NSString *, id> *removed =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, nil, nil);
    XCTAssertEqualObjects(removed[@"stableForEpoch"], @NO);
    XCTAssertEqual(
        [removed[@"hosts"][@"outer"][@"removedRecognizerIdentitySignature"] count], 1U);
}

- (void)testInteractionHostTopologyReportsExternalOwnershipWithoutHierarchyScan {
    UIView *outer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    UIView *inner = [[UIView alloc] initWithFrame:outer.bounds];
    UIView *external = [[UIView alloc] initWithFrame:outer.bounds];
    [outer addSubview:inner];
    [external addInteraction:[IDInteractionHostTopologyTestInteraction new]];

    NSDictionary<NSString *, id> *snapshot =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, inner, external);
    XCTAssertEqualObjects(snapshot[@"installationHost"], @"external");
    XCTAssertEqualObjects(snapshot[@"liveHostCount"], @1);
    XCTAssertEqualObjects(snapshot[@"hosts"][@"external"][@"ancestry"], @"external");

    IDPrivateResetInteractionHostTopologyBaselineForUITesting(outer, inner, external);
    NSDictionary<NSString *, id> *withoutExplicitExternal =
        IDPrivateCopyInteractionHostTopologyForUITesting(outer, inner, nil);
    XCTAssertEqualObjects(withoutExplicitExternal[@"installationHost"], @"none");
    XCTAssertEqualObjects(withoutExplicitExternal[@"liveHostCount"], @0);
}

- (void)testInlinePredictionDismissWrapperChecksExactABIAndFailsClosed {
    IDInlinePredictionDismissProbeCallCount = 0;
    XCTAssertTrue(
        IDPrivateTestingDismissInlineTextCompletionWithKeyboardClass(
            IDInlinePredictionDismissGoodProbe.class));
    XCTAssertEqual(IDInlinePredictionDismissProbeCallCount, 1U);

    XCTAssertFalse(
        IDPrivateTestingDismissInlineTextCompletionWithKeyboardClass(
            IDInlinePredictionDismissMissingProbe.class));
    XCTAssertFalse(
        IDPrivateTestingDismissInlineTextCompletionWithKeyboardClass(
            IDInlinePredictionDismissWrongABIProbe.class));
    XCTAssertFalse(
        IDPrivateTestingDismissInlineTextCompletionWithKeyboardClass(Nil));
    XCTAssertEqual(IDInlinePredictionDismissProbeCallCount, 1U);
}

- (void)testStockOracleLifecycleBoundaryConstructsTypedHostAndSeparatesActions {
    UITextView *resignEditor = (UITextView *)IDPrivateNewStockOracleTextView(
        UITextView.class, CGRectMake(0, 0, 240, 160));
    XCTAssertTrue([resignEditor isKindOfClass:UITextView.class]);
    IDPrivateTestingRequestResponderLoss(resignEditor);
    NSDictionary *resign =
        IDPrivateCopyStockFloatingLifecycleStateForUITesting(resignEditor);
    XCTAssertEqual([resign[@"resignActionCount"] unsignedIntegerValue], 1U);
    XCTAssertEqual([resign[@"keyboardDismissActionCount"] unsignedIntegerValue], 0U);

    UITextView *dismissEditor = (UITextView *)IDPrivateNewStockOracleTextView(
        UITextView.class, CGRectMake(0, 0, 240, 160));
    IDPrivateTestingRequestKeyboardDismissal(dismissEditor);
    NSDictionary *dismiss =
        IDPrivateCopyStockFloatingLifecycleStateForUITesting(dismissEditor);
    XCTAssertEqual([dismiss[@"resignActionCount"] unsignedIntegerValue], 0U);
    XCTAssertEqual([dismiss[@"keyboardDismissActionCount"] unsignedIntegerValue], 1U);
    NSSet *required = [NSSet setWithArray:@[
        @"resignActionCount", @"keyboardDismissActionCount", @"responderLossCount",
        @"editableOffCount", @"selectableOffCount", @"presentationUpdates",
        @"containerToken", @"containerStable", @"containerSubviews",
        @"sessionObject", @"assistantSessionObject", @"displaySessionObject",
        @"sessionOwnersMatch", @"assistantSessionToken", @"displaySessionToken",
        @"sessionActive", @"autoscrollObject", @"autoscrollActive",
        @"recognizerCount", @"recognizerSignature",
    ]];
    XCTAssertTrue([required isSubsetOfSet:[NSSet setWithArray:dismiss.allKeys]]);
}

- (void)testFloatingLifecycleAssistantSelectorsHaveExactABIs {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 120, 80)
        attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"lifecycle"]]];
    Class cls = [view.id_interactionAssistant class];
    NSMethodSignature *resigned = [cls instanceMethodSignatureForSelector:
        NSSelectorFromString(@"resignedFirstResponder")];
    NSMethodSignature *detach = [cls instanceMethodSignatureForSelector:
        NSSelectorFromString(@"detach:")];
    XCTAssertNotNil(resigned);
    XCTAssertEqual(strcmp(resigned.methodReturnType, @encode(void)), 0);
    XCTAssertEqual(resigned.numberOfArguments, 2U);
    XCTAssertNotNil(detach);
    XCTAssertEqual(strcmp(detach.methodReturnType, @encode(void)), 0);
    XCTAssertEqual(detach.numberOfArguments, 3U);
    XCTAssertEqual(strcmp([detach getArgumentTypeAtIndex:2], @encode(BOOL)), 0);
}

- (void)testTextAutoscrollDirectionUsesRecoveredPrivateInsetsAtMovingOffset {
    UITextView *stock = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    stock.text = [@"line\n" stringByPaddingToLength:4000 withString:@"line\n"
                                            startingAtIndex:0];
    stock.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    stock.contentOffset = CGPointMake(0, 80);
    [stock layoutIfNeeded];
    stock.contentSize = CGSizeMake(320, 4000);

    UIEdgeInsets measured = UIEdgeInsetsMake(40, 5, 8, 5);
    CGPoint pointBetweenOldAndRecoveredTopBands = CGPointMake(100, 110);
    __block CGRect safe = CGRectZero;
    __block NSUInteger direction = 0;
    IDPrivateTestingWithTextContainerInsetAdjustment(stock, measured, ^{
        safe = IDPrivateTextAutoscrollSafeRect(stock, stock.textContainerInset, 8.0);
        direction = IDPrivateTextAutoscrollDirections(
            stock, stock.textContainerInset, pointBetweenOldAndRecoveredTopBands, 8.0);
    });

    XCTAssertEqual(direction, 4U, @"safe=%@ content=%@",
                   NSStringFromCGRect(safe), NSStringFromCGSize(stock.contentSize));
}

- (void)testUIKitAutoscrollOracleSnapshotsAcceptedStart {
    id autoscroll = IDPrivateTestingNewUIKitAutoscroll();
    IDUIKitAutoscrollOracleTarget *target =
        [IDUIKitAutoscrollOracleTarget new];
    UIScrollView *container =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    CGPoint point = CGPointMake(12.5, 88.0);

    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, point, 8U, 10.0));
    NSDictionary<NSString *, id> *snapshot =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertTrue([snapshot[@"active"] boolValue]);
    XCTAssertTrue([snapshot[@"targetPresent"] boolValue]);
    XCTAssertTrue([snapshot[@"containerPresent"] boolValue]);
    XCTAssertEqual([snapshot[@"directions"] unsignedIntegerValue], 8U);
    XCTAssertEqualWithAccuracy(
        [snapshot[@"repeatInterval"] doubleValue], 10.0, 0.000001);
    XCTAssertTrue(CGPointEqualToPoint(
        [snapshot[@"point"] CGPointValue], point));
    XCTAssertNotEqual([snapshot[@"timerIdentity"] unsignedLongLongValue], 0ULL);

    IDPrivateTestingInvalidateUIKitAutoscroll(autoscroll);
}

- (void)testUIKitAutoscrollOracleRejectsInvalidAndDisabledStarts {
    UIScrollView *container = [UIScrollView new];
    IDUIKitAutoscrollOracleTarget *target =
        [IDUIKitAutoscrollOracleTarget new];

    id incompatibleTargetAutoscroll =
        IDPrivateTestingNewUIKitAutoscroll();
    XCTAssertFalse(IDPrivateTestingStartUIKitAutoscroll(
        incompatibleTargetAutoscroll, [NSObject new], container,
        CGPointZero, 8U, 0.075));

    id nilContainerAutoscroll = IDPrivateTestingNewUIKitAutoscroll();
    XCTAssertFalse(IDPrivateTestingStartUIKitAutoscroll(
        nilContainerAutoscroll, target, nil, CGPointZero, 8U, 0.075));

    id zeroDirectionAutoscroll = IDPrivateTestingNewUIKitAutoscroll();
    XCTAssertFalse(IDPrivateTestingStartUIKitAutoscroll(
        zeroDirectionAutoscroll, target, container, CGPointZero, 0U, 0.075));

    id zeroIntervalAutoscroll = IDPrivateTestingNewUIKitAutoscroll();
    XCTAssertFalse(IDPrivateTestingStartUIKitAutoscroll(
        zeroIntervalAutoscroll, target, container, CGPointZero, 8U, 0.0));

    IDUIKitAutoscrollOracleContainer *rejectingContainer =
        [IDUIKitAutoscrollOracleContainer new];
    rejectingContainer.permitsAutoscroll = NO;
    id policyAutoscroll = IDPrivateTestingNewUIKitAutoscroll();
    XCTAssertFalse(IDPrivateTestingStartUIKitAutoscroll(
        policyAutoscroll, target, rejectingContainer, CGPointZero, 8U, 0.075));

    id disabledAutoscroll = IDPrivateTestingNewUIKitAutoscroll();
    IDPrivateTestingSetUIKitAutoscrollDisabled(disabledAutoscroll, YES);
    XCTAssertFalse(IDPrivateTestingStartUIKitAutoscroll(
        disabledAutoscroll, target, container, CGPointZero, 8U, 0.075));

    for (id autoscroll in @[
             incompatibleTargetAutoscroll,
             nilContainerAutoscroll,
             zeroDirectionAutoscroll,
             zeroIntervalAutoscroll,
             policyAutoscroll,
             disabledAutoscroll,
         ]) {
        NSDictionary *snapshot =
            IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
        XCTAssertFalse([snapshot[@"active"] boolValue]);
        XCTAssertEqual([snapshot[@"timerIdentity"] unsignedLongLongValue], 0ULL);
    }
}

- (void)testUIKitAutoscrollOracleIncrementsCountBeforeCallback {
    id autoscroll = IDPrivateTestingNewUIKitAutoscroll();
    IDUIKitAutoscrollOracleTarget *target =
        [IDUIKitAutoscrollOracleTarget new];
    UIScrollView *container = [UIScrollView new];
    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointZero, 8U, 10.0));

    IDPrivateTestingFireUIKitAutoscroll(autoscroll);
    IDPrivateTestingFireUIKitAutoscroll(autoscroll);

    XCTAssertEqualObjects(target.observedCounts, (@[@1, @2]));
    XCTAssertEqual(
        [IDPrivateTestingCopyUIKitAutoscrollSnapshot(
            autoscroll)[@"count"] unsignedIntegerValue],
        2U);
    IDPrivateTestingInvalidateUIKitAutoscroll(autoscroll);
}

- (void)testUIKitAutoscrollOracleCoalescesBelowSeventyAndRestartsAtSeventy {
    id autoscroll = IDPrivateTestingNewUIKitAutoscroll();
    IDUIKitAutoscrollOracleTarget *target =
        [IDUIKitAutoscrollOracleTarget new];
    UIScrollView *container =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointZero, 8U, 10.0));
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.1];
    while (target.callbackCount == 0 && deadline.timeIntervalSinceNow > 0.0) {
        [NSRunLoop.mainRunLoop
            runMode:NSDefaultRunLoopMode
            beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    }
    XCTAssertEqual(target.callbackCount, 1U);
    NSDictionary *before =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);

    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointMake(69.999, 0), 8U, 10.0));
    NSDictionary *coalesced =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertEqualObjects(coalesced[@"timerIdentity"], before[@"timerIdentity"]);
    XCTAssertEqualObjects(coalesced[@"timerFireDate"], before[@"timerFireDate"]);
    XCTAssertEqual([coalesced[@"count"] unsignedIntegerValue], 1U);

    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointMake(139.999, 0), 8U, 10.0));
    NSDictionary *restarted =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertEqualObjects(restarted[@"timerIdentity"], before[@"timerIdentity"]);
    XCTAssertLessThan(
        [restarted[@"timerFireDate"] doubleValue],
        [coalesced[@"timerFireDate"] doubleValue] - 1.0);
    XCTAssertEqual([restarted[@"count"] unsignedIntegerValue], 1U);
    IDPrivateTestingInvalidateUIKitAutoscroll(autoscroll);
}

- (void)testUIKitAutoscrollOracleUsesGlobalDistanceAndResetsCountOnlyForDirection {
    id autoscroll = IDPrivateTestingNewUIKitAutoscroll();
    IDUIKitAutoscrollOracleTarget *target =
        [IDUIKitAutoscrollOracleTarget new];
    UIView *root =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    UIScrollView *container =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    container.transform = CGAffineTransformMakeScale(2.0, 2.0);
    [root addSubview:container];

    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointZero, 8U, 10.0));
    IDPrivateTestingFireUIKitAutoscroll(autoscroll);
    NSDictionary *before =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertEqual([before[@"count"] unsignedIntegerValue], 1U);

    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointMake(40, 0), 8U, 11.0));
    NSDictionary *intervalRestart =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertEqual([intervalRestart[@"count"] unsignedIntegerValue], 1U);

    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointMake(40, 0), 4U, 11.0));
    NSDictionary *directionRestart =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertEqual([directionRestart[@"count"] unsignedIntegerValue], 0U);
    IDPrivateTestingInvalidateUIKitAutoscroll(autoscroll);
}

- (void)testUIKitAutoscrollOracleOwnsTargetWeaklyAndContainerWhileActive {
    id autoscroll = IDPrivateTestingNewUIKitAutoscroll();
    __weak IDUIKitAutoscrollOracleTarget *weakTarget;
    __weak UIScrollView *weakContainer;
    @autoreleasepool {
        IDUIKitAutoscrollOracleTarget *target =
            [IDUIKitAutoscrollOracleTarget new];
        UIScrollView *container = [UIScrollView new];
        weakTarget = target;
        weakContainer = container;
        XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
            autoscroll, target, container, CGPointZero, 8U, 10.0));
    }

    XCTAssertNil(weakTarget);
    XCTAssertNotNil(weakContainer);
    NSDictionary *active =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertFalse([active[@"targetPresent"] boolValue]);
    XCTAssertTrue([active[@"containerPresent"] boolValue]);

    IDPrivateTestingInvalidateUIKitAutoscroll(autoscroll);
    XCTAssertNil(weakContainer);
    NSDictionary *inactive =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    XCTAssertFalse([inactive[@"active"] boolValue]);
    XCTAssertFalse([inactive[@"containerPresent"] boolValue]);
    XCTAssertEqual([inactive[@"timerIdentity"] unsignedLongLongValue], 0ULL);
    IDPrivateTestingInvalidateUIKitAutoscroll(autoscroll);
}

- (void)testUIKitAutoscrollOracleFiresImmediatelyAndRepeatsAtSeventyFiveMilliseconds {
    id autoscroll = IDPrivateTestingNewUIKitAutoscroll();
    IDUIKitAutoscrollOracleTarget *target =
        [IDUIKitAutoscrollOracleTarget new];
    target.callbackExpectation =
        [self expectationWithDescription:@"three UIKit autoscroll callbacks"];
    target.callbackExpectation.expectedFulfillmentCount = 3;
    UIScrollView *container = [UIScrollView new];
    CFTimeInterval start = CACurrentMediaTime();

    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        autoscroll, target, container, CGPointZero, 8U, 0.075));
    [self waitForExpectations:@[target.callbackExpectation] timeout:0.4];
    IDPrivateTestingInvalidateUIKitAutoscroll(autoscroll);

    XCTAssertGreaterThanOrEqual(target.callbackTimestamps.count, 3U);
    XCTAssertLessThan(
        target.callbackTimestamps[0].doubleValue - start, 0.05);
    for (NSUInteger index = 1; index < 3; index += 1) {
        NSTimeInterval interval =
            target.callbackTimestamps[index].doubleValue -
            target.callbackTimestamps[index - 1].doubleValue;
        XCTAssertEqualWithAccuracy(interval, 0.075, 0.04);
    }
}

- (void)testTextAutoscrollSafeRectAppliesNegativeHorizontalAdjustmentBeforeEffectiveInset {
    CGRect safe = IDPrivateTestingTextAutoscrollSafeRectWithGeometry(
        CGRectMake(10, 20, 300, 200), UIEdgeInsetsMake(8, 5, 8, 5),
        UIEdgeInsetsMake(10, 7, 12, 9), -4.0, UIEdgeInsetsZero, 8.0);
    XCTAssertTrue(CGRectEqualToRect(safe, CGRectMake(14, 38, 279, 162)), @"%@",
                                  NSStringFromCGRect(safe));
}

- (void)testTextAutoscrollSafeRectAppliesNonzeroEffectiveInsetAfterTextGeometry {
    CGRect safe = IDPrivateTestingTextAutoscrollSafeRectWithGeometry(
        CGRectMake(10, 20, 300, 200), UIEdgeInsetsMake(8, 5, 8, 5),
        UIEdgeInsetsMake(10, 7, 12, 9), 0.0,
        UIEdgeInsetsMake(3, 11, 13, 17), 8.0);
    XCTAssertTrue(CGRectEqualToRect(safe, CGRectMake(36, 41, 240, 146)), @"%@",
                                  NSStringFromCGRect(safe));
}

- (void)testPrivateTestingWrappersRejectMissingPrivateABIs {
    UIView *plainView = [UIView new];
    UIScrollView *plainScroll = [UIScrollView new];
    XCTAssertThrowsSpecificNamed(
        IDPrivateTestingInternalTextLayoutController(plainView),
        NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(
        IDPrivateTestingCursorPositionAtPoint(plainView, nil, CGPointZero, NULL),
        NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(
        IDPrivateTestingConvertPointFromRenderSpace(plainView, CGPointZero),
        NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(
        IDPrivateTestingWithTextContainerInsetAdjustment(plainScroll, UIEdgeInsetsZero, ^{}),
        NSException, NSInternalInconsistencyException);
}

- (void)testTextAutoscrollSafeRectRejectsPresentWrongSizeInsetAdjustmentIvar {
    UIScrollView *host = IDPrivateTestingNewTextAutoscrollHostWithIncompatibleIvar(
        IDPrivateTestingIncompatibleAutoscrollIvarTextContainerInsetAdjustment);
    XCTAssertThrowsSpecificNamed(
        IDPrivateTextAutoscrollSafeRect(host, UIEdgeInsetsZero, 8.0),
        NSException, NSInternalInconsistencyException);
}

- (void)testTextAutoscrollSafeRectRejectsPresentWrongSizeHorizontalAdjustmentIvar {
    UIScrollView *host = IDPrivateTestingNewTextAutoscrollHostWithIncompatibleIvar(
        IDPrivateTestingIncompatibleAutoscrollIvarHorizontalGeometryAdjustment);
    XCTAssertThrowsSpecificNamed(
        IDPrivateTextAutoscrollSafeRect(host, UIEdgeInsetsZero, 8.0),
        NSException, NSInternalInconsistencyException);
}

- (void)testTextAutoscrollSafeRectAllowsAbsentGeometryAdjustmentIvars {
    UIScrollView *host = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    host.contentSize = CGSizeMake(320, 1000);
    XCTAssertNoThrow(IDPrivateTextAutoscrollSafeRect(host, UIEdgeInsetsZero, 8.0));
}

static NSArray<NSString *> *IDRichLayoutP0SelectorNames(void) {
    return @[
        @"textStorage",
        @"textContainers",
        @"firstTextContainer",
        @"textContainerForPosition:",
        @"beginningOfDocument",
        @"endOfDocument",
        @"emptyTextRangeAtPosition:",
        @"textRangeFromPosition:toPosition:",
        @"positionFromPosition:offset:",
        @"positionFromPosition:offset:affinity:",
        @"positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:",
        @"textRangeForLineEnclosingPosition:",
        @"textRangeForLineEnclosingPosition:effectiveAffinity:",
        @"attributesAtPosition:inDirection:",
        @"baseWritingDirectionAtPosition:",
        @"comparePosition:toPosition:",
        @"offsetFromPosition:toPosition:",
        @"affinityForPosition:",
        @"characterRangeForTextRange:",
        @"boundingRectForCharacterRange:",
        @"characterRangeForTextRange:clippedToDocument:",
        @"characterRangesForTextRange:clippedToDocument:",
        @"textRangeForCharacterRange:",
        @"textRangeForCharacterRanges:",
        @"positionWithOffset:affinity:",
        @"textInputController",
        @"adoptTextInputController:",
        @"detachFromTextInputController",
        @"canAccessLayoutManager",
        @"invalidateDisplayForCharacterRange:",
        @"rangeOfCharacterClusterAtIndex:type:",
        @"selectionRectsForRange:fromView:forContainerPassingTest:",
        @"requestTextGeometryAtPosition:typingAttributes:resultBlock:",
        @"insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:",
        @"cursorPositionAtPoint:inContainer:",
        @"nearestPositionAtPoint:inContainer:",
        @"ensureLayoutForRange:",
        @"invalidateLayoutForRange:",
        @"annotatedSubstringForRange:",
        @"addAnnotationAttribute:value:forRange:",
        @"annotationAttribute:atPosition:",
        @"removeAnnotationAttribute:forRange:",
        @"addRenderingAttributes:forRange:",
        @"removeRenderingAttributes:forRange:",
        @"_invalidateTemporaryAttributesInRange:",
    ];
}

- (void)testIOS26PrivateContractsArePresent {
    XCTAssertTrue(IDPrivateUIKit.isCompatible, @"%@", IDPrivateUIKit.compatibilityReport);
}

- (void)testRichLayoutCompatibilityReportListsEveryMissingP0Selector {
    NSString *report = IDPrivateRichLayoutCompatibilityReport([NSObject new]);

    for (NSString *selectorName in IDRichLayoutP0SelectorNames()) {
        XCTAssertTrue([report containsString:selectorName], @"%@", report);
    }
}

- (void)testRichLayoutRequirementThrowsStageSpecificExceptionListingAllMissingSelectors {
    NSString *stage = @"Synthetic rich layout construction";
    NSException *caught = nil;

    @try {
        IDPrivateRequireRichLayoutController([NSObject new], stage);
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:stage], @"%@", caught.reason);
    for (NSString *selectorName in IDRichLayoutP0SelectorNames()) {
        XCTAssertTrue([caught.reason containsString:selectorName], @"%@", caught.reason);
    }
}

- (void)testCompatibilityReportNamesEveryRequiredComponent {
    NSString *report = IDPrivateUIKit.compatibilityReport;
    XCTAssertTrue([report containsString:@"_UITextLayoutControllerBase"]);
    XCTAssertTrue([report containsString:@"UITextInputController"]);
    XCTAssertTrue([report containsString:@"UITextInteractionAssistant"]);
    XCTAssertTrue([report containsString:@"UITextPasteConfigurationSupporting_Internal"]);
    // The mechanism is named by IVAR, not by offset, since 2026-09-15: iOS 27 moved
    // _textCanvasViews from +0x50 to +0x58 and the lookup is by name now.
    XCTAssertTrue([report containsString:
        @"_UITextKit2LayoutController._textCanvasViews"]);
    XCTAssertTrue([report containsString:@"NSTextViewportLayoutController layoutViewport"]);
    XCTAssertTrue([report containsString:@"NSTextLayoutFragment drawAtPoint:inContext:"]);
    XCTAssertTrue([report containsString:@"setContinuousSpellCheckingEnabled:"]);
}

- (void)testCompatibilityReportNamesTheLayoutConstructionPath {
    XCTAssertTrue([IDPrivateUIKit.compatibilityReport containsString:@"Layout construction:"]);
}

- (void)testRichLayoutCompatibilityReportIncludesRecoveredMutableSelectionRectABIs {
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha"]]
               defaultAttributes:@{}];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    IDRichTextLayoutController *controller = [[IDRichTextLayoutController alloc]
        initWithDocument:document
               blockStack:stack];
    NSString *report = IDPrivateRichLayoutCompatibilityReport(controller);
    XCTAssertTrue([report containsString:@"3 mutable selection-rect ABI contracts"], @"%@", report);
}

- (void)testMutableSelectionRectCallbacksRoundEndpointsAtActualViewScale {
    IDRichTextSelectionRect *rect = [[IDRichTextSelectionRect alloc]
        initWithRect:CGRectZero
        containsStart:NO
        containsEnd:NO
        isVertical:NO
        writingDirection:NSWritingDirectionLeftToRight];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    view.contentScaleFactor = 3.0;
    [rect setRect:CGRectMake(0.2, 0.2, 1.2, 1.2) fromView:view];
    [rect setContainsStart:YES];
    [rect setContainsEnd:YES];

    XCTAssertEqualWithAccuracy(CGRectGetMinX(rect.rect), 1.0 / 3.0, 0.0001);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(rect.rect), 1.0 / 3.0, 0.0001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(rect.rect), 4.0 / 3.0, 0.0001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(rect.rect), 4.0 / 3.0, 0.0001);
    XCTAssertTrue(rect.containsStart);
    XCTAssertTrue(rect.containsEnd);
}

- (void)testCompatibleRuntimeValidationDoesNotThrow {
    XCTAssertNoThrow([IDPrivateUIKit requireCompatibleRuntime]);
}

- (void)testInteractionABIValidationRetainsNoArgumentAndArgumentTypeSpecs {
    IDInteractionABIValidationProbe *probe = [IDInteractionABIValidationProbe new];

    for (NSUInteger iteration = 0; iteration < 64; iteration += 1) {
        @autoreleasepool {
            XCTAssertNoThrow([IDPrivateUIKit requireInteractionHost:probe
                                                               stage:@"Lifetime host ABI"]);
            XCTAssertNoThrow([IDPrivateUIKit requireInteractionAssistant:probe
                                                                    stage:@"Lifetime assistant ABI"]);
        }
    }
}

- (void)testFloatingContainerCreationCountTracksLiteralStockIdentitiesWithoutRetention {
    IDFloatingContainerStockProbe *probe = [IDFloatingContainerStockProbe new];
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 0U);

    UIView *first = [UIView new];
    __weak UIView *weakFirst = first;
    probe.observedContainer = first;
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 1U);
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 1U);
    probe.observedContainer = nil;
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 1U);

    UIView *second = [UIView new];
    __weak UIView *weakSecond = second;
    probe.observedContainer = second;
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 2U);
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 2U);
    probe.observedContainer = nil;
    first = nil;
    second = nil;
    XCTAssertNil(weakFirst);
    XCTAssertNil(weakSecond);

    UIView *third = [UIView new];
    __weak UIView *weakThird = third;
    probe.observedContainer = third;
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 3U);
    probe.observedContainer = nil;
    third = nil;
    XCTAssertNil(weakThird);
    XCTAssertEqual(IDPrivateFloatingContainerCreationCountForUITesting(probe), 3U);
}

- (void)testFloatingContainerCreationCountRejectsIncompatibleCustomBackendABI {
    IDFloatingContainerWrongBackendABIProbe *probe =
        [IDFloatingContainerWrongBackendABIProbe new];
    XCTAssertThrowsSpecificNamed(
        IDPrivateFloatingContainerCreationCountForUITesting(probe), NSException,
        NSInternalInconsistencyException);
}

- (void)testBlockHostAdoptsRecoveredTextAutoscrollingProtocolWithExactCallbackABIs {
    Protocol *protocol = NSProtocolFromString(@"UITextAutoscrolling");
    XCTAssertNotNil(protocol);
    __unused IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
      attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"autoscroll"]]];
    XCTAssertTrue(class_conformsToProtocol(IDBlockTextView.class, protocol));

    SEL start = NSSelectorFromString(@"startAutoscroll:");
    SEL cancel = NSSelectorFromString(@"cancelAutoscroll");
    NSMethodSignature *startSignature =
        [IDBlockTextView instanceMethodSignatureForSelector:start];
    NSMethodSignature *cancelSignature =
        [IDBlockTextView instanceMethodSignatureForSelector:cancel];
    XCTAssertNotNil(startSignature);
    XCTAssertNotNil(cancelSignature);
    if (startSignature == nil || cancelSignature == nil) return;
    XCTAssertEqual(strcmp(startSignature.methodReturnType, @encode(void)), 0);
    XCTAssertEqual(startSignature.numberOfArguments, 3U);
    XCTAssertEqual(strcmp([startSignature getArgumentTypeAtIndex:2], @encode(CGPoint)), 0);
    XCTAssertEqual(strcmp(cancelSignature.methodReturnType, @encode(void)), 0);
    XCTAssertEqual(cancelSignature.numberOfArguments, 2U);

    struct objc_method_description requiredStart =
        protocol_getMethodDescription(protocol, start, YES, YES);
    struct objc_method_description requiredCancel =
        protocol_getMethodDescription(protocol, cancel, YES, YES);
    XCTAssertNotEqual(requiredStart.name, NULL);
    XCTAssertNotEqual(requiredCancel.name, NULL);
    NSMethodSignature *requiredStartSignature =
        [NSMethodSignature signatureWithObjCTypes:requiredStart.types];
    NSMethodSignature *requiredCancelSignature =
        [NSMethodSignature signatureWithObjCTypes:requiredCancel.types];
    XCTAssertEqual(strcmp(requiredStartSignature.methodReturnType,
                          startSignature.methodReturnType), 0);
    XCTAssertEqual(requiredStartSignature.numberOfArguments,
                   startSignature.numberOfArguments);
    NSUInteger requiredSize = 0, requiredAlignment = 0;
    NSUInteger actualSize = 0, actualAlignment = 0;
    NSGetSizeAndAlignment([requiredStartSignature getArgumentTypeAtIndex:2],
                          &requiredSize, &requiredAlignment);
    NSGetSizeAndAlignment([startSignature getArgumentTypeAtIndex:2],
                          &actualSize, &actualAlignment);
    XCTAssertEqual(requiredSize, actualSize);
    XCTAssertEqual(requiredAlignment, actualAlignment);
    XCTAssertEqual(strcmp(requiredCancelSignature.methodReturnType,
                          cancelSignature.methodReturnType), 0);
    XCTAssertEqual(requiredCancelSignature.numberOfArguments,
                   cancelSignature.numberOfArguments);
    XCTAssertEqual(IDPrivateObject0(view.id_interactionAssistant,
                                    NSSelectorFromString(@"_asTextAutoscrolling")),
                   view);
    XCTAssertEqual(IDPrivateObject0(view.id_interactionAssistant,
                                    NSSelectorFromString(@"scrollView")),
                   view);
}

- (void)testTextAutoscrollingInstallationRejectsWrongStartReturnABIBeforeAdoption {
    static Class wrongABIClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wrongABIClass = objc_allocateClassPair(NSObject.class,
                                               "IDWrongTextAutoscrollingABIProbe", 0);
        class_addMethod(wrongABIClass, NSSelectorFromString(@"startAutoscroll:"),
                        (IMP)IDWrongAutoscrollStart, "q@:{CGPoint=dd}");
        class_addMethod(wrongABIClass, NSSelectorFromString(@"cancelAutoscroll"),
                        (IMP)IDValidAutoscrollCancel, "v@:");
        objc_registerClassPair(wrongABIClass);
    });
    Protocol *protocol = NSProtocolFromString(@"UITextAutoscrolling");
    XCTAssertFalse(class_conformsToProtocol(wrongABIClass, protocol));
    XCTAssertThrowsSpecificNamed(
        [IDPrivateUIKit installTextAutoscrollingSupportOnClass:wrongABIClass],
        NSException, NSInternalInconsistencyException);
    XCTAssertFalse(class_conformsToProtocol(wrongABIClass, protocol));
}

- (void)testUITextSelectionGuardedVisualRangeFallbackUsesPublicDocumentOperations {
    IDVisualSelectionFallbackDocument *document =
        [[IDVisualSelectionFallbackDocument alloc]
            initWithFrame:CGRectMake(0, 0, 280, 120)];
    document.text = @"abcdef";
    [document layoutIfNeeded];
    UITextPosition *selectionStart = [document positionFromPosition:
        document.beginningOfDocument offset:2];
    UITextPosition *selectionEnd = [document positionFromPosition:
        document.beginningOfDocument offset:4];
    document.selectedTextRange = [document textRangeFromPosition:selectionStart
                                                       toPosition:selectionEnd];
    NSRange originalSelection = [document id_NSRangeForTextRange:
        document.selectedTextRange];

    Class selectionClass = NSClassFromString(@"UITextSelection");
    XCTAssertNotNil(selectionClass);
    id selection = ((id (*)(id, SEL, id))objc_msgSend)(
        [selectionClass alloc], NSSelectorFromString(@"initWithDocument:"), document);
    XCTAssertNotNil(selection);
    SEL fallbackSelector = NSSelectorFromString(
        @"_boundedOrInvertedSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    XCTAssertTrue([selection respondsToSelector:fallbackSelector]);

    IDVisualSelectionFallbackCandidateCallCount = 0;
    NSArray<NSDictionary<NSString *, NSNumber *> *> *rows = @[
        @{ @"anchor": @1, @"extent": @4,
           @"direction": @(UITextStorageDirectionForward) },
        @{ @"anchor": @4, @"extent": @1,
           @"direction": @(UITextStorageDirectionBackward) },
    ];
    for (NSDictionary<NSString *, NSNumber *> *row in rows) {
        UITextPosition *anchor = [document positionFromPosition:
            document.beginningOfDocument offset:row[@"anchor"].integerValue];
        UITextPosition *extent = [document positionFromPosition:
            document.beginningOfDocument offset:row[@"extent"].integerValue];
        CGRect caret = [document caretRectForPosition:extent];
        CGPoint point = CGPointMake(CGRectGetMidX(caret), CGRectGetMidY(caret));
        UITextRange *result = nil;
        XCTAssertNoThrow(result = ((id (*)(id, SEL, id, CGPoint, id, NSInteger))
            objc_msgSend)(selection, fallbackSelector, extent, point, anchor,
                          row[@"direction"].integerValue));
        XCTAssertNotNil(result);
        XCTAssertTrue(NSEqualRanges([document id_NSRangeForTextRange:result],
                                    NSMakeRange(1, 3)), @"row=%@", row);
        XCTAssertTrue(NSEqualRanges([document id_NSRangeForTextRange:
            document.selectedTextRange], originalSelection));
    }
    XCTAssertEqual(IDVisualSelectionFallbackCandidateCallCount, 0U);
}

- (void)testRichInputFactoryRejectsWrongButPresentInitializerABIBeforeTypedSend {
    IDWrongInputInitializerCallCount = 0;
    NSException *caught = nil;

    @try {
        (void)IDPrivateNewInputControllerWithRichLayoutControllerUsingClass(
            [NSObject new],
            [NSObject new],
            IDWrongRichInputInitializerABI.class);
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Rich input-controller initializer ABI preflight"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:@"initWithTextLayoutController:"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:@"ABI mismatch"], @"%@", caught.reason);
    XCTAssertEqual(IDWrongInputInitializerCallCount, 0U);
}

- (void)testRichInputFactoryRejectsWrongButPresentDelegateSetterABIBeforeAllocation {
    IDWrongInputDelegateSetterCallCount = 0;
    NSException *caught = nil;

    @try {
        (void)IDPrivateNewInputControllerWithRichLayoutControllerUsingClass(
            [NSObject new],
            [NSObject new],
            IDWrongRichInputDelegateABI.class);
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Rich input-controller delegate ABI preflight"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:@"setDelegate:"], @"%@", caught.reason);
    XCTAssertTrue([caught.reason containsString:@"ABI mismatch"], @"%@", caught.reason);
    XCTAssertEqual(IDWrongInputDelegateSetterCallCount, 0U);
}

- (void)testConstructionInvokesBackwardDeletePreflightWithoutMutationSelectionOrUndo {
    IDPreflightProbeTextView *view =
        [[IDPreflightProbeTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];

    XCTAssertEqual(view.inputControllerPreflightCount, 1U);
    XCTAssertEqualObjects(view.text, @"");
    XCTAssertTrue(NSEqualRanges([view id_NSRangeForTextRange:view.selectedTextRange],
                                NSMakeRange(0, 0)));
    XCTAssertFalse(view.undoManager.canUndo);
    XCTAssertFalse(view.undoManager.canRedo);
}

- (void)testBackwardDeleteConstructionPreflightValidatesAggregateWithoutCallingUnionRange {
    IDBackwardDeleteAggregateProbe *aggregate = [IDBackwardDeleteAggregateProbe new];
    IDBackwardDeleteControllerProbe *controller = [IDBackwardDeleteControllerProbe new];
    controller.rangesResult = aggregate;

    XCTAssertNoThrow(IDPrivateInputPreflightBackwardDeleteRanges(controller));
    XCTAssertEqual(controller.rangesQueryCount, 1U);
    XCTAssertEqual(aggregate.unionRangeCallCount, 0U);
}

- (void)testBackwardDeleteConstructionPreflightThrowsReadableInternalExceptionForInvalidAggregate {
    IDBackwardDeleteControllerProbe *controller = [IDBackwardDeleteControllerProbe new];
    controller.rangesResult = [NSObject new];
    NSException *caught = nil;

    @try {
        IDPrivateInputPreflightBackwardDeleteRanges(controller);
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Backward-delete ranges construction preflight"]);
    XCTAssertTrue([caught.reason containsString:@"unionRange"]);
    XCTAssertTrue([caught.reason containsString:IDPrivateUIKit.compatibilityReport]);
}

- (void)testBackwardDeleteConstructionPreflightRejectsNilAggregate {
    IDBackwardDeleteControllerProbe *controller = [IDBackwardDeleteControllerProbe new];
    NSException *caught = nil;

    @try {
        IDPrivateInputPreflightBackwardDeleteRanges(controller);
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Backward-delete ranges construction preflight"]);
    XCTAssertTrue([caught.reason containsString:@"<nil>"]);
    XCTAssertTrue([caught.reason containsString:@"unionRange"]);
}

- (void)testNilObjectValidationThrowsWithStageAndCompatibilityReport {
    NSString *stage = @"Synthetic private controller creation";

    @try {
        [IDPrivateUIKit requireObject:nil stage:stage];
        XCTFail(@"Expected nil private object validation to throw");
    } @catch (NSException *exception) {
        XCTAssertEqualObjects(exception.name, NSInternalInconsistencyException);
        XCTAssertTrue([exception.reason containsString:stage], @"%@", exception.reason);
        XCTAssertTrue([exception.reason containsString:IDPrivateUIKit.compatibilityReport],
                      @"%@",
                      exception.reason);
    }
}

- (void)testRuntimeGeometryAndCommandABIsMatchControllerContracts {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    view.text = @"geometry";
    [view layoutIfNeeded];

    CGRect caret = IDPrivateRectObject(view.id_inputController,
                                       @selector(caretRectForPosition:),
                                       view.beginningOfDocument);
    XCTAssertFalse(CGRectIsNull(caret));
    XCTAssertTrue(isfinite(caret.origin.x));
    XCTAssertTrue(isfinite(caret.origin.y));
    XCTAssertTrue(IDPrivateRespondsToSelector(view.id_inputController, @selector(copy:)));
    XCTAssertTrue(IDPrivateRespondsToSelector(view.id_inputController, @selector(cut:)));
    XCTAssertTrue(IDPrivateRespondsToSelector(view.id_inputController, @selector(paste:)));
    XCTAssertTrue(IDPrivateRespondsToSelector(view.id_inputController,
                                              @selector(selectionAffinity)));
    XCTAssertTrue([view conformsToProtocol:@protocol(UITextPasteConfigurationSupporting)]);
    XCTAssertTrue(IDPrivateRespondsToSelector(view, NSSelectorFromString(@"_inputController")));
    XCTAssertTrue(IDPrivateRespondsToSelector(
        view,
        NSSelectorFromString(@"_implicitPasteConfigurationClasses")));
    XCTAssertEqual(IDPrivateTextContainerTextView(view.id_textContainer),
                   view.id_canvasView);
    XCTAssertEqual(IDPrivateInputUndoManager(view.id_inputController), view.undoManager);

    UITextPosition *copyEnd = [view positionFromPosition:view.beginningOfDocument offset:4];
    view.selectedTextRange = [view textRangeFromPosition:view.beginningOfDocument
                                              toPosition:copyEnd];
    IDPrivateInputCopy(view.id_inputController, nil);
    XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, @"geom");

    IDPrivateInteractionSelectAll(view.id_interactionAssistant, nil);
    XCTAssertEqualObjects([view textInRange:view.selectedTextRange], @"geometry");
    UIPasteboard.generalPasteboard.items = @[];
}

- (void)testPrivateContainerHostRejectsReplacementInEveryBuildConfiguration {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    NSTextContainer *replacement = [NSTextContainer new];

    XCTAssertThrowsSpecificNamed([view setTextContainer:replacement],
                                 NSException,
                                 NSInternalInconsistencyException);
    XCTAssertEqual(IDPrivateTextContainerTextView(view.id_textContainer),
                   view.id_canvasView);
}

- (void)testCanvasTextColorAllowsNilTransientButRejectsIncompatibleNonnullContext {
    XCTAssertEqualObjects(IDPrivateCanvasTextColor(nil), UIColor.labelColor);
    XCTAssertThrowsSpecificNamed(IDPrivateCanvasTextColor([NSObject new]),
                                 NSException,
                                 NSInternalInconsistencyException);
}

- (void)testLayoutEngineHostAllowsNilTransientButRejectsIncompatibleNonnullObject {
    XCTAssertNoThrow(IDPrivateCanvasSetHostsLayoutEngine((UIView *)nil, YES));
    XCTAssertThrowsSpecificNamed(
        IDPrivateCanvasSetHostsLayoutEngine((UIView *)[NSObject new], YES),
        NSException,
        NSInternalInconsistencyException);
}

- (void)testCanvasBridgeRegistersExactCanvasForTextContainer {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 240, 120)];
    UIView *probe = [UIView new];
    XCTAssertNoThrow(IDPrivateRegisterTextLayoutCanvas(view.id_layoutController,
                                                        view.id_textContainer,
                                                        probe));
    XCTAssertEqual(IDPrivateRegisteredTextLayoutCanvas(view.id_layoutController,
                                                        view.id_textContainer),
                   probe);
}

- (void)testCanvasRegistrationRejectsAnUnmappedObjectWithReadableStage {
    NSException *caught = nil;
    @try {
        IDPrivateRegisterTextLayoutCanvas([NSObject new], [NSTextContainer new], [UIView new]);
    } @catch (NSException *exception) {
        caught = exception;
    }
    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:
        @"Canvas map at _UITextKit2LayoutController._textCanvasViews"]);
    XCTAssertTrue([caught.reason containsString:IDPrivateUIKit.compatibilityReport]);
}

- (void)testContinuousSpellCheckingBridgeUsesRecoveredBoolABI {
    IDBoolSetterProbe *probe = [IDBoolSetterProbe new];
    IDPrivateSetContinuousSpellCheckingEnabled(probe, YES);
    XCTAssertTrue(probe.continuousSpellCheckingEnabled);
    XCTAssertTrue(IDPrivateContinuousSpellCheckingEnabled(probe));
    IDPrivateSetContinuousSpellCheckingEnabled(probe, NO);
    XCTAssertFalse(probe.continuousSpellCheckingEnabled);
    XCTAssertFalse(IDPrivateContinuousSpellCheckingEnabled(probe));
}

- (void)testSuppressedDelegateNotificationBridgeRejectsWrongButPresentBlockABI {
    IDWrongSuppressedNotificationABICallCount = 0;
    NSException *caught = nil;
    @try {
        IDPrivateInputPerformWhileSuppressingDelegateNotifications(
            [IDWrongSuppressedNotificationABIProbe new], ^{});
    } @catch (NSException *exception) {
        caught = exception;
    }
    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:
        @"_performWhileSuppressingDelegateNotifications:"], @"%@", caught.reason);
    XCTAssertEqual(IDWrongSuppressedNotificationABICallCount, 0U);
}

- (void)testObjectRangeBridgeRejectsWrongButPresentReturnABIBeforeDispatch {
    IDWrongObjectRangeABICallCount = 0;
    NSException *caught = nil;
    @try {
        IDPrivateVoidObjectRange(
            [IDWrongObjectRangeABIProbe new],
            @selector(setAttributedMarkedText:selectedRange:),
            [[NSAttributedString alloc] initWithString:@"prediction"],
            NSMakeRange(0, 0));
    } @catch (NSException *exception) {
        caught = exception;
    }
    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:
        @"setAttributedMarkedText:selectedRange:"], @"%@", caught.reason);
    XCTAssertEqual(IDWrongObjectRangeABICallCount, 0U);
}

- (void)testInputTextTraitsBridgeRejectsMissingAndWrongGetterABIBeforeDispatch {
    NSException *missing = nil;
    @try {
        IDPrivateInputTextInputTraits([NSObject new]);
    } @catch (NSException *exception) {
        missing = exception;
    }
    XCTAssertEqualObjects(missing.name, NSInternalInconsistencyException);
    XCTAssertTrue([missing.reason containsString:@"_textInputTraits"],
                  @"%@",
                  missing.reason);

    IDWrongTextInputTraitsGetterCallCount = 0;
    NSException *wrong = nil;
    @try {
        IDPrivateInputTextInputTraits(
            [IDWrongTextInputTraitsGetterABIProbe new]);
    } @catch (NSException *exception) {
        wrong = exception;
    }
    XCTAssertEqualObjects(wrong.name, NSInternalInconsistencyException);
    XCTAssertTrue([wrong.reason containsString:@"_textInputTraits"],
                  @"%@",
                  wrong.reason);
    XCTAssertEqual(IDWrongTextInputTraitsGetterCallCount, 0U);
}

- (void)testInputTextTraitsSynchronizationRejectsWrongSetterABIBeforeDispatch {
    static Class wrongTraitsClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class traitsClass = NSClassFromString(@"UITextInputTraits");
        wrongTraitsClass = objc_allocateClassPair(
            traitsClass, "IDWrongTextInputTraitsSetterABIProbe", 0);
        class_addMethod(
            wrongTraitsClass,
            @selector(setAutocorrectionType:),
            (IMP)IDWrongTextInputTraitsSetter,
            "q@:q");
        objc_registerClassPair(wrongTraitsClass);
    });

    IDTextInputTraitsControllerProbe *controller =
        [IDTextInputTraitsControllerProbe new];
    controller.traits = [wrongTraitsClass new];
    IDBlockTextView *source = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:@[[[NSAttributedString alloc] initWithString:@""]]];

    IDWrongTextInputTraitsSetterCallCount = 0;
    NSException *caught = nil;
    @try {
        IDPrivateSynchronizeTextInputTraits(controller, source);
    } @catch (NSException *exception) {
        caught = exception;
    }
    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"setAutocorrectionType:"],
                  @"%@",
                  caught.reason);
    XCTAssertEqual(IDWrongTextInputTraitsSetterCallCount, 0U);
}

- (void)testInputLayoutManagerDetachBridgeUsesInventoriedHopperVoidZeroABI {
    NSString *testPath = [NSString stringWithUTF8String:__FILE__];
    NSString *root = [[testPath stringByDeletingLastPathComponent]
        stringByDeletingLastPathComponent];
    NSString *inventoryPath = IDEngineSourceFile(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    NSDictionary *inventory = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfFile:inventoryPath] options:0 error:nil];
    NSPredicate *detach = [NSPredicate predicateWithBlock:
        ^BOOL(NSDictionary *member, NSDictionary *bindings) {
            (void)bindings;
            return [member[@"identifier"]
                isEqualToString:@"inputController.detach"] &&
                [member[@"name"]
                    isEqualToString:@"_detachFromLayoutManager"] &&
                [member[@"returnType"] isEqualToString:@"v"] &&
                [member[@"argumentTypes"] count] == 0 &&
                [member[@"required"] boolValue];
        }];
    NSArray *members =
        inventory[@"capabilities"][@"inputController"][@"members"];
    XCTAssertEqual([members filteredArrayUsingPredicate:detach].count, 1U);

    SEL selector = NSSelectorFromString(@"_detachFromLayoutManager");
    Method method = class_getInstanceMethod(NSClassFromString(@"UITextInputController"),
                                            selector);
    XCTAssertNotEqual(method, NULL);
    NSMethodSignature *signature = method == NULL
        ? nil
        : [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    XCTAssertEqual(strcmp(signature.methodReturnType, @encode(void)), 0);
    XCTAssertEqual(signature.numberOfArguments, 2U);

    IDInputLayoutManagerDetachProbe *probe = [IDInputLayoutManagerDetachProbe new];
    IDPrivateInputDetachFromLayoutManager(probe);
    XCTAssertEqual(probe.detachCallCount, 1U);
}

- (void)testThrowingInteractionAssistantInitializerCleansPartiallyAdoptedHostState {
    [IDThrowingInteractionAssistant resetProbe];
    UIView *hostView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    NSException *caught = nil;

    @try {
        [IDPrivateUIKit newInteractionAssistantWithView:hostView
                                        assistantClass:IDThrowingInteractionAssistant.class];
        XCTFail(@"Expected the synthetic interaction assistant initializer to throw");
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Interaction assistant initialization"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:IDThrowingInteractionAssistantCause.name],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:IDThrowingInteractionAssistantCause.reason],
                  @"%@",
                  caught.reason);
    XCTAssertEqual(caught.userInfo[@"IDPrivateUIKitUnderlyingException"],
                   IDThrowingInteractionAssistantCause);
    XCTAssertEqual(IDThrowingInteractionAssistantClearCount, 1U);
    XCTAssertEqual(hostView.gestureRecognizers.count, 0U);
    XCTAssertNil([hostView viewWithTag:IDThrowingInteractionAssistantTransientTag]);
}

- (void)testInteractionAssistantPostInitPreflightFailureCleansAdoptedHostState {
    [IDPreflightFailingInteractionAssistant prepareForPostInitPreflightFailure];
    UIView *hostView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    NSException *caught = nil;

    @try {
        [IDPrivateUIKit newInteractionAssistantWithView:hostView
                                        assistantClass:IDPreflightFailingInteractionAssistant.class];
        XCTFail(@"Expected interaction assistant post-init preflight to throw");
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Interaction assistant initialization"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:@"Interaction assistant construction preflight"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:@"selectionChanged is missing"],
                  @"%@",
                  caught.reason);
    XCTAssertEqual(IDThrowingInteractionAssistantClearCount, 1U);
    XCTAssertEqual(hostView.gestureRecognizers.count, 0U);
    XCTAssertNil([hostView viewWithTag:IDThrowingInteractionAssistantTransientTag]);
}

@end
