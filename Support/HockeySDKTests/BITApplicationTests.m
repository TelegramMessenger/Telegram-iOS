#import <XCTest/XCTest.h>
#import "BITApplication.h"

@interface BITApplicationTests : XCTestCase

@end

@implementation BITApplicationTests

- (void)testverPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITApplication *item = [BITApplication new];
    item.version = expected;
    NSString *actual = item.version;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.version = expected;
    actual = item.version;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITApplication *item = [BITApplication new];
    item.version = @"Test string";
    item.build = @"Test build";
    item.typeId = @"Test typeId";
    NSDictionary *actual = [item serializeToDictionary];
    NSDictionary *expected = @{@"ai.application.ver":@"Test string", @"ai.application.build":@"Test build", @"ai.application.typeId":@"Test typeId"};
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
