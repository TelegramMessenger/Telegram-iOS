//
//  BITAuthenticator
//  HockeySDK
//
//  Created by Stephan Diederich on 08.08.13.
//
//

#import "BITAuthenticator.h"
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITAuthenticator_Private.h"
#import "BITHTTPOperation.h"
#import "BITHockeyAppClient.h"

static NSString* const kBITAuthenticatorAuthTokenKey = @"BITAuthenticatorAuthTokenKey";
static NSString* const kBITAuthenticatorLastAuthenticatedVersionKey = @"BITAuthenticatorLastAuthenticatedVersionKey";

@implementation BITAuthenticator {
  id _appDidBecomeActiveObserver;
  
  UIViewController *_authenticationController;
}

- (void)dealloc {
  [self unregisterObservers];
}

- (instancetype) initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironemt:(BOOL)isAppStoreEnvironment {
  self = [super initWithAppIdentifier:appIdentifier isAppStoreEnvironemt:isAppStoreEnvironment];
  if( self ) {
    
  }
  return self;
}

#pragma mark - BITHockeyBaseManager overrides
- (void)startManager {
  //disabled in the appStore
  if([self isAppStoreEnvironment]) return;
  
  [self registerObservers];
  
  switch (self.validationType) {
    case BITAuthenticatorValidationTypeOnAppActive:
      [self validateInstallationWithCompletion:[self defaultValidationCompletionBlock]];
      break;
    case BITAuthenticatorValidationTypeOnFirstLaunch:
      if(![self.lastAuthenticatedVersion isEqualToString:self.executableUUID]) {
        [self validateInstallationWithCompletion:[self defaultValidationCompletionBlock]];
      }
      break;
    case BITAuthenticatorValidationTypeOptional:
      //TODO: what to do in optional case?
      break;
    case BITAuthenticatorValidationTypeNever:
      break;
  }
}

#pragma mark -
- (NSString *)installationIdentification {
  NSString *authToken = self.authenticationToken;
  if(authToken) {
    return authToken;
  }
  UIDevice *device = self.currentDevice;
  if([device respondsToSelector:@selector(identifierForVendor)]) {
    return self.currentDevice.identifierForVendor.UUIDString;
  } else {
    SEL uniqueIdentifier = NSSelectorFromString(@"uniqueIdentifier");
    if([device respondsToSelector:uniqueIdentifier]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
      NSString *uuid = [device performSelector:uniqueIdentifier];
#pragma clang diagnostic pop
      return uuid;
    } else {
      //TODO: what?
      return nil;
    }
  }
}

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
       completion:^(BITHTTPOperation *operation, id response, NSError *error) {
         typeof (self) strongSelf = weakSelf;
         if(nil == response) {
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
           BOOL isValidated = [strongSelf.class isValidationResponseValid:response error:&validationParseError];
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
  NSDictionary *params = nil;
  switch (self.authenticationType) {
    case BITAuthenticatorAuthTypeEmail:
      params = @{@"iuid" : self.authenticationToken};
      break;
    case BITAuthenticatorAuthTypeEmailAndPassword:
      params = @{@"auid" : self.authenticationToken};
      break;
  }
  return params;
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
                                   code:BITAuthenticatorAPIServerReturnedInvalidRespone
                               userInfo:(jsonParseError ? @{NSUnderlyingErrorKey : jsonParseError} : nil)];
    }
    return NO;
  }
  if(![jsonObject isKindOfClass:[NSDictionary class]]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidRespone
                               userInfo:nil];
    }
    return NO;
  }
  
  NSString *status = jsonObject[@"status"];
  if([status isEqualToString:@"not authorized"]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorNotAuthorized
                               userInfo:nil];
    }
    return NO;
  } else if([status isEqualToString:@"not found"]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorNotAuthorized
                               userInfo:nil];
    }
    return NO;
  } else if([status isEqualToString:@"validated"]) {
    return YES;
  } else {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidRespone
                               userInfo:nil];
    }
    return NO;
  }
}

- (void)authenticateWithCompletion:(tAuthenticationCompletion)completion {
  if(_authenticationController) {
    BITHockeyLog(@"Already authenticating. Ignoring request");
    return;
  }
  
  BOOL requiresPassword;
  switch (self.authenticationType) {
    case BITAuthenticatorAuthTypeEmailAndPassword:
      requiresPassword = YES;
      break;
    case BITAuthenticatorAuthTypeEmail:
      requiresPassword = NO;
      break;
  }
  
  BITAuthenticationViewController *viewController = [[BITAuthenticationViewController alloc] initWithApplicationIdentifier:self.encodedAppIdentifier
                                                                                                           requirePassword:requiresPassword
                                                                                                                  delegate:self];
  viewController.authenticator = self;
  switch (self.validationType) {
    case BITAuthenticatorValidationTypeNever:
    case BITAuthenticatorValidationTypeOptional:
      viewController.showsCancelButton = YES;
      break;
    case BITAuthenticatorValidationTypeOnAppActive:
    case BITAuthenticatorValidationTypeOnFirstLaunch:
      viewController.showsCancelButton = NO;
      break;
  }
  
  if([self.delegate respondsToSelector:@selector(authenticator:willShowAuthenticationController:)]) {
    [self.delegate authenticator:self willShowAuthenticationController:viewController];
  }
  
  _authenticationController = viewController;
  _authenticationCompletionBlock = completion;
  UIViewController *rootViewController = [self.findVisibleWindow rootViewController];
  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
  [rootViewController presentModalViewController:navController
                                        animated:YES];
}

#pragma mark - AuthenticationViewControllerDelegate
- (void) authenticationViewControllerDidCancel:(UIViewController*) viewController {
  [viewController dismissModalViewControllerAnimated:YES];
  
  _authenticationController = nil;
  self.authenticationToken = nil;
  NSError *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                       code:BITAuthenticatorAuthenticationCancelled
                                   userInfo:nil];
  if(self.authenticationCompletionBlock) {
    self.authenticationCompletionBlock(self.authenticationToken, error);
    self.authenticationCompletionBlock = nil;
  }
}

- (void) authenticationViewController:(UIViewController*) viewController
               authenticatedWithToken:(NSString*) token {
  [viewController dismissModalViewControllerAnimated:YES];
  _authenticationController = nil;
  self.authenticationToken = token;
  self.lastAuthenticatedVersion = [self executableUUID];
  if(self.authenticationCompletionBlock) {
    self.authenticationCompletionBlock(self.authenticationToken, nil);
    self.authenticationCompletionBlock = nil;
  }
}

#pragma mark - Validation Pseudo-Delegate
- (void)validationFailedWithError:(NSError *)validationError completion:(tValidationCompletion) completion{
  if(completion) {
    completion(NO, validationError);
  }
}

- (void)validationSucceededWithCompletion:(tValidationCompletion) completion {
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
  [self setLastAuthenticatedVersion:nil];
}

- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  _appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                  object:nil
                                                                                   queue:NSOperationQueue.mainQueue
                                                                              usingBlock:^(NSNotification *note) {
                                                                                typeof(self) strongSelf = weakSelf;
                                                                                [strongSelf applicationDidBecomeActive:note];
                                                                              }];
}

- (void) unregisterObservers {
  if(_appDidBecomeActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidBecomeActiveObserver];
    _appDidBecomeActiveObserver = nil;
  }
}

#pragma mark - Property overrides
- (void)setAuthenticationToken:(NSString *)authenticationToken {
  if(![self.authenticationToken isEqualToString:authenticationToken]) {
    [self willChangeValueForKey:@"installationIdentification"];
    if(nil == authenticationToken) {
      [self removeKeyFromKeychain:kBITAuthenticatorAuthTokenKey];
    } else {
      [self addStringValueToKeychain:authenticationToken forKey:kBITAuthenticatorAuthTokenKey];
    }
    [self didChangeValueForKey:@"installationIdentification"];
  }
}

- (NSString *)authenticationToken {
  return [self stringValueFromKeychainForKey:kBITAuthenticatorAuthTokenKey];
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

#pragma mark - Application Lifecycle
- (void)applicationDidBecomeActive:(NSNotification *)note {
  if(BITAuthenticatorValidationTypeOnAppActive == self.validationType) {
    [self validateInstallationWithCompletion:[self defaultValidationCompletionBlock]];
  }
}

- (tValidationCompletion) defaultValidationCompletionBlock {
  return ^(BOOL validated, NSError *error) {
    switch (self.validationType) {
      case BITAuthenticatorValidationTypeNever:
      case BITAuthenticatorValidationTypeOptional:
        break;
      case BITAuthenticatorValidationTypeOnAppActive:
      case BITAuthenticatorValidationTypeOnFirstLaunch:
        [self authenticateWithCompletion:nil];
        break;
    }
  };
};

@end
