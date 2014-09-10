//
//  BITFeedbackManagerTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 24.03.14.
//
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITFeedbackManager.h"
#import "BITFeedbackManagerPrivate.h"
#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITTestHelper.h"

@interface BITFeedbackManagerTests : XCTestCase

@end

@implementation BITFeedbackManagerTests {
  BITFeedbackManager *_sut;
}

- (void)setUp {
  [super setUp];

  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  hm.delegate = nil;
  _sut = [[BITFeedbackManager alloc] initWithAppIdentifier:nil isAppStoreEnvironment:NO];
  _sut.delegate = nil;
}

- (void)tearDown {
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wimplicit"
  __gcov_flush();
# pragma clang diagnostic pop
 
  [_sut removeKeyFromKeychain:kBITHockeyMetaUserID];
  [_sut removeKeyFromKeychain:kBITHockeyMetaUserName];
  [_sut removeKeyFromKeychain:kBITHockeyMetaUserEmail];

  _sut = nil;
  
  [super tearDown];
}

#pragma mark - Private

- (void)startManager {
  [_sut startManager];
}

#pragma mark - Setup Tests


#pragma mark - User Metadata

- (void)testUpdateUserIDWithNoDataPresent {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  _sut.delegate = delegateMock;
  
  BOOL dataAvailable = [_sut updateUserIDUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(NO));
  assertThat(_sut.userID, nilValue());
  
  [verifyCount(delegateMock, times(1)) userIDForHockeyManager:hm componentManager:_sut];
}

- (void)testUpdateUserIDWithDelegateReturningData {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  NSObject <BITHockeyManagerDelegate> *classMock = mockObjectAndProtocol([NSObject class], @protocol(BITHockeyManagerDelegate));
  [given([classMock userIDForHockeyManager:hm componentManager:_sut]) willReturn:@"test"];
  hm.delegate = classMock;
  _sut.delegate = classMock;
  
  BOOL dataAvailable = [_sut updateUserIDUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userID, equalTo(@"test"));
  
  [verifyCount(classMock, times(1)) userIDForHockeyManager:hm componentManager:_sut];
}

- (void)testUpdateUserIDWithValueInKeychain {
  [_sut addStringValueToKeychain:@"test" forKey:kBITHockeyMetaUserID];
  
  BOOL dataAvailable = [_sut updateUserIDUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userID, equalTo(@"test"));
}

- (void)testUpdateUserIDWithGlobalSetter {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  [hm setUserID:@"test"];
  
  BOOL dataAvailable = [_sut updateUserIDUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userID, equalTo(@"test"));
}


- (void)testUpdateUserNameWithNoDataPresent {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  _sut.delegate = delegateMock;
  
  BOOL dataAvailable = [_sut updateUserNameUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(NO));
  assertThat(_sut.userName, nilValue());
  
  [verifyCount(delegateMock, times(1)) userNameForHockeyManager:hm componentManager:_sut];
}

- (void)testUpdateUserNameWithDelegateReturningData {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  NSObject <BITHockeyManagerDelegate> *classMock = mockObjectAndProtocol([NSObject class], @protocol(BITHockeyManagerDelegate));
  [given([classMock userNameForHockeyManager:hm componentManager:_sut]) willReturn:@"test"];
  hm.delegate = classMock;
  _sut.delegate = classMock;
  
  BOOL dataAvailable = [_sut updateUserNameUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userName, equalTo(@"test"));
  
  [verifyCount(classMock, times(1)) userNameForHockeyManager:hm componentManager:_sut];
}

- (void)testUpdateUserNameWithValueInKeychain {
  [_sut addStringValueToKeychain:@"test" forKey:kBITHockeyMetaUserName];
  
  BOOL dataAvailable = [_sut updateUserNameUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userName, equalTo(@"test"));
}

- (void)testUpdateUserNameWithGlobalSetter {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  [hm setUserName:@"test"];
  
  BOOL dataAvailable = [_sut updateUserNameUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userName, equalTo(@"test"));
}


- (void)testUpdateUserEmailWithNoDataPresent {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  _sut.delegate = delegateMock;
  
  BOOL dataAvailable = [_sut updateUserEmailUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(NO));
  assertThat(_sut.userEmail, nilValue());
  
  [verifyCount(delegateMock, times(1)) userEmailForHockeyManager:hm componentManager:_sut];
}

- (void)testUpdateUserEmailWithDelegateReturningData {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  NSObject <BITHockeyManagerDelegate> *classMock = mockObjectAndProtocol([NSObject class], @protocol(BITHockeyManagerDelegate));
  [given([classMock userEmailForHockeyManager:hm componentManager:_sut]) willReturn:@"test"];
  hm.delegate = classMock;
  _sut.delegate = classMock;
  
  BOOL dataAvailable = [_sut updateUserEmailUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userEmail, equalTo(@"test"));
  
  [verifyCount(classMock, times(1)) userEmailForHockeyManager:hm componentManager:_sut];
}

- (void)testUpdateUserEmailWithValueInKeychain {
  [_sut addStringValueToKeychain:@"test" forKey:kBITHockeyMetaUserEmail];
  
  BOOL dataAvailable = [_sut updateUserEmailUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userEmail, equalTo(@"test"));
}

- (void)testUpdateUserEmailWithGlobalSetter {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  [hm setUserEmail:@"test"];
  
  BOOL dataAvailable = [_sut updateUserEmailUsingKeychainAndDelegate];
  
  assertThatBool(dataAvailable, equalToBool(YES));
  assertThat(_sut.userEmail, equalTo(@"test"));
}


@end
