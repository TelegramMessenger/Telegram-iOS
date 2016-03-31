#import <XCTest/XCTest.h>
#import "BITDomain.h"

@interface BITDomainTests : XCTestCase

@end

@implementation BITDomainTests

- (void)testSerialize {
    BITDomain *item = [BITDomain new];
    NSString *actual = [item serializeToString];
    NSString *expected = @"{}";
    XCTAssertTrue([actual isEqualToString:expected]);
}

@end
