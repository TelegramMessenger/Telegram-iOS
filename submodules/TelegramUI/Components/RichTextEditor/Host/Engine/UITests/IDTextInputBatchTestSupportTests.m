#import "IDTextInputBatchTestSupport.h"
#import "IDIMECompositionLifecycleTestSupport.h"
#import "IDInlinePredictionLifecycleTestSupport.h"

#include <stdlib.h>

@interface IDTextInputBatchTestSupportTests : XCTestCase
@end

@interface IDTextInputIssueCapturingTestCase : XCTestCase
@property(nonatomic, strong) NSMutableArray<XCTIssue *> *capturedIssues;
@property(nonatomic, strong) NSMutableArray<XCTAttachment *> *capturedAttachments;
@end

@implementation IDTextInputIssueCapturingTestCase
- (instancetype)init {
    self = [super init];
    if (self) {
        _capturedIssues = [NSMutableArray array];
        _capturedAttachments = [NSMutableArray array];
    }
    return self;
}
- (void)recordIssue:(XCTIssue *)issue {
    [self.capturedIssues addObject:issue];
}
- (void)addAttachment:(XCTAttachment *)attachment {
    [self.capturedAttachments addObject:attachment];
}
@end

@implementation IDTextInputBatchTestSupportTests

- (NSData *)catalogDataWithRows:(NSArray<NSString *> *)rows
                         groups:(NSArray<NSDictionary *> *)groups {
    NSDictionary *catalog = @{
        @"schema": @1,
        @"runtime": @{@"osVersion": @"26.5", @"osBuild": @"23F73"},
        @"udid": @"FA6F7462-AA97-42FE-9E57-8DA0593CE756",
        @"subsystem": @"autocorrection",
        @"rows": rows,
        @"groups": groups,
    };
    return [NSJSONSerialization dataWithJSONObject:catalog options:0 error:nil];
}

- (NSData *)catalogDataWithGroups:(NSArray<NSDictionary *> *)groups {
    return [self catalogDataWithRows:@[@"interior-accept-space"]
                              groups:groups];
}

- (NSData *)validCatalogData {
    return [self catalogDataWithGroups:@[@{
        @"id": @"ordinary-accept",
        @"language": @"en-US",
        @"rows": @[@"interior-accept-space"],
        @"stateSensitive": @NO,
        @"resetPolicy": @"erase-reset-learning-provision",
    }]];
}

- (NSData *)inlinePredictionCatalogData {
    NSDictionary *catalog = @{
        @"schema": @1,
        @"runtime": @{@"osVersion": @"26.5", @"osBuild": @"23F73"},
        @"udid": @"FA6F7462-AA97-42FE-9E57-8DA0593CE756",
        @"subsystem": @"inline-prediction",
        @"rows": @[@"interior-accept", @"interior-reject"],
        @"groups": @[@{
            @"id": @"interior",
            @"language": @"en-US",
            @"rows": @[@"interior-accept", @"interior-reject"],
            @"stateSensitive": @YES,
            @"resetPolicy": @"erase-reset-learning-provision",
        }],
    };
    return [NSJSONSerialization dataWithJSONObject:catalog
        options:0 error:nil];
}

- (NSURL *)temporaryHandshakeRoot {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
        NSUUID.UUID.UUIDString];
    NSURL *URL = [NSURL fileURLWithPath:path isDirectory:YES];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:URL
        withIntermediateDirectories:YES attributes:nil error:nil]);
    [self addTeardownBlock:^{
        [NSFileManager.defaultManager removeItemAtURL:URL error:nil];
    }];
    return URL;
}

- (IDTextInputGroupBoundary *)ordinaryPassBoundary {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self validCatalogData],
        @"autocorrection--group--ordinary-accept", nil);
    __block IDTextInputGroupBoundary *result = nil;
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) { (void)observation; },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            result = boundary;
            return NO;
        });
    return result;
}

- (IDTextInputGroupBoundary *)stateSensitiveRowBoundary {
    [self installTestGroupToken];
    NSArray *rows = @[@"first-row", @"second-row"];
    NSData *data = [self catalogDataWithRows:rows groups:@[@{
        @"id": @"mixed-rows", @"language": @"en-US", @"rows": rows,
        @"stateSensitive": @YES,
        @"resetPolicy": @"erase-reset-learning-provision",
    }]];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, @"autocorrection--group--mixed-rows", nil);
    __block IDTextInputGroupBoundary *result = nil;
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) { (void)observation; },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            if (boundary.kind == IDTextInputGroupBoundaryKindRow) {
                result = boundary;
                return NO;
            }
            return YES;
        });
    return result;
}

- (IDTextInputGroupBoundary *)stateSensitiveHostBoundary {
    [self installTestGroupToken];
    NSData *data = [self catalogDataWithRows:@[@"first-row"] groups:@[@{
        @"id": @"mixed-rows", @"language": @"en-US",
        @"rows": @[@"first-row"], @"stateSensitive": @YES,
        @"resetPolicy": @"erase-reset-learning-provision",
    }]];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, @"autocorrection--group--mixed-rows", nil);
    __block IDTextInputGroupBoundary *result = nil;
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) { (void)observation; },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            result = boundary;
            return NO;
        });
    return result;
}

- (NSDictionary *)boundaryRequestWithToken:(NSString *)token
                                   boundary:(IDTextInputGroupBoundary *)boundary {
    return @{
        @"schema": @2,
        @"kind": @"pass",
        @"token": token,
        @"groupId": @"autocorrection--group--ordinary-accept",
        @"sequenceIndex": @1,
        @"completedBatchId":
            boundary.completedBatchIdentifier,
        @"nextBatchId":
            boundary.nextBatchIdentifier,
    };
}

- (BOOL)writeBoundaryRequestAtDirectory:(NSURL *)directory
                                  token:(NSString *)token
                               boundary:(IDTextInputGroupBoundary *)boundary
                                  error:(NSError **)error {
    return IDWriteTextInputGroupBoundaryRequest(
        directory, token, @"autocorrection--group--ordinary-accept",
        boundary, error);
}

- (BOOL)waitAtDirectory:(NSURL *)directory
                  token:(NSString *)token
               boundary:(IDTextInputGroupBoundary *)boundary
                timeout:(NSTimeInterval)timeout
                  error:(NSError **)error {
    return IDWaitForTextInputGroupBoundaryResponse(
        directory, token, @"autocorrection--group--ordinary-accept",
        boundary, timeout, error);
}

- (void)installTestGroupToken {
    NSString *token = [@"aa" stringByPaddingToLength:64
        withString:@"aa" startingAtIndex:0];
    setenv("INPUTDEC_TEXT_INPUT_GROUP_TOKEN", token.UTF8String, 1);
    [self addTeardownBlock:^{
        unsetenv("INPUTDEC_TEXT_INPUT_GROUP_TOKEN");
    }];
}

- (void)testBoundaryRequestIsExactAtomicAndReplaySafe {
    NSString *token = [@"01" stringByPaddingToLength:64
        withString:@"01" startingAtIndex:0];
    NSError *error = nil;
    NSURL *directory = IDTextInputGroupHandshakeDirectory(
        [self temporaryHandshakeRoot], token, &error);
    IDTextInputGroupBoundary *boundary = [self ordinaryPassBoundary];
    XCTAssertNotNil(directory, @"%@", error);
    XCTAssertTrue([[directory.path stringByDeletingLastPathComponent]
        hasSuffix:@"Documents/InputDecTextInputGroup"]);
    XCTAssertTrue([self writeBoundaryRequestAtDirectory:directory
        token:token boundary:boundary error:&error], @"%@", error);
    NSURL *requestURL = [directory URLByAppendingPathComponent:
        @"boundary-001-request.json"];
    NSDictionary *request = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfURL:requestURL] options:0 error:nil];
    XCTAssertEqualObjects(request, [self boundaryRequestWithToken:token
        boundary:boundary]);
    XCTAssertEqual([[NSFileManager.defaultManager contentsOfDirectoryAtURL:
        directory includingPropertiesForKeys:nil options:0 error:nil] count],
        1U);
    error = nil;
    XCTAssertFalse([self writeBoundaryRequestAtDirectory:directory
        token:token boundary:boundary error:&error]);
    XCTAssertEqualObjects(error.domain, IDTextInputBatchErrorDomain);
}

- (void)testRowBoundaryRequestUsesExactSchemaTwoFieldFamily {
    NSString *token = [@"12" stringByPaddingToLength:64
        withString:@"12" startingAtIndex:0];
    NSURL *directory = IDTextInputGroupHandshakeDirectory(
        [self temporaryHandshakeRoot], token, nil);
    IDTextInputGroupBoundary *boundary = [self stateSensitiveRowBoundary];
    XCTAssertTrue(IDWriteTextInputGroupBoundaryRequest(
        directory, token, @"autocorrection--group--mixed-rows",
        boundary, nil));
    NSURL *requestURL = [directory URLByAppendingPathComponent:
        @"boundary-002-request.json"];
    NSDictionary *request = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfURL:requestURL] options:0 error:nil];
    XCTAssertEqualObjects(request, (@{
        @"schema": @2, @"kind": @"row", @"token": token,
        @"groupId": @"autocorrection--group--mixed-rows",
        @"sequenceIndex": @2,
        @"batchId": @"autocorrection--r1--stock-custom--mixed-rows",
        @"completedRowId": @"first-row", @"nextRowId": @"second-row",
    }));
}

- (void)testHostBoundaryRequestUsesExactSchemaTwoFieldFamily {
    NSString *token = [@"13" stringByPaddingToLength:64
        withString:@"13" startingAtIndex:0];
    NSURL *directory = IDTextInputGroupHandshakeDirectory(
        [self temporaryHandshakeRoot], token, nil);
    IDTextInputGroupBoundary *boundary = [self stateSensitiveHostBoundary];
    XCTAssertEqual(boundary.kind, IDTextInputGroupBoundaryKindHost);
    XCTAssertTrue(IDWriteTextInputGroupBoundaryRequest(
        directory, token, @"autocorrection--group--mixed-rows",
        boundary, nil));
    NSURL *requestURL = [directory URLByAppendingPathComponent:
        @"boundary-001-request.json"];
    NSDictionary *request = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfURL:requestURL] options:0 error:nil];
    XCTAssertEqualObjects(request, (@{
        @"schema": @2, @"kind": @"host", @"token": token,
        @"groupId": @"autocorrection--group--mixed-rows",
        @"sequenceIndex": @1,
        @"batchId": @"autocorrection--r1--stock-custom--mixed-rows",
        @"rowId": @"first-row", @"completedHost": @"stock",
        @"nextHost": @"custom",
    }));
}

- (void)testValidBoundaryResponseIsAcceptedAndRawTokenFilesAreRemoved {
    NSString *token = [@"23" stringByPaddingToLength:64
        withString:@"23" startingAtIndex:0];
    NSURL *directory = IDTextInputGroupHandshakeDirectory(
        [self temporaryHandshakeRoot], token, nil);
    IDTextInputGroupBoundary *boundary = [self ordinaryPassBoundary];
    XCTAssertTrue([self writeBoundaryRequestAtDirectory:directory
        token:token boundary:boundary error:nil]);
    NSMutableDictionary *response =
        [[self boundaryRequestWithToken:token boundary:boundary] mutableCopy];
    response[@"resetSummarySHA256"] = [@"ab" stringByPaddingToLength:64
        withString:@"ab" startingAtIndex:0];
    response[@"result"] = @"ready";
    NSURL *responseURL = [directory URLByAppendingPathComponent:
        @"boundary-001-response.json"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:response
        options:NSJSONWritingSortedKeys error:nil];
    XCTAssertTrue([data writeToURL:responseURL options:NSDataWritingAtomic
                             error:nil]);
    NSError *error = nil;
    XCTAssertTrue([self waitAtDirectory:directory token:token
        boundary:boundary timeout:0.2 error:&error], @"%@", error);
    XCTAssertEqual([[NSFileManager.defaultManager contentsOfDirectoryAtURL:
        directory includingPropertiesForKeys:nil options:0 error:nil] count],
        0U);
}

- (void)testMalformedMismatchedAndSymlinkedResponsesFailClosed {
    NSString *token = [@"45" stringByPaddingToLength:64
        withString:@"45" startingAtIndex:0];
    NSArray<NSDictionary *> *mutations = @[
        @{@"token": [@"67" stringByPaddingToLength:64
            withString:@"67" startingAtIndex:0]},
        @{@"sequenceIndex": @2},
        @{@"kind": @"row"},
        @{@"completedBatchId": @"autocorrection--r2--stock-custom--ordinary-accept"},
        @{@"nextBatchId": @"autocorrection--r2--custom-stock--ordinary-accept"},
        @{@"resetSummarySHA256": @"bad"},
        @{@"result": @"failed"},
        @{@"extra": @YES},
    ];
    IDTextInputGroupBoundary *boundary = [self ordinaryPassBoundary];
    for (NSDictionary *mutation in mutations) {
        NSURL *directory = IDTextInputGroupHandshakeDirectory(
            [self temporaryHandshakeRoot], token, nil);
        XCTAssertTrue([self writeBoundaryRequestAtDirectory:directory
            token:token boundary:boundary error:nil]);
        NSMutableDictionary *response =
            [[self boundaryRequestWithToken:token boundary:boundary]
                mutableCopy];
        response[@"resetSummarySHA256"] = [@"cd" stringByPaddingToLength:64
            withString:@"cd" startingAtIndex:0];
        response[@"result"] = @"ready";
        [response addEntriesFromDictionary:mutation];
        NSURL *responseURL = [directory URLByAppendingPathComponent:
            @"boundary-001-response.json"];
        NSData *data = [NSJSONSerialization dataWithJSONObject:response
            options:0 error:nil];
        [data writeToURL:responseURL options:0 error:nil];
        NSError *error = nil;
        XCTAssertFalse([self waitAtDirectory:directory token:token
            boundary:boundary timeout:0.05 error:&error]);
        XCTAssertEqualObjects(error.domain, IDTextInputBatchErrorDomain);
    }

    NSURL *directory = IDTextInputGroupHandshakeDirectory(
        [self temporaryHandshakeRoot], token, nil);
    XCTAssertTrue([self writeBoundaryRequestAtDirectory:directory
        token:token boundary:boundary error:nil]);
    NSURL *target = [directory URLByAppendingPathComponent:@"target.json"];
    [@"{}" writeToURL:target atomically:YES
              encoding:NSUTF8StringEncoding error:nil];
    NSURL *responseURL = [directory URLByAppendingPathComponent:
        @"boundary-001-response.json"];
    XCTAssertTrue([NSFileManager.defaultManager createSymbolicLinkAtURL:
        responseURL withDestinationURL:target error:nil]);
    NSError *error = nil;
    XCTAssertFalse([self waitAtDirectory:directory token:token
        boundary:boundary timeout:0.05 error:&error]);
    XCTAssertEqualObjects(error.domain, IDTextInputBatchErrorDomain);
}

- (void)testBoundaryTimeoutUsesMonotonicDeadline {
    NSString *token = [@"89" stringByPaddingToLength:64
        withString:@"89" startingAtIndex:0];
    NSURL *directory = IDTextInputGroupHandshakeDirectory(
        [self temporaryHandshakeRoot], token, nil);
    IDTextInputGroupBoundary *boundary = [self ordinaryPassBoundary];
    XCTAssertTrue([self writeBoundaryRequestAtDirectory:directory
        token:token boundary:boundary error:nil]);
    NSTimeInterval started = NSProcessInfo.processInfo.systemUptime;
    NSError *error = nil;
    XCTAssertFalse([self waitAtDirectory:directory token:token
        boundary:boundary timeout:0.05 error:&error]);
    NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - started;
    XCTAssertGreaterThanOrEqual(elapsed, 0.04);
    XCTAssertLessThanOrEqual(elapsed, 0.5);
    XCTAssertEqualObjects(error.domain, IDTextInputBatchErrorDomain);
}

- (void)testHandshakeDirectoryRejectsInvalidTokenAndSymlinkedRoot {
    NSURL *root = [self temporaryHandshakeRoot];
    NSError *error = nil;
    XCTAssertNil(IDTextInputGroupHandshakeDirectory(root, @"../token", &error));
    XCTAssertEqualObjects(error.domain, IDTextInputBatchErrorDomain);
    NSURL *link = [root URLByAppendingPathComponent:@"link"];
    XCTAssertTrue([NSFileManager.defaultManager createSymbolicLinkAtURL:link
        withDestinationURL:root error:nil]);
    error = nil;
    NSString *token = [@"ef" stringByPaddingToLength:64
        withString:@"ef" startingAtIndex:0];
    XCTAssertNil(IDTextInputGroupHandshakeDirectory(link, token, &error));
    XCTAssertEqualObjects(error.domain, IDTextInputBatchErrorDomain);
}

- (void)testGroupTokenHashIsStableLowercaseSHA256 {
    NSString *token = [@"01" stringByPaddingToLength:64
        withString:@"01" startingAtIndex:0];
    XCTAssertEqualObjects(
        IDTextInputGroupTokenSHA256(token),
        @"58badd9b455145b487ad24c7f259cc437cc4ffd0784716845249321fb5961cfc");
    XCTAssertNil(IDTextInputGroupTokenSHA256(@"invalid"));
}

- (void)testSelectedBatchExpandsExactStockCustomObservationOrder {
    NSError *error = nil;
    IDTextInputBatch *batch = IDLoadTextInputBatchFromData(
        [self validCatalogData],
        @"autocorrection--r1--stock-custom--ordinary-accept", &error);
    XCTAssertNotNil(batch, @"%@", error);
    XCTAssertEqualObjects(batch.identifier,
        @"autocorrection--r1--stock-custom--ordinary-accept");
    XCTAssertEqualObjects(batch.subsystem, @"autocorrection");
    XCTAssertEqualObjects([batch.observations valueForKey:@"identity"], (@[
        @"interior-accept-space--stock",
        @"interior-accept-space--custom",
    ]));
    XCTAssertEqual(batch.observations[0].host, IDTextInputBatchHostStock);
    XCTAssertEqual(batch.observations[1].host, IDTextInputBatchHostCustom);
}

- (void)testSelectedBatchExpandsExactCustomStockObservationOrder {
    NSError *error = nil;
    IDTextInputBatch *batch = IDLoadTextInputBatchFromData(
        [self validCatalogData],
        @"autocorrection--r2--custom-stock--ordinary-accept", &error);
    XCTAssertNotNil(batch, @"%@", error);
    XCTAssertEqualObjects([batch.observations valueForKey:@"identity"], (@[
        @"interior-accept-space--custom",
        @"interior-accept-space--stock",
    ]));
}

- (void)testAttachmentNameUsesActiveRowAndHostAndCleansUp {
    IDTextInputBatch *batch = IDLoadTextInputBatchFromData(
        [self validCatalogData],
        @"autocorrection--r1--stock-custom--ordinary-accept", nil);
    IDTextInputBatchObservation *observation = batch.observations.firstObject;
    XCTAssertEqualObjects(IDTextInputBatchAttachmentName(@"baseline"),
                          @"baseline");
    IDWithTextInputBatch(batch, ^{
        IDWithTextInputBatchObservation(observation, ^{
            XCTAssertEqualObjects(
                IDTextInputBatchAttachmentName(
                    @"autocorrection-baseline-status_1"),
                @"group--autocorrection--r1--stock-custom--"
                 "ordinary-accept--interior-accept-space--stock--"
                 "autocorrection-baseline-status_1");
        });
    });
    XCTAssertEqualObjects(IDTextInputBatchAttachmentName(@"baseline"),
                          @"baseline");
}

- (void)testNestedNamespaceIsRejectedAndOuterNamespaceIsRestored {
    IDTextInputBatch *batch = IDLoadTextInputBatchFromData(
        [self validCatalogData],
        @"autocorrection--r1--stock-custom--ordinary-accept", nil);
    IDTextInputBatchObservation *observation = batch.observations.firstObject;
    IDWithTextInputBatch(batch, ^{
        XCTAssertThrowsSpecificNamed(
            IDWithTextInputBatch(batch, ^{}),
            NSException, NSInternalInconsistencyException);
        IDWithTextInputBatchObservation(observation, ^{
            XCTAssertThrowsSpecificNamed(
                IDWithTextInputBatchObservation(observation, ^{}),
                NSException, NSInternalInconsistencyException);
            XCTAssertTrue([
                IDTextInputBatchAttachmentName(@"still-active")
                hasPrefix:@"group--autocorrection--r1--stock-custom--"
                           "ordinary-accept--interior-accept-space--stock--"]);
        });
    });
    XCTAssertEqualObjects(IDTextInputBatchAttachmentName(@"clean"), @"clean");
}

- (void)testLogicalGroupExpandsFourPassesInCanonicalOrder {
    NSError *error = nil;
    id group = IDLoadTextInputGroupFromData(
        [self validCatalogData],
        @"autocorrection--group--ordinary-accept", &error);
    XCTAssertNotNil(group, @"%@", error);
    XCTAssertEqualObjects([group valueForKey:@"identifier"],
                          @"autocorrection--group--ordinary-accept");
    XCTAssertEqualObjects([group valueForKey:@"subsystem"],
                          @"autocorrection");
    XCTAssertFalse([[group valueForKey:@"stateSensitive"] boolValue]);
    NSArray *batches = [group valueForKey:@"batches"];
    XCTAssertEqualObjects([batches valueForKey:@"stateSensitive"],
                          (@[@NO, @NO, @NO, @NO]));
    XCTAssertEqualObjects([batches valueForKey:@"identifier"], (@[
        @"autocorrection--r1--stock-custom--ordinary-accept",
        @"autocorrection--r1--custom-stock--ordinary-accept",
        @"autocorrection--r2--stock-custom--ordinary-accept",
        @"autocorrection--r2--custom-stock--ordinary-accept",
    ]));
}

- (void)testSnapshotInlineGroupLoadsFourCanonicalBatches {
    NSData *data = [self inlinePredictionCatalogData];
    NSString *identifier =
        @"inline-prediction--snapshot-row-v1--interior-accept";
    NSError *error = nil;
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, identifier, &error);
    XCTAssertNotNil(group, @"%@", error);
    XCTAssertEqualObjects(group.identifier, identifier);
    XCTAssertTrue(group.stateSensitive);
    XCTAssertEqualObjects([group.batches valueForKey:@"identifier"], (@[
        @"inline-prediction--r1--stock-custom--interior-accept",
        @"inline-prediction--r1--custom-stock--interior-accept",
        @"inline-prediction--r2--stock-custom--interior-accept",
        @"inline-prediction--r2--custom-stock--interior-accept",
    ]));
    XCTAssertEqualObjects(
        [group.batches valueForKeyPath:@"@unionOfArrays.observations.host"],
        (@[@(IDTextInputBatchHostStock), @(IDTextInputBatchHostCustom),
           @(IDTextInputBatchHostCustom), @(IDTextInputBatchHostStock),
           @(IDTextInputBatchHostStock), @(IDTextInputBatchHostCustom),
           @(IDTextInputBatchHostCustom), @(IDTextInputBatchHostStock)]));
}

- (void)testSnapshotInlineGroupRejectsLegacyAndMalformedIdentities {
    NSData *data = [self inlinePredictionCatalogData];
    for (NSString *identifier in @[
            @"inline-prediction--group--interior-accept",
            @"inline-prediction--group-r1--interior-accept",
            @"inline-prediction--group-r1-stock-custom--interior-accept",
            @"inline-prediction--snapshot-row-v2--interior-accept",
            @"inline-prediction--snapshot-row-v1--unknown-row",
        ]) {
        NSError *error = nil;
        XCTAssertNil(IDLoadTextInputGroupFromData(
            data, identifier, &error));
        XCTAssertNotNil(error);
    }
}

- (void)testSnapshotInlineGroupRunnerExecutesFourPasses {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self inlinePredictionCatalogData],
        @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    NSMutableArray<NSString *> *observations = [NSMutableArray array];
    NSMutableArray<NSString *> *boundaries = [NSMutableArray array];
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            [observations addObject:observation.identity];
        },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            NSString *kind = boundary.kind == IDTextInputGroupBoundaryKindHost
                ? @"host" : (boundary.kind == IDTextInputGroupBoundaryKindPass
                    ? @"pass" : @"row");
            [boundaries addObject:kind];
            return YES;
        });
    XCTAssertEqual(observations.count, 8U);
    XCTAssertEqualObjects(boundaries, (@[
        @"host", @"pass", @"host", @"pass",
        @"host", @"pass", @"host",
    ]));
}

- (void)testSnapshotRunnerRetriesOnlyCurrentObservation {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self inlinePredictionCatalogData],
        @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    NSMutableArray<NSString *> *events = [NSMutableArray array];
    NSMutableArray<NSString *> *attempts = [NSMutableArray array];
    __block BOOL firstReadinessMissing = YES;
    IDRunSnapshotTextInputGroup(
        self, group, 20, [NSIndexSet indexSet],
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            [attempts addObject:[NSString stringWithFormat:
                @"%@-%lu", IDTextInputBatchAttachmentName(@"attempt"),
                (unsigned long)attempt]];
            if (firstReadinessMissing) {
                firstReadinessMissing = NO;
                return IDTextInputObservationAttemptReadinessUnavailable;
            }
            return IDTextInputObservationAttemptCompleted;
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *boundary) {
            (void)observation;
            [events addObject:[NSString stringWithFormat:@"%ld-%lu-%@",
                (long)kind, (unsigned long)attempt,
                boundary == nil ? @"none" : @"boundary"]];
            return YES;
        });

    XCTAssertEqual(attempts.count, 9U);
    XCTAssertEqual(events.count, 25U);
    XCTAssertTrue([attempts[0] containsString:@"attempt-001--attempt"]);
    XCTAssertTrue([attempts[1] containsString:@"attempt-002--attempt"]);
    XCTAssertTrue([attempts[2] containsString:@"attempt-001--attempt"]);
}

- (void)testSnapshotRunnerExhaustsAtTwenty {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self inlinePredictionCatalogData],
        @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    IDTextInputIssueCapturingTestCase *capturing =
        [IDTextInputIssueCapturingTestCase new];
    __block NSUInteger attempts = 0;
    IDRunSnapshotTextInputGroup(
        capturing, group, 20, [NSIndexSet indexSet],
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            (void)observation;
            attempts = attempt;
            return IDTextInputObservationAttemptReadinessUnavailable;
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *boundary) {
            (void)kind; (void)observation; (void)attempt; (void)boundary;
            return YES;
        });
    XCTAssertEqual(attempts, 20U);
    XCTAssertEqual(capturing.capturedIssues.count, 1U);
    XCTAssertTrue([capturing.capturedIssues.firstObject.compactDescription
        containsString:@"20"]);
}

- (void)testSnapshotRunnerResumesContiguousCompletedPrefix {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self inlinePredictionCatalogData],
        @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    NSMutableArray<NSString *> *attempted = [NSMutableArray array];
    NSMutableArray<NSNumber *> *preparationHasBoundary =
        [NSMutableArray array];
    IDRunSnapshotTextInputGroup(
        self, group, 20,
        [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)],
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            (void)attempt;
            [attempted addObject:IDTextInputBatchAttachmentName(@"resumed")];
            return IDTextInputObservationAttemptCompleted;
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *boundary) {
            (void)observation; (void)attempt;
            if (kind == IDTextInputObservationEventStarted) {
                [preparationHasBoundary addObject:@(boundary != nil)];
            }
            return YES;
        });
    XCTAssertEqual(attempted.count, 5U);
    XCTAssertTrue(preparationHasBoundary.firstObject.boolValue);
    XCTAssertTrue([attempted.firstObject containsString:
        @"inline-prediction--r1--custom-stock--interior-accept"]);

    IDTextInputIssueCapturingTestCase *capturing =
        [IDTextInputIssueCapturingTestCase new];
    NSMutableIndexSet *sparse = [NSMutableIndexSet indexSetWithIndex:1];
    [sparse addIndex:3];
    __block NSUInteger sparseRuns = 0;
    IDRunSnapshotTextInputGroup(
        capturing, group, 20, sparse,
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            (void)observation; (void)attempt;
            sparseRuns += 1;
            return IDTextInputObservationAttemptCompleted;
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *boundary) {
            (void)kind; (void)observation; (void)attempt; (void)boundary;
            return YES;
        });
    XCTAssertEqual(sparseRuns, 0U);
    XCTAssertEqual(capturing.capturedIssues.count, 1U);
}

- (void)testSnapshotRunnerPreservesCanonicalOrderAndStopsBeforeFailedPreparation {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self inlinePredictionCatalogData],
        @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    NSMutableArray<NSString *> *attempted = [NSMutableArray array];
    NSMutableArray<NSString *> *boundaries = [NSMutableArray array];
    IDRunSnapshotTextInputGroup(
        self, group, 20, [NSIndexSet indexSet],
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            (void)attempt;
            [attempted addObject:IDTextInputBatchAttachmentName(@"run")];
            return IDTextInputObservationAttemptCompleted;
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *boundary) {
            (void)observation; (void)attempt;
            if (kind == IDTextInputObservationEventStarted && boundary != nil) {
                [boundaries addObject:
                    boundary.kind == IDTextInputGroupBoundaryKindHost
                        ? @"host" : @"pass"];
            }
            return YES;
        });
    XCTAssertEqual(attempted.count, 8U);
    XCTAssertTrue([attempted[0] containsString:@"r1--stock-custom"]);
    XCTAssertTrue([attempted[1] containsString:@"r1--stock-custom"]);
    XCTAssertTrue([attempted[2] containsString:@"r1--custom-stock"]);
    XCTAssertTrue([attempted[4] containsString:@"r2--stock-custom"]);
    XCTAssertTrue([attempted[6] containsString:@"r2--custom-stock"]);
    XCTAssertEqualObjects(boundaries, (@[
        @"host", @"pass", @"host", @"pass",
        @"host", @"pass", @"host",
    ]));

    __block NSUInteger launches = 0;
    IDRunSnapshotTextInputGroup(
        self, group, 20, [NSIndexSet indexSet],
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            (void)observation; (void)attempt;
            launches += 1;
            return IDTextInputObservationAttemptCompleted;
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *boundary) {
            (void)kind; (void)observation; (void)attempt; (void)boundary;
            return NO;
        });
    XCTAssertEqual(launches, 0U);
}

- (void)testCompletedObservationEnvironmentRequiresContiguousPrefix {
    const char *oldValue = getenv(
        "INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS");
    NSString *saved = oldValue == NULL
        ? nil : [NSString stringWithUTF8String:oldValue];
    @try {
        unsetenv("INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS");
        XCTAssertEqual(IDLoadTextInputCompletedObservationIndexes().count, 0U);
        setenv("INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS", "1,2,3", 1);
        XCTAssertEqualObjects(IDLoadTextInputCompletedObservationIndexes(),
            [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)]);
        for (NSString *invalid in @[
                @"1,3", @"0", @"9", @"1,,2", @"01", @"1,2,2", @"x",
            ]) {
            setenv("INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS",
                   invalid.UTF8String, 1);
            XCTAssertNil(IDLoadTextInputCompletedObservationIndexes(),
                         @"%@", invalid);
        }
    } @finally {
        if (saved == nil) {
            unsetenv("INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS");
        } else {
            setenv("INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS",
                   saved.UTF8String, 1);
        }
    }
}

- (void)testSnapshotAttachmentNamesCarryAttemptIdentity {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self inlinePredictionCatalogData],
        @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    IDTextInputIssueCapturingTestCase *capturing =
        [IDTextInputIssueCapturingTestCase new];
    __block BOOL retryFirst = YES;
    IDRunSnapshotTextInputGroup(
        capturing, group, 20, [NSIndexSet indexSet],
        ^IDTextInputObservationAttemptOutcome(
            IDTextInputBatchObservation *observation, NSUInteger attempt) {
            (void)observation; (void)attempt;
            if (retryFirst) {
                retryFirst = NO;
                return IDTextInputObservationAttemptReadinessUnavailable;
            }
            return IDTextInputObservationAttemptCompleted;
        },
        ^BOOL(IDTextInputObservationEventKind kind,
              IDTextInputBatchObservation *observation, NSUInteger attempt,
              IDTextInputGroupBoundary *boundary) {
            (void)kind; (void)observation; (void)attempt; (void)boundary;
            return YES;
        });
    NSPredicate *named = [NSPredicate predicateWithBlock:
        ^BOOL(XCTAttachment *attachment, NSDictionary *bindings) {
            (void)bindings;
            return [attachment.name isEqual:@"observation-attempts.json"];
        }];
    NSArray<XCTAttachment *> *maps =
        [capturing.capturedAttachments filteredArrayUsingPredicate:named];
    XCTAssertEqual(maps.count, 1U);
    NSArray<NSString *> *attachmentNames =
        [capturing.capturedAttachments valueForKey:@"name"];
    XCTAssertTrue([attachmentNames containsObject:@"group-metadata.json"]);
    for (IDTextInputBatch *batch in group.batches) {
        NSString *metadataName = [NSString stringWithFormat:
            @"group--%@--metadata.json", batch.identifier];
        XCTAssertTrue([attachmentNames containsObject:metadataName]);
    }
    NSArray<NSDictionary *> *entries = maps.firstObject.userInfo[@"observations"];
    XCTAssertEqual(entries.count, 8U);
    XCTAssertEqualObjects(entries.firstObject[@"successfulAttempt"], @2);
    XCTAssertEqualObjects(entries.firstObject[@"readinessAttempts"], @1);
    for (NSDictionary *entry in [entries subarrayWithRange:NSMakeRange(1, 7)]) {
        XCTAssertEqualObjects(entry[@"successfulAttempt"], @1);
        XCTAssertEqualObjects(entry[@"readinessAttempts"], @0);
    }
}

- (void)testSnapshotObservationHandshakeUsesExactSchemaThree {
    NSData *data = [self inlinePredictionCatalogData];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    IDTextInputBatchObservation *observation =
        group.batches.firstObject.observations.firstObject;
    NSURL *directory = [self temporaryHandshakeRoot];
    NSString *token = [@"ab" stringByPaddingToLength:64
        withString:@"ab" startingAtIndex:0];
    NSError *error = nil;
    XCTAssertTrue(IDWriteTextInputObservationEvent(
        directory, token, group.identifier, 1, 1,
        IDTextInputObservationEventStarted, observation, 1, nil, &error),
        @"%@", error);
    NSURL *request = [directory URLByAppendingPathComponent:
        @"observation-000001-event.json"];
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfURL:request] options:0 error:nil];
    XCTAssertEqualObjects(event, (@{
        @"schema": @3, @"kind": @"observation-started",
        @"token": token, @"groupId": group.identifier,
        @"eventIndex": @1, @"observationIndex": @1, @"attempt": @1,
        @"batchId": observation.batchIdentifier,
        @"rowId": observation.rowIdentifier, @"host": @"stock",
        @"precedingBoundary": NSNull.null,
    }));
    NSMutableDictionary *response = [event mutableCopy];
    response[@"kind"] = @"restore-complete";
    response[@"preparationKind"] = @"observation-started";
    response[@"resetSummarySHA256"] = [@"cd" stringByPaddingToLength:64
        withString:@"cd" startingAtIndex:0];
    response[@"result"] = @"ready";
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:response
        options:NSJSONWritingSortedKeys error:nil];
    NSURL *responseURL = [directory URLByAppendingPathComponent:
        @"observation-000001-restore.json"];
    XCTAssertTrue([responseData writeToURL:responseURL options:0 error:nil]);
    XCTAssertTrue(IDWaitForTextInputObservationRestoreResponse(
        directory, token, group.identifier, 1, 1,
        IDTextInputObservationEventStarted, observation, 1, nil, 0.1,
        &error), @"%@", error);
    XCTAssertFalse([NSFileManager.defaultManager
        fileExistsAtPath:request.path]);
    XCTAssertFalse([NSFileManager.defaultManager
        fileExistsAtPath:responseURL.path]);
}

- (void)testStateSensitiveGroupEmitsHostsRowsAndPassesInOneSequence {
    [self installTestGroupToken];
    NSArray *rows = @[@"first-row", @"second-row", @"third-row"];
    NSData *data = [self catalogDataWithRows:rows groups:@[@{
        @"id": @"mixed-rows",
        @"language": @"en-US",
        @"rows": rows,
        @"stateSensitive": @YES,
        @"resetPolicy": @"erase-reset-learning-provision",
    }]];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, @"autocorrection--group--mixed-rows", nil);
    XCTAssertTrue(group.stateSensitive);
    XCTAssertEqualObjects([group.batches valueForKey:@"stateSensitive"],
                          (@[@YES, @YES, @YES, @YES]));
    NSMutableArray<NSString *> *events = [NSMutableArray array];
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            [events addObject:[@"observation:" stringByAppendingString:
                observation.identity]];
        },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            NSString *kind = boundary.kind == IDTextInputGroupBoundaryKindHost
                ? @"host" : (boundary.kind == IDTextInputGroupBoundaryKindRow
                    ? @"row" : @"pass");
            [events addObject:[NSString stringWithFormat:@"boundary:%lu:%@",
                (unsigned long)boundary.sequenceIndex, kind]];
            if (boundary.kind == IDTextInputGroupBoundaryKindHost) {
                XCTAssertNotNil(boundary.batchIdentifier);
                XCTAssertNotNil(boundary.rowIdentifier);
                XCTAssertNotNil(boundary.completedHost);
                XCTAssertNotNil(boundary.nextHost);
                BOOL reverse = [boundary.batchIdentifier
                    containsString:@"--custom-stock--"];
                XCTAssertEqualObjects(boundary.completedHost,
                    reverse ? @"custom" : @"stock");
                XCTAssertEqualObjects(boundary.nextHost,
                    reverse ? @"stock" : @"custom");
                XCTAssertNil(boundary.completedRowIdentifier);
                XCTAssertNil(boundary.nextRowIdentifier);
                XCTAssertNil(boundary.completedBatchIdentifier);
                XCTAssertNil(boundary.nextBatchIdentifier);
            } else if (boundary.kind == IDTextInputGroupBoundaryKindRow) {
                XCTAssertNotNil(boundary.batchIdentifier);
                XCTAssertNil(boundary.rowIdentifier);
                XCTAssertNil(boundary.completedHost);
                XCTAssertNil(boundary.nextHost);
                XCTAssertNotNil(boundary.completedRowIdentifier);
                XCTAssertNotNil(boundary.nextRowIdentifier);
                XCTAssertNil(boundary.completedBatchIdentifier);
                XCTAssertNil(boundary.nextBatchIdentifier);
            } else {
                XCTAssertNil(boundary.batchIdentifier);
                XCTAssertNil(boundary.completedRowIdentifier);
                XCTAssertNil(boundary.nextRowIdentifier);
                XCTAssertNotNil(boundary.completedBatchIdentifier);
                XCTAssertNotNil(boundary.nextBatchIdentifier);
            }
            return YES;
        });
    NSArray *boundaryEvents = [events filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(NSString *event, id bindings) {
            (void)bindings;
            return [event hasPrefix:@"boundary:"];
        }]];
    XCTAssertEqualObjects(boundaryEvents, (@[
        @"boundary:1:host", @"boundary:2:row", @"boundary:3:host",
        @"boundary:4:row", @"boundary:5:host", @"boundary:6:pass",
        @"boundary:7:host", @"boundary:8:row", @"boundary:9:host",
        @"boundary:10:row", @"boundary:11:host", @"boundary:12:pass",
        @"boundary:13:host", @"boundary:14:row", @"boundary:15:host",
        @"boundary:16:row", @"boundary:17:host", @"boundary:18:pass",
        @"boundary:19:host", @"boundary:20:row", @"boundary:21:host",
        @"boundary:22:row", @"boundary:23:host",
    ]));
    for (NSUInteger index = 0; index < events.count; index++) {
        if (![events[index] containsString:@":host"]) continue;
        XCTAssertTrue([events[index - 1] hasPrefix:@"observation:"]);
        XCTAssertTrue([events[index + 1] hasPrefix:@"observation:"]);
        NSArray *before = [events[index - 1] componentsSeparatedByString:@"--"];
        NSArray *after = [events[index + 1] componentsSeparatedByString:@"--"];
        XCTAssertEqualObjects(before.firstObject, after.firstObject);
    }
}

- (void)testGroupRunnerStopsImmediatelyAfterRejectedHostBoundary {
    [self installTestGroupToken];
    NSData *data = [self catalogDataWithRows:@[@"first-row"] groups:@[@{
        @"id": @"mixed-rows", @"language": @"en-US",
        @"rows": @[@"first-row"], @"stateSensitive": @YES,
        @"resetPolicy": @"erase-reset-learning-provision",
    }]];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, @"autocorrection--group--mixed-rows", nil);
    __block NSUInteger observationCount = 0;
    __block IDTextInputGroupBoundary *rejected = nil;
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            (void)observation;
            observationCount += 1;
        },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            rejected = boundary;
            return NO;
        });
    XCTAssertEqual(observationCount, 1U);
    XCTAssertEqual(rejected.kind, IDTextInputGroupBoundaryKindHost);
    XCTAssertEqualObjects(rejected.completedHost, @"stock");
    XCTAssertEqualObjects(rejected.nextHost, @"custom");
}

- (void)testGroupRunnerStopsImmediatelyAfterRejectedRowBoundary {
    [self installTestGroupToken];
    NSArray *rows = @[@"first-row", @"second-row"];
    NSData *data = [self catalogDataWithRows:rows groups:@[@{
        @"id": @"mixed-rows", @"language": @"en-US", @"rows": rows,
        @"stateSensitive": @YES,
        @"resetPolicy": @"erase-reset-learning-provision",
    }]];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, @"autocorrection--group--mixed-rows", nil);
    __block NSUInteger observationCount = 0;
    NSMutableArray<NSString *> *boundaries = [NSMutableArray array];
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            (void)observation;
            observationCount += 1;
        },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            [boundaries addObject:[NSString stringWithFormat:@"%lu:%@",
                (unsigned long)boundary.sequenceIndex,
                boundary.kind == IDTextInputGroupBoundaryKindHost ? @"host" :
                (boundary.kind == IDTextInputGroupBoundaryKindRow
                    ? @"row" : @"pass")]];
            return boundary.kind != IDTextInputGroupBoundaryKindRow;
        });
    XCTAssertEqual(observationCount, 2U);
    XCTAssertEqualObjects(boundaries, (@[@"1:host", @"2:row"]));
}

- (void)testGroupRunnerExecutesEveryPassAndThreeBoundariesInOrder {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self validCatalogData],
        @"autocorrection--group--ordinary-accept", nil);
    NSMutableArray<NSString *> *observations = [NSMutableArray array];
    NSMutableArray<NSString *> *boundaries = [NSMutableArray array];
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            [observations addObject:IDTextInputBatchAttachmentName(@"probe")];
        },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            [boundaries addObject:[NSString stringWithFormat:@"%lu:%@:%@:%@",
                (unsigned long)boundary.sequenceIndex,
                boundary.kind == IDTextInputGroupBoundaryKindPass
                    ? @"pass" : @"row",
                boundary.completedBatchIdentifier,
                boundary.nextBatchIdentifier]];
            return YES;
        });
    XCTAssertEqualObjects(observations, (@[
        @"group--autocorrection--r1--stock-custom--ordinary-accept--"
         "interior-accept-space--stock--probe",
        @"group--autocorrection--r1--stock-custom--ordinary-accept--"
         "interior-accept-space--custom--probe",
        @"group--autocorrection--r1--custom-stock--ordinary-accept--"
         "interior-accept-space--custom--probe",
        @"group--autocorrection--r1--custom-stock--ordinary-accept--"
         "interior-accept-space--stock--probe",
        @"group--autocorrection--r2--stock-custom--ordinary-accept--"
         "interior-accept-space--stock--probe",
        @"group--autocorrection--r2--stock-custom--ordinary-accept--"
         "interior-accept-space--custom--probe",
        @"group--autocorrection--r2--custom-stock--ordinary-accept--"
         "interior-accept-space--custom--probe",
        @"group--autocorrection--r2--custom-stock--ordinary-accept--"
         "interior-accept-space--stock--probe",
    ]));
    XCTAssertEqualObjects(boundaries, (@[
        @"1:pass:autocorrection--r1--stock-custom--ordinary-accept:"
         "autocorrection--r1--custom-stock--ordinary-accept",
        @"2:pass:autocorrection--r1--custom-stock--ordinary-accept:"
         "autocorrection--r2--stock-custom--ordinary-accept",
        @"3:pass:autocorrection--r2--stock-custom--ordinary-accept:"
         "autocorrection--r2--custom-stock--ordinary-accept",
    ]));
}

- (void)testGroupRunnerStopsImmediatelyAfterRejectedBoundary {
    [self installTestGroupToken];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        [self validCatalogData],
        @"autocorrection--group--ordinary-accept", nil);
    __block NSUInteger observationCount = 0;
    NSMutableArray<NSNumber *> *boundaries = [NSMutableArray array];
    IDRunTextInputGroup(self, group,
        ^(IDTextInputBatchObservation *observation) {
            (void)observation;
            observationCount += 1;
        },
        ^BOOL(IDTextInputGroupBoundary *boundary) {
            [boundaries addObject:@(boundary.sequenceIndex)];
            return boundary.sequenceIndex != 2;
        });
    XCTAssertEqual(observationCount, 4U);
    XCTAssertEqualObjects(boundaries, (@[@1, @2]));
}

- (void)testBatchOnlyNamespaceNamesGroupMetadata {
    IDTextInputBatch *batch = IDLoadTextInputBatchFromData(
        [self validCatalogData],
        @"autocorrection--r1--stock-custom--ordinary-accept", nil);
    IDWithTextInputBatch(batch, ^{
        XCTAssertEqualObjects(
            IDTextInputBatchAttachmentName(@"metadata.json"),
            @"group--autocorrection--r1--stock-custom--ordinary-accept--"
             "metadata.json");
    });
}

- (void)testObservationNamespaceRequiresAnActiveBatch {
    IDTextInputBatch *batch = IDLoadTextInputBatchFromData(
        [self validCatalogData],
        @"autocorrection--r1--stock-custom--ordinary-accept", nil);
    XCTAssertThrowsSpecificNamed(
        IDWithTextInputBatchObservation(batch.observations.firstObject, ^{}),
        NSException, NSInternalInconsistencyException);
}

- (void)testUnknownAndMalformedLogicalGroupsFailClosed {
    for (NSString *identifier in @[
            @"autocorrection--group--missing",
            @"autocorrection--r1--ordinary-accept",
            @"ime--group--ordinary-accept",
            @"autocorrection--group--ordinary-accept--extra",
        ]) {
        NSError *error = nil;
        XCTAssertNil(IDLoadTextInputGroupFromData(
            [self validCatalogData], identifier, &error));
        XCTAssertNotNil(error);
    }
}

- (void)testUnknownBatchAndMalformedCatalogFailClosed {
    NSError *error = nil;
    XCTAssertNil(IDLoadTextInputBatchFromData(
        [self validCatalogData], @"autocorrection--r3--bad--missing", &error));
    XCTAssertNotNil(error);

    error = nil;
    XCTAssertNil(IDLoadTextInputBatchFromData(
        [@"{" dataUsingEncoding:NSUTF8StringEncoding],
        @"autocorrection--r1--stock-custom--ordinary-accept", &error));
    XCTAssertNotNil(error);
}

- (void)testDuplicateGroupedRowFailsClosed {
    NSDictionary *group = @{
        @"id": @"ordinary-accept",
        @"language": @"en-US",
        @"rows": @[
            @"interior-accept-space", @"interior-accept-space",
        ],
        @"stateSensitive": @NO,
        @"resetPolicy": @"erase-reset-learning-provision",
    };
    NSError *error = nil;
    XCTAssertNil(IDLoadTextInputBatchFromData(
        [self catalogDataWithGroups:@[group]],
        @"autocorrection--r1--stock-custom--ordinary-accept", &error));
    XCTAssertNotNil(error);
}

- (void)testInlinePredictionIdentifierLookupIsExact {
    NSArray<IDInlinePredictionRow *> *rows =
        IDInlinePredictionRowsMatchingIdentifier(
            @"before-boundary-dismiss-then-type");
    XCTAssertEqual(rows.count, 1U);
    XCTAssertEqualObjects(rows.firstObject.identifier,
                          @"before-boundary-dismiss-then-type");
    XCTAssertEqual(
        IDInlinePredictionRowsMatchingIdentifier(@"unknown").count, 0U);
}

- (void)testIMEIdentifierLookupIsExact {
    NSArray<IDIMECompositionRow *> *rows =
        IDIMECompositionRowsMatchingIdentifier(
            @"japanese-romaji-before-boundary-return-commit-then-undo");
    XCTAssertEqual(rows.count, 1U);
    XCTAssertEqualObjects(
        rows.firstObject.identifier,
        @"japanese-romaji-before-boundary-return-commit-then-undo");
    XCTAssertEqual(
        IDIMECompositionRowsMatchingIdentifier(@"japanese").count, 0U);
}

- (void)testIMELifecycleDictionaryRetainsComparatorFields {
    IDIMECompositionStatus *status = [IDIMECompositionStatus new];
    NSDictionary<NSString *, id> *values = @{
        @"scenario": @"ime-japanese-romaji-interior-candidate-commit",
        @"language": @"japanese-romaji",
        @"location": @"interior",
        @"decision": @"candidate-commit",
        @"canonical": @"Alpha\nBeta",
        @"blocks": @[@"Alpha", @"Beta"],
        @"blockIdentifiers": @[@"block-a", @"block-b"],
        @"anchorIdentities": @[@"anchor-a"],
        @"selection": [NSValue valueWithRange:NSMakeRange(5, 0)],
        @"affinity": @"forward",
        @"markedRange": [NSValue valueWithRange:
            NSMakeRange(NSNotFound, 0)],
        @"markedText": @"",
        @"markedSelection": [NSValue valueWithRange:
            NSMakeRange(NSNotFound, 0)],
        @"markedAttributeKeys": @[],
        @"structuralNewlineLocations": @[@5],
        @"checkingRanges": @[[NSValue valueWithRange:NSMakeRange(0, 1)]],
        @"temporaryRenderingDescriptors": @[],
        @"candidateDescriptor": @{
            @"visible": @NO, @"actionable": @NO, @"labels": @[],
            @"selectedLabel": @"", @"geometry": @{
                @"x": @0, @"y": @0, @"width": @0, @"height": @0,
            },
        },
        @"keyboardState": @{
            @"visible": @YES, @"primaryLanguage": @"ja-JP",
            @"enabledInputModeIdentifiers": @[@"mode"],
        },
        @"compositionGeometry": @{
            @"x": @1, @"y": @2, @"width": @3, @"height": @4,
        },
        @"mutationTrace": @[@"textDidChange"],
        @"eventTrace": @[@"textDidChange"],
        @"coordinateSpaceIdentity": @"screen",
        @"documentRevision": @1,
        @"textEpoch": @2,
        @"selectionEpoch": @3,
        @"checkingEpoch": @4,
        @"layoutEpoch": @5,
        @"firstResponder": @YES,
    };
    [values enumerateKeysAndObjectsUsingBlock:
        ^(NSString *key, id value, BOOL *stop) {
            (void)stop;
            [status setValue:value forKey:key];
        }];
    IDIMECompositionPhaseSnapshot *phase =
        [IDIMECompositionPhaseSnapshot new];
    [phase setValue:@"baseline" forKey:@"phase"];
    [phase setValue:status forKey:@"status"];
    IDIMECompositionRunResult *result = [IDIMECompositionRunResult new];
    [result setValue:IDIMECompositionRowsMatchingIdentifier(
        @"japanese-romaji-interior-candidate-commit").firstObject
             forKey:@"row"];
    [result setValue:@[phase] forKey:@"phases"];

    NSDictionary<NSString *, id> *json =
        IDIMECompositionLifecycleDictionary(result, @"batch");
    NSSet<NSString *> *expectedTopLevelKeys = [NSSet setWithArray:
        @[@"schema", @"testMethod", @"decision", @"phases"]];
    XCTAssertEqualObjects(
        [NSSet setWithArray:json.allKeys],
        expectedTopLevelKeys);
    XCTAssertEqualObjects(json[@"testMethod"], @"batch");
    XCTAssertEqualObjects(json[@"decision"], @"candidate-commit");
    XCTAssertEqualObjects([json[@"phases"] valueForKey:@"phase"],
                          @[@"baseline"]);
    NSDictionary *serializedStatus = json[@"phases"][0][@"status"];
    NSMutableSet *expectedKeys = [NSMutableSet setWithArray:values.allKeys];
    [expectedKeys addObject:@"schema"];
    XCTAssertEqualObjects([NSSet setWithArray:serializedStatus.allKeys],
                          expectedKeys);
    XCTAssertEqualObjects(serializedStatus[@"markedRange"], (@{
        @"location": @(NSNotFound), @"length": @0,
    }));
    XCTAssertEqualObjects(serializedStatus[@"checkingRanges"], (@[@{
        @"location": @0, @"length": @1,
    }]));
}

@end
