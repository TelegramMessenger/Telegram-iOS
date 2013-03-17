//
//  HockeySDKTests.m
//  HockeySDKTests
//
//  Created by Andreas Linde on 13.03.13.
//
//

#import <SenTestingKit/SenTestingKit.h>

// Uncomment the next two lines to use OCHamcrest for test assertions:
#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

// Uncomment the next two lines to use OCMockito for mock objects:
#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "BITStoreUpdateManager.h"
#import "BITStoreUpdateManagerPrivate.h"
#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITTestHelper.h"


@interface BITStoreUpdateManagerTests : SenTestCase

@end


@implementation BITStoreUpdateManagerTests {
  BITStoreUpdateManager *_storeUpdateManager;
}

- (void)setUp {
  [super setUp];
  
  // Set-up code here.
  _storeUpdateManager = [[BITStoreUpdateManager alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
}

- (void)tearDown {
  // Tear-down code here.
  _storeUpdateManager = nil;
  
  [super tearDown];
}


#pragma mark - Private

- (NSDictionary *)jsonFromFixture:(NSString *)fixture {
  NSString *dataString = [BITTestHelper jsonFixture:fixture];
  
  NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
  
  return json;
}

- (void)startManager {
  _storeUpdateManager.enableStoreUpdateManager = YES;
  [_storeUpdateManager startManager];
  [NSObject cancelPreviousPerformRequestsWithTarget:_storeUpdateManager selector:@selector(checkForUpdateDelayed) object:nil];
}


#pragma mark - Time


#pragma mark - JSON Response Processing

- (void)testProcessStoreResponseWithEmptyData {
  BOOL result = [_storeUpdateManager processStoreResponseWithString:nil];
  
  STAssertFalse(result, @"Empty data was handled correctly");
}

- (void)testProcessStoreResponseWithInvalidData {
  NSString *invalidString = @"8a@c&)if";
  BOOL result = [_storeUpdateManager processStoreResponseWithString:invalidString];
  
  STAssertFalse(result, @"Invalid JSON data was handled correctly");
}

- (void)testProcessStoreResponseWithUnknownBundleIdentifier {
  NSString *dataString = [BITTestHelper jsonFixture:@"StoreBundleIdentifierUnknown"];
  BOOL result = [_storeUpdateManager processStoreResponseWithString:dataString];
  
  STAssertFalse(result, @"Valid but empty json data was handled correctly");
}

- (void)testProcessStoreResponseWithKnownBundleIdentifier {
  NSString *dataString = [BITTestHelper jsonFixture:@"StoreBundleIdentifierKnown"];
  BOOL result = [_storeUpdateManager processStoreResponseWithString:dataString];

  STAssertTrue(result, @"Valid and correct JSON data was handled correctly");
}


#pragma mark - Last version

#pragma mark - Version compare

- (void)testFirstStartHasNewVersionReturnsFalseWithFirstCheck {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];

  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];

  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  STAssertFalse(result, @"There is no udpate available");
}

- (void)testFirstStartHasNewVersionReturnsFalseWithSameVersion {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.2"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  STAssertFalse(result, @"There is no udpate available");
}


- (void)testFirstStartHasNewVersionReturnsFalseWithSameVersionButDifferentUUID {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.2"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@"1"];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  STAssertFalse(result, @"There is no udpate available");
}

- (void)testFirstStartHasNewVersionReturnsTrue {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.1"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  STAssertTrue(result, @"There is an udpate available");
}


- (void)testFirstStartHasNewVersionReturnsFalseBecauseWeHaveANewerVersionInstalled {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.3"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  _storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [_storeUpdateManager hasNewVersion:json];
  
  STAssertFalse(result, @"There is no udpate available");
}

@end
