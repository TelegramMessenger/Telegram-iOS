/*
 * Author: Andreas Linde <mail@andreaslinde.de>
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

#import "BITHockeyHelper.h"

#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"
#if HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_UPDATES || HOCKEYSDK_FEATURE_FEEDBACK
#import "BITHockeyBaseViewController.h"
#endif

#import "BITKeychainUtils.h"

#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>

#ifndef __IPHONE_6_1
#define __IPHONE_6_1     60100
#endif

@implementation BITHockeyBaseManager {
  UINavigationController *_navController;
  
  NSDateFormatter *_rfc3339Formatter;
  
  BOOL _isAppStoreEnvironment;
}


- (instancetype)init {
  if ((self = [super init])) {
    _serverURL = BITHOCKEYSDK_URL;

    if ([self isPreiOS7Environment]) {
      _barStyle = UIBarStyleBlackOpaque;
      self.navigationBarTintColor = BIT_RGBCOLOR(25, 25, 25);
    } else {
      _barStyle = UIBarStyleDefault;
    }
    _modalPresentationStyle = UIModalPresentationFormSheet;
    
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    _rfc3339Formatter = [[NSDateFormatter alloc] init];
    [_rfc3339Formatter setLocale:enUSPOSIXLocale];
    [_rfc3339Formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [_rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  }
  return self;
}

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironment:(BOOL)isAppStoreEnvironment {
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
  return bit_encodeAppIdentifier(_appIdentifier);
}

- (BOOL)isPreiOS7Environment {
  return bit_isPreiOS7Environment();
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
  const struct mach_header *executableHeader = NULL;
  for (uint32_t i = 0; i < _dyld_image_count(); i++) {
    const struct mach_header *header = _dyld_get_image_header(i);
    if (header->filetype == MH_EXECUTE) {
      executableHeader = header;
      break;
    }
  }
  
  if (!executableHeader)
    return @"";
  
  BOOL is64bit = executableHeader->magic == MH_MAGIC_64 || executableHeader->magic == MH_CIGAM_64;
  uintptr_t cursor = (uintptr_t)executableHeader + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
  const struct segment_command *segmentCommand = NULL;
  for (uint32_t i = 0; i < executableHeader->ncmds; i++, cursor += segmentCommand->cmdsize) {
    segmentCommand = (struct segment_command *)cursor;
    if (segmentCommand->cmd == LC_UUID) {
      const struct uuid_command *uuidCommand = (const struct uuid_command *)segmentCommand;
      const uint8_t *uuid = uuidCommand->uuid;
      return [[NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
               uuid[0], uuid[1], uuid[2], uuid[3],
               uuid[4], uuid[5], uuid[6], uuid[7],
               uuid[8], uuid[9], uuid[10], uuid[11],
               uuid[12], uuid[13], uuid[14], uuid[15]]
              lowercaseString];
    }
  }
  
  return @"";
}

- (UIWindow *)findVisibleWindow {
  UIWindow *visibleWindow = [UIApplication sharedApplication].keyWindow;
  
  if (!(visibleWindow.hidden)) {
    return visibleWindow;
  }
  
  // if the rootViewController property (available >= iOS 4.0) of the main window is set, we present the modal view controller on top of the rootViewController
  NSArray *windows = [[UIApplication sharedApplication] windows];
  for (UIWindow *window in windows) {
    if (!window.hidden && !visibleWindow) {
      visibleWindow = window;
    }
    if ([UIWindow instancesRespondToSelector:@selector(rootViewController)]) {
      if (!(window.hidden) && ([window rootViewController])) {
        visibleWindow = window;
        BITHockeyLog(@"INFO: UIWindow with rootViewController found: %@", visibleWindow);
        break;
      }
    }
  }
  
  return visibleWindow;
}

/**
 * Provide a custom UINavigationController with customized appearance settings
 *
 * @param viewController The root viewController
 * @param modalPresentationStyle The modal presentation style
 *
 * @return A UINavigationController
 */
- (UINavigationController *)customNavigationControllerWithRootViewController:(UIViewController *)viewController presentationStyle:(UIModalPresentationStyle)modalPresentationStyle {
  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
  navController.navigationBar.barStyle = self.barStyle;
  if (self.navigationBarTintColor) {
    navController.navigationBar.tintColor = self.navigationBarTintColor;
  } else {
    // in case of iOS 7 we overwrite the tint color on the navigation bar
    if (![self isPreiOS7Environment]) {
      if ([UIWindow instancesRespondToSelector:NSSelectorFromString(@"tintColor")]) {
        [navController.navigationBar setTintColor:BIT_RGBCOLOR(0, 122, 255)];
      }
    }
  }
  navController.modalPresentationStyle = self.modalPresentationStyle;
  
  return navController;
}

- (void)showView:(UIViewController *)viewController {
  // if we compile Crash only, then BITHockeyBaseViewController is not included
  // in the headers and will cause a warning with the modulemap file
#if HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_UPDATES || HOCKEYSDK_FEATURE_FEEDBACK
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
  
  // as per documentation this only works if called from within viewWillAppear: or viewDidAppear:
  // in tests this also worked fine on iOS 6 and 7 but not on iOS 5 so we are still trying this
  if ([parentViewController isBeingPresented]) {
    BITHockeyLog(@"WARNING: There is already a view controller being presented onto the parentViewController. Delaying presenting the new view controller by 0.5s.");
    [self performSelector:@selector(showView:) withObject:viewController afterDelay:0.5];
    return;
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
  
  _navController = [self customNavigationControllerWithRootViewController:viewController presentationStyle:_modalPresentationStyle];
  
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
#endif
}

- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key {
	if (!key || !stringValue)
		return NO;
  
  NSError *error = nil;
  return [BITKeychainUtils storeUsername:key
                             andPassword:stringValue
                          forServiceName:bit_keychainHockeySDKServiceName()
                          updateExisting:YES
                                   error:&error];
}

- (BOOL)addStringValueToKeychainForThisDeviceOnly:(NSString *)stringValue forKey:(NSString *)key {
	if (!key || !stringValue)
		return NO;
  
  NSError *error = nil;
  return [BITKeychainUtils storeUsername:key
                             andPassword:stringValue
                          forServiceName:bit_keychainHockeySDKServiceName()
                          updateExisting:YES
                           accessibility:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                                   error:&error];
}

- (NSString *)stringValueFromKeychainForKey:(NSString *)key {
	if (!key)
		return nil;
  
  NSError *error = nil;
  return [BITKeychainUtils getPasswordForUsername:key
                                   andServiceName:bit_keychainHockeySDKServiceName()
                                            error:&error];
}

- (BOOL)removeKeyFromKeychain:(NSString *)key {
  NSError *error = nil;
  return [BITKeychainUtils deleteItemForUsername:key
                                  andServiceName:bit_keychainHockeySDKServiceName()
                                           error:&error];
}


#pragma mark - Manager Control

- (void)startManager {
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
