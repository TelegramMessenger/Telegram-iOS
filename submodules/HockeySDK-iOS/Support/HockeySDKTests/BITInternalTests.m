#import <XCTest/XCTest.h>
#import "BITInternal.h"

@interface BITInternalTests : XCTestCase

@end

@implementation BITInternalTests

- (void)testsdk_versionPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITInternal *item = [BITInternal new];
    item.sdkVersion = expected;
    NSString *actual = item.sdkVersion;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.sdkVersion = expected;
    actual = item.sdkVersion;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testagent_versionPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITInternal *item = [BITInternal new];
    item.agentVersion = expected;
    NSString *actual = item.agentVersion;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.agentVersion = expected;
    actual = item.agentVersion;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITInternal *item = [BITInternal new];
    item.sdkVersion = @"Test string";
    item.agentVersion = @"Test string";
    NSDictionary *actual = [item serializeToDictionary];
    NSDictionary *expected = @{@"ai.internal.sdkVersion":@"Test string", @"ai.internal.agentVersion":@"Test string"};
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
