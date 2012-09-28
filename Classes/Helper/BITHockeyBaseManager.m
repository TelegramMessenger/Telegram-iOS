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

#import <sys/sysctl.h>


@implementation BITHockeyBaseManager


- (id)init {
  if ((self = [super init])) {
    _isAppStoreEnvironment = NO;
    _appIdentifier = nil;
    
    _navController = nil;
    _barStyle = UIBarStyleDefault;
    _modalPresentationStyle = UIModalPresentationFormSheet;
    
    _rfc3339Formatter = [[NSDateFormatter alloc] init];
    [_rfc3339Formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [_rfc3339Formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
  }
  return self;
}

- (id)initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironemt:(BOOL)isAppStoreEnvironment {
  if ((self = [self init])) {
 
    self.appIdentifier = appIdentifier;
    _isAppStoreEnvironment = isAppStoreEnvironment;
  
  }
  return self;
}


- (void)dealloc {
  [_appIdentifier release];

  [_navController release], _navController = nil;
  
  [_rfc3339Formatter release], _rfc3339Formatter = nil;
  
  [super dealloc];
}


#pragma mark - Private

- (void)reportError:(NSError *)error {
  BITHockeyLog(@"Error: %@", [error localizedDescription]);
}

- (NSString *)encodedAppIdentifier {
  return (_appIdentifier ? bit_URLEncodedString(_appIdentifier) : bit_URLEncodedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]));
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

- (void)showView:(BITHockeyBaseViewController *)viewController {
  UIViewController *parentViewController = nil;
  
  if ([[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(viewControllerForHockeyManager:componentManager:)]) {
    parentViewController = [[BITHockeyManager sharedHockeyManager].delegate viewControllerForHockeyManager:[BITHockeyManager sharedHockeyManager] componentManager:self];
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
    parentViewController = [[NSClassFromString(@"TTNavigator") performSelector:(NSSelectorFromString(@"navigator"))] visibleViewController];
  }
  
  if (_navController != nil) [_navController release], _navController = nil;
  
  _navController = [[UINavigationController alloc] initWithRootViewController:viewController];
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
    
    viewController.modalAnimated = YES;
    
    [parentViewController presentModalViewController:_navController animated:YES];
  } else {
    // if not, we add a subview to the window. A bit hacky but should work in most circumstances.
    // Also, we don't get a nice animation for free, but hey, this is for beta not production users ;)
    BITHockeyLog(@"INFO: No rootViewController found, using UIWindow-approach: %@", visibleWindow);
    viewController.modalAnimated = NO;
    [visibleWindow addSubview:_navController.view];
  }
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
