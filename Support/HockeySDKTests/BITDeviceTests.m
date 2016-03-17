#import <XCTest/XCTest.h>
#import "BITDevice.h"

@interface BITDeviceTests : XCTestCase

@end

@implementation BITDeviceTests

- (void)testidPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.deviceId = expected;
    NSString *actual = item.deviceId;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.deviceId = expected;
    actual = item.deviceId;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testipPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.ip = expected;
    NSString *actual = item.ip;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.ip = expected;
    actual = item.ip;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testlanguagePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.language = expected;
    NSString *actual = item.language;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.language = expected;
    actual = item.language;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testlocalePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.locale = expected;
    NSString *actual = item.locale;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.locale = expected;
    actual = item.locale;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testmodelPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.model = expected;
    NSString *actual = item.model;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.model = expected;
    actual = item.model;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testnetworkPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.network = expected;
    NSString *actual = item.network;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.network = expected;
    actual = item.network;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testoem_namePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.oemName = expected;
    NSString *actual = item.oemName;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.oemName = expected;
    actual = item.oemName;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testosPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.os = expected;
    NSString *actual = item.os;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.os = expected;
    actual = item.os;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testos_versionPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.osVersion = expected;
    NSString *actual = item.osVersion;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.osVersion = expected;
    actual = item.osVersion;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testrole_instancePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.roleInstance = expected;
    NSString *actual = item.roleInstance;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.roleInstance = expected;
    actual = item.roleInstance;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testrole_namePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.roleName = expected;
    NSString *actual = item.roleName;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.roleName = expected;
    actual = item.roleName;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testscreen_resolutionPropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.screenResolution = expected;
    NSString *actual = item.screenResolution;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.screenResolution = expected;
    actual = item.screenResolution;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testtypePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.type = expected;
    NSString *actual = item.type;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.type = expected;
    actual = item.type;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testvm_namePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITDevice *item = [BITDevice new];
    item.machineName = expected;
    NSString *actual = item.machineName;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.machineName = expected;
    actual = item.machineName;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
    BITDevice *item = [BITDevice new];
    item.deviceId = @"Test string";
    item.ip = @"Test string";
    item.language = @"Test string";
    item.locale = @"Test string";
    item.model = @"Test string";
    item.network = @"Test string";
    item.networkName = @"Test networkName";
    item.oemName = @"Test string";
    item.os = @"Test string";
    item.osVersion = @"Test string";
    item.roleInstance = @"Test string";
    item.roleName = @"Test string";
    item.screenResolution = @"Test string";
    item.type = @"Test string";
    item.machineName = @"Test string";
    item.vmName = @"Test vmName";
    NSDictionary *actual = [item serializeToDictionary];
    NSDictionary *expected = @{@"ai.device.id":@"Test string", @"ai.device.ip":@"Test string", @"ai.device.language":@"Test string", @"ai.device.locale":@"Test string", @"ai.device.model":@"Test string", @"ai.device.network":@"Test string", @"ai.device.networkName":@"Test networkName", @"ai.device.oemName":@"Test string", @"ai.device.os":@"Test string", @"ai.device.osVersion":@"Test string", @"ai.device.roleInstance":@"Test string", @"ai.device.roleName":@"Test string", @"ai.device.screenResolution":@"Test string", @"ai.device.type":@"Test string", @"ai.device.machineName":@"Test string", @"ai.device.vmName":@"Test vmName"};
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
