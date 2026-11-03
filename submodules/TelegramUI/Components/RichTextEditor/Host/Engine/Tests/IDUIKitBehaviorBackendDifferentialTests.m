#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDNativeSelectionPresentationBackend.h"
#import "IDPrivateUIKit.h"
#import "IDVerticalAutoscroll.h"
#import "IDUIKitBehaviorBackend.h"
#import "IDUIKitBehaviorKernel.h"
#import "IDUIKitCapabilityResolver.h"

static IDUIKitBehaviorCapabilities IDBackendTestRequestedCapabilities(void) {
    return IDUIKitBehaviorCapabilityInputController |
        IDUIKitBehaviorCapabilityIncomingCallbacks |
        IDUIKitBehaviorCapabilityTypingAttributes |
        IDUIKitBehaviorCapabilityInteraction |
        IDUIKitBehaviorCapabilityFloatingCursor |
        IDUIKitBehaviorCapabilityAutoscroll |
        IDUIKitBehaviorCapabilityChecking |
        IDUIKitBehaviorCapabilityPrediction |
        IDUIKitBehaviorCapabilityPaste |
        IDUIKitBehaviorCapabilityDictation;
}

@interface IDBackendWrongABIProbe : NSObject
- (NSInteger)id_wrongABI;
@end

// RETIRED (2026-09-15), and it is the one retirement caused by a real BEHAVIOURAL difference rather
// than by layout. It asserts that an optional capability with no runtime support is REJECTED, using
// `autoscrollEntry` — whose rejection upstream comes from a `referenceOnly` contract row. The
// vendored kernel empties `referenceOnly` on the way in (`Vendor/VENDOR.md`, "Manifest transforms":
// 53 rows dropped), so here that capability is accepted and the report reads
// `IDUIKitCapabilityStateUnavailable` where upstream reads `…RejectedContract`. Verified rather than
// assumed: `autoscrollEntry` appears in the pristine manifest's `referenceOnly`, and the shipped
// contract data contains the string `referenceOnly` zero times.
//
// The transform was recorded as ABI-preserving, which it is; this is its behavioural consequence,
// and it is now recorded in VENDOR.md as well. Restoring the test means restoring those rows, which
// is a decision about the kernel, not about its tests.

@implementation IDBackendWrongABIProbe
- (NSInteger)id_wrongABI { return 0; }
@end

@interface IDBackendDictationPhrase : UIDictationPhrase
@property(nonatomic, copy) NSString *id_text;
@end
@implementation IDBackendDictationPhrase
- (NSString *)text { return self.id_text; }
@end

@interface IDBackendMaskingLookup : NSObject <IDUIKitRuntimeLookingUp>
@property(nonatomic, copy) NSSet<NSString *> *hiddenClasses;
@property(nonatomic, copy) NSSet<NSString *> *hiddenProtocols;
@property(nonatomic, copy) NSSet<NSString *> *hiddenInstanceMethods;
@property(nonatomic, copy) NSSet<NSString *> *wrongABIInstanceMethods;
@property(nonatomic, strong) NSMutableSet<NSString *> *lookedUpClasses;
@property(nonatomic, strong) NSMutableSet<NSString *> *lookedUpProtocols;
@end

@implementation IDBackendMaskingLookup

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _hiddenClasses = [NSSet set];
        _hiddenProtocols = [NSSet set];
        _hiddenInstanceMethods = [NSSet set];
        _wrongABIInstanceMethods = [NSSet set];
        _lookedUpClasses = [NSMutableSet set];
        _lookedUpProtocols = [NSMutableSet set];
    }
    return self;
}

- (Class)classNamed:(NSString *)name {
    [self.lookedUpClasses addObject:name];
    return [self.hiddenClasses containsObject:name]
        ? Nil
        : NSClassFromString(name);
}

- (Protocol *)protocolNamed:(NSString *)name {
    [self.lookedUpProtocols addObject:name];
    return [self.hiddenProtocols containsObject:name]
        ? nil
        : NSProtocolFromString(name);
}

- (Method)instanceMethodForClass:(Class)cls selector:(SEL)selector {
    NSString *key = [NSString stringWithFormat:@"%@|%@",
        NSStringFromClass(cls), NSStringFromSelector(selector)];
    if ([self.hiddenInstanceMethods containsObject:key]) return NULL;
    if ([self.wrongABIInstanceMethods containsObject:key]) {
        return class_getInstanceMethod(
            IDBackendWrongABIProbe.class, @selector(id_wrongABI));
    }
    return class_getInstanceMethod(cls, selector);
}

- (Method)classMethodForClass:(Class)cls selector:(SEL)selector {
    return class_getClassMethod(cls, selector);
}

- (Ivar)instanceVariableForClass:(Class)cls name:(NSString *)name {
    return class_getInstanceVariable(cls, name.UTF8String);
}

@end

static NSUInteger IDReferenceCompatibilityGateCount;

@interface IDGateRecordingBlockTextView : IDBlockTextView
@end

@implementation IDGateRecordingBlockTextView

+ (void)id_requireReferenceCompatibleRuntime {
    IDReferenceCompatibilityGateCount += 1;
    [IDPrivateUIKit requireCompatibleRuntime];
}

@end

@interface IDUIKitBehaviorBackendDifferentialTests : XCTestCase
@end

@interface IDBlockTextView (IDAutoscrollBackendTestInspection)
- (void)startAutoscroll:(CGPoint)point;
- (void)cancelAutoscroll;
- (void)didMoveToWindow;
@end

@implementation IDUIKitBehaviorBackendDifferentialTests

- (NSArray<NSAttributedString *> *)blocks {
    return @[
        [[NSAttributedString alloc] initWithString:@"one"],
        [[NSAttributedString alloc] initWithString:@"two"],
    ];
}

- (IDBlockTextView *)minimalViewWithLookup:(IDBackendMaskingLookup *)lookup {
    IDUIKitCapabilityResolver *resolver =
        [[IDUIKitCapabilityResolver alloc] initWithLookup:lookup];
    return [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 260, 140)
        attributedBlocks:self.blocks
        behaviorBackend:IDUIKitBehaviorBackendMinimalKernel
        resolver:resolver
        requestedCapabilities:IDBackendTestRequestedCapabilities()
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                return [[IDNativeSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
            }];
}

- (IDUIKitCapabilityReport *)reportNamed:(NSString *)identifier
                                    view:(IDBlockTextView *)view {
    for (IDUIKitCapabilityReport *report
         in view.id_behaviorReport.capabilities) {
        if ([report.identifier isEqualToString:identifier]) {
            return report;
        }
    }
    return nil;
}

- (void)assertBasicEditingFallback:(IDBlockTextView *)view
                        capability:(NSString *)capability {
    XCTAssertNotNil(view, @"%@", capability);
    UITextPosition *end = view.endOfDocument;
    view.selectedTextRange =
        [view textRangeFromPosition:end toPosition:end];
    [view insertText:@"X"];
    XCTAssertEqualObjects(view.text, @"one\ntwoX", @"%@", capability);
    [view deleteBackward];
    XCTAssertEqualObjects(view.text, @"one\ntwo", @"%@", capability);
    XCTAssertNotNil(view.id_selectionPresentationBackend, @"%@",
                    capability);
}

- (void)assertSpecificFallback:(IDBlockTextView *)view
                    capability:(NSString *)capability {
    if ([capability isEqualToString:@"interaction"]) {
        XCTAssertNil(view.id_interactionCapability);
    } else if ([capability isEqualToString:@"floatingCursor"]) {
        XCTAssertNotNil(view.id_interactionCapability);
        XCTAssertNoThrow([view.id_interactionCapability
            beginFloatingCursorAtPoint:CGPointMake(12, 12)]);
        XCTAssertNoThrow([view.id_interactionCapability
            updateFloatingCursorAtPoint:CGPointMake(16, 12)
                               animated:NO]);
        XCTAssertNoThrow([view.id_interactionCapability endFloatingCursor]);
    } else if ([capability isEqualToString:@"autoscrollEntry"]) {
        XCTAssertNotNil(view.id_interactionCapability);
        XCTAssertNil(view.id_behaviorKernel.autoscrollEntry);
        XCTAssertNil(view.id_textAutoscroll);
    } else if ([capability isEqualToString:@"checking"]) {
        [view.id_behaviorInput id_setContinuousSpellCheckingEnabled:YES];
        XCTAssertFalse(
            view.id_behaviorInput.id_isContinuousSpellCheckingEnabled);
    } else if ([capability isEqualToString:@"typingAttributes"]) {
        view.id_behaviorInput.typingAttributes = @{
            NSForegroundColorAttributeName: UIColor.redColor,
        };
        XCTAssertEqualObjects(view.id_behaviorInput.typingAttributes, @{});
        XCTAssertNil(view.id_behaviorInput.id_textInputTraits);
    } else if ([capability isEqualToString:@"prediction"]) {
        NSAttributedString *marked = [[NSAttributedString alloc]
            initWithString:@"Q"
                attributes:@{NSForegroundColorAttributeName:
                                 UIColor.redColor}];
        [view.id_behaviorInput setAttributedMarkedText:marked
                                        selectedRange:NSMakeRange(1, 0)];
        XCTAssertNotNil(view.markedTextRange);
        XCTAssertTrue([view.text hasSuffix:@"Q"]);
        [view unmarkText];
    } else if ([capability isEqualToString:@"paste"]) {
        UIPasteboard.generalPasteboard.string = @"P";
        XCTAssertTrue([view.id_behaviorInput
            shouldHandlePasteAction:@selector(paste:)
                             sender:nil]);
        XCTAssertFalse([view.id_behaviorInput
            shouldHandlePasteAction:@selector(cut:)
                             sender:nil]);
        [view.id_behaviorInput performPaste:nil];
        XCTAssertTrue([view.text hasSuffix:@"P"]);
        UIPasteboard.generalPasteboard.items = @[];
    } else if ([capability isEqualToString:@"dictation"]) {
        IDBackendDictationPhrase *first =
            [IDBackendDictationPhrase new];
        first.id_text = @"hello ";
        IDBackendDictationPhrase *second =
            [IDBackendDictationPhrase new];
        second.id_text = @"world";
        [view insertDictationResult:@[first, second]];
        XCTAssertTrue([view.text hasSuffix:@"hello world"]);
    }
}

- (void)testPublicInitializerSelectsReferenceBackend {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 260, 140)
        attributedBlocks:self.blocks];

    XCTAssertEqual(view.id_behaviorBackend,
                   IDUIKitBehaviorBackendReference);
    XCTAssertNil(view.id_behaviorKernel);
    XCTAssertNotNil(view.id_behaviorInput);
}

- (void)testReferenceBackendInvokesGlobalCompatibilityGate {
    IDReferenceCompatibilityGateCount = 0;
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    IDUIKitCapabilityResolver *resolver =
        [[IDUIKitCapabilityResolver alloc] initWithLookup:lookup];

    IDBlockTextView *view = [[IDGateRecordingBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 260, 140)
        attributedBlocks:self.blocks
        behaviorBackend:IDUIKitBehaviorBackendReference
        resolver:resolver
        requestedCapabilities:IDBackendTestRequestedCapabilities()
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                return [[IDNativeSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
            }];

    XCTAssertNotNil(view);
    XCTAssertEqual(IDReferenceCompatibilityGateCount, 1U);
    XCTAssertEqual(lookup.lookedUpClasses.count, 0U,
                   @"Reference mode must remain controlled by the global gate");
}

- (void)testMinimalConstructsRichControllerAndKernelWithoutGlobalGate {
    IDReferenceCompatibilityGateCount = 0;
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    IDUIKitCapabilityResolver *resolver =
        [[IDUIKitCapabilityResolver alloc] initWithLookup:lookup];

    IDBlockTextView *view = [[IDGateRecordingBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 260, 140)
        attributedBlocks:self.blocks
        behaviorBackend:IDUIKitBehaviorBackendMinimalKernel
        resolver:resolver
        requestedCapabilities:IDBackendTestRequestedCapabilities()
        selectionPresentationBackendFactory:
            ^id<IDSelectionPresentationBackend>(IDBlockTextView *hostView) {
                return [[IDNativeSelectionPresentationBackend alloc]
                    initWithHostView:hostView];
            }];

    XCTAssertNotNil(view.id_richLayoutController);
    XCTAssertNotNil(view.id_behaviorKernel);
    XCTAssertEqual(view.id_behaviorInput,
                   view.id_behaviorKernel.inputController);
    XCTAssertEqual(IDReferenceCompatibilityGateCount, 0U);
    NSMutableDictionary<NSString *, NSNumber *> *states =
        [NSMutableDictionary dictionary];
    for (IDUIKitCapabilityReport *report
             in view.id_behaviorReport.capabilities) {
        states[report.identifier] = @(report.state);
    }
    XCTAssertEqualObjects(states[@"inputController"],
                          @(IDUIKitCapabilityStateActive));
    XCTAssertEqualObjects(states[@"incomingCallbacks"],
                          @(IDUIKitCapabilityStateActive));
    XCTAssertEqualObjects(states[@"typingAttributes"],
                          @(IDUIKitCapabilityStateActive));
    XCTAssertEqualObjects(states[@"interaction"],
                          @(IDUIKitCapabilityStateActive));
    XCTAssertEqualObjects(states[@"floatingCursor"],
                          @(IDUIKitCapabilityStateActive));
}

- (void)testReferenceAutoscrollLazilyConstructsUIKitEngine {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 260, 140)
        attributedBlocks:self.blocks];
    view.contentSize = CGSizeMake(260, 560);
    [view startAutoscroll:CGPointMake(100, 170)];

    XCTAssertNotNil(view.id_textAutoscroll);
    XCTAssertEqualObjects(
        NSStringFromClass([view.id_textAutoscroll class]),
        @"UIAutoscroll");
    XCTAssertNil(view.id_verticalAutoscroll);
    XCTAssertEqualObjects(
        IDPrivateCopyTextAutoscrollTraceForUITesting(view)[@"engine"],
        @"uikit");
    [view cancelAutoscroll];
}

- (void)testReferenceAutoscrollConstructsUIKitEngineBeforeRejectingInsidePoint {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 260, 140)
        attributedBlocks:self.blocks];
    view.contentSize = CGSizeMake(260, 560);

    [view startAutoscroll:CGPointMake(100, 50)];

    XCTAssertNotNil(view.id_textAutoscroll);
    XCTAssertEqualObjects(
        NSStringFromClass([view.id_textAutoscroll class]),
        @"UIAutoscroll");
    XCTAssertNil(view.id_verticalAutoscroll);
    XCTAssertEqualObjects(
        IDPrivateCopyTextAutoscrollTraceForUITesting(view)[@"directions"],
        @0);
}

- (void)testMinimalAutoscrollUsesCleanEngineWithoutResolvingUIKitEngine {
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    lookup.hiddenClasses = [NSSet setWithObject:@"UIAutoscroll"];
    IDBlockTextView *view = [self minimalViewWithLookup:lookup];
    view.contentSize = CGSizeMake(260, 560);
    [view startAutoscroll:CGPointMake(100, 170)];

    XCTAssertNil(view.id_textAutoscroll);
    XCTAssertTrue([view.id_verticalAutoscroll
        isKindOfClass:IDVerticalAutoscroll.class]);
    XCTAssertTrue(view.id_verticalAutoscroll.isActive);
    XCTAssertFalse([lookup.lookedUpClasses containsObject:@"UIAutoscroll"]);
    NSDictionary *trace =
        IDPrivateCopyTextAutoscrollTraceForUITesting(view);
    XCTAssertEqualObjects(trace[@"engine"], @"project");
    XCTAssertEqualObjects(trace[@"directions"],
                          @(IDVerticalAutoscrollDirectionDown));

    [view cancelAutoscroll];
    [view cancelAutoscroll];
    XCTAssertFalse(view.id_verticalAutoscroll.isActive);
    XCTAssertEqualObjects(
        IDPrivateCopyTextAutoscrollTraceForUITesting(view)[@"cancelCount"],
        @2);
}

- (void)testMinimalAutoscrollUsesPublicSafeBandAndStopsAtBoundary {
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    IDBlockTextView *view = [self minimalViewWithLookup:lookup];
    view.frame = CGRectMake(0, 0, 260, 140);
    view.contentInset = UIEdgeInsetsMake(11, 0, 13, 0);
    view.textContainerInset = UIEdgeInsetsMake(7, 5, 9, 5);
    view.contentSize = CGSizeMake(260, 560);
    view.contentOffset =
        CGPointMake(0, -view.adjustedContentInset.top);

    [view startAutoscroll:CGPointMake(100, 50)];
    NSDictionary *inside =
        IDPrivateCopyTextAutoscrollTraceForUITesting(view);
    XCTAssertNil(view.id_verticalAutoscroll);
    XCTAssertEqualObjects(inside[@"directions"], @0);
    XCTAssertEqualObjects(inside[@"engine"], @"project");

    [view startAutoscroll:CGPointMake(100, 170)];
    NSDictionary *outside =
        IDPrivateCopyTextAutoscrollTraceForUITesting(view);
    NSDictionary *safe = outside[@"safe"];
    XCTAssertEqualWithAccuracy(
        [safe[@"y"] doubleValue],
        CGRectGetMinY(view.bounds) +
            view.adjustedContentInset.top +
            view.textContainerInset.top + 8.0,
        0.001);
    XCTAssertEqualWithAccuracy(
        [safe[@"height"] doubleValue],
        CGRectGetHeight(view.bounds) -
            view.adjustedContentInset.top -
            view.adjustedContentInset.bottom -
            view.textContainerInset.top -
            view.textContainerInset.bottom - 16.0,
        0.001);
    XCTAssertTrue(view.id_verticalAutoscroll.isActive);

    [view cancelAutoscroll];
    view.contentOffset = CGPointMake(
        0, view.contentSize.height - CGRectGetHeight(view.bounds) +
               view.adjustedContentInset.bottom);
    [view startAutoscroll:
        CGPointMake(100, CGRectGetMaxY(view.bounds) + 20)];
    XCTAssertFalse(view.id_verticalAutoscroll.isActive);
    XCTAssertEqualObjects(
        IDPrivateCopyTextAutoscrollTraceForUITesting(view)[@"directions"],
        @0);
    XCTAssertNotNil(view.id_document);
    XCTAssertNotNil(view.id_richLayoutController);
    XCTAssertNotNil(view.id_behaviorInput);
    XCTAssertNotNil(view.id_interactionCapability);
    XCTAssertNotNil(view.id_selectionPresentationBackend);
}

- (void)testRejectedAutoscrollEntryClosesOnlyAutoscrollSession {
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    lookup.hiddenProtocols =
        [NSSet setWithObject:@"UITextAutoscrolling"];
    IDBlockTextView *view = [self minimalViewWithLookup:lookup];
    view.contentSize = CGSizeMake(260, 560);

    NSUInteger cancelsBefore =
        [IDPrivateCopyTextAutoscrollTraceForUITesting(
            view)[@"cancelCount"] unsignedIntegerValue];
    [view startAutoscroll:CGPointMake(100, 170)];

    XCTAssertNil(view.id_textAutoscroll);
    XCTAssertNil(view.id_verticalAutoscroll);
    XCTAssertGreaterThanOrEqual(
        [IDPrivateCopyTextAutoscrollTraceForUITesting(
            view)[@"cancelCount"] unsignedIntegerValue],
        cancelsBefore + 1);
    XCTAssertNotNil(view.id_document);
    XCTAssertNotNil(view.id_richLayoutController);
    XCTAssertNotNil(view.id_behaviorInput);
    XCTAssertNotNil(view.id_interactionCapability);
    XCTAssertNotNil(view.id_selectionPresentationBackend);
}

- (void)testMinimalAutoscrollTerminalPathsClearOnlyCleanSession {
    NSArray<NSDictionary<NSString *, id> *> *rows = @[
        @{@"name": @"cancel",
          @"action": ^(IDBlockTextView *view) {
              [view cancelAutoscroll];
          }},
        @{@"name": @"resign",
          @"action": ^(IDBlockTextView *view) {
              [view resignFirstResponder];
          }},
        @{@"name": @"windowDetach",
          @"action": ^(IDBlockTextView *view) {
              [view didMoveToWindow];
          }},
        @{@"name": @"editableOff",
          @"action": ^(IDBlockTextView *view) {
              view.editable = NO;
          }},
        @{@"name": @"selectableOff",
          @"action": ^(IDBlockTextView *view) {
              view.selectable = NO;
          }},
    ];
    for (NSDictionary<NSString *, id> *row in rows) {
        IDBlockTextView *view =
            [self minimalViewWithLookup:
                [IDBackendMaskingLookup new]];
        view.contentSize = CGSizeMake(260, 560);
        [view startAutoscroll:CGPointMake(100, 170)];
        XCTAssertTrue(view.id_verticalAutoscroll.isActive,
                      @"%@", row[@"name"]);

        void (^action)(IDBlockTextView *) = row[@"action"];
        action(view);

        XCTAssertNil(view.id_verticalAutoscroll,
                     @"%@", row[@"name"]);
        XCTAssertNil(view.id_textAutoscroll,
                     @"%@", row[@"name"]);
        XCTAssertNotNil(view.id_document, @"%@", row[@"name"]);
        XCTAssertNotNil(view.id_richLayoutController,
                        @"%@", row[@"name"]);
        XCTAssertNotNil(view.id_behaviorInput, @"%@", row[@"name"]);
        XCTAssertNotNil(view.id_selectionPresentationBackend,
                        @"%@", row[@"name"]);
        if (![row[@"name"] isEqual:@"selectableOff"]) {
            XCTAssertNotNil(view.id_interactionCapability,
                            @"%@", row[@"name"]);
        }
    }
}

- (void)testMinimalAutoscrollCancellationReturnsOffMainAndCleansUp {
    IDBlockTextView *view =
        [self minimalViewWithLookup:[IDBackendMaskingLookup new]];
    view.contentSize = CGSizeMake(260, 560);
    [view startAutoscroll:CGPointMake(100, 170)];
    XCTAssertTrue(view.id_verticalAutoscroll.isActive);

    XCTestExpectation *returned =
        [self expectationWithDescription:@"off-main cancel returned"];
    dispatch_async(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [view cancelAutoscroll];
            [returned fulfill];
        });
    [self waitForExpectations:@[returned] timeout:1.0];
    [NSRunLoop.mainRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];

    XCTAssertNil(view.id_verticalAutoscroll);
    XCTAssertNotNil(view.id_document);
    XCTAssertNotNil(view.id_behaviorInput);
    XCTAssertNotNil(view.id_selectionPresentationBackend);
}

- (void)testMinimalDoesNotResolveReferenceOnlyLayoutCanvasOrRenderingClasses {
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    lookup.hiddenClasses = [NSSet setWithArray:@[
        @"_UITextLayoutControllerBase",
        @"_UITextKit2LayoutController",
        @"IDTextLayoutCanvasView",
        @"NSTextLayoutFragment",
        @"NSTextViewportLayoutController",
        @"<canvas context>",
        @"<custom render controller>",
        @"<custom render surface>",
        @"<anchored attachment provider>",
        @"<platform rendering-surface text range>",
        @"UIKeyboardImpl",
        @"_UIKeyboardStateManager",
        @"_UITextFloatingCursorSession",
        @"_UITextSelectionLollipopView",
    ]];

    IDBlockTextView *view = [self minimalViewWithLookup:lookup];

    XCTAssertNotNil(view);
    for (NSString *className in lookup.hiddenClasses) {
        XCTAssertFalse([lookup.lookedUpClasses containsObject:className],
                       @"Minimal mode unexpectedly resolved %@", className);
    }
}



- (void)testMinimalFailsCleanlyWhenInputConstructorIsHidden {
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    lookup.hiddenInstanceMethods = [NSSet setWithObject:
        @"UITextInputController|initWithTextLayoutController:"];

    XCTAssertThrowsSpecificNamed(
        [self minimalViewWithLookup:lookup],
        NSException,
        NSInternalInconsistencyException);
}

- (void)testMinimalFailsCleanlyWhenMandatoryDelegateSetterIsHidden {
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    lookup.hiddenInstanceMethods = [NSSet setWithObject:
        @"UITextInputController|setDelegate:"];

    XCTAssertThrowsSpecificNamed(
        [self minimalViewWithLookup:lookup],
        NSException,
        NSInternalInconsistencyException);
}

- (void)testMinimalWithoutInteractionStillEditsAndChangesBlockStructure {
    IDBackendMaskingLookup *lookup = [IDBackendMaskingLookup new];
    lookup.hiddenClasses =
        [NSSet setWithObject:@"UITextInteractionAssistant"];
    IDBlockTextView *view = [self minimalViewWithLookup:lookup];
    XCTAssertNil(view.id_behaviorKernel.interaction);
    XCTAssertNil(view.id_interactionCapability);

    UITextPosition *afterOne =
        [view positionFromPosition:view.beginningOfDocument offset:3];
    view.selectedTextRange =
        [view textRangeFromPosition:afterOne toPosition:afterOne];
    [view insertText:@"X"];
    XCTAssertEqualObjects(view.text, @"oneX\ntwo");
    [view deleteBackward];
    XCTAssertEqualObjects(view.text, @"one\ntwo");

    UITextPosition *replaceStart =
        [view positionFromPosition:view.beginningOfDocument offset:1];
    UITextPosition *replaceEnd =
        [view positionFromPosition:view.beginningOfDocument offset:3];
    UITextRange *replaceRange =
        [view textRangeFromPosition:replaceStart toPosition:replaceEnd];
    [view replaceRange:replaceRange withText:@"NE"];
    XCTAssertEqualObjects(view.text, @"oNE\ntwo");

    UITextPosition *splitPosition =
        [view positionFromPosition:view.beginningOfDocument offset:2];
    view.selectedTextRange =
        [view textRangeFromPosition:splitPosition toPosition:splitPosition];
    [view insertText:@"\n"];
    XCTAssertEqual(view.attributedBlocks.count, 3U);
    XCTAssertEqualObjects(view.text, @"oN\nE\ntwo");

    UITextPosition *secondBlockStart =
        [view positionFromPosition:view.beginningOfDocument offset:3];
    view.selectedTextRange =
        [view textRangeFromPosition:secondBlockStart
                        toPosition:secondBlockStart];
    [view deleteBackward];
    XCTAssertEqual(view.attributedBlocks.count, 2U);
    XCTAssertEqualObjects(view.text, @"oNE\ntwo");
}

- (void)testMinimalLifecycleStressReleasesAllEditorGraphs {
    __weak IDBlockTextView *weakView = nil;
    __weak id weakController = nil;
    __weak id weakAssistant = nil;
    __weak id weakKernel = nil;
    __weak id weakPresentationBackend = nil;
    __weak id weakLayoutController = nil;
    for (NSUInteger state = 0; state < 5; state += 1) {
        for (NSUInteger iteration = 0; iteration < 100; iteration += 1) {
            @autoreleasepool {
                IDBlockTextView *view =
                    [self minimalViewWithLookup:
                        [IDBackendMaskingLookup new]];
                [view becomeFirstResponder];
                if (state == 1) {
                    [view setMarkedText:@"marked"
                         selectedRange:NSMakeRange(6, 0)];
                } else if (state == 2) {
                    UITextPosition *start = view.beginningOfDocument;
                    UITextPosition *end =
                        [view positionFromPosition:start offset:3];
                    view.selectedTextRange =
                        [view textRangeFromPosition:start toPosition:end];
                } else if (state == 3) {
                    [view.id_interactionCapability
                        id_setNeedsSelectionDisplayUpdate];
                    [view id_updateSelectionPresentation];
                } else if (state == 4) {
                    [view.id_interactionCapability
                        beginFloatingCursorAtPoint:CGPointMake(20, 20)];
                }
                weakView = view;
                weakController = view.id_inputController;
                weakAssistant = view.id_interactionAssistant;
                weakKernel = view.id_behaviorKernel;
                weakPresentationBackend =
                    view.id_selectionPresentationBackend;
                weakLayoutController = view.id_richLayoutController;
                [view resignFirstResponder];
                [view id_tearDownEditorGraph];
                view = nil;
            }
            XCTAssertNil(weakView, @"state=%lu iteration=%lu",
                         (unsigned long)state,
                         (unsigned long)iteration);
            XCTAssertNil(weakController, @"state=%lu iteration=%lu",
                         (unsigned long)state,
                         (unsigned long)iteration);
            XCTAssertNil(weakAssistant, @"state=%lu iteration=%lu",
                         (unsigned long)state,
                         (unsigned long)iteration);
            XCTAssertNil(weakKernel, @"state=%lu iteration=%lu",
                         (unsigned long)state,
                         (unsigned long)iteration);
            XCTAssertNil(weakPresentationBackend,
                         @"state=%lu iteration=%lu",
                         (unsigned long)state,
                         (unsigned long)iteration);
            XCTAssertNil(weakLayoutController,
                         @"state=%lu iteration=%lu",
                         (unsigned long)state,
                         (unsigned long)iteration);
        }
    }
    XCTestExpectation *drained =
        [self expectationWithDescription:@"queued callbacks drained"];
    dispatch_async(dispatch_get_main_queue(), ^{ [drained fulfill]; });
    [self waitForExpectations:@[drained] timeout:2.0];
    XCTAssertNil(weakView);
    XCTAssertNil(weakController);
    XCTAssertNil(weakAssistant);
    XCTAssertNil(weakKernel);
    XCTAssertNil(weakPresentationBackend);
    XCTAssertNil(weakLayoutController);
}

@end
