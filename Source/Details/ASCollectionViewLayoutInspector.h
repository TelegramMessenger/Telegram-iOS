//
//  ASCollectionViewLayoutInspector.h
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
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

@class ASCollectionView;
@protocol ASCollectionDataSource;
@protocol ASCollectionDelegate;

NS_ASSUME_NONNULL_BEGIN

extern ASSizeRange NodeConstrainedSizeForScrollDirection(ASCollectionView *collectionView);

@protocol ASCollectionViewLayoutInspecting <NSObject>

/**
 * Asks the inspector to provide a constrained size range for the given collection view node.
 */
- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Return the directions in which your collection view can scroll
 */
- (ASScrollDirection)scrollableDirections;

@optional

/**
 * Asks the inspector to provide a constrained size range for the given supplementary node.
 */
- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Asks the inspector for the number of supplementary views for the given kind in the specified section.
 */
- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section;

/**
 * Allow the inspector to respond to delegate changes.
 *
 * @discussion A great time to update perform selector caches!
 */
- (void)didChangeCollectionViewDelegate:(nullable id<ASCollectionDelegate>)delegate;

/**
 * Allow the inspector to respond to dataSource changes.
 *
 * @discussion A great time to update perform selector caches!
 */
- (void)didChangeCollectionViewDataSource:(nullable id<ASCollectionDataSource>)dataSource;

#pragma mark Deprecated Methods

/**
 * Asks the inspector for the number of supplementary sections in the collection view for the given kind.
 *
 * @deprecated This method will not be called, and it is only deprecated as a reminder to remove it.
 * Supplementary elements must exist in the same sections as regular collection view items i.e. -numberOfSectionsInCollectionView:
 */
- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryNodeOfKind:(NSString *)kind ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

@end

/**
 * A layout inspector for non-flow layouts that returns a constrained size to let the cells layout itself as
 * far as possible based on the scrollable direction of the collection view.
 * It doesn't support supplementary nodes and therefore doesn't implement delegate methods
 * that are related to supplementary node's management.
 *
 * @warning This class is not meant to be subclassed and will be restricted in the future.
 */
@interface ASCollectionViewLayoutInspector : NSObject <ASCollectionViewLayoutInspecting>

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView ASDISPLAYNODE_DEPRECATED_MSG("Use -init instead.");

@end


NS_ASSUME_NONNULL_END

#endif