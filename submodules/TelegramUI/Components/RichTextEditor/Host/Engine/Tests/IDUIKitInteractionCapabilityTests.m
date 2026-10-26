#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "IDUIKitInteractionCapability.h"

static NSUInteger IDInteractionProbeAllocationCount;
static NSUInteger IDInteractionProbeInitializationCount;
static NSUInteger IDInteractionProbeCleanupCount;
static __weak UIView *IDInteractionProbeInitializedView;
static NSMutableArray<NSString *> *IDInteractionProbeEvents;
static CGPoint IDInteractionProbePoint;
static BOOL IDInteractionProbeAnimated;
static __weak id IDInteractionProbeSender;

@interface IDInteractionHostProbe : UIView
@end

@implementation IDInteractionHostProbe
- (id)interactionAssistant { return nil; }
- (id)customRenderController { return nil; }
- (CGPoint)_convertPointFromRenderSpace:(CGPoint)point { return point; }
- (UIView *)_textInputViewForAddingGestureRecognizers { return self; }
- (UIView *)selectionContainerView { return self; }
- (UIView *)_selectionContainerViewAboveText { return self; }
- (UIView *)_existingSelectionContainerView { return self; }
- (void)_placeSelectionContainerView {}
- (BOOL)_isInteractiveTextSelectionDisabled { return NO; }
- (void)_updateSelectionGestures {}
- (void)_textKit2CanvasDidLayout {}
- (void)_updateInteractionGeometry {}
- (BOOL)isEditing { return YES; }
- (BOOL)hasEditableSelection { return YES; }
- (id)_visualSelectionRangeForExtent:(id)extent
                            forPoint:(CGPoint)point
                        fromPosition:(id)position
                         inDirection:(NSInteger)direction {
    (void)extent;
    (void)point;
    (void)position;
    (void)direction;
    return nil;
}
@end

@interface IDInteractionAssistantProbe : NSObject
@property(nonatomic, weak) UIView *view;
+ (void)reset;
- (instancetype)initWithView:(UIView *)view;
- (void)selectionChanged;
- (void)activateSelection;
- (void)deactivateSelection;
- (void)setSelectionDisplayVisible:(BOOL)visible;
- (void)setNeedsSelectionDisplayUpdate;
- (void)setGestureRecognizers;
- (void)clearGestureRecognizers:(BOOL)forced;
- (void)resignedFirstResponder;
- (void)detach:(BOOL)forced;
- (void)selectWord;
- (void)selectAll:(id)sender;
- (void)autoscrollWillNotStart;
- (void)beginFloatingCursorAtPoint:(CGPoint)point;
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated;
- (void)endFloatingCursor;
@end

@implementation IDInteractionAssistantProbe

+ (id)allocWithZone:(struct _NSZone *)zone {
    IDInteractionProbeAllocationCount += 1;
    return [super allocWithZone:zone];
}

+ (void)reset {
    IDInteractionProbeAllocationCount = 0;
    IDInteractionProbeInitializationCount = 0;
    IDInteractionProbeCleanupCount = 0;
    IDInteractionProbeInitializedView = nil;
    IDInteractionProbeEvents = [NSMutableArray array];
    IDInteractionProbePoint = CGPointZero;
    IDInteractionProbeAnimated = NO;
    IDInteractionProbeSender = nil;
}

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if (self != nil) {
        IDInteractionProbeInitializationCount += 1;
        IDInteractionProbeInitializedView = view;
        _view = view;
    }
    return self;
}

- (void)selectionChanged {
    [IDInteractionProbeEvents addObject:@"selectionChanged"];
}
- (void)activateSelection {
    [IDInteractionProbeEvents addObject:@"activate"];
}
- (void)deactivateSelection {
    [IDInteractionProbeEvents addObject:@"deactivate"];
}
- (void)setSelectionDisplayVisible:(BOOL)visible {
    [IDInteractionProbeEvents addObject:
        visible ? @"visible:1" : @"visible:0"];
}
- (void)setNeedsSelectionDisplayUpdate {
    [IDInteractionProbeEvents addObject:@"displayUpdate"];
}
- (void)setGestureRecognizers {
    [IDInteractionProbeEvents addObject:@"recognizers:set"];
}
- (void)clearGestureRecognizers:(BOOL)forced {
    IDInteractionProbeCleanupCount += 1;
    [IDInteractionProbeEvents addObject:
        forced ? @"recognizers:clear:1" : @"recognizers:clear:0"];
    UIView *transient = [self.view viewWithTag:2607];
    [transient removeFromSuperview];
}
- (void)resignedFirstResponder {
    [IDInteractionProbeEvents addObject:@"resigned"];
}
- (void)detach:(BOOL)forced {
    [IDInteractionProbeEvents addObject:
        forced ? @"detach:1" : @"detach:0"];
}
- (void)selectWord {
    [IDInteractionProbeEvents addObject:@"selectWord"];
}
- (void)selectAll:(id)sender {
    IDInteractionProbeSender = sender;
    [IDInteractionProbeEvents addObject:@"selectAll"];
}
- (void)autoscrollWillNotStart {
    [IDInteractionProbeEvents addObject:@"autoscrollWillNotStart"];
}
- (void)beginFloatingCursorAtPoint:(CGPoint)point {
    IDInteractionProbePoint = point;
    [IDInteractionProbeEvents addObject:@"floating:begin"];
}
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    IDInteractionProbePoint = point;
    IDInteractionProbeAnimated = animated;
    [IDInteractionProbeEvents addObject:@"floating:update"];
}
- (void)endFloatingCursor {
    [IDInteractionProbeEvents addObject:@"floating:end"];
}

@end

@interface IDThrowingInteractionAssistantProbe :
    IDInteractionAssistantProbe
@end

@implementation IDThrowingInteractionAssistantProbe
- (instancetype)initWithView:(UIView *)view {
    self = [super initWithView:view];
    UIView *transient = [[UIView alloc] initWithFrame:CGRectZero];
    transient.tag = 2607;
    [view addSubview:transient];
    @throw [NSException
        exceptionWithName:@"IDInteractionConstructionProbe"
                   reason:@"intentional partial construction failure"
                 userInfo:nil];
}
@end

@interface IDWrongInteractionAssistantProbe :
    IDInteractionAssistantProbe
- (NSInteger)selectionChanged;
@end

@implementation IDWrongInteractionAssistantProbe
- (NSInteger)selectionChanged {
    [IDInteractionProbeEvents addObject:@"wrongSelectionChanged"];
    return 0;
}
@end

@interface IDWrongFloatingCursorAssistantProbe :
    IDInteractionAssistantProbe
- (NSInteger)updateFloatingCursorAtPoint:(CGPoint)point
                                animated:(BOOL)animated;
@end

@implementation IDWrongFloatingCursorAssistantProbe
- (NSInteger)updateFloatingCursorAtPoint:(CGPoint)point
                                animated:(BOOL)animated {
    (void)point;
    (void)animated;
    [IDInteractionProbeEvents addObject:@"wrongFloatingUpdate"];
    return 0;
}
@end

@interface IDInteractionLookup : NSObject <IDUIKitRuntimeLookingUp>
@property(nonatomic) Class resolvedClass;
@end

@implementation IDInteractionLookup
- (Class)classNamed:(NSString *)name {
    return [name isEqualToString:@"UITextInteractionAssistant"]
        ? self.resolvedClass
        : Nil;
}
- (Protocol *)protocolNamed:(NSString *)name {
    (void)name;
    return nil;
}
- (Method)instanceMethodForClass:(Class)cls selector:(SEL)selector {
    return class_getInstanceMethod(cls, selector);
}
- (Method)classMethodForClass:(Class)cls selector:(SEL)selector {
    return class_getClassMethod(cls, selector);
}
- (Ivar)instanceVariableForClass:(Class)cls name:(NSString *)name {
    return class_getInstanceVariable(cls, name.UTF8String);
}
@end

@interface IDUIKitInteractionCapabilityTests : XCTestCase
@property(nonatomic, strong) IDInteractionLookup *lookup;
@property(nonatomic, strong) IDUIKitCapabilityResolver *resolver;
@property(nonatomic, strong)
    IDUIKitRuntimeCapabilityContract *contract;
@end

@implementation IDUIKitInteractionCapabilityTests

- (void)setUp {
    [super setUp];
    [IDInteractionAssistantProbe reset];
    self.lookup = [IDInteractionLookup new];
    self.lookup.resolvedClass = IDInteractionAssistantProbe.class;
    self.resolver = [[IDUIKitCapabilityResolver alloc]
        initWithLookup:self.lookup];
    self.contract = IDUIKitInteractionRuntimeContract();
    XCTAssertNotNil(self.contract);
}

- (IDUIKitInteractionCapability *)makeCapability {
    NSError *error = nil;
    IDUIKitInteractionCapability *capability =
        [[IDUIKitInteractionCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
                        view:[IDInteractionHostProbe new]
                       error:&error];
    XCTAssertNotNil(capability);
    XCTAssertNil(error);
    return capability;
}

- (void)testUnavailableInteractionDoesNotAllocateAssistant {
    self.lookup.resolvedClass = Nil;
    NSError *error = nil;
    IDUIKitInteractionCapability *capability =
        [[IDUIKitInteractionCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
                        view:[IDInteractionHostProbe new]
                       error:&error];

    XCTAssertNotNil(capability);
    XCTAssertNil(error);
    XCTAssertNil(capability.privateAssistant);
    XCTAssertEqual(capability.report.state,
                   IDUIKitCapabilityStateUnavailable);
    XCTAssertEqual(IDInteractionProbeAllocationCount, 0U);
}

- (void)testWrongInteractionABIRejectsBeforeAllocation {
    self.lookup.resolvedClass =
        IDWrongInteractionAssistantProbe.class;
    NSError *error = nil;
    IDUIKitInteractionCapability *capability =
        [[IDUIKitInteractionCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
                        view:[IDInteractionHostProbe new]
                       error:&error];

    XCTAssertNotNil(capability);
    XCTAssertNil(error);
    XCTAssertNil(capability.privateAssistant);
    XCTAssertEqual(capability.report.state,
                   IDUIKitCapabilityStateRejectedContract);
    XCTAssertEqual(IDInteractionProbeAllocationCount, 0U);
    XCTAssertEqual(IDInteractionProbeEvents.count, 0U);
}

- (void)testConstructionUsesExactInitializerAndActivatesReport {
    IDInteractionHostProbe *host =
        [IDInteractionHostProbe new];
    NSError *error = nil;
    IDUIKitInteractionCapability *capability =
        [[IDUIKitInteractionCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
                        view:host
                       error:&error];

    XCTAssertNotNil(capability);
    XCTAssertNil(error);
    XCTAssertEqual(IDInteractionProbeAllocationCount, 1U);
    XCTAssertEqual(IDInteractionProbeInitializationCount, 1U);
    XCTAssertIdentical(IDInteractionProbeInitializedView, host);
    XCTAssertTrue([capability.privateAssistant
        isKindOfClass:IDInteractionAssistantProbe.class]);
    XCTAssertEqual(capability.report.state,
                   IDUIKitCapabilityStateActive);
    XCTAssertEqual(capability.floatingCursorReport.state,
                   IDUIKitCapabilityStateActive);
}

- (void)testHostRejectionOccursBeforeAssistantAllocation {
    NSError *error = nil;
    IDUIKitInteractionCapability *capability =
        [[IDUIKitInteractionCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
                        view:[UIView new]
                       error:&error];

    XCTAssertNotNil(capability);
    XCTAssertNotNil(error);
    XCTAssertNil(capability.privateAssistant);
    XCTAssertEqual(
        capability.report.state,
        IDUIKitCapabilityStateUnavailable);
    XCTAssertEqual(
        capability.floatingCursorReport.state,
        IDUIKitCapabilityStateUnavailable);
    XCTAssertEqual(IDInteractionProbeAllocationCount, 0U);
}

- (void)testPartialInitializerFailureClearsRecognizersAndTransientView {
    self.lookup.resolvedClass =
        IDThrowingInteractionAssistantProbe.class;
    IDInteractionHostProbe *host =
        [IDInteractionHostProbe new];
    NSError *error = nil;
    IDUIKitInteractionCapability *capability =
        [[IDUIKitInteractionCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
                        view:host
                       error:&error];

    XCTAssertNotNil(capability);
    XCTAssertNotNil(error);
    XCTAssertNil(capability.privateAssistant);
    XCTAssertEqual(
        capability.report.state,
        IDUIKitCapabilityStateUnavailable);
    XCTAssertEqual(
        capability.floatingCursorReport.state,
        IDUIKitCapabilityStateUnavailable);
    XCTAssertEqual(IDInteractionProbeAllocationCount, 1U);
    XCTAssertEqual(IDInteractionProbeInitializationCount, 1U);
    XCTAssertEqual(IDInteractionProbeCleanupCount, 1U);
    XCTAssertNil([host viewWithTag:2607]);
}

- (void)testFloatingCursorRejectionDoesNotDisableInteraction {
    self.lookup.resolvedClass =
        IDWrongFloatingCursorAssistantProbe.class;
    IDUIKitInteractionCapability *capability =
        [self makeCapability];

    XCTAssertEqual(capability.report.state,
                   IDUIKitCapabilityStateActive);
    XCTAssertEqual(capability.floatingCursorReport.state,
                   IDUIKitCapabilityStateRejectedContract);

    [capability id_selectionChanged];
    [capability beginFloatingCursorAtPoint:CGPointMake(3, 4)];
    [capability updateFloatingCursorAtPoint:CGPointMake(5, 6)
                                  animated:YES];
    [capability endFloatingCursor];
    XCTAssertEqualObjects(IDInteractionProbeEvents,
                          (@[@"selectionChanged"]));
}

- (void)testLifecycleMethodsForwardExactArgumentsAndOrder {
    IDUIKitInteractionCapability *capability =
        [self makeCapability];
    NSObject *sender = [NSObject new];

    [capability setSelectionActive:YES visible:YES];
    [capability id_selectionChanged];
    [capability id_setNeedsSelectionDisplayUpdate];
    [capability setGestureRecognizersEnabled:YES];
    [capability setGestureRecognizersEnabled:NO];
    [capability clearGestureRecognizersForced:NO];
    [capability beginFloatingCursorAtPoint:CGPointMake(1, 2)];
    [capability updateFloatingCursorAtPoint:CGPointMake(8, 9)
                                  animated:YES];
    [capability endFloatingCursor];
    [capability id_resignedFirstResponder];
    [capability id_selectWord];
    [capability selectAll:sender];
    [capability id_autoscrollWillNotStart];
    [capability setSelectionActive:NO visible:NO];

    XCTAssertEqualObjects(IDInteractionProbeEvents, (@[
        @"visible:1",
        @"activate",
        @"selectionChanged",
        @"displayUpdate",
        @"recognizers:set",
        @"recognizers:clear:1",
        @"recognizers:clear:0",
        @"floating:begin",
        @"floating:update",
        @"floating:end",
        @"resigned",
        @"selectWord",
        @"selectAll",
        @"autoscrollWillNotStart",
        @"visible:0",
        @"deactivate",
    ]));
    XCTAssertTrue(CGPointEqualToPoint(
        IDInteractionProbePoint, CGPointMake(8, 9)));
    XCTAssertTrue(IDInteractionProbeAnimated);
    XCTAssertIdentical(IDInteractionProbeSender, sender);
}

- (void)testDetachIsIdempotentAndSuppressesLaterForwarding {
    IDUIKitInteractionCapability *capability =
        [self makeCapability];

    [capability detach];
    [capability detach];
    [capability id_selectionChanged];
    [capability setGestureRecognizersEnabled:YES];
    [capability beginFloatingCursorAtPoint:CGPointMake(1, 2)];

    XCTAssertEqualObjects(IDInteractionProbeEvents,
                          (@[@"detach:1"]));
}

@end
