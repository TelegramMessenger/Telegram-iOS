//
//  ASListKitTests.m
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "ASListKitTestAdapterDataSource.h"
#import "ASXCTExtensions.h"
#import <JGMethodSwizzler/JGMethodSwizzler.h>
#import "ASTestCase.h"

@interface ASListKitTests : ASTestCase

@property (nonatomic, strong) ASCollectionNode *collectionNode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) IGListAdapter *adapter;
@property (nonatomic, strong) ASListKitTestAdapterDataSource *dataSource;
@property (nonatomic, strong) UICollectionViewFlowLayout *layout;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic) NSInteger reloadDataCount;

@end

@implementation ASListKitTests

- (void)setUp
{
  [super setUp];

  [ASCollectionView swizzleInstanceMethod:@selector(reloadData) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, ASCollectionView *) {
      JGOriginalImplementation(void);
      _reloadDataCount++;
    };
  }];

  self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];

  self.layout = [[UICollectionViewFlowLayout alloc] init];
  self.collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:self.layout];
  self.collectionNode.frame = self.window.bounds;
  self.collectionView = self.collectionNode.view;

  [self.window addSubnode:self.collectionNode];

  IGListAdapterUpdater *updater = [[IGListAdapterUpdater alloc] init];

  self.dataSource = [[ASListKitTestAdapterDataSource alloc] init];
  self.adapter = [[IGListAdapter alloc] initWithUpdater:updater
                                         viewController:nil
                                       workingRangeSize:0];
  self.adapter.dataSource = self.dataSource;
  [self.adapter setASDKCollectionNode:self.collectionNode];
  XCTAssertNotNil(self.adapter.collectionView, @"Adapter was not bound to collection view. You may have a stale copy of AsyncDisplayKit that was built without IG_LIST_KIT. Clean Builder Folder IMO.");
}

- (void)tearDown
{
  [super tearDown];
  XCTAssert([ASCollectionView deswizzleAllMethods]);
  self.reloadDataCount = 0;
  self.window = nil;
  self.collectionNode = nil;
  self.collectionView = nil;
  self.adapter = nil;
  self.dataSource = nil;
  self.layout = nil;
}

- (void)test_whenAdapterUpdated_withObjectsOverflow_thatVisibleObjectsIsSubsetOfAllObjects
{
  // each section controller returns n items sized 100x10
  self.dataSource.objects = @[@1, @2, @3, @4, @5, @6];
  XCTestExpectation *e = [self expectationWithDescription:@"Data update completed"];

  [self.adapter performUpdatesAnimated:NO completion:^(BOOL finished) {
    [e fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1 handler:nil];
  self.collectionNode.view.contentOffset = CGPointMake(0, 30);
  [self.collectionNode.view layoutIfNeeded];


  NSArray *visibleObjects = [[self.adapter visibleObjects] sortedArrayUsingSelector:@selector(compare:)];
  NSArray *expectedObjects = @[@3, @4, @5];
  XCTAssertEqualObjects(visibleObjects, expectedObjects);
}

- (void)test_whenCollectionViewIsNotInAWindow_updaterDoesNotJustCallReloadData
{
  [self.collectionView removeFromSuperview];

  [self.collectionView layoutIfNeeded];
  self.dataSource.objects = @[@1, @2, @3, @4, @5, @6];
  XCTestExpectation *e = [self expectationWithDescription:@"Data update completed"];

  [self.adapter performUpdatesAnimated:NO completion:^(BOOL finished) {
    [e fulfill];
  }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
  [self.collectionView layoutIfNeeded];

  XCTAssertEqual(self.reloadDataCount, 2);
}

@end
