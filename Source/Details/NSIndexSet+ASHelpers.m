//
//  NSIndexSet+ASHelpers.m
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

// UIKit indexPath helpers
#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

@implementation NSIndexSet (ASHelpers)

- (NSIndexSet *)as_indexesByMapping:(NSUInteger (^)(NSUInteger))block
{
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
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
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  [self enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    [indexes enumerateRangesInRange:range options:kNilOptions usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
      [result addIndexesInRange:range];
    }];
  }];
  return result;
}

+ (NSIndexSet *)as_indexSetFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths inSection:(NSUInteger)section
{
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
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
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  for (NSIndexPath *indexPath in indexPaths) {
    [result addIndex:indexPath.section];
  }
  return result;
}

- (NSArray<NSIndexPath *> *)as_filterIndexPathsBySection:(id<NSFastEnumeration>)indexPaths
{
  NSMutableArray *result = [NSMutableArray array];
  for (NSIndexPath *indexPath in indexPaths) {
    if ([self containsIndex:indexPath.section]) {
      [result addObject:indexPath];
    }
  }
  return result;
}

@end
