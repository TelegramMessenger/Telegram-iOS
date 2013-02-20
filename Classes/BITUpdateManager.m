/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde.
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
#import "BITUpdateManagerPrivate.h"
#import "BITUpdateViewControllerPrivate.h"
#import "BITAppVersionMetaInfo.h"


@implementation BITUpdateManager {
  NSString *_currentAppVersion;
  
  BITUpdateViewController *_currentHockeyViewController;
  
  BOOL _dataFound;
  BOOL _showFeedback;
  BOOL _updateAlertShowing;
  BOOL _lastCheckFailed;
  BOOL _sendUsageData;
  
  BOOL _didSetupDidBecomeActiveNotifications;

  BOOL _firstStartAfterInstall;
  
  NSNumber *_versionID;
  NSString *_versionUUID;
  NSString *_uuid;
}


#pragma mark - private

- (void)reportError:(NSError *)error {
  BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
  _lastCheckFailed = YES;
  
  // only show error if we enable that
  if (_showFeedback) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateError")
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:BITHockeyLocalizedString(@"OK") otherButtonTitles:nil];
    [alert show];
    _showFeedback = NO;
  }
}


- (void)didBecomeActiveActions {
  if (![self isUpdateManagerDisabled]) {
    [self checkExpiryDateReached];
    if (![self expiryDateReached]) {
      [self startUsage];
      if (_checkForUpdateOnLaunch) {
        [self checkForUpdate];
      }
    }
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

#pragma mark - Expiry

- (BOOL)expiryDateReached {
  if ([self isAppStoreEnvironment]) return NO;
  
  if (_expiryDate) {
    NSDate *currentDate = [NSDate date];
    if ([currentDate compare:_expiryDate] != NSOrderedAscending)
      return YES;
  }
  
  return NO;
}

- (void)checkExpiryDateReached {
  if (![self expiryDateReached]) return;
  
  BOOL shouldShowDefaultAlert = YES;
  
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(shouldDisplayExpiryAlertForUpdateManager:)]) {
    shouldShowDefaultAlert = [self.delegate shouldDisplayExpiryAlertForUpdateManager:self];
  }
  
  if (shouldShowDefaultAlert) {
    NSString *appName = bit_appName(BITHockeyLocalizedString(@"HockeyAppNamePlaceholder"));
    [self showBlockingScreen:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateExpired"), appName] image:@"authorize_denied.png"];

    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(didDisplayExpiryAlertForUpdateManager:)]) {
      [self.delegate didDisplayExpiryAlertForUpdateManager:self];
    }
    
    // the UI is now blocked, make sure we don't add our UI on top of it over and over again
    [self cleanupDidBecomeActiveNotifications];
  }
}

#pragma mark - Usage

- (void)startUsage {
  if ([self expiryDateReached]) return;

  self.usageStartTimestamp = [NSDate date];
  
  BOOL newVersion = NO;
  
  if (![[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForUUID]) {
    newVersion = YES;
  } else {
    if ([(NSString *)[[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForUUID] compare:_uuid] != NSOrderedSame) {
      newVersion = YES;
    }
  }
  
  if (newVersion) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]] forKey:kBITUpdateDateOfVersionInstallation];
    [[NSUserDefaults standardUserDefaults] setObject:_uuid forKey:kBITUpdateUsageTimeForUUID];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:0] forKey:kBITUpdateUsageTimeOfCurrentVersion];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }    
}

- (void)stopUsage {
  if ([self expiryDateReached]) return;
  
  double timeDifference = [[NSDate date] timeIntervalSinceReferenceDate] - [_usageStartTimestamp timeIntervalSinceReferenceDate];
  double previousTimeDifference = [(NSNumber *)[[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeOfCurrentVersion] doubleValue];
  
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:previousTimeDifference + timeDifference] forKey:kBITUpdateUsageTimeOfCurrentVersion];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)currentUsageString {
  double currentUsageTime = [[NSUserDefaults standardUserDefaults] doubleForKey:kBITUpdateUsageTimeOfCurrentVersion];
  
  if (currentUsageTime > 0) {
    // round (up) to 1 minute
    return [NSString stringWithFormat:@"%.0f", ceil(currentUsageTime / 60.0)*60];
  } else {
    return @"0";
  }
}

- (NSString *)installationDateString {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"MM/dd/yyyy"];
  double installationTimeStamp = [[NSUserDefaults standardUserDefaults] doubleForKey:kBITUpdateDateOfVersionInstallation];
  if (installationTimeStamp == 0.0f) {
    return [formatter stringFromDate:[NSDate date]];
  } else {
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:installationTimeStamp]];
  }
}

#pragma mark - Device identifier

- (NSString *)deviceIdentifier {
  if ([_delegate respondsToSelector:@selector(customDeviceIdentifierForUpdateManager:)]) {
    NSString *identifier = [_delegate performSelector:@selector(customDeviceIdentifierForUpdateManager:) withObject:self];
    if (identifier && [identifier length] > 0) {
      return identifier;
    }
  }
  
  return @"invalid";
}

#pragma mark - Authorization

- (NSString *)authenticationToken {
  return [BITHockeyMD5([NSString stringWithFormat:@"%@%@%@%@",
                 _authenticationSecret,
                 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"],
                 [self deviceIdentifier]
                 ]
                ) lowercaseString];
}

- (BITUpdateAuthorizationState)authorizationState {
  NSString *version = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateAuthorizedVersion];
  NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateAuthorizedToken];
  
  if (version != nil && token != nil) {
    if ([version compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
      // if it is denied, block the screen permanently
      if ([token compare:[self authenticationToken]] != NSOrderedSame) {
        return BITUpdateAuthorizationDenied;
      } else {
        return BITUpdateAuthorizationAllowed;
      }
    }
  }
  return BITUpdateAuthorizationPending;
}

#pragma mark - Cache

- (void)checkUpdateAvailable {
  // check if there is an update available
  NSComparisonResult comparissonResult = bit_versionCompare(self.newestAppVersion.version, self.currentAppVersion);
  
  if (comparissonResult == NSOrderedDescending) {
    self.updateAvailable = YES;
  } else if (comparissonResult == NSOrderedSame) {
    // compare using the binary UUID and stored version id
    self.updateAvailable = NO;
    if (_firstStartAfterInstall) {
      if ([self.newestAppVersion hasUUID:_uuid]) {
        _versionUUID = [_uuid copy];
        _versionID = [self.newestAppVersion.versionID copy];
        [self saveAppCache];
      } else {
        [self.appVersions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
          if (idx > 0 && [obj isKindOfClass:[BITAppVersionMetaInfo class]]) {
            NSComparisonResult compareVersions = bit_versionCompare([(BITAppVersionMetaInfo *)obj version], self.currentAppVersion);
            BOOL uuidFound = [(BITAppVersionMetaInfo *)obj hasUUID:_uuid];

            if (uuidFound) {
              _versionUUID = [_uuid copy];
              _versionID = [[(BITAppVersionMetaInfo *)obj versionID] copy];
              [self saveAppCache];
              
              self.updateAvailable = YES;
            }

            if (compareVersions != NSOrderedSame || uuidFound) {
              *stop = YES;
            }
          }
        }];
      }
    } else {
      if ([self.newestAppVersion.versionID compare:_versionID] == NSOrderedDescending)
        self.updateAvailable = YES;
    }
  }
}

- (void)loadAppCache {
  _firstStartAfterInstall = NO;
  _versionUUID = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateInstalledUUID];
  if (!_versionUUID) {
    _firstStartAfterInstall = YES;
  } else {
    if ([_uuid compare:_versionUUID] != NSOrderedSame)
      _firstStartAfterInstall = YES;
  }
  _versionID = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateInstalledVersionID];
  _companyName = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateCurrentCompanyName];
  
  NSData *savedHockeyData = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateArrayOfLastCheck];
  NSArray *savedHockeyCheck = nil;
  if (savedHockeyData) {
    savedHockeyCheck = [NSKeyedUnarchiver unarchiveObjectWithData:savedHockeyData];
  }
  if (savedHockeyCheck) {
    self.appVersions = [NSArray arrayWithArray:savedHockeyCheck];
    [self checkUpdateAvailable];
  } else {
    self.appVersions = nil;
  }
}

- (void)saveAppCache {
  if (_companyName)
    [[NSUserDefaults standardUserDefaults] setObject:_companyName forKey:kBITUpdateCurrentCompanyName];
  if (_versionUUID)
    [[NSUserDefaults standardUserDefaults] setObject:_versionUUID forKey:kBITUpdateInstalledUUID];
  if (_versionID)
    [[NSUserDefaults standardUserDefaults] setObject:_versionID forKey:kBITUpdateInstalledVersionID];
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.appVersions];
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:kBITUpdateArrayOfLastCheck];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Window Helper

- (UIWindow *)findVisibleWindow {
  UIWindow *visibleWindow = nil;
  
  // if the rootViewController property (available >= iOS 4.0) of the main window is set, we present the modal view controller on top of the rootViewController
  NSArray *windows = [[UIApplication sharedApplication] windows];
  for (UIWindow *window in windows) {
    if (!window.hidden && !visibleWindow) {
      visibleWindow = window;
    }
    if ([UIWindow instancesRespondToSelector:@selector(rootViewController)]) {
      if ([window rootViewController]) {
        visibleWindow = window;
        BITHockeyLog(@"INFO: UIWindow with rootViewController found: %@", visibleWindow);
        break;
      }
    }
  }
  
  return visibleWindow;
}


#pragma mark - Init

- (id)init {
  if ((self = [super init])) {
    _delegate = nil;
    _expiryDate = nil;
    _checkInProgress = NO;
    _dataFound = NO;
    _updateAvailable = NO;
    _lastCheckFailed = NO;
    _currentAppVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    _blockingView = nil;
    _requireAuthorization = NO;
    _authenticationSecret = nil;
    _lastCheck = nil;
    _uuid = [[self executableUUID] copy];
    _versionUUID = nil;
    _versionID = nil;
    _sendUsageData = YES;
    _disableUpdateManager = NO;
    _checkForTracker = NO;
    _didSetupDidBecomeActiveNotifications = NO;
    _firstStartAfterInstall = NO;
    _companyName = nil;
    
    // set defaults
    self.showDirectInstallOption = NO;
    self.alwaysShowUpdateReminder = YES;
    self.checkForUpdateOnLaunch = YES;
    self.updateSetting = BITUpdateCheckStartup;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateDateOfLastCheck]) {
      // we did write something else in the past, so for compatibility reasons do this
      id tempLastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateDateOfLastCheck];
      if ([tempLastCheck isKindOfClass:[NSDate class]]) {
        self.lastCheck = tempLastCheck;
      }
    }
    
    if (!_lastCheck) {
      self.lastCheck = [NSDate distantPast];
    }
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(updateManagerShouldSendUsageData:)]) {
      _sendUsageData = [self.delegate updateManagerShouldSendUsageData:self];
    }
    
    if (!BITHockeyBundle()) {
      NSLog(@"[HockeySDK] WARNING: %@ is missing, make sure it is added!", BITHOCKEYSDK_BUNDLE);
    }
    
    [self loadAppCache];
    
    [self startUsage];

    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillTerminateNotification object:nil];
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillResignActiveNotification object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
  
  [_urlConnection cancel];
}


#pragma mark - BetaUpdateUI

- (BITUpdateViewController *)hockeyViewController:(BOOL)modal {
  return [[BITUpdateViewController alloc] initWithModalStyle:modal];
}

- (void)showUpdateView {
  if ([self isAppStoreEnvironment]) {
    NSLog(@"[HockeySDK] This should not be called from an app store build!");
    return;
  }
  
  if (_currentHockeyViewController) {
    BITHockeyLog(@"INFO: Update view already visible, aborting");
    return;
  }
  
  self.barStyle = UIBarStyleBlack;
  [self showView:[self hockeyViewController:YES]];
}


- (void)showCheckForUpdateAlert {
  if ([self isAppStoreEnvironment]) return;
  if ([self isUpdateManagerDisabled]) return;
  
  if (!_updateAlertShowing) {
    if ([self hasNewerMandatoryVersion]) {
      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateAvailable")
                                                           message:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateAlertMandatoryTextWithAppVersion"), [self.newestAppVersion nameAndVersionString]]
                                                          delegate:self
                                                 cancelButtonTitle:BITHockeyLocalizedString(@"UpdateInstall")
                                                 otherButtonTitles:nil
                                 ];
      [alertView setTag:2];
      [alertView show];
      _updateAlertShowing = YES;
    } else {
      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateAvailable")
                                                           message:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateAlertTextWithAppVersion"), [self.newestAppVersion nameAndVersionString]]
                                                          delegate:self
                                                 cancelButtonTitle:BITHockeyLocalizedString(@"UpdateIgnore")
                                                 otherButtonTitles:BITHockeyLocalizedString(@"UpdateShow"), nil
                                 ];
      if (self.isShowingDirectInstallOption) {
        [alertView addButtonWithTitle:BITHockeyLocalizedString(@"UpdateInstall")];
      }
      [alertView setTag:0];
      [alertView show];
      _updateAlertShowing = YES;
    }
  }
}


// nag the user with neverending alerts if we cannot find out the window for presenting the covering sheet
- (void)alertFallback:(NSString *)message {
  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                       message:message
                                                      delegate:self
                                             cancelButtonTitle:BITHockeyLocalizedString(@"HockeyOK")
                                             otherButtonTitles:nil
                             ];
  [alertView setTag:1];
  [alertView show];    
}


// open an authorization screen
- (void)showBlockingScreen:(NSString *)message image:(NSString *)image {
  self.blockingView = nil;
  
  UIWindow *visibleWindow = [self findVisibleWindow];
  if (visibleWindow == nil) {
    [self alertFallback:message];
    return;
  }
  
  CGRect frame = [visibleWindow frame];
  
  self.blockingView = [[UIView alloc] initWithFrame:frame];
  UIImageView *backgroundView = [[UIImageView alloc] initWithImage:bit_imageNamed(@"bg.png", BITHOCKEYSDK_BUNDLE)];
  backgroundView.contentMode = UIViewContentModeScaleAspectFill;
  backgroundView.frame = frame;
  [self.blockingView addSubview:backgroundView];
  
  if (image != nil) {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:bit_imageNamed(image, BITHOCKEYSDK_BUNDLE)];
    imageView.contentMode = UIViewContentModeCenter;
    imageView.frame = frame;
    [self.blockingView addSubview:imageView];
  }
  
  if (message != nil) {
    frame.origin.x = 20;
    frame.origin.y = frame.size.height - 140;
    frame.size.width -= 40;
    frame.size.height = 50;
    
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = message;
    label.textAlignment = kBITTextLabelAlignmentCenter;
    label.numberOfLines = 2;
    label.backgroundColor = [UIColor clearColor];
    
    [self.blockingView addSubview:label];
  }
  
  [visibleWindow addSubview:self.blockingView];
}


#pragma mark - RequestComments

- (BOOL)shouldCheckForUpdates {
  BOOL checkForUpdate = NO;
  
  switch (self.updateSetting) {
    case BITUpdateCheckStartup:
      checkForUpdate = YES;
      break;
    case BITUpdateCheckDaily: {
      NSTimeInterval dateDiff = fabs([self.lastCheck timeIntervalSinceNow]);
      if (dateDiff != 0)
        dateDiff = dateDiff / (60*60*24);
      
      checkForUpdate = (dateDiff >= 1);
      break;
    }
    case BITUpdateCheckManually:
      checkForUpdate = NO;
      break;
    default:
      break;
  }
  
  return checkForUpdate;
}

- (void)checkForAuthorization {
  NSMutableString *parameter = [NSMutableString stringWithFormat:@"api/2/apps/%@", [self encodedAppIdentifier]];
  
  [parameter appendFormat:@"?format=json&authorize=yes&app_version=%@&udid=%@&sdk=%@&sdk_version=%@&uuid=%@",
   bit_URLEncodedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]),
   ([self isAppStoreEnvironment] ? @"appstore" : bit_URLEncodedString([self deviceIdentifier])),
   BITHOCKEY_NAME,
   BITHOCKEY_VERSION,
   _uuid
   ];
  
  // build request & send
  NSString *url = [NSString stringWithFormat:@"%@%@", self.serverURL, parameter];
  BITHockeyLog(@"INFO: Sending api request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:1 timeoutInterval:10.0];
  [request setHTTPMethod:@"GET"];
  [request setValue:@"Hockey/iOS" forHTTPHeaderField:@"User-Agent"];
  
  NSURLResponse *response = nil;
  NSError *error = NULL;
  BOOL failed = YES;
  
  NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
  
  if ([responseData length]) {
    NSString *responseString = [[NSString alloc] initWithBytes:[responseData bytes] length:[responseData length] encoding: NSUTF8StringEncoding];
    
    if (responseString && [responseString dataUsingEncoding:NSUTF8StringEncoding]) {
      NSDictionary *feedDict = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
      
      // server returned empty response?
      if (![feedDict count]) {
        [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                              code:BITUpdateAPIServerReturnedEmptyResponse
                                          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned empty response.", NSLocalizedDescriptionKey, nil]]];
        return;
      } else {
        BITHockeyLog(@"INFO: Received API response: %@", responseString);
        NSString *token = [[feedDict objectForKey:@"authcode"] lowercaseString];
        failed = NO;
        if ([[self authenticationToken] compare:token] == NSOrderedSame) {
          // identical token, activate this version
          
          // store the new data
          [[NSUserDefaults standardUserDefaults] setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:kBITUpdateAuthorizedVersion];
          [[NSUserDefaults standardUserDefaults] setObject:token forKey:kBITUpdateAuthorizedToken];
          [[NSUserDefaults standardUserDefaults] synchronize];
          
          self.requireAuthorization = NO;
          self.blockingView = nil;
          
          // now continue with an update check right away
          if (self.checkForUpdateOnLaunch) {
            [self checkForUpdate];
          }
        } else {
          // different token, block this version
          BITHockeyLog(@"INFO: AUTH FAILURE: %@", [self authenticationToken]);
          
          // store the new data
          [[NSUserDefaults standardUserDefaults] setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:kBITUpdateAuthorizedVersion];
          [[NSUserDefaults standardUserDefaults] setObject:token forKey:kBITUpdateAuthorizedToken];
          [[NSUserDefaults standardUserDefaults] synchronize];
          
          [self showBlockingScreen:BITHockeyLocalizedString(@"UpdateAuthorizationDenied") image:@"authorize_denied.png"];
        }
      }
    }
    
  }
  
  if (failed) {
    [self showBlockingScreen:BITHockeyLocalizedString(@"UpdateAuthorizationOffline") image:@"authorize_request.png"];
  }
}

- (void)checkForUpdate {
  if (![self isAppStoreEnvironment] && ![self isUpdateManagerDisabled]) {
    if ([self expiryDateReached]) return;
    if (self.requireAuthorization) return;
    
    if (self.isUpdateAvailable && [self hasNewerMandatoryVersion]) {
      [self showCheckForUpdateAlert];
    }
    
    [self checkForUpdateShowFeedback:NO];
  } else if ([self checkForTracker]) {
    [self checkForUpdateShowFeedback:NO];
  }
}

- (void)checkForUpdateShowFeedback:(BOOL)feedback {
  if (self.isCheckInProgress) return;
  
  _showFeedback = feedback;
  self.checkInProgress = YES;
  
  // do we need to update?
  if (![self checkForTracker] && ![self shouldCheckForUpdates] && !_currentHockeyViewController) {
    BITHockeyLog(@"INFO: Update not needed right now");
    self.checkInProgress = NO;
    return;
  }
  
  NSMutableString *parameter = [NSMutableString stringWithFormat:@"api/2/apps/%@?format=json&extended=true&udid=%@&sdk=%@&sdk_version=%@&uuid=%@", 
                                bit_URLEncodedString([self encodedAppIdentifier]),
                                ([self isAppStoreEnvironment] ? @"appstore" : bit_URLEncodedString([self deviceIdentifier])),
                                BITHOCKEY_NAME,
                                BITHOCKEY_VERSION,
                                _uuid];
  
  // add additional statistics if user didn't disable flag
  if (_sendUsageData) {
    [parameter appendFormat:@"&app_version=%@&os=iOS&os_version=%@&device=%@&lang=%@&first_start_at=%@&usage_time=%@",
     bit_URLEncodedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]),
     bit_URLEncodedString([[UIDevice currentDevice] systemVersion]),
     bit_URLEncodedString([self getDevicePlatform]),
     bit_URLEncodedString([[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0]),
     bit_URLEncodedString([self installationDateString]),
     bit_URLEncodedString([self currentUsageString])
     ];
  }
  
  if ([self checkForTracker]) {
    [parameter appendFormat:@"&jmc=yes"];
  }
  
  // build request & send
  NSString *url = [NSString stringWithFormat:@"%@%@", self.serverURL, parameter];
  BITHockeyLog(@"INFO: Sending api request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:1 timeoutInterval:10.0];
  [request setHTTPMethod:@"GET"];
  [request setValue:@"Hockey/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  self.urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
  if (!_urlConnection) {
    self.checkInProgress = NO;
    [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                          code:BITUpdateAPIClientCannotCreateConnection
                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Url Connection could not be created.", NSLocalizedDescriptionKey, nil]]];
  }
}

- (BOOL)initiateAppDownload {
  if ([self isAppStoreEnvironment]) return NO;
  
  if (!self.isUpdateAvailable) {
    BITHockeyLog(@"WARNING: No update available. Aborting.");
    return NO;
  }
  
#if TARGET_IPHONE_SIMULATOR
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateWarning") message:BITHockeyLocalizedString(@"UpdateSimulatorMessage") delegate:nil cancelButtonTitle:BITHockeyLocalizedString(@"HockeyOK") otherButtonTitles:nil];
  [alert show];
  return NO;
#endif
  
  NSString *extraParameter = [NSString string];
  if (_sendUsageData) {
    extraParameter = [NSString stringWithFormat:@"&udid=%@", [self deviceIdentifier]];
  }
  
  NSString *hockeyAPIURL = [NSString stringWithFormat:@"%@api/2/apps/%@?format=plist%@", self.serverURL, [self encodedAppIdentifier], extraParameter];
  NSString *iOSUpdateURL = [NSString stringWithFormat:@"itms-services://?action=download-manifest&url=%@", bit_URLEncodedString(hockeyAPIURL)];
  
  BITHockeyLog(@"INFO: API Server Call: %@, calling iOS with %@", hockeyAPIURL, iOSUpdateURL);
  BOOL success = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iOSUpdateURL]];
  BITHockeyLog(@"INFO: System returned: %d", success);
  return success;
}


// checks whether this app version is authorized
- (BOOL)appVersionIsAuthorized {
  if (self.requireAuthorization && !_authenticationSecret) {
    [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                          code:BITUpdateAPIClientAuthorizationMissingSecret
                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Authentication secret is not set but required.", NSLocalizedDescriptionKey, nil]]];
    
    return NO;
  }
  
  if (!self.requireAuthorization) {
    self.blockingView = nil;
    return YES;
  }

#if TARGET_IPHONE_SIMULATOR
  NSLog(@"Authentication checks only work on devices. Using the simulator will always return being authorized.");
  return YES;
#endif

  BITUpdateAuthorizationState state = [self authorizationState];
  if (state == BITUpdateAuthorizationDenied) {
    [self showBlockingScreen:BITHockeyLocalizedString(@"UpdateAuthorizationDenied") image:@"authorize_denied.png"];
  } else if (state == BITUpdateAuthorizationAllowed) {
    self.requireAuthorization = NO;
    return YES;
  }
  
  return NO;
}


// begin the startup process
- (void)startManager {
  if (![self isAppStoreEnvironment]) {
    if ([self isUpdateManagerDisabled]) return;

    BITHockeyLog(@"INFO: Start UpdateManager");

    [self checkExpiryDateReached];
    if (![self expiryDateReached]) {
      if (![self appVersionIsAuthorized]) {
        if ([self authorizationState] == BITUpdateAuthorizationPending) {
          [self showBlockingScreen:BITHockeyLocalizedString(@"UpdateAuthorizationProgress") image:@"authorize_request.png"];
          
          [self performSelector:@selector(checkForAuthorization) withObject:nil afterDelay:0.0f];
        }
      } else {
        if ([self checkForTracker] || ([self isCheckForUpdateOnLaunch] && [self shouldCheckForUpdates])) {
          [self performSelector:@selector(checkForUpdate) withObject:nil afterDelay:1.0f];
        }
      }
    }
  } else {
    if ([self checkForTracker]) {
      // if we are in the app store, make sure not to send usage information in any case for now
      _sendUsageData = NO;
      
      [self performSelector:@selector(checkForUpdate) withObject:nil afterDelay:1.0f];
    }
  }
  [self setupDidBecomeActiveNotifications];
}


#pragma mark - NSURLRequest

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
  NSURLRequest *newRequest = request;
  if (redirectResponse) {
    newRequest = nil;
  }
  return newRequest;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  if ([response respondsToSelector:@selector(statusCode)]) {
    int statusCode = [((NSHTTPURLResponse *)response) statusCode];
    if (statusCode == 404) {
      [connection cancel];  // stop connecting; no more delegate messages
      NSString *errorStr = [NSString stringWithFormat:@"Hockey API received HTTP Status Code %d", statusCode];
      [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                            code:BITUpdateAPIServerReturnedInvalidStatus
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorStr, NSLocalizedDescriptionKey, nil]]];
      return;
    }
  }
  
  self.receivedData = [NSMutableData data];
  [_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  [_receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  self.receivedData = nil;
  self.urlConnection = nil;
  self.checkInProgress = NO;
  [self reportError:error];
}

// api call returned, parsing
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  self.checkInProgress = NO;
  
  if ([self.receivedData length]) {
    NSString *responseString = [[NSString alloc] initWithBytes:[_receivedData bytes] length:[_receivedData length] encoding: NSUTF8StringEncoding];
    BITHockeyLog(@"INFO: Received API response: %@", responseString);
    
    if (!responseString || ![responseString dataUsingEncoding:NSUTF8StringEncoding]) {
      self.receivedData = nil;
      self.urlConnection = nil;
      return;
    }
    
    NSError *error = nil;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
                                              
    self.trackerConfig = (([self checkForTracker] && [[json valueForKey:@"tracker"] isKindOfClass:[NSDictionary class]]) ? [json valueForKey:@"tracker"] : nil);
    self.companyName = (([[json valueForKey:@"company"] isKindOfClass:[NSString class]]) ? [json valueForKey:@"company"] : nil);
    
    if (![self isAppStoreEnvironment]) {
      NSArray *feedArray = (NSArray *)[json valueForKey:@"versions"];
      
      // remember that we just checked the server
      self.lastCheck = [NSDate date];
      
      // server returned empty response?
      if (![feedArray count]) {
        BITHockeyLog(@"WARNING: No versions available for download on HockeyApp.");
        self.receivedData = nil;
        self.urlConnection = nil;
        return;
      } else {
        _lastCheckFailed = NO;
      }
      
      
      NSString *currentAppCacheVersion = [[self newestAppVersion].version copy];
      
      // clear cache and reload with new data
      NSMutableArray *tmpAppVersions = [NSMutableArray arrayWithCapacity:[feedArray count]];
      for (NSDictionary *dict in feedArray) {
        BITAppVersionMetaInfo *appVersionMetaInfo = [BITAppVersionMetaInfo appVersionMetaInfoFromDict:dict];
        if ([appVersionMetaInfo isValid]) {
          [tmpAppVersions addObject:appVersionMetaInfo];
        } else {
          [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                                code:BITUpdateAPIServerReturnedInvalidData
                                            userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Invalid data received from server.", NSLocalizedDescriptionKey, nil]]];
        }
      }
      // only set if different!
      if (![self.appVersions isEqualToArray:tmpAppVersions]) {
        self.appVersions = [tmpAppVersions copy];
      }
      [self saveAppCache];
      
      [self checkUpdateAvailable];
      BOOL newVersionDiffersFromCachedVersion = ![self.newestAppVersion.version isEqualToString:currentAppCacheVersion];
      
      // show alert if we are on the latest & greatest
      if (_showFeedback && !self.isUpdateAvailable) {
        // use currentVersionString, as version still may differ (e.g. server: 1.2, client: 1.3)
        NSString *versionString = [self currentAppVersion];
        NSString *shortVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        shortVersionString = shortVersionString ? [NSString stringWithFormat:@"%@ ", shortVersionString] : @"";
        versionString = [shortVersionString length] ? [NSString stringWithFormat:@"(%@)", versionString] : versionString;
        NSString *currentVersionString = [NSString stringWithFormat:@"%@ %@ %@%@", self.newestAppVersion.name, BITHockeyLocalizedString(@"UpdateVersion"), shortVersionString, versionString];
        NSString *alertMsg = [NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateNoUpdateAvailableMessage"), currentVersionString];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateNoUpdateAvailableTitle")
                                                        message:alertMsg
                                                       delegate:nil
                                              cancelButtonTitle:BITHockeyLocalizedString(@"HockeyOK")
                                              otherButtonTitles:nil];
        [alert show];
      }
      
      if (self.isUpdateAvailable && (self.alwaysShowUpdateReminder || newVersionDiffersFromCachedVersion || [self hasNewerMandatoryVersion])) {
        if (_updateAvailable && !_currentHockeyViewController) {
          [self showCheckForUpdateAlert];
        }
      }
      _showFeedback = NO;
    }
  } else {
    [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                          code:BITUpdateAPIServerReturnedEmptyResponse
                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned an empty response.", NSLocalizedDescriptionKey, nil]]];
  }
  self.receivedData = nil;
  self.urlConnection = nil;
}

- (BOOL)hasNewerMandatoryVersion {
  BOOL result = NO;
  
  for (BITAppVersionMetaInfo *appVersion in self.appVersions) {
    if ([appVersion.version isEqualToString:self.currentAppVersion] || bit_versionCompare(appVersion.version, self.currentAppVersion) == NSOrderedAscending) {
      break;
    }
    
    if ([appVersion.mandatory boolValue]) {
      result = YES;
    }
  }
  
  return result;
}


#pragma mark - Properties

- (void)setCurrentHockeyViewController:(BITUpdateViewController *)aCurrentHockeyViewController {
  if (_currentHockeyViewController != aCurrentHockeyViewController) {
    _currentHockeyViewController = aCurrentHockeyViewController;
    //HockeySDKLog(@"active hockey view controller: %@", aCurrentHockeyViewController);
  }
}

- (NSString *)currentAppVersion {
  return _currentAppVersion;
}

- (void)setLastCheck:(NSDate *)aLastCheck {
  if (_lastCheck != aLastCheck) {
    _lastCheck = [aLastCheck copy];
    
    [[NSUserDefaults standardUserDefaults] setObject:_lastCheck forKey:kBITUpdateDateOfLastCheck];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
}

- (void)setAppVersions:(NSArray *)anAppVersions {
  if (_appVersions != anAppVersions || !_appVersions) {
    [self willChangeValueForKey:@"appVersions"];
    
    // populate with default values (if empty)
    if (![anAppVersions count]) {
      BITAppVersionMetaInfo *defaultApp = [[BITAppVersionMetaInfo alloc] init];
      defaultApp.name = bit_appName(BITHockeyLocalizedString(@"HockeyAppNamePlaceholder"));
      defaultApp.version = _currentAppVersion;
      defaultApp.shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
      _appVersions = [NSArray arrayWithObject:defaultApp];
    } else {
      _appVersions = [anAppVersions copy];
    }      
    [self didChangeValueForKey:@"appVersions"];
  }
}

- (BITAppVersionMetaInfo *)newestAppVersion {
  BITAppVersionMetaInfo *appVersion = [_appVersions objectAtIndex:0];
  return appVersion;
}

- (void)setBlockingView:(UIView *)anBlockingView {
  if (_blockingView != anBlockingView) {
    [_blockingView removeFromSuperview];
    _blockingView = anBlockingView;
  }
}


#pragma mark - UIAlertViewDelegate

// invoke the selected action from the action sheet for a location element
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if ([alertView tag] == 2) {
    (void)[self initiateAppDownload];
    _updateAlertShowing = NO;
    return;
  } else if ([alertView tag] == 1) {
    [self alertFallback:[alertView message]];
    return;
  }
  
  _updateAlertShowing = NO;
  if (buttonIndex == [alertView firstOtherButtonIndex]) {
    // YES button has been clicked
    [self showUpdateView];
  } else if (buttonIndex == [alertView firstOtherButtonIndex] + 1) {
    // YES button has been clicked
    (void)[self initiateAppDownload];
  }
}

@end
