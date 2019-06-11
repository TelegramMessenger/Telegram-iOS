#import <XCTest/XCTest.h>
#import "BITDomain.h"

@interface BITDomainTests : XCTestCase

@end

@implementation BITDomainTests

- (void)testSerialize {
    BITDomain *item = [BITDomain new];
    NSDictionary *actual = [item serializeToDictionary];
    NSDictionary *expected = @{};
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
