#import <XCTest/XCTest.h>
#import "BITOperation.h"

@interface BITOperationTests : XCTestCase

@end

@implementation BITOperationTests

- (void)testidPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITOperation *item = [BITOperation new];
    item.operationId = expected;
    NSString *actual = item.operationId;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.operationId = expected;
    actual = item.operationId;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testnamePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITOperation *item = [BITOperation new];
    item.name = expected;
    NSString *actual = item.name;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.name = expected;
    actual = item.name;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testparent_idPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITOperation *item = [BITOperation new];
    item.parentId = expected;
    NSString *actual = item.parentId;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.parentId = expected;
    actual = item.parentId;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testroot_idPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITOperation *item = [BITOperation new];
    item.rootId = expected;
    NSString *actual = item.rootId;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.rootId = expected;
    actual = item.rootId;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITOperation *item = [BITOperation new];
    item.operationId = @"Test string";
    item.name = @"Test string";
    item.parentId = @"Test string";
    item.rootId = @"Test string";
    item.syntheticSource = @"Test source";
    item.isSynthetic = @"false";
    NSString *actual = [item serializeToString];
    NSString *expected = @"{\"ai.operation.id\":\"Test string\",\"ai.operation.name\":\"Test string\",\"ai.operation.parentId\":\"Test string\",\"ai.operation.rootId\":\"Test string\",\"ai.operation.syntheticSource\":\"Test source\",\"ai.operation.isSynthetic\":false}";
    XCTAssertTrue([actual isEqualToString:expected]);
}

@end
