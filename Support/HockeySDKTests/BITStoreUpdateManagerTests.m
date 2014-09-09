//
//  HockeySDKTests.m
//  HockeySDKTests
//
//  Created by Andreas Linde on 13.03.13.
//
//

#import <XCTest/XCTest.h>

// Uncomment the next two lines to use OCHamcrest for test assertions:
#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

// Uncomment the next two lines to use OCMockito for mock objects:
#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDKFeatureConfig.h"
#import "BITStoreUpdateManager.h"
#import "BITStoreUpdateManagerPrivate.h"
#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITTestHelper.h"


@interface BITStoreUpdateManagerTests : XCTestCase

@end


@implementation BITStoreUpdateManagerTests {
  BITStoreUpdateManager *_storeUpdateManager;
}

- (void)setUp {
  [super setUp];
  
  // Set-up code here.
  _storeUpdateManager = [[BITStoreUpdateManager alloc] initWithAppIdentifier:nil isAppStoreEnvironment:YES];
}

- (void)tearDown {
  // Tear-down code here.
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wimplicit"
  __gcov_flush();
# pragma clang diagnostic pop
  
  _storeUpdateManager = nil;
  
  [super tearDown];
}


#pragma mark - Private

- (NSDictionary *)jsonFromFixture:(NSString *)fixture {
  NSString *dataString = [BITTestHelper jsonFixture:fixture];
  
  NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  
  return json;
}

- (void)startManager {
  _storeUpdateManager.enableStoreUpdateManager = YES;
  [_storeUpdateManager startManager];
  [NSObject cancelPreviousPerformRequestsWithTarget:_storeUpdateManager selector:@selector(checkForUpdateDelayed) object:nil];
}


#pragma mark - Time

- (void)testUpdateCheckDailyFirstTimeEver {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking daily first time ever");
}

- (void)testUpdateCheckDailyFirstTimeTodayLastCheckPreviousDay {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24)]];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  _storeUpdateManager.updateSetting = BITStoreUpdateCheckDaily;
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking daily first time today with last check done previous day");
}

- (void)testUpdateCheckDailySecondTimeOfTheDay {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  _storeUpdateManager.userDefaults = mockUserDefaults;
  _storeUpdateManager.lastCheck = [NSDate date];
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking daily second time of the day");
}

- (void)testUpdateCheckWeeklyFirstTimeEver {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  _storeUpdateManager.userDefaults = mockUserDefaults;
  _storeUpdateManager.updateSetting = BITStoreUpdateCheckWeekly;
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking weekly first time ever");
}

- (void)testUpdateCheckWeeklyFirstTimeTodayLastCheckPreviousWeek {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24*7)]];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  _storeUpdateManager.updateSetting = BITStoreUpdateCheckWeekly;
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking weekly first time after one week");
}

- (void)testUpdateCheckWeeklyFirstTimeFiveDaysAfterPreviousCheck {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24*5)]];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  _storeUpdateManager.updateSetting = BITStoreUpdateCheckWeekly;
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking weekly first time five days after previous check");
}

- (void)testUpdateCheckManuallyFirstTimeEver {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  _storeUpdateManager.userDefaults = mockUserDefaults;
  _storeUpdateManager.updateSetting = BITStoreUpdateCheckManually;
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking manually first time ever");
}

- (void)testUpdateCheckManuallyFirstTimeTodayLastCheckDonePreviousDay {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24)]];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  _storeUpdateManager.updateSetting = BITStoreUpdateCheckManually;
  
  [self startManager];
  
  BOOL result = [_storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking manually first time ever");
}


#pragma mark - JSON Response Processing

- (void)testProcessStoreResponseWithEmptyData {
  BOOL result = [_storeUpdateManager processStoreResponseWithString:nil];
  
  XCTAssertFalse(result, @"Empty data was handled correctly");
}

- (void)testProcessStoreResponseWithInvalidData {
  NSString *invalidString = @"8a@c&)if";
  BOOL result = [_storeUpdateManager processStoreResponseWithString:invalidString];
  
  XCTAssertFalse(result, @"Invalid JSON data was handled correctly");
}

- (void)testProcessStoreResponseWithUnknownBundleIdentifier {
  NSString *dataString = [BITTestHelper jsonFixture:@"StoreBundleIdentifierUnknown"];
  BOOL result = [_storeUpdateManager processStoreResponseWithString:dataString];
  
  XCTAssertFalse(result, @"Valid but empty json data was handled correctly");
}

- (void)testProcessStoreResponseWithKnownBundleIdentifier {
  NSString *dataString = [BITTestHelper jsonFixture:@"StoreBundleIdentifierKnown"];
  BOOL result = [_storeUpdateManager processStoreResponseWithString:dataString];

  XCTAssertTrue(result, @"Valid and correct JSON data was handled correctly");
}


#pragma mark - Last version

#pragma mark - Version compare

- (void)testFirstStartHasNewVersionReturnsFalseWithFirstCheck {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];

  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];

  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}

- (void)testFirstStartHasNewVersionReturnsFalseWithSameVersion {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.2"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}


- (void)testFirstStartHasNewVersionReturnsFalseWithSameVersionButDifferentUUID {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.2"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@"1"];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}

- (void)testFirstStartHasNewVersionReturnsTrue {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.1"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  XCTAssertTrue(result, @"There is an udpate available");
}


- (void)testFirstStartHasNewVersionReturnsFalseBecauseWeHaveANewerVersionInstalled {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.3"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}

- (void)testReportedVersionIsBeingIgnored {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.1"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateIgnoredVersion"]) willReturn:@"4.1.2"];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"The newer version is being ignored");
}

- (void)testReportedVersionIsNewerThanTheIgnoredVersion {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.1"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateIgnoredVersion"]) willReturn:@"4.1.1"];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  XCTAssertTrue(result, @"The newer version is not ignored");
}

@end
