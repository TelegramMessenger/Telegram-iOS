//
//  AppDelegate.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "AppDelegate.h"

#import "TabBarController.h"
#import "CollectionViewController.h"
#import "ViewController.h"


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];

  ViewController *viewController = [[ViewController alloc] init];
  viewController.tabBarItem.title = @"TextStress";

  CollectionViewController *cvc = [[CollectionViewController alloc] init];
  cvc.tabBarItem.title = @"Flexbox";

  TabBarController *tabBarController = [[TabBarController alloc] init];
  tabBarController.viewControllers = @[cvc, viewController];

  self.window.rootViewController = tabBarController;
  [self.window makeKeyAndVisible];
  return YES;
}

@end
