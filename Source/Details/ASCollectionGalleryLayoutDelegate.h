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

@protocol ASCollectionGalleryLayoutSizeProviding <NSObject>

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

@end

/**
 * A thread-safe layout delegate that arranges items with the same size into a flow layout.
 *
 * @note Supplemenraty elements are not supported.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASCollectionGalleryLayoutDelegate : NSObject <ASCollectionLayoutDelegate>

@property (nonatomic, weak) id<ASCollectionGalleryLayoutSizeProviding> sizeProvider;

- (instancetype)initWithScrollableDirections:(ASScrollDirection)scrollableDirections NS_DESIGNATED_INITIALIZER;

- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END

#endif
