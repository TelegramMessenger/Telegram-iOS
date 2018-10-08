//
//  ASLayoutTransition.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/_ASTransitionContext.h>
#import <AsyncDisplayKit/ASDisplayNodeLayout.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASLayoutElementTransition

/**
 * Objects conform to this project returns if it's possible to layout asynchronous
 */
@protocol ASLayoutElementTransition <NSObject>

/**
 * @abstract Returns if the layoutElement can be used to layout in an asynchronous way on a background thread.
 */
@property (nonatomic, readonly) BOOL canLayoutAsynchronous;

@end

@interface ASDisplayNode () <ASLayoutElementTransition>
@end
@interface ASLayoutSpec () <ASLayoutElementTransition>
@end


#pragma mark - ASLayoutTransition

AS_SUBCLASSING_RESTRICTED
@interface ASLayoutTransition : NSObject <_ASTransitionContextLayoutDelegate>

/**
 * Node to apply layout transition on
 */
@property (nonatomic, weak, readonly) ASDisplayNode *node;

/**
 * Previous layout to transition from
 */
@property (nonatomic, readonly) const ASDisplayNodeLayout &previousLayout NS_RETURNS_INNER_POINTER;

/**
 * Pending layout to transition to
 */
@property (nonatomic, readonly) const ASDisplayNodeLayout &pendingLayout NS_RETURNS_INNER_POINTER;

/**
 * Returns if the layout transition needs to happen synchronously
 */
@property (nonatomic, readonly) BOOL isSynchronous;

/**
 * Returns a newly initialized layout transition
 */
- (instancetype)initWithNode:(ASDisplayNode *)node
               pendingLayout:(const ASDisplayNodeLayout &)pendingLayout
              previousLayout:(const ASDisplayNodeLayout &)previousLayout NS_DESIGNATED_INITIALIZER;

/**
 * Insert and remove subnodes that were added or removed between the previousLayout and the pendingLayout
 */
- (void)commitTransition;

/**
 * Insert all new subnodes that were added and move the subnodes that moved between the previous layout and
 * the pending layout.
 */
- (void)applySubnodeInsertionsAndMoves;

/**
 * Remove all subnodes that are removed between the previous layout and the pending layout
 */
- (void)applySubnodeRemovals;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
