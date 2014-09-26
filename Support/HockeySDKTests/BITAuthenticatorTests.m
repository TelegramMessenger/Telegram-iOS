//
//  HockeySDKTests.m
//  HockeySDKTests
//
//  Created by Andreas Linde on 13.03.13.
//
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITAuthenticator.h"
#import "BITAuthenticator_Private.h"
#import "BITHTTPOperation.h"
#import "BITTestHelper.h"
#import "BITHockeyAppClient.h"

@interface MyDevice : NSObject
- (NSString*) uniqueIdentifier;
@end
@implementation MyDevice
- (NSString*) uniqueIdentifier {return @"reallyUnique";}
@end

@interface MyDeviceWithIdentifierForVendor : MyDevice
@property (copy) NSUUID *identifierForVendor;
@end
@implementation MyDeviceWithIdentifierForVendor

- (instancetype)init {
  self = [super init];
  if( self ) {
    _identifierForVendor = [NSUUID UUID];
  }
  return self;
}

@end

static void *kInstallationIdentification = &kInstallationIdentification;

@interface BITAuthenticatorTests : XCTestCase
@end

@implementation BITAuthenticatorTests {
  BITAuthenticator *_sut;
  BOOL _KVOCalled;
}

- (void)setUp {
  [super setUp];
  
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironment:NO];
}

- (void)tearDown {
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wimplicit"
  __gcov_flush();
# pragma clang diagnostic pop
  
  [_sut cleanupInternalStorage];
  _sut = nil;
  
  [super tearDown];
}

#pragma mark - Setup helpers
- (NSDictionary *)jsonFromFixture:(NSString *)fixture {
  NSString *dataString = [BITTestHelper jsonFixture:fixture];
  
  NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  
  return json;
}

#pragma mark - Setup Tests
- (void) testThatItInstantiates {
  XCTAssertNotNil(_sut, @"Should be there");
}

#pragma mark - Persistence Tests
- (void) testThatLastAuthenticatedVersionIsPersisted {
  _sut.lastAuthenticatedVersion = @"1.2.1";
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironment:YES];
  assertThat(_sut.lastAuthenticatedVersion, equalTo(@"1.2.1"));
}

- (void) testThatCleanupWorks {
  _sut.lastAuthenticatedVersion = @"1.2";
  
  [_sut cleanupInternalStorage];
  
  assertThat(_sut.lastAuthenticatedVersion, equalTo(nil));
  assertThat(_sut.installationIdentifier, equalTo(nil));
}

#pragma mark - Initial defaults
- (void) testDefaultValues {
  assertThatBool(_sut.restrictApplicationUsage, equalToBool(NO));
  assertThatBool(_sut.isIdentified, equalToBool(NO));
  assertThatBool(_sut.isValidated, equalToBool(NO));
  assertThat(_sut.authenticationSecret, equalTo(nil));
  assertThat(_sut.installationIdentifier, equalTo(nil));
  assertThat(_sut.installationIdentifierParameterString, equalTo(@"uuid"));
}

#pragma mark - General identification tests
- (void) testThatIsDoesntShowMoreThanOneAuthenticationController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  
  [_sut identifyWithCompletion:nil];
  [_sut identifyWithCompletion:nil];
  [_sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatChangingIdentificationTypeResetsIdentifiedFlag {
  _sut.identified = YES;
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  assertThatBool(_sut.identified, equalToBool(NO));
}

- (void) testThatAfterChangingIdentificationTypeIdentificationIsRedone {
  [_sut storeInstallationIdentifier:@"meh" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  _sut.identified = YES;
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  [_sut identifyWithCompletion:nil];
  assertThatBool(_sut.identified, equalToBool(NO));
  assertThat(_sut.installationIdentifier, nilValue());
}

- (void) testThatIdentifyingAnAlreadyIdentifiedInstanceDoesNothing {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [_sut storeInstallationIdentifier:@"meh" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  _sut.identified = YES;
  
  [_sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, never()) authenticator:_sut willShowAuthenticationController:(id)anything()];
}


#pragma mark - Anonymous identification type
- (void) testAnonymousIdentification {
  _sut.identificationType = BITAuthenticatorIdentificationTypeAnonymous;
  assertThatBool(_sut.isIdentified, equalToBool(NO));
  [_sut identifyWithCompletion:^(BOOL identified, NSError *error) {
    assertThatBool(identified, equalToBool(YES));
    assertThat(error, equalTo(nil));
  }];
  assertThatBool(_sut.isIdentified, equalToBool(YES));
  assertThat(_sut.installationIdentifier, notNilValue());
}

//anoynmous users can't be validated
- (void) testAnonymousValidation {
  _sut.identificationType = BITAuthenticatorIdentificationTypeAnonymous;
  assertThatBool(_sut.isValidated, equalToBool(NO));
  [_sut validateWithCompletion:^(BOOL validated, NSError *error) {
    assertThatBool(_sut.validated, equalToBool(NO));
    assertThat(error, notNilValue());
  }];
  assertThatBool(_sut.isValidated, equalToBool(NO));
}

#pragma mark - Device identification type
- (void) testDeviceIdentificationShowsViewController {
  _sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;

  [_sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}
#pragma mark - Web auth identification type
- (void) testWebAuthIdentificationShowsViewController {
  _sut.identificationType = BITAuthenticatorIdentificationTypeWebAuth;
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  
  [_sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

#pragma mark - Email identification type
- (void) testEmailIdentificationFailsWithMissingSecret {
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [_sut identifyWithCompletion:^(BOOL identified, NSError *error) {
    assertThatBool(identified, equalToBool(NO));
    assertThat(error, notNilValue());
  }];
}

- (void) testEmailIdentificationShowsViewController {
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  _sut.authenticationSecret = @"mySecret";
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  
  [_sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testEmailValidationFailsWithMissingSecret {
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [_sut validateWithCompletion:^(BOOL validated, NSError *error) {
    assertThatBool(validated, equalToBool(NO));
    assertThat(error, notNilValue());
  }];
}

- (void) testThatEmailIdentificationQueuesAnOperation {
  id httpClientMock = mock(BITHockeyAppClient.class);
  _sut.hockeyAppClient = httpClientMock;
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [_sut storeInstallationIdentifier:@"meh" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  _sut.authenticationSecret = @"double";
  [_sut authenticationViewController:nil
       handleAuthenticationWithEmail:@"stephan@dd.de"
                            password:@"nopass"
                          completion:nil];
  [verify(httpClientMock) enqeueHTTPOperation:anything()];
}

#pragma mark - User identification type
- (void) testUserIdentificationShowsViewController {
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  
  [_sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}


#pragma mark - Generic validation tests
- (void) testThatValidationFailsIfNotIdentified {
  _sut.identified = NO;
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  [_sut validateWithCompletion:^(BOOL validated, NSError *error) {
    assertThatBool(validated, equalToBool(NO));
    assertThatLong(error.code, equalToLong(BITAuthenticatorNotIdentified));
  }];
}

- (void) testThatValidationCreatesAGETRequest {
  id httpClientMock = mock(BITHockeyAppClient.class);
  _sut.hockeyAppClient = httpClientMock;
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [_sut storeInstallationIdentifier:@"meh" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  _sut.authenticationSecret = @"double";
  [_sut validateWithCompletion:nil];
  [verify(httpClientMock) getPath:(id)anything()
                       parameters:(id)anything()
                       completion:(id)anything()];
}

#pragma mark - Authentication
- (void) testThatEnabledRestrictionTriggersValidation {
  id clientMock = mock(BITHockeyAppClient.class);
  _sut.hockeyAppClient = clientMock;
  _sut.authenticationSecret = @"sekret";
  _sut.restrictApplicationUsage = YES;
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [_sut storeInstallationIdentifier:@"asd" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  [_sut authenticate];
  
  [verify(clientMock) getPath:(id)anything() parameters:(id)anything() completion:(id)anything()];
}

- (void) testThatDisabledRestrictionDoesntTriggerValidation {
  id clientMock = mock(BITHockeyAppClient.class);
  _sut.hockeyAppClient = clientMock;
  _sut.authenticationSecret = @"sekret";
  _sut.restrictApplicationUsage = NO;
  _sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [_sut storeInstallationIdentifier:@"asd" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  [_sut authenticate];
  
  [verifyCount(clientMock, never()) getPath:(id)anything() parameters:(id)anything() completion:(id)anything()];
}

#pragma mark - Lifetime checks
- (void) testThatValidationTriggersOnDidBecomeActive {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  _sut.restrictApplicationUsage = YES;
  
  [_sut applicationDidBecomeActive:nil];
  
  [verify(delegateMock) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

#pragma mark - Validation helper checks
- (void) testThatValidationTriggersOnNewVersion {
  _sut.restrictApplicationUsage = YES;
  _sut.restrictionEnforcementFrequency = BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch;
  _sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  _sut.validated = YES;
  _sut.lastAuthenticatedVersion = @"111xxx";
  assertThatBool(_sut.needsValidation, equalToBool(YES));
}

- (void) testThatValidationDoesNotTriggerOnSameVersion {
  _sut.restrictApplicationUsage = YES;
  _sut.restrictionEnforcementFrequency = BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch;
  _sut.validated = YES;
  _sut.lastAuthenticatedVersion = _sut.executableUUID;
  assertThatBool(_sut.needsValidation, equalToBool(NO));
}

@end
