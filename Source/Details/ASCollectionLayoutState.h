//
//  ASCollectionLayoutState.h
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
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASCollectionLayoutContext, ASLayout, ASCollectionElement;

NS_ASSUME_NONNULL_BEGIN

typedef ASCollectionElement * _Nullable (^ASCollectionLayoutStateGetElementBlock)(ASLayout *);

@interface NSMapTable (ASCollectionLayoutConvenience)

+ (NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *)elementToLayoutAttributesTable;

@end

AS_SUBCLASSING_RESTRICTED

/// An immutable state of the collection layout
@interface ASCollectionLayoutState : NSObject

/// The context used to calculate this object
@property (nonatomic, strong, readonly) ASCollectionLayoutContext *context;

/// The final content size of the collection's layout
@property (nonatomic, assign, readonly) CGSize contentSize;

- (instancetype)init __unavailable;

/**
 * Designated initializer.
 *
 * @param context The context used to calculate this object
 *
 * @param contentSize The content size of the collection's layout
 *
 * @param table A map between elements to their layout attributes. It must contain all elements.
 * It should have NSMapTableObjectPointerPersonality and NSMapTableWeakMemory as key options.
 */
- (instancetype)initWithContext:(ASCollectionLayoutContext *)context
                    contentSize:(CGSize)contentSize
 elementToLayoutAttributesTable:(NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *)table NS_DESIGNATED_INITIALIZER;

/**
 * Convenience initializer. Returns an object with zero content size and an empty table.
 *
 * @param context The context used to calculate this object
 */
- (instancetype)initWithContext:(ASCollectionLayoutContext *)context;

/**
 * Convenience initializer.
 *
 * @param context The context used to calculate this object
 *
 * @param layout The layout describes size and position of all elements.
 *
 * @param getElementBlock A block that can retrieve the collection element from a sublayout of the root layout.
 */
- (instancetype)initWithContext:(ASCollectionLayoutContext *)context
                         layout:(ASLayout *)layout
                getElementBlock:(ASCollectionLayoutStateGetElementBlock)getElementBlock;

/**
 * Returns all layout attributes present in this object.
 */
- (NSArray<UICollectionViewLayoutAttributes *> *)allLayoutAttributes;

/**
 * Returns layout attributes of elements in the specified rect.
 *
 * @param rect The rect containing the target elements.
 */
- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect;

/**
 * Returns layout attributes of the element at the specified index path.
 *
 * @param indexPath The index path of the item.
 */
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns layout attributes of the specified supplementary element.
 *
 * @param kind A string that identifies the type of the supplementary element.
 *
 * @param indexPath The index path of the element.
 */
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind
                                                                                 atIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns layout attributes of the specified element.
 *
 * @element The element.
 */
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForElement:(ASCollectionElement *)element;

@end

NS_ASSUME_NONNULL_END

#endif
