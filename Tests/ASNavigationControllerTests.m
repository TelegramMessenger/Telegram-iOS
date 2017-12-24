//
//  ASNavigationControllerTests.m
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
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "ASNavigationController.h"

@interface ASNavigationControllerTests : XCTestCase
@end

@implementation ASNavigationControllerTests

- (void)testSetViewControllers {
  ASViewController *firstController = [ASViewController new];
  ASViewController *secondController = [ASViewController new];
  NSArray *expectedViewControllerStack = @[firstController, secondController];
  ASNavigationController *navigationController = [ASNavigationController new];
  [navigationController setViewControllers:@[firstController, secondController]];
  XCTAssertEqual(navigationController.topViewController, secondController);
  XCTAssertEqual(navigationController.visibleViewController, secondController);
  XCTAssertTrue([navigationController.viewControllers isEqualToArray:expectedViewControllerStack]);
}

- (void)testPopViewController {
  ASViewController *firstController = [ASViewController new];
  ASViewController *secondController = [ASViewController new];
  NSArray *expectedViewControllerStack = @[firstController];
  ASNavigationController *navigationController = [ASNavigationController new];
  [navigationController setViewControllers:@[firstController, secondController]];
  [navigationController popViewControllerAnimated:false];
  XCTAssertEqual(navigationController.topViewController, firstController);
  XCTAssertEqual(navigationController.visibleViewController, firstController);
  XCTAssertTrue([navigationController.viewControllers isEqualToArray:expectedViewControllerStack]);
}

- (void)testPushViewController {
  ASViewController *firstController = [ASViewController new];
  ASViewController *secondController = [ASViewController new];
  NSArray *expectedViewControllerStack = @[firstController, secondController];
  ASNavigationController *navigationController = [[ASNavigationController new] initWithRootViewController:firstController];
  [navigationController pushViewController:secondController animated:false];
  XCTAssertEqual(navigationController.topViewController, secondController);
  XCTAssertEqual(navigationController.visibleViewController, secondController);
  XCTAssertTrue([navigationController.viewControllers isEqualToArray:expectedViewControllerStack]);
}

@end
