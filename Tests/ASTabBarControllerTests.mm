//
//  ASTabBarControllerTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASTabBarController.h>
#import <AsyncDisplayKit/ASViewController.h>

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
