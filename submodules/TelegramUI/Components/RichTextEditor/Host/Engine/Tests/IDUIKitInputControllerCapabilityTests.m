#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "IDUIKitInputControllerCapability.h"

static NSUInteger IDInputProbeAllocationCount;
static NSUInteger IDInputProbeDeallocationCount;
static NSUInteger IDInputProbeDelegateSetCount;
static NSUInteger IDInputProbeDetachCount;
static NSUInteger IDInputProbeDeleteCount;
static NSUInteger IDInputProbeSuppressionCount;
static id IDInputProbeLayoutController;
static id IDInputProbeDelegate;
static id IDInputProbeObjectArgument;
static NSRange IDInputProbeRangeArgument;
static CGPoint IDInputProbePointArgument;

@interface IDInputControllerRangesProbe : NSObject
- (NSRange)unionRange;
@end

@implementation IDInputControllerRangesProbe
- (NSRange)unionRange {
    return NSMakeRange(7, 3);
}
@end

@interface IDInputControllerProbe : NSObject
@property(nonatomic, strong) id selectedTextRange;
@property(nonatomic, strong) id inputDelegate;
@property(nonatomic, strong) NSDictionary *typingAttributes;
+ (void)reset;
- (instancetype)initWithTextLayoutController:(id)layoutController;
- (void)setDelegate:(id)delegate;
- (id)textInRange:(id)range;
- (void)setMarkedText:(id)text selectedRange:(NSRange)range;
- (NSInteger)comparePosition:(id)left toPosition:(id)right;
- (id)closestPositionToPoint:(CGPoint)point;
- (CGRect)caretRectForPosition:(id)position;
- (void)_performWhileSuppressingDelegateNotifications:
    (void (^)(void))body;
- (id)_rangesForBackwardsDelete;
- (void)_detachFromLayoutManager;
- (void)deleteBackward;
@end

@implementation IDInputControllerProbe

+ (id)allocWithZone:(struct _NSZone *)zone {
    IDInputProbeAllocationCount += 1;
    return [super allocWithZone:zone];
}

+ (void)reset {
    IDInputProbeAllocationCount = 0;
    IDInputProbeDeallocationCount = 0;
    IDInputProbeDelegateSetCount = 0;
    IDInputProbeDetachCount = 0;
    IDInputProbeDeleteCount = 0;
    IDInputProbeSuppressionCount = 0;
    IDInputProbeLayoutController = nil;
    IDInputProbeDelegate = nil;
    IDInputProbeObjectArgument = nil;
    IDInputProbeRangeArgument = NSMakeRange(NSNotFound, 0);
    IDInputProbePointArgument = CGPointZero;
}

- (instancetype)initWithTextLayoutController:(id)layoutController {
    self = [super init];
    if (self != nil) {
        IDInputProbeLayoutController = layoutController;
        _typingAttributes = @{};
    }
    return self;
}

- (void)dealloc {
    IDInputProbeDeallocationCount += 1;
}

- (void)setDelegate:(id)delegate {
    IDInputProbeDelegateSetCount += 1;
    IDInputProbeDelegate = delegate;
}

- (id)textInRange:(id)range {
    IDInputProbeObjectArgument = range;
    return @"probe-text";
}

- (void)setMarkedText:(id)text selectedRange:(NSRange)range {
    IDInputProbeObjectArgument = text;
    IDInputProbeRangeArgument = range;
}

- (NSInteger)comparePosition:(id)left toPosition:(id)right {
    IDInputProbeObjectArgument = @[left ?: NSNull.null,
                                   right ?: NSNull.null];
    return NSOrderedDescending;
}

- (id)closestPositionToPoint:(CGPoint)point {
    IDInputProbePointArgument = point;
    return @"point-result";
}

- (CGRect)caretRectForPosition:(id)position {
    IDInputProbeObjectArgument = position;
    return CGRectMake(1, 2, 3, 4);
}

- (void)_performWhileSuppressingDelegateNotifications:
    (void (^)(void))body {
    IDInputProbeSuppressionCount += 1;
    body();
}

- (id)_rangesForBackwardsDelete {
    return [IDInputControllerRangesProbe new];
}

- (void)_detachFromLayoutManager {
    IDInputProbeDetachCount += 1;
}

- (void)deleteBackward {
    IDInputProbeDeleteCount += 1;
}

@end

@interface IDFailingInputControllerProbe : IDInputControllerProbe
@end

@implementation IDFailingInputControllerProbe
- (instancetype)initWithTextLayoutController:(id)layoutController {
    (void)layoutController;
    return nil;
}
@end

@interface IDWrongInputControllerProbe : NSObject
- (NSInteger)setDelegate:(id)delegate;
@end

@implementation IDWrongInputControllerProbe
- (NSInteger)setDelegate:(id)delegate {
    (void)delegate;
    IDInputProbeDelegateSetCount += 1;
    return 0;
}
@end

@interface IDInputControllerLookup : NSObject <IDUIKitRuntimeLookingUp>
@property(nonatomic) Class resolvedClass;
@end

@implementation IDInputControllerLookup
- (Class)classNamed:(NSString *)name {
    return [name isEqualToString:@"UITextInputController"]
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

@interface IDUIKitInputControllerCapabilityTests : XCTestCase
@property(nonatomic, strong) IDInputControllerLookup *lookup;
@property(nonatomic, strong) IDUIKitCapabilityResolver *resolver;
@property(nonatomic, strong) IDUIKitRuntimeCapabilityContract *contract;
@end

@implementation IDUIKitInputControllerCapabilityTests

- (NSDictionary<NSString *, id> *)member:(NSString *)identifier
                                    name:(NSString *)name
                              returnType:(NSString *)returnType
                           argumentTypes:(NSArray<NSString *> *)argumentTypes {
    return @{
        @"identifier": identifier,
        @"class": @"UITextInputController",
        @"kind": [name isEqualToString:@"class"]
            ? @"classMethod"
            : @"instanceMethod",
        @"name": name,
        @"returnType": returnType,
        @"argumentTypes": argumentTypes,
        @"required": @YES,
        @"direction": @"outgoing",
        @"source": [NSString stringWithFormat:
            @"PrivateUIKit/BehaviorKernel/IDUIKitInputControllerCapability.m|%@",
            name],
        @"evidence":
            @"docs/hopper/UIKitCore-iOS26.5.md#minimal-private-input-kernel",
        @"fallback": @"none",
        @"teardown": @"Detach once.",
    };
}

- (IDUIKitRuntimeCapabilityContract *)makeContract {
    NSArray *members = @[
        [self member:@"input.class"
                name:@"class"
          returnType:@"#"
       argumentTypes:@[]],
        [self member:@"input.init"
                name:@"initWithTextLayoutController:"
          returnType:@"@"
       argumentTypes:@[@"@"]],
        [self member:@"input.delegate"
                name:@"setDelegate:"
          returnType:@"v"
       argumentTypes:@[@"@"]],
        [self member:@"input.object"
                name:@"textInRange:"
          returnType:@"@"
       argumentTypes:@[@"@"]],
        [self member:@"input.range"
                name:@"setMarkedText:selectedRange:"
          returnType:@"v"
       argumentTypes:@[@"@", @"{_NSRange=QQ}"]],
        [self member:@"input.integer"
                name:@"comparePosition:toPosition:"
          returnType:@"q"
       argumentTypes:@[@"@", @"@"]],
        [self member:@"input.point"
                name:@"closestPositionToPoint:"
          returnType:@"@"
       argumentTypes:@[@"{CGPoint=dd}"]],
        [self member:@"input.rect"
                name:@"caretRectForPosition:"
          returnType:@"{CGRect={CGPoint=dd}{CGSize=dd}}"
       argumentTypes:@[@"@"]],
        [self member:@"input.block"
                name:@"_performWhileSuppressingDelegateNotifications:"
          returnType:@"v"
       argumentTypes:@[@"@?"]],
        [self member:@"input.ranges"
                name:@"_rangesForBackwardsDelete"
          returnType:@"@"
       argumentTypes:@[]],
        [self member:@"input.detach"
                name:@"_detachFromLayoutManager"
          returnType:@"v"
       argumentTypes:@[]],
        [self member:@"input.delete"
                name:@"deleteBackward"
          returnType:@"v"
       argumentTypes:@[]],
    ];
    NSDictionary *dictionary = @{
        @"schema": @1,
        @"runtime": @{
            @"osVersion": @"26.5",
            @"osBuild": @"23F73",
        },
        @"capabilities": @{
            @"inputController": @{
                @"mandatory": @YES,
                @"dependencies": @[],
                @"fallback": @"none",
                @"members": members,
            },
        },
        @"referenceOnly": @{},
        @"forbidden": @[],
    };
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:dictionary options:0 error:nil];
    IDUIKitRuntimeManifest *manifest =
        [IDUIKitRuntimeManifest manifestWithData:data error:nil];
    XCTAssertNotNil(manifest);
    return manifest.capabilities[@"inputController"];
}

- (void)setUp {
    [super setUp];
    [IDInputControllerProbe reset];
    self.lookup = [IDInputControllerLookup new];
    self.lookup.resolvedClass = IDInputControllerProbe.class;
    self.resolver = [[IDUIKitCapabilityResolver alloc]
        initWithLookup:self.lookup];
    self.contract = [self makeContract];
}

- (void)testConstructingInitializerValidatesThenInitializesAndSetsDelegateOnce {
    NSObject *layout = [NSObject new];
    NSObject *delegate = [NSObject new];
    NSError *error = nil;
    IDUIKitInputControllerCapability *capability =
        [[IDUIKitInputControllerCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
            layoutController:layout
                    delegate:delegate
                       error:&error];

    XCTAssertNotNil(capability);
    XCTAssertNil(error);
    XCTAssertEqual(IDInputProbeAllocationCount, 1U);
    XCTAssertIdentical(IDInputProbeLayoutController, layout);
    XCTAssertEqual(IDInputProbeDelegateSetCount, 1U);
    XCTAssertIdentical(IDInputProbeDelegate, delegate);
    XCTAssertTrue([capability.privateController
        isKindOfClass:IDInputControllerProbe.class]);
    XCTAssertEqual(capability.report.state,
                   IDUIKitCapabilityStateActive);
}

- (void)testWrongABIRejectsBeforeAllocationOrDelegateMutation {
    self.lookup.resolvedClass = IDWrongInputControllerProbe.class;
    self.resolver = [[IDUIKitCapabilityResolver alloc]
        initWithLookup:self.lookup];
    NSError *error = nil;

    IDUIKitInputControllerCapability *capability =
        [[IDUIKitInputControllerCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
            layoutController:[NSObject new]
                    delegate:[NSObject new]
                       error:&error];

    XCTAssertNil(capability);
    XCTAssertNotNil(error);
    XCTAssertEqual(IDInputProbeAllocationCount, 0U);
    XCTAssertEqual(IDInputProbeDelegateSetCount, 0U);
}

- (void)testAdoptionValidatesWithoutAllocatingOrSettingDelegate {
    IDInputControllerProbe *controller =
        [[IDInputControllerProbe alloc]
            initWithTextLayoutController:[NSObject new]];
    NSUInteger allocations = IDInputProbeAllocationCount;
    NSError *error = nil;

    IDUIKitInputControllerCapability *capability =
        [[IDUIKitInputControllerCapability alloc]
            initAdoptingPrivateController:controller
                                 contract:self.contract
                                 resolver:self.resolver
                                    error:&error];

    XCTAssertNotNil(capability);
    XCTAssertNil(error);
    XCTAssertIdentical(capability.privateController, controller);
    XCTAssertEqual(IDInputProbeAllocationCount, allocations);
    XCTAssertEqual(IDInputProbeDelegateSetCount, 0U);
}

- (void)testRepresentativeABIFamiliesForwardExactly {
    IDUIKitInputControllerCapability *capability =
        [[IDUIKitInputControllerCapability alloc]
            initAdoptingPrivateController:
                [[IDInputControllerProbe alloc]
                    initWithTextLayoutController:[NSObject new]]
                                 contract:self.contract
                                 resolver:self.resolver
                                    error:nil];
    NSObject *object = [NSObject new];
    XCTAssertEqualObjects([capability textInRange:(id)object],
                          @"probe-text");
    XCTAssertIdentical(IDInputProbeObjectArgument, object);

    [capability setMarkedText:@"marked"
               selectedRange:NSMakeRange(4, 2)];
    XCTAssertEqualObjects(IDInputProbeObjectArgument, @"marked");
    XCTAssertTrue(NSEqualRanges(IDInputProbeRangeArgument,
                               NSMakeRange(4, 2)));

    XCTAssertEqual([capability comparePosition:(id)@"left"
                                    toPosition:(id)@"right"],
                   NSOrderedDescending);
    XCTAssertEqualObjects(IDInputProbeObjectArgument,
                          (@[@"left", @"right"]));

    XCTAssertEqualObjects(
        [capability closestPositionToPoint:CGPointMake(9, 8)],
        @"point-result");
    XCTAssertTrue(CGPointEqualToPoint(IDInputProbePointArgument,
                                     CGPointMake(9, 8)));

    XCTAssertTrue(CGRectEqualToRect(
        [capability caretRectForPosition:(id)object],
        CGRectMake(1, 2, 3, 4)));

    __block BOOL invoked = NO;
    [capability performWhileSuppressingDelegateNotifications:^{
        invoked = YES;
    }];
    XCTAssertTrue(invoked);
    XCTAssertEqual(IDInputProbeSuppressionCount, 1U);
    XCTAssertTrue(NSEqualRanges(capability.backwardDeleteRange,
                               NSMakeRange(7, 3)));
}

- (void)testFailedInitializerReleasesProvisionalController {
    self.lookup.resolvedClass = IDFailingInputControllerProbe.class;
    self.resolver = [[IDUIKitCapabilityResolver alloc]
        initWithLookup:self.lookup];
    NSError *error = nil;

    IDUIKitInputControllerCapability *capability =
        [[IDUIKitInputControllerCapability alloc]
            initWithContract:self.contract
                    resolver:self.resolver
            layoutController:[NSObject new]
                    delegate:[NSObject new]
                       error:&error];

    XCTAssertNil(capability);
    XCTAssertNotNil(error);
    XCTAssertEqual(IDInputProbeAllocationCount, 1U);
    XCTAssertEqual(IDInputProbeDeallocationCount, 1U);
    XCTAssertEqual(IDInputProbeDelegateSetCount, 0U);
}

- (void)testDetachIsIdempotentAndAllLaterForwardingIsRejected {
    IDUIKitInputControllerCapability *capability =
        [[IDUIKitInputControllerCapability alloc]
            initAdoptingPrivateController:
                [[IDInputControllerProbe alloc]
                    initWithTextLayoutController:[NSObject new]]
                                 contract:self.contract
                                 resolver:self.resolver
                                    error:nil];

    [capability detach];
    [capability detach];
    XCTAssertEqual(IDInputProbeDetachCount, 1U);
    XCTAssertThrowsSpecificNamed(
        [capability deleteBackward],
        NSException,
        NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(
        [capability textInRange:(id)[NSObject new]],
        NSException,
        NSInternalInconsistencyException);
}

@end
