//
//  AppDelegate.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "AppDelegate.h"

#import "AsyncTableViewController.h"
#import "AsyncViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];
  
  UITabBarController *tabBarController = [[UITabBarController alloc] initWithNibName:nil bundle:nil];
  self.window.rootViewController = tabBarController;
  
  [tabBarController setViewControllers:@[[[AsyncTableViewController alloc] init], [[AsyncViewController alloc] init]]];
  
  [self.window makeKeyAndVisible];
  return YES;
}

@end
