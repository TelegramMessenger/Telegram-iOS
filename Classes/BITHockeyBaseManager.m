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

// We need BIT_UNUSED macro to make sure there aren't any warnings when building
// HockeySDK Distribution scheme. Since several configurations are build in this scheme
// and different features can be turned on and off we can't just use __unused attribute.
#if !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions)
#if HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_UPDATES || HOCKEYSDK_FEATURE_FEEDBACK
#define BIT_UNUSED
#else
#define BIT_UNUSED __unused
#endif
#endif

@interface BITHockeyBaseManager ()

@property (nonatomic, strong) UINavigationController *navController;
@property (nonatomic, strong) NSDateFormatter *rfc3339Formatter;

@end

@implementation BITHockeyBaseManager

- (instancetype)init {
  if ((self = [super init])) {
    _serverURL = BITHOCKEYSDK_URL;
    _barStyle = UIBarStyleDefault;
    _modalPresentationStyle = UIModalPresentationFormSheet;
    
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    _rfc3339Formatter = [[NSDateFormatter alloc] init];
    [_rfc3339Formatter setLocale:enUSPOSIXLocale];
    [_rfc3339Formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [_rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  }
  return self;
}

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier appEnvironment:(BITEnvironment)environment {
  if ((self = [self init])) {
    _appIdentifier = appIdentifier;
    _appEnvironment = environment;
  }
  return self;
}


#pragma mark - Private

- (void)reportError:(NSError *)error {
  BITHockeyLogError(@"ERROR: %@", [error localizedDescription]);
}

- (NSString *)encodedAppIdentifier {
  return bit_encodeAppIdentifier(self.appIdentifier);
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

#if !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions)
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
        BITHockeyLogDebug(@"INFO: UIWindow with rootViewController found: %@", visibleWindow);
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
    if ([UIWindow instancesRespondToSelector:NSSelectorFromString(@"tintColor")]) {
      [navController.navigationBar setTintColor:BIT_RGBCOLOR(0, 122, 255)];
    }
  }
  navController.modalPresentationStyle = modalPresentationStyle;
  
  return navController;
}

- (UIViewController *)visibleWindowRootViewController {
  UIViewController *parentViewController = nil;
  id strongDelegate = [BITHockeyManager sharedHockeyManager].delegate;
  if ([strongDelegate respondsToSelector:@selector(viewControllerForHockeyManager:componentManager:)]) {
    parentViewController = [strongDelegate viewControllerForHockeyManager:[BITHockeyManager sharedHockeyManager] componentManager:self];
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
  
  return parentViewController;
}

- (void)showAlertController:(UIViewController *)alertController {
  
  // always execute this on the main thread
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *parentViewController = [self visibleWindowRootViewController];
    
    // as per documentation this only works if called from within viewWillAppear: or viewDidAppear:
    // in tests this also worked fine on iOS 6 and 7 but not on iOS 5 so we are still trying this
    if ([parentViewController isKindOfClass:NSClassFromString(@"UIAlertController")] || [parentViewController isBeingPresented]) {
      BITHockeyLogWarning(@"WARNING: There is already a view controller being presented onto the parentViewController. Delaying presenting the new view controller by 0.5s.");
      [self performSelector:@selector(showAlertController:) withObject:alertController afterDelay:0.5];
      return;
    }
    
    if (parentViewController) {
      [parentViewController presentViewController:alertController animated:YES completion:nil];
    }
  });
}

- (void)showView:(BIT_UNUSED UIViewController *)viewController {
  // if we compile Crash only, then BITHockeyBaseViewController is not included
  // in the headers and will cause a warning with the modulemap file
#if HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_UPDATES || HOCKEYSDK_FEATURE_FEEDBACK
    UIViewController *parentViewController = [self visibleWindowRootViewController];
    
    // as per documentation this only works if called from within viewWillAppear: or viewDidAppear:
    // in tests this also worked fine on iOS 6 and 7 but not on iOS 5 so we are still trying this
    if ([parentViewController isBeingPresented]) {
      BITHockeyLogDebug(@"INFO: There is already a view controller being presented onto the parentViewController. Delaying presenting the new view controller by 0.5s.");
      [self performSelector:@selector(showView:) withObject:viewController afterDelay:0.5];
      return;
    }
    
    if (self.navController != nil) self.navController = nil;
    
    self.navController = [self customNavigationControllerWithRootViewController:viewController presentationStyle:self.modalPresentationStyle];
    
    if (parentViewController) {
      self.navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
      
      // page sheet for the iPad
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navController.modalPresentationStyle = UIModalPresentationFormSheet;
      }
      
      if ([viewController isKindOfClass:[BITHockeyBaseViewController class]])
        [(BITHockeyBaseViewController *)viewController setModalAnimated:YES];
      
      [parentViewController presentViewController:self.navController animated:YES completion:nil];
    } else {
      // if not, we add a subview to the window. A bit hacky but should work in most circumstances.
      // Also, we don't get a nice animation for free, but hey, this is for beta not production users ;)
      UIWindow *visibleWindow = [self findVisibleWindow];
      
      BITHockeyLogDebug(@"INFO: No rootViewController found, using UIWindow-approach: %@", visibleWindow);
      if ([viewController isKindOfClass:[BITHockeyBaseViewController class]])
        [(BITHockeyBaseViewController *)viewController setModalAnimated:NO];
      [visibleWindow addSubview:self.navController.view];
    }
#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_UPDATES || HOCKEYSDK_FEATURE_FEEDBACK */
}
#endif // HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions && HOCKEYSDK_CONFIGURATION_RelaseCrashOnlyWatchOS


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
  if (![self.rfc3339Formatter getObjectValue:&date forString:dateString range:nil error:&error]) {
    BITHockeyLogWarning(@"WARNING: Invalid date '%@' string: %@", dateString, error);
  }
  
  return date;
}


@end
