//
//  NSIndexSet+ASHelpers.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

// UIKit indexPath helpers
#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

@implementation NSIndexSet (ASHelpers)

- (NSIndexSet *)as_indexesByMapping:(NSUInteger (^)(NSUInteger))block
{
  NSMutableIndexSet *result = [[NSMutableIndexSet alloc] init];
  [self enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
      NSUInteger newIndex = block(i);
      if (newIndex != NSNotFound) {
        [result addIndex:newIndex];
      }
    }
  }];
  return result;
}

- (NSIndexSet *)as_intersectionWithIndexes:(NSIndexSet *)indexes
{
  NSMutableIndexSet *result = [[NSMutableIndexSet alloc] init];
  [self enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    [indexes enumerateRangesInRange:range options:kNilOptions usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
      [result addIndexesInRange:range];
    }];
  }];
  return result;
}

+ (NSIndexSet *)as_indexSetFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths inSection:(NSUInteger)section
{
  NSMutableIndexSet *result = [[NSMutableIndexSet alloc] init];
  for (NSIndexPath *indexPath in indexPaths) {
    if (indexPath.section == section) {
      [result addIndex:indexPath.item];
    }
  }
  return result;
}

- (NSUInteger)as_indexChangeByInsertingItemsBelowIndex:(NSUInteger)index
{
  __block NSUInteger newIndex = index;
  [self enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
      if (i <= newIndex) {
        newIndex += 1;
      } else {
        *stop = YES;
      }
    }
  }];
  return newIndex - index;
}

- (NSString *)as_smallDescription
{
  NSMutableString *result = [NSMutableString stringWithString:@"{ "];
  [self enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    if (range.length == 1) {
      [result appendFormat:@"%tu ", range.location];
    } else {
      [result appendFormat:@"%tu-%tu ", range.location, NSMaxRange(range) - 1];
    }
  }];
  [result appendString:@"}"];
  return result;
}

+ (NSIndexSet *)as_sectionsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
  NSMutableIndexSet *result = [[NSMutableIndexSet alloc] init];
  for (NSIndexPath *indexPath in indexPaths) {
    [result addIndex:indexPath.section];
  }
  return result;
}

@end
