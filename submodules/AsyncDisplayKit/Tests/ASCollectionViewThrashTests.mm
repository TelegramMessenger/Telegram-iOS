//
//  ASCollectionViewThrashTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASCollectionView.h>
#import <stdatomic.h>

#import "ASThrashUtility.h"

@interface ASCollectionViewThrashTests : XCTestCase

@end

@implementation ASCollectionViewThrashTests
{
  // The current update, which will be logged in case of a failure.
  ASThrashUpdate *_update;
  BOOL _failed;
}

- (void)tearDown
{
  if (_failed && _update != nil) {
    NSLog(@"Failed update %@: %@", _update, _update.logFriendlyBase64Representation);
  }
  _failed = NO;
  _update = nil;
}

// NOTE: Despite the documentation, this is not always called if an exception is caught.
- (void)recordFailureWithDescription:(NSString *)description inFile:(NSString *)filePath atLine:(NSUInteger)lineNumber expected:(BOOL)expected
{
  _failed = YES;
  [super recordFailureWithDescription:description inFile:filePath atLine:lineNumber expected:expected];
}

- (void)verifyDataSource:(ASThrashDataSource *)ds
{
  CollectionView *collectionView = ds.collectionView;
  NSArray <ASThrashTestSection *> *data = [ds data];
  for (NSInteger i = 0; i < collectionView.numberOfSections; i++) {
    XCTAssertEqual([collectionView numberOfItemsInSection:i], data[i].items.count);

    for (NSInteger j = 0; j < [collectionView numberOfItemsInSection:i]; j++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:j inSection:i];
      ASThrashTestItem *item = data[i].items[j];
      ASThrashTestNode *node = (ASThrashTestNode *)[collectionView nodeForItemAtIndexPath:indexPath];
      XCTAssertEqualObjects(node.item, item, @"Wrong node at index path %@", indexPath);
    }
  }
}

#pragma mark Test Methods

- (void)testInitialDataRead
{
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initCollectionViewDataSourceWithData:[ASThrashTestSection sectionsWithCount:kInitialSectionCount]];
  [self verifyDataSource:ds];
}

/// Replays the Base64 representation of an ASThrashUpdate from "ASThrashTestRecordedCase" file
- (void)testRecordedThrashCase
{
  NSURL *caseURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"ASThrashTestRecordedCase" withExtension:nil subdirectory:@"TestResources"];
  NSString *base64 = [NSString stringWithContentsOfURL:caseURL encoding:NSUTF8StringEncoding error:NULL];

  _update = [ASThrashUpdate thrashUpdateWithBase64String:base64];
  if (_update == nil) {
    return;
  }

  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initCollectionViewDataSourceWithData:_update.oldData];
  [self applyUpdateUsingBatchUpdates:_update
                        toDataSource:ds
                            animated:NO
                       useXCTestWait:YES];
  [self verifyDataSource:ds];
}

- (void)testThrashingWildly
{
  for (NSInteger i = 0; i < kThrashingIterationCount; i++) {
    [self setUp];
    @autoreleasepool {
      NSArray *sections = [ASThrashTestSection sectionsWithCount:kInitialSectionCount];
      _update = [[ASThrashUpdate alloc] initWithData:sections];
      ASThrashDataSource *ds = [[ASThrashDataSource alloc] initCollectionViewDataSourceWithData:sections];

      [self applyUpdateUsingBatchUpdates:_update
                            toDataSource:ds
                                animated:NO
                           useXCTestWait:NO];
      [self verifyDataSource:ds];
      [self expectationForPredicate:[ds predicateForDeallocatedHierarchy] evaluatedWithObject:(id)kCFNull handler:nil];
    }
    [self waitForExpectationsWithTimeout:3 handler:nil];

    [self tearDown];
  }
}

- (void)testThrashingWildlyOnSameCollectionView
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"last test ran"];
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initCollectionViewDataSourceWithData:nil];
  for (NSInteger i = 0; i < 1000; i++) {
    [self setUp];
    @autoreleasepool {
      NSArray *sections = [ASThrashTestSection sectionsWithCount:kInitialSectionCount];
      _update = [[ASThrashUpdate alloc] initWithData:sections];
      [ds setData:sections];
      [ds.collectionView reloadData];

      [self applyUpdateUsingBatchUpdates:_update
                            toDataSource:ds
                                animated:NO
                           useXCTestWait:NO];
      [self verifyDataSource:ds];
      if (i == 999) {
        [expectation fulfill];
      }
    }

    [self tearDown];
  }
  [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testThrashingWildlyDispatchWildly
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"last test ran"];
  for (NSInteger i = 0; i < kThrashingIterationCount; i++) {
    [self setUp];
    @autoreleasepool {
      dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *sections = [ASThrashTestSection sectionsWithCount:kInitialSectionCount];
        _update = [[ASThrashUpdate alloc] initWithData:sections];
        ASThrashDataSource *ds = [[ASThrashDataSource alloc] initCollectionViewDataSourceWithData:sections];

        [self applyUpdateUsingBatchUpdates:_update
                              toDataSource:ds
                                  animated:NO
                             useXCTestWait:NO];
        [self verifyDataSource:ds];
        if (i == kThrashingIterationCount-1) {
          [expectation fulfill];
        }
      });
    }

    [self tearDown];
  }

  [self waitForExpectationsWithTimeout:100 handler:nil];
}

#pragma mark Helpers

- (void)applyUpdateUsingBatchUpdates:(ASThrashUpdate *)update
                        toDataSource:(ASThrashDataSource *)dataSource animated:(BOOL)animated
                       useXCTestWait:(BOOL)wait
{
  CollectionView *collectionView = dataSource.collectionView;

  XCTestExpectation *expectation;
  if (wait) {
    expectation = [self expectationWithDescription:@"Wait for collection view to update"];
  }

  void (^updateBlock)() = ^ void (){
    dataSource.data = update.data;

    [collectionView insertSections:update.insertedSectionIndexes];
    [collectionView deleteSections:update.deletedSectionIndexes];
    [collectionView reloadSections:update.replacedSectionIndexes];

    [update.insertedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
      NSArray *indexPaths = [indexes indexPathsInSection:idx];
      [collectionView insertItemsAtIndexPaths:indexPaths];
    }];

    [update.deletedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
      NSArray *indexPaths = [indexes indexPathsInSection:idx];
      [collectionView deleteItemsAtIndexPaths:indexPaths];
    }];

    [update.replacedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
      NSArray *indexPaths = [indexes indexPathsInSection:idx];
      [collectionView reloadItemsAtIndexPaths:indexPaths];
    }];
  };

  @try {
    [collectionView performBatchAnimated:animated
                                 updates:updateBlock
                              completion:^(BOOL finished) {
                                [expectation fulfill];
                              }];
  } @catch (NSException *exception) {
    _failed = YES;
    XCTFail("TEST FAILED");
    @throw exception;
  }

  if (wait) {
    [self waitForExpectationsWithTimeout:1 handler:nil];
  }
}

@end
