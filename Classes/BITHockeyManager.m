/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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

#if HOCKEYSDK_FEATURE_CRASH_REPORTER || HOCKEYSDK_FEATURE_FEEDBACK || HOCKEYSDK_FEATURE_UPDATES || HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_STORE_UPDATES || HOCKEYSDK_FEATURE_METRICS
#import "BITHockeyBaseManagerPrivate.h"
#endif

#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"
#import "BITKeychainUtils.h"

#include <stdint.h>

typedef struct {
  uint8_t       info_version;
  const char    hockey_version[16];
  const char    hockey_build[16];
} bitstadium_info_t;

static bitstadium_info_t bitstadium_library_info __attribute__((section("__TEXT,__bit_hockey,regular,no_dead_strip"))) = {
  .info_version = 1,
  .hockey_version = BITHOCKEY_C_VERSION,
  .hockey_build = BITHOCKEY_C_BUILD
};

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
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */

#if HOCKEYSDK_FEATURE_METRICS
#import "BITMetricsManagerPrivate.h"
#import "BITCategoryContainer.h"
#endif /* HOCKEYSDK_FEATURE_METRICS */

@interface BITHockeyManager ()

- (BOOL)shouldUseLiveIdentifier;

@property (nonatomic, copy) NSString *appIdentifier;
@property (nonatomic, copy) NSString *liveIdentifier;
@property (nonatomic) BOOL validAppIdentifier;
@property (nonatomic) BOOL startManagerIsInvoked;
@property (nonatomic) BOOL startUpdateManagerIsInvoked;
@property (nonatomic) BOOL managersInitialized;
@property (nonatomic, strong) BITHockeyAppClient *hockeyAppClient;

// Redeclare BITHockeyManager properties with readwrite attribute.
@property (nonatomic, readwrite) NSString *installString;

#if HOCKEYSDK_FEATURE_CRASH_REPORTER
@property (nonatomic, strong, readwrite) BITCrashManager *crashManager;
#endif

#if HOCKEYSDK_FEATURE_UPDATES
@property (nonatomic, strong, readwrite) BITUpdateManager *updateManager;
#endif

#if HOCKEYSDK_FEATURE_STORE_UPDATES
@property (nonatomic, strong, readwrite) BITStoreUpdateManager *storeUpdateManager;
#endif

#if HOCKEYSDK_FEATURE_FEEDBACK
@property (nonatomic, strong, readwrite) BITFeedbackManager *feedbackManager;
#endif

#if HOCKEYSDK_FEATURE_AUTHENTICATOR
@property (nonatomic, strong, readwrite) BITAuthenticator *authenticator;
#endif

#if HOCKEYSDK_FEATURE_METRICS
@property (nonatomic, strong, readwrite) BITMetricsManager *metricsManager;
#endif


@end


@implementation BITHockeyManager

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
  if (self.appEnvironment != BITEnvironmentAppStore) {
    if ([environment isEqualToString:@"liveIdentifier"]) {
      BITHockeyLogWarning(@"[HockeySDK] WARNING: The liveIdentifier is invalid! The SDK will be disabled when deployed to the App Store without setting a valid app identifier!");
    } else {
      BITHockeyLogError(@"[HockeySDK] ERROR: The %@ is invalid! Please use the HockeyApp app identifier you find on the apps website on HockeyApp! The SDK is disabled!", environment);
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

- (instancetype)init {
  if ((self = [super init])) {
    _serverURL = BITHOCKEYSDK_URL;
    _delegate = nil;
    _managersInitialized = NO;
    
    _hockeyAppClient = nil;
    
#if HOCKEYSDK_FEATURE_CRASH_REPORTER
    _disableCrashManager = NO;
#endif
#if HOCKEYSDK_FEATURE_METRICS
    _disableMetricsManager = NO;
#endif
#if HOCKEYSDK_FEATURE_FEEDBACK
    _disableFeedbackManager = NO;
#endif
#if HOCKEYSDK_FEATURE_UPDATES
    _disableUpdateManager = NO;
#endif
#if HOCKEYSDK_FEATURE_STORE_UPDATES
    _enableStoreUpdateManager = NO;
#endif
    
    _appEnvironment = bit_currentAppEnvironment();
    _startManagerIsInvoked = NO;
    _startUpdateManagerIsInvoked = NO;
    
    _liveIdentifier = nil;
    _installString = bit_appAnonID(NO);
    _disableInstallTracking = NO;
    
    [self performSelector:@selector(validateStartManagerIsInvoked) withObject:nil afterDelay:0.0];
  }
  return self;
}

- (void)dealloc {
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  // start Authenticator
  if (self.appEnvironment != BITEnvironmentAppStore) {
    [self.authenticator removeObserver:self forKeyPath:@"identified"];
  }
#endif
}


#pragma mark - Public Instance Methods (Configuration)

- (void)configureWithIdentifier:(NSString *)appIdentifier {
  self.appIdentifier = [appIdentifier copy];
  
  [self initializeModules];
}

- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id<BITHockeyManagerDelegate>)delegate {
  self.delegate = delegate;
  self.appIdentifier = [appIdentifier copy];
  
  [self initializeModules];
}

- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id<BITHockeyManagerDelegate>)delegate {
  self.delegate = delegate;

  // check the live identifier now, because otherwise invalid identifier would only be logged when the app is already in the store
  if (![self checkValidityOfAppIdentifier:liveIdentifier]) {
    [self logInvalidIdentifier:@"liveIdentifier"];
    self.liveIdentifier = [liveIdentifier copy];
  }

  if ([self shouldUseLiveIdentifier]) {
    self.appIdentifier = [liveIdentifier copy];
  }
  else {
    self.appIdentifier = [betaIdentifier copy];
  }
  
  [self initializeModules];
}

- (void)startManager {
  if (!self.validAppIdentifier) return;
  if (self.startManagerIsInvoked) {
    BITHockeyLogWarning(@"[HockeySDK] Warning: startManager should only be invoked once! This call is ignored.");
    return;
  }
  
  // Fix bug where Application Support directory was encluded from backup
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
  bit_fixBackupAttributeForURL(appSupportURL);
  
  if (![self isSetUpOnMainThread]) return;
  
  if ((self.appEnvironment == BITEnvironmentAppStore) && [self isInstallTrackingDisabled]) {
    self.installString = bit_appAnonID(YES);
  }

  BITHockeyLogDebug(@"INFO: Starting HockeyManager");
  self.startManagerIsInvoked = YES;
  
#if HOCKEYSDK_FEATURE_CRASH_REPORTER
  // start CrashManager
  if (![self isCrashManagerDisabled]) {
    BITHockeyLogDebug(@"INFO: Start CrashManager");
    
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
    if (self.authenticator) {
      [self.crashManager setInstallationIdentification:[self.authenticator publicInstallationIdentifier]];
      [self.crashManager setInstallationIdentificationType:[self.authenticator identificationType]];
      [self.crashManager setInstallationIdentified:[self.authenticator isIdentified]];
    }
#endif

    [self.crashManager startManager];
  }
#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */

#if HOCKEYSDK_FEATURE_METRICS
  // start MetricsManager
  if (!self.isMetricsManagerDisabled) {
    BITHockeyLogDebug(@"INFO: Start MetricsManager");
    [self.metricsManager startManager];
    [BITCategoryContainer activateCategory];
  }
#endif /* HOCKEYSDK_FEATURE_METRICS */

  // App Extensions can only use BITCrashManager and BITMetricsManager, so ignore all others automatically
  if (bit_isRunningInAppExtension()) {
    return;
  }
  
#if HOCKEYSDK_FEATURE_STORE_UPDATES
  // start StoreUpdateManager
  if ([self isStoreUpdateManagerEnabled]) {
    BITHockeyLogDebug(@"INFO: Start StoreUpdateManager");
    if (self.serverURL) {
      [self.storeUpdateManager setServerURL:self.serverURL];
    }
    [self.storeUpdateManager performSelector:@selector(startManager) withObject:nil afterDelay:0.5];
  }
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */

#if HOCKEYSDK_FEATURE_FEEDBACK
  // start FeedbackManager
  if (![self isFeedbackManagerDisabled]) {
    BITHockeyLogDebug(@"INFO: Start FeedbackManager");
    if (self.serverURL) {
      [self.feedbackManager setServerURL:self.serverURL];
    }
    [self.feedbackManager performSelector:@selector(startManager) withObject:nil afterDelay:1.0];
  }
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
  
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  // start Authenticator
  if (self.appEnvironment != BITEnvironmentAppStore) {
    // hook into manager with kvo!
    [self.authenticator addObserver:self forKeyPath:@"identified" options:0 context:nil];
    
    BITHockeyLogDebug(@"INFO: Start Authenticator");
    if (self.serverURL) {
      [self.authenticator setServerURL:self.serverURL];
    }
    [self.authenticator performSelector:@selector(startManager) withObject:nil afterDelay:0.5];
  }
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
  
#if HOCKEYSDK_FEATURE_UPDATES
  BOOL isIdentified = NO;

#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  if (self.appEnvironment != BITEnvironmentAppStore)
    isIdentified = [self.authenticator isIdentified];
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */

  // Setup UpdateManager
  if (![self isUpdateManagerDisabled] && isIdentified) {
    [self invokeStartUpdateManager];
  }
#endif /* HOCKEYSDK_FEATURE_UPDATES */
}

#if HOCKEYSDK_FEATURE_UPDATES
- (void)setDisableUpdateManager:(BOOL)disableUpdateManager {
  if (self.updateManager) {
    [self.updateManager setDisableUpdateManager:disableUpdateManager];
  }
  _disableUpdateManager = disableUpdateManager;
}
#endif /* HOCKEYSDK_FEATURE_UPDATES */


#if HOCKEYSDK_FEATURE_STORE_UPDATES
- (void)setEnableStoreUpdateManager:(BOOL)enableStoreUpdateManager {
  if (self.storeUpdateManager) {
    [self.storeUpdateManager setEnableStoreUpdateManager:enableStoreUpdateManager];
  }
  _enableStoreUpdateManager = enableStoreUpdateManager;
}
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */


#if HOCKEYSDK_FEATURE_FEEDBACK
- (void)setDisableFeedbackManager:(BOOL)disableFeedbackManager {
  if (self.feedbackManager) {
    [self.feedbackManager setDisableFeedbackManager:disableFeedbackManager];
  }
  _disableFeedbackManager = disableFeedbackManager;
}
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */

#if HOCKEYSDK_FEATURE_METRICS
- (void)setDisableMetricsManager:(BOOL)disableMetricsManager {
  if (self.metricsManager) {
    self.metricsManager.disabled = disableMetricsManager;
  }
  _disableMetricsManager = disableMetricsManager;
}
#endif /* HOCKEYSDK_FEATURE_METRICS */

- (void)setServerURL:(NSString *)aServerURL {
  // ensure url ends with a trailing slash
  if (![aServerURL hasSuffix:@"/"]) {
    aServerURL = [NSString stringWithFormat:@"%@/", aServerURL];
  }
  
  if (self.serverURL != aServerURL) {
    _serverURL = [aServerURL copy];
    
    if (self.hockeyAppClient) {
      self.hockeyAppClient.baseURL = [NSURL URLWithString:self.serverURL ?: BITHOCKEYSDK_URL];
    }
  }
}


- (void)setDelegate:(id<BITHockeyManagerDelegate>)delegate {
  if (self.appEnvironment != BITEnvironmentAppStore) {
    if (self.startManagerIsInvoked) {
      BITHockeyLogError(@"[HockeySDK] ERROR: The `delegate` property has to be set before calling [[BITHockeyManager sharedHockeyManager] startManager] !");
    }
  }

  if (_delegate != delegate) {
    _delegate = delegate;
    id<BITHockeyManagerDelegate> currentDelegate = _delegate;
    
#if HOCKEYSDK_FEATURE_CRASH_REPORTER
    if (self.crashManager) {
      self.crashManager.delegate = currentDelegate;
    }
#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */
    
#if HOCKEYSDK_FEATURE_UPDATES
    if (self.updateManager) {
      self.updateManager.delegate = currentDelegate;
    }
#endif /* HOCKEYSDK_FEATURE_UPDATES */
    
#if HOCKEYSDK_FEATURE_FEEDBACK
    if (self.feedbackManager) {
      self.feedbackManager.delegate = currentDelegate;
    }
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
    
#if HOCKEYSDK_FEATURE_STORE_UPDATES
    if (self.storeUpdateManager) {
      self.storeUpdateManager.delegate = currentDelegate;
    }
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */

#if HOCKEYSDK_FEATURE_AUTHENTICATOR
    if (self.authenticator) {
      self.authenticator.delegate = currentDelegate;
    }
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
  }
}

- (void)setDebugLogEnabled:(BOOL)debugLogEnabled {
  _debugLogEnabled = debugLogEnabled;
  if (debugLogEnabled) {
    self.logLevel = BITLogLevelDebug;
  } else {
    self.logLevel = BITLogLevelWarning;
  }
}

- (BITLogLevel)logLevel {
  return BITHockeyLogger.currentLogLevel;
}

- (void)setLogLevel:(BITLogLevel)logLevel {
  BITHockeyLogger.currentLogLevel = logLevel;
}

- (void)setLogHandler:(BITLogHandler)logHandler {
  [BITHockeyLogger setLogHandler:logHandler];
}

- (void)modifyKeychainUserValue:(NSString *)value forKey:(NSString *)key {
  NSError *error = nil;
  BOOL success = YES;
  NSString *updateType = @"update";
  
  if (value) {
    success = [BITKeychainUtils storeUsername:key
                                  andPassword:value
                               forServiceName:bit_keychainHockeySDKServiceName()
                               updateExisting:YES
                                accessibility:kSecAttrAccessibleAlwaysThisDeviceOnly
                                        error:&error];
  } else {
    updateType = @"delete";
    if ([BITKeychainUtils getPasswordForUsername:key
                                  andServiceName:bit_keychainHockeySDKServiceName()
                                           error:&error]) {
      success = [BITKeychainUtils deleteItemForUsername:key
                                         andServiceName:bit_keychainHockeySDKServiceName()
                                                  error:&error];
    }
  }
  
  if (!success) {
    NSString *errorDescription = [error description] ?: @"";
    BITHockeyLogError(@"ERROR: Couldn't %@ key %@ in the keychain. %@", updateType, key, errorDescription);
  }
}

- (void)setUserID:(NSString *)userID {
  // always set it, since nil value will trigger removal of the keychain entry
  _userID = userID;
  
  [self modifyKeychainUserValue:userID forKey:kBITHockeyMetaUserID];
}

- (void)setUserName:(NSString *)userName {
  // always set it, since nil value will trigger removal of the keychain entry
  _userName = userName;
  
  [self modifyKeychainUserValue:userName forKey:kBITHockeyMetaUserName];
}

- (void)setUserEmail:(NSString *)userEmail {
  // always set it, since nil value will trigger removal of the keychain entry
  _userEmail = userEmail;
  
  [self modifyKeychainUserValue:userEmail forKey:kBITHockeyMetaUserEmail];
}

- (void)testIdentifier {
  if (!self.appIdentifier || (self.appEnvironment == BITEnvironmentAppStore)) {
    return;
  }
  
  NSDate *now = [NSDate date];
  NSString *timeString = [NSString stringWithFormat:@"%.0f", [now timeIntervalSince1970]];
  [self pingServerForIntegrationStartWorkflowWithTimeString:timeString appIdentifier:self.appIdentifier];
  
  if (self.liveIdentifier) {
    [self pingServerForIntegrationStartWorkflowWithTimeString:timeString appIdentifier:self.liveIdentifier];
  }
}


- (NSString *)version {
  return (NSString *)[NSString stringWithUTF8String:bitstadium_library_info.hockey_version];
}

- (NSString *)build {
  return (NSString *)[NSString stringWithUTF8String:bitstadium_library_info.hockey_build];
}


#pragma mark - KVO

#if HOCKEYSDK_FEATURE_UPDATES
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *) __unused change context:(void *) __unused context {
  if ([keyPath isEqualToString:@"identified"] &&
      [object valueForKey:@"isIdentified"] ) {
    if (self.appEnvironment != BITEnvironmentAppStore) {
      BOOL identified = [(NSNumber *)[object valueForKey:@"isIdentified"] boolValue];
      if (identified && ![self isUpdateManagerDisabled]) {
        [self invokeStartUpdateManager];
      }
    }
  }
}
#endif /* HOCKEYSDK_FEATURE_UPDATES */


#pragma mark - Private Instance Methods

- (BITHockeyAppClient *)hockeyAppClient {
  if (!_hockeyAppClient) {
    _hockeyAppClient = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:self.serverURL]];
  }
  return _hockeyAppClient;
}

- (NSString *)integrationFlowTimeString {
  NSString *timeString = [[NSBundle mainBundle] objectForInfoDictionaryKey:BITHOCKEY_INTEGRATIONFLOW_TIMESTAMP];
  
  return timeString;
}

- (BOOL)integrationFlowStartedWithTimeString:(NSString *)timeString {
  if (timeString == nil || (self.appEnvironment == BITEnvironmentAppStore)) {
    return NO;
  }
  
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
  [dateFormatter setLocale:enUSPOSIXLocale];
  [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
  NSDate *integrationFlowStartDate = [dateFormatter dateFromString:timeString];
  
  if (integrationFlowStartDate && [integrationFlowStartDate timeIntervalSince1970] > [[NSDate date] timeIntervalSince1970] - (60 * 10) ) {
    return YES;
  }
  
  return NO;
}

- (void)pingServerForIntegrationStartWorkflowWithTimeString:(NSString *)timeString appIdentifier:(NSString *)appIdentifier {
  if (!appIdentifier || (self.appEnvironment == BITEnvironmentAppStore)) {
    return;
  }
  
  NSString *integrationPath = [NSString stringWithFormat:@"api/3/apps/%@/integration", bit_encodeAppIdentifier(appIdentifier)];
  
  BITHockeyLogDebug(@"INFO: Sending integration workflow ping to %@", integrationPath);
  
  NSDictionary *params = @{@"timestamp": timeString,
                           @"sdk": BITHOCKEY_NAME,
                           @"sdk_version": BITHOCKEY_VERSION,
                           @"bundle_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
                           };
  
  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
  NSURLRequest *request = [[self hockeyAppClient] requestWithMethod:@"POST" path:integrationPath parameters:params];
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler: ^(NSData * __unused data, NSURLResponse *response, NSError * __unused error) {
                                            [session finishTasksAndInvalidate];

                                            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
                                            [self logPingMessageForStatusCode:httpResponse.statusCode];
                                          }];
  [task resume];

}

- (void)logPingMessageForStatusCode:(NSInteger)statusCode {
  switch (statusCode) {
    case 400:
      BITHockeyLogError(@"ERROR: App ID not found");
      break;
    case 201:
      BITHockeyLogDebug(@"INFO: Ping accepted.");
      break;
    case 200:
      BITHockeyLogDebug(@"INFO: Ping accepted. Server already knows.");
      break;
    default:
      BITHockeyLogError(@"ERROR: Unknown error");
      break;
  }
}

- (void)validateStartManagerIsInvoked {
  if (self.validAppIdentifier && (self.appEnvironment != BITEnvironmentAppStore)) {
    if (!self.startManagerIsInvoked) {
      BITHockeyLogError(@"[HockeySDK] ERROR: You did not call [[BITHockeyManager sharedHockeyManager] startManager] to startup the HockeySDK! Please do so after setting up all properties. The SDK is NOT running.");
    }
  }
}

#if HOCKEYSDK_FEATURE_UPDATES
- (void)invokeStartUpdateManager {
  if (self.startUpdateManagerIsInvoked) return;
  
  self.startUpdateManagerIsInvoked = YES;
  BITHockeyLogDebug(@"INFO: Start UpdateManager");
  if (self.serverURL) {
    [self.updateManager setServerURL:self.serverURL];
  }
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  if (self.authenticator) {
    [self.updateManager setInstallationIdentification:[self.authenticator installationIdentifier]];
    [self.updateManager setInstallationIdentificationType:[self.authenticator installationIdentifierParameterString]];
    [self.updateManager setInstallationIdentified:[self.authenticator isIdentified]];
  }
#endif
  [self.updateManager performSelector:@selector(startManager) withObject:nil afterDelay:0.5];
}
#endif /* HOCKEYSDK_FEATURE_UPDATES */

- (BOOL)isSetUpOnMainThread {
  NSString *errorString = @"ERROR: HockeySDK has to be setup on the main thread!";
  
  if (!NSThread.isMainThread) {
    if (self.appEnvironment == BITEnvironmentAppStore) {
      BITHockeyLogError(@"%@", errorString);
    } else {
      BITHockeyLogError(@"%@", errorString);
      NSAssert(NSThread.isMainThread, errorString);
    }
    
    return NO;
  }
  
  return YES;
}

- (BOOL)shouldUseLiveIdentifier {
  BOOL delegateResult = NO;
  id<BITHockeyManagerDelegate> currentDelegate = self.delegate;
  if ([currentDelegate respondsToSelector:@selector(shouldUseLiveIdentifierForHockeyManager:)]) {
    delegateResult = [currentDelegate shouldUseLiveIdentifierForHockeyManager:self];
  }

  return (delegateResult) || (self.appEnvironment == BITEnvironmentAppStore);
}

- (void)initializeModules {
  if (self.managersInitialized) {
    BITHockeyLogWarning(@"[HockeySDK] Warning: The SDK should only be initialized once! This call is ignored.");
    return;
  }
  
  self.validAppIdentifier = [self checkValidityOfAppIdentifier:self.appIdentifier];
  
  if (![self isSetUpOnMainThread]) return;
  
  self.startManagerIsInvoked = NO;
  
  if (self.validAppIdentifier) {
#if HOCKEYSDK_FEATURE_CRASH_REPORTER
    BITHockeyLogDebug(@"INFO: Setup CrashManager");
    id<BITHockeyManagerDelegate> currentDelegate = self.delegate;
    self.crashManager = [[BITCrashManager alloc] initWithAppIdentifier:self.appIdentifier
                                                    appEnvironment:self.appEnvironment
                                                   hockeyAppClient:[self hockeyAppClient]];
    self.crashManager.delegate = currentDelegate;
#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */
    
#if HOCKEYSDK_FEATURE_UPDATES
    BITHockeyLogDebug(@"INFO: Setup UpdateManager");
    self.updateManager = [[BITUpdateManager alloc] initWithAppIdentifier:self.appIdentifier appEnvironment:self.appEnvironment];
    self.updateManager.delegate = currentDelegate;
#endif /* HOCKEYSDK_FEATURE_UPDATES */

#if HOCKEYSDK_FEATURE_STORE_UPDATES
    BITHockeyLogDebug(@"INFO: Setup StoreUpdateManager");
    self.storeUpdateManager = [[BITStoreUpdateManager alloc] initWithAppIdentifier:self.appIdentifier appEnvironment:self.appEnvironment];
    self.storeUpdateManager.delegate = currentDelegate;
#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */
    
#if HOCKEYSDK_FEATURE_FEEDBACK
    BITHockeyLogDebug(@"INFO: Setup FeedbackManager");
    self.feedbackManager = [[BITFeedbackManager alloc] initWithAppIdentifier:self.appIdentifier appEnvironment:self.appEnvironment];
    self.feedbackManager.delegate = currentDelegate;
#endif /* HOCKEYSDK_FEATURE_FEEDBACK */

#if HOCKEYSDK_FEATURE_AUTHENTICATOR
    BITHockeyLogDebug(@"INFO: Setup Authenticator");
    self.authenticator = [[BITAuthenticator alloc] initWithAppIdentifier:self.appIdentifier appEnvironment:self.appEnvironment];
    self.authenticator.hockeyAppClient = [self hockeyAppClient];
    self.authenticator.delegate = currentDelegate;
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
    
#if HOCKEYSDK_FEATURE_METRICS
    BITHockeyLogDebug(@"INFO: Setup MetricsManager");
    NSString *iKey = bit_appIdentifierToGuid(self.appIdentifier);
    self.metricsManager = [[BITMetricsManager alloc] initWithAppIdentifier:iKey appEnvironment:self.appEnvironment];
#endif /* HOCKEYSDK_FEATURE_METRICS */

    if (self.appEnvironment != BITEnvironmentAppStore) {
      NSString *integrationFlowTime = [self integrationFlowTimeString];
      if (integrationFlowTime && [self integrationFlowStartedWithTimeString:integrationFlowTime]) {
        [self pingServerForIntegrationStartWorkflowWithTimeString:integrationFlowTime appIdentifier:self.appIdentifier];
      }
    }
    self.managersInitialized = YES;
  } else {
    [self logInvalidIdentifier:@"app identifier"];
  }
}

@end
