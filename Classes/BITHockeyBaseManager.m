//
//  CNSHockeyBaseManager.m
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITHockeyHelper.h"

#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITHockeyBaseViewController.h"

#import "BITHockeyManagerPrivate.h"
#import "BITKeychainUtils.h"

#import <sys/sysctl.h>
#if !TARGET_IPHONE_SIMULATOR
#import <mach-o/ldsyms.h>
#endif

@implementation BITHockeyBaseManager {
  UINavigationController *_navController;
  
  NSDateFormatter *_rfc3339Formatter;
  
  BOOL _isAppStoreEnvironment;
}


- (id)init {
  if ((self = [super init])) {
    _isAppStoreEnvironment = NO;
    _appIdentifier = nil;
    _serverURL = BITHOCKEYSDK_URL;

    _navController = nil;
    _barStyle = UIBarStyleBlackOpaque;
    self.tintColor = BIT_RGBCOLOR(25, 25, 25);
    _modalPresentationStyle = UIModalPresentationFormSheet;
    
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    _rfc3339Formatter = [[NSDateFormatter alloc] init];
    [_rfc3339Formatter setLocale:enUSPOSIXLocale];
    [_rfc3339Formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [_rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  }
  return self;
}

- (id)initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironemt:(BOOL)isAppStoreEnvironment {
  if ((self = [self init])) {
    _appIdentifier = appIdentifier;
    _isAppStoreEnvironment = isAppStoreEnvironment;
  }
  return self;
}


#pragma mark - Private

- (void)reportError:(NSError *)error {
  BITHockeyLog(@"ERROR: %@", [error localizedDescription]);
}

- (BOOL)isAppStoreEnvironment {
  return _isAppStoreEnvironment;
}

- (NSString *)encodedAppIdentifier {
  return (_appIdentifier ? bit_URLEncodedString(_appIdentifier) : bit_URLEncodedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]));
}

- (NSString *)getDevicePlatform {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *answer = (char*)malloc(size);
  if (answer == NULL)
    return @"";
  sysctlbyname("hw.machine", answer, &size, NULL, 0);
  NSString *platform = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
  free(answer);
  return platform;
}

- (NSString *)executableUUID {
  // This now requires the testing of this feature to be done on an actual device, since it returns always empty strings on the simulator
  // Once there is a better solution to get unit test targets build without problems this should be changed again, so testing of this
  // feature is also possible using the simulator
  // See: http://support.hockeyapp.net/discussions/problems/2306-integrating-hockeyapp-with-test-bundle-target-i386-issues
  //      http://support.hockeyapp.net/discussions/problems/4113-linking-hockeysdk-to-test-bundle-target
#if !TARGET_IPHONE_SIMULATOR
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
#endif
  return @"";
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
        BITHockeyLog(@"INFO: UIWindow with rootViewController found: %@", visibleWindow);
        break;
      }
    }
  }
  
  return visibleWindow;
}

- (void)showView:(UIViewController *)viewController {
  UIViewController *parentViewController = nil;
  
  if ([[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(viewControllerForHockeyManager:componentManager:)]) {
    parentViewController = [[BITHockeyManager sharedHockeyManager].delegate viewControllerForHockeyManager:[BITHockeyManager sharedHockeyManager] componentManager:self];
  }
  
  UIWindow *visibleWindow = [self findVisibleWindow];
  
  if (parentViewController == nil) {
    parentViewController = [visibleWindow rootViewController];
  }
  
  // use topmost modal view
  while (parentViewController.presentedViewController) {
    parentViewController = parentViewController.presentedViewController;
  }
  
  // special addition to get rootViewController from three20 which has it's own controller handling
  if (NSClassFromString(@"TTNavigator")) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    UIViewController *ttParentViewController = nil;
    ttParentViewController = [[NSClassFromString(@"TTNavigator") performSelector:(NSSelectorFromString(@"navigator"))] visibleViewController];
    if (ttParentViewController)
      parentViewController = ttParentViewController;
#pragma clang diagnostic pop
  }
  
  if (_navController != nil) _navController = nil;
  
  _navController = [[UINavigationController alloc] initWithRootViewController:viewController];
  _navController.navigationBar.barStyle = _barStyle;
  _navController.navigationBar.tintColor = _tintColor;
  _navController.modalPresentationStyle = _modalPresentationStyle;
  
  if (parentViewController) {
    _navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    // page sheet for the iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      _navController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    if ([viewController isKindOfClass:[BITHockeyBaseViewController class]])
      [(BITHockeyBaseViewController *)viewController setModalAnimated:YES];
    
    [parentViewController presentViewController:_navController animated:YES completion:nil];
  } else {
    // if not, we add a subview to the window. A bit hacky but should work in most circumstances.
    // Also, we don't get a nice animation for free, but hey, this is for beta not production users ;)
    BITHockeyLog(@"INFO: No rootViewController found, using UIWindow-approach: %@", visibleWindow);
    if ([viewController isKindOfClass:[BITHockeyBaseViewController class]])
      [(BITHockeyBaseViewController *)viewController setModalAnimated:NO];
    [visibleWindow addSubview:_navController.view];
  }
}

- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key {
	if (!key || !stringValue)
		return NO;
  
  NSString *serviceName = [NSString stringWithFormat:@"%@.HockeySDK", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
  
  NSError *error = nil;
  return [BITKeychainUtils storeUsername:key andPassword:stringValue forServiceName:serviceName updateExisting:YES error:&error];
}

- (NSString *)stringValueFromKeychainForKey:(NSString *)key {
	if (!key)
		return nil;
  
  NSString *serviceName = [NSString stringWithFormat:@"%@.HockeySDK", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];

  NSError *error = nil;
  return [BITKeychainUtils getPasswordForUsername:key andServiceName:serviceName error:&error];
}

- (BOOL)removeKeyFromKeychain:(NSString *)key {
  NSString *serviceName = [NSString stringWithFormat:@"%@.HockeySDK", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];

  NSError *error = nil;
  return [BITKeychainUtils deleteItemForUsername:key andServiceName:serviceName error:&error];
}


#pragma mark - Manager Control

- (void)startManager {
}


#pragma mark - Networking

- (NSData *)appendPostValue:(NSString *)value forKey:(NSString *)key {
  NSString *boundary = @"----FOO";
  
  NSMutableData *postBody = [NSMutableData data];
  
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\";\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"Content-Type: text\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];    
  [postBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  
  return postBody;
}


#pragma mark - Helpers

- (NSDate *)parseRFC3339Date:(NSString *)dateString {
  NSDate *date = nil;
  NSError *error = nil; 
  if (![_rfc3339Formatter getObjectValue:&date forString:dateString range:nil error:&error]) {
    BITHockeyLog(@"INFO: Invalid date '%@' string: %@", dateString, error);
  }
  
  return date;
}


@end
