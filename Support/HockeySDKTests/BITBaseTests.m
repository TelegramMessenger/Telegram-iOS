#import <XCTest/XCTest.h>
#import "BITBase.h"

@interface BITBaseTests : XCTestCase

@end

@implementation BITBaseTests

- (void)testbase_typePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITBase *item = [BITBase new];
    item.baseType = expected;
    NSString *actual = item.baseType;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.baseType = expected;
    actual = item.baseType;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITBase *item = [BITBase new];
    item.baseType = @"Test string";
    NSString *actual = [item serializeToString];
    NSString *expected = @"{\"baseType\":\"Test string\"}";
    XCTAssertTrue([actual isEqualToString:expected]);
}

@end
