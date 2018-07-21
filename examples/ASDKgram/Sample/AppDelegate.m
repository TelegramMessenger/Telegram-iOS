//
//  AppDelegate.m
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) through the present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "AppDelegate.h"
#import "PhotoFeedViewController.h"
#import "PhotoFeedNodeController.h"
#import "PhotoFeedListKitViewController.h"
#import "WindowWithStatusBarUnderlay.h"
#import "Utilities.h"

#import <AsyncDisplayKit/ASGraphicsContext.h>

#define WEAVER 0

#if WEAVER
#import <Weaver/WVDebugger.h>
#endif

@interface AppDelegate () <UITabBarControllerDelegate>
@end

@implementation AppDelegate
{
  WindowWithStatusBarUnderlay *_window;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  
  // this UIWindow subclass is neccessary to make the status bar opaque
  _window                  = [[WindowWithStatusBarUnderlay alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _window.backgroundColor  = [UIColor whiteColor];
  
  // ASDK Home Feed viewController & navController
  PhotoFeedNodeController *asdkHomeFeedVC      = [[PhotoFeedNodeController alloc] init];
  UINavigationController *asdkHomeFeedNavCtrl  = [[UINavigationController alloc] initWithRootViewController:asdkHomeFeedVC];
  asdkHomeFeedNavCtrl.tabBarItem               = [[UITabBarItem alloc] initWithTitle:@"ASDK" image:[UIImage imageNamed:@"home"] tag:0];
  asdkHomeFeedNavCtrl.hidesBarsOnSwipe         = YES;

  // ListKit Home Feed viewController & navController
  PhotoFeedListKitViewController *listKitHomeFeedVC      = [[PhotoFeedListKitViewController alloc] init];
  UINavigationController *listKitHomeFeedNavCtrl  = [[UINavigationController alloc] initWithRootViewController:listKitHomeFeedVC];
  listKitHomeFeedNavCtrl.tabBarItem               = [[UITabBarItem alloc] initWithTitle:@"ListKit" image:[UIImage imageNamed:@"home"] tag:0];
  listKitHomeFeedNavCtrl.hidesBarsOnSwipe         = YES;

  // UIKit Home Feed viewController & navController
  PhotoFeedViewController *uikitHomeFeedVC     = [[PhotoFeedViewController alloc] init];
  UINavigationController *uikitHomeFeedNavCtrl = [[UINavigationController alloc] initWithRootViewController:uikitHomeFeedVC];
  uikitHomeFeedNavCtrl.tabBarItem              = [[UITabBarItem alloc] initWithTitle:@"UIKit" image:[UIImage imageNamed:@"home"] tag:0];
  uikitHomeFeedNavCtrl.hidesBarsOnSwipe        = YES;

  // UITabBarController
  UITabBarController *tabBarController         = [[UITabBarController alloc] init];
  tabBarController.viewControllers             = @[uikitHomeFeedNavCtrl, asdkHomeFeedNavCtrl, listKitHomeFeedNavCtrl];
  tabBarController.selectedViewController      = asdkHomeFeedNavCtrl;
  tabBarController.delegate                    = self;
  [[UITabBar appearance] setTintColor:[UIColor darkBlueColor]];
  
  _window.rootViewController = tabBarController;
  [_window makeKeyAndVisible];
  
  // Nav Bar appearance
  NSDictionary *attributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
  [[UINavigationBar appearance] setTitleTextAttributes:attributes];
  [[UINavigationBar appearance] setBarTintColor:[UIColor darkBlueColor]];
  [[UINavigationBar appearance] setTranslucent:NO];
  
  // iOS8 hides the status bar in landscape orientation, this forces the status bar hidden status to NO
  [application setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
  [application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];

#if WEAVER
  WVDebugger *debugger = [WVDebugger defaultInstance];
  [debugger enableLayoutElementDebuggingWithApplication:application];
  [debugger autoConnect];
#endif

  return YES;
}

#pragma mark - UITabBarControllerDelegate

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
  if ([viewController isKindOfClass:[UINavigationController class]]) { 
    NSArray *viewControllers = [(UINavigationController *)viewController viewControllers];
    UIViewController *rootViewController = viewControllers[0];
    if ([rootViewController conformsToProtocol:@protocol(PhotoFeedControllerProtocol)]) {
      // FIXME: the dataModel does not currently handle clearing data during loading properly
//      [(id <PhotoFeedControllerProtocol>)rootViewController resetAllData];
    }
  }
}

@end
