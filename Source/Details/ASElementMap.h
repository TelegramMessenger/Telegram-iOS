//
//  ASElementMap.h
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

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionElement, ASSection, UICollectionViewLayoutAttributes;
@protocol ASSectionContext;

/**
 * An immutable representation of the state of a collection view's data.
 * All items and supplementary elements are represented by ASCollectionElement.
 * Fast enumeration is in terms of ASCollectionElement.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASElementMap : NSObject <NSCopying, NSFastEnumeration>

/**
 * The number of sections (of items) in this map.
 */
@property (readonly) NSInteger numberOfSections;

/**
 * The kinds of supplementary elements present in this map. O(1)
 */
@property (copy, readonly) NSArray<NSString *> *supplementaryElementKinds;

/**
 * Returns number of items in the given section. O(1)
 */
- (NSInteger)numberOfItemsInSection:(NSInteger)section;

/**
 * Returns the context object for the given section, if any. O(1)
 */
- (nullable id<ASSectionContext>)contextForSection:(NSInteger)section;

/**
 * All the index paths for all the items in this map. O(N)
 *
 * This property may be removed in the future, since it doesn't account for supplementary nodes.
 */
@property (copy, readonly) NSArray<NSIndexPath *> *itemIndexPaths;

/**
 * All the item elements in this map, in ascending order. O(N)
 */
@property (copy, readonly) NSArray<ASCollectionElement *> *itemElements;

/**
 * Returns the index path that corresponds to the same element in @c map at the given @c indexPath.
 * O(1) for items, fast O(N) for sections.
 *
 * Note you can pass "section index paths" of length 1 and get a corresponding section index path.
 */
- (nullable NSIndexPath *)convertIndexPath:(NSIndexPath *)indexPath fromMap:(ASElementMap *)map;

/**
 * Returns the section index into the receiver that corresponds to the same element in @c map at @c sectionIndex. Fast O(N).
 *
 * Returns @c NSNotFound if the section does not exist in the receiver.
 */
- (NSInteger)convertSection:(NSInteger)sectionIndex fromMap:(ASElementMap *)map;

/**
 * Returns the index path for the given element. O(1)
 */
- (nullable NSIndexPath *)indexPathForElement:(ASCollectionElement *)element;

/**
 * Returns the index path for the given element, if it represents a cell. O(1)
 */
- (nullable NSIndexPath *)indexPathForElementIfCell:(ASCollectionElement *)element;

/**
 * Returns the item-element at the given index path. O(1)
 */
- (nullable ASCollectionElement *)elementForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns the element for the supplementary element of the given kind at the given index path. O(1)
 */
- (nullable ASCollectionElement *)supplementaryElementOfKind:(NSString *)supplementaryElementKind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns the element that corresponds to the given layout attributes, if any.
 *
 * NOTE: This method only regards the category, kind, and index path of the attributes object. Elements do not
 * have any concept of size/position.
 */
- (nullable ASCollectionElement *)elementForLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes;

/**
 * A very terse description e.g. { itemCounts = [ <S0: 1> <S1: 16> ] }
 */
@property (atomic, readonly) NSString *smallDescription;

#pragma mark - Initialization -- Only Useful to ASDataController


// SectionIndex -> ItemIndex -> Element
typedef NSArray<NSArray<ASCollectionElement *> *> ASCollectionElementTwoDimensionalArray;

// ElementKind -> IndexPath -> Element
typedef NSDictionary<NSString *, NSDictionary<NSIndexPath *, ASCollectionElement *> *> ASSupplementaryElementDictionary;

/**
 * Create a new element map for this dataset. You probably don't need to use this – ASDataController is the only one who creates these.
 *
 * @param sections The array of ASSection objects.
 * @param items A 2D array of ASCollectionElements, for each item.
 * @param supplementaryElements A dictionary of gathered supplementary elements.
 */
- (instancetype)initWithSections:(NSArray<ASSection *> *)sections
                           items:(ASCollectionElementTwoDimensionalArray *)items
           supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements;

@end

NS_ASSUME_NONNULL_END

#endif
