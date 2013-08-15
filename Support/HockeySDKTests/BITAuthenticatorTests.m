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
  [_sut cancelOperationsWithPath:nil method:nil];
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

#pragma mark - Networking base tests
- (void) testThatURLRequestHasBaseURLSet {
  _sut.serverURL = @"http://myserver.com";
  NSMutableURLRequest *request = [_sut requestWithMethod:@"GET" path:nil parameters:nil];
  assertThat(request.URL, equalTo([NSURL URLWithString:@"http://myserver.com/"]));
}

- (void) testThatURLRequestHasPathAppended {
  _sut.serverURL = @"http://myserver.com";
  NSMutableURLRequest *request = [_sut requestWithMethod:@"GET" path:@"projects" parameters:nil];
  assertThat(request.URL, equalTo([NSURL URLWithString:@"http://myserver.com/projects"]));
}

- (void) testThatURLRequestHasMethodSet {
  NSMutableURLRequest *request = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  
  assertThat(request.HTTPMethod, equalTo(@"POST"));
}

- (void) testThatOperationHasURLRequestSet {
  _sut.serverURL = @"http://myserver.com";
  NSURLRequest *r = [_sut requestWithMethod:@"PUT" path:@"x" parameters:nil];
  BITHTTPOperation *op = [_sut operationWithURLRequest:r
                                            completion:nil];
  assertThat(op.URLRequest, equalTo(r));
}

- (void) testThatURLRequestHasParametersInGetAppended {
  NSDictionary *parameters = @{
                               @"email" : @"peter@pan.de",
                               @"push" : @"pop",
                               };
  NSMutableURLRequest *request = [_sut requestWithMethod:@"GET"
                                                    path:@"something"
                                              parameters:parameters];
  NSURL *url = request.URL;
  NSString *params = [url query];
  NSArray *paramPairs = [params componentsSeparatedByString:@"&"];
  assertThat(paramPairs, hasCountOf(2));
  
  NSMutableDictionary *dict = [NSMutableDictionary new];
  for(NSString *paramPair in paramPairs) {
    NSArray *a = [paramPair componentsSeparatedByString:@"="];
    assertThat(a, hasCountOf(2));
    dict[a[0]] = a[1];
  }
  assertThat(dict, equalTo(parameters));
}

- (void) testThatURLRequestHasParametersInPostInTheBody {
  //pending
}

#pragma mark - Convenience methods
- (void) testThatGetPathCreatesAndEnquesAnOperation {
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(0));
  [given([_sut operationWithURLRequest:(id)anything()
                            completion:nil]) willReturn:[NSOperation new]];

  [_sut getPath:@"endpoint"
     parameters:nil
     completion:nil];
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(1));
}

- (void) testThatPostPathCreatesAndEnquesAnOperation {
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(0));
  [given([_sut operationWithURLRequest:nil
                            completion:nil]) willReturn:[NSOperation new]];
  
  [_sut postPath:@"endpoint"
     parameters:nil
     completion:nil];
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(1));
}

#pragma mark - Completion Tests
- (void) testThatCompletionIsCalled {
  //TODO
}

#pragma mark - HTTPOperation enqueuing / cancellation
- (void) testThatOperationIsQueued {
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(0));
  [_sut.operationQueue setSuspended:YES];
  BITHTTPOperation *op = [BITHTTPOperation new];
  [_sut enqeueHTTPOperation:op];
  
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithNilMethod {
  [_sut.operationQueue setSuspended:YES];
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:nil parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:nil parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:nil method:nil];
  assertThatUnsignedInt(numCancelled, equalToUnsignedInt(3));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithNilPath {
  [_sut.operationQueue setSuspended:YES];
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:nil method:nil];
  assertThatUnsignedInt(numCancelled, equalToUnsignedInt(3));
}


- (void) testThatOperationCancellingMatchesAllOperationsWithSetPath {
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut.operationQueue setSuspended:YES];
  
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:@"Another/acas" method:nil];
  assertThatUnsignedInt(numCancelled, equalToUnsignedInt(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithSetMethod {
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:nil method:@"POST"];
  assertThatUnsignedInt(numCancelled, equalToUnsignedInt(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithSetMethodAndPath {
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedInt(_sut.operationQueue.operationCount, equalToUnsignedInt(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:@"Another/acas" method:@"PUT"];
  assertThatUnsignedInt(numCancelled, equalToUnsignedInt(1));
}

#pragma mark - Operation Testing

@end
