//
//  ASTabBarControllerTests.m
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import "ASTabBarController.h"
#import "ASViewController.h"

@interface ASTabBarControllerTests: XCTestCase

@end

@implementation ASTabBarControllerTests

- (void)testTabBarControllerSelectIndex {
  ASViewController *firstViewController = [ASViewController new];
  ASViewController *secondViewController = [ASViewController new];
  NSArray *viewControllers = @[firstViewController, secondViewController];
  ASTabBarController *tabBarController = [ASTabBarController new];
  [tabBarController setViewControllers:viewControllers];
  [tabBarController setSelectedIndex:1];
  XCTAssertTrue([tabBarController.viewControllers isEqualToArray:viewControllers]);
  XCTAssertEqual(tabBarController.selectedViewController, secondViewController);
}

- (void)testTabBarControllerSelectViewController {
  ASViewController *firstViewController = [ASViewController new];
  ASViewController *secondViewController = [ASViewController new];
  NSArray *viewControllers = @[firstViewController, secondViewController];
  ASTabBarController *tabBarController = [ASTabBarController new];
  [tabBarController setViewControllers:viewControllers];
  [tabBarController setSelectedViewController:secondViewController];
  XCTAssertTrue([tabBarController.viewControllers isEqualToArray:viewControllers]);
  XCTAssertEqual(tabBarController.selectedViewController, secondViewController);
}

@end
