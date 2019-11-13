//
//  NSArray+Diffing.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/NSArray+Diffing.h>
#import <UIKit/NSIndexPath+UIKitAdditions.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <unordered_map>

@implementation NSArray (Diffing)

typedef BOOL (^compareBlock)(id _Nonnull lhs, id _Nonnull rhs);

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions
{
  [self asdk_diffWithArray:array insertions:insertions deletions:deletions moves:nil compareBlock:[NSArray defaultCompareBlock]];
}

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions
              compareBlock:(compareBlock)comparison
{
  [self asdk_diffWithArray:array insertions:insertions deletions:deletions moves:nil compareBlock:comparison];
}

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions
                     moves:(NSArray<NSIndexPath *> **)moves
{
  [self asdk_diffWithArray:array insertions:insertions deletions:deletions moves:moves
              compareBlock:[NSArray defaultCompareBlock]];
}

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions
                     moves:(NSArray<NSIndexPath *> **)moves compareBlock:(compareBlock)comparison
{
  struct NSObjectHash
  {
    std::size_t operator()(id <NSObject> k) const { return (std::size_t) [k hash]; };
  };
  struct NSObjectCompare
  {
    bool operator()(id <NSObject> lhs, id <NSObject> rhs) const { return (bool) [lhs isEqual:rhs]; };
  };
  std::unordered_multimap<unowned id, NSUInteger, NSObjectHash, NSObjectCompare> potentialMoves;

  NSAssert(comparison != nil, @"Comparison block is required");
  NSAssert(moves == nil || comparison == [NSArray defaultCompareBlock], @"move detection requires isEqual: and hash (no custom compare)");
  NSMutableArray<NSIndexPath *> *moveIndexPaths = nil;
  NSMutableIndexSet *insertionIndexes = nil, *deletionIndexes = nil;
  if (moves) {
    moveIndexPaths = [NSMutableArray new];
  }
  NSMutableIndexSet *commonIndexes = [self _asdk_commonIndexesWithArray:array compareBlock:comparison];

  if (deletions || moves) {
    deletionIndexes = [NSMutableIndexSet indexSet];
    NSUInteger i = 0;
    for (id element in self) {
      if (![commonIndexes containsIndex:i]) {
        [deletionIndexes addIndex:i];
      }
      if (moves) {
        potentialMoves.insert(std::pair<id, NSUInteger>(element, i));
      }
      ++i;
    }
  }

  if (insertions || moves) {
    insertionIndexes = [NSMutableIndexSet indexSet];
    NSArray *commonObjects = [self objectsAtIndexes:commonIndexes];
    for (NSUInteger i = 0, j = 0; j < array.count; j++) {
      auto moveFound = potentialMoves.find(array[j]);
      NSUInteger movedFrom = NSNotFound;
      if (moveFound != potentialMoves.end() && moveFound->second != j) {
        movedFrom = moveFound->second;
        potentialMoves.erase(moveFound);
        [moveIndexPaths addObject:[NSIndexPath indexPathForItem:j inSection:movedFrom]];
      }
      if (i < commonObjects.count && j < array.count && comparison(commonObjects[i], array[j])) {
        i++;
      } else {
        if (movedFrom != NSNotFound) {
          // moves will coalesce a delete / insert - the insert is just not done, and here we remove the delete:
          [deletionIndexes removeIndex:movedFrom];
          // OR a move will have come from the LCS:
          if ([commonIndexes containsIndex:movedFrom]) {
            [commonIndexes removeIndex:movedFrom];
            commonObjects = [self objectsAtIndexes:commonIndexes];
          }
        } else {
          [insertionIndexes addIndex:j];
        }
      }
    }
  }

  if (moves) {*moves = moveIndexPaths;}
  if (deletions) {*deletions = deletionIndexes;}
  if (insertions) {*insertions = insertionIndexes;}
}

// https://github.com/raywenderlich/swift-algorithm-club/tree/master/Longest%20Common%20Subsequence is not exactly this code (obviously), but
// is a good commentary on the algorithm.
- (NSMutableIndexSet *)_asdk_commonIndexesWithArray:(NSArray *)array compareBlock:(BOOL (^)(id lhs, id rhs))comparison
{
  NSAssert(comparison != nil, @"Comparison block is required");

  NSInteger selfCount = self.count;
  NSInteger arrayCount = array.count;

  // Allocate the diff map in the heap so we don't blow the stack for large arrays.
  NSInteger **lengths = NULL;
  lengths = (NSInteger **)malloc(sizeof(NSInteger*) * (selfCount+1));
  if (lengths == NULL) {
    ASDisplayNodeFailAssert(@"Failed to allocate memory for diffing");
    return nil;
  }
  // Fill in a LCS length matrix:
  for (NSInteger i = 0; i <= selfCount; i++) {
    lengths[i] = (NSInteger *)malloc(sizeof(NSInteger) * (arrayCount+1));
    if (lengths[i] == NULL) {
      ASDisplayNodeFailAssert(@"Failed to allocate memory for diffing");
      return nil;
    }
    id selfObj = i > 0 ? self[i-1] : nil;
    for (NSInteger j = 0; j <= arrayCount; j++) {
      if (i == 0 || j == 0) {
        lengths[i][j] = 0;
      } else if (comparison(selfObj, array[j-1])) {
        lengths[i][j] = 1 + lengths[i-1][j-1];
      } else {
        lengths[i][j] = MAX(lengths[i-1][j], lengths[i][j-1]);
      }
    }
  }
  // Backtrack to fill in indices based on length matrix:
  NSMutableIndexSet *common = [NSMutableIndexSet indexSet];
  NSInteger i = selfCount, j = arrayCount;
  while(i > 0 && j > 0) {
    if (comparison(self[i-1], array[j-1])) {
      [common addIndex:(i-1)];
      i--; j--;
    } else if (lengths[i-1][j] > lengths[i][j-1]) {
      i--;
    } else {
      j--;
    }
  }

  for (NSInteger i = 0; i <= selfCount; i++) {
    free(lengths[i]);
  }
  free(lengths);
  return common;
}

static compareBlock defaultCompare = nil;

+ (compareBlock)defaultCompareBlock
{
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    defaultCompare = ^BOOL(id lhs, id rhs) {
      return [lhs isEqual:rhs];
    };
  });

  return defaultCompare;
}

@end
