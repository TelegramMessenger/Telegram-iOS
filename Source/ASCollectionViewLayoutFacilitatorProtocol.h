//
//  ASCollectionViewLayoutFacilitatorProtocol.h
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
