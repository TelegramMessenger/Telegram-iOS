/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_AUTHENTICATOR

#import "HockeySDKPrivate.h"
#import "BITAuthenticator_Private.h"
#import "BITAuthenticationViewController.h"
#import "BITHockeyAppClient.h"
#import "BITHockeyHelper.h"
#import "BITHockeyBaseManagerPrivate.h"

#include <sys/stat.h>

static NSString *const kBITAuthenticatorUUIDKey = @"BITAuthenticatorUUIDKey";
static NSString *const kBITAuthenticatorIdentifierKey = @"BITAuthenticatorIdentifierKey";
static NSString *const kBITAuthenticatorIdentifierTypeKey = @"BITAuthenticatorIdentifierTypeKey";
static NSString *const kBITAuthenticatorLastAuthenticatedVersionKey = @"BITAuthenticatorLastAuthenticatedVersionKey";
static NSString *const kBITAuthenticatorUserEmailKey = @"BITAuthenticatorUserEmailKey";

//deprecated
static NSString *const kBITAuthenticatorAuthTokenKey = @"BITAuthenticatorAuthTokenKey";
static NSString *const kBITAuthenticatorAuthTokenTypeKey = @"BITAuthenticatorAuthTokenTypeKey";

typedef unsigned int bit_uint32;
static unsigned char kBITPNGHeader[8] = {137, 80, 78, 71, 13, 10, 26, 10};
static unsigned char kBITPNGEndChunk[4] = {0x49, 0x45, 0x4e, 0x44};


@interface BITAuthenticator()

@property (nonatomic, assign) BOOL isSetup;

@property (nonatomic, strong) id appDidBecomeActiveObserver;
@property (nonatomic, strong) id appDidEnterBackgroundObserver;
@property (nonatomic, strong) UIViewController *authenticationController;

@end


@implementation BITAuthenticator

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier appEnvironment:(BITEnvironment)environment {
  self = [super initWithAppIdentifier:appIdentifier appEnvironment:environment];
  if (self) {
    _webpageURL = [NSURL URLWithString:@"https://rink.hockeyapp.net/"];
    
    _identificationType = BITAuthenticatorIdentificationTypeAnonymous;
    _isSetup = NO;
    _restrictApplicationUsage = NO;
    _restrictionEnforcementFrequency = BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch;
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
}

#pragma mark - BITHockeyBaseManager overrides

- (void)startManager {
  //disabled in TestFlight and the AppStore
  if (self.appEnvironment != BITEnvironmentOther) { return; }
  
  self.isSetup = YES;
}

#pragma mark -

- (void)authenticateInstallation {
  //disabled in TestFlight and the AppStore
  if (self.appEnvironment != BITEnvironmentOther) { return; }
  
  // make sure this is called after startManager so all modules are fully setup
  if (!self.isSetup) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(authenticateInstallation) object:nil];
    [self performSelector:@selector(authenticateInstallation) withObject:nil afterDelay:0.1];
  } else {
    switch ([[UIApplication sharedApplication] applicationState]) {
      case UIApplicationStateActive:
        [self authenticate];
        break;
      case UIApplicationStateBackground:
      case UIApplicationStateInactive:
        // do nothing, wait for active state
        break;
    }
  }
  [self registerObservers];
}

- (void)authenticate {
  [self identifyWithCompletion:^(BOOL identified, NSError *error) {
    if (identified) {
      if ([self needsValidation]) {
        [self validate];
      } else {
        [self dismissAuthenticationControllerAnimated:YES completion:nil];
      }
    } else {
      BITHockeyLogError(@"Failed to identify. Error: %@", error);
    }
  }];
}

#pragma mark - Identification

- (void)identifyWithCompletion:(void (^)(BOOL identified, NSError *))completion {
  if (self.authenticationController) {
    BITHockeyLogDebug(@"Authentication controller already visible. Ignoring identify request");
    if (completion) { completion(NO, nil); }
    return;
  }
  //first check if the stored identification type matches the one currently configured
  NSString *storedTypeString = [self stringValueFromKeychainForKey:kBITAuthenticatorIdentifierTypeKey];
  NSString *configuredTypeString = [self.class stringForIdentificationType:self.identificationType];
  if (storedTypeString && ![storedTypeString isEqualToString:configuredTypeString]) {
    BITHockeyLogDebug(@"Identification type mismatch for stored auth-token. Resetting.");
    [self storeInstallationIdentifier:nil withType:BITAuthenticatorIdentificationTypeAnonymous];
  }
  
  NSString *identification = [self installationIdentifier];
  
  if (identification) {
    self.identified = YES;
    if (completion) { completion(YES, nil); }
    return;
  }
  
  [self processFullSizeImage];
  if (self.identified) {
    if (completion) { completion(YES, nil); }
    return;
  }
  
  //it's not identified yet, do it now
  BITAuthenticationViewController *viewController = nil;
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeAnonymous:
      [self storeInstallationIdentifier:bit_UUID() withType:BITAuthenticatorIdentificationTypeAnonymous];
      self.identified = YES;
      if (completion) { completion(YES, nil); }
      return;
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
      viewController = [[BITAuthenticationViewController alloc] initWithDelegate:self];
      viewController.requirePassword = YES;
      viewController.tableViewTitle = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerDataEmailAndPasswordDescription");
      break;
    case BITAuthenticatorIdentificationTypeDevice:
      viewController = [[BITAuthenticationViewController alloc] initWithDelegate:self];
      viewController.requirePassword = NO;
      viewController.showsLoginViaWebButton = YES;
      viewController.tableViewTitle = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerWebUDIDLoginDescription");
      break;
    case BITAuthenticatorIdentificationTypeWebAuth:
      viewController = [[BITAuthenticationViewController alloc] initWithDelegate:self];
      viewController.requirePassword = NO;
      viewController.showsLoginViaWebButton = YES;
      viewController.tableViewTitle = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerWebAuthLoginDescription");
      break;
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
      if (nil == self.authenticationSecret) {
        NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                             code:BITAuthenticatorAuthorizationSecretMissing
                                         userInfo:@{NSLocalizedDescriptionKey:@"For email identification, the authentication secret must be set"}];
        if (completion) { completion(NO, error); }
        return;
      }
      viewController = [[BITAuthenticationViewController alloc] initWithDelegate:self];
      viewController.requirePassword = NO;
      viewController.tableViewTitle = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerDataEmailDescription");
      break;
  }
  id strongDelegate = self.delegate;
  if ([strongDelegate respondsToSelector:@selector(authenticator:willShowAuthenticationController:)]) {
    [strongDelegate authenticator:self willShowAuthenticationController:viewController];
  }
  
  NSAssert(viewController, @"ViewController should've been created");
  
  viewController.email = [self stringValueFromKeychainForKey:kBITAuthenticatorUserEmailKey];
  self.authenticationController = viewController;
  self.identificationCompletion = completion;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self showView:viewController];
  });
}

#pragma mark - Validation

- (BOOL)needsValidation {
  if (BITAuthenticatorIdentificationTypeAnonymous == self.identificationType) {
    return NO;
  }
  if (NO == self.restrictApplicationUsage) {
    return NO;
  }
  if (self.restrictionEnforcementFrequency == BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch &&
      ![self.executableUUID isEqualToString:self.lastAuthenticatedVersion]) {
    return YES;
  }
  if (NO == self.isValidated && self.restrictionEnforcementFrequency == BITAuthenticatorAppRestrictionEnforcementOnAppActive) {
    return YES;
  }
  return NO;
}

- (void)validate {
  [self validateWithCompletion:^(BOOL validated, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (validated) {
        [self dismissAuthenticationControllerAnimated:YES completion:nil];
      } else {
        BITHockeyLogError(@"Validation failed with error: %@", error);
        __weak typeof(self) weakSelf = self;

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                                 message:error.localizedDescription
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyOK")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction __unused *action) {
                                                           typeof(self) strongSelf = weakSelf;
                                                           [strongSelf validate];
                                                         }];

        [alertController addAction:okAction];
        [self showAlertController:alertController];
      }
    });
  }];
}

- (void)validateWithCompletion:(void (^)(BOOL validated, NSError *))completion {
  BOOL requirementsFulfilled = YES;
  NSError *error = nil;
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeAnonymous: {
      error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                  code:BITAuthenticatorErrorUnknown
                              userInfo:@{NSLocalizedDescriptionKey:@"Anonymous users can't be validated"}];
      requirementsFulfilled = NO;
      break;
    }
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
      if (nil == self.authenticationSecret) {
        error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                    code:BITAuthenticatorAuthorizationSecretMissing
                                userInfo:@{NSLocalizedDescriptionKey:@"For email validation, the authentication secret must be set"}];
        requirementsFulfilled = NO;
        break;
      }
      //no break
    case BITAuthenticatorIdentificationTypeDevice:
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
    case BITAuthenticatorIdentificationTypeWebAuth:
      if (nil == self.installationIdentifier) {
        error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                    code:BITAuthenticatorNotIdentified
                                userInfo:@{NSLocalizedDescriptionKey:@"Make sure to identify the installation first"}];
        requirementsFulfilled = NO;
      }
      break;
  }
  if (NO == requirementsFulfilled) {
    if (completion) {
      completion(NO, error);
    }
    return;
  }
  
  NSString *validationPath = [NSString stringWithFormat:@"api/3/apps/%@/identity/validate", self.encodedAppIdentifier];
  
  __weak typeof(self) weakSelf = self;
  NSURLRequest *request = [self.hockeyAppClient requestWithMethod:@"GET" path:validationPath parameters:[self validationParameters]];

  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];

  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse __unused *response, NSError *innerError) {
                                            typeof(self) strongSelf = weakSelf;

                                            [session finishTasksAndInvalidate];

                                            [strongSelf handleValidationResponseWithData:data error:innerError completion:completion];
                                          }];
  [task resume];
}

- (void)handleValidationResponseWithData:(NSData *)responseData error:(NSError *)error completion:(void (^)(BOOL validated, NSError *))completion {
  if (nil == responseData) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")};
    if (error) {
      NSMutableDictionary *dict = [userInfo mutableCopy];
      dict[NSUnderlyingErrorKey] = error;
      userInfo = dict;
    }
    NSError *localError = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                         code:BITAuthenticatorNetworkError
                                     userInfo:userInfo];
    self.validated = NO;
    if (completion) { completion(NO, localError); }
  } else {
    NSError *validationParseError = nil;
    BOOL valid = [self.class isValidationResponseValid:responseData error:&validationParseError];
    self.validated = valid;
    if (valid) {
      [self setLastAuthenticatedVersion:self.executableUUID];
    }
    if (completion) { completion(valid, validationParseError); }
  }
}

- (NSDictionary *)validationParameters {
  NSParameterAssert(self.installationIdentifier);
  NSParameterAssert(self.installationIdentifierParameterString);
  
  NSString *installString = bit_appAnonID(NO);
  if (installString) {
    return @{self.installationIdentifierParameterString:self.installationIdentifier, @"install_string":installString};
  }
  
  return @{self.installationIdentifierParameterString:self.installationIdentifier};
}

+ (BOOL)isValidationResponseValid:(id)response error:(NSError *__autoreleasing *)error {
  NSParameterAssert(response);
  
  NSError *jsonParseError = nil;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:response
                                                  options:0
                                                    error:&jsonParseError];
  if (nil == jsonObject) {
    if (error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return NO;
  }
  if (![jsonObject isKindOfClass:[NSDictionary class]]) {
    if (error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return NO;
  }
  
  NSString *status = jsonObject[@"status"];
  if ([status isEqualToString:@"not authorized"]) {
    if (error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorNotAuthorized
                               userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationNotMember")}];
    }
    return NO;
  } else if ([status isEqualToString:@"not found"]) {
    if (error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorUnknownApplicationID
                               userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationContactDeveloper")}];
    }
    return NO;
  } else if ([status isEqualToString:@"validated"]) {
    return YES;
  } else {
    if (error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return NO;
  }
}

#pragma mark - AuthenticationViewController Helper

/**
 * This method has to be called on the main queue
 */
- (void)dismissAuthenticationControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
  if (!self.authenticationController) { return; }
  UIViewController *presentingViewController = [self.authenticationController presentingViewController];
  
  // If there is no presenting view controller just remove view
  if (presentingViewController) {
    [self.authenticationController dismissViewControllerAnimated:animated completion:completion];
  } else {
    [self.authenticationController.navigationController.view removeFromSuperview];
    if (completion) {
      completion();
    }
  }
  self.authenticationController = nil;
}

#pragma mark - AuthenticationViewControllerDelegate

- (void)authenticationViewController:(UIViewController *)viewController
       handleAuthenticationWithEmail:(NSString *)email
                            password:(NSString *)password
                          completion:(void (^)(BOOL, NSError *))completion {
  
  NSParameterAssert(email && email.length);
  NSParameterAssert(self.identificationType == BITAuthenticatorIdentificationTypeHockeyAppEmail || (password && password.length));
  
  // Trim whitespace from email in case the user has added a whitespace at the end of the email address. This shouldn't
  // happen if devs use our UI but we've had 1-2 support tickets where the email contained whitespace at the end and
  // verification failed because of that.
  email = [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  NSURLRequest *request = [self requestForAuthenticationEmail:email password:password];
  
  [self authenticationViewController:viewController handleAuthenticationWithEmail:email request:request completion:completion];
}

- (void)authenticationViewController:(UIViewController *) __unused viewController
       handleAuthenticationWithEmail:(NSString *)email
                             request:(NSURLRequest *)request
                          completion:(void (^)(BOOL, NSError *))completion {
  
  __weak typeof(self) weakSelf = self;
  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];

  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError __unused *error) {
                                            typeof(self) strongSelf = weakSelf;
                                            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

                                            [session finishTasksAndInvalidate];

                                            [strongSelf handleAuthenticationWithResponse:httpResponse email:email data:data completion:completion];
                                          }];
  [task resume];
}

- (void)authenticationViewControllerDidTapWebButton:(UIViewController *) __unused viewController {
  NSURL *url = [self deviceAuthenticationURL];
  if (url) {
    [[UIApplication sharedApplication] openURL:url];
  }
}

#pragma mark - Networking

- (void)handleAuthenticationWithResponse:(NSHTTPURLResponse *)response email:(NSString *)email data:(NSData *)data completion:(void (^)(BOOL, NSError *))completion {
  NSError *authParseError = nil;
  NSString *authToken = [self.class authenticationTokenFromURLResponse:response
                                                                  data:data
                                                                 error:&authParseError];
  BOOL identified;
  if (authToken) {
    identified = YES;
    [self storeInstallationIdentifier:authToken withType:self.identificationType];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self dismissAuthenticationControllerAnimated:YES completion:nil];
    });
    BOOL success = [self addStringValueToKeychain:email forKey:kBITAuthenticatorUserEmailKey];
    if (!success) {
      [self alertOnFailureStoringTokenInKeychain];
    }
  } else {
    identified = NO;
  }
  self.identified = identified;
  if (completion) { completion(identified, authParseError); }
  if (self.identificationCompletion) {
    self.identificationCompletion(identified, authParseError);
    self.identificationCompletion = nil;
  }
}

- (NSURLRequest *)requestForAuthenticationEmail:(NSString *)email password:(NSString *)password {
  NSString *authenticationPath = [self authenticationPath];
  NSMutableDictionary *params = [NSMutableDictionary dictionary];
  
  NSString *installString = bit_appAnonID(NO);
  if (installString) {
    params[@"install_string"] = installString;
  }
  
  if (BITAuthenticatorIdentificationTypeHockeyAppEmail == self.identificationType) {
    NSString *authCode = BITHockeyMD5([NSString stringWithFormat:@"%@%@",
                                       self.authenticationSecret ?: @"",
                                       email ?: @""]);
    
    params[@"email"] = email ?: @"";
    params[@"authcode"] = authCode.lowercaseString;
  }
  
  NSMutableURLRequest *request = [self.hockeyAppClient requestWithMethod:@"POST"
                                                                    path:authenticationPath
                                                              parameters:params];
  if (BITAuthenticatorIdentificationTypeHockeyAppUser == self.identificationType) {
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", email, password];
    NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", bit_base64String(authData, authData.length)];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
  }
  
  return request;
}

- (NSString *)authenticationPath {
  if (BITAuthenticatorIdentificationTypeHockeyAppUser == self.identificationType) {
    return [NSString stringWithFormat:@"api/3/apps/%@/identity/authorize", self.encodedAppIdentifier];
  } else {
    return [NSString stringWithFormat:@"api/3/apps/%@/identity/check", self.encodedAppIdentifier];
  }
}

+ (NSString *)authenticationTokenFromURLResponse:(NSHTTPURLResponse *)urlResponse data:(NSData *)data error:(NSError *__autoreleasing *)error {
  if (nil == urlResponse) {
    if (error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return nil;
  }
  
  switch (urlResponse.statusCode) {
    case 401:
      if (error) {
        *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                     code:BITAuthenticatorNotAuthorized
                                 userInfo:@{
                                            NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationWrongEmailPassword")
                                            }];
      }
      break;
    case 200:
    case 404:
      //Do nothing, handled below
      break;
    default:
      if (error) {
        *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                     code:BITAuthenticatorAPIServerReturnedInvalidResponse
                                 userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
        
      }
      break;
  }
  if (200 != urlResponse.statusCode && 404 != urlResponse.statusCode) {
    //make sure we have an error created if user wanted to have one
    NSParameterAssert(nil == error || *error);
    return nil;
  }
  
  NSError *jsonParseError = nil;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                  options:0
                                                    error:&jsonParseError];
  //no json or unexpected json
  if (nil == jsonObject || ![jsonObject isKindOfClass:[NSDictionary class]]) {
    if (error) {
      NSDictionary *userInfo = @{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")};
      if (jsonParseError) {
        NSMutableDictionary *userInfoMutable = [userInfo mutableCopy];
        userInfoMutable[NSUnderlyingErrorKey] = jsonParseError;
        userInfo = userInfoMutable;
      }
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:userInfo];
    }
    return nil;
  }
  
  NSString *status = jsonObject[@"status"];
  NSString *authToken = nil;
  if ([status isEqualToString:@"identified"]) {
    authToken = jsonObject[@"iuid"];
  } else if ([status isEqualToString:@"authorized"]) {
    authToken = jsonObject[@"auid"];
  } else if ([status isEqualToString:@"not authorized"]) {
    if (error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorNotAuthorized
                               userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationNotMember")}];
      
    }
  }
  //if no error is set yet, but error parameter is given, return a generic error
  if (nil == authToken && error && nil == *error) {
    *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                 code:BITAuthenticatorAPIServerReturnedInvalidResponse
                             userInfo:@{NSLocalizedDescriptionKey:BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
  }
  return authToken;
}

- (NSURL *)deviceAuthenticationURL {
  NSString *whatParameter = nil;
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeWebAuth:
      whatParameter = @"email";
      break;
    case BITAuthenticatorIdentificationTypeDevice:
      whatParameter = @"udid";
      break;
    case BITAuthenticatorIdentificationTypeAnonymous:
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
      return nil;
  }
  NSURL *url = [self.webpageURL URLByAppendingPathComponent:[NSString stringWithFormat:@"apps/%@/authorize", self.encodedAppIdentifier]];
  NSParameterAssert(whatParameter && url.absoluteString);
  url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?what=%@", url.absoluteString, whatParameter]];
  return url;
}

- (BOOL)handleOpenURL:(NSURL *)url
    sourceApplication:(NSString *) __unused sourceApplication
           annotation:(id)annotation {
  //check if this URL was meant for us, if not return NO so the user can
  //handle it
  NSString *const kAuthorizationHost = @"authorize";
  NSString *urlScheme = self.urlScheme ?: [NSString stringWithFormat:@"ha%@", self.appIdentifier];
  if (!([[url scheme] isEqualToString:urlScheme] && [[url host] isEqualToString:kAuthorizationHost])) {
    BITHockeyLogWarning(@"WARNING: URL scheme for authentication doesn't match!");
    return NO;
  }
  
  NSString *installationIdentifier = nil;
  NSString *localizedErrorDescription = nil;
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeWebAuth: {
      NSString *email = nil;
      [self.class email:&email andIUID:&installationIdentifier fromOpenURL:url];
      if (email) {
        BOOL success = [self addStringValueToKeychain:email forKey:kBITAuthenticatorUserEmailKey];
        if (!success) {
          [self alertOnFailureStoringTokenInKeychain];
        }
      } else {
        BITHockeyLogDebug(@"No email found in URL: %@", url);
      }
      localizedErrorDescription = @"Failed to retrieve parameters from URL.";
      break;
    }
    case BITAuthenticatorIdentificationTypeDevice: {
      installationIdentifier = [self.class UDIDFromOpenURL:url annotation:annotation];
      localizedErrorDescription = @"Failed to retrieve UDID from URL.";
      break;
    }
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
    case BITAuthenticatorIdentificationTypeAnonymous:
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
      return NO;
  }
  
  if (installationIdentifier) {
    BITHockeyLogDebug(@"Authentication succeeded.");
    if (NO == self.restrictApplicationUsage) {
      [self dismissAuthenticationControllerAnimated:YES completion:nil];
    }
    [self storeInstallationIdentifier:installationIdentifier withType:self.identificationType];
    self.identified = YES;
    if (self.identificationCompletion) {
      self.identificationCompletion(YES, nil);
      self.identificationCompletion = nil;
    }
  } else {
    //reset token
    BITHockeyLogDebug(@"Resetting authentication token");
    [self storeInstallationIdentifier:nil withType:self.identificationType];
    self.identified = NO;
    if (self.identificationCompletion) {
      NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                           code:BITAuthenticatorErrorUnknown
                                       userInfo:@{NSLocalizedDescriptionKey:localizedErrorDescription}];
      self.identificationCompletion(NO, error);
      self.identificationCompletion = nil;
    }
  }
  return YES;
}

+ (NSString *)UDIDFromOpenURL:(NSURL *)url annotation:(id) __unused annotation {
  NSString *query = [url query];
  NSString *udid = nil;
  //there should actually only one
  static NSString *const UDIDQuerySpecifier = @"udid";
  for (NSString *queryComponents in [query componentsSeparatedByString:@"&"]) {
    NSArray *parameterComponents = [queryComponents componentsSeparatedByString:@"="];
    if (2 == parameterComponents.count && [parameterComponents[0] isEqualToString:UDIDQuerySpecifier]) {
      udid = parameterComponents[1];
      break;
    }
  }
  return udid;
}

+ (void)email:(NSString *__autoreleasing *)email andIUID:(NSString *__autoreleasing *)iuid fromOpenURL:(NSURL *)url {
  NSString *query = [url query];
  //there should actually only one
  static NSString *const EmailQuerySpecifier = @"email";
  static NSString *const IUIDQuerySpecifier = @"iuid";
  for (NSString *queryComponents in [query componentsSeparatedByString:@"&"]) {
    NSArray *parameterComponents = [queryComponents componentsSeparatedByString:@"="];
    if (email && 2 == parameterComponents.count && [parameterComponents[0] isEqualToString:EmailQuerySpecifier]) {
      *email = parameterComponents[1];
    } else if (iuid && 2 == parameterComponents.count && [parameterComponents[0] isEqualToString:IUIDQuerySpecifier]) {
      *iuid = parameterComponents[1];
    }
  }
}

#pragma mark - Private helpers

- (void)alertOnFailureStoringTokenInKeychain {
  if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
    return;
  }
  
  BITHockeyLogError(@"[HockeySDK] ERROR: The authentication token could not be stored due to a keychain error. This is most likely a signing or keychain entitlement issue!");
}

- (void)cleanupInternalStorage {
  [self removeKeyFromKeychain:kBITAuthenticatorIdentifierTypeKey];
  [self removeKeyFromKeychain:kBITAuthenticatorIdentifierKey];
  [self removeKeyFromKeychain:kBITAuthenticatorUUIDKey];
  [self removeKeyFromKeychain:kBITAuthenticatorUserEmailKey];
  [self setLastAuthenticatedVersion:nil];
  self.identified = NO;
  self.validated = NO;
  
  //cleanup values stored from 3.5 Beta1..Beta3
  [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenKey];
  [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenTypeKey];
}

- (void)processFullSizeImage {
#ifdef BIT_INTERNAL_DEBUG
  NSString* path = [[NSBundle mainBundle] pathForResource:@"iTunesArtwork" ofType:@"png"];
#else
  NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/../iTunesArtwork"];
#endif
  
  struct stat fs;
  int fd = open([path UTF8String], O_RDONLY, 0);
  if (fstat(fd, &fs) < 0) {
    // File not found
    close(fd);
    return;
  }
  
  BITHockeyLogDebug(@"Processing full size image for possible authentication");
  
  unsigned char *buffer, *source;
  source = (unsigned char *)malloc((unsigned long)fs.st_size);
  if (read(fd, source, (unsigned long)fs.st_size) != fs.st_size) {
    close(fd);
    // Couldn't read file
    free(source);
    return;
  }
  
  if ((fs.st_size < 20) || (memcmp(source, kBITPNGHeader, 8))) {
    // Not a PNG
    free(source);
    return;
  }
  
  buffer = source + 8;
  
  NSString *result = nil;
  bit_uint32 length;
  unsigned char *name;
  unsigned char *data;
  int chunk_index = 0;
  long long bytes_left = fs.st_size - 8;
  do {
    memcpy(&length, buffer, 4);
    length = ntohl(length);
    
    buffer += 4;
    name = (unsigned char *)malloc(5);
    name[4] = 0;
    memcpy(name, buffer, 4);
    
    buffer += 4;
    data = (unsigned char *)malloc(length + 1);
    
    if (bytes_left >= length) {
      memcpy(data, buffer, length);
      
      buffer += length;
      buffer += 4;
      if (!strcmp((const char *)name, "tEXt")) {
        data[length] = 0;
        NSString *key = [NSString stringWithCString:(char *)data encoding:NSUTF8StringEncoding];
        
        if ([key isEqualToString:@"Data"]) {
          result = [NSString stringWithCString:(char *)(data + key.length + 1) encoding:NSUTF8StringEncoding];
        }
      }
      
      if (!memcmp(name, kBITPNGEndChunk, 4)) {
        chunk_index = 128;
      }
    }
    
    free(data);
    free(name);
    
    bytes_left -= (length + 3 * 4);
  } while ((chunk_index++ < 128) && (bytes_left > 8));
  
  free(source);
  
  if (result) {
    BITHockeyLogDebug(@"Authenticating using full size image information: %@", result);
    [self handleOpenURL:[NSURL URLWithString:result] sourceApplication:nil annotation:nil];
  } else {
    BITHockeyLogDebug(@"No authentication information found");
  }
}

#pragma mark - NSNotification

- (void)registerObservers {
  __weak typeof(self) weakSelf = self;
  if (nil == self.appDidBecomeActiveObserver) {
    self.appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                        object:nil
                                                                                         queue:NSOperationQueue.mainQueue
                                                                                    usingBlock:^(NSNotification *note) {
                                                                                      typeof(self) strongSelf = weakSelf;
                                                                                      [strongSelf applicationDidBecomeActive:note];
                                                                                    }];
  }
  if (nil == self.appDidEnterBackgroundObserver) {
    self.appDidEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                                                           object:nil
                                                                                            queue:NSOperationQueue.mainQueue
                                                                                       usingBlock:^(NSNotification *note) {
                                                                                         typeof(self) strongSelf = weakSelf;
                                                                                         [strongSelf applicationDidEnterBackground:note];
                                                                                       }];
  }
}

- (void)unregisterObservers {
  if (self.appDidBecomeActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:self.appDidBecomeActiveObserver];
    self.appDidBecomeActiveObserver = nil;
  }
  if (self.appDidEnterBackgroundObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:self.appDidEnterBackgroundObserver];
    self.appDidEnterBackgroundObserver = nil;
  }
}

#pragma mark - Property overrides

- (void)storeInstallationIdentifier:(NSString *)installationIdentifier withType:(BITAuthenticatorIdentificationType)type {
  if (nil == installationIdentifier) {
    [self removeKeyFromKeychain:kBITAuthenticatorIdentifierKey];
    [self removeKeyFromKeychain:kBITAuthenticatorIdentifierTypeKey];
  } else {
    BOOL success1 = [self addStringValueToKeychainForThisDeviceOnly:installationIdentifier
                                                             forKey:kBITAuthenticatorIdentifierKey];
    BOOL success2 = [self addStringValueToKeychainForThisDeviceOnly:[self.class stringForIdentificationType:type]
                                                             forKey:kBITAuthenticatorIdentifierTypeKey];
    if (!success1 || !success2) {
      [self alertOnFailureStoringTokenInKeychain];
    }
  }
}

- (NSString *)installationIdentifier {
  NSString *identifier = [self stringValueFromKeychainForKey:kBITAuthenticatorIdentifierKey];
  return identifier;
}

- (void)setLastAuthenticatedVersion:(NSString *)lastAuthenticatedVersion {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (nil == lastAuthenticatedVersion) {
    [defaults removeObjectForKey:kBITAuthenticatorLastAuthenticatedVersionKey];
  } else {
    [defaults setObject:lastAuthenticatedVersion
                 forKey:kBITAuthenticatorLastAuthenticatedVersionKey];
    if(bit_isPreiOS8Environment()) {
      [defaults synchronize];
    }
  }
}

- (NSString *)lastAuthenticatedVersion {
  return [[NSUserDefaults standardUserDefaults] objectForKey:kBITAuthenticatorLastAuthenticatedVersionKey];
}

- (NSString *)installationIdentifierParameterString {
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
    case BITAuthenticatorIdentificationTypeWebAuth:
      return @"iuid";
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
      return @"auid";
    case BITAuthenticatorIdentificationTypeDevice:
      return @"udid";
    case BITAuthenticatorIdentificationTypeAnonymous:
      return @"uuid";
  }
}

+ (NSString *)stringForIdentificationType:(BITAuthenticatorIdentificationType)identificationType {
  switch (identificationType) {
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
      return @"iuid";
    case BITAuthenticatorIdentificationTypeWebAuth:
      return @"webAuth";
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
      return @"auid";
    case BITAuthenticatorIdentificationTypeDevice:
      return @"udid";
    case BITAuthenticatorIdentificationTypeAnonymous:
      return @"uuid";
  }
}

- (void)setIdentificationType:(BITAuthenticatorIdentificationType)identificationType {
  if (_identificationType != identificationType) {
    _identificationType = identificationType;
    self.identified = NO;
    self.validated = NO;
  }
}

- (NSString *)publicInstallationIdentifier {
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
    case BITAuthenticatorIdentificationTypeWebAuth:
      return [self stringValueFromKeychainForKey:kBITAuthenticatorUserEmailKey];
    case BITAuthenticatorIdentificationTypeAnonymous:
    case BITAuthenticatorIdentificationTypeDevice:
      return [self stringValueFromKeychainForKey:kBITAuthenticatorIdentifierKey];
  }
}

#pragma mark - Application Lifecycle

- (void)applicationDidBecomeActive:(NSNotification *) __unused note {
  [self authenticate];
}

- (void)applicationDidEnterBackground:(NSNotification *) __unused note {
  if (BITAuthenticatorAppRestrictionEnforcementOnAppActive == self.restrictionEnforcementFrequency) {
    self.validated = NO;
  }
}

@end

#endif  /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
