//
//  NSIndexSet+ASHelpers.h
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

#import <Foundation/Foundation.h>

@interface NSIndexSet (ASHelpers)

- (NSIndexSet *)as_indexesByMapping:(NSUInteger (^)(NSUInteger idx))block;

- (NSIndexSet *)as_intersectionWithIndexes:(NSIndexSet *)indexes;

/// Returns all the item indexes from the given index paths that are in the given section.
+ (NSIndexSet *)as_indexSetFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths inSection:(NSUInteger)section;

/// If you've got an old index, and you insert items using this index set, this returns the change to get to the new index.
- (NSUInteger)as_indexChangeByInsertingItemsBelowIndex:(NSUInteger)index;

- (NSString *)as_smallDescription;

/// Returns all the section indexes contained in the index paths array.
+ (NSIndexSet *)as_sectionsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (NSArray<NSIndexPath *> *)as_filterIndexPathsBySection:(id<NSFastEnumeration>)indexPaths;

@end
