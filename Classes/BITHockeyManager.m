/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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
#import "HockeySDKPrivate.h"

#import "BITHockeyManagerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITHockeyHelper.h"


#if HOCKEYSDK_FEATURE_CRASH_REPORTER
#import "BITCrashManagerPrivate.h"
#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */

#if HOCKEYSDK_FEATURE_UPDATES
#import "BITUpdateManagerPrivate.h"
#endif /* HOCKEYSDK_FEATURE_UPDATES */

#if HOCKEYSDK_FEATURE_STORE_UPDATES
#import "BITStoreUpdateManagerPrivate.h"
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */

#if HOCKEYSDK_FEATURE_FEEDBACK
#import "BITFeedbackManagerPrivate.h"
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */

#if HOCKEYSDK_FEATURE_AUTHENTICATOR
#import "BITAuthenticator_Private.h"
#import "BITHockeyAppClient.h"
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */

@interface BITHockeyManager ()

- (BOOL)shouldUseLiveIdentifier;

#if HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT
- (void)configureJMC;
#endif /* HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT */

@end


@implementation BITHockeyManager {
  NSString *_appIdentifier;
  
  BOOL _validAppIdentifier;
  
  BOOL _startManagerIsInvoked;
  
  BOOL _startUpdateManagerIsInvoked;
}

#pragma mark - Private Class Methods

- (BOOL)checkValidityOfAppIdentifier:(NSString *)identifier {
  BOOL result = NO;
  
  if (identifier) {
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:identifier];
    result = ([identifier length] == 32) && ([hexSet isSupersetOfSet:inStringSet]);
  }
  
  return result;
}

- (void)logInvalidIdentifier:(NSString *)environment {
  if (!_appStoreEnvironment) {
    if ([environment isEqualToString:@"liveIdentifier"]) {
      NSLog(@"[HockeySDK] WARNING: The liveIdentifier is invalid! The SDK will be disabled when deployed to the App Store without setting a valid app identifier!");
    } else {
      NSLog(@"[HockeySDK] ERROR: The %@ is invalid! Please use the HockeyApp app identifier you find on the apps website on HockeyApp! The SDK is disabled!", environment);
    }
  }
}


#pragma mark - Public Class Methods

+ (BITHockeyManager *)sharedHockeyManager {
  static BITHockeyManager *sharedInstance = nil;
  static dispatch_once_t pred;
  
  dispatch_once(&pred, ^{
    sharedInstance = [BITHockeyManager alloc];
    sharedInstance = [sharedInstance init];
  });
  
  return sharedInstance;
}

- (id) init {
  if ((self = [super init])) {
    _serverURL = nil;
    _delegate = nil;
    
    _disableCrashManager = NO;
    _disableUpdateManager = NO;
    _disableFeedbackManager = NO;

    _enableStoreUpdateManager = NO;
    
    _appStoreEnvironment = NO;
    _startManagerIsInvoked = NO;
    _startUpdateManagerIsInvoked = NO;
    
    _installString = bit_appAnonID();
    
#if !TARGET_IPHONE_SIMULATOR
    // check if we are really in an app store environment
    if (![[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]) {
      _appStoreEnvironment = YES;
    }
#endif

    [self performSelector:@selector(validateStartManagerIsInvoked) withObject:nil afterDelay:0.0f];
  }
  return self;
}


#pragma mark - Public Instance Methods (Configuration)

- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id)delegate {
  _delegate = delegate;
  _appIdentifier = [appIdentifier copy];
  
  [self initializeModules];
}

- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id)delegate {
  _delegate = delegate;

  // check the live identifier now, because otherwise invalid identifier would only be logged when the app is already in the store
  if (![self checkValidityOfAppIdentifier:liveIdentifier]) {
    [self logInvalidIdentifier:@"liveIdentifier"];
  }

  if ([self shouldUseLiveIdentifier]) {
    _appIdentifier = [liveIdentifier copy];
  }
  else {
    _appIdentifier = [betaIdentifier copy];
  }
  
  [self initializeModules];
}


- (void)startManager {
  if (!_validAppIdentifier) return;
  
  if (![self isSetUpOnMainThread]) return;
  
  BITHockeyLog(@"INFO: Starting HockeyManager");
  _startManagerIsInvoked = YES;
  
#if HOCKEYSDK_FEATURE_CRASH_REPORTER
  // start CrashManager
  if (![self isCrashManagerDisabled]) {
    BITHockeyLog(@"INFO: Start CrashManager");
    if (_serverURL) {
      [_crashManager setServerURL:_serverURL];
    }
    
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
    if (_authenticator) {
      [_crashManager setInstallationIdentification:[self.authenticator publicInstallationIdentifier]];
      [_crashManager setInstallationIdentificationType:[self.authenticator identificationType]];
      [_crashManager setInstallationIdentified:[self.authenticator isIdentified]];
    }
#endif

    [_crashManager startManager];
  }
#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */
  
#if HOCKEYSDK_FEATURE_STORE_UPDATES
  // start StoreUpdateManager
  if ([self isStoreUpdateManagerEnabled]) {
    BITHockeyLog(@"INFO: Start StoreUpdateManager");
    if (_serverURL) {
      [_storeUpdateManager setServerURL:_serverURL];
    }
    [_storeUpdateManager performSelector:@selector(startManager) withObject:nil afterDelay:0.5f];
  }
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */

#if HOCKEYSDK_FEATURE_FEEDBACK
  // start FeedbackManager
  if (![self isFeedbackManagerDisabled]) {
    BITHockeyLog(@"INFO: Start FeedbackManager");
    if (_serverURL) {
      [_feedbackManager setServerURL:_serverURL];
    }
    [_feedbackManager performSelector:@selector(startManager) withObject:nil afterDelay:1.0f];
  }
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
  
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  // start Authenticator
  if (![self isAppStoreEnvironment]) {
    // hook into manager with kvo!
    [_authenticator addObserver:self forKeyPath:@"identified" options:0 context:nil];
    
    BITHockeyLog(@"INFO: Start Authenticator");
    if (_serverURL) {
      [_authenticator setServerURL:_serverURL];
    }
    [_authenticator performSelector:@selector(startManager) withObject:nil afterDelay:0.5f];
  }
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
  
#if HOCKEYSDK_FEATURE_UPDATES
  BOOL jmcIsPresent = NO;
  BOOL isIdentified = NO;

#if HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT
  jmcIsPresent = [[self class] isJMCPresent]
#endif /* HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT */

#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  if (![self isAppStoreEnvironment])
    isIdentified = [self.authenticator isIdentified];
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */

  // Setup UpdateManager
  if (
      (![self isUpdateManagerDisabled] && isIdentified) ||
      jmcIsPresent) {
    [self invokeStartUpdateManager];
  }
#endif /* HOCKEYSDK_FEATURE_UPDATES */
}


#if HOCKEYSDK_FEATURE_UPDATES
- (void)setDisableUpdateManager:(BOOL)disableUpdateManager {
  if (_updateManager) {
    [_updateManager setDisableUpdateManager:disableUpdateManager];
  }
  _disableUpdateManager = disableUpdateManager;
}
#endif /* HOCKEYSDK_FEATURE_UPDATES */


#if HOCKEYSDK_FEATURE_STORE_UPDATES
- (void)setEnableStoreUpdateManager:(BOOL)enableStoreUpdateManager {
  if (_storeUpdateManager) {
    [_storeUpdateManager setEnableStoreUpdateManager:enableStoreUpdateManager];
  }
  _enableStoreUpdateManager = enableStoreUpdateManager;
}
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */


#if HOCKEYSDK_FEATURE_FEEDBACK
- (void)setDisableFeedbackManager:(BOOL)disableFeedbackManager {
  if (_feedbackManager) {
    [_feedbackManager setDisableFeedbackManager:disableFeedbackManager];
  }
  _disableFeedbackManager = disableFeedbackManager;
}
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */


- (void)setServerURL:(NSString *)aServerURL {
  // ensure url ends with a trailing slash
  if (![aServerURL hasSuffix:@"/"]) {
    aServerURL = [NSString stringWithFormat:@"%@/", aServerURL];
  }
  
  if (_serverURL != aServerURL) {
    _serverURL = [aServerURL copy];
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
    _authenticator.hockeyAppClient.baseURL = [NSURL URLWithString:_serverURL ? _serverURL : BITHOCKEYSDK_URL];
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
  }
}


- (NSString *)version {
  return BITHOCKEY_VERSION;
}

- (NSString *)build {
  return BITHOCKEY_BUILD;
}


#pragma mark - KVO

#if HOCKEYSDK_FEATURE_UPDATES
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if ([keyPath isEqualToString:@"identified"] &&
      [object valueForKey:@"isIdentified"] ) {
    if (![self isAppStoreEnvironment]) {
      BOOL identified = [(NSNumber *)[object valueForKey:@"isIdentified"] boolValue];
      if (identified && ![self isUpdateManagerDisabled]) {
        [self invokeStartUpdateManager];
      }
    }
#if HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT
  } else if (([object trackerConfig]) && ([[object trackerConfig] isKindOfClass:[NSDictionary class]])) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *trackerConfig = [[defaults valueForKey:@"BITTrackerConfigurations"] mutableCopy];
    if (!trackerConfig) {
      trackerConfig = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    
    [trackerConfig setValue:[object trackerConfig] forKey:_appIdentifier];
    [defaults setValue:trackerConfig forKey:@"BITTrackerConfigurations"];
    
    [defaults synchronize];
    [self configureJMC];
#endif /* HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT */
  }
}
#endif /* HOCKEYSDK_FEATURE_UPDATES */


#pragma mark - Private Instance Methods

- (void)validateStartManagerIsInvoked {
  if (_validAppIdentifier && !_appStoreEnvironment) {
    if (!_startManagerIsInvoked) {
      NSLog(@"[HockeySDK] ERROR: You did not call [[BITHockeyManager sharedHockeyManager] startManager] to startup the HockeySDK! Please do so after setting up all properties. The SDK is NOT running.");
    }
  }
}

#if HOCKEYSDK_FEATURE_UPDATES
- (void)invokeStartUpdateManager {
  if (_startUpdateManagerIsInvoked) return;
  
  _startUpdateManagerIsInvoked = YES;
  BITHockeyLog(@"INFO: Start UpdateManager");
  if (_serverURL) {
    [_updateManager setServerURL:_serverURL];
  }
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  if (_authenticator) {
    [_updateManager setInstallationIdentification:[self.authenticator installationIdentifier]];
    [_updateManager setInstallationIdentificationType:[self.authenticator installationIdentifierParameterString]];
    [_updateManager setInstallationIdentified:[self.authenticator isIdentified]];
  }
#endif
  [_updateManager performSelector:@selector(startManager) withObject:nil afterDelay:0.5f];
}
#endif /* HOCKEYSDK_FEATURE_UPDATES */

- (BOOL)isSetUpOnMainThread {
  NSString *errorString = @"ERROR: This SDK has to be setup on the main thread!";
  
  if (!NSThread.isMainThread) {
    if (self.isAppStoreEnvironment) {
      BITHockeyLog(@"%@", errorString);
    } else {
      NSAssert(NSThread.isMainThread, errorString);
    }
    
    return NO;
  }
  
  return YES;
}

- (BOOL)shouldUseLiveIdentifier {
  BOOL delegateResult = NO;
  if ([_delegate respondsToSelector:@selector(shouldUseLiveIdentifierForHockeyManager:)]) {
    delegateResult = [(NSObject <BITHockeyManagerDelegate>*)_delegate shouldUseLiveIdentifierForHockeyManager:self];
  }

  return (delegateResult) || (_appStoreEnvironment);
}

- (void)initializeModules {
  _validAppIdentifier = [self checkValidityOfAppIdentifier:_appIdentifier];
  
  if (![self isSetUpOnMainThread]) return;
  
  _startManagerIsInvoked = NO;
  
  if (_validAppIdentifier) {
#if HOCKEYSDK_FEATURE_CRASH_REPORTER
    BITHockeyLog(@"INFO: Setup CrashManager");
    _crashManager = [[BITCrashManager alloc] initWithAppIdentifier:_appIdentifier isAppStoreEnvironment:_appStoreEnvironment];
    _crashManager.delegate = _delegate;
#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */
    
#if HOCKEYSDK_FEATURE_UPDATES
    BITHockeyLog(@"INFO: Setup UpdateManager");
    _updateManager = [[BITUpdateManager alloc] initWithAppIdentifier:_appIdentifier isAppStoreEnvironment:_appStoreEnvironment];
    _updateManager.delegate = _delegate;
#endif /* HOCKEYSDK_FEATURE_UPDATES */

#if HOCKEYSDK_FEATURE_STORE_UPDATES
    BITHockeyLog(@"INFO: Setup StoreUpdateManager");
    _storeUpdateManager = [[BITStoreUpdateManager alloc] initWithAppIdentifier:_appIdentifier isAppStoreEnvironment:_appStoreEnvironment];
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */
    
#if HOCKEYSDK_FEATURE_FEEDBACK
    BITHockeyLog(@"INFO: Setup FeedbackManager");
    _feedbackManager = [[BITFeedbackManager alloc] initWithAppIdentifier:_appIdentifier isAppStoreEnvironment:_appStoreEnvironment];
    _feedbackManager.delegate = _delegate;
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */

#if HOCKEYSDK_FEATURE_AUTHENTICATOR
    BITHockeyLog(@"INFO: Setup Authenticator");
    BITHockeyAppClient *client = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:_serverURL ? _serverURL : BITHOCKEYSDK_URL]];
    _authenticator = [[BITAuthenticator alloc] initWithAppIdentifier:_appIdentifier isAppStoreEnvironment:_appStoreEnvironment];
    _authenticator.hockeyAppClient = client;
    _authenticator.delegate = _delegate;
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */

#if HOCKEYSDK_FEATURE_UPDATES
    
#if HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT
    // Only if JMC is part of the project
    if ([[self class] isJMCPresent]) {
      BITHockeyLog(@"INFO: Setup JMC");
      [_updateManager setCheckForTracker:YES];
      [_updateManager addObserver:self forKeyPath:@"trackerConfig" options:0 context:nil];
      [[self class] disableJMCCrashReporter];
      [self performSelector:@selector(configureJMC) withObject:nil afterDelay:0];
    }
#endif /* HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT */

#endif /* HOCKEYSDK_FEATURE_UPDATES */

  } else {
    [self logInvalidIdentifier:@"app identifier"];
  }
}

#if HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT

#pragma mark - JMC

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
+ (id)jmcInstance {
  id jmcClass = NSClassFromString(@"JMC");
  if ((jmcClass) && ([jmcClass respondsToSelector:@selector(sharedInstance)])) {
    return [jmcClass performSelector:@selector(sharedInstance)];
  }
#ifdef JMC_LEGACY
  else if ((jmcClass) && ([jmcClass respondsToSelector:@selector(instance)])) {
    return [jmcClass performSelector:@selector(instance)]; // legacy pre (JMC 1.0.11) support
  }
#endif
  
  return nil;
}
#pragma clang diagnostic pop

+ (BOOL)isJMCActive {
  id jmcInstance = [self jmcInstance];
  return (jmcInstance) && ([jmcInstance performSelector:@selector(url)]);
}

+ (BOOL)isJMCPresent {
  return [self jmcInstance] != nil;
}

#pragma mark - Private Class Methods

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
+ (void)disableJMCCrashReporter {
  id jmcInstance = [self jmcInstance];
  SEL optionsSelector = @selector(options);
  id jmcOptions = [jmcInstance performSelector:optionsSelector];
  SEL crashReporterSelector = @selector(setCrashReportingEnabled:);
  
  BOOL value = NO;
  
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jmcOptions methodSignatureForSelector:crashReporterSelector]];
  invocation.target = jmcOptions;
  invocation.selector = crashReporterSelector;
  [invocation setArgument:&value atIndex:2];
  [invocation invoke];
}
#pragma clang diagnostic pop

+ (BOOL)checkJMCConfiguration:(NSDictionary *)configuration {
  return (([configuration isKindOfClass:[NSDictionary class]]) &&
          ([[configuration valueForKey:@"enabled"] boolValue]) &&
          ([(NSString *)[configuration valueForKey:@"url"] length] > 0) &&
          ([(NSString *)[configuration valueForKey:@"key"] length] > 0) &&
          ([(NSString *)[configuration valueForKey:@"project"] length] > 0));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
+ (void)applyJMCConfiguration:(NSDictionary *)configuration {
  id jmcInstance = [self jmcInstance];
  SEL configureSelector = @selector(configureJiraConnect:projectKey:apiKey:);
  
  __unsafe_unretained NSString *url = [configuration valueForKey:@"url"];
  __unsafe_unretained NSString *project = [configuration valueForKey:@"project"];
  __unsafe_unretained NSString *key = [configuration valueForKey:@"key"];
  
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jmcInstance methodSignatureForSelector:configureSelector]];
  invocation.target = jmcInstance;
  invocation.selector = configureSelector;
  [invocation setArgument:&url atIndex:2];
  [invocation setArgument:&project atIndex:3];
  [invocation setArgument:&key atIndex:4];
  [invocation invoke];
  
  SEL pingSelector = NSSelectorFromString(@"ping");
  if ([jmcInstance respondsToSelector:pingSelector]) {
    [jmcInstance performSelector:pingSelector];
  }
}
#pragma clang diagnostic pop

- (void)configureJMC {
  // Return if JMC is already configured
  if ([[self class] isJMCActive]) {
    return;
  }
  
  // Configure JMC from user defaults
  NSDictionary *configurations = [[NSUserDefaults standardUserDefaults] valueForKey:@"BITTrackerConfigurations"];
  NSDictionary *configuration = [configurations valueForKey:_appIdentifier];
  if ([[self class] checkJMCConfiguration:configuration]) {
    [[self class] applyJMCConfiguration:configuration];
  }
}

#endif /* HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT */

@end
