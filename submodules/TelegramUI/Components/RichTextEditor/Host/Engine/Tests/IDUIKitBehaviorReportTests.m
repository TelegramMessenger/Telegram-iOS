#import <XCTest/XCTest.h>

#import "IDUIKitBehaviorReport.h"

@interface IDUIKitBehaviorReportTests : XCTestCase
@end

@implementation IDUIKitBehaviorReportTests

- (IDUIKitCapabilityReport *)reportWithIdentifier:(NSString *)identifier
                                             state:(IDUIKitCapabilityState)state {
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:identifier
                     state:state
           requiredMembers:@[@"member.z", @"member.a"]
              observedABIs:@{
                  @"member.z": @"return=v; arguments=()",
                  @"member.a": @"return=@; arguments=(@)",
              }
              dependencies:@[@"dependency.z", @"dependency.a"]
                  fallback:@"disable-capability"
           rejectionReason:state == IDUIKitCapabilityStateRejectedContract
               ? @"member.a: expected @, observed q"
               : nil];
}

- (void)testNormalizesAllCapabilityStatesInStableOrder {
    NSArray<NSNumber *> *states = @[
        @(IDUIKitCapabilityStateUnavailable),
        @(IDUIKitCapabilityStateRejectedContract),
        @(IDUIKitCapabilityStateAvailable),
        @(IDUIKitCapabilityStateActive),
        @(IDUIKitCapabilityStateProjectOwned),
    ];
    NSArray<NSString *> *names = @[
        @"unavailable",
        @"rejectedContract",
        @"available",
        @"active",
        @"projectOwned",
    ];

    for (NSUInteger index = 0; index < states.count; index += 1) {
        IDUIKitCapabilityReport *report =
            [self reportWithIdentifier:
                [NSString stringWithFormat:@"capability.%lu",
                 (unsigned long)index]
                                  state:states[index].unsignedIntegerValue];
        XCTAssertEqualObjects(
            report.normalizedDictionary[@"state"],
            names[index]);
    }
    XCTAssertGreaterThan(
        IDUIKitCapabilityStateProjectOwned,
        IDUIKitCapabilityStateActive);
}

- (void)testCapabilityNormalizationIsStableAndValueBased {
    IDUIKitCapabilityReport *left = [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:@"inputController"
                     state:IDUIKitCapabilityStateRejectedContract
           requiredMembers:@[@"input.z", @"input.a"]
              observedABIs:@{
                  @"input.z": @"return=v; arguments=()",
                  @"input.a": @"return=@; arguments=(@)",
              }
              dependencies:@[@"typingAttributes", @"interaction"]
                  fallback:@"use-public-input"
           rejectionReason:@"input.a: expected @, observed q"];
    IDUIKitCapabilityReport *right = [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:@"inputController"
                     state:IDUIKitCapabilityStateRejectedContract
           requiredMembers:@[@"input.a", @"input.z"]
              observedABIs:@{
                  @"input.a": @"return=@; arguments=(@)",
                  @"input.z": @"return=v; arguments=()",
              }
              dependencies:@[@"interaction", @"typingAttributes"]
                  fallback:@"use-public-input"
           rejectionReason:@"input.a: expected @, observed q"];

    NSDictionary *normalized = left.normalizedDictionary;
    XCTAssertEqualObjects(normalized[@"identifier"], @"inputController");
    XCTAssertEqualObjects(normalized[@"requiredMembers"],
                          (@[@"input.a", @"input.z"]));
    XCTAssertEqualObjects(normalized[@"dependencies"],
                          (@[@"interaction", @"typingAttributes"]));
    XCTAssertEqualObjects(normalized[@"fallback"], @"use-public-input");
    XCTAssertEqualObjects(normalized[@"rejectionReason"],
                          @"input.a: expected @, observed q");
    XCTAssertEqualObjects(left, right);
    XCTAssertEqual(left.hash, right.hash);
    XCTAssertEqualObjects(left.normalizedDictionary,
                          right.normalizedDictionary);

    NSData *leftJSON = [NSJSONSerialization
        dataWithJSONObject:left.normalizedDictionary
                   options:NSJSONWritingSortedKeys
                     error:nil];
    NSData *rightJSON = [NSJSONSerialization
        dataWithJSONObject:right.normalizedDictionary
                   options:NSJSONWritingSortedKeys
                     error:nil];
    XCTAssertEqualObjects(leftJSON, rightJSON);
}

- (void)testCapabilityActivationCreatesANewOneWaySnapshot {
    IDUIKitCapabilityReport *available =
        [self reportWithIdentifier:@"interaction"
                             state:IDUIKitCapabilityStateAvailable];
    IDUIKitCapabilityReport *active = [available reportByActivating];

    XCTAssertNotEqual(available, active);
    XCTAssertEqual(available.state, IDUIKitCapabilityStateAvailable);
    XCTAssertEqual(active.state, IDUIKitCapabilityStateActive);
    XCTAssertEqualObjects(available.identifier, active.identifier);
    XCTAssertEqualObjects(available.requiredMembers,
                          active.requiredMembers);
    XCTAssertEqualObjects(available.observedABIs,
                          active.observedABIs);
    XCTAssertEqualObjects(active, [active reportByActivating]);
}

- (void)testTerminalCapabilityStatesRejectActivation {
    for (NSNumber *state in @[
             @(IDUIKitCapabilityStateUnavailable),
             @(IDUIKitCapabilityStateRejectedContract),
             @(IDUIKitCapabilityStateProjectOwned),
         ]) {
        IDUIKitCapabilityReport *report =
            [self reportWithIdentifier:@"terminal"
                                 state:state.unsignedIntegerValue];
        XCTAssertThrowsSpecificNamed(
            [report reportByActivating],
            NSException,
            NSInternalInconsistencyException);
    }
}

- (void)testProjectOwnedCapabilityReportRemainsAnImmutableSnapshot {
    NSMutableArray<NSString *> *members =
        [NSMutableArray arrayWithObject:@"autoscrollEntry.protocol"];
    NSMutableDictionary<NSString *, NSString *> *observed =
        [@{@"autoscrollEntry.protocol":
               @"protocol=UITextAutoscrolling"} mutableCopy];
    IDUIKitCapabilityReport *report =
        [[IDUIKitCapabilityReport alloc]
            initWithIdentifier:@"autoscroll"
                         state:IDUIKitCapabilityStateProjectOwned
               requiredMembers:members
                  observedABIs:observed
                  dependencies:@[]
                      fallback:@"use-project-owned-autoscroll"
               rejectionReason:nil];

    [members addObject:@"mutated"];
    observed[@"mutated"] = @"mutated";

    XCTAssertEqualObjects(
        report.normalizedDictionary[@"state"],
        @"projectOwned");
    XCTAssertEqualObjects(
        report.requiredMembers,
        (@[@"autoscrollEntry.protocol"]));
    XCTAssertEqualObjects(
        report.observedABIs,
        (@{@"autoscrollEntry.protocol":
               @"protocol=UITextAutoscrolling"}));
    XCTAssertThrowsSpecificNamed(
        [report reportByActivating],
        NSException,
        NSInternalInconsistencyException);
}

- (void)testAggregateNormalizationSortsCapabilitiesAndPreservesDetachedState {
    IDUIKitCapabilityReport *zeta =
        [self reportWithIdentifier:@"zeta"
                             state:IDUIKitCapabilityStateAvailable];
    IDUIKitCapabilityReport *alpha =
        [self reportWithIdentifier:@"alpha"
                             state:IDUIKitCapabilityStateActive];
    IDUIKitBehaviorReport *report = [[IDUIKitBehaviorReport alloc]
        initWithOSVersion:@"26.5"
                  osBuild:@"23F73"
              capabilities:@[zeta, alpha]
                  detached:NO];

    NSDictionary *normalized = report.normalizedDictionary;
    XCTAssertEqualObjects(normalized[@"osVersion"], @"26.5");
    XCTAssertEqualObjects(normalized[@"osBuild"], @"23F73");
    XCTAssertEqualObjects(normalized[@"detached"], @NO);
    NSArray<NSDictionary *> *capabilities = normalized[@"capabilities"];
    XCTAssertEqualObjects(capabilities[0][@"identifier"], @"alpha");
    XCTAssertEqualObjects(capabilities[1][@"identifier"], @"zeta");

    IDUIKitBehaviorReport *detached =
        [report reportByMarkingDetached];
    XCTAssertFalse(report.isDetached);
    XCTAssertTrue(detached.isDetached);
    XCTAssertNotEqual(report, detached);
    XCTAssertEqualObjects(detached,
                          [detached reportByMarkingDetached]);
}

- (void)testAggregateEqualityIgnoresCapabilityInsertionOrder {
    IDUIKitCapabilityReport *alpha =
        [self reportWithIdentifier:@"alpha"
                             state:IDUIKitCapabilityStateAvailable];
    IDUIKitCapabilityReport *zeta =
        [self reportWithIdentifier:@"zeta"
                             state:IDUIKitCapabilityStateActive];
    IDUIKitBehaviorReport *left = [[IDUIKitBehaviorReport alloc]
        initWithOSVersion:@"26.5"
                  osBuild:@"23F73"
              capabilities:@[zeta, alpha]
                  detached:YES];
    IDUIKitBehaviorReport *right = [[IDUIKitBehaviorReport alloc]
        initWithOSVersion:@"26.5"
                  osBuild:@"23F73"
              capabilities:@[alpha, zeta]
                  detached:YES];

    XCTAssertEqualObjects(left, right);
    XCTAssertEqual(left.hash, right.hash);
    XCTAssertEqualObjects(left.normalizedDictionary,
                          right.normalizedDictionary);
}

@end
