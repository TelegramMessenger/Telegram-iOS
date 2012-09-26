/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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

#import "BITCrashManagerPrivate.h"
#import "BITUpdateManagerPrivate.h"


@interface BITHockeyManager ()

- (BOOL)shouldUseLiveIdentifier;

#if JIRA_MOBILE_CONNECT_SUPPORT_ENABLED
- (void)configureJMC;
#endif

@end

@implementation BITHockeyManager

@synthesize crashManager = _crashManager;
@synthesize updateManager = _updateManager;

@synthesize appStoreEnvironment = _appStoreEnvironment;

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
    NSLog(@"[HockeySDK] ERROR: The %@ is invalid! Please use the HockeyApp app identifier you find on the apps website on HockeyApp! The SDK is disabled!", environment);
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
    _updateURL = nil;
    _delegate = nil;
    
    _disableCrashManager = NO;
    _disableUpdateManager = NO;
    
    _appStoreEnvironment = NO;
    _startManagerIsInvoked = NO;

    // check if we are really not in an app store environment
    if ([[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]) {
      _appStoreEnvironment = NO;
    } else {
      _appStoreEnvironment = YES;
    }
    
#if TARGET_IPHONE_SIMULATOR
    _appStoreEnvironment = NO;
#endif

    [self performSelector:@selector(validateStartManagerIsInvoked) withObject:nil afterDelay:0.0f];
  }
  return self;
}

- (void)dealloc {
  [_appIdentifier release], _appIdentifier = nil;
  
  [_crashManager release], _crashManager = nil;
  [_updateManager release], _updateManager = nil;
  
  _delegate = nil;
  
  [super dealloc];
}


#pragma mark - Public Instance Methods (Configuration)

- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id)delegate {
  _delegate = delegate;
  [_appIdentifier release];
  _appIdentifier = [appIdentifier copy];
  
  [self initializeModules];
}

- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id)delegate {
  _delegate = delegate;
  [_appIdentifier release];

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
  
  BITHockeyLog(@"INFO: Starting HockeyManager");
  _startManagerIsInvoked = YES;
  
  // start CrashManager
  if (![self isCrashManagerDisabled]) {
    BITHockeyLog(@"INFO: Start CrashManager");
    if (_updateURL) {
      [_crashManager setUpdateURL:_updateURL];
    }
    [_crashManager startManager];
  }
  
  // Setup UpdateManager
  if (![self isUpdateManagerDisabled]
#if JIRA_MOBILE_CONNECT_SUPPORT_ENABLED
      || [[self class] isJMCPresent]
#endif
      ) {
    BITHockeyLog(@"INFO: Start UpdateManager with small delay");
    if (_updateURL) {
      [_updateManager setUpdateURL:_updateURL];
    }
    [_updateManager performSelector:@selector(startManager) withObject:nil afterDelay:0.5f];
  }
}


- (void)validateStartManagerIsInvoked {
  if (_validAppIdentifier && !_appStoreEnvironment) {
    if (!_startManagerIsInvoked) {
      NSLog(@"[HockeySDK] ERROR: You did not call [[BITHockeyManager sharedHockeyManager] startManager] to startup the HockeySDK! Please do so after setting up all properties. The SDK is NOT running.");
    }
  }
}


- (void)setDisableUpdateManager:(BOOL)disableUpdateManager {
  if (_updateManager) {
    [_updateManager setDisableUpdateManager:disableUpdateManager];
  }
  _disableUpdateManager = disableUpdateManager;
}


- (void)setUpdateURL:(NSString *)anUpdateURL {
  // ensure url ends with a trailing slash
  if (![anUpdateURL hasSuffix:@"/"]) {
    anUpdateURL = [NSString stringWithFormat:@"%@/", anUpdateURL];
  }
  
  if (_updateURL != anUpdateURL) {
    [_updateURL release];
    _updateURL = [anUpdateURL copy];
  }
}


#pragma mark - Private Instance Methods

- (BOOL)shouldUseLiveIdentifier {
  BOOL delegateResult = NO;
  if ([_delegate respondsToSelector:@selector(shouldUseLiveIdentifier)]) {
    delegateResult = [(NSObject <BITHockeyManagerDelegate>*)_delegate shouldUseLiveIdentifier];
  }

  return (delegateResult) || (_appStoreEnvironment);
}

- (void)initializeModules {
  _validAppIdentifier = [self checkValidityOfAppIdentifier:_appIdentifier];
  
  _startManagerIsInvoked = NO;
  
  if (_validAppIdentifier) {
    BITHockeyLog(@"INFO: Setup CrashManager");
    _crashManager = [[BITCrashManager alloc] initWithAppIdentifier:_appIdentifier];
    _crashManager.delegate = _delegate;
    
    BITHockeyLog(@"INFO: Setup UpdateManager");
    _updateManager = [[BITUpdateManager alloc] initWithAppIdentifier:_appIdentifier isAppStoreEnvironemt:_appStoreEnvironment];
    _updateManager.delegate = _delegate;
    
#if JIRA_MOBILE_CONNECT_SUPPORT_ENABLED
    // Only if JMC is part of the project
    if ([[self class] isJMCPresent]) {
      BITHockeyLog(@"INFO: Setup JMC");
      [_updateManager setCheckForTracker:YES];
      [_updateManager addObserver:self forKeyPath:@"trackerConfig" options:0 context:nil];
      [[self class] disableJMCCrashReporter];
      [self performSelector:@selector(configureJMC) withObject:nil afterDelay:0];
    }
#endif
    
  } else {
    [self logInvalidIdentifier:@"app identifier"];
  }
}

#if JIRA_MOBILE_CONNECT_SUPPORT_ENABLED

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
+ (void)disableJMCCrashReporter {
  id jmcInstance = [self jmcInstance];
  id jmcOptions = [jmcInstance performSelector:@selector(options)];
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
          ([[configuration valueForKey:@"url"] length] > 0) &&
          ([[configuration valueForKey:@"key"] length] > 0) &&
          ([[configuration valueForKey:@"project"] length] > 0));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
+ (void)applyJMCConfiguration:(NSDictionary *)configuration {
  id jmcInstance = [self jmcInstance];
  SEL configureSelector = @selector(configureJiraConnect:projectKey:apiKey:);
  
  NSString *url = [configuration valueForKey:@"url"];
  NSString *project = [configuration valueForKey:@"project"];
  NSString *key = [configuration valueForKey:@"key"];
  
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jmcInstance methodSignatureForSelector:configureSelector]];
  invocation.target = jmcInstance;
  invocation.selector = configureSelector;
  [invocation setArgument:&url atIndex:2];
  [invocation setArgument:&project atIndex:3];
  [invocation setArgument:&key atIndex:4];
  [invocation invoke];
  
  if ([jmcInstance respondsToSelector:@selector(ping)]) {
    [jmcInstance performSelector:@selector(ping)];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (([object trackerConfig]) && ([[object trackerConfig] isKindOfClass:[NSDictionary class]])) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *trackerConfig = [[defaults valueForKey:@"BITTrackerConfigurations"] mutableCopy];
    if (!trackerConfig) {
      trackerConfig = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
    }

    [trackerConfig setValue:[object trackerConfig] forKey:_appIdentifier];
    [defaults setValue:trackerConfig forKey:@"BITTrackerConfigurations"];
    [trackerConfig release];
    
    [defaults synchronize];
    [self configureJMC];
  }
}
#endif

@end
