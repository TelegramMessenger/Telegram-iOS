#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "IDUIKitBehaviorKernel.h"

static NSUInteger IDKernelInputAllocationCount;
static NSUInteger IDKernelInteractionAllocationCount;
static NSUInteger IDKernelDelayedCallbackCount;
static NSUInteger IDKernelFailedInteractionCleanupCount;
static NSUInteger IDKernelHostDeallocationCount;
static NSUInteger IDKernelInteractionDeallocationCount;
static BOOL IDKernelInteractionInitializationReturnsNil;
static BOOL IDKernelEntryWasActiveBeforeInteractionAllocation;
static NSMutableArray<NSString *> *IDKernelEvents;

static Protocol *IDKernelAutoscrollingProtocol(void) {
    static Protocol *protocol;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *name = @"IDKernelUITextAutoscrolling";
        protocol = NSProtocolFromString(name);
        if (protocol == nil) {
            protocol = objc_allocateProtocol(name.UTF8String);
            objc_registerProtocol(protocol);
        }
    });
    return protocol;
}

@interface IDKernelInputProbe : NSObject
@property(nonatomic, weak) id delegate;
- (instancetype)initWithTextLayoutController:(id)layoutController;
- (void)setDelegate:(id)delegate;
- (void)_detachFromLayoutManager;
@end

@implementation IDKernelInputProbe
+ (id)allocWithZone:(struct _NSZone *)zone {
    IDKernelInputAllocationCount += 1;
    return [super allocWithZone:zone];
}
- (instancetype)initWithTextLayoutController:(id)layoutController {
    (void)layoutController;
    return [super init];
}
- (void)setDelegate:(id)delegate {
    _delegate = delegate;
}
- (void)_detachFromLayoutManager {
    [IDKernelEvents addObject:@"input:detach"];
}
@end

@interface IDKernelMissingInputConstructorProbe : NSObject
- (void)setDelegate:(id)delegate;
- (void)_detachFromLayoutManager;
@end
@implementation IDKernelMissingInputConstructorProbe
- (void)setDelegate:(id)delegate { (void)delegate; }
- (void)_detachFromLayoutManager {}
@end

@interface IDKernelMissingInputDelegateProbe : NSObject
- (instancetype)initWithTextLayoutController:(id)layoutController;
- (void)_detachFromLayoutManager;
@end
@implementation IDKernelMissingInputDelegateProbe
- (instancetype)initWithTextLayoutController:(id)layoutController {
    (void)layoutController;
    return [super init];
}
- (void)_detachFromLayoutManager {}
@end

@interface IDKernelThrowingInputDelegateProbe : IDKernelInputProbe
@end
@implementation IDKernelThrowingInputDelegateProbe
- (void)setDelegate:(id)delegate {
    (void)delegate;
    @throw [NSException exceptionWithName:@"IDKernelDelegateFailure"
                                   reason:@"injected delegate failure"
                                 userInfo:nil];
}
@end

@interface IDKernelHostProbe : UIView
@end
@implementation IDKernelHostProbe
- (void)dealloc {
    IDKernelHostDeallocationCount += 1;
}
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
- (void)startAutoscroll:(CGPoint)point { (void)point; }
- (void)cancelAutoscroll {}
- (id)_visualSelectionRangeForExtent:(id)extent
                            forPoint:(CGPoint)point
                        fromPosition:(id)position
                         inDirection:(NSInteger)direction {
    (void)extent; (void)point; (void)position; (void)direction;
    return nil;
}
@end

@interface IDKernelInteractionProbe : NSObject
@property(nonatomic, weak) UIView *host;
@property(nonatomic) BOOL detached;
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

@implementation IDKernelInteractionProbe
+ (id)allocWithZone:(struct _NSZone *)zone {
    IDKernelInteractionAllocationCount += 1;
    IDKernelEntryWasActiveBeforeInteractionAllocation =
        class_conformsToProtocol(
            IDKernelHostProbe.class,
            IDKernelAutoscrollingProtocol());
    return [super allocWithZone:zone];
}
- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if (self != nil) {
        if (IDKernelInteractionInitializationReturnsNil) {
            return nil;
        }
        _host = view;
        __weak typeof(self) weakSelf = self;
        __weak UIView *weakHost = view;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf != nil && !weakSelf.detached &&
                weakHost != nil) {
                IDKernelDelayedCallbackCount += 1;
            }
        });
    }
    return self;
}
- (void)selectionChanged {}
- (void)activateSelection {}
- (void)deactivateSelection {}
- (void)setSelectionDisplayVisible:(BOOL)visible { (void)visible; }
- (void)setNeedsSelectionDisplayUpdate {}
- (void)setGestureRecognizers {}
- (void)clearGestureRecognizers:(BOOL)forced {
    (void)forced;
    IDKernelFailedInteractionCleanupCount += 1;
}
- (void)resignedFirstResponder {}
- (void)detach:(BOOL)forced {
    (void)forced;
    self.detached = YES;
    [IDKernelEvents addObject:@"interaction:detach"];
}
- (void)selectWord {}
- (void)selectAll:(id)sender { (void)sender; }
- (void)autoscrollWillNotStart {}
- (void)beginFloatingCursorAtPoint:(CGPoint)point { (void)point; }
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    (void)point; (void)animated;
}
- (void)endFloatingCursor {}
- (void)dealloc {
    IDKernelInteractionDeallocationCount += 1;
}
@end

@interface IDKernelWrongInteractionProbe : IDKernelInteractionProbe
- (NSInteger)selectionChanged;
@end
@implementation IDKernelWrongInteractionProbe
- (NSInteger)selectionChanged { return 0; }
@end

@interface IDKernelLookup : NSObject <IDUIKitRuntimeLookingUp>
@property(nonatomic) Class inputClass;
@property(nonatomic) Class interactionClass;
@property(nonatomic, strong, nullable) Protocol *autoscrollProtocol;
@end
@implementation IDKernelLookup
- (Class)classNamed:(NSString *)name {
    if ([name isEqualToString:@"UITextInputController"]) {
        return self.inputClass;
    }
    if ([name isEqualToString:@"UITextInteractionAssistant"]) {
        return self.interactionClass;
    }
    if ([name isEqualToString:@"IDKernelHostProbe"]) {
        return IDKernelHostProbe.class;
    }
    return Nil;
}
- (Protocol *)protocolNamed:(NSString *)name {
    return [name isEqualToString:
        NSStringFromProtocol(IDKernelAutoscrollingProtocol())]
        ? self.autoscrollProtocol
        : nil;
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

@interface IDUIKitBehaviorKernelTests : XCTestCase
@property(nonatomic, strong) IDKernelLookup *lookup;
@property(nonatomic, strong) IDUIKitCapabilityResolver *resolver;
@property(nonatomic, strong) IDUIKitRuntimeManifest *manifest;
@end

@implementation IDUIKitBehaviorKernelTests

- (NSDictionary *)member:(NSString *)identifier
                   class:(NSString *)className
                    name:(NSString *)name
                  return:(NSString *)returnType
               arguments:(NSArray<NSString *> *)arguments {
    return @{
        @"identifier": identifier, @"class": className,
        @"kind": [name isEqualToString:@"class"]
            ? @"classMethod" : @"instanceMethod",
        @"name": name, @"returnType": returnType,
        @"argumentTypes": arguments, @"required": @YES,
        @"direction": @"outgoing",
        @"source": @"Tests/IDUIKitBehaviorKernelTests.m|fixture",
        @"evidence": @"kernel test fixture", @"fallback": @"none",
        @"teardown": @"Detach once.",
    };
}

- (IDUIKitRuntimeManifest *)makeManifest {
    NSString *input = @"UITextInputController";
    NSString *interaction = @"UITextInteractionAssistant";
    NSMutableArray *interactionMembers = [NSMutableArray arrayWithObject:
        [self member:@"interaction.class" class:interaction name:@"class"
              return:@"#" arguments:@[]]];
    NSArray *interactionMethods = @[
        @[@"initWithView:", @"@", @[@"@"]],
        @[@"selectionChanged", @"v", @[]],
        @[@"activateSelection", @"v", @[]],
        @[@"deactivateSelection", @"v", @[]],
        @[@"setSelectionDisplayVisible:", @"v", @[@"B"]],
        @[@"setNeedsSelectionDisplayUpdate", @"v", @[]],
        @[@"setGestureRecognizers", @"v", @[]],
        @[@"clearGestureRecognizers:", @"v", @[@"B"]],
        @[@"resignedFirstResponder", @"v", @[]],
        @[@"detach:", @"v", @[@"B"]],
        @[@"selectWord", @"v", @[]],
        @[@"selectAll:", @"v", @[@"@"]],
        @[@"autoscrollWillNotStart", @"v", @[]],
    ];
    for (NSArray *method in interactionMethods) {
        [interactionMembers addObject:
            [self member:[@"interaction." stringByAppendingString:method[0]]
                   class:interaction name:method[0] return:method[1]
               arguments:method[2]]];
    }
    NSDictionary *root = @{
        @"schema": @1,
        @"runtime": @{@"osVersion": @"26.5", @"osBuild": @"23F73"},
        @"capabilities": @{
            @"inputController": @{
                @"mandatory": @YES, @"dependencies": @[],
                @"fallback": @"none", @"members": @[
                    [self member:@"input.class" class:input name:@"class"
                          return:@"#" arguments:@[]],
                    [self member:@"input.init" class:input
                            name:@"initWithTextLayoutController:"
                          return:@"@" arguments:@[@"@"]],
                    [self member:@"input.delegate" class:input
                            name:@"setDelegate:" return:@"v"
                       arguments:@[@"@"]],
                    [self member:@"input.detach" class:input
                            name:@"_detachFromLayoutManager" return:@"v"
                       arguments:@[]],
                ],
            },
            @"interaction": @{
                @"mandatory": @NO, @"dependencies": @[@"inputController"],
                @"fallback": @"project selection",
                @"members": interactionMembers,
            },
            @"floatingCursor": @{
                @"mandatory": @NO, @"dependencies": @[@"interaction"],
                @"fallback": @"ordinary selection", @"members": @[
                    [self member:@"floating.begin" class:interaction
                            name:@"beginFloatingCursorAtPoint:"
                          return:@"v" arguments:@[@"{CGPoint=dd}"]],
                ],
            },
            @"autoscrollEntry": @{
                @"mandatory": @NO,
                @"dependencies": @[],
                @"fallback": @"project vertical autoscroll disabled",
                @"members": @[
                    @{
                        @"identifier": @"autoscrollEntry.protocol",
                        @"class": NSStringFromProtocol(
                            IDKernelAutoscrollingProtocol()),
                        @"kind": @"protocol",
                        @"name": NSStringFromProtocol(
                            IDKernelAutoscrollingProtocol()),
                        @"returnType": @"@",
                        @"argumentTypes": @[],
                        @"required": @YES,
                        @"direction": @"incoming",
                        @"source": @"Tests/IDUIKitBehaviorKernelTests.m|IDKernelAutoscrollingProtocol",
                        @"evidence": @"kernel test fixture",
                        @"fallback": @"none",
                        @"teardown": @"No retained runtime state.",
                    },
                    [self member:@"autoscrollEntry.start"
                           class:@"IDKernelHostProbe"
                            name:@"startAutoscroll:"
                          return:@"v"
                       arguments:@[@"{CGPoint=dd}"]],
                    [self member:@"autoscrollEntry.cancel"
                           class:@"IDKernelHostProbe"
                            name:@"cancelAutoscroll"
                          return:@"v"
                       arguments:@[]],
                ],
            },
        },
        @"referenceOnly": @{}, @"forbidden": @[],
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root
                                                   options:0 error:nil];
    return [IDUIKitRuntimeManifest manifestWithData:data error:nil];
}

- (void)setUp {
    [super setUp];
    IDKernelInputAllocationCount = 0;
    IDKernelInteractionAllocationCount = 0;
    IDKernelDelayedCallbackCount = 0;
    IDKernelFailedInteractionCleanupCount = 0;
    IDKernelHostDeallocationCount = 0;
    IDKernelInteractionDeallocationCount = 0;
    IDKernelInteractionInitializationReturnsNil = NO;
    IDKernelEntryWasActiveBeforeInteractionAllocation = NO;
    IDKernelEvents = [NSMutableArray array];
    self.lookup = [IDKernelLookup new];
    self.lookup.inputClass = IDKernelInputProbe.class;
    self.lookup.interactionClass = IDKernelInteractionProbe.class;
    self.lookup.autoscrollProtocol = IDKernelAutoscrollingProtocol();
    self.resolver = [[IDUIKitCapabilityResolver alloc]
        initWithLookup:self.lookup];
    self.manifest = [self makeManifest];
    XCTAssertNotNil(self.manifest);
}

- (IDUIKitBehaviorKernel *)kernelWithRequested:
    (IDUIKitBehaviorCapabilities)requested
                                  host:(UIView *)host
                                 error:(NSError **)error {
    return [[IDUIKitBehaviorKernel alloc]
        initWithManifest:self.manifest resolver:self.resolver
        layoutController:[NSObject new] delegate:[NSObject new]
        view:host requestedCapabilities:requested error:error];
}

- (IDUIKitCapabilityReport *)reportNamed:(NSString *)name
                                  kernel:(IDUIKitBehaviorKernel *)kernel {
    for (IDUIKitCapabilityReport *report in kernel.report.capabilities) {
        if ([report.identifier isEqualToString:name]) return report;
    }
    return nil;
}

- (void)testMissingInteractionStillProducesActiveInputController {
    self.lookup.interactionClass = Nil;
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
        host:[IDKernelHostProbe new] error:nil];
    XCTAssertNotNil(kernel);
    XCTAssertEqual(kernel.lifecycle, IDUIKitBehaviorKernelLifecycleActive);
    XCTAssertNotNil(kernel.inputController);
    XCTAssertNil(kernel.interaction);
    XCTAssertEqual([self reportNamed:@"interaction" kernel:kernel].state,
                   IDUIKitCapabilityStateUnavailable);
}

- (void)testAutoscrollEntryActivatesBeforeInteractionConstruction {
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:(IDUIKitBehaviorCapabilityInteraction |
                             IDUIKitBehaviorCapabilityAutoscroll)
        host:[IDKernelHostProbe new] error:nil];

    XCTAssertNotNil(kernel.autoscrollEntry);
    XCTAssertTrue(kernel.autoscrollEntry.isActive);
    XCTAssertTrue(IDKernelEntryWasActiveBeforeInteractionAllocation);
    XCTAssertEqual(
        [self reportNamed:@"autoscrollEntry" kernel:kernel].state,
        IDUIKitCapabilityStateActive);
    XCTAssertEqual(
        [self reportNamed:@"autoscrollEngine" kernel:kernel].state,
        IDUIKitCapabilityStateProjectOwned);
}

- (void)testMissingAutoscrollProtocolLeavesInteractionUsable {
    self.lookup.autoscrollProtocol = nil;
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:(IDUIKitBehaviorCapabilityInteraction |
                             IDUIKitBehaviorCapabilityAutoscroll)
        host:[IDKernelHostProbe new] error:nil];

    XCTAssertNil(kernel.autoscrollEntry);
    XCTAssertNotNil(kernel.interaction);
    XCTAssertEqual(
        [self reportNamed:@"autoscrollEntry" kernel:kernel].state,
        IDUIKitCapabilityStateUnavailable);
    XCTAssertNil([self reportNamed:@"autoscrollEngine" kernel:kernel]);
}

- (void)testWrongInteractionABIDoesNotAllocateAssistant {
    self.lookup.interactionClass = IDKernelWrongInteractionProbe.class;
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
        host:[IDKernelHostProbe new] error:nil];
    XCTAssertNotNil(kernel);
    XCTAssertEqual(IDKernelInteractionAllocationCount, 0U);
    XCTAssertEqual([self reportNamed:@"interaction" kernel:kernel].state,
                   IDUIKitCapabilityStateRejectedContract);
}

- (void)testMissingInputConstructorFailsWithoutActiveKernel {
    self.lookup.inputClass = IDKernelMissingInputConstructorProbe.class;
    NSError *error = nil;
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
        host:[IDKernelHostProbe new] error:&error];
    XCTAssertNil(kernel);
    XCTAssertNotNil(error);
    XCTAssertEqual(IDKernelInputAllocationCount, 0U);
    XCTAssertEqual(IDKernelInteractionAllocationCount, 0U);
}

- (void)testMissingInputDelegateSetterFailsWithoutActiveKernel {
    self.lookup.inputClass = IDKernelMissingInputDelegateProbe.class;
    NSError *error = nil;
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
        host:[IDKernelHostProbe new] error:&error];
    XCTAssertNil(kernel);
    XCTAssertNotNil(error);
    XCTAssertEqual(IDKernelInteractionAllocationCount, 0U);
}

- (void)testThrowingInputDelegateSetterCleansUpAndFailsConstruction {
    self.lookup.inputClass = IDKernelThrowingInputDelegateProbe.class;
    NSError *error = nil;
    IDUIKitBehaviorKernel *kernel = nil;
    XCTAssertNoThrow(kernel = [self
        kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
        host:[IDKernelHostProbe new] error:&error]);
    XCTAssertNil(kernel);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(IDKernelEvents, (@[@"input:detach"]));
    XCTAssertEqual(IDKernelInteractionAllocationCount, 0U);
}

- (void)testFloatingCursorRejectsWhenInteractionIsUnavailable {
    self.lookup.interactionClass = Nil;
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:(IDUIKitBehaviorCapabilityInteraction |
                             IDUIKitBehaviorCapabilityFloatingCursor)
        host:[IDKernelHostProbe new] error:nil];
    XCTAssertEqual([self reportNamed:@"floatingCursor" kernel:kernel].state,
                   IDUIKitCapabilityStateUnavailable);
}

- (void)testDetachOrderIsInteractionThenInput {
    IDUIKitBehaviorKernel *kernel = [self
        kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
        host:[IDKernelHostProbe new] error:nil];
    [kernel detach];
    [kernel detach];
    XCTAssertEqualObjects(IDKernelEvents,
                          (@[@"interaction:detach", @"input:detach"]));
    XCTAssertEqual(kernel.lifecycle,
                   IDUIKitBehaviorKernelLifecycleDetached);
}

- (void)testRepeatedDetachAndDeallocAfterFailedConstructionAreSafe {
    for (NSUInteger index = 0; index < 100; index += 1) {
        @autoreleasepool {
            self.lookup.inputClass =
                IDKernelMissingInputConstructorProbe.class;
            IDUIKitBehaviorKernel *kernel = [self
                kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
                host:[IDKernelHostProbe new] error:nil];
            XCTAssertNil(kernel);
            [kernel detach];
        }
    }
}

- (void)testInteractionInitializationFailureFallsBackAndReleasesCycles {
    IDKernelInteractionInitializationReturnsNil = YES;
    NSHashTable<UIView *> *weakHosts =
        [NSHashTable weakObjectsHashTable];
    for (NSUInteger index = 0; index < 100; index += 1) {
        @autoreleasepool {
            UIView *host = [IDKernelHostProbe new];
            [weakHosts addObject:host];
            IDUIKitBehaviorKernel *kernel = [self
                kernelWithRequested:
                    (IDUIKitBehaviorCapabilityInteraction |
                     IDUIKitBehaviorCapabilityFloatingCursor)
                host:host error:nil];
            XCTAssertNotNil(kernel, @"iteration=%lu",
                            (unsigned long)index);
            XCTAssertNotNil(kernel.inputController);
            XCTAssertNil(kernel.interaction);
            XCTAssertEqual(
                [self reportNamed:@"interaction" kernel:kernel].state,
                IDUIKitCapabilityStateUnavailable);
            [kernel detach];
            kernel = nil;
            host = nil;
        }
    }
    XCTAssertEqual(IDKernelFailedInteractionCleanupCount, 100U);
    XCTestExpectation *drained =
        [self expectationWithDescription:@"failed interactions drained"];
    dispatch_async(dispatch_get_main_queue(), ^{ [drained fulfill]; });
    [self waitForExpectations:@[drained] timeout:1.0];
    XCTAssertEqual(IDKernelInteractionDeallocationCount, 100U);
    XCTAssertEqual(IDKernelHostDeallocationCount, 100U);
    XCTAssertEqual(weakHosts.allObjects.count, 0U);
}

- (void)testHostProbeDoesNotHaveIndependentLifetime {
    NSHashTable<UIView *> *weakHosts =
        [NSHashTable weakObjectsHashTable];
    for (NSUInteger index = 0; index < 100; index += 1) {
        @autoreleasepool {
            UIView *host = [IDKernelHostProbe new];
            [weakHosts addObject:host];
            host = nil;
        }
    }
    XCTAssertEqual(IDKernelHostDeallocationCount, 100U);
    XCTAssertEqual(weakHosts.allObjects.count, 0U);
}

- (void)testNoDelayedCallbackReachesReleasedDelegate {
    __weak UIView *weakHost;
    @autoreleasepool {
        UIView *host = [IDKernelHostProbe new];
        weakHost = host;
        IDUIKitBehaviorKernel *kernel = [self
            kernelWithRequested:IDUIKitBehaviorCapabilityInteraction
            host:host error:nil];
        [kernel detach];
        kernel = nil;
        host = nil;
    }
    XCTestExpectation *drained =
        [self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{ [drained fulfill]; });
    [self waitForExpectations:@[drained] timeout:1.0];
    XCTAssertNil(weakHost);
    XCTAssertEqual(IDKernelDelayedCallbackCount, 0U);
}

@end
