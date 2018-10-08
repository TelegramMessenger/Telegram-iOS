//
//  ASCollectionInternal.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionView.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionViewLayoutFacilitatorProtocol;
@class ASCollectionNode;
@class ASDataController;
@class ASRangeController;

@interface ASCollectionView ()
- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(nullable id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator owningNode:(nullable ASCollectionNode *)owningNode eventLog:(nullable ASEventLog *)eventLog;

@property (nonatomic, weak) ASCollectionNode *collectionNode;
@property (nonatomic, readonly) ASDataController *dataController;
@property (nonatomic, readonly) ASRangeController *rangeController;

/**
 * The change set that we're currently building, if any.
 */
@property (nonatomic, nullable, readonly) _ASHierarchyChangeSet *changeSet;

/**
 * @see ASCollectionNode+Beta.h for full documentation.
 */
@property (nonatomic) BOOL usesSynchronousDataLoading;

/**
 * Attempt to get the view-layer index path for the item with the given index path.
 *
 * @param indexPath The index path of the item.
 * @param wait If the item hasn't reached the view yet, this attempts to wait for updates to commit.
 */
- (nullable NSIndexPath *)convertIndexPathFromCollectionNode:(NSIndexPath *)indexPath waitingIfNeeded:(BOOL)wait;

/**
 * Attempt to get the node index path given the view-layer index path.
 *
 * @param indexPath The index path of the row.
 */
- (nullable NSIndexPath *)convertIndexPathToCollectionNode:(NSIndexPath *)indexPath;

/**
 * Attempt to get the node index paths given the view-layer index paths.
 *
 * @param indexPaths An array of index paths in the view space
 */
- (nullable NSArray<NSIndexPath *> *)convertIndexPathsToCollectionNode:(nullable NSArray<NSIndexPath *> *)indexPaths;

- (void)beginUpdates;

- (void)endUpdatesAnimated:(BOOL)animated completion:(nullable void (^)(BOOL))completion;

@end

NS_ASSUME_NONNULL_END

#endif
