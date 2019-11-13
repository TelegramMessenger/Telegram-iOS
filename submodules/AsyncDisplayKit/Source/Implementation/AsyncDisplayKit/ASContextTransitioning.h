//
//  ASContextTransitioning.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDimension.h>

@class ASDisplayNode;
@class ASLayout;

NS_ASSUME_NONNULL_BEGIN

AS_EXTERN NSString * const ASTransitionContextFromLayoutKey;
AS_EXTERN NSString * const ASTransitionContextToLayoutKey;

@protocol ASContextTransitioning <NSObject>

/**
 @abstract Defines if the given transition is animated
 */
- (BOOL)isAnimated;

/**
 * @abstract Retrieve either the "from" or "to" layout
 */
- (nullable ASLayout *)layoutForKey:(NSString *)key;

/**
 * @abstract Retrieve either the "from" or "to" constrainedSize
 */
- (ASSizeRange)constrainedSizeForKey:(NSString *)key;

/**
 * @abstract Retrieve the subnodes from either the "from" or "to" layout
 */
- (NSArray<ASDisplayNode *> *)subnodesForKey:(NSString *)key;

/**
 * @abstract Subnodes that have been inserted in the layout transition
 */
- (NSArray<ASDisplayNode *> *)insertedSubnodes;

/**
 * @abstract Subnodes that will be removed in the layout transition
 */
- (NSArray<ASDisplayNode *> *)removedSubnodes;

/**
 @abstract The frame for the given node before the transition began.
 @discussion Returns CGRectNull if the node was not in the hierarchy before the transition.
 */
- (CGRect)initialFrameForNode:(ASDisplayNode *)node;

/**
 @abstract The frame for the given node when the transition completes.
 @discussion Returns CGRectNull if the node is no longer in the hierarchy after the transition.
 */
- (CGRect)finalFrameForNode:(ASDisplayNode *)node;

/**
 @abstract Invoke this method when the transition is completed in `animateLayoutTransition:`
 @discussion Passing NO to `didComplete` will set the original layout as the new layout.
 */
- (void)completeTransition:(BOOL)didComplete;

@end

NS_ASSUME_NONNULL_END
