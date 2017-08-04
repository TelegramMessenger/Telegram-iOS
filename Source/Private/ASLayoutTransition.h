//
//  ASLayoutTransition.h
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

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/_ASTransitionContext.h>
#import <AsyncDisplayKit/ASDisplayNodeLayout.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>

#import <memory>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASLayoutElementTransition

/**
 * Objects conform to this project returns if it's possible to layout asynchronous
 */
@protocol ASLayoutElementTransition <NSObject>

/**
 * @abstract Returns if the layoutElement can be used to layout in an asynchronous way on a background thread.
 */
@property (nonatomic, assign, readonly) BOOL canLayoutAsynchronous;

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
@property (nonatomic, readonly, weak) ASDisplayNode *node;

/**
 * Previous layout to transition from
 */
@property (nonatomic, readonly, assign) std::shared_ptr<ASDisplayNodeLayout> previousLayout;

/**
 * Pending layout to transition to
 */
@property (nonatomic, readonly, assign) std::shared_ptr<ASDisplayNodeLayout> pendingLayout;

/**
 * Returns if the layout transition needs to happen synchronously
 */
@property (nonatomic, readonly, assign) BOOL isSynchronous;

/**
 * Returns a newly initialized layout transition
 */
- (instancetype)initWithNode:(ASDisplayNode *)node
               pendingLayout:(std::shared_ptr<ASDisplayNodeLayout>)pendingLayout
              previousLayout:(std::shared_ptr<ASDisplayNodeLayout>)previousLayout NS_DESIGNATED_INITIALIZER;

/**
 * Insert and remove subnodes that were added or removed between the previousLayout and the pendingLayout
 */
- (void)commitTransition;

/**
 * Insert all new subnodes that were added between the previous layout and the pending layout
 */
- (void)applySubnodeInsertions;

/**
 * Remove all subnodes that are removed between the previous layout and the pending layout
 */
- (void)applySubnodeRemovals;

@end

@interface ASLayoutTransition (Unavailable)

- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END
