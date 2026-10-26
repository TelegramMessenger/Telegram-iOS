#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "IDUIKitCapabilityResolver.h"

@interface IDUIKitResolverProbe : NSObject {
@public
    NSInteger _count;
}
+ (id)sharedObject;
- (id)objectForObject:(id)value;
- (NSInteger)lengthForObject:(id)value;
- (void)performBlock:(void (^)(void))block;
@end

@implementation IDUIKitResolverProbe

+ (id)sharedObject {
    return self;
}

- (id)objectForObject:(id)value {
    return value;
}

- (NSInteger)lengthForObject:(id)value {
    return [value length];
}

- (void)performBlock:(void (^)(void))block {
    if (block != nil) {
        block();
    }
}

@end

@interface IDUIKitMaskingRuntimeLookup :
    NSObject <IDUIKitRuntimeLookingUp>
@property(nonatomic, copy) NSSet<NSString *> *hiddenClassNames;
@property(nonatomic, copy) NSSet<NSString *> *hiddenInstanceSelectors;
@property(nonatomic, copy) NSSet<NSString *> *hiddenClassSelectors;
@property(nonatomic, copy) NSSet<NSString *> *hiddenProtocolNames;
@property(nonatomic) NSUInteger classLookupCount;
@property(nonatomic) NSUInteger protocolLookupCount;
@property(nonatomic) NSUInteger methodLookupCount;
@property(nonatomic) NSUInteger ivarLookupCount;
@end

@implementation IDUIKitMaskingRuntimeLookup

- (Class)classNamed:(NSString *)name {
    self.classLookupCount += 1;
    if ([self.hiddenClassNames containsObject:name]) {
        return Nil;
    }
    return [name isEqualToString:@"IDUIKitResolverProbe"]
        ? IDUIKitResolverProbe.class
        : Nil;
}

- (Protocol *)protocolNamed:(NSString *)name {
    self.protocolLookupCount += 1;
    if ([self.hiddenProtocolNames containsObject:name]) {
        return nil;
    }
    return [name isEqualToString:@"NSObject"]
        ? @protocol(NSObject)
        : nil;
}

- (Method)instanceMethodForClass:(Class)cls selector:(SEL)selector {
    self.methodLookupCount += 1;
    if ([self.hiddenInstanceSelectors
            containsObject:NSStringFromSelector(selector)]) {
        return NULL;
    }
    return class_getInstanceMethod(cls, selector);
}

- (Method)classMethodForClass:(Class)cls selector:(SEL)selector {
    self.methodLookupCount += 1;
    if ([self.hiddenClassSelectors
            containsObject:NSStringFromSelector(selector)]) {
        return NULL;
    }
    return class_getClassMethod(cls, selector);
}

- (Ivar)instanceVariableForClass:(Class)cls name:(NSString *)name {
    self.ivarLookupCount += 1;
    return class_getInstanceVariable(cls, name.UTF8String);
}

@end

@interface IDUIKitCapabilityResolverTests : XCTestCase
@property(nonatomic, strong) IDUIKitMaskingRuntimeLookup *lookup;
@property(nonatomic, strong) IDUIKitCapabilityResolver *resolver;
@end

@implementation IDUIKitCapabilityResolverTests

- (void)setUp {
    [super setUp];
    self.lookup = [IDUIKitMaskingRuntimeLookup new];
    self.lookup.hiddenClassNames = [NSSet set];
    self.lookup.hiddenInstanceSelectors = [NSSet set];
    self.lookup.hiddenClassSelectors = [NSSet set];
    self.lookup.hiddenProtocolNames = [NSSet set];
    self.resolver = [[IDUIKitCapabilityResolver alloc]
        initWithLookup:self.lookup];
}

- (NSDictionary<NSString *, id> *)protocolMemberWithRequired:
    (BOOL)required {
    return @{
        @"identifier": @"autoscrollEntry.protocol",
        @"class": @"NSObject",
        @"kind": @"protocol",
        @"name": @"NSObject",
        @"returnType": @"@",
        @"argumentTypes": @[],
        @"required": @(required),
        @"direction": @"outgoing",
        @"source": @"PrivateUIKit/BehaviorKernel/IDUIKitCapabilityResolver.m|NSObject",
        @"evidence": @"docs/hopper/UIKitCore-iOS26.5.md#clean-room-vertical-autoscroll-oracle",
        @"fallback": @"use-project-owned-autoscroll",
        @"teardown": @"Protocol lookup retains no runtime state.",
    };
}

- (NSDictionary<NSString *, id> *)memberWithIdentifier:
    (NSString *)identifier
                                                  kind:(NSString *)kind
                                                  name:(NSString *)name
                                            returnType:(NSString *)returnType
                                         argumentTypes:
    (NSArray<NSString *> *)argumentTypes
                                              required:(BOOL)required {
    return @{
        @"identifier": identifier,
        @"class": @"IDUIKitResolverProbe",
        @"kind": kind,
        @"name": name,
        @"returnType": returnType,
        @"argumentTypes": argumentTypes,
        @"required": @(required),
        @"direction": @"outgoing",
        @"source": [NSString stringWithFormat:
            @"PrivateUIKit/IDPrivateUIKit.m|%@", name],
        @"evidence": @"docs/hopper/UIKitCore-iOS26.5.md#minimal-private-input-kernel",
        @"fallback": @"none",
        @"teardown": @"Release with the capability owner.",
    };
}

- (IDUIKitRuntimeCapabilityContract *)contractWithMembers:
    (NSArray<NSDictionary<NSString *, id> *> *)members {
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
    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:dictionary options:0 error:&jsonError];
    XCTAssertNotNil(data);
    XCTAssertNil(jsonError);
    NSError *manifestError = nil;
    IDUIKitRuntimeManifest *manifest =
        [IDUIKitRuntimeManifest manifestWithData:data
                                           error:&manifestError];
    XCTAssertNotNil(manifest);
    XCTAssertNil(manifestError);
    return manifest.capabilities[@"inputController"];
}

- (NSArray<NSDictionary<NSString *, id> *> *)completeMembers {
    return @[
        [self memberWithIdentifier:@"input.object"
                              kind:@"instanceMethod"
                              name:@"objectForObject:"
                        returnType:@"@"
                     argumentTypes:@[@"@"]
                          required:YES],
        [self memberWithIdentifier:@"input.integer"
                              kind:@"instanceMethod"
                              name:@"lengthForObject:"
                        returnType:@"q"
                     argumentTypes:@[@"@"]
                          required:YES],
        [self memberWithIdentifier:@"input.shared"
                              kind:@"classMethod"
                              name:@"sharedObject"
                        returnType:@"@"
                     argumentTypes:@[]
                          required:YES],
        [self memberWithIdentifier:@"input.count"
                              kind:@"ivar"
                              name:@"_count"
                        returnType:@"q"
                     argumentTypes:@[]
                          required:YES],
    ];
}

- (void)testAcceptsCompleteContractWithoutInstantiatingClass {
    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:[self completeMembers]]];

    XCTAssertTrue(result.isAccepted);
    XCTAssertEqual(result.state, IDUIKitCapabilityStateAvailable);
    XCTAssertEqualObjects(result.contractIdentifier,
                          @"inputController");
    XCTAssertEqualObjects(result.mismatches, @[]);
    XCTAssertEqual(result.observedABIs.count, 4U);
    XCTAssertEqual(self.lookup.classLookupCount, 1U);
    XCTAssertEqual(self.lookup.methodLookupCount, 3U);
    XCTAssertEqual(self.lookup.ivarLookupCount, 1U);
}

- (void)testMissingClassIsUnavailableRatherThanRejectedABI {
    self.lookup.hiddenClassNames =
        [NSSet setWithObject:@"IDUIKitResolverProbe"];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:[self completeMembers]]];

    XCTAssertFalse(result.isAccepted);
    XCTAssertEqual(result.state, IDUIKitCapabilityStateUnavailable);
    XCTAssertEqual(result.mismatches.count, 1U);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"IDUIKitResolverProbe"]);
    XCTAssertEqual(self.lookup.methodLookupCount, 0U);
    XCTAssertEqual(self.lookup.ivarLookupCount, 0U);
}

- (void)testMissingRequiredSelectorIsUnavailable {
    self.lookup.hiddenInstanceSelectors =
        [NSSet setWithObject:@"objectForObject:"];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:[self completeMembers]]];

    XCTAssertFalse(result.isAccepted);
    XCTAssertEqual(result.state, IDUIKitCapabilityStateUnavailable);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"input.object"]);
}

- (void)testMissingOptionalSelectorDoesNotRejectCapability {
    self.lookup.hiddenInstanceSelectors =
        [NSSet setWithObject:@"optionalObject:"];
    NSMutableArray *members = [[self completeMembers] mutableCopy];
    [members addObject:
        [self memberWithIdentifier:@"input.optional"
                              kind:@"instanceMethod"
                              name:@"optionalObject:"
                        returnType:@"@"
                     argumentTypes:@[@"@"]
                          required:NO]];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:members]];

    XCTAssertTrue(result.isAccepted);
    XCTAssertEqual(result.state, IDUIKitCapabilityStateAvailable);
    XCTAssertEqualObjects(result.mismatches, @[]);
    XCTAssertEqualObjects(result.observedABIs[@"input.optional"],
                          @"<missing optional>");
}

- (void)testClassUsedOnlyByOptionalMemberMayBeMissing {
    self.lookup.hiddenClassNames =
        [NSSet setWithObject:@"IDUIKitResolverProbe"];
    NSArray *members = @[
        [self memberWithIdentifier:@"input.optional"
                              kind:@"instanceMethod"
                              name:@"optionalObject:"
                        returnType:@"@"
                     argumentTypes:@[@"@"]
                          required:NO],
    ];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:members]];

    XCTAssertTrue(result.isAccepted);
    XCTAssertEqual(result.state, IDUIKitCapabilityStateAvailable);
    XCTAssertEqualObjects(result.mismatches, @[]);
    XCTAssertEqualObjects(result.observedABIs[@"input.optional"],
                          @"<missing optional>");
}

- (void)testWrongReturnABIRejectsCompleteCapability {
    NSMutableArray *members = [[self completeMembers] mutableCopy];
    members[0] =
        [self memberWithIdentifier:@"input.object"
                              kind:@"instanceMethod"
                              name:@"objectForObject:"
                        returnType:@"v"
                     argumentTypes:@[@"@"]
                          required:YES];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:members]];

    XCTAssertFalse(result.isAccepted);
    XCTAssertEqual(result.state,
                   IDUIKitCapabilityStateRejectedContract);
    XCTAssertEqual(result.mismatches.count, 1U);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"input.object"]);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"expected return v"]);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"observed return @"]);
}

- (void)testWrongScalarWidthRejectsCapability {
    NSMutableArray *members = [[self completeMembers] mutableCopy];
    members[1] =
        [self memberWithIdentifier:@"input.integer"
                              kind:@"instanceMethod"
                              name:@"lengthForObject:"
                        returnType:@"i"
                     argumentTypes:@[@"@"]
                          required:YES];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:members]];

    XCTAssertEqual(result.state,
                   IDUIKitCapabilityStateRejectedContract);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"expected return i"]);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"observed return q"]);
}

- (void)testBlockArgumentDoesNotMatchObjectContract {
    NSArray *members = @[
        [self memberWithIdentifier:@"input.block"
                              kind:@"instanceMethod"
                              name:@"performBlock:"
                        returnType:@"v"
                     argumentTypes:@[@"@"]
                          required:YES],
    ];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:members]];

    XCTAssertEqual(result.state,
                   IDUIKitCapabilityStateRejectedContract);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"argument 0 expected @"]);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"observed @?"]);
}

- (void)testQualifiedObjectReturnMatchesObjectContract {
    NSArray *members = @[
        [self memberWithIdentifier:@"input.object"
                              kind:@"instanceMethod"
                              name:@"objectForObject:"
                        returnType:@"@"
                     argumentTypes:@[@"@"]
                          required:YES],
    ];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:members]];

    XCTAssertTrue(result.isAccepted);
}

- (void)testReportsAllABIMismatchesInManifestOrder {
    NSArray *members = @[
        [self memberWithIdentifier:@"first"
                              kind:@"instanceMethod"
                              name:@"objectForObject:"
                        returnType:@"v"
                     argumentTypes:@[@"@"]
                          required:YES],
        [self memberWithIdentifier:@"second"
                              kind:@"instanceMethod"
                              name:@"lengthForObject:"
                        returnType:@"i"
                     argumentTypes:@[@"@"]
                          required:YES],
    ];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:members]];

    XCTAssertEqual(result.mismatches.count, 2U);
    XCTAssertTrue([result.mismatches[0] hasPrefix:@"first:"]);
    XCTAssertTrue([result.mismatches[1] hasPrefix:@"second:"]);
}

- (void)testFindsRequiredProtocolWithoutClassOrMethodLookup {
    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:@[
                [self protocolMemberWithRequired:YES],
            ]]];

    XCTAssertTrue(result.isAccepted);
    XCTAssertEqual(result.state, IDUIKitCapabilityStateAvailable);
    XCTAssertEqualObjects(
        result.observedABIs[@"autoscrollEntry.protocol"],
        @"protocol=NSObject");
    XCTAssertEqual(self.lookup.protocolLookupCount, 1U);
    XCTAssertEqual(self.lookup.classLookupCount, 0U);
    XCTAssertEqual(self.lookup.methodLookupCount, 0U);
    XCTAssertEqual(self.lookup.ivarLookupCount, 0U);
    XCTAssertEqual(
        [self.resolver protocolNamed:@"NSObject"],
        @protocol(NSObject));
}

- (void)testMissingRequiredProtocolIsUnavailable {
    self.lookup.hiddenProtocolNames = [NSSet setWithObject:@"NSObject"];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:@[
                [self protocolMemberWithRequired:YES],
            ]]];

    XCTAssertFalse(result.isAccepted);
    XCTAssertEqual(result.state, IDUIKitCapabilityStateUnavailable);
    XCTAssertEqual(result.mismatches.count, 1U);
    XCTAssertTrue([result.mismatches.firstObject
        containsString:@"Protocol NSObject is unavailable"]);
    XCTAssertEqual(self.lookup.protocolLookupCount, 1U);
    XCTAssertEqual(self.lookup.classLookupCount, 0U);
}

- (void)testMissingOptionalProtocolIsRecordedWithoutRejecting {
    self.lookup.hiddenProtocolNames = [NSSet setWithObject:@"NSObject"];

    IDUIKitContractResult *result =
        [self.resolver evaluateContract:
            [self contractWithMembers:@[
                [self protocolMemberWithRequired:NO],
            ]]];

    XCTAssertTrue(result.isAccepted);
    XCTAssertEqualObjects(
        result.observedABIs[@"autoscrollEntry.protocol"],
        @"<missing optional>");
}

@end
