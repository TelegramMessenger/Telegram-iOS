//
//  ASCollectionLayoutDelegate.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

@class ASElementMap, ASCollectionLayoutContext, ASCollectionLayoutState;

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionLayoutDelegate <NSObject>

/**
 * @abstract Returns the scrollable directions of the coming layout (@see @c -calculateLayoutWithContext:).
 * It will be available in the context parameter in +calculateLayoutWithContext:
 *
 * @return The scrollable directions.
 *
 * @discusstion This method will be called on main thread.
 */
- (ASScrollDirection)scrollableDirections;

/**
 * @abstract Returns any additional information needed for a coming layout pass (@see @c -calculateLayoutWithContext:) with the given elements.
 *
 * @param elements The elements to be laid out later.
 *
 * @discussion The returned object must support equality and hashing (i.e `-isEqual:` and `-hash` must be properly implemented).
 * It should contain all the information needed for the layout pass to perform. It will be available in the context parameter in +calculateLayoutWithContext:
 *
 * This method will be called on main thread.
 */
- (nullable id)additionalInfoForLayoutWithElements:(ASElementMap *)elements;

/**
 * @abstract Prepares and returns a new layout for given context.
 *
 * @param context A context that contains all elements to be laid out and any additional information needed.
 *
 * @return The new layout calculated for the given context.
 *
 * @discussion This method is called ahead of time, i.e before the underlying collection/table view is aware of the provided elements.
 * As a result, clients must solely rely on the given context and should not reach out to other objects for information not available in the context.
 *
 * This method can be called on background theads. It must be thread-safe and should not change any internal state of this delegate.
 * It must block the calling thread but can dispatch to other theads to reduce total blocking time.
 */
+ (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context;

@end

NS_ASSUME_NONNULL_END

#endif
