//
//  HockeySDKTests.m
//  HockeySDKTests
//
//  Created by Andreas Linde on 13.03.13.
//
//

#import <SenTestingKit/SenTestingKit.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITAuthenticator.h"
#import "BITAuthenticator_Private.h"
#import "BITHTTPOperation.h"
#import "BITTestHelper.h"

@interface MyDevice : NSObject
- (NSString*) uniqueIdentifier;
@end
@implementation MyDevice
- (NSString*) uniqueIdentifier {return @"reallyUnique";}
@end

@interface BITAuthenticatorTests : SenTestCase
@end

@implementation BITAuthenticatorTests {
  BITAuthenticator *_sut;
}

- (void)setUp {
  [super setUp];
  
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
}

- (void)tearDown {
  [_sut cleanupInternalStorage];
  _sut = nil;
  
  [super tearDown];
}

#pragma mark - Setup helpers
- (NSDictionary *)jsonFromFixture:(NSString *)fixture {
  NSString *dataString = [BITTestHelper jsonFixture:fixture];
  
  NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
  
  return json;
}

#pragma mark - Setup Tests
- (void) testThatItInstantiates {
  STAssertNotNil(_sut, @"Should be there");
}

#pragma mark - Persistence Tests
- (void) testThatAuthenticationTokenIsPersisted {
  _sut.authenticationToken = @"SuperToken";
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
  assertThat(_sut.authenticationToken, equalTo(@"SuperToken"));
}

- (void) testThatLastAuthenticatedVersionIsPersisted {
  _sut.lastAuthenticatedVersion = @"1.2.1";
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
  assertThat(_sut.lastAuthenticatedVersion, equalTo(@"1.2.1"));
}

- (void) testThatCleanupWorks {
  _sut.authenticationToken = @"MyToken";
  _sut.lastAuthenticatedVersion = @"1.2";
  
  [_sut cleanupInternalStorage];
  
  assertThat(_sut.authenticationToken, equalTo(nil));
  assertThat(_sut.lastAuthenticatedVersion, equalTo(nil));
}

#pragma mark - Identification Tests
- (void) testIdentificationReturnsTheVendorIdentifierIfAvailable {
  STAssertEqualObjects([_sut installationIdentification], [[UIDevice currentDevice] identifierForVendor].UUIDString,
                       @"Freshly initialized, it should return the vendor identifier");
}

- (void) testIdentificationReturnsTheUniqueIdentifier {
  //use a device that responds to the old -(NSString*)uniqueIdentifier, but not to -(NSUUID*)identifierForVendor
  MyDevice *device = [MyDevice new];
  _sut.currentDevice = (UIDevice*)device;
  
  NSString *hockeyUUID = [_sut installationIdentification];
  STAssertEqualObjects(hockeyUUID, @"reallyUnique",
                       @"If there is no vendorIdentifier, it should use the old uniqueIdentifier");
}

- (void) testIdentificationReturnsTheAuthTokenIfSet {
  _sut.authenticationToken = @"PeterPan";
  assertThat(_sut.installationIdentification, equalTo(@"PeterPan"));
}

#pragma mark - authentication tests
- (void) testThatAuthenticateWithTypeEmailShowsAViewController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.authenticationType = BITAuthenticatorAuthTypeEmail;
  
  [_sut authenticateWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatAuthenticateWithTypeEmailAndPasswordShowsAViewController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.authenticationType = BITAuthenticatorAuthTypeEmailAndPassword;
  
  [_sut authenticateWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatIsDoesntShowMoreThanOneAuthenticationController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.authenticationType = BITAuthenticatorAuthTypeEmailAndPassword;
  
  [_sut authenticateWithCompletion:nil];
  [_sut authenticateWithCompletion:nil];
  [_sut authenticateWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatSuccessfulAuthenticationStoresTheToken {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;

  //this will prepare everything and show the viewcontroller
  [_sut authenticateWithCompletion:nil];
  //fake delegate call from the viewcontroller
  [_sut authenticationViewController:nil authenticatedWithToken:@"SuperToken"];
  
  assertThat(_sut.authenticationToken, equalTo(@"SuperToken"));
}

- (void) testThatSuccessfulAuthenticationCallsTheDelegate {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.authenticationToken = @"Test";
  
  [_sut authenticateWithCompletion:nil];
  [_sut authenticationViewController:nil authenticatedWithToken:@"SuperToken"];
  
  [verify(delegateMock) authenticatorDidAuthenticate:_sut];
}

- (void) testThatCancelledAuthenticationCallsTheErrorDelegate {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  
  //this will prepare everything and show the viewcontroller
  [_sut authenticateWithCompletion:nil];
  //fake delegate call from the viewcontroller
  [_sut authenticationViewControllerDidCancel:nil];
  
  [verify(delegateMock) authenticator:_sut failedToAuthenticateWithError:[NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                                                                             code:BITAuthenticatorAuthenticationCancelled
                                                                                         userInfo:nil]];
}

- (void) testThatCancelledAuthenticationResetsTheToken {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.authenticationToken = @"Meh";
  
  //this will prepare everything and show the viewcontroller
  [_sut authenticateWithCompletion:nil];
  //fake delegate call from the viewcontroller
  [_sut authenticationViewControllerDidCancel:nil];
  
  assertThat(_sut.authenticationToken, equalTo(nil));
}

#pragma mark - validation tests
- (void) testThatValidationWithoutTokenWantsToShowTheAuthenticationViewController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOptional;
  
  [_sut validateInstallationWithCompletion:nil];
  
  [verify(delegateMock) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

#pragma mark - Lifetime checks
- (void) testThatValidationDoesntTriggerIfDisabled {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeNever;
  
  [_sut startManager];
  
  [verifyCount(delegateMock, never()) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatValidationTriggersOnStart {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  
  [_sut startManager];
  
  [verify(delegateMock) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatValidationTriggersOnDidBecomeActive {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnAppActive;
  
  [_sut applicationDidBecomeActive:nil];
  
  [verify(delegateMock) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatValidationTriggersOnNewVersion {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  _sut.lastAuthenticatedVersion = @"111xxx";
  
  [_sut startManager];
  
  [verify(delegateMock) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatValidationDoesNotTriggerOnSameVersion {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  _sut.lastAuthenticatedVersion = _sut.executableUUID;
  
  [_sut startManager];
  
  [verifyCount(delegateMock, never()) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatFailedValidationCallsTheDelegate {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  
  [_sut validateInstallationWithCompletion:nil];
  [_sut validationFailedWithError:nil completion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut failedToValidateInstallationWithError:(id)anything()];
  [verifyCount(delegateMock, never()) authenticatorDidValidateInstallation:_sut];
}

- (void) testThatSuccessValidationCallsTheDelegate {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  
  [_sut validateInstallationWithCompletion:nil];
  [_sut validationSucceededWithCompletion:nil];

  [verifyCount(delegateMock, never()) authenticator:_sut failedToValidateInstallationWithError:(id)anything()];
  [verifyCount(delegateMock, times(1)) authenticatorDidValidateInstallation:_sut];
}

@end
