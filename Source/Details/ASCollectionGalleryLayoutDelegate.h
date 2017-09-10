//
//  ASCollectionGalleryLayoutDelegate.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionLayoutDelegate.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

@class ASElementMap;

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionGalleryLayoutPropertiesProviding <NSObject>

/**
 * Returns the fixed size of each and every element.
 *
 * @discussion This method will only be called on main thread.
 *
 * @param elements All elements to be sized.
 *
 * @return The elements' size
 */
- (CGSize)sizeForElements:(ASElementMap *)elements;

@optional

/**
 * Returns the minumum spacing to use between lines of items.
 *
 * @discussion This method will only be called on main thread.
 *
 * @discussion For a vertically scrolling layout, this value represents the minimum spacing between rows.
 * For a horizontally scrolling one, it represents the minimum spacing between columns.
 * It is not applied between the first line and the header, or between the last line and the footer.
 * This is the same behavior as UICollectionViewFlowLayout's minimumLineSpacing.
 *
 * @param elements All elements in the layout.
 *
 * @return The interitem spacing
 */
- (CGFloat)minimumLineSpacingForElements:(ASElementMap *)elements;

/**
 * Returns the minumum spacing to use between items in the same row or column, depending on the scroll directions.
 *
 * @discussion This method will only be called on main thread.
 *
 * @discussion For a vertically scrolling layout, this value represents the minimum spacing between items in the same row. 
 * For a horizontally scrolling one, it represents the minimum spacing between items in the same column.
 * It is considered while fitting items into lines, but the actual final spacing between some items might be larger.
 * This is the same behavior as UICollectionViewFlowLayout's minimumInteritemSpacing.
 *
 * @param elements All elements in the layout.
 *
 * @return The interitem spacing
 */
- (CGFloat)minimumInteritemSpacingForElements:(ASElementMap *)elements;

/**
 * Returns the margins of each section.
 *
 * @discussion This method will only be called on main thread.
 *
 * @param elements All elements in the layout.
 *
 * @return The margins used to layout content in a section
 */
- (UIEdgeInsets)sectionInsetForElements:(ASElementMap *)elements;

@end

/**
 * A thread-safe layout delegate that arranges items with the same size into a flow layout.
 *
 * @note Supplemenraty elements are not supported.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASCollectionGalleryLayoutDelegate : NSObject <ASCollectionLayoutDelegate>

@property (nonatomic, weak) id<ASCollectionGalleryLayoutPropertiesProviding> propertiesProvider;

/**
 * Designated initializer.
 *
 * @param scrollableDirections The scrollable directions of this layout. Must be either vertical or horizontal directions.
 */
- (instancetype)initWithScrollableDirections:(ASScrollDirection)scrollableDirections NS_DESIGNATED_INITIALIZER;

- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END

#endif
