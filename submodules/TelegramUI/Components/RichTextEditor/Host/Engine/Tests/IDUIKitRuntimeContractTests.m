#import <XCTest/XCTest.h>

#import "IDUIKitRuntimeContract.h"

@interface IDUIKitRuntimeContractTests : XCTestCase
@end

@implementation IDUIKitRuntimeContractTests

- (NSMutableDictionary<NSString *, id> *)validManifestDictionary {
    return [@{
        @"schema": @1,
        @"runtime": [@{
            @"osVersion": @"26.5",
            @"osBuild": @"23F73",
        } mutableCopy],
        @"capabilities": [@{
            @"inputController": [@{
                @"mandatory": @YES,
                @"dependencies": @[],
                @"fallback": @"none",
                @"members": [@[
                    [@{
                        @"identifier": @"inputController.constructor",
                        @"class": @"IDFakeInputController",
                        @"kind": @"instanceMethod",
                        @"name": @"initWithTextLayoutController:",
                        @"returnType": @"@",
                        @"argumentTypes": @[@"@"],
                        @"required": @YES,
                        @"direction": @"outgoing",
                        @"source": @"PrivateUIKit/IDPrivateUIKit.m|initWithTextLayoutController:",
                        @"evidence": @"docs/hopper/UIKitCore-iOS26.5.md#minimal-private-input-kernel",
                        @"fallback": @"none",
                        @"teardown": @"Detach the controller before releasing the layout adapter.",
                    } mutableCopy],
                    [@{
                        @"identifier": @"inputController.delegate",
                        @"class": @"IDFakeInputController",
                        @"kind": @"instanceMethod",
                        @"name": @"setDelegate:",
                        @"returnType": @"v",
                        @"argumentTypes": @[@"@"],
                        @"required": @YES,
                        @"direction": @"outgoing",
                        @"source": @"PrivateUIKit/IDPrivateUIKit.m|setDelegate:",
                        @"evidence": @"docs/hopper/UIKitCore-iOS26.5.md#minimal-private-input-kernel",
                        @"fallback": @"none",
                        @"teardown": @"Release with the controller.",
                    } mutableCopy],
                ] mutableCopy],
            } mutableCopy],
        } mutableCopy],
        @"referenceOnly": [NSMutableDictionary dictionary],
        @"forbidden": [@[@"_UITextKit2LayoutController"] mutableCopy],
    } mutableCopy];
}

- (NSData *)dataForDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary
                                                   options:0
                                                     error:&error];
    XCTAssertNotNil(data);
    XCTAssertNil(error);
    return data;
}

- (NSMutableDictionary<NSString *, id> *)autoscrollProtocolMember {
    return [@{
        @"identifier": @"autoscrollEntry.protocol",
        @"class": @"UITextAutoscrolling",
        @"kind": @"protocol",
        @"name": @"UITextAutoscrolling",
        @"returnType": @"@",
        @"argumentTypes": @[],
        @"required": @YES,
        @"direction": @"outgoing",
        @"source": @"PrivateUIKit/BehaviorKernel/IDUIKitCapabilityResolver.m|UITextAutoscrolling",
        @"evidence": @"docs/hopper/UIKitCore-iOS26.5.md#clean-room-vertical-autoscroll-oracle",
        @"fallback": @"use-project-owned-autoscroll",
        @"teardown": @"Protocol lookup retains no runtime state.",
    } mutableCopy];
}

- (void)testParsesStrictCapabilityManifest {
    NSError *error = nil;
    IDUIKitRuntimeManifest *manifest =
        [IDUIKitRuntimeManifest
            manifestWithData:[self dataForDictionary:
                [self validManifestDictionary]]
                       error:&error];

    XCTAssertNotNil(manifest);
    XCTAssertNil(error);
    XCTAssertEqual(manifest.schemaVersion, 1);
    XCTAssertEqualObjects(manifest.osVersion, @"26.5");
    XCTAssertEqualObjects(manifest.osBuild, @"23F73");
    XCTAssertEqual(manifest.capabilities.count, 1U);
    XCTAssertEqual(
        manifest.capabilities[@"inputController"].capability,
        IDUIKitBehaviorCapabilityInputController);
    XCTAssertTrue(
        manifest.capabilities[@"inputController"].isMandatory);
    XCTAssertEqual(
        manifest.capabilities[@"inputController"].members.count,
        2U);
    IDUIKitRuntimeMemberContract *constructor =
        manifest.capabilities[@"inputController"].members.firstObject;
    XCTAssertEqualObjects(constructor.direction, @"outgoing");
    XCTAssertEqualObjects(
        constructor.source,
        @"PrivateUIKit/IDPrivateUIKit.m|initWithTextLayoutController:");
    XCTAssertTrue([constructor.evidence
        hasPrefix:@"docs/hopper/UIKitCore-iOS26.5.md#"]);
    XCTAssertEqualObjects(constructor.fallback, @"none");
    XCTAssertTrue(constructor.teardown.length > 0);
    XCTAssertEqual(manifest.referenceOnly.count, 0U);
    XCTAssertEqualObjects(
        manifest.forbiddenSymbols,
        (@[@"_UITextKit2LayoutController"]));
}

- (void)testRejectsUnknownRootKey {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    dictionary[@"surprise"] = @YES;
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertEqualObjects(error.domain,
                          IDUIKitRuntimeContractErrorDomain);
    XCTAssertTrue([error.localizedDescription
        containsString:@"surprise"]);
}

- (void)testRejectsDuplicateMemberIdentifier {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *capability =
        dictionary[@"capabilities"][@"inputController"];
    NSMutableArray *members = capability[@"members"];
    NSMutableDictionary *duplicate =
        [members.firstObject mutableCopy];
    duplicate[@"name"] = @"other:";
    [members addObject:duplicate];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription
        containsString:@"inputController.constructor"]);
}

- (void)testRejectsMissingRuntimeBuild {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    [dictionary[@"runtime"] removeObjectForKey:@"osBuild"];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription
        containsString:@"osBuild"]);
}

- (void)testRejectsUnknownCapabilityName {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    dictionary[@"capabilities"][@"unknownBehavior"] =
        dictionary[@"capabilities"][@"inputController"];
    [dictionary[@"capabilities"]
        removeObjectForKey:@"inputController"];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription
        containsString:@"unknownBehavior"]);
}

- (void)testRejectsSelectorWhoseColonCountDiffersFromArguments {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *member =
        dictionary[@"capabilities"][@"inputController"]
                  [@"members"][0];
    member[@"argumentTypes"] = @[];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription
        containsString:@"initWithTextLayoutController:"]);
}

- (void)testObjectABIRejectsBlockABI {
    XCTAssertTrue(IDUIKitRuntimeTypeEncodingMatches("@\"NSString\"",
                                                    @"@"));
    XCTAssertFalse(IDUIKitRuntimeTypeEncodingMatches("@?", @"@"));
    XCTAssertTrue(IDUIKitRuntimeTypeEncodingMatches("@?", @"@?"));
}

- (void)testAllowsRepeatedObjectArgumentTypes {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *member =
        dictionary[@"capabilities"][@"inputController"]
                  [@"members"][0];
    member[@"name"] = @"replaceRange:withText:";
    member[@"argumentTypes"] = @[@"@", @"@"];
    NSError *error = nil;

    IDUIKitRuntimeManifest *manifest =
        [IDUIKitRuntimeManifest
            manifestWithData:[self dataForDictionary:dictionary]
                       error:&error];

    XCTAssertNotNil(manifest);
    XCTAssertNil(error);
    XCTAssertEqualObjects(
        manifest.capabilities[@"inputController"]
                .members.firstObject.argumentTypes,
        (@[@"@", @"@"]));
}

- (void)testRejectsMalformedTypeEncoding {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *member =
        dictionary[@"capabilities"][@"inputController"]
                  [@"members"][0];
    member[@"returnType"] = @"^";
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription
        containsString:@"returnType"]);
}

- (void)testRejectsMalformedJSON {
    NSData *data = [@"{\"schema\":" dataUsingEncoding:
        NSUTF8StringEncoding];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest manifestWithData:data
                                                    error:&error]);
    XCTAssertEqualObjects(error.domain,
                          IDUIKitRuntimeContractErrorDomain);
}

- (void)testRejectsMemberWithoutAuditProvenance {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *member =
        dictionary[@"capabilities"][@"inputController"]
                  [@"members"][0];
    [member removeObjectForKey:@"evidence"];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription
        containsString:@"evidence"]);
}

- (void)testParsesProtocolMemberWithCanonicalShape {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *capability =
        dictionary[@"capabilities"][@"inputController"];
    capability[@"members"] = @[[self autoscrollProtocolMember]];
    NSError *error = nil;

    IDUIKitRuntimeManifest *manifest =
        [IDUIKitRuntimeManifest
            manifestWithData:[self dataForDictionary:dictionary]
                       error:&error];

    XCTAssertNotNil(manifest);
    XCTAssertNil(error);
    IDUIKitRuntimeMemberContract *member =
        manifest.capabilities[@"inputController"].members.firstObject;
    XCTAssertEqual(member.kind, IDUIKitPrivateMemberKindProtocol);
    XCTAssertEqualObjects(member.className, @"UITextAutoscrolling");
    XCTAssertEqualObjects(member.name, @"UITextAutoscrolling");
    XCTAssertEqualObjects(member.returnType, @"@");
    XCTAssertEqualObjects(member.argumentTypes, @[]);
}

- (void)testRejectsProtocolMemberWithArguments {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *member = [self autoscrollProtocolMember];
    member[@"argumentTypes"] = @[@"@"];
    dictionary[@"capabilities"][@"inputController"][@"members"] = @[member];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription containsString:@"protocol"]);
    XCTAssertTrue([error.localizedDescription containsString:@"arguments"]);
}

- (void)testRejectsProtocolMemberWithNonObjectReturn {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *member = [self autoscrollProtocolMember];
    member[@"returnType"] = @"v";
    dictionary[@"capabilities"][@"inputController"][@"members"] = @[member];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription containsString:@"protocol"]);
    XCTAssertTrue([error.localizedDescription containsString:@"return"]);
}

- (void)testRejectsProtocolMemberWhoseClassAndNameDiffer {
    NSMutableDictionary *dictionary = [self validManifestDictionary];
    NSMutableDictionary *member = [self autoscrollProtocolMember];
    member[@"name"] = @"DifferentProtocol";
    dictionary[@"capabilities"][@"inputController"][@"members"] = @[member];
    NSError *error = nil;

    XCTAssertNil([IDUIKitRuntimeManifest
        manifestWithData:[self dataForDictionary:dictionary]
                   error:&error]);
    XCTAssertTrue([error.localizedDescription containsString:@"protocol"]);
    XCTAssertTrue([error.localizedDescription containsString:@"class"]);
    XCTAssertTrue([error.localizedDescription containsString:@"name"]);
}

@end
