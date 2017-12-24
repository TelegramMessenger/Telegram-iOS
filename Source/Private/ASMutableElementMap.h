//
//  ASMutableElementMap.h
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

#ifndef MINIMAL_ASDK

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASIntegerMap.h>

NS_ASSUME_NONNULL_BEGIN

@class ASSection, ASCollectionElement, _ASHierarchyChangeSet;

/**
 * This mutable version will be removed in the future. It's only here now to keep the diff small
 * as we port data controller to use ASElementMap.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASMutableElementMap : NSObject <NSCopying>

- (instancetype)init __unavailable;

- (instancetype)initWithSections:(NSArray<ASSection *> *)sections items:(ASCollectionElementTwoDimensionalArray *)items supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements;

- (void)insertSection:(ASSection *)section atIndex:(NSInteger)index;

- (void)removeAllSections;

/// Only modifies the array of ASSection * objects
- (void)removeSectionsAtIndexes:(NSIndexSet *)indexes;

- (void)removeAllElements;

- (void)removeItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (void)removeSectionsOfItems:(NSIndexSet *)itemSections;

- (void)insertEmptySectionsOfItemsAtIndexes:(NSIndexSet *)sections;

- (void)insertElement:(ASCollectionElement *)element atIndexPath:(NSIndexPath *)indexPath;

/**
 * Update the index paths for all supplementary elements to account for section-level
 * deletes, moves, inserts. This must be called before adding new supplementary elements.
 *
 * This also deletes any supplementary elements in deleted sections.
 */
- (void)migrateSupplementaryElementsWithSectionMapping:(ASIntegerMap *)mapping;

@end

@interface ASElementMap (MutableCopying) <NSMutableCopying>
@end

NS_ASSUME_NONNULL_END

#endif
