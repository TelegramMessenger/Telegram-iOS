/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013 HockeyApp, Bit Stadium GmbH.
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


#import "BITAuthenticator.h"
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITAuthenticator_Private.h"
#import "BITHTTPOperation.h"
#import "BITHockeyAppClient.h"
#import "BITHockeyHelper.h"

static NSString* const kBITAuthenticatorAuthTokenKey = @"BITAuthenticatorAuthTokenKey";
static NSString* const kBITAuthenticatorAuthTokenTypeKey = @"BITAuthenticatorAuthTokenTypeKey";
static NSString* const kBITAuthenticatorLastAuthenticatedVersionKey = @"BITAuthenticatorLastAuthenticatedVersionKey";
static NSString* const kBITAuthenticatorDidSkipOptionalLogin = @"BITAuthenticatorDidSkipOptionalLogin";

@implementation BITAuthenticator {
  id _appDidBecomeActiveObserver;
  id _appWillResignActiveObserver;
  UIViewController *_authenticationController;
}

- (void)dealloc {
  [self unregisterObservers];
}

- (instancetype) initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironment:(BOOL)isAppStoreEnvironment {
  self = [super initWithAppIdentifier:appIdentifier isAppStoreEnvironment:isAppStoreEnvironment];
  if( self ) {
    _webpageURL = [NSURL URLWithString:@"https://rink.hockeyapp.net/"];
    
    _authenticationType = BITAuthenticatorAuthTypeUDIDProvider;
    _validationType = BITAuthenticatorValidationTypeNever;
  }
  return self;
}

#pragma mark - BITHockeyBaseManager overrides
- (void)startManager {
  //disabled in the appStore
  if([self isAppStoreEnvironment]) return;
  
  switch ([[UIApplication sharedApplication] applicationState]) {
    case UIApplicationStateActive:
      [self triggerAuthentication];
      break;
    case UIApplicationStateBackground:
    case UIApplicationStateInactive:
      // do nothing, wait for active state
      break;
  }

  [self registerObservers];
}

#pragma mark -
- (void) triggerAuthentication {
  switch (self.validationType) {
    case BITAuthenticatorValidationTypeOnAppActive:
      [self validateInstallationWithCompletion:[self defaultValidationCompletionBlock]];
      break;
    case BITAuthenticatorValidationTypeOnFirstLaunch:
      if(![self.lastAuthenticatedVersion isEqualToString:self.executableUUID]) {
        self.installationIdentificationValidated = NO;
        [self validateInstallationWithCompletion:[self defaultValidationCompletionBlock]];
      } else {
        self.installationIdentificationValidated = YES;
      }
      break;
    case BITAuthenticatorValidationTypeOptional:
      if(NO == self.didSkipOptionalLogin) {
        [self validateInstallationWithCompletion:[self defaultValidationCompletionBlock]];
      } else {
        self.installationIdentificationValidated = YES;
      }
      break;
    case BITAuthenticatorValidationTypeNever:
      self.installationIdentificationValidated = YES;
      break;
  }
}

#pragma mark -
- (NSString *)installationIdentification {
  NSString *authToken = self.authenticationToken;
  if(authToken) {
    return authToken;
  }
  return bit_appAnonID();
}

- (NSString*) installationIdentificationType {
  NSString *authToken = self.authenticationToken;
  if(nil == authToken) {
    return @"udid";
  } else {
    return [self authenticationTokenType];
  }
}

#pragma mark - Validation
- (void) validateInstallationWithCompletion:(tValidationCompletion) completion {
  if(nil == self.authenticationToken) {
    [self authenticateWithCompletion:^(NSString *authenticationToken, NSError *error) {
      if(nil == authenticationToken) {
        //if authentication fails, there's nothing to validate
        NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                             code:BITAuthenticatorNotAuthorized
                                         userInfo:nil];
        if(completion) completion(NO, error);
      } else {
        if(completion) completion(YES, nil);
      }
    }];
  } else {
    NSString *validationPath = [NSString stringWithFormat:@"api/3/apps/%@/identity/validate", self.encodedAppIdentifier];
    __weak typeof (self) weakSelf = self;
    [self.hockeyAppClient getPath:validationPath
       parameters:[self validationParameters]
       completion:^(BITHTTPOperation *operation, NSData* responseData, NSError *error) {
         typeof (self) strongSelf = weakSelf;
         if(nil == responseData) {
           NSDictionary *userInfo = nil;
           if(error) {
             userInfo = @{NSUnderlyingErrorKey : error};
           }
           NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                                code:BITAuthenticatorNetworkError
                                            userInfo:userInfo];
           [strongSelf validationFailedWithError:error completion:completion];
         } else {
           NSError *validationParseError = nil;
           BOOL isValidated = [strongSelf.class isValidationResponseValid:responseData error:&validationParseError];
           if(isValidated) {
             [strongSelf validationSucceededWithCompletion:completion];
           } else {
             [strongSelf validationFailedWithError:validationParseError completion:completion];
           }
         }
       }];
  }
}

- (NSDictionary*) validationParameters {
  NSParameterAssert(self.authenticationToken);
  NSParameterAssert(self.installationIdentificationType);
  return @{self.installationIdentificationType : self.authenticationToken};
}

+ (BOOL) isValidationResponseValid:(id) response error:(NSError **) error {
  NSParameterAssert(response);

  NSError *jsonParseError = nil;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:response
                                                  options:0
                                                    error:&jsonParseError];
  if(nil == jsonObject) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return NO;
  }
  if(![jsonObject isKindOfClass:[NSDictionary class]]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return NO;
  }
  
  NSString *status = jsonObject[@"status"];
  if([status isEqualToString:@"not authorized"]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorNotAuthorized
                               userInfo:@{NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationNotMember")}];
    }
    return NO;
  } else if([status isEqualToString:@"not found"]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorUnknownApplicationID
                               userInfo:@{NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationContactDeveloper")}];
    }
    return NO;
  } else if([status isEqualToString:@"validated"]) {
    return YES;
  } else {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return NO;
  }
}

#pragma mark - Authentication

- (void)authenticateWithCompletion:(tAuthenticationCompletion)completion {
  if(_authenticationController) {
    BITHockeyLog(@"Already authenticating. Ignoring request");
    return;
  }
  if(_authenticationType == BITAuthenticatorAuthTypeEmail && (nil == _authenticationSecret || !_authenticationSecret.length)) {
    if(completion) {
      NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                           code:BITAuthenticatorAuthorizationSecretMissing
                                       userInfo:@{NSLocalizedDescriptionKey: @"HockeyAuthenticationAuthSecretMissing"}];
      completion(nil, error);
    }
    return;
  }

  BITAuthenticationViewController *viewController = [[BITAuthenticationViewController alloc] initWithDelegate:self];
  switch (self.authenticationType) {
    case BITAuthenticatorAuthTypeEmailAndPassword:
      viewController.requirePassword = YES;
      break;
    case BITAuthenticatorAuthTypeEmail:
      viewController.requirePassword = NO;
      break;
    case BITAuthenticatorAuthTypeUDIDProvider:
      viewController.requirePassword = NO;
      viewController.showsLoginViaWebButton = YES;
      break;
  }
  
  switch (self.validationType) {
    case BITAuthenticatorValidationTypeNever:
    case BITAuthenticatorValidationTypeOptional:
      viewController.showsSkipButton = YES;
      break;
    case BITAuthenticatorValidationTypeOnAppActive:
    case BITAuthenticatorValidationTypeOnFirstLaunch:
      viewController.showsSkipButton = NO;
      break;
  }
  
  if([self.delegate respondsToSelector:@selector(authenticator:willShowAuthenticationController:)]) {
    [self.delegate authenticator:self willShowAuthenticationController:viewController];
  }
  
  _authenticationController = viewController;
  _authenticationCompletionBlock = completion;
  [self showView:viewController];
}

- (void) didAuthenticateWithToken:(NSString*) token {
  [_authenticationController dismissViewControllerAnimated:YES completion:nil];
  _authenticationController = nil;
  [self setAuthenticationToken:token withType:[self.class stringForAuthenticationType:self.authenticationType]];
  self.installationIdentificationValidated = YES;
  self.lastAuthenticatedVersion = [self executableUUID];
  if(self.authenticationCompletionBlock) {
    self.authenticationCompletionBlock(self.authenticationToken, nil);
    self.authenticationCompletionBlock = nil;
  }
}

+ (NSString*) stringForAuthenticationType:(BITAuthenticatorAuthType) authType {
  switch (authType) {
    case BITAuthenticatorAuthTypeEmail: return @"iuid";
    case BITAuthenticatorAuthTypeEmailAndPassword: return @"auid";
    case BITAuthenticatorAuthTypeUDIDProvider:
      //fallthrough
    default:
      return @"udid";
      break;
  }
}
#pragma mark - AuthenticationViewControllerDelegate
- (void) authenticationViewControllerDidSkip:(UIViewController *)viewController {
  [viewController dismissViewControllerAnimated:YES completion:nil];
  
  _authenticationController = nil;
  [self setAuthenticationToken:nil withType:nil];
  if(self.validationType == BITAuthenticatorValidationTypeOptional) {
    self.didSkipOptionalLogin = YES;
    self.installationIdentificationValidated = YES;
  }
  NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                       code:BITAuthenticatorAuthenticationCancelled
                                   userInfo:nil];
  if(self.authenticationCompletionBlock) {
    self.authenticationCompletionBlock(self.authenticationToken, error);
    self.authenticationCompletionBlock = nil;
  }
}

- (void)authenticationViewController:(UIViewController *)viewController
       handleAuthenticationWithEmail:(NSString *)email
                            password:(NSString *)password
                          completion:(void (^)(BOOL, NSError *))completion {
  NSParameterAssert(email && email.length);
  NSParameterAssert(self.authenticationType == BITAuthenticatorAuthTypeEmail || (password && password.length));
  NSURLRequest* request = [self requestForAuthenticationEmail:email password:password];
  __weak typeof (self) weakSelf = self;
  BITHTTPOperation *operation = [self.hockeyAppClient operationWithURLRequest:request
                                                                   completion:^(BITHTTPOperation *operation, NSData* responseData, NSError *error) {
                                                                     typeof (self) strongSelf = weakSelf;
                                                                     NSError *authParseError = nil;
                                                                     NSString *authToken = [strongSelf.class authenticationTokenFromURLResponse:operation.response
                                                                                                                                           data:responseData
                                                                                                                                      error:&authParseError];
                                                                     if(nil == authToken) {
                                                                       completion(NO, authParseError);
                                                                     } else {
                                                                       //no need to call completion, we're dismissing it anyways
                                                                       [self didAuthenticateWithToken:authToken];
                                                                     }}];
  [self.hockeyAppClient enqeueHTTPOperation:operation];
}

- (NSURLRequest *) requestForAuthenticationEmail:(NSString*) email password:(NSString*) password {
  NSString *authenticationPath = [self authenticationPath];
  NSDictionary *params = nil;
  
  if(BITAuthenticatorAuthTypeEmail == self.authenticationType) {
    NSString *authCode = BITHockeyMD5([NSString stringWithFormat:@"%@%@",
                                       self.authenticationSecret ? : @"",
                                       email ? : @""]);
    params = @{
             @"email" : email ? : @"",
             @"authcode" : authCode.lowercaseString,
             };
  }

  NSMutableURLRequest *request = [self.hockeyAppClient requestWithMethod:@"POST"
                                                                    path:authenticationPath
                                                              parameters:params];
  if(BITAuthenticatorAuthTypeEmailAndPassword == self.authenticationType) {
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", email, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", bit_base64String(authData, authData.length)];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
  }
  return request;
}

- (NSString *) authenticationPath {
  if(BITAuthenticatorAuthTypeEmailAndPassword == self.authenticationType) {
    return [NSString stringWithFormat:@"api/3/apps/%@/identity/authorize", self.encodedAppIdentifier];
  } else {
    return [NSString stringWithFormat:@"api/3/apps/%@/identity/check", self.encodedAppIdentifier];
  }
}


+ (NSString *) authenticationTokenFromURLResponse:(NSHTTPURLResponse*) urlResponse data:(NSData*) data error:(NSError **) error {
  NSParameterAssert(urlResponse);
  if(nil == urlResponse) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidResponse
                               userInfo:@{ NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
    }
    return nil;
  }
  
  switch (urlResponse.statusCode) {
    case 401:
      if(error) {
        *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                     code:BITAuthenticatorNotAuthorized
                                 userInfo:@{
                                            NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationWrongEmailPassword")
                                            }];
      }
      break;
    case 200:
    case 404:
      //Do nothing, handled below
      break;
    default:
      if(error) {
        *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                     code:BITAuthenticatorAPIServerReturnedInvalidResponse
                                 userInfo:@{ NSLocalizedDescriptionKey : BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
        
      }
      break;
  }
  if(200 != urlResponse.statusCode && 404 != urlResponse.statusCode) {
    //make sure we have an error created if user wanted to have one
    NSParameterAssert(0 == error || *error);
    return nil;
  }
  
  NSError *jsonParseError = nil;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                  options:0
                                                    error:&jsonParseError];
  //no json or unexpected json
  if(nil == jsonObject || ![jsonObject isKindOfClass:[NSDictionary class]]) {
    if(error) {
      NSDictionary *userInfo = @{NSLocalizedDescriptionKey: BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")};
      if(jsonParseError) {
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
  if([status isEqualToString:@"identified"]) {
    authToken = jsonObject[@"iuid"];
  } else if([status isEqualToString:@"authorized"]) {
    authToken = jsonObject[@"auid"];
  } else if([status isEqualToString:@"not authorized"]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorNotAuthorized
                               userInfo:@{NSLocalizedDescriptionKey: BITHockeyLocalizedString(@"HockeyAuthenticationNotMember")}];
      
    }
  }
  //if no error is set yet, but error parameter is given, return a generic error
  if(nil == authToken && error && nil == *error) {
    *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                 code:BITAuthenticatorAPIServerReturnedInvalidResponse
                             userInfo:@{NSLocalizedDescriptionKey: BITHockeyLocalizedString(@"HockeyAuthenticationFailedAuthenticate")}];
  }
  return authToken;
}

- (void)authenticationViewControllerDidTapWebButton:(UIViewController *)viewController {
  NSURL *hockeyWebbasedLoginURL = [self.webpageURL URLByAppendingPathComponent:[NSString stringWithFormat:@"apps/%@/authorize", self.encodedAppIdentifier]];
  [[UIApplication sharedApplication] openURL:hockeyWebbasedLoginURL];
}

- (BOOL) handleOpenURL:(NSURL *) url
     sourceApplication:(NSString *) sourceApplication
            annotation:(id) annotation {
  BOOL isValidURL = NO;
  NSString *udid = [self UDIDFromOpenURL:url annotation:annotation isValidURL:&isValidURL];
  if(NO == isValidURL) {
    //do nothing, was not for us
    return NO;
  }
  
  if(udid){
    [self setAuthenticationToken:udid withType:[self.class stringForAuthenticationType:BITAuthenticatorAuthTypeUDIDProvider]];
    [self validateInstallationWithCompletion:^(BOOL validated, NSError *error) {
      if(validated) {
        [_authenticationController dismissViewControllerAnimated:YES completion:nil];
        _authenticationController = nil;
      } else {
        //TODO: show why validation failed
      }
    }];
  } else {
    //reset auth-token
    [self setAuthenticationToken:nil withType:nil];
  }
  return YES;
}

- (NSString *) UDIDFromOpenURL:(NSURL *) url annotation:(id) annotation isValidURL:(BOOL*) isValid{
  NSString *urlScheme = [NSString stringWithFormat:@"ha%@", self.appIdentifier];
  if([[url scheme] isEqualToString:urlScheme]) {
    if(isValid) {
      *isValid = YES;
    }
    NSString *query = [url query];
    NSString *udid = nil;
    //there should actually only one
    static NSString * const UDIDQuerySpecifier = @"udid";
    for(NSString *queryComponents in [query componentsSeparatedByString:@"&"]) {
      NSArray *parameterComponents = [queryComponents componentsSeparatedByString:@"="];
      if(2 == parameterComponents.count && [parameterComponents[0] isEqualToString:UDIDQuerySpecifier]) {
        udid = parameterComponents[1];
        break;
      }
    }
    return udid;
  } else {
    if(isValid) {
      *isValid = NO;
    }
    return nil;
  }
}

#pragma mark - Validation Pseudo-Delegate
- (void)validationFailedWithError:(NSError *)validationError completion:(tValidationCompletion) completion{
  if(completion) {
    completion(NO, validationError);
  }
}

- (void)validationSucceededWithCompletion:(tValidationCompletion) completion {
  self.installationIdentificationValidated = YES;
  if(completion) {
    completion(YES, nil);
  }
}

#pragma mark - Private helpers
- (UIDevice *)currentDevice {
  return _currentDevice ? : [UIDevice currentDevice];;
}

- (void) cleanupInternalStorage {
  [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenKey];
  [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenTypeKey];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBITAuthenticatorDidSkipOptionalLogin];
  [self setLastAuthenticatedVersion:nil];
}

- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  if(nil == _appDidBecomeActiveObserver) {
    _appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf applicationDidBecomeActive:note];
                                                                                }];
  }
  if(nil == _appWillResignActiveObserver) {
    _appWillResignActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf applicationWillResignActive:note];
                                                                                }];
  }
}

- (void) unregisterObservers {
  if(_appDidBecomeActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidBecomeActiveObserver];
    _appDidBecomeActiveObserver = nil;
  }
  if(_appWillResignActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appWillResignActiveObserver];
    _appWillResignActiveObserver = nil;
  }
}

#pragma mark - Property overrides
- (void)setAuthenticationToken:(NSString *)authenticationToken withType:(NSString*) authenticationTokenType {
  NSParameterAssert(nil == authenticationToken || nil != authenticationTokenType);
  if(![self.authenticationToken isEqualToString:authenticationToken] || ![self.authenticationTokenType isEqualToString:authenticationTokenType]) {
    [self willChangeValueForKey:@"installationIdentification"];
    if(nil == authenticationToken) {
      [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenKey];
      [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenTypeKey];
    } else {
      [self addStringValueToKeychainForThisDeviceOnly:authenticationToken forKey:kBITAuthenticatorAuthTokenKey];
      [self addStringValueToKeychainForThisDeviceOnly:authenticationTokenType forKey:kBITAuthenticatorAuthTokenTypeKey];
    }
    [self didChangeValueForKey:@"installationIdentification"];
  }
}

- (NSString *)authenticationToken {
  NSString *authToken = [self stringValueFromKeychainForKey:kBITAuthenticatorAuthTokenKey];
  if(nil == authToken) return nil;
  
  //check if the auth token matches the current setting
  if(![self.authenticationTokenType isEqualToString:[self.class stringForAuthenticationType:self.authenticationType]]) {
    BITHockeyLog(@"Auth type mismatch for stored auth-token. Resetting.");
    [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenKey];
    return nil;
  }

  return authToken;
}

- (NSString *)authenticationTokenType {
  NSString *authTokenType = [self stringValueFromKeychainForKey:kBITAuthenticatorAuthTokenTypeKey];
  return authTokenType;
}

- (void)setLastAuthenticatedVersion:(NSString *)lastAuthenticatedVersion {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  if(nil == lastAuthenticatedVersion){
    [defaults removeObjectForKey:kBITAuthenticatorLastAuthenticatedVersionKey];
  } else {
    [defaults setObject:lastAuthenticatedVersion
                 forKey:kBITAuthenticatorLastAuthenticatedVersionKey];
    [defaults synchronize];
  }
}

- (NSString *)lastAuthenticatedVersion {
  return [[NSUserDefaults standardUserDefaults] objectForKey:kBITAuthenticatorLastAuthenticatedVersionKey];
}

- (void)setDidSkipOptionalLogin:(BOOL)didSkipOptionalLogin {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  if(NO == didSkipOptionalLogin){
    [defaults removeObjectForKey:kBITAuthenticatorDidSkipOptionalLogin];
  } else {
    [defaults setObject:@(YES)
                 forKey:kBITAuthenticatorDidSkipOptionalLogin];
    [defaults synchronize];
  }
}

- (BOOL)didSkipOptionalLogin {
  return [[NSUserDefaults standardUserDefaults] objectForKey:kBITAuthenticatorDidSkipOptionalLogin];
}

#pragma mark - Application Lifecycle
- (void)applicationDidBecomeActive:(NSNotification *)note {
  [self triggerAuthentication];
}

- (void)applicationWillResignActive:(NSNotification *)note {
  if(BITAuthenticatorValidationTypeOnAppActive == self.validationType) {
    self.installationIdentificationValidated = NO;
  }
}

#pragma mark - 
- (tValidationCompletion) defaultValidationCompletionBlock {
  return ^(BOOL validated, NSError *error) {
    switch (self.validationType) {
      case BITAuthenticatorValidationTypeNever:
      case BITAuthenticatorValidationTypeOptional:
        break;
      case BITAuthenticatorValidationTypeOnAppActive:
      case BITAuthenticatorValidationTypeOnFirstLaunch:
        if(!validated) {
          [self authenticateWithCompletion:nil];
        }
        break;
    }
  };
};
@end
