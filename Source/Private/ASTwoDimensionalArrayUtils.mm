//
//  ASTwoDimensionalArrayUtils.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCollections.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>

#import <vector>

// Import UIKit to get [NSIndexPath indexPathForItem:inSection:] which uses
// tagged pointers.
#import <UIKit/UIKit.h>

#pragma mark - Public Methods

NSMutableArray<NSMutableArray *> *ASTwoDimensionalArrayDeepMutableCopy(NSArray<NSArray *> *array)
{
  NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
  NSInteger i = 0;
  for (NSArray *subarray in array) {
    ASDisplayNodeCAssert([subarray isKindOfClass:[NSArray class]], @"This function expects NSArray<NSArray *> *");
    newArray[i++] = [subarray mutableCopy];
  }
  return newArray;
}

void ASDeleteElementsInTwoDimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray<NSIndexPath *> *indexPaths)
{
  if (indexPaths.count == 0) {
    return;
  }

#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(asdk_inverseCompare:)];
  ASDisplayNodeCAssert([sortedIndexPaths isEqualToArray:indexPaths], @"Expected array of index paths to be sorted in descending order.");
#endif

  /**
   * It is tempting to do something clever here and collect indexes into ranges or NSIndexSets
   * but deep down, __NSArrayM only implements removeObjectAtIndex: and so doing all that extra
   * work ends up running the same code.
   */
  for (NSIndexPath *indexPath in indexPaths) {
    NSInteger section = indexPath.section;
    if (section >= mutableArray.count) {
      ASDisplayNodeCFailAssert(@"Invalid section index %ld – only %ld sections", (long)section, (long)mutableArray.count);
      continue;
    }

    NSMutableArray *subarray = mutableArray[section];
    NSInteger item = indexPath.item;
    if (item >= subarray.count) {
      ASDisplayNodeCFailAssert(@"Invalid item index %ld – only %ld items in section %ld", (long)item, (long)subarray.count, (long)section);
      continue;
    }
    [subarray removeObjectAtIndex:item];
  }
}

NSArray<NSIndexPath *> *ASIndexPathsForTwoDimensionalArray(NSArray <NSArray *>* twoDimensionalArray)
{
  NSInteger sectionCount = twoDimensionalArray.count;
  NSInteger counts[sectionCount];
  NSInteger totalCount = 0;
  NSInteger i = 0;
  for (NSArray *subarray in twoDimensionalArray) {
    NSInteger count = subarray.count;
    counts[i++] = count;
    totalCount += count;
  }
  
  // Count could be huge. Use a reserved vector rather than VLA (stack.)
  std::vector<NSIndexPath *> indexPaths;
  indexPaths.reserve(totalCount);
  for (NSInteger i = 0; i < sectionCount; i++) {
    for (NSInteger j = 0; j < counts[i]; j++) {
      indexPaths.push_back([NSIndexPath indexPathForItem:j inSection:i]);
    }
  }
  return [NSArray arrayByTransferring:indexPaths.data() count:totalCount];
}

NSArray *ASElementsInTwoDimensionalArray(NSArray <NSArray *>* twoDimensionalArray)
{
  NSInteger totalCount = 0;
  for (NSArray *subarray in twoDimensionalArray) {
    totalCount += subarray.count;
  }
  
  std::vector<id> elements;
  elements.reserve(totalCount);
  for (NSArray *subarray in twoDimensionalArray) {
    for (id object in subarray) {
      elements.push_back(object);
    }
  }
  return [NSArray arrayByTransferring:elements.data() count:totalCount];
}

id ASGetElementInTwoDimensionalArray(NSArray *array, NSIndexPath *indexPath)
{
  ASDisplayNodeCAssertNotNil(indexPath, @"Expected non-nil index path");
  ASDisplayNodeCAssert(indexPath.length == 2, @"Expected index path of length 2. Index path: %@", indexPath);
  NSInteger section = indexPath.section;
  if (array.count <= section) {
    return nil;
  }

  NSArray *innerArray = array[section];
  NSInteger item = indexPath.item;
  if (innerArray.count <= item) {
    return nil;
  }
  return innerArray[item];
}
