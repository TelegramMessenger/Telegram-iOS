#import <XCTest/XCTest.h>
#import "BITSession.h"

@interface BITSessionTests : XCTestCase

@end

@implementation BITSessionTests

- (void)testidPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITSession *item = [BITSession new];
    item.sessionId = expected;
    NSString *actual = item.sessionId;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.sessionId = expected;
    actual = item.sessionId;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testis_firstPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITSession *item = [BITSession new];
    item.isFirst = expected;
    NSString *actual = item.isFirst;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.isFirst = expected;
    actual = item.isFirst;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testis_newPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITSession *item = [BITSession new];
    item.isNew = expected;
    NSString *actual = item.isNew;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.isNew = expected;
    actual = item.isNew;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITSession *item = [BITSession new];
    item.sessionId = @"Test string";
    item.isFirst = @"Test string";
    item.isNew = @"Test string";
    NSDictionary *actual = [item serializeToDictionary];
    NSDictionary *expected = @{@"ai.session.id":@"Test string", @"ai.session.isFirst":@"Test string", @"ai.session.isNew":@"Test string"};
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
