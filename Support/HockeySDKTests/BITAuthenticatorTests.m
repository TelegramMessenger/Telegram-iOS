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

@interface MyDeviceWithIdentifierForVendor : MyDevice
@property (copy) NSUUID *identifierForVendor;
@end
@implementation MyDeviceWithIdentifierForVendor

- (id)init {
  self = [super init];
  if( self ) {
    _identifierForVendor = [NSUUID UUID];
  }
  return self;
}

@end

static void *kInstallationIdentification = &kInstallationIdentification;

@interface BITAuthenticatorTests : SenTestCase
@end

@implementation BITAuthenticatorTests {
  BITAuthenticator *_sut;
  BOOL _KVOCalled;
}

- (void)setUp {
  [super setUp];
  
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:NO];
  _sut.authenticationType = BITAuthenticatorAuthTypeEmailAndPassword;
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
  [_sut setAuthenticationToken:@"SuperToken" withType:@"udid"];
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
  assertThat(_sut.authenticationToken, equalTo(@"SuperToken"));
}

- (void) testThatLastAuthenticatedVersionIsPersisted {
  _sut.lastAuthenticatedVersion = @"1.2.1";
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
  assertThat(_sut.lastAuthenticatedVersion, equalTo(@"1.2.1"));
}

- (void) testThatCleanupWorks {
  [_sut setAuthenticationToken:@"MyToken" withType:@"udid"];
  _sut.lastAuthenticatedVersion = @"1.2";
  [_sut setDidSkipOptionalLogin:YES];
  
  [_sut cleanupInternalStorage];
  
  assertThat(_sut.authenticationToken, equalTo(nil));
  assertThat(_sut.lastAuthenticatedVersion, equalTo(nil));
  assertThat(_sut.installationIdentificationType, equalTo(@"udid"));
  assertThatBool(_sut.didSkipOptionalLogin, equalToBool(NO));
}

- (void) testThatSkipLoginIsPersisted {
  [_sut setDidSkipOptionalLogin:YES];
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
  assertThatBool(_sut.didSkipOptionalLogin, equalToBool(YES));
  [_sut setDidSkipOptionalLogin:NO];
  _sut = [[BITAuthenticator alloc] initWithAppIdentifier:nil isAppStoreEnvironemt:YES];
  assertThatBool(_sut.didSkipOptionalLogin, equalToBool(NO));
}

#pragma mark - Identification Tests
- (void) testIdentificationReturnsTheVendorIdentifierIfAvailable {
  STAssertEqualObjects([_sut installationIdentification], [[UIDevice currentDevice] identifierForVendor].UUIDString,
                       @"Freshly initialized, it should return the vendor identifier");
}

- (void) testIdentificationReturnsTheAuthTokenIfSet {
  [_sut setAuthenticationType:BITAuthenticatorAuthTypeUDIDProvider];
  [_sut setAuthenticationToken:@"PeterPan" withType:@"udid"];
  assertThat(_sut.installationIdentification, equalTo(@"PeterPan"));
}

#pragma mark - authentication tests
- (void) testThatAuthenticateWithTypeEmailShowsAViewController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.authenticationSecret = @"myscret";
  _sut.authenticationType = BITAuthenticatorAuthTypeEmail;
  
  [_sut authenticateWithCompletion:nil];
  
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatAuthenticateWithTypeEmailShowsAViewControllerOnlyIfAuthenticationSecretIsSet {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.authenticationSecret = nil;
  _sut.authenticationType = BITAuthenticatorAuthTypeEmail;
  
  [_sut authenticateWithCompletion:nil];
  
  [verifyCount(delegateMock, times(0)) authenticator:_sut willShowAuthenticationController:(id)anything()];
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
  [_sut didAuthenticateWithToken:@"SuperToken"];
  
  assertThat(_sut.authenticationToken, equalTo(@"SuperToken"));
}

- (void) testThatSuccessfulAuthenticationCallsTheBlock {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  [_sut setAuthenticationToken:@"Test" withType:@"adid"];
  __block BOOL didAuthenticate = NO;
  [_sut authenticateWithCompletion:^(NSString *authenticationToken, NSError *error) {
    if(authenticationToken) didAuthenticate = YES;
  }];
  [_sut didAuthenticateWithToken:@"SuperToken"];
  
  assertThatBool(didAuthenticate, equalToBool(YES));
}

- (void) testThatCancelledAuthenticationSetsProperError {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  
  //this will prepare everything and show the viewcontroller
  __block BOOL didAuthenticateCalled = NO;
  __block NSError *authenticationError = nil;
  [_sut authenticateWithCompletion:^(NSString *authenticationToken, NSError *error) {
    didAuthenticateCalled = YES;
    authenticationError = error;
  }];

  //fake delegate call from the viewcontroller
  [_sut authenticationViewControllerDidSkip:nil];

  assertThatBool(didAuthenticateCalled, equalToBool(YES));
  assertThat(authenticationError, equalTo([NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                                              code:BITAuthenticatorAuthenticationCancelled
                                                          userInfo:nil]));
}

- (void) testThatCancelledAuthenticationResetsTheToken {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  [_sut setAuthenticationToken:@"Meh" withType:@"bdid"];
  
  //this will prepare everything and show the viewcontroller
  [_sut authenticateWithCompletion:nil];
  //fake delegate call from the viewcontroller
  [_sut authenticationViewControllerDidSkip:nil];
  
  assertThat(_sut.authenticationToken, equalTo(nil));
}

- (void) testThatKVOWorksOnApplicationIdentification {
  //this will prepare everything and show the viewcontroller
  [_sut authenticateWithCompletion:nil];

  [_sut addObserver:self forKeyPath:@"installationIdentification"
            options:0
            context:kInstallationIdentification];
  
  //fake delegate call from the viewcontroller
  [_sut authenticationViewControllerDidSkip:nil];
  assertThatBool(_KVOCalled, equalToBool(YES));
  [_sut removeObserver:self forKeyPath:@"installationIdentification"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if(kInstallationIdentification == context) {
    _KVOCalled = YES;
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - InstallationIdentificationType
- (void) testThatEmailAuthSetsTheProperInstallationIdentificationType {
  _sut.authenticationType = BITAuthenticatorAuthTypeEmail;
  //fake delegate call from the viewcontroller
  [_sut didAuthenticateWithToken:@"SuperToken"];
  
  assertThat(_sut.installationIdentificationType, equalTo(@"iuid"));
}

- (void) testThatPasswordAuthSetsTheProperInstallationIdentificationType {
  _sut.authenticationType = BITAuthenticatorAuthTypeEmailAndPassword;
  //fake delegate call from the viewcontroller
  [_sut didAuthenticateWithToken:@"SuperToken"];
  
  assertThat(_sut.installationIdentificationType, equalTo(@"auid"));
}

- (void) testThatUDIDAuthSetsTheProperInstallationIdentificationType {
  _sut.authenticationType = BITAuthenticatorAuthTypeUDIDProvider;
  //fake delegate call from the viewcontroller
  [_sut didAuthenticateWithToken:@"SuperToken"];
  
  assertThat(_sut.installationIdentificationType, equalTo(@"udid"));
}

- (void) testThatDefaultAuthReturnsProperInstallationIdentificationType {
  _sut.authenticationType = BITAuthenticatorAuthTypeEmailAndPassword;
  //fake delegate call from the viewcontroller
  [_sut authenticationViewControllerDidSkip:nil];
  
  assertThat(_sut.installationIdentificationType, equalTo(@"udid"));
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

- (void) testThatFailedValidationCallsTheCompletionBlock {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  
  __block BOOL validated = YES;
  __block NSError *error = nil;
  tValidationCompletion completion = ^(BOOL validated_, NSError *error_) {
    validated = validated_;
    error = error_;
  };
  [_sut validateInstallationWithCompletion:completion];
  [_sut validationFailedWithError:[NSError errorWithDomain:kBITAuthenticatorErrorDomain code:0 userInfo:nil]
                       completion:completion];
  
  assertThatBool(validated, equalToBool(NO));
  assertThat(error, notNilValue());
}

- (void) testThatFailedRequiredValidationShowsAuthenticationViewController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnAppActive;
  
  [_sut validationFailedWithError:[NSError errorWithDomain:kBITAuthenticatorErrorDomain code:0 userInfo:nil]
                       completion:_sut.defaultValidationCompletionBlock];
  [verifyCount(delegateMock, times(1)) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatFailedOptionalValidationDoesNotShowAuthenticationViewController {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOptional;
  
  [_sut validationFailedWithError:nil
                       completion:_sut.defaultValidationCompletionBlock];
  [verifyCount(delegateMock, never()) authenticator:_sut willShowAuthenticationController:(id)anything()];
}

- (void) testThatSuccessValidationCallsTheCompletionBlock {
  id delegateMock = mockProtocol(@protocol(BITAuthenticatorDelegate));
  _sut.delegate = delegateMock;
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  
  __block BOOL validated = NO;
  __block NSError *error = nil;
  tValidationCompletion completion = ^(BOOL validated_, NSError *error_) {
    validated = validated_;
    error = error_;
  };
  [_sut validateInstallationWithCompletion:completion];
  [_sut validationSucceededWithCompletion:completion];

  assertThatBool(validated, equalToBool(YES));
  assertThat(error, nilValue());
}

- (void) testThatAuthTokenIsResettingWhenVendorIdentifierChanged {
  MyDeviceWithIdentifierForVendor *device = [MyDeviceWithIdentifierForVendor new];
  _sut.currentDevice = (id)device;
  [_sut didAuthenticateWithToken:@"SuperToken"];
  NSString *ident = [_sut installationIdentification];
  assertThat(ident, equalTo(@"SuperToken"));
  device.identifierForVendor = [NSUUID UUID];
  ident = [_sut installationIdentification];
  assertThat(ident, isNot(equalTo(@"SuperToken")));
}

#pragma mark - Test installationIdentificationValidated Flag
- (void) testThatFlagIsResetOnFailedValidation {
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  assertThatBool(_sut.installationIdentificationValidated, equalToBool(NO));
}

- (void) testThatFlagIsSetOnFailedValidation {
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  [_sut validationSucceededWithCompletion:nil];
  assertThatBool(_sut.installationIdentificationValidated, equalToBool(YES));
}

- (void) testThatApplicationBackgroundingResetsValidatedFlagInValidationTypeOnAppActive {
  _sut.validationType = BITAuthenticatorValidationTypeOnAppActive;
  //trigger flag set to YES
  [_sut validationSucceededWithCompletion:nil];
  [_sut applicationWillResignActive:nil];
  assertThatBool(_sut.installationIdentificationValidated, equalToBool(NO));
}

- (void) testThatApplicationBackgroundingKeepValidatedFlag {
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  //trigger flag set to YES
  [_sut validationSucceededWithCompletion:nil];
  [_sut applicationWillResignActive:nil];
  assertThatBool(_sut.installationIdentificationValidated, equalToBool(YES));
}

- (void) testThatInitialAuthSetsValidatedFlag {
  _sut.validationType = BITAuthenticatorValidationTypeOnFirstLaunch;
  [_sut didAuthenticateWithToken:@"MyToken"];
  assertThatBool(_sut.installationIdentificationValidated, equalToBool(YES));
}

@end
