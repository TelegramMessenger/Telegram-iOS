//
//  ASCollectionViewLayoutFacilitatorProtocol.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#pragma once
#import <Foundation/Foundation.h>

/**
 * This facilitator protocol is intended to help Layout to better
 * gel with the CollectionView
 */
@protocol ASCollectionViewLayoutFacilitatorProtocol <NSObject>

/**
 * Inform that the collectionView is editing the cells at a list of indexPaths
 *
 * @param indexPaths an array of NSIndexPath objects of cells being/will be edited.
 * @param isBatched indicates whether the editing operation will be batched by the collectionView
 *
 * NOTE: when isBatched, used in combination with -collectionViewWillPerformBatchUpdates
 */
- (void)collectionViewWillEditCellsAtIndexPaths:(NSArray *)indexPaths batched:(BOOL)isBatched;

/**
 * Inform that the collectionView is editing the sections at a set of indexes
 *
 * @param indexes an NSIndexSet of section indexes being/will be edited.
 * @param batched indicates whether the editing operation will be batched by the collectionView
 *
 * NOTE: when batched, used in combination with -collectionViewWillPerformBatchUpdates
 */
- (void)collectionViewWillEditSectionsAtIndexSet:(NSIndexSet *)indexes batched:(BOOL)batched;

/**
 * Informs the delegate that the collectionView is about to call performBatchUpdates
 */
- (void)collectionViewWillPerformBatchUpdates;

@end

#endif
