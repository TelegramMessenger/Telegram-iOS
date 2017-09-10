//
//  BITAuthenticatorTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 13.03.13.
//
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITAuthenticator_Private.h"
#import "BITHockeyBaseManagerPrivate.h"
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

@property(nonatomic, strong) BITAuthenticator *sut;

@end

@implementation BITAuthenticatorTests

- (void)setUp {
  [super setUp];
  
  self.sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil appEnvironment:BITEnvironmentOther];
}

- (void)tearDown {
  [self.sut cleanupInternalStorage];
  self.sut = nil;
  
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
  XCTAssertNotNil(self.sut, @"Should be there");
}

#pragma mark - Persistence Tests
- (void) testThatLastAuthenticatedVersionIsPersisted {
  self.sut.lastAuthenticatedVersion = @"1.2.1";
  self.sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil appEnvironment:BITEnvironmentAppStore];
  assertThat(self.sut.lastAuthenticatedVersion, equalTo(@"1.2.1"));
}

- (void) testThatCleanupWorks {
  self.sut.lastAuthenticatedVersion = @"1.2";
  self.sut.identified = YES;
  self.sut.validated = YES;
  
  [self.sut cleanupInternalStorage];
  
  assertThat(self.sut.lastAuthenticatedVersion, equalTo(nil));
  assertThat(self.sut.installationIdentifier, equalTo(nil));
  assertThatBool(self.sut.isIdentified, isFalse());
  assertThatBool(self.sut.isValidated, isFalse());
}

#pragma mark - Initial defaults
- (void) testDefaultValues {
  assertThatBool(self.sut.restrictApplicationUsage, isFalse());
  assertThatBool(self.sut.isIdentified, isFalse());
  assertThatBool(self.sut.isValidated, isFalse());
  assertThat(self.sut.authenticationSecret, equalTo(nil));
  assertThat(self.sut.installationIdentifier, equalTo(nil));
  assertThat(self.sut.installationIdentifierParameterString, equalTo(@"uuid"));
}

#pragma mark - General identification tests
- (void) testThatIsDoesntShowMoreThanOneAuthenticationController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  self.sut.delegate = delegateMock;
  self.sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  
  [self.sut identifyWithCompletion:nil];
  [self.sut identifyWithCompletion:nil];
  [self.sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:self.sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatChangingIdentificationTypeResetsIdentifiedFlag {
  self.sut.identified = YES;
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  assertThatBool(self.sut.identified, isFalse());
}

- (void) testThatAfterChangingIdentificationTypeIdentificationIsRedone {
  [self.sut storeInstallationIdentifier:@"meh" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  self.sut.identified = YES;
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  [self.sut identifyWithCompletion:nil];
  assertThatBool(self.sut.identified, isFalse());
  assertThat(self.sut.installationIdentifier, nilValue());
}

- (void) testThatIdentifyingAnAlreadyIdentifiedInstanceDoesNothing {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  self.sut.delegate = delegateMock;
  
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [self.sut storeInstallationIdentifier:@"meh" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  self.sut.identified = YES;
  
  [self.sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, never()) authenticator:self.sut willShowAuthenticationController:(id)anything()];
}


#pragma mark - Anonymous identification type
- (void) testAnonymousIdentification {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeAnonymous;
  assertThatBool(self.sut.isIdentified, isFalse());
  [self.sut identifyWithCompletion:^(BOOL identified, NSError *error) {
    assertThatBool(identified, isTrue());
    assertThat(error, equalTo(nil));
  }];
  assertThatBool(self.sut.isIdentified, isTrue());
  assertThat(self.sut.installationIdentifier, notNilValue());
}

//anoynmous users can't be validated
- (void) testAnonymousValidation {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeAnonymous;
  assertThatBool(self.sut.isValidated, isFalse());
  [self.sut validateWithCompletion:^(BOOL __unused validated, NSError *error) {
    assertThatBool(self.sut.validated, isFalse());
    assertThat(error, notNilValue());
  }];
  assertThatBool(self.sut.isValidated, isFalse());
}

#pragma mark - Device identification type
- (void) testDeviceIdentificationShowsViewController {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  self.sut.delegate = delegateMock;

  [self.sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:self.sut willShowAuthenticationController:(id)anything()];
}
#pragma mark - Web auth identification type
- (void) testWebAuthIdentificationShowsViewController {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeWebAuth;
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  self.sut.delegate = delegateMock;
  
  [self.sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:self.sut willShowAuthenticationController:(id)anything()];
}

#pragma mark - Email identification type
- (void) testEmailIdentificationFailsWithMissingSecret {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [self.sut identifyWithCompletion:^(BOOL identified, NSError *error) {
    assertThatBool(identified, isFalse());
    assertThat(error, notNilValue());
  }];
}

- (void) testEmailIdentificationShowsViewController {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  self.sut.authenticationSecret = @"mySecret";
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  self.sut.delegate = delegateMock;
  
  [self.sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:self.sut willShowAuthenticationController:(id)anything()];
}

- (void) testEmailValidationFailsWithMissingSecret {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [self.sut validateWithCompletion:^(BOOL validated, NSError *error) {
    assertThatBool(validated, isFalse());
    assertThat(error, notNilValue());
  }];
}

#pragma mark - User identification type
- (void) testUserIdentificationShowsViewController {
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  self.sut.delegate = delegateMock;
  
  [self.sut identifyWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:self.sut willShowAuthenticationController:(id)anything()];
}


#pragma mark - Generic validation tests
- (void) testThatValidationFailsIfNotIdentified {
  self.sut.identified = NO;
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppUser;
  [self.sut validateWithCompletion:^(BOOL validated, NSError *error) {
    assertThatBool(validated, isFalse());
    assertThatLong(error.code, equalToLong(BITAuthenticatorNotIdentified));
  }];
}

#pragma mark - Authentication
- (void) testThatEnabledRestrictionTriggersValidation {
  id mockAuthenticator = OCMPartialMock(self.sut);
  self.sut.authenticationSecret = @"sekret";
  self.sut.restrictApplicationUsage = YES;
  self.sut.identificationType = BITAuthenticatorIdentificationTypeHockeyAppEmail;
  [self.sut storeInstallationIdentifier:@"asd" withType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
  
  
  OCMExpect([mockAuthenticator validateWithCompletion:(id)anything()]);
  [self.sut authenticate];
  OCMVerifyAll(mockAuthenticator);
}

#pragma mark - Lifetime checks
- (void) testThatValidationTriggersOnDidBecomeActive {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  self.sut.delegate = delegateMock;
  self.sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  self.sut.restrictApplicationUsage = YES;
  
  [self.sut applicationDidBecomeActive:nil];
  
  [verify(delegateMock) authenticator:self.sut willShowAuthenticationController:(id)anything()];
}

#pragma mark - Validation helper checks
- (void) testThatValidationTriggersOnNewVersion {
  self.sut.restrictApplicationUsage = YES;
  self.sut.restrictionEnforcementFrequency = BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch;
  self.sut.identificationType = BITAuthenticatorIdentificationTypeDevice;
  self.sut.validated = YES;
  self.sut.lastAuthenticatedVersion = @"111xxx";
  assertThatBool(self.sut.needsValidation, isTrue());
}

- (void) testThatValidationDoesNotTriggerOnSameVersion {
  self.sut.restrictApplicationUsage = YES;
  self.sut.restrictionEnforcementFrequency = BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch;
  self.sut.validated = YES;
  self.sut.lastAuthenticatedVersion = self.sut.executableUUID;
  assertThatBool(self.sut.needsValidation, isFalse());
}

@end
