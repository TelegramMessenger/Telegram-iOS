#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "IDUIKitAutoscrollEntryCapability.h"

static void IDEntryStart(id self, SEL command, CGPoint point) {
    (void)self;
    (void)command;
    (void)point;
}

static NSInteger IDEntryWrongStart(
    id self, SEL command, CGPoint point) {
    (void)self;
    (void)command;
    (void)point;
    return 0;
}

static void IDEntryCancel(id self, SEL command) {
    (void)self;
    (void)command;
}

static NSInteger IDEntryWrongCancel(id self, SEL command) {
    (void)self;
    (void)command;
    return 0;
}

static Protocol *IDEntryTestProtocol(void) {
    static Protocol *protocol;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *name = @"IDUITextAutoscrollingTestProtocol";
        protocol = NSProtocolFromString(name);
        if (protocol == nil) {
            protocol = objc_allocateProtocol(name.UTF8String);
            objc_registerProtocol(protocol);
        }
    });
    return protocol;
}

@interface IDEntryLookup : NSObject <IDUIKitRuntimeLookingUp>
@property(nonatomic) Class viewClass;
@property(nonatomic, strong, nullable) Protocol *resolvedProtocol;
@end

@implementation IDEntryLookup
- (Class)classNamed:(NSString *)name {
    return [name isEqualToString:NSStringFromClass(self.viewClass)]
        ? self.viewClass
        : Nil;
}
- (Protocol *)protocolNamed:(NSString *)name {
    return [name isEqualToString:
        NSStringFromProtocol(IDEntryTestProtocol())]
        ? self.resolvedProtocol
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

@interface IDRejectingAutoscrollEntryCapability :
    IDUIKitAutoscrollEntryCapability
@end

@implementation IDRejectingAutoscrollEntryCapability
- (BOOL)adoptProtocol:(Protocol *)protocol
              onClass:(Class)viewClass {
    (void)protocol;
    (void)viewClass;
    return NO;
}
@end

@interface IDUIKitAutoscrollEntryCapabilityTests : XCTestCase
@property(nonatomic, strong) IDEntryLookup *lookup;
@property(nonatomic, strong) IDUIKitCapabilityResolver *resolver;
@end

@implementation IDUIKitAutoscrollEntryCapabilityTests

- (void)setUp {
    [super setUp];
    self.lookup = [IDEntryLookup new];
    self.lookup.resolvedProtocol = IDEntryTestProtocol();
    self.resolver = [[IDUIKitCapabilityResolver alloc]
        initWithLookup:self.lookup];
}

- (Class)createViewClassWithStartReturn:(const char *)startReturn
                            cancelReturn:(const char *)cancelReturn {
    static NSUInteger serial;
    NSString *name = [NSString stringWithFormat:
        @"IDAutoscrollEntryView%lu", (unsigned long)++serial];
    Class cls = objc_allocateClassPair(
        UIView.class, name.UTF8String, 0);
    NSString *startEncoding = [NSString stringWithFormat:
        @"%s@:%s", startReturn, @encode(CGPoint)];
    class_addMethod(
        cls,
        @selector(startAutoscroll:),
        startReturn[0] == 'v'
            ? (IMP)IDEntryStart
            : (IMP)IDEntryWrongStart,
        startEncoding.UTF8String);
    NSString *cancelEncoding = [NSString stringWithFormat:
        @"%s@:", cancelReturn];
    class_addMethod(
        cls,
        @selector(cancelAutoscroll),
        cancelReturn[0] == 'v'
            ? (IMP)IDEntryCancel
            : (IMP)IDEntryWrongCancel,
        cancelEncoding.UTF8String);
    objc_registerClassPair(cls);
    return cls;
}

- (IDUIKitRuntimeCapabilityContract *)contractForClass:(Class)viewClass {
    NSString *protocolName =
        NSStringFromProtocol(IDEntryTestProtocol());
    NSDictionary *audit = @{
        @"required": @YES,
        @"direction": @"incoming",
        @"source": @"PrivateUIKit/BehaviorKernel/IDUIKitAutoscrollEntryCapability.m|entry",
        @"evidence": @"docs/hopper/UIKitCore-iOS26.5.md#clean-room-vertical-autoscroll-oracle",
        @"fallback": @"vertical edge autoscroll disabled",
        @"teardown": @"No retained runtime state.",
    };
    NSMutableDictionary *(^member)(
        NSString *, NSString *, NSString *, NSString *, NSArray *) =
        ^NSMutableDictionary *(
            NSString *identifier,
            NSString *className,
            NSString *kind,
            NSString *name,
            NSArray *arguments) {
            NSMutableDictionary *result = [audit mutableCopy];
            [result addEntriesFromDictionary:@{
                @"identifier": identifier,
                @"class": className,
                @"kind": kind,
                @"name": name,
                @"returnType": @"v",
                @"argumentTypes": arguments,
            }];
            return result;
        };
    NSMutableDictionary *protocolMember = member(
        @"autoscrollEntry.protocol",
        protocolName,
        @"protocol",
        protocolName,
        @[]);
    protocolMember[@"returnType"] = @"@";
    NSDictionary *dictionary = @{
        @"schema": @1,
        @"runtime": @{
            @"osVersion": @"26.5",
            @"osBuild": @"23F73",
        },
        @"capabilities": @{
            @"autoscrollEntry": @{
                @"mandatory": @NO,
                @"dependencies": @[],
                @"fallback": @"vertical edge autoscroll disabled",
                @"members": @[
                    protocolMember,
                    member(
                        @"autoscrollEntry.start",
                        NSStringFromClass(viewClass),
                        @"incomingCallback",
                        @"startAutoscroll:",
                        @[@"{CGPoint=dd}"]),
                    member(
                        @"autoscrollEntry.cancel",
                        NSStringFromClass(viewClass),
                        @"incomingCallback",
                        @"cancelAutoscroll",
                        @[]),
                ],
            },
        },
        @"referenceOnly": @{},
        @"forbidden": @[],
    };
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:dictionary options:0 error:nil];
    NSError *error = nil;
    IDUIKitRuntimeManifest *manifest =
        [IDUIKitRuntimeManifest manifestWithData:data error:&error];
    XCTAssertNotNil(manifest);
    XCTAssertNil(error);
    return manifest.capabilities[@"autoscrollEntry"];
}

- (IDUIKitAutoscrollEntryCapability *)capabilityForClass:
    (Class)viewClass
                                                    type:
    (Class)capabilityClass {
    self.lookup.viewClass = viewClass;
    return [[capabilityClass alloc]
        initWithContract:[self contractForClass:viewClass]
                resolver:self.resolver
               viewClass:viewClass];
}

- (void)testCompleteEntryContractAdoptsProtocolAndActivates {
    Class viewClass =
        [self createViewClassWithStartReturn:"v" cancelReturn:"v"];

    IDUIKitAutoscrollEntryCapability *capability =
        [self capabilityForClass:viewClass
                            type:IDUIKitAutoscrollEntryCapability.class];

    XCTAssertTrue(capability.isActive);
    XCTAssertEqual(
        capability.report.state,
        IDUIKitCapabilityStateActive);
    XCTAssertTrue(class_conformsToProtocol(
        viewClass, IDEntryTestProtocol()));
}

- (void)testMissingProtocolDoesNotMutateClass {
    Class viewClass =
        [self createViewClassWithStartReturn:"v" cancelReturn:"v"];
    self.lookup.resolvedProtocol = nil;

    IDUIKitAutoscrollEntryCapability *capability =
        [self capabilityForClass:viewClass
                            type:IDUIKitAutoscrollEntryCapability.class];

    XCTAssertFalse(capability.isActive);
    XCTAssertEqual(
        capability.report.state,
        IDUIKitCapabilityStateUnavailable);
    XCTAssertFalse(class_conformsToProtocol(
        viewClass, IDEntryTestProtocol()));
}

- (void)testWrongStartABIDoesNotMutateClass {
    Class viewClass =
        [self createViewClassWithStartReturn:"q" cancelReturn:"v"];

    IDUIKitAutoscrollEntryCapability *capability =
        [self capabilityForClass:viewClass
                            type:IDUIKitAutoscrollEntryCapability.class];

    XCTAssertFalse(capability.isActive);
    XCTAssertEqual(
        capability.report.state,
        IDUIKitCapabilityStateRejectedContract);
    XCTAssertFalse(class_conformsToProtocol(
        viewClass, IDEntryTestProtocol()));
}

- (void)testWrongCancelABIDoesNotMutateClass {
    Class viewClass =
        [self createViewClassWithStartReturn:"v" cancelReturn:"q"];

    IDUIKitAutoscrollEntryCapability *capability =
        [self capabilityForClass:viewClass
                            type:IDUIKitAutoscrollEntryCapability.class];

    XCTAssertFalse(capability.isActive);
    XCTAssertEqual(
        capability.report.state,
        IDUIKitCapabilityStateRejectedContract);
    XCTAssertFalse(class_conformsToProtocol(
        viewClass, IDEntryTestProtocol()));
}

- (void)testAdoptionFailureProducesRejectedReport {
    Class viewClass =
        [self createViewClassWithStartReturn:"v" cancelReturn:"v"];

    IDUIKitAutoscrollEntryCapability *capability =
        [self capabilityForClass:viewClass
                            type:IDRejectingAutoscrollEntryCapability.class];

    XCTAssertFalse(capability.isActive);
    XCTAssertEqual(
        capability.report.state,
        IDUIKitCapabilityStateRejectedContract);
    XCTAssertFalse(class_conformsToProtocol(
        viewClass, IDEntryTestProtocol()));
}

@end
