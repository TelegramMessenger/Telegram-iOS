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

static NSString* const kBITAuthenticatorUUIDKey = @"BITAuthenticatorUUIDKey";
static NSString* const kBITAuthenticatorIdentifierKey = @"BITAuthenticatorIdentifierKey";
static NSString* const kBITAuthenticatorIdentifierTypeKey = @"BITAuthenticatorIdentifierTypeKey";
static NSString* const kBITAuthenticatorLastAuthenticatedVersionKey = @"BITAuthenticatorLastAuthenticatedVersionKey";
static NSString* const kBITAuthenticatorUserEmailKey = @"BITAuthenticatorUserEmailKey";

//deprecated
static NSString* const kBITAuthenticatorAuthTokenKey = @"BITAuthenticatorAuthTokenKey";
static NSString* const kBITAuthenticatorAuthTokenTypeKey = @"BITAuthenticatorAuthTokenTypeKey";


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
    
    _identificationType = BITAuthenticatorIdentificationTypeAnonymous;
    _automaticMode = YES;
    _restrictApplicationUsage = NO;
    _restrictionEnforcementFrequency = BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch;
  }
  return self;
}

#pragma mark - BITHockeyBaseManager overrides
- (void)startManager {
  //disabled in the appStore
  if([self isAppStoreEnvironment]) return;
  
  switch ([[UIApplication sharedApplication] applicationState]) {
    case UIApplicationStateActive:
      [self authenticate];
      break;
    case UIApplicationStateBackground:
    case UIApplicationStateInactive:
      // do nothing, wait for active state
      break;
  }
  
  [self registerObservers];
}

#pragma mark -
- (void) authenticate {
  //when running in manual mode, we don't actually do anything ourselves
  if(!self.automaticMode) return;
  
  [self identifyWithCompletion:^(BOOL identified, NSError *error) {
    if(identified) {
      if([self needsValidation]) {
        [self validateWithCompletion:^(BOOL validated, NSError *error) {
          if(validated) {
            [_authenticationController dismissViewControllerAnimated:YES completion:nil];
            _authenticationController = nil;
          } else {
            [self storeInstallationIdentifier:nil withType:self.identificationType];
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                                message:error.localizedDescription
                                                               delegate:nil
                                                      cancelButtonTitle:BITHockeyLocalizedString(@"HockeyOK")
                                                      otherButtonTitles:nil];
            [alertView show];
            dispatch_async(dispatch_get_main_queue(), ^{
              [self authenticate];
            });
          }
        }];
      } else {
        [_authenticationController dismissViewControllerAnimated:YES completion:nil];
        _authenticationController = nil;
      }
    } else {
      BITHockeyLog(@"Failed to identify. Error: %@", error);
    }
  }];
}

- (BOOL) needsValidation {
  if(BITAuthenticatorIdentificationTypeAnonymous == self.identificationType) {
    return NO;
  }
  if(NO == self.restrictApplicationUsage) {
    return NO;
  }
  if(self.restrictionEnforcementFrequency == BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch &&
     ![self.executableUUID isEqualToString:self.lastAuthenticatedVersion]) {
    return YES;
  }
  if(NO == self.isValidated && self.restrictionEnforcementFrequency == BITAuthenticatorAppRestrictionEnforcementOnAppActive) {
    return YES;
  }
  return NO;
}
- (void) identifyWithCompletion:(void (^)(BOOL identified, NSError *))completion {
  if(_authenticationController) {
    BITHockeyLog(@"Authentication controller already visible. Ingoring identify request");
    if(completion) completion(NO, nil);
    return;
  }
  //first check if the stored identification type matches the one currently configured
  NSString *storedTypeString = [self stringValueFromKeychainForKey:kBITAuthenticatorIdentifierTypeKey];
  NSString *configuredTypeString = [self.class stringForIdentificationType:self.identificationType];
  if(storedTypeString && ![storedTypeString isEqualToString:configuredTypeString]) {
    BITHockeyLog(@"Identification type mismatch for stored auth-token. Resetting.");
    [self storeInstallationIdentifier:nil withType:BITAuthenticatorIdentificationTypeAnonymous];
  }
  
  NSString *identification = [self installationIdentifier];
  
  if(identification) {
    self.identified = YES;
    if(completion) completion(YES, nil);
    return;
  }
  
  //it's not identified yet, do it now
  BITAuthenticationViewController *viewController = nil;
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeAnonymous:
      [self storeInstallationIdentifier:bit_UUID() withType:BITAuthenticatorIdentificationTypeAnonymous];
      self.identified = YES;
      if(completion) completion(YES, nil);
      return;
      break;
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
      break;
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
      if(nil == self.authenticationSecret) {
        NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                             code:BITAuthenticatorAuthorizationSecretMissing
                                         userInfo:@{NSLocalizedDescriptionKey : @"For email identification, the authentication secret must be set"}];
        if(completion) completion(NO, error);
        return;
      }
      viewController = [[BITAuthenticationViewController alloc] initWithDelegate:self];
      viewController.requirePassword = NO;
      viewController.tableViewTitle = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerDataEmailDescription");
      break;
  }
  
  if([self.delegate respondsToSelector:@selector(authenticator:willShowAuthenticationController:)]) {
    [self.delegate authenticator:self willShowAuthenticationController:viewController];
  }
  
  NSAssert(viewController, @"ViewController should've been created");
  
  viewController.email = [self stringValueFromKeychainForKey:kBITAuthenticatorUserEmailKey];
  _authenticationController = viewController;
  _identificationCompletion = completion;
  [self showView:viewController];
}

#pragma mark - Validation
- (void) validateWithCompletion:(void (^)(BOOL validated, NSError *))completion {
  BOOL requirementsFulfilled = YES;
  NSError *error = nil;
  switch(self.identificationType) {
    case BITAuthenticatorIdentificationTypeAnonymous: {
      error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                  code:BITAuthenticatorErrorUnknown
                              userInfo:@{NSLocalizedDescriptionKey : @"Anonymous users can't be validated"}];
      requirementsFulfilled = NO;
      break;
    }
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
      if(nil == self.authenticationSecret) {
        error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                    code:BITAuthenticatorAuthorizationSecretMissing
                                userInfo:@{NSLocalizedDescriptionKey : @"For email validation, the authentication secret must be set"}];
        requirementsFulfilled = NO;
        break;
      }
      //no break
    case BITAuthenticatorIdentificationTypeDevice:
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
      if(nil == self.installationIdentifier) {
        error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                    code:BITAuthenticatorNotIdentified
                                userInfo:@{NSLocalizedDescriptionKey : @"Make sure to identify the installation first"}];
        requirementsFulfilled = NO;
      }
      break;
  }
  if(NO == requirementsFulfilled) {
    if(completion) {
      completion(NO, error);
    }
    return;
  }
  
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
                         self.validated = NO;
                         if(completion) completion(NO, error);
                       } else {
                         NSError *validationParseError = nil;
                         BOOL valid = [strongSelf.class isValidationResponseValid:responseData error:&validationParseError];
                         strongSelf.validated = valid;
                         if(valid) {
                           [self setLastAuthenticatedVersion:self.executableUUID];
                         }
                         if(completion) completion(valid, validationParseError);
                       }
                     }];
}

- (NSDictionary*) validationParameters {
  NSParameterAssert(self.installationIdentifier);
  NSParameterAssert(self.installationIdentifierTypeString);
  return @{self.installationIdentifierTypeString : self.installationIdentifier};
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

#pragma mark - AuthenticationViewControllerDelegate
- (void)authenticationViewController:(UIViewController *)viewController
       handleAuthenticationWithEmail:(NSString *)email
                            password:(NSString *)password
                          completion:(void (^)(BOOL, NSError *))completion {
  NSParameterAssert(email && email.length);
  NSParameterAssert(self.identificationType == BITAuthenticatorIdentificationTypeHockeyAppEmail || (password && password.length));
  NSURLRequest* request = [self requestForAuthenticationEmail:email password:password];
  __weak typeof (self) weakSelf = self;
  BITHTTPOperation *operation = [self.hockeyAppClient operationWithURLRequest:request
                                                                   completion:^(BITHTTPOperation *operation, NSData* responseData, NSError *error) {
                                                                     typeof (self) strongSelf = weakSelf;
                                                                     NSError *authParseError = nil;
                                                                     NSString *authToken = [strongSelf.class authenticationTokenFromURLResponse:operation.response
                                                                                                                                           data:responseData
                                                                                                                                          error:&authParseError];
                                                                     BOOL identified;
                                                                     if(authToken) {
                                                                       identified = YES;
                                                                       [strongSelf storeInstallationIdentifier:authToken withType:strongSelf.identificationType];
                                                                       [strongSelf->_authenticationController dismissViewControllerAnimated:YES
                                                                                                                                 completion:nil];
                                                                       strongSelf->_authenticationController = nil;
                                                                       [self addStringValueToKeychain:email forKey:kBITAuthenticatorUserEmailKey];
                                                                     } else {
                                                                       identified = NO;
                                                                     }
                                                                     self.identified = identified;
                                                                     completion(identified, authParseError);
                                                                     if(strongSelf.identificationCompletion) strongSelf.identificationCompletion(identified, authParseError);
                                                                     strongSelf.identificationCompletion = nil;
                                                                     
                                                                   }];
  [self.hockeyAppClient enqeueHTTPOperation:operation];
}

- (NSURLRequest *) requestForAuthenticationEmail:(NSString*) email password:(NSString*) password {
  NSString *authenticationPath = [self authenticationPath];
  NSDictionary *params = nil;
  
  if(BITAuthenticatorIdentificationTypeHockeyAppEmail == self.identificationType) {
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
  if(BITAuthenticatorIdentificationTypeHockeyAppUser == self.identificationType) {
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", email, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", bit_base64String(authData, authData.length)];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
  }
  return request;
}

- (NSString *) authenticationPath {
  if(BITAuthenticatorIdentificationTypeHockeyAppUser == self.identificationType) {
    return [NSString stringWithFormat:@"api/3/apps/%@/identity/authorize", self.encodedAppIdentifier];
  } else {
    return [NSString stringWithFormat:@"api/3/apps/%@/identity/check", self.encodedAppIdentifier];
  }
}

+ (NSString *) authenticationTokenFromURLResponse:(NSHTTPURLResponse*) urlResponse data:(NSData*) data error:(NSError **) error {
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
    NSParameterAssert(nil == error || *error);
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

- (NSURL *)deviceAuthenticationURL {
  return [self.webpageURL URLByAppendingPathComponent:[NSString stringWithFormat:@"apps/%@/authorize", self.encodedAppIdentifier]];
}

- (void)authenticationViewControllerDidTapWebButton:(UIViewController *)viewController {
  NSURL *url = [self deviceAuthenticationURL];
  if(url) {
    [[UIApplication sharedApplication] openURL:url];
  }
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
    if(NO == self.restrictApplicationUsage) {
      [_authenticationController dismissViewControllerAnimated:YES completion:nil];
      _authenticationController = nil;
    }
    [self storeInstallationIdentifier:udid withType:BITAuthenticatorIdentificationTypeDevice];
    self.identified = YES;
    if(self.identificationCompletion) {
      self.identificationCompletion(YES, nil);
      self.identificationCompletion = nil;
    }
  } else {
    //reset token
    [self storeInstallationIdentifier:nil withType:BITAuthenticatorIdentificationTypeDevice];
    self.identified = NO;
    if(self.identificationCompletion) {
      NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                           code:BITAuthenticatorErrorUnknown
                                       userInfo:@{NSLocalizedDescriptionKey : @"Failed to retrieve UDID from URL"}];
      self.identificationCompletion(NO, error);
      self.identificationCompletion = nil;
    }
  }
  return YES;
}

- (NSString *) UDIDFromOpenURL:(NSURL *) url annotation:(id) annotation isValidURL:(BOOL*) isValid{
  NSString *const kAuthorizationHost = @"authorize";
  NSString *urlScheme = _urlScheme ? : [NSString stringWithFormat:@"ha%@", self.appIdentifier];
  if([[url scheme] isEqualToString:urlScheme] && [[url host] isEqualToString:kAuthorizationHost]) {
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

#pragma mark - Private helpers
- (void) cleanupInternalStorage {
  [self removeKeyFromKeychain:kBITAuthenticatorIdentifierTypeKey];
  [self removeKeyFromKeychain:kBITAuthenticatorIdentifierKey];
  [self removeKeyFromKeychain:kBITAuthenticatorUUIDKey];
  [self removeKeyFromKeychain:kBITAuthenticatorUserEmailKey];
  [self setLastAuthenticatedVersion:nil];
  
  //cleanup values stored from 3.5 Beta1..Beta3
  [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenKey];
  [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenTypeKey];
}

#pragma mark - KVO
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
- (void)storeInstallationIdentifier:(NSString *)installationIdentifier withType:(BITAuthenticatorIdentificationType) type {
  if(nil == installationIdentifier) {
    [self removeKeyFromKeychain:kBITAuthenticatorIdentifierKey];
    [self removeKeyFromKeychain:kBITAuthenticatorIdentifierTypeKey];
  } else {
    BOOL success = [self addStringValueToKeychainForThisDeviceOnly:installationIdentifier
                                                            forKey:kBITAuthenticatorIdentifierKey];
    NSParameterAssert(success);
    success = [self addStringValueToKeychainForThisDeviceOnly:[self.class stringForIdentificationType:type]
                                                       forKey:kBITAuthenticatorIdentifierTypeKey];
    NSParameterAssert(success);
#pragma unused(success)
  }
}

- (NSString*) installationIdentifier {
  NSString *identifier = [self stringValueFromKeychainForKey:kBITAuthenticatorIdentifierKey];
  return identifier;
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

- (NSString *)installationIdentifierTypeString {
  return [self.class stringForIdentificationType:self.identificationType];
}

+ (NSString *)stringForIdentificationType:(BITAuthenticatorIdentificationType) identificationType {
  switch(identificationType) {
    case BITAuthenticatorIdentificationTypeHockeyAppEmail: return @"iuid";
    case BITAuthenticatorIdentificationTypeHockeyAppUser: return @"auid";
    case BITAuthenticatorIdentificationTypeDevice: return @"udid";
    case BITAuthenticatorIdentificationTypeAnonymous: return @"uuid";
  }
}

- (void)setIdentificationType:(BITAuthenticatorIdentificationType)identificationType {
  if(_identificationType != identificationType) {
    _identificationType = identificationType;
    self.identified = NO;
    self.validated = NO;
  }
}

- (NSString *)publicInstallationIdentifier {
  switch (self.identificationType) {
    case BITAuthenticatorIdentificationTypeHockeyAppEmail:
    case BITAuthenticatorIdentificationTypeHockeyAppUser:
      return [self stringValueFromKeychainForKey:kBITAuthenticatorUserEmailKey];
    case BITAuthenticatorIdentificationTypeAnonymous:
    case BITAuthenticatorIdentificationTypeDevice:
      return [self stringValueFromKeychainForKey:kBITAuthenticatorIdentifierKey];
  }
}

#pragma mark - Application Lifecycle
- (void)applicationDidBecomeActive:(NSNotification *)note {
  [self authenticate];
}

- (void)applicationWillResignActive:(NSNotification *)note {
  //only reset if app is really going into the background, e.g not when pulling down
  //the notification center
  if(BITAuthenticatorAppRestrictionEnforcementOnAppActive == self.restrictionEnforcementFrequency &&
     [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
    self.validated = NO;
  }
}
@end
