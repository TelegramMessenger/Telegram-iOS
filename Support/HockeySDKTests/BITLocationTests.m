#import <XCTest/XCTest.h>
#import "BITLocation.h"

@interface BITLocationTests : XCTestCase

@end

@implementation BITLocationTests

- (void)testipPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITLocation *item = [BITLocation new];
    item.ip = expected;
    NSString *actual = item.ip;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.ip = expected;
    actual = item.ip;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITLocation *item = [BITLocation new];
    item.ip = @"Test string";
    NSString *actual = [item serializeToString];
    NSString *expected = @"{\"ai.location.ip\":\"Test string\"}";
    XCTAssertTrue([actual isEqualToString:expected]);
}

@end
