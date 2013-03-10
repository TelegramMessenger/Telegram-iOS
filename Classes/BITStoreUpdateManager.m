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
  NSString *_lastStoreVersion;
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
    _lastStoreVersion = nil;
    _newStoreVersion = nil;
    _appStoreURL = nil;
    _currentUUID = [[self executableUUID] copy];
    _countryCode = nil;
    
    // set defaults
    self.checkForUpdateOnLaunch = YES;
    self.updateSetting = BITStoreUpdateCheckDaily;

    if ([[NSUserDefaults standardUserDefaults] objectForKey:kBITStoreUpdateLastStoreVersion]) {
      _lastStoreVersion = [[NSUserDefaults standardUserDefaults] objectForKey:kBITStoreUpdateLastStoreVersion];
    }

    if ([[NSUserDefaults standardUserDefaults] objectForKey:kBITStoreUpdateDateOfLastCheck]) {
      self.lastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:kBITStoreUpdateDateOfLastCheck];
    }
    
    if (!_lastCheck) {
      self.lastCheck = [NSDate distantPast];
    }
    
    if (!BITHockeyBundle()) {
      NSLog(@"[HockeySDK] WARNING: %@ is missing, make sure it is added!", BITHOCKEYSDK_BUNDLE);
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}


#pragma mark - Version

- (BOOL)hasNewVersion:(NSDictionary *)dictionary {
  _lastCheckFailed = YES;
  
  if ( [(NSDictionary *)[dictionary objectForKey:@"results"] count] > 0 ) {
    _lastCheckFailed = NO;

    _newStoreVersion = [(NSDictionary *)[[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"version"];
    _appStoreURL = [(NSDictionary *)[[dictionary objectForKey:@"results"] objectAtIndex:0] objectForKey:@"trackViewUrl"];
    
    if (!_newStoreVersion || !_appStoreURL) {
      return NO;
    } else if (!_lastStoreVersion) {
      [[NSUserDefaults standardUserDefaults] setObject:_currentUUID forKey:kBITStoreUpdateLastUUID];
      [[NSUserDefaults standardUserDefaults] setObject:_newStoreVersion forKey:kBITStoreUpdateLastStoreVersion];
      [[NSUserDefaults standardUserDefaults] synchronize];
      return NO;
    } else {
      NSComparisonResult comparissonResult = bit_versionCompare(_newStoreVersion, _lastStoreVersion);
      
      if (comparissonResult == NSOrderedDescending) {
        return YES;
      } else {
        return NO;
      }

    }
  }
  
  return NO;
}

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


#pragma mark - Update Check

- (void)checkForUpdate {
  if (![self isAppStoreEnvironment]) return;
  if (![self isStoreUpdateManagerEnabled]) return;
  if (self.isCheckInProgress) return;
  
  self.checkInProgress = YES;
  
  // do we need to update?
  if (![self shouldCheckForUpdates]) {
    BITHockeyLog(@"INFO: Update check not needed right now");
    self.checkInProgress = NO;
    return;
  }
  
  NSString *country = @"";
  if (self.countryCode) {
    country = [NSString stringWithFormat:@"&country=%@", self.countryCode];
  } else {
    country = [NSString stringWithFormat:@"&country=%@", [(NSDictionary *)[NSLocale currentLocale] objectForKey: NSLocaleCountryCode]];
  }
  // TODO: problem with worldwide is timed releases!
  
  NSString *appBundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  
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
      
      NSError *error = nil;
      NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
      
      // remember that we just checked the server
      self.lastCheck = [NSDate date];
      
      self.updateAvailable = [self hasNewVersion:json];
      if (_lastCheckFailed) return;
      
      if ([self isUpdateAvailable]) {
        [self showUpdateAlert];
      }
    }
  }];
}


// begin the startup process
- (void)startManager {
  if (![self isAppStoreEnvironment]) return;
  if (![self isStoreUpdateManagerEnabled]) return;

  BITHockeyLog(@"INFO: Start UpdateManager");

  // did the user just update the version?
  NSString *lastStoredUUID = nil;
  if ([[NSUserDefaults standardUserDefaults] objectForKey:kBITStoreUpdateLastUUID]) {
    lastStoredUUID = [[NSUserDefaults standardUserDefaults] objectForKey:kBITStoreUpdateLastUUID];
    if (_lastStoreVersion && lastStoredUUID && ![lastStoredUUID isEqualToString:_currentUUID]) {
      // a new version has been installed, reset everything
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBITStoreUpdateLastStoreVersion];
      _lastStoreVersion = nil;
    }
  }
  
  if (lastStoredUUID && ![lastStoredUUID isEqualToString:_currentUUID]) {
    [[NSUserDefaults standardUserDefaults] setObject:_currentUUID forKey:kBITStoreUpdateLastUUID];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
  
  if ([self isCheckingForUpdateOnLaunch] && [self shouldCheckForUpdates]) {
    [self performSelector:@selector(checkForUpdate) withObject:nil afterDelay:1.0f];
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
    [alertView setTag:0];
    [alertView show];
    _updateAlertShowing = YES;
  }
}


#pragma mark - Properties

- (void)setLastCheck:(NSDate *)aLastCheck {
  if (_lastCheck != aLastCheck) {
    _lastCheck = [aLastCheck copy];
    
    [[NSUserDefaults standardUserDefaults] setObject:self.lastCheck forKey:kBITStoreUpdateDateOfLastCheck];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
}


#pragma mark - UIAlertViewDelegate

// invoke the selected action from the action sheet for a location element
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  _updateAlertShowing = NO;
  if (buttonIndex == [alertView cancelButtonIndex]) {
    [[NSUserDefaults standardUserDefaults] setObject:self.lastCheck forKey:kBITStoreUpdateDateOfLastCheck];
    [[NSUserDefaults standardUserDefaults] synchronize];
  } else if (buttonIndex == [alertView firstOtherButtonIndex]) {
    // Remind button
  } else if (buttonIndex == [alertView firstOtherButtonIndex] + 1) {
    // Show button
    if (_appStoreURL) {
      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_appStoreURL]];
    }
  }
}

@end
