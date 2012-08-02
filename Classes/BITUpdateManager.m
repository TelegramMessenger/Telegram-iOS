/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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
#import <mach-o/ldsyms.h>
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITUpdateManagerPrivate.h"
#import "BITUpdateViewControllerPrivate.h"
#import "BITAppVersionMetaInfo.h"

#import "NSString+BITHockeyAdditions.h"
#import "UIImage+BITHockeyAdditions.h"


// API defines - do not change
#define BETA_DOWNLOAD_TYPE_PROFILE	@"profile"
#define BETA_UPDATE_RESULT          @"result"
#define BETA_UPDATE_TITLE           @"title"
#define BETA_UPDATE_SUBTITLE        @"subtitle"
#define BETA_UPDATE_NOTES           @"notes"
#define BETA_UPDATE_VERSION         @"version"
#define BETA_UPDATE_TIMESTAMP       @"timestamp"
#define BETA_UPDATE_APPSIZE         @"appsize"


@implementation BITUpdateManager

@synthesize delegate = _delegate;

@synthesize urlConnection = _urlConnection;
@synthesize checkInProgress = _checkInProgress;
@synthesize receivedData = _receivedData;
@synthesize alwaysShowUpdateReminder = _showUpdateReminder;
@synthesize checkForUpdateOnLaunch = _checkForUpdateOnLaunch;
@synthesize compareVersionType = _compareVersionType;
@synthesize lastCheck = _lastCheck;
@synthesize updateSetting = _updateSetting;
@synthesize appVersions = _appVersions;
@synthesize updateAvailable = _updateAvailable;
@synthesize usageStartTimestamp = _usageStartTimestamp;
@synthesize currentHockeyViewController = _currentHockeyViewController;
@synthesize showDirectInstallOption = _showDirectInstallOption;
@synthesize requireAuthorization = _requireAuthorization;
@synthesize authenticationSecret = _authenticationSecret;
@synthesize authorizeView = _authorizeView;
@synthesize checkForTracker = _checkForTracker;
@synthesize trackerConfig = _trackerConfig;
@synthesize barStyle = _barStyle;
@synthesize modalPresentationStyle = _modalPresentationStyle;


#pragma mark - private

- (void)reportError:(NSError *)error {
  BITHockeyLog(@"Error: %@", [error localizedDescription]);
  _lastCheckFailed = YES;
  
  // only show error if we enable that
  if (_showFeedback) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateError")
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:BITHockeyLocalizedString(@"OK") otherButtonTitles:nil];
    [alert show];
    [alert release];
    _showFeedback = NO;
  }
}

- (NSString *)encodedAppIdentifier {
  return (_appIdentifier ? [_appIdentifier bit_URLEncodedString] : [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] bit_URLEncodedString]);
}

- (NSString *)getDevicePlatform {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *answer = (char*)malloc(size);
  sysctlbyname("hw.machine", answer, &size, NULL, 0);
  NSString *platform = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
  free(answer);
  return platform;
}

- (NSString *)executableUUID {
  const uint8_t *command = (const uint8_t *)(&_mh_execute_header + 1);
  for (uint32_t idx = 0; idx < _mh_execute_header.ncmds; ++idx) {
    const struct load_command *load_command = (const struct load_command *)command;
    if (load_command->cmd == LC_UUID) {
      const struct uuid_command *uuid_command = (const struct uuid_command *)command;
      const uint8_t *uuid = uuid_command->uuid;
      return [[NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
               uuid[0], uuid[1], uuid[2], uuid[3],
               uuid[4], uuid[5], uuid[6], uuid[7],
               uuid[8], uuid[9], uuid[10], uuid[11],
               uuid[12], uuid[13], uuid[14], uuid[15]]
              lowercaseString];
    } else {
      command += load_command->cmdsize;
    }
  }
  return nil;
}

- (void)startUsage {
  self.usageStartTimestamp = [NSDate date];
  BOOL newVersion = NO;
  
  if (![[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForVersionString]) {
    newVersion = YES;
  } else {
    if ([(NSString *)[[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForVersionString] compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] != NSOrderedSame) {
      newVersion = YES;
    }
  }
  
  if (newVersion) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]] forKey:kBITUpdateDateOfVersionInstallation];
    [[NSUserDefaults standardUserDefaults] setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:kBITUpdateUsageTimeForVersionString];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:0] forKey:kBITUpdateUsageTimeOfCurrentVersion];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }    
}

- (void)stopUsage {
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
  NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
  [formatter setDateFormat:@"MM/dd/yyyy"];
  double installationTimeStamp = [[NSUserDefaults standardUserDefaults] doubleForKey:kBITUpdateDateOfVersionInstallation];
  if (installationTimeStamp == 0.0f) {
    return [formatter stringFromDate:[NSDate date]];
  } else {
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:installationTimeStamp]];
  }
}

- (NSString *)deviceIdentifier {
  if ([_delegate respondsToSelector:@selector(customDeviceIdentifierForUpdateManager:)]) {
    NSString *identifier = [_delegate performSelector:@selector(customDeviceIdentifierForUpdateManager:) withObject:self];
    if (identifier && [identifier length] > 0) {
      return identifier;
    }
  }
  
  return @"invalid";
}

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

- (void)checkUpdateAvailable {
  // check if there is an update available
  if (self.compareVersionType == BITUpdateComparisonResultGreater) {
    self.updateAvailable = ([self.newestAppVersion.version bit_versionCompare:self.currentAppVersion] == NSOrderedDescending);
  } else {
    self.updateAvailable = ([self.newestAppVersion.version compare:self.currentAppVersion] != NSOrderedSame);
  }
}

- (void)loadAppCache {
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
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.appVersions];
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:kBITUpdateArrayOfLastCheck];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

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
        BITHockeyLog(@"UIWindow with rootViewController found: %@", visibleWindow);
        break;
      }
    }
  }
  
  return visibleWindow;
}


#pragma mark - Init

- (id)initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironemt:(BOOL)isAppStoreEnvironment {
  if ((self = [super init])) {
    _appIdentifier = appIdentifier;
    _isAppStoreEnvironment = isAppStoreEnvironment;
    
    _delegate = nil;
    _checkInProgress = NO;
    _dataFound = NO;
    _updateAvailable = NO;
    _lastCheckFailed = NO;
    _currentAppVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    _navController = nil;
    _authorizeView = nil;
    _requireAuthorization = NO;
    _authenticationSecret = nil;
    _lastCheck = nil;
    _uuid = [[self executableUUID] retain];
    _sendUsageData = YES;
    
    // set defaults
    self.showDirectInstallOption = NO;
    self.requireAuthorization = NO;
    self.alwaysShowUpdateReminder = YES;
    self.checkForUpdateOnLaunch = YES;
    self.compareVersionType = BITUpdateComparisonResultGreater;
    self.barStyle = UIBarStyleDefault;
    self.modalPresentationStyle = UIModalPresentationFormSheet;
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
      NSLog(@"WARNING: %@ is missing, make sure it is added!", BITHOCKEYSDK_BUNDLE);
    }
    
    [self loadAppCache];
    
    [self startUsage];

    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(startManager) name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
    
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillTerminateNotification object:nil];
    [dnc addObserver:self selector:@selector(startUsage) name:UIApplicationDidBecomeActiveNotification object:nil];
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillResignActiveNotification object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyNetworkDidBecomeReachableNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
  
  _delegate = nil;
  
  [_urlConnection cancel];
  self.urlConnection = nil;
  
  [_navController release];
  [_authorizeView release];
  [_currentHockeyViewController release];
  [_appVersions release];
  [_receivedData release];
  [_lastCheck release];
  [_usageStartTimestamp release];
  [_authenticationSecret release];
  [_uuid release];
  
  [super dealloc];
}


#pragma mark - BetaUpdateUI

- (BITUpdateViewController *)hockeyViewController:(BOOL)modal {
  return [[[BITUpdateViewController alloc] init:self modal:modal] autorelease];
}

- (void)showUpdateView {
  if (_isAppStoreEnvironment) {
    NSLog(@"this should not be called from an app store build.");
    return;
  }
  
  if (_currentHockeyViewController) {
    BITHockeyLog(@"update view already visible, aborting");
    return;
  }
  
  UIViewController *parentViewController = nil;
  
  if ([[self delegate] respondsToSelector:@selector(viewControllerForUpdateManager:)]) {
    parentViewController = [_delegate viewControllerForUpdateManager:self];
  }
  
  UIWindow *visibleWindow = [self findVisibleWindow];
  
  if (parentViewController == nil && [UIWindow instancesRespondToSelector:@selector(rootViewController)]) {
    parentViewController = [visibleWindow rootViewController];
  }
  
  // use topmost modal view
  while (parentViewController.modalViewController) {
    parentViewController = parentViewController.modalViewController;
  }
  
  // special addition to get rootViewController from three20 which has it's own controller handling
  if (NSClassFromString(@"TTNavigator")) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    parentViewController = [[NSClassFromString(@"TTNavigator") performSelector:(NSSelectorFromString(@"navigator"))] visibleViewController];
#pragma clang diagnostic pop
  }
  
  if (_navController != nil) [_navController release];
  
  BITUpdateViewController *hockeyViewController = [self hockeyViewController:YES];    
  _navController = [[UINavigationController alloc] initWithRootViewController:hockeyViewController];
  _navController.navigationBar.barStyle = _barStyle;
  _navController.modalPresentationStyle = _modalPresentationStyle;
  
  if (parentViewController) {
    if ([_navController respondsToSelector:@selector(setModalTransitionStyle:)]) {
      _navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    
    // page sheet for the iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [_navController respondsToSelector:@selector(setModalPresentationStyle:)]) {
      _navController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    hockeyViewController.modalAnimated = YES;
    
    [parentViewController presentModalViewController:_navController animated:YES];
  } else {
    // if not, we add a subview to the window. A bit hacky but should work in most circumstances.
    // Also, we don't get a nice animation for free, but hey, this is for beta not production users ;)
    NSLog(@"Warning: No rootViewController found and no view controller set via delegate, using UIWindow-approach: %@", visibleWindow);
    hockeyViewController.modalAnimated = NO;
    [visibleWindow addSubview:_navController.view];
  }
}


- (void)showCheckForUpdateAlert {
  if (_isAppStoreEnvironment) return;
  
  if (!_updateAlertShowing) {
    if ([self hasNewerMandatoryVersion]) {
      UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateAvailable")
                                                           message:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateAlertMandatoryTextWithAppVersion"), [self.newestAppVersion nameAndVersionString]]
                                                          delegate:self
                                                 cancelButtonTitle:BITHockeyLocalizedString(@"UpdateInstall")
                                                 otherButtonTitles:nil
                                 ] autorelease];
      [alertView setTag:2];
      [alertView show];
      _updateAlertShowing = YES;
    } else {
      UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateAvailable")
                                                           message:[NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateAlertTextWithAppVersion"), [self.newestAppVersion nameAndVersionString]]
                                                          delegate:self
                                                 cancelButtonTitle:BITHockeyLocalizedString(@"UpdateIgnore")
                                                 otherButtonTitles:BITHockeyLocalizedString(@"UpdateShow"), nil
                                 ] autorelease];
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
  UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:nil
                                                       message:message
                                                      delegate:self
                                             cancelButtonTitle:@"Ok"
                                             otherButtonTitles:nil
                             ] autorelease];
  [alertView setTag:1];
  [alertView show];    
}


// open an authorization screen
- (void)showAuthorizationScreen:(NSString *)message image:(NSString *)image {
  self.authorizeView = nil;
  
  UIWindow *visibleWindow = [self findVisibleWindow];
  if (visibleWindow == nil) {
    [self alertFallback:message];
    return;
  }
  
  CGRect frame = [visibleWindow frame];
  
  self.authorizeView = [[[UIView alloc] initWithFrame:frame] autorelease];
  UIImageView *backgroundView = [[[UIImageView alloc] initWithImage:[UIImage bit_imageNamed:@"bg.png" bundle:BITHOCKEYSDK_BUNDLE]] autorelease];
  backgroundView.contentMode = UIViewContentModeScaleAspectFill;
  backgroundView.frame = frame;
  [self.authorizeView addSubview:backgroundView];
  
  if (image != nil) {
    UIImageView *imageView = [[[UIImageView alloc] initWithImage:[UIImage bit_imageNamed:image bundle:BITHOCKEYSDK_BUNDLE]] autorelease];
    imageView.contentMode = UIViewContentModeCenter;
    imageView.frame = frame;
    [self.authorizeView addSubview:imageView];
  }
  
  if (message != nil) {
    frame.origin.x = 20;
    frame.origin.y = frame.size.height - 140;
    frame.size.width -= 40;
    frame.size.height = 40;
    
    UILabel *label = [[[UILabel alloc] initWithFrame:frame] autorelease];
    label.text = message;
    label.textAlignment = UITextAlignmentCenter;
    label.numberOfLines = 2;
    label.backgroundColor = [UIColor clearColor];
    
    [self.authorizeView addSubview:label];
  }
  
  [visibleWindow addSubview:self.authorizeView];
}


#pragma mark - JSONParsing

- (id)parseJSONResultString:(NSString *)jsonString {
  NSError *error = nil;
  id feedResult = nil;
  
  if (!jsonString)
    return nil;

#if BITHOCKEYSDK_NATIVE_JSON_AVAILABLE
  feedResult = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
#else
  id nsjsonClass = NSClassFromString(@"NSJSONSerialization");
  SEL nsjsonSelect = NSSelectorFromString(@"JSONObjectWithData:options:error:");
  SEL sbJSONSelector = NSSelectorFromString(@"JSONValue");
  SEL jsonKitSelector = NSSelectorFromString(@"objectFromJSONStringWithParseOptions:error:");
  SEL yajlSelector = NSSelectorFromString(@"yajl_JSONWithOptions:error:");
  
  if (nsjsonClass && [nsjsonClass respondsToSelector:nsjsonSelect]) {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[nsjsonClass methodSignatureForSelector:nsjsonSelect]];
    invocation.target = nsjsonClass;
    invocation.selector = nsjsonSelect;
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

    if (!jsonData)
      return nil;

    [invocation setArgument:&jsonData atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
    NSUInteger readOptions = kNilOptions;
    [invocation setArgument:&readOptions atIndex:3];
    [invocation setArgument:&error atIndex:4];
    [invocation invoke];
    [invocation getReturnValue:&feedResult];
  } else if (jsonKitSelector && [jsonString respondsToSelector:jsonKitSelector]) {
    // first try JSONkit
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jsonString methodSignatureForSelector:jsonKitSelector]];
    invocation.target = jsonString;
    invocation.selector = jsonKitSelector;
    int parseOptions = 0;
    [invocation setArgument:&parseOptions atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
    [invocation setArgument:&error atIndex:3];
    [invocation invoke];
    [invocation getReturnValue:&feedResult];
  } else if (sbJSONSelector && [jsonString respondsToSelector:sbJSONSelector]) {
    // now try SBJson
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jsonString methodSignatureForSelector:sbJSONSelector]];
    invocation.target = jsonString;
    invocation.selector = sbJSONSelector;
    [invocation invoke];
    [invocation getReturnValue:&feedResult];
  } else if (yajlSelector && [jsonString respondsToSelector:yajlSelector]) {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jsonString methodSignatureForSelector:yajlSelector]];
    invocation.target = jsonString;
    invocation.selector = yajlSelector;
    
    NSUInteger yajlParserOptions = 0;
    [invocation setArgument:&yajlParserOptions atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
    [invocation setArgument:&error atIndex:3];
    
    [invocation invoke];
    [invocation getReturnValue:&feedResult];
  } else {
    error = [NSError errorWithDomain:kBITUpdateErrorDomain
                                code:BITUpdateAPIServerReturnedEmptyResponse
                            userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"You need a JSON Framework in your runtime for iOS4!", NSLocalizedDescriptionKey, nil]];
  }
#endif
  
  if (error) {
    [self reportError:error];
    return nil;
  }
  
  return feedResult;
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
   [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] bit_URLEncodedString],
   (_isAppStoreEnvironment ? @"appstore" : [[self deviceIdentifier] bit_URLEncodedString]),
   BITHOCKEY_NAME,
   BITHOCKEY_VERSION,
   _uuid
   ];
  
  // build request & send
  NSString *url = [NSString stringWithFormat:@"%@%@", BITHOCKEYSDK_URL, parameter];
  BITHockeyLog(@"sending api request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:1 timeoutInterval:10.0];
  [request setHTTPMethod:@"GET"];
  [request setValue:@"Hockey/iOS" forHTTPHeaderField:@"User-Agent"];
  
  NSURLResponse *response = nil;
  NSError *error = NULL;
  BOOL failed = YES;
  
  NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
  
  if ([responseData length]) {
    NSString *responseString = [[[NSString alloc] initWithBytes:[responseData bytes] length:[responseData length] encoding: NSUTF8StringEncoding] autorelease];
    
    NSDictionary *feedDict = (NSDictionary *)[self parseJSONResultString:responseString];
    
    // server returned empty response?
    if (![feedDict count]) {
      [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                            code:BITUpdateAPIServerReturnedEmptyResponse
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned empty response.", NSLocalizedDescriptionKey, nil]]];
      return;
    } else {
      BITHockeyLog(@"Received API response: %@", responseString);
      NSString *token = [[feedDict objectForKey:@"authcode"] lowercaseString];
      failed = NO;
      if ([[self authenticationToken] compare:token] == NSOrderedSame) {
        // identical token, activate this version
        
        // store the new data
        [[NSUserDefaults standardUserDefaults] setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:kBITUpdateAuthorizedVersion];
        [[NSUserDefaults standardUserDefaults] setObject:token forKey:kBITUpdateAuthorizedVersion];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        self.requireAuthorization = NO;
        self.authorizeView = nil;
        
        // now continue with an update check right away
        if (self.checkForUpdateOnLaunch) {
          [self checkForUpdate];
        }
      } else {
        // different token, block this version
        BITHockeyLog(@"AUTH FAILURE: %@", [self authenticationToken]);
        
        // store the new data
        [[NSUserDefaults standardUserDefaults] setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:kBITUpdateAuthorizedVersion];
        [[NSUserDefaults standardUserDefaults] setObject:token forKey:kBITUpdateAuthorizedVersion];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self showAuthorizationScreen:BITHockeyLocalizedString(@"UpdateAuthorizationDenied") image:@"authorize_denied.png"];
      }
    }
    
  }
  
  if (failed) {
    [self showAuthorizationScreen:BITHockeyLocalizedString(@"UpdateAuthorizationOffline") image:@"authorize_request.png"];
  }
}

- (void)checkForUpdate {
  if (_isAppStoreEnvironment && !_checkForTracker) return;
  
  if (self.requireAuthorization) return;
  if (self.isUpdateAvailable && [self hasNewerMandatoryVersion]) {
    [self showCheckForUpdateAlert];
  }
  [self checkForUpdateShowFeedback:NO];
}

- (void)checkForUpdateShowFeedback:(BOOL)feedback {
  if (self.isCheckInProgress) return;
  
  _showFeedback = feedback;
  self.checkInProgress = YES;
  
  // do we need to update?
  if (![self shouldCheckForUpdates] && !_currentHockeyViewController) {
    BITHockeyLog(@"update not needed right now");
    self.checkInProgress = NO;
    return;
  }
  
  NSMutableString *parameter = [NSMutableString stringWithFormat:@"api/2/apps/%@?format=json&udid=%@&sdk=%@&sdk_version=%@&uuid=%@", 
                                [[self encodedAppIdentifier] bit_URLEncodedString],
                                (_isAppStoreEnvironment ? @"appstore" : [[self deviceIdentifier] bit_URLEncodedString]),
                                BITHOCKEY_NAME,
                                BITHOCKEY_VERSION,
                                _uuid];
  
  // add additional statistics if user didn't disable flag
  if (_sendUsageData) {
    [parameter appendFormat:@"&app_version=%@&os=iOS&os_version=%@&device=%@&lang=%@&first_start_at=%@&usage_time=%@",
     [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] bit_URLEncodedString],
     [[[UIDevice currentDevice] systemVersion] bit_URLEncodedString],
     [[self getDevicePlatform] bit_URLEncodedString],
     [[[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0] bit_URLEncodedString],
     [[self installationDateString] bit_URLEncodedString],
     [[self currentUsageString] bit_URLEncodedString]
     ];
  }
  
  if ([self checkForTracker]) {
    [parameter appendFormat:@"&jmc=yes"];
  }
  
  // build request & send
  NSString *url = [NSString stringWithFormat:@"%@%@", BITHOCKEYSDK_URL, parameter];
  BITHockeyLog(@"sending api request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:1 timeoutInterval:10.0];
  [request setHTTPMethod:@"GET"];
  [request setValue:@"Hockey/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  self.urlConnection = [[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
  if (!_urlConnection) {
    self.checkInProgress = NO;
    [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                          code:BITUpdateAPIClientCannotCreateConnection
                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Url Connection could not be created.", NSLocalizedDescriptionKey, nil]]];
  }
}

- (BOOL)initiateAppDownload {
  if (_isAppStoreEnvironment) return NO;
  
  if (!self.isUpdateAvailable) {
    BITHockeyLog(@"Warning: No update available. Aborting.");
    return NO;
  }
  
#if TARGET_IPHONE_SIMULATOR
  UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"UpdateWarning") message:BITHockeyLocalizedString(@"UpdateSimulatorMessage") delegate:nil cancelButtonTitle:BITHockeyLocalizedString(@"HockeyOK") otherButtonTitles:nil] autorelease];
  [alert show];
  return NO;
#endif
  
  NSString *extraParameter = [NSString string];
  if (_sendUsageData) {
    extraParameter = [NSString stringWithFormat:@"&udid=%@", [self deviceIdentifier]];
  }
  
  NSString *hockeyAPIURL = [NSString stringWithFormat:@"%@api/2/apps/%@?format=plist%@", BITHOCKEYSDK_URL, [self encodedAppIdentifier], extraParameter];
  NSString *iOSUpdateURL = [NSString stringWithFormat:@"itms-services://?action=download-manifest&url=%@", [hockeyAPIURL bit_URLEncodedString]];
  
  BITHockeyLog(@"API Server Call: %@, calling iOS with %@", hockeyAPIURL, iOSUpdateURL);
  BOOL success = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iOSUpdateURL]];
  BITHockeyLog(@"System returned: %d", success);
  return success;
}


// checks wether this app version is authorized
- (BOOL)appVersionIsAuthorized {
  if (self.requireAuthorization && !_authenticationSecret) {
    [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                          code:BITUpdateAPIClientAuthorizationMissingSecret
                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Authentication secret is not set but required.", NSLocalizedDescriptionKey, nil]]];
    
    return NO;
  }
  
  if (!self.requireAuthorization) {
    self.authorizeView = nil;
    return YES;
  }
  
  BITUpdateAuthorizationState state = [self authorizationState];
  if (state == BITUpdateAuthorizationDenied) {
    [self showAuthorizationScreen:BITHockeyLocalizedString(@"UpdateAuthorizationDenied") image:@"authorize_denied.png"];
  } else if (state == BITUpdateAuthorizationAllowed) {
    self.requireAuthorization = NO;
    return YES;
  }
  
  return NO;
}


// begin the startup process
- (void)startManager {
  if (![self appVersionIsAuthorized]) {
    if ([self authorizationState] == BITUpdateAuthorizationPending) {
      [self showAuthorizationScreen:BITHockeyLocalizedString(@"UpdateAuthorizationProgress") image:@"authorize_request.png"];
      
      [self performSelector:@selector(checkForAuthorization) withObject:nil afterDelay:0.0f];
    }
  } else {
    if ([self shouldCheckForUpdates]) {
      [self performSelector:@selector(checkForUpdate) withObject:nil afterDelay:1.0f];
    }
  }
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
    NSString *responseString = [[[NSString alloc] initWithBytes:[_receivedData bytes] length:[_receivedData length] encoding: NSUTF8StringEncoding] autorelease];
    BITHockeyLog(@"Received API response: %@", responseString);
    
    id json = [self parseJSONResultString:responseString];
    self.trackerConfig = (([self checkForTracker] && [[json valueForKey:@"tracker"] isKindOfClass:[NSDictionary class]]) ? [json valueForKey:@"tracker"] : nil);
    
    if (!_isAppStoreEnvironment) {
      NSArray *feedArray = (NSArray *)([self checkForTracker] ? [json valueForKey:@"versions"] : json);
      
      self.receivedData = nil;
      self.urlConnection = nil;
      
      // remember that we just checked the server
      self.lastCheck = [NSDate date];
      
      // server returned empty response?
      if (![feedArray count]) {
        [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                              code:BITUpdateAPIServerReturnedEmptyResponse
                                          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned empty response.", NSLocalizedDescriptionKey, nil]]];
        return;
      } else {
        _lastCheckFailed = NO;
      }
      
      
      NSString *currentAppCacheVersion = [[[self newestAppVersion].version copy] autorelease];
      
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
        self.appVersions = [[tmpAppVersions copy] autorelease];
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
        [alert release];
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
}

- (BOOL)hasNewerMandatoryVersion {
  BOOL result = NO;
  
  for (BITAppVersionMetaInfo *appVersion in self.appVersions) {
    if ([appVersion.version isEqualToString:self.currentAppVersion] || [appVersion.version bit_versionCompare:self.currentAppVersion] == NSOrderedAscending) {
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
    [_currentHockeyViewController release];
    _currentHockeyViewController = [aCurrentHockeyViewController retain];
    //HockeySDKLog(@"active hockey view controller: %@", aCurrentHockeyViewController);
  }
}

- (void)setCheckForUpdateOnLaunch:(BOOL)flag {
  if (_checkForUpdateOnLaunch != flag) {
    _checkForUpdateOnLaunch = flag;
    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    if (flag) {
      [dnc addObserver:self selector:@selector(checkForUpdate) name:UIApplicationDidBecomeActiveNotification object:nil];
    } else {
      [dnc removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    }
  }
}

- (NSString *)currentAppVersion {
  return _currentAppVersion;
}

- (void)setLastCheck:(NSDate *)aLastCheck {
  if (_lastCheck != aLastCheck) {
    [_lastCheck release];
    _lastCheck = [aLastCheck copy];
    
    [[NSUserDefaults standardUserDefaults] setObject:_lastCheck forKey:kBITUpdateDateOfLastCheck];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
}

- (void)setAppVersions:(NSArray *)anAppVersions {
  if (_appVersions != anAppVersions || !_appVersions) {
    [_appVersions release];
    [self willChangeValueForKey:@"appVersions"];
    
    // populate with default values (if empty)
    if (![anAppVersions count]) {
      BITAppVersionMetaInfo *defaultApp = [[[BITAppVersionMetaInfo alloc] init] autorelease];
      defaultApp.name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
      defaultApp.version = _currentAppVersion;
      defaultApp.shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
      _appVersions = [[NSArray arrayWithObject:defaultApp] retain];
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

- (void)setAuthorizeView:(UIView *)anAuthorizeView {
  if (_authorizeView != anAuthorizeView) {
    [_authorizeView removeFromSuperview];
    [_authorizeView release];
    _authorizeView = [anAuthorizeView retain];
  }
}


#pragma mark - UIAlertViewDelegate

// invoke the selected action from the actionsheet for a location element
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
