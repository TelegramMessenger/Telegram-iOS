//
//  ASCollectionLayoutState.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
@property (readonly) ASCollectionLayoutContext *context;

/// The final content size of the collection's layout
@property (readonly) CGSize contentSize;

- (instancetype)init NS_UNAVAILABLE;

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
