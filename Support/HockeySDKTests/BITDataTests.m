#import <XCTest/XCTest.h>
#import "BITData.h"

@interface BITDataTests : XCTestCase

@end

@implementation BITDataTests

- (void)testbase_dataPropertyWorksAsExpected {
    BITTelemetryData *expected = [BITTelemetryData new];
    BITData *item = [BITData new];
    item.baseData = expected;
    BITTelemetryData *actual = item.baseData;
    XCTAssertTrue(actual == expected);
    
    expected = [BITTelemetryData new];
    item.baseData = expected;
    actual = item.baseData;
    XCTAssertTrue(actual == expected);
}

- (void)testSerialize {
    BITData *item = [BITData new];
    item.baseData = [BITTelemetryData new];
    NSString *actual = [item serializeToString];
    NSString *expected = @"{\"baseData\":{}}";
    XCTAssertTrue([actual isEqualToString:expected]);
}

@end
