//
//  NSIndexSet+ASHelpers.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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

@end
