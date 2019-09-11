/*
 * Author: Andreas Linde <mail@andreaslinde.de>
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

#if HOCKEYSDK_FEATURE_STORE_UPDATES

#import <sys/sysctl.h>

#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyHelper+Application.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITStoreUpdateManagerPrivate.h"

@interface BITStoreUpdateManager ()

@property (nonatomic, copy) NSString *latestStoreVersion;
@property (nonatomic, copy) NSString *appStoreURLString;
@property (nonatomic, copy) NSString *currentUUID;
@property (nonatomic) BOOL updateAlertShowing;
@property (nonatomic) BOOL lastCheckFailed;
@property (nonatomic, weak) id appDidBecomeActiveObserver;
@property (nonatomic, weak) id networkDidBecomeReachableObserver;

@end

@implementation BITStoreUpdateManager

#pragma mark - private

- (void)reportError:(NSError *)error {
  BITHockeyLogError(@"ERROR: %@", [error localizedDescription]);
  self.lastCheckFailed = YES;
}


- (void)didBecomeActiveActions {
  if ([self shouldCancelProcessing]) return;
  
  if ([self isCheckingForUpdateOnLaunch] && [self shouldAutoCheckForUpdates]) {
    [self performSelector:@selector(checkForUpdateDelayed) withObject:nil afterDelay:1.0];
  }
}

#pragma mark - Observers

- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  if(nil == self.appDidBecomeActiveObserver) {
    self.appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification __unused *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf didBecomeActiveActions];
                                                                                }];
  }
  if(nil == self.networkDidBecomeReachableObserver) {
    self.networkDidBecomeReachableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:BITHockeyNetworkDidBecomeReachableNotification
                                                                                     object:nil
                                                                                      queue:NSOperationQueue.mainQueue
                                                                                 usingBlock:^(NSNotification __unused *note) {
                                                                                   typeof(self) strongSelf = weakSelf;
                                                                                   [strongSelf didBecomeActiveActions];
                                                                                 }];
  }
}

- (void) unregisterObservers {
  id strongAppDidBecomeActiveObserver = self.appDidBecomeActiveObserver;
  id strongNetworkDidBecomeReachableObserver = self.networkDidBecomeReachableObserver;
  if(strongAppDidBecomeActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:strongAppDidBecomeActiveObserver];
    self.appDidBecomeActiveObserver = nil;
  }
  if(strongNetworkDidBecomeReachableObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:strongNetworkDidBecomeReachableObserver];
    self.networkDidBecomeReachableObserver = nil;
  }
}


#pragma mark - Init

- (instancetype)init {
  if ((self = [super init])) {
    _checkInProgress = NO;
    _updateAvailable = NO;
    _lastCheckFailed = NO;
    _enableStoreUpdateManager = NO;
    _updateAlertShowing = NO;
    _updateUIEnabled = YES;
    _latestStoreVersion = nil;
    _appStoreURLString = nil;
    _currentUUID = [[self executableUUID] copy];
    _countryCode = nil;
    
    _mainBundle = [NSBundle mainBundle];
    _currentLocale = [NSLocale currentLocale];
    _userDefaults = [NSUserDefaults standardUserDefaults];
    
    // set defaults
    self.checkForUpdateOnLaunch = YES;
    self.updateSetting = BITStoreUpdateCheckWeekly;

    if (!BITHockeyBundle()) {
      BITHockeyLogWarning(@"[HockeySDK] WARNING: %@ is missing, built in UI is deactivated!", BITHOCKEYSDK_BUNDLE);
    }
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
}


#pragma mark - Version

- (NSString *)lastStoreVersion {
  NSString *versionString = nil;
  
  if ([self.userDefaults objectForKey:kBITStoreUpdateLastStoreVersion]) {
    // get the last saved version string from the app store
    versionString = [self.userDefaults objectForKey:kBITStoreUpdateLastStoreVersion];
  }
  
  // if there is a UUID saved which doesn't match the current binary UUID
  // then there is possibly a newer version in the store
  NSString *lastSavedUUID = nil;
  if ([self.userDefaults objectForKey:kBITStoreUpdateLastUUID]) {
    lastSavedUUID = [self.userDefaults objectForKey:kBITStoreUpdateLastUUID];

    if (lastSavedUUID && [lastSavedUUID length] > 0 && ![lastSavedUUID isEqualToString:self.currentUUID]) {
      // the UUIDs don't match, store the new one
      [self.userDefaults setObject:self.currentUUID forKey:kBITStoreUpdateLastUUID];
      
      if (versionString) {
        // a new version has been installed, reset everything
        // so we set versionString to nil to simulate that this is the very run
        [self.userDefaults removeObjectForKey:kBITStoreUpdateLastStoreVersion];
        versionString = nil;
      }
    }
  }
  
  return versionString;
}

- (BOOL)hasNewVersion:(NSDictionary *)dictionary {
  self.lastCheckFailed = YES;
  
  NSString *lastStoreVersion = [self lastStoreVersion];
  
  if ([[dictionary objectForKey:@"results"] isKindOfClass:[NSArray class]] &&
      [(NSArray *)[dictionary objectForKey:@"results"] count] > 0 ) {
    self.lastCheckFailed = NO;

    self.latestStoreVersion = [(NSDictionary *)[(NSArray *)[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"version"];
    self.appStoreURLString = [(NSDictionary *)[(NSArray *)[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"trackViewUrl"];
    
    NSString *ignoredVersion = nil;
    if ([self.userDefaults objectForKey:kBITStoreUpdateIgnoreVersion]) {
      ignoredVersion = [self.userDefaults objectForKey:kBITStoreUpdateIgnoreVersion];
      BITHockeyLogDebug(@"INFO: Ignored version: %@", ignoredVersion);
    }
    
    if (!self.latestStoreVersion || !self.appStoreURLString) {
      return NO;
    } else if (ignoredVersion && [ignoredVersion isEqualToString:self.latestStoreVersion]) {
      return NO;
    } else if (!lastStoreVersion) {
      // this is the very first time we get a valid response and
      // set the reference of the store result to be equal to the current installed version
      // even though the current installed version could be older than the one in the app store
      // but this ensures that we never have false alerts, since the version string in
      // iTunes Connect doesn't have to match CFBundleVersion or CFBundleShortVersionString
      // and even if it matches it is hard/impossible to 100% determine which one it is,
      // since they could change at any time
      [self.userDefaults setObject:self.currentUUID forKey:kBITStoreUpdateLastUUID];
      [self.userDefaults setObject:self.latestStoreVersion forKey:kBITStoreUpdateLastStoreVersion];
      return NO;
    } else {
      BITHockeyLogDebug(@"INFO: Compare new version string %@ with %@", self.latestStoreVersion, lastStoreVersion);
      
      NSComparisonResult comparisonResult = bit_versionCompare(self.latestStoreVersion, lastStoreVersion);
      
      if (comparisonResult == NSOrderedDescending) {
        return YES;
      } else {
        return NO;
      }

    }
  }
  
  return NO;
}


#pragma mark - Time

- (BOOL)shouldAutoCheckForUpdates {
  BOOL checkForUpdate = NO;
  
  switch (self.updateSetting) {
    case BITStoreUpdateCheckDaily: {
      NSTimeInterval dateDiff = fabs([self.lastCheck timeIntervalSinceNow]);
      if (dateDiff != 0)
        dateDiff = dateDiff / (60*60*24);
      
      checkForUpdate = (dateDiff >= 1);
      break;
    }
    case BITStoreUpdateCheckWeekly: {
      NSTimeInterval dateDiff = fabs([self.lastCheck timeIntervalSinceNow]);
      if (dateDiff != 0)
        dateDiff = dateDiff / (60*60*24);
      
      checkForUpdate = (dateDiff >= 7);
      break;
    }
    case BITStoreUpdateCheckManually:
      checkForUpdate = NO;
      break;
    default:
      break;
  }
  
  return checkForUpdate;
}


#pragma mark - Private

- (BOOL)shouldCancelProcessing {
  if (self.appEnvironment != BITEnvironmentAppStore) {
    BITHockeyLogWarning(@"WARNING: StoreUpdateManager is cancelled because it's not running in an AppStore environment");
    return YES;
  }
  
  if (![self isStoreUpdateManagerEnabled]) {
    return YES;
  }
  
  return NO;
}


- (BOOL)processStoreResponseWithString:(NSString *)responseString {
  if (!responseString) return NO;
  
  NSData *data = [responseString dataUsingEncoding:NSUTF8StringEncoding];
  
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  
  if (error) {
    BITHockeyLogError(@"ERROR: Invalid JSON string. %@", [error localizedDescription]);
    return NO;
  }
  
  // remember that we just checked the server
  self.lastCheck = [NSDate date];
  
  self.updateAvailable = [self hasNewVersion:json];
  
  BITHockeyLogDebug(@"INFO: Update available: %i", self.updateAvailable);
  
  if (self.lastCheckFailed) {
    BITHockeyLogError(@"ERROR: Last check failed");
    return NO;
  }
  
  if ([self isUpdateAvailable]) {
    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(detectedUpdateFromStoreUpdateManager:newVersion:storeURL:)]) {
      [strongDelegate detectedUpdateFromStoreUpdateManager:self newVersion:self.latestStoreVersion storeURL:[NSURL URLWithString:self.appStoreURLString]];
    }
    
    if (self.updateUIEnabled && BITHockeyBundle()) {
      [self showUpdateAlert];
    } else {
      // Ignore this version
      [self.userDefaults setObject:self.latestStoreVersion forKey:kBITStoreUpdateIgnoreVersion];
    }
  }
  
  return YES;
}


#pragma mark - Update Check

- (void)checkForUpdateManual:(BOOL)manual {
  if ([self shouldCancelProcessing]) return;

  if (self.isCheckInProgress) return;
  self.checkInProgress = YES;
  
  // do we need to update?
  if (!manual && ![self shouldAutoCheckForUpdates]) {
    BITHockeyLogDebug(@"INFO: Update check not needed right now");
    self.checkInProgress = NO;
    return;
  }
  
  NSString *country = @"";
  if (self.countryCode) {
    country = [NSString stringWithFormat:@"&country=%@", self.countryCode];
  } else {
    // if the local is by any chance the systemLocale, it could happen that the NSLocaleCountryCode returns nil!
    if ([(NSDictionary *)self.currentLocale objectForKey:NSLocaleCountryCode]) {
      country = [NSString stringWithFormat:@"&country=%@", [(NSDictionary *)self.currentLocale objectForKey:NSLocaleCountryCode]];
    } else {
      // don't check, just to be save
      BITHockeyLogError(@"ERROR: Locale returned nil, can't determine the store to use!");
      self.checkInProgress = NO;
      return;
    }
  }
  
  NSString *appBundleIdentifier = [self.mainBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  
  NSString *url = [NSString stringWithFormat:@"https://itunes.apple.com/lookup?bundleId=%@%@",
                   bit_URLEncodedString(appBundleIdentifier),
                   country];
  
  BITHockeyLogDebug(@"INFO: Sending request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:(NSURL *)[NSURL URLWithString:url] cachePolicy:1 timeoutInterval:10.0];
  [request setHTTPMethod:@"GET"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  __weak typeof (self) weakSelf = self;
  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];

  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler: ^(NSData *data, NSURLResponse __unused *response, NSError *error) {
                                            typeof (self) strongSelf = weakSelf;

                                            [session finishTasksAndInvalidate];

                                            [strongSelf handleResponeWithData:data error:error];
                                          }];
  [task resume];
}

- (void)handleResponeWithData:(NSData *)responseData error:(NSError *)error{
  self.checkInProgress = NO;
  
  if (error) {
    [self reportError:error];
  } else if ([responseData length]) {
    NSString *responseString = [[NSString alloc] initWithBytes:[responseData bytes] length:[responseData length] encoding: NSUTF8StringEncoding];
    BITHockeyLogWarning(@"INFO: Received API response: %@", responseString);
    
    if (!responseString || ![responseString dataUsingEncoding:NSUTF8StringEncoding]) {
      return;
    }
    
    [self processStoreResponseWithString:responseString];
  }
}

- (void)checkForUpdateDelayed {
  [self checkForUpdateManual:NO];
}

- (void)checkForUpdate {
  [self checkForUpdateManual:YES];
}


// begin the startup process
- (void)startManager {
  if ([self shouldCancelProcessing]) return;
  
  BITHockeyLogDebug(@"INFO: Start UpdateManager");

  if ([self.userDefaults objectForKey:kBITStoreUpdateDateOfLastCheck]) {
    self.lastCheck = [self.userDefaults objectForKey:kBITStoreUpdateDateOfLastCheck];
  }
  
  if (!self.lastCheck) {
    self.lastCheck = [NSDate distantPast];
  }
  
  [self registerObservers];
  
  // we are already delayed, so the notification already came in and this won't invoked twice
  switch ([BITHockeyHelper applicationState]) {
    case BITApplicationStateActive:
      [self didBecomeActiveActions];
      break;
    case BITApplicationStateBackground:
    case BITApplicationStateInactive:
    case BITApplicationStateUnknown:
      // do nothing, wait for active state
      break;
  }
}


#pragma mark - Alert

- (void)showUpdateAlert {
  dispatch_async(dispatch_get_main_queue(), ^{
  if (!self.updateAlertShowing) {
    NSString *versionString = [NSString stringWithFormat:@"%@ %@", BITHockeyLocalizedString(@"Version"), self.latestStoreVersion];
    __weak typeof(self) weakSelf = self;

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:BITHockeyLocalizedString(@"UpdateAvailable")
                                                                             message:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateAlertTextWithAppVersion"), versionString]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ignoreAction = [BITAlertAction actionWithTitle:BITHockeyLocalizedString(@"Ignore")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction __unused *action) {
                                                           typeof(self) strongSelf = weakSelf;
                                                           [strongSelf ignoreAction];
                                                         }];
    [alertController addAction:ignoreAction];
    UIAlertAction *remindAction = [BITAlertAction actionWithTitle:BITHockeyLocalizedString(@"Remind Me")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction __unused *action) {
                                                           typeof(self) strongSelf = weakSelf;
                                                           [strongSelf remindAction];
                                                         }];
    [alertController addAction:remindAction];
    UIAlertAction *showAction = [BITAlertAction actionWithTitle:BITHockeyLocalizedString(@"Show")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction __unused *action) {
                                                         typeof(self) strongSelf = weakSelf;
                                                         [strongSelf showAction];
                                                       }];
    [alertController addAction:showAction];
    [self showAlertController:alertController];
    self.updateAlertShowing = YES;
  }
  });
}


#pragma mark - Properties

- (void)setLastCheck:(NSDate *)aLastCheck {
  if (_lastCheck != aLastCheck) {
    _lastCheck = aLastCheck;
    
    [self.userDefaults setObject:self.lastCheck forKey:kBITStoreUpdateDateOfLastCheck];
  }
}

- (void)ignoreAction {
  self.updateAlertShowing = NO;
  [self.userDefaults setObject:self.latestStoreVersion forKey:kBITStoreUpdateIgnoreVersion];
}

- (void)remindAction {
  self.updateAlertShowing = NO;
}

- (void)showAction {
  self.updateAlertShowing = NO;
  [self.userDefaults setObject:self.latestStoreVersion forKey:kBITStoreUpdateIgnoreVersion];
  
  if (self.appStoreURLString) {
    [[UIApplication sharedApplication] openURL:(NSURL *)[NSURL URLWithString:self.appStoreURLString]];
  } else {
    BITHockeyLogWarning(@"WARNING: The app store page couldn't be opened, since we did not get a valid URL from the store API.");
  }
}

@end

#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */
