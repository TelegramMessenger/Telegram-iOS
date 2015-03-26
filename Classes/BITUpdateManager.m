/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_UPDATES

#import <sys/sysctl.h>

#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITUpdateManagerPrivate.h"
#import "BITUpdateViewControllerPrivate.h"
#import "BITAppVersionMetaInfo.h"

typedef NS_ENUM(NSInteger, BITUpdateAlertViewTag) {
  BITUpdateAlertViewTagDefaultUpdate = 0,
  BITUpdateAlertViewTagNeverEndingAlertView = 1,
  BITUpdateAlertViewTagMandatoryUpdate = 2,
};

@implementation BITUpdateManager {
  NSString *_currentAppVersion;
  
  BITUpdateViewController *_currentHockeyViewController;
  
  BOOL _dataFound;
  BOOL _showFeedback;
  BOOL _updateAlertShowing;
  BOOL _lastCheckFailed;
  BOOL _sendUsageData;
  
  NSFileManager  *_fileManager;
  NSString       *_updateDir;
  NSString       *_usageDataFile;

  id _appDidBecomeActiveObserver;
  id _appDidEnterBackgroundObserver;
  id _networkDidBecomeReachableObserver;

  BOOL _didStartUpdateProcess;
  BOOL _didEnterBackgroundState;
  
  BOOL _firstStartAfterInstall;
  
  NSNumber *_versionID;
  NSString *_versionUUID;
  NSString *_uuid;
  
  NSString *_blockingScreenMessage;
  NSDate *_lastUpdateCheckFromBlockingScreen;
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
  if ([self isUpdateManagerDisabled]) return;
  
  // this is a special iOS 8 case for handling the case that the app is not moved to background
  // once the users accepts the iOS install alert button. Without this, the install process doesn't start.
  //
  // Important: The iOS dialog offers the user to deny installation, we can't find out which button
  // was tapped, so we assume the user agreed
  if (_didStartUpdateProcess) {
    _didStartUpdateProcess = NO;
    
    // we only care about iOS 8 or later
    if (bit_isPreiOS8Environment()) return;
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(updateManagerWillExitApp:)]) {
      [self.delegate updateManagerWillExitApp:self];
    }
    
    // for now we simply exit the app, later SDK versions might optionally show an alert with localized text
    // describing the user to press the home button to start the update process
    exit(0);
  }
  
  if (!_didEnterBackgroundState) return;
  
  _didEnterBackgroundState = NO;
  
  [self checkExpiryDateReached];
  if ([self expiryDateReached]) return;
  
  [self startUsage];

  if ([self isCheckForUpdateOnLaunch] && [self shouldCheckForUpdates]) {
    [self checkForUpdate];
  }
}

- (void)didEnterBackgroundActions {
  _didEnterBackgroundState = NO;
  
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
    _didEnterBackgroundState = YES;
  }
}


#pragma mark - Observers
- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  if(nil == _appDidEnterBackgroundObserver) {
    _appDidEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf didEnterBackgroundActions];
                                                                                }];
  }
  if(nil == _appDidBecomeActiveObserver) {
    _appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                     object:nil
                                                                                      queue:NSOperationQueue.mainQueue
                                                                                 usingBlock:^(NSNotification *note) {
                                                                                   typeof(self) strongSelf = weakSelf;
                                                                                   [strongSelf didBecomeActiveActions];
                                                                                 }];
  }
  if(nil == _networkDidBecomeReachableObserver) {
    _networkDidBecomeReachableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:BITHockeyNetworkDidBecomeReachableNotification
                                                                                     object:nil
                                                                                      queue:NSOperationQueue.mainQueue
                                                                                 usingBlock:^(NSNotification *note) {
                                                                                   typeof(self) strongSelf = weakSelf;
                                                                                   [strongSelf didBecomeActiveActions];
                                                                                 }];
  }
}

- (void) unregisterObservers {
  if(_appDidEnterBackgroundObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidEnterBackgroundObserver];
    _appDidEnterBackgroundObserver = nil;
  }
  if(_appDidBecomeActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidBecomeActiveObserver];
    _appDidBecomeActiveObserver = nil;
  }
  if(_networkDidBecomeReachableObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_networkDidBecomeReachableObserver];
    _networkDidBecomeReachableObserver = nil;
  }
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
    if (!_blockingScreenMessage)
      _blockingScreenMessage = [NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateExpired"), appName];
    [self showBlockingScreen:_blockingScreenMessage image:@"authorize_denied.png"];

    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(didDisplayExpiryAlertForUpdateManager:)]) {
      [self.delegate didDisplayExpiryAlertForUpdateManager:self];
    }
    
    // the UI is now blocked, make sure we don't add our UI on top of it over and over again
    [self unregisterObservers];
  }
}

#pragma mark - Usage

- (void)loadAppVersionUsageData {
  self.currentAppVersionUsageTime = @0;
  
  if ([self expiryDateReached]) return;
  
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
    [self storeUsageTimeForCurrentVersion:[NSNumber numberWithDouble:0]];
  } else {
    if (![_fileManager fileExistsAtPath:_usageDataFile])
      return;
    
    NSData *codedData = [[NSData alloc] initWithContentsOfFile:_usageDataFile];
    if (codedData == nil) return;
    
    NSKeyedUnarchiver *unarchiver = nil;
    
    @try {
      unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
    }
    @catch (NSException *exception) {
      return;
    }
    
    if ([unarchiver containsValueForKey:kBITUpdateUsageTimeOfCurrentVersion]) {
      self.currentAppVersionUsageTime = [unarchiver decodeObjectForKey:kBITUpdateUsageTimeOfCurrentVersion];
    }
    
    [unarchiver finishDecoding];
  }
}

- (void)startUsage {
  if ([self expiryDateReached]) return;
  
  self.usageStartTimestamp = [NSDate date];
}

- (void)stopUsage {
  if ([self isAppStoreEnvironment]) return;
  if ([self expiryDateReached]) return;
  
  double timeDifference = [[NSDate date] timeIntervalSinceReferenceDate] - [_usageStartTimestamp timeIntervalSinceReferenceDate];
  double previousTimeDifference = [self.currentAppVersionUsageTime doubleValue];
  
  [self storeUsageTimeForCurrentVersion:[NSNumber numberWithDouble:previousTimeDifference + timeDifference]];
}

- (void) storeUsageTimeForCurrentVersion:(NSNumber *)usageTime {
  if ([self isAppStoreEnvironment]) return;
  
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  
  [archiver encodeObject:usageTime forKey:kBITUpdateUsageTimeOfCurrentVersion];
  
  [archiver finishEncoding];
  [data writeToFile:_usageDataFile atomically:YES];
  
  self.currentAppVersionUsageTime = usageTime;
}

- (NSString *)currentUsageString {
  double currentUsageTime = [self.currentAppVersionUsageTime doubleValue];
  
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


#pragma mark - Cache

- (void)checkUpdateAvailable {
  // check if there is an update available
  NSComparisonResult comparisonResult = bit_versionCompare(self.newestAppVersion.version, self.currentAppVersion);
  
  if (comparisonResult == NSOrderedDescending) {
    self.updateAvailable = YES;
  } else if (comparisonResult == NSOrderedSame) {
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


#pragma mark - Init

- (instancetype)init {
  if ((self = [super init])) {
    _delegate = nil;
    _expiryDate = nil;
    _checkInProgress = NO;
    _dataFound = NO;
    _updateAvailable = NO;
    _lastCheckFailed = NO;
    _currentAppVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    _blockingView = nil;
    _lastCheck = nil;
    _uuid = [[self executableUUID] copy];
    _versionUUID = nil;
    _versionID = nil;
    _sendUsageData = YES;
    _disableUpdateManager = NO;
    _firstStartAfterInstall = NO;
    _companyName = nil;
    _currentAppVersionUsageTime = @0;
    
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
    
    if (!BITHockeyBundle()) {
      NSLog(@"[HockeySDK] WARNING: %@ is missing, make sure it is added!", BITHOCKEYSDK_BUNDLE);
    }
    
    _fileManager = [[NSFileManager alloc] init];
    
    _usageDataFile = [bit_settingsDir() stringByAppendingPathComponent:BITHOCKEY_USAGE_DATA];
    
    [self loadAppCache];
    
    _installationIdentification = [self stringValueFromKeychainForKey:kBITUpdateInstallationIdentification];
    
    [self loadAppVersionUsageData];
    [self startUsage];

    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillTerminateNotification object:nil];
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillResignActiveNotification object:nil];
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
  
  [_urlConnection cancel];
}


#pragma mark - BetaUpdateUI

- (BITUpdateViewController *)hockeyViewController:(BOOL)modal {
  if ([self isAppStoreEnvironment]) {
    NSLog(@"[HockeySDK] This should not be called from an app store build!");
    // return an empty view controller instead
    BITHockeyBaseViewController *blankViewController = [[BITHockeyBaseViewController alloc] initWithModalStyle:modal];
    return (BITUpdateViewController *)blankViewController;
  }
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
  
  if ([self isPreiOS7Environment])
    self.barStyle = UIBarStyleBlack;
  
  BITUpdateViewController *updateViewController = [self hockeyViewController:YES];
  if ([self hasNewerMandatoryVersion] || [self expiryDateReached]) {
    [updateViewController setMandatoryUpdate: YES];
  }
  [self showView:updateViewController];
}


- (void)showCheckForUpdateAlert {
  if ([self isAppStoreEnvironment]) return;
  if ([self isUpdateManagerDisabled]) return;
  
  if (!_updateAlertShowing) {
    if ([self hasNewerMandatoryVersion]) {
      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateAvailable")
                                                           message:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateAlertMandatoryTextWithAppVersion"), [self.newestAppVersion nameAndVersionString]]
                                                          delegate:self
                                                 cancelButtonTitle:nil
                                                 otherButtonTitles:BITHockeyLocalizedString(@"UpdateShow"), BITHockeyLocalizedString(@"UpdateInstall"), nil
                                 ];
      [alertView setTag:BITUpdateAlertViewTagMandatoryUpdate];
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
      [alertView setTag:BITUpdateAlertViewTagDefaultUpdate];
      [alertView show];
      _updateAlertShowing = YES;
    }
  }
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
  
  if (!self.disableUpdateCheckOptionWhenExpired) {
    UIButton *checkForUpdateButton = [UIButton buttonWithType:kBITButtonTypeSystem];
    checkForUpdateButton.frame = CGRectMake((frame.size.width - 140) / 2.f, frame.size.height - 100, 140, 25);
    [checkForUpdateButton setTitle:BITHockeyLocalizedString(@"UpdateButtonCheck") forState:UIControlStateNormal];
    [checkForUpdateButton addTarget:self
                             action:@selector(checkForUpdateForExpiredVersion)
                   forControlEvents:UIControlEventTouchUpInside];
    [self.blockingView addSubview:checkForUpdateButton];
  }
  
  if (message != nil) {
    frame.origin.x = 20;
    frame.origin.y = frame.size.height - 180;
    frame.size.width -= 40;
    frame.size.height = 70;
    
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = message;
    label.textAlignment = kBITTextLabelAlignmentCenter;
    label.numberOfLines = 3;
    label.adjustsFontSizeToFitWidth = YES;
    label.backgroundColor = [UIColor clearColor];
    
    [self.blockingView addSubview:label];
  }
  
  [visibleWindow addSubview:self.blockingView];
}

- (void)checkForUpdateForExpiredVersion {
  if (!self.checkInProgress) {
    
    if (!_lastUpdateCheckFromBlockingScreen ||
        fabs([NSDate timeIntervalSinceReferenceDate] - [_lastUpdateCheckFromBlockingScreen timeIntervalSinceReferenceDate]) > 60) {
      _lastUpdateCheckFromBlockingScreen = [NSDate date];
      [self checkForUpdateShowFeedback:NO];
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
  
  if (!self.disableUpdateCheckOptionWhenExpired && [message isEqualToString:_blockingScreenMessage]) {
    [alertView addButtonWithTitle:BITHockeyLocalizedString(@"UpdateButtonCheck")];
  }
  
  [alertView setTag:BITUpdateAlertViewTagNeverEndingAlertView];
  [alertView show];
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

- (void)checkForUpdate {
  if (![self isAppStoreEnvironment] && ![self isUpdateManagerDisabled]) {
    if ([self expiryDateReached]) return;
    if (![self installationIdentified]) return;
    
    if (self.isUpdateAvailable && [self hasNewerMandatoryVersion]) {
      [self showCheckForUpdateAlert];
    }
    
    [self checkForUpdateShowFeedback:NO];
  }
}

- (void)checkForUpdateShowFeedback:(BOOL)feedback {
  if ([self isAppStoreEnvironment]) return;
  if (self.isCheckInProgress) return;
  
  _showFeedback = feedback;
  self.checkInProgress = YES;
  
  // do we need to update?
  if (!_currentHockeyViewController && ![self shouldCheckForUpdates] && _updateSetting != BITUpdateCheckManually) {
    BITHockeyLog(@"INFO: Update not needed right now");
    self.checkInProgress = NO;
    return;
  }
  
  NSMutableString *parameter = [NSMutableString stringWithFormat:@"api/2/apps/%@?format=json&extended=true%@&sdk=%@&sdk_version=%@&uuid=%@",
                                bit_URLEncodedString([self encodedAppIdentifier]),
                                ([self isAppStoreEnvironment] ? @"&udid=appstore" : @""),
                                BITHOCKEY_NAME,
                                BITHOCKEY_VERSION,
                                _uuid];
  
  // add installationIdentificationType and installationIdentifier if available
  if (self.installationIdentification && self.installationIdentificationType) {
    [parameter appendFormat:@"&%@=%@",
     bit_URLEncodedString(self.installationIdentificationType),
     bit_URLEncodedString(self.installationIdentification)
     ];
  }
  
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

#else
  
  NSString *extraParameter = [NSString string];
  if (_sendUsageData && self.installationIdentification && self.installationIdentificationType) {
    extraParameter = [NSString stringWithFormat:@"&%@=%@",
                      bit_URLEncodedString(self.installationIdentificationType),
                      bit_URLEncodedString(self.installationIdentification)
                      ];
  }
  
  NSString *hockeyAPIURL = [NSString stringWithFormat:@"%@api/2/apps/%@/app_versions/%@?format=plist%@", self.serverURL, [self encodedAppIdentifier], [self.newestAppVersion.versionID stringValue], extraParameter];
  NSString *iOSUpdateURL = [NSString stringWithFormat:@"itms-services://?action=download-manifest&url=%@", bit_URLEncodedString(hockeyAPIURL)];

  // Notify delegate of update intent before placing the call
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(willStartDownloadAndUpdate:)]) {
    [self.delegate willStartDownloadAndUpdate:self];
  }

  BITHockeyLog(@"INFO: API Server Call: %@, calling iOS with %@", hockeyAPIURL, iOSUpdateURL);
  BOOL success = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iOSUpdateURL]];
  BITHockeyLog(@"INFO: System returned: %d", success);
  
  _didStartUpdateProcess = success;
  
  return success;

#endif
}


// begin the startup process
- (void)startManager {
  if (![self isAppStoreEnvironment]) {
    if ([self isUpdateManagerDisabled]) return;
    
    BITHockeyLog(@"INFO: Starting UpdateManager");
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(updateManagerShouldSendUsageData:)]) {
      _sendUsageData = [self.delegate updateManagerShouldSendUsageData:self];
    }
    
    [self checkExpiryDateReached];
    if (![self expiryDateReached]) {
      if ([self isCheckForUpdateOnLaunch] && [self shouldCheckForUpdates]) {
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) return;
        
        [self performSelector:@selector(checkForUpdate) withObject:nil afterDelay:1.0f];
      }
    }
  }
  [self registerObservers];
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
    NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
    if (statusCode == 404) {
      [connection cancel];  // stop connecting; no more delegate messages
      NSString *errorStr = [NSString stringWithFormat:@"Hockey API received HTTP Status Code %ld", (long)statusCode];
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
  if ([self expiryDateReached]) {
    if (!self.blockingView) {
      [self alertFallback:_blockingScreenMessage];
    }
  } else {
    [self reportError:error];
  }
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
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    
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
          // check if minOSVersion is set and this device qualifies
          BOOL deviceOSVersionQualifies = YES;
          if ([appVersionMetaInfo minOSVersion] && ![[appVersionMetaInfo minOSVersion] isKindOfClass:[NSNull class]]) {
            NSComparisonResult comparisonResult = bit_versionCompare(appVersionMetaInfo.minOSVersion, [[UIDevice currentDevice] systemVersion]);
            if (comparisonResult == NSOrderedDescending) {
              deviceOSVersionQualifies = NO;
            }
          }
          
          if (deviceOSVersionQualifies)
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
  } else if (![self expiryDateReached]) {
    [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                          code:BITUpdateAPIServerReturnedEmptyResponse
                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned an empty response.", NSLocalizedDescriptionKey, nil]]];
  }
  
  if (!_updateAlertShowing && [self expiryDateReached] && !self.blockingView) {
    [self alertFallback:_blockingScreenMessage];
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

- (void)setInstallationIdentificationType:(NSString *)installationIdentificationType {
  if (![_installationIdentificationType isEqualToString:installationIdentificationType]) {
    // we already use "uuid" in our requests for providing the binary UUID to the server
    // so we need to stick to "udid" even when BITAuthenticator is providing a plain uuid
    if ([installationIdentificationType isEqualToString:@"uuid"]) {
      _installationIdentificationType = @"udid";
    } else {
      _installationIdentificationType = installationIdentificationType;
    }
  }
}

- (void)setInstallationIdentification:(NSString *)installationIdentification {
  if (![_installationIdentification isEqualToString:installationIdentification]) {
    if (installationIdentification) {
      [self addStringValueToKeychain:installationIdentification forKey:kBITUpdateInstallationIdentification];
    } else {
      [self removeKeyFromKeychain:kBITUpdateInstallationIdentification];
    }
    _installationIdentification = installationIdentification;
    
    // we need to reset the usage time, because the user/device may have changed
    [self storeUsageTimeForCurrentVersion:[NSNumber numberWithDouble:0]];
    self.usageStartTimestamp = [NSDate date];
  }
}


#pragma mark - UIAlertViewDelegate

// invoke the selected action from the action sheet for a location element
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if ([alertView tag] == BITUpdateAlertViewTagNeverEndingAlertView) {
    if (buttonIndex == 1) {
      [self checkForUpdateForExpiredVersion];
    } else {
      [self alertFallback:_blockingScreenMessage];
    }
    return;
  }
  
  _updateAlertShowing = NO;
  if (buttonIndex == [alertView firstOtherButtonIndex]) {
    // YES button has been clicked
    if (self.blockingView) {
      [self.blockingView removeFromSuperview];
    }
    [self showUpdateView];
  } else if (buttonIndex == [alertView firstOtherButtonIndex] + 1) {
    // YES button has been clicked
    (void)[self initiateAppDownload];
  } else {
    if ([self expiryDateReached] && !self.blockingView) {
      [self alertFallback:_blockingScreenMessage];
    }
  }
}

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
