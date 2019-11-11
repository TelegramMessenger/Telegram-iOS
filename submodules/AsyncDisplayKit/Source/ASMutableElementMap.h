//
//  ASMutableElementMap.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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

- (void)removeSupplementaryElementsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths kind:(NSString *)kind;

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
