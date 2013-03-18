/*
 * Author: Andreas Linde <mail@andreaslinde.de>
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

#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITStoreUpdateManagerPrivate.h"


@implementation BITStoreUpdateManager {
  NSString *_newStoreVersion;
  NSString *_appStoreURL;
  NSString *_currentUUID;
  
  BOOL _updateAlertShowing;
  BOOL _lastCheckFailed;
  
  BOOL _didSetupDidBecomeActiveNotifications;
}


#pragma mark - private

- (void)reportError:(NSError *)error {
  BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
  _lastCheckFailed = YES;
}


- (void)didBecomeActiveActions {
  if ([self isStoreUpdateManagerEnabled] && [self isCheckingForUpdateOnLaunch]) {
    [self checkForUpdate];
  }
}

- (void)setupDidBecomeActiveNotifications {
  if (!_didSetupDidBecomeActiveNotifications) {
    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(didBecomeActiveActions) name:UIApplicationDidBecomeActiveNotification object:nil];
    [dnc addObserver:self selector:@selector(didBecomeActiveActions) name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
    _didSetupDidBecomeActiveNotifications = YES;
  }
}

- (void)cleanupDidBecomeActiveNotifications {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}


#pragma mark - Init

- (id)init {
  if ((self = [super init])) {
    _checkInProgress = NO;
    _updateAvailable = NO;
    _lastCheckFailed = NO;
    _enableStoreUpdateManager = NO;
    _didSetupDidBecomeActiveNotifications = NO;
    _updateAlertShowing = NO;
    _newStoreVersion = nil;
    _appStoreURL = nil;
    _currentUUID = [[self executableUUID] copy];
    _countryCode = nil;
    
    _mainBundle = [NSBundle mainBundle];
    _currentLocale = [NSLocale currentLocale];
    _userDefaults = [NSUserDefaults standardUserDefaults];
    
    // set defaults
    self.checkForUpdateOnLaunch = YES;
    self.updateSetting = BITStoreUpdateCheckDaily;

    if (!BITHockeyBundle()) {
      NSLog(@"[HockeySDK] WARNING: %@ is missing, built in UI is deactivated!", BITHOCKEYSDK_BUNDLE);
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
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

    if (lastSavedUUID && ![lastSavedUUID isEqualToString:_currentUUID]) {
      // the UUIDs don't match, store the new one
      [self.userDefaults setObject:_currentUUID forKey:kBITStoreUpdateLastUUID];
      
      if (versionString) {
        // a new version has been installed, reset everything
        // so we set versionString to nil to simulate that this is the very run
        [self.userDefaults removeObjectForKey:kBITStoreUpdateLastStoreVersion];
        versionString = nil;
      }

      [self.userDefaults synchronize];
    }
  }
  
  return versionString;
}

- (BOOL)hasNewVersion:(NSDictionary *)dictionary {
  _lastCheckFailed = YES;
  
  NSString *lastStoreVersion = [self lastStoreVersion];
  
  if ([[dictionary objectForKey:@"results"] isKindOfClass:[NSArray class]] &&
      [(NSArray *)[dictionary objectForKey:@"results"] count] > 0 ) {
    _lastCheckFailed = NO;

    _newStoreVersion = [(NSDictionary *)[(NSArray *)[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"version"];
    _appStoreURL = [(NSDictionary *)[(NSArray *)[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"trackViewUrl"];
    
    NSString *ignoredVersion = nil;
    if ([self.userDefaults objectForKey:kBITStoreUpdateIgnoreVersion]) {
      ignoredVersion = [self.userDefaults objectForKey:kBITStoreUpdateIgnoreVersion];
    }
    
    if (!_newStoreVersion || !_appStoreURL) {
      return NO;
    } else if (ignoredVersion && [ignoredVersion isEqualToString:_newStoreVersion]) {
      return NO;
    } else if (!lastStoreVersion) {
      // this is the very first time we get a valid response and
      // set the reference of the store result to be equal to the current installed version
      // even though the current installed version could be older than the one in the app store
      // but this ensures that we never have false alerts, since the version string in
      // iTunes Connect doesn't have to match CFBundleVersion or CFBundleShortVersionString
      // and even if it matches it is hard/impossible to 100% determine which one it is,
      // since they could change at any time
      [self.userDefaults setObject:_currentUUID forKey:kBITStoreUpdateLastUUID];
      [self.userDefaults setObject:_newStoreVersion forKey:kBITStoreUpdateLastStoreVersion];
      [self.userDefaults synchronize];
      return NO;
    } else {
      NSComparisonResult comparissonResult = bit_versionCompare(_newStoreVersion, lastStoreVersion);
      
      if (comparissonResult == NSOrderedDescending) {
        return YES;
      } else {
        return NO;
      }

    }
  }
  
  return NO;
}


#pragma mark - Time

- (BOOL)shouldCheckForUpdates {
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
  if (![self isAppStoreEnvironment]) return YES;
  if (![self isStoreUpdateManagerEnabled]) return YES;
  return NO;
}


- (BOOL)processStoreResponseWithString:(NSString *)responseString {
  if (!responseString) return NO;
  
  NSData *data = [responseString dataUsingEncoding:NSUTF8StringEncoding];
  
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
  
  if (error) {
    BITHockeyLog(@"ERROR: Invalid JSON string. %@", [error localizedDescription]);
    return NO;
  }
  
  // remember that we just checked the server
  self.lastCheck = [NSDate date];
  
  self.updateAvailable = [self hasNewVersion:json];
  if (_lastCheckFailed) return NO;
  
  if ([self isUpdateAvailable] && BITHockeyBundle()) {
    [self showUpdateAlert];
  }
  
  return YES;
}


#pragma mark - Update Check

- (void)checkForUpdateManual:(BOOL)manual {
  if ([self shouldCancelProcessing]) return;

  if (self.isCheckInProgress) return;
  self.checkInProgress = YES;
  
  // do we need to update?
  if (!manual && ![self shouldCheckForUpdates]) {
    BITHockeyLog(@"INFO: Update check not needed right now");
    self.checkInProgress = NO;
    return;
  }
  
  NSString *country = @"";
  if (self.countryCode) {
    country = [NSString stringWithFormat:@"&country=%@", self.countryCode];
  } else {
    country = [NSString stringWithFormat:@"&country=%@", [(NSDictionary *)self.currentLocale objectForKey: NSLocaleCountryCode]];
  }
  // TODO: problem with worldwide is timed releases!
  
  NSString *appBundleIdentifier = [self.mainBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  
  NSString *url = [NSString stringWithFormat:@"http://itunes.apple.com/lookup?bundleId=%@%@",
                   bit_URLEncodedString(appBundleIdentifier),
                   country];
  
  BITHockeyLog(@"INFO: Sending request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:1 timeoutInterval:10.0];
  [request setHTTPMethod:@"GET"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error){
    self.checkInProgress = NO;
    
    if (error) {
      [self reportError:error];
    } else if ([responseData length]) {
      NSString *responseString = [[NSString alloc] initWithBytes:[responseData bytes] length:[responseData length] encoding: NSUTF8StringEncoding];
      BITHockeyLog(@"INFO: Received API response: %@", responseString);
      
      if (!responseString || ![responseString dataUsingEncoding:NSUTF8StringEncoding]) {
        return;
      }
      
      [self processStoreResponseWithString:responseString];
    }
  }];
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
  
  BITHockeyLog(@"INFO: Start UpdateManager");

  if ([self.userDefaults objectForKey:kBITStoreUpdateDateOfLastCheck]) {
    self.lastCheck = [self.userDefaults objectForKey:kBITStoreUpdateDateOfLastCheck];
  }
  
  if (!_lastCheck) {
    self.lastCheck = [NSDate distantPast];
  }
  
  if ([self isCheckingForUpdateOnLaunch] && [self shouldCheckForUpdates]) {
    [self performSelector:@selector(checkForUpdateDelayed) withObject:nil afterDelay:1.0f];
  }

  [self setupDidBecomeActiveNotifications];
}


#pragma mark - Alert

- (void)showUpdateAlert {
  if (!_updateAlertShowing) {
    NSString *versionString = [NSString stringWithFormat:@"%@ %@", BITHockeyLocalizedString(@"UpdateVersion"), _newStoreVersion];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateAvailable")
                                                        message:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateAlertTextWithAppVersion"), versionString]
                                                       delegate:self
                                              cancelButtonTitle:BITHockeyLocalizedString(@"UpdateIgnore")
                                              otherButtonTitles:BITHockeyLocalizedString(@"UpdateRemindMe"), BITHockeyLocalizedString(@"UpdateShow"), nil
                              ];
    [alertView show];
    _updateAlertShowing = YES;
  }
}


#pragma mark - Properties

- (void)setLastCheck:(NSDate *)aLastCheck {
  if (_lastCheck != aLastCheck) {
    _lastCheck = [aLastCheck copy];
    
    [self.userDefaults setObject:self.lastCheck forKey:kBITStoreUpdateDateOfLastCheck];
    [self.userDefaults synchronize];
  }
}


#pragma mark - UIAlertViewDelegate

// invoke the selected action from the action sheet for a location element
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  _updateAlertShowing = NO;
  if (buttonIndex == [alertView cancelButtonIndex]) {
    // Ignore
    [self.userDefaults setObject:_newStoreVersion forKey:kBITStoreUpdateIgnoreVersion];
    [self.userDefaults synchronize];
  } else if (buttonIndex == [alertView firstOtherButtonIndex]) {
    // Remind button
  } else if (buttonIndex == [alertView firstOtherButtonIndex] + 1) {
    // Show button
    [self.userDefaults setObject:_newStoreVersion forKey:kBITStoreUpdateIgnoreVersion];
    [self.userDefaults synchronize];
    
    if (_appStoreURL) {
      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_appStoreURL]];
    }
  }
}

@end
