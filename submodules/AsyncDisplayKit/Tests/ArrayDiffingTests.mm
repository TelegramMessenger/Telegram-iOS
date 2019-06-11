//
//  ArrayDiffingTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/NSArray+Diffing.h>

@interface NSArray (ArrayDiffingTests)
- (NSIndexSet *)_asdk_commonIndexesWithArray:(NSArray *)array compareBlock:(BOOL (^)(id lhs, id rhs))comparison;
@end

@interface ArrayDiffingTests : XCTestCase

@end

@implementation ArrayDiffingTests

- (void)testDiffingCommonIndexes
{
  NSArray<NSArray *> *tests = @[
    @[
      @[@"bob", @"alice", @"dave"],
      @[@"bob", @"alice", @"dave", @"gary"],
      @[@0, @1, @2]
    ],
    @[
      @[@"bob", @"alice", @"dave"],
      @[@"bob", @"gary", @"dave"],
      @[@0, @2]
    ],
    @[
      @[@"bob", @"alice"],
      @[@"gary", @"dave"],
      @[],
    ],
    @[
      @[@"bob", @"alice", @"dave"],
      @[],
      @[],
    ],
    @[
      @[],
      @[@"bob", @"alice", @"dave"],
      @[],
    ],
  ];

  for (NSArray *test in tests) {
    NSIndexSet *indexSet = [test[0] _asdk_commonIndexesWithArray:test[1] compareBlock:^BOOL(id lhs, id rhs) {
      return [lhs isEqual:rhs];
    }];
    NSMutableIndexSet *mutableIndexSet = [indexSet mutableCopy];
    
    for (NSNumber *index in (NSArray *)test[2]) {
      XCTAssert([indexSet containsIndex:[index integerValue]]);
      [mutableIndexSet removeIndex:[index integerValue]];
    }

    XCTAssert([mutableIndexSet count] == 0, @"Unaccounted deletions: %@", mutableIndexSet);
  }
}

- (void)testDiffingInsertionsAndDeletions {
  NSArray<NSArray *> *tests = @[
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"bob", @"alice", @"dave", @"gary"],
        @[@3],
        @[],
      ],
      @[
        @[@"a", @"b", @"c", @"d"],
        @[@"d", @"c", @"b", @"a"],
        @[@1, @2, @3],
        @[@0, @1, @2],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"bob", @"gary", @"alice", @"dave"],
        @[@1],
        @[],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"bob", @"alice"],
        @[],
        @[@2],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[],
        @[],
        @[@0, @1, @2],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"gary", @"alice", @"dave", @"jack"],
        @[@0, @3],
        @[@0],
      ],
      @[
        @[@"bob", @"alice", @"dave", @"judy", @"lynda", @"tony"],
        @[@"gary", @"bob", @"suzy", @"tony"],
        @[@0, @2],
        @[@1, @2, @3, @4],
      ],
      @[
        @[@"bob", @"alice", @"dave", @"judy"],
        @[@"judy", @"dave", @"alice", @"bob"],
        @[@1, @2, @3],
        @[@0, @1, @2],
      ],
  ];

  long n = 0;
  for (NSArray *test in tests) {
    NSIndexSet *insertions, *deletions;
    [test[0] asdk_diffWithArray:test[1] insertions:&insertions deletions:&deletions];
    NSMutableIndexSet *mutableInsertions = [insertions mutableCopy];
    NSMutableIndexSet *mutableDeletions = [deletions mutableCopy];

    for (NSNumber *index in (NSArray *)test[2]) {
      XCTAssert([mutableInsertions containsIndex:[index integerValue]], @"Test #%ld: insertions %@ does not contain %@",
      n, insertions, index);
      [mutableInsertions removeIndex:[index integerValue]];
    }
    for (NSNumber *index in (NSArray *)test[3]) {
      XCTAssert([mutableDeletions containsIndex:[index integerValue]], @"Test #%ld: deletions %@ does not contain %@",
      n, deletions, index
      );
      [mutableDeletions removeIndex:[index integerValue]];
    }

    XCTAssert([mutableInsertions count] == 0, @"Test #%ld: Unaccounted insertions: %@", n, mutableInsertions);
    XCTAssert([mutableDeletions count] == 0, @"Test #%ld: Unaccounted deletions: %@", n, mutableDeletions);
    n++;
  }
}

- (void)testDiffingInsertsDeletesAndMoves
{
  NSArray<NSArray *> *tests = @[
          @[
                  @[@"a", @"b"],
                  @[@"b", @"a"],
                  @[],
                  @[],
                  @[[NSIndexPath indexPathWithIndexes:(NSUInteger[]) {1, 0} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]) {0, 1} length:2]
                  ]],
          @[
                  @[@"bob", @"alice", @"dave"],
                  @[@"bob", @"alice", @"dave", @"gary"],
                  @[@3],
                  @[],
                  @[]],
          @[
                  @[@"a", @"b", @"c", @"d"],
                  @[@"d", @"c", @"b", @"a"],
                  @[],
                  @[],
                  @[[NSIndexPath indexPathWithIndexes:(NSUInteger[]){3, 0} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]){2, 1} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]){1, 2} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]){0, 3} length:2]
                  ]],
          @[
                  @[@"bob", @"alice", @"dave"],
                  @[@"bob", @"gary", @"dave", @"alice"],
                  @[@1],
                  @[],
                  @[[NSIndexPath indexPathWithIndexes:(NSUInteger[]) {1, 3} length:2]
                  ]],
          @[
                  @[@"bob", @"alice", @"dave"],
                  @[@"bob", @"alice"],
                  @[],
                  @[@2],
                  @[]],
          @[
                  @[@"bob", @"alice", @"dave"],
                  @[],
                  @[],
                  @[@0, @1, @2],
                  @[]],
          @[
                  @[@"bob", @"alice", @"dave"],
                  @[@"gary", @"alice", @"dave", @"jack"],
                  @[@0, @3],
                  @[@0],
                  @[]],
          @[
                  @[@"bob", @"alice", @"dave", @"judy", @"lynda", @"tony"],
                  @[@"gary", @"bob", @"suzy", @"tony"],
                  @[@0, @2],
                  @[@1, @2, @3, @4],
                  @[[NSIndexPath indexPathWithIndexes:(NSUInteger[]){0, 1} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]){5, 3} length:2]
                  ]],
          @[
                  @[@"bob", @"alice", @"dave", @"judy"],
                  @[@"judy", @"dave", @"alice", @"bob"],
                  @[],
                  @[],
                  @[[NSIndexPath indexPathWithIndexes:(NSUInteger[]){3, 0} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]){2, 1} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]){1, 2} length:2],
                          [NSIndexPath indexPathWithIndexes:(NSUInteger[]){0, 3} length:2]
                  ]]

  ];

  long n = 0;
  for (NSArray *test in tests) {
    NSIndexSet *insertions, *deletions;
    NSArray<NSIndexPath *> *moves;
    [test[0] asdk_diffWithArray:test[1] insertions:&insertions deletions:&deletions moves:&moves];
    NSMutableIndexSet *mutableInsertions = [insertions mutableCopy];
    NSMutableIndexSet *mutableDeletions = [deletions mutableCopy];

    for (NSNumber *index in (NSArray *) test[2]) {
      XCTAssert([mutableInsertions containsIndex:[index integerValue]], @"Test #%ld, insertions does not contain %ld",
              n, (long)[index integerValue]);
      [mutableInsertions removeIndex:(NSUInteger) [index integerValue]];
    }
    for (NSNumber *index in (NSArray *) test[3]) {
      XCTAssert([mutableDeletions containsIndex:[index integerValue]], @"Test #%ld, deletions does not contain %ld",
              n, (long)[index integerValue]);
      [mutableDeletions removeIndex:(NSUInteger) [index integerValue]];
    }

    XCTAssert([mutableInsertions count] == 0, @"Test #%ld, Unaccounted insertions: %@", n, mutableInsertions);
    XCTAssert([mutableDeletions count] == 0, @"Test #%ld, Unaccounted deletions: %@", n, mutableDeletions);

    XCTAssert([moves isEqual:test[4]], @"Test #%ld, %@ !isEqual: %@", n, moves, test[4]);
    n++;
  }
}

- (void)testArrayDiffingRebuildingWithRandomElements
{
  NSArray<NSNumber *> *original = @[];
  NSArray<NSNumber *> *pending = @[];

  NSIndexSet *insertions = nil;
  NSIndexSet *deletions = nil;
  NSArray<NSIndexPath *> *moves;

  for (int testNumber = 0; testNumber <= 25; testNumber++) {
    int len = arc4random_uniform(10);
    for (int j = 0; j < len; j++) {
      original = [original arrayByAddingObject:@(arc4random_uniform(25))];
    }
    len = arc4random_uniform(10);
    for (int j = 0; j < len; j++) {
      pending = [pending arrayByAddingObject:@(arc4random_uniform(25))];
    }
    // Some sequences that presented issues in the past:
    if (testNumber == 0) {
      original = @[@20, @11, @14, @2, @14, @5, @4, @18, @0];
      pending = @[@9, @18, @18, @19, @20, @18, @22, @10, @3];
    }
    if (testNumber == 1) {
      original = @[@5, @9, @21, @11, @5, @9, @8];
      pending = @[@2, @12, @17, @19, @9, @1, @8, @5, @21];
    }
    if (testNumber == 2) {
      original = @[@14, @14, @12, @8, @20, @4, @0, @10];
      pending = @[@14];
    }

    [original asdk_diffWithArray:pending insertions:&insertions deletions:&deletions moves:&moves];

    NSMutableArray *deletionsList = [NSMutableArray new];
    [deletions enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
      [deletionsList addObject:@(idx)];
    }];
    NSMutableArray *insertionsList = [NSMutableArray new];
    [insertions enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
      [insertionsList addObject:@(idx)];
    }];

    NSUInteger i = 0;
    NSUInteger j = 0;
    NSMutableArray<NSNumber *> *test = [NSMutableArray new];
    for (NSUInteger count = 0; count < [pending count]; count++) {
      if (i < [insertionsList count] && [insertionsList[i] unsignedIntegerValue] == count) {
        [test addObject:pending[[insertionsList[i] unsignedIntegerValue]]];
        i++;
      } else if (j < [moves count] && [moves[j] indexAtPosition:1] == count) {
        [test addObject:original[[moves[j] indexAtPosition:0]]];
        j++;
      } else {
        [test addObject:original[count]];
      }
    }

    XCTAssert([test isEqualToArray:pending], @"Did not mutate to expected new array:\n [%@] -> [%@], actual: [%@]\ninsertions: %@\nmoves: %@\ndeletions: %@",
            [original componentsJoinedByString:@","], [pending componentsJoinedByString:@","], [test componentsJoinedByString:@","],
            insertions, moves, deletions);
    original = @[];
    pending = @[];
  }
}
@end
