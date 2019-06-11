//
//  ASTableViewThrashTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASTableViewInternal.h>
#import <AsyncDisplayKit/ASTableView+Undeprecated.h>
#import <stdatomic.h>

#import "ASThrashUtility.h"

@interface ASTableViewThrashTests: XCTestCase
@end

@implementation ASTableViewThrashTests
{
  // The current update, which will be logged in case of a failure.
  ASThrashUpdate *_update;
  BOOL _failed;
}

#pragma mark Overrides

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

#pragma mark Test Methods

// Disabled temporarily due to issue where cell nodes are not marked invisible before deallocation.
- (void)testInitialDataRead
{
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initTableViewDataSourceWithData:[ASThrashTestSection sectionsWithCount:kInitialSectionCount]];
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
  
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initTableViewDataSourceWithData:_update.oldData];
  ds.tableView.test_enableSuperUpdateCallLogging = YES;
  [self applyUpdate:_update toDataSource:ds];
  [self verifyDataSource:ds];
}

// Disabled temporarily due to issue where cell nodes are not marked invisible before deallocation.
- (void)testThrashingWildly
{
  for (NSInteger i = 0; i < kThrashingIterationCount; i++) {
    [self setUp];
    @autoreleasepool {
      NSArray *sections = [ASThrashTestSection sectionsWithCount:kInitialSectionCount];
      _update = [[ASThrashUpdate alloc] initWithData:sections];
      ASThrashDataSource *ds = [[ASThrashDataSource alloc] initTableViewDataSourceWithData:sections];

      [self applyUpdate:_update toDataSource:ds];
      [self verifyDataSource:ds];
      [self expectationForPredicate:[ds predicateForDeallocatedHierarchy] evaluatedWithObject:(id)kCFNull handler:nil];
    }
    [self waitForExpectationsWithTimeout:3 handler:nil];

    [self tearDown];
  }
}

#pragma mark Helpers

- (void)applyUpdate:(ASThrashUpdate *)update toDataSource:(ASThrashDataSource *)dataSource
{
  TableView *tableView = dataSource.tableView;
  
  [tableView beginUpdates];
  dataSource.data = update.data;
  
  [tableView insertSections:update.insertedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView deleteSections:update.deletedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView reloadSections:update.replacedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [update.insertedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:idx];
    [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [update.deletedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [update.replacedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  @try {
    [tableView endUpdatesAnimated:NO completion:nil];
#if !USE_UIKIT_REFERENCE
    [tableView waitUntilAllUpdatesAreCommitted];
#endif
  } @catch (NSException *exception) {
    _failed = YES;
    @throw exception;
  }
}

- (void)verifyDataSource:(ASThrashDataSource *)ds
{
  TableView *tableView = ds.tableView;
  NSArray <ASThrashTestSection *> *data = [ds data];
  XCTAssertEqual(data.count, tableView.numberOfSections);
  for (NSInteger i = 0; i < tableView.numberOfSections; i++) {
    XCTAssertEqual([tableView numberOfRowsInSection:i], data[i].items.count);
    XCTAssertEqual([tableView rectForHeaderInSection:i].size.height, data[i].headerHeight);

    for (NSInteger j = 0; j < [tableView numberOfRowsInSection:i]; j++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:j inSection:i];
      ASThrashTestItem *item = data[i].items[j];
#if USE_UIKIT_REFERENCE
      XCTAssertEqual([tableView rectForRowAtIndexPath:indexPath].size.height, item.rowHeight);
#else
      ASThrashTestNode *node = (ASThrashTestNode *)[tableView nodeForRowAtIndexPath:indexPath];
      XCTAssertEqualObjects(node.item, item, @"Wrong node at index path %@", indexPath);
#endif
    }
  }
}

@end
