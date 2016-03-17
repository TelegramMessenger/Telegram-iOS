#import <XCTest/XCTest.h>
#import "BITUser.h"

@interface BITUserTests : XCTestCase

@end

@implementation BITUserTests

- (void)testaccount_acquisition_datePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITUser *item = [BITUser new];
    item.accountAcquisitionDate = expected;
    NSString *actual = item.accountAcquisitionDate;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.accountAcquisitionDate = expected;
    actual = item.accountAcquisitionDate;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testaccount_idPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITUser *item = [BITUser new];
    item.accountId = expected;
    NSString *actual = item.accountId;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.accountId = expected;
    actual = item.accountId;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testuser_agentPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITUser *item = [BITUser new];
    item.userAgent = expected;
    NSString *actual = item.userAgent;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.userAgent = expected;
    actual = item.userAgent;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testidPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITUser *item = [BITUser new];
    item.userId = expected;
    NSString *actual = item.userId;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.userId = expected;
    actual = item.userId;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITUser *item = [BITUser new];
    item.accountAcquisitionDate = @"Test string";
    item.accountId = @"Test string";
    item.userAgent = @"Test string";
    item.userId = @"Test string";
    item.storeRegion = @"Test region";
    item.authUserId = @"Test authUserId";
    item.anonUserAcquisitionDate = @"Test anonUserAcquisitionDate";
    item.authUserAcquisitionDate = @"Test authUserAcquisitionDate";
    NSDictionary *actual = [item serializeToDictionary];
    NSDictionary *expected = @{@"ai.user.accountAcquisitionDate":@"Test string", @"ai.user.accountId":@"Test string", @"ai.user.userAgent":@"Test string", @"ai.user.id":@"Test string", @"ai.user.storeRegion":@"Test region", @"ai.user.authUserId":@"Test authUserId", @"ai.user.anonUserAcquisitionDate":@"Test anonUserAcquisitionDate", @"ai.user.authUserAcquisitionDate":@"Test authUserAcquisitionDate"};
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
