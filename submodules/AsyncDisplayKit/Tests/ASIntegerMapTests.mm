//
//  ASIntegerMapTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASTestCase.h"
#import "ASIntegerMap.h"

@interface ASIntegerMapTests : ASTestCase

@end

@implementation ASIntegerMapTests

- (void)testIsEqual
{
  ASIntegerMap *map = [[ASIntegerMap alloc] init];
  [map setInteger:1 forKey:0];
  ASIntegerMap *alsoMap = [[ASIntegerMap alloc] init];
  [alsoMap setInteger:1 forKey:0];
  ASIntegerMap *notMap = [[ASIntegerMap alloc] init];
  [notMap setInteger:2 forKey:0];
  XCTAssertEqualObjects(map, alsoMap);
  XCTAssertNotEqualObjects(map, notMap);
}

#pragma mark - Changeset mapping

/// 1 item, no changes -> identity map
- (void)testEmptyChange
{
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:1 deleted:nil inserted:nil];
  XCTAssertEqual(map, ASIntegerMap.identityMap);
}

/// 0 items -> empty map
- (void)testChangeOnNoData
{
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:0 deleted:nil inserted:nil];
  XCTAssertEqual(map, ASIntegerMap.emptyMap);
}

/// 2 items, delete 0
- (void)testBasicChange1
{
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:2 deleted:[NSIndexSet indexSetWithIndex:0] inserted:nil];
  XCTAssertEqual([map integerForKey:0], NSNotFound);
  XCTAssertEqual([map integerForKey:1], 0);
  XCTAssertEqual([map integerForKey:2], NSNotFound);
}

/// 2 items, insert 0
- (void)testBasicChange2
{
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:2 deleted:nil inserted:[NSIndexSet indexSetWithIndex:0]];
  XCTAssertEqual([map integerForKey:0], 1);
  XCTAssertEqual([map integerForKey:1], 2);
  XCTAssertEqual([map integerForKey:2], NSNotFound);
}

/// 2 items, insert 0, delete 0
- (void)testChange1
{
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:2 deleted:[NSIndexSet indexSetWithIndex:0] inserted:[NSIndexSet indexSetWithIndex:0]];
  XCTAssertEqual([map integerForKey:0], NSNotFound);
  XCTAssertEqual([map integerForKey:1], 1);
  XCTAssertEqual([map integerForKey:2], NSNotFound);
}

/// 4 items, insert {0-1, 3}
- (void)testChange2
{
  NSMutableIndexSet *inserts = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)];
  [inserts addIndex:3];
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:4 deleted:nil inserted:inserts];
  XCTAssertEqual([map integerForKey:0], 2);
  XCTAssertEqual([map integerForKey:1], 4);
  XCTAssertEqual([map integerForKey:2], 5);
  XCTAssertEqual([map integerForKey:3], 6);
}

/// 4 items, delete {0-1, 3}
- (void)testChange3
{
  NSMutableIndexSet *deletes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)];
  [deletes addIndex:3];
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:4 deleted:deletes inserted:nil];
  XCTAssertEqual([map integerForKey:0], NSNotFound);
  XCTAssertEqual([map integerForKey:1], NSNotFound);
  XCTAssertEqual([map integerForKey:2], 0);
  XCTAssertEqual([map integerForKey:3], NSNotFound);
}

/// 5 items, delete {0-1, 3} insert {1-2, 4}
- (void)testChange4
{
  NSMutableIndexSet *deletes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)];
  [deletes addIndex:3];
  NSMutableIndexSet *inserts = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)];
  [inserts addIndex:4];
  ASIntegerMap *map = [ASIntegerMap mapForUpdateWithOldCount:5 deleted:deletes inserted:inserts];
  XCTAssertEqual([map integerForKey:0], NSNotFound);
  XCTAssertEqual([map integerForKey:1], NSNotFound);
  XCTAssertEqual([map integerForKey:2], 0);
  XCTAssertEqual([map integerForKey:3], NSNotFound);
  XCTAssertEqual([map integerForKey:4], 3);
  XCTAssertEqual([map integerForKey:5], NSNotFound);
}

@end
