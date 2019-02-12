//
//  ASCollectionViewProtocols.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

typedef NS_OPTIONS(NSUInteger, ASCellLayoutMode) {
  /**
   * No options set. If cell layout mode is set to ASCellLayoutModeNone, the default values for
   * each flag listed below is used.
   */
  ASCellLayoutModeNone = 0,
  /**
   * If ASCellLayoutModeSyncForSmallContent is enabled it will cause ASDataController to wait on the
   * background queue if the amount of new content is small.
   */
  ASCellLayoutModeSyncForSmallContent = 1 << 1,
  /**
   * If ASCellLayoutModeAlwaysSync is enabled it will cause the ASDataController to wait on the
   * background queue, and this ensures that any new / changed cells are in the hierarchy by the
   * very next CATransaction / frame draw.
   *
   * Note: Sync & Async flags force the behavior to be always one or the other, regardless of the
   * items. Default: If neither ASCellLayoutModeAlwaysSync or ASCellLayoutModeAlwaysAsync is set,
   * default behavior is synchronous when there are 0 or 1 ASCellNodes in the data source, and
   * asynchronous when there are 2 or more.
  */
  ASCellLayoutModeAlwaysSync = 1 << 2,                // Default OFF
  ASCellLayoutModeAlwaysAsync = 1 << 3,               // Default OFF
  ASCellLayoutModeForceIfNeeded = 1 << 4,             // Deprecated, default OFF.
  ASCellLayoutModeAlwaysPassthroughDelegate = 1 << 5, // Deprecated, default ON.
  /** Instead of using performBatchUpdates: prefer using reloadData for changes for collection view */
  ASCellLayoutModeAlwaysReloadData = 1 << 6,          // Default OFF
  /** If flag is enabled nodes are *not* gonna be range managed. */
  ASCellLayoutModeDisableRangeController = 1 << 7,    // Default OFF
  ASCellLayoutModeAlwaysLazy = 1 << 8,                // Deprecated, default OFF.
  /**
   * Defines if the node creation should happen serialized and not in parallel within the
   * data controller
   */
  ASCellLayoutModeSerializeNodeCreation = 1 << 9,     // Default OFF
  /**
   * When set, the performBatchUpdates: API (including animation) is used when handling Section
   * Reload operations. This is useful only when ASCellLayoutModeAlwaysReloadData is enabled and
   * cell height animations are desired.
   */
  ASCellLayoutModeAlwaysBatchUpdateSectionReload = 1 << 10 // Default OFF
};

NS_ASSUME_NONNULL_BEGIN

/**
 * This is a subset of UICollectionViewDataSource.
 *
 * @see ASCollectionDataSource
 */
@protocol ASCommonCollectionDataSource <NSObject>

@optional

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section ASDISPLAYNODE_DEPRECATED_MSG("Implement -collectionNode:numberOfItemsInSection: instead.");

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView ASDISPLAYNODE_DEPRECATED_MSG("Implement -numberOfSectionsInCollectionNode: instead.");

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement - collectionNode:nodeForSupplementaryElementOfKind:atIndexPath: instead.");

@end


/**
 * This is a subset of UICollectionViewDelegate.
 *
 * @see ASCollectionDelegate
 */
@protocol ASCommonCollectionDelegate <NSObject, UIScrollViewDelegate>

@optional

- (UICollectionViewTransitionLayout *)collectionView:(UICollectionView *)collectionView transitionLayoutForOldLayout:(UICollectionViewLayout *)fromLayout newLayout:(UICollectionViewLayout *)toLayout;

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement -collectionNode:willDisplaySupplementaryView:forElementKind:atIndexPath: instead.");
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingSupplementaryView:(UICollectionReusableView *)view forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement -collectionNode:didEndDisplayingSupplementaryView:forElementKind:atIndexPath: instead.");

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:shouldHighlightItemAtIndexPath: instead.");
- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:didHighlightItemAtIndexPath: instead.");
- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:didUnhighlightItemAtIndexPath: instead.");

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:shouldSelectItemAtIndexPath: instead.");
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:didSelectItemAtIndexPath: instead.");
- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:shouldDeselectItemAtIndexPath: instead.");
- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:didDeselectItemAtIndexPath: instead.");

- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:shouldShowMenuForItemAtIndexPath: instead.");
- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:canPerformAction:forItemAtIndexPath:withSender: instead.");
- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:performAction:forItemAtIndexPath:withSender: instead.");

@end

NS_ASSUME_NONNULL_END

#endif
