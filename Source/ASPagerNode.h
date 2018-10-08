//
//  ASPagerNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionNode.h>

@class ASPagerNode;
@class ASPagerFlowLayout;

NS_ASSUME_NONNULL_BEGIN

#define ASPagerNodeDataSource ASPagerDataSource
@protocol ASPagerDataSource <NSObject>

/**
 * This method replaces -collectionView:numberOfItemsInSection:
 *
 * @param pagerNode The sender.
 * @return The total number of pages that can display in the pagerNode.
 */
- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode;

@optional

/**
 * This method replaces -collectionView:nodeForItemAtIndexPath:
 *
 * @param pagerNode The sender.
 * @param index     The index of the requested node.
 * @return a node for display at this index. This will be called on the main thread and should
 *   not implement reuse (it will be called once per row).  Unlike UICollectionView's version,
 *   this method is not called when the row is about to display.
 */
- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index;

/**
 * This method replaces -collectionView:nodeBlockForItemAtIndexPath:
 * This method takes precedence over pagerNode:nodeAtIndex: if implemented.
 *
 * @param pagerNode The sender.
 * @param index     The index of the requested node.
 * @return a block that creates the node for display at this index.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */
- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index;

@end

@protocol ASPagerDelegate <ASCollectionDelegate>
@end

/**
 * A horizontal, paging collection node.
 */
@interface ASPagerNode : ASCollectionNode

/**
 * Configures a default horizontal, paging flow layout with 0 inter-item spacing.
 */
- (instancetype)init;

/**
 * Initializer with custom-configured flow layout properties.
 *
 * NOTE: The flow layout must have a horizontal scroll direction.
 */
- (instancetype)initWithCollectionViewLayout:(ASPagerFlowLayout *)flowLayout;

/**
 * Data Source is required, and uses a different protocol from ASCollectionNode.
 */
- (void)setDataSource:(nullable id <ASPagerDataSource>)dataSource;
- (nullable id <ASPagerDataSource>)dataSource AS_WARN_UNUSED_RESULT;

/**
 * Delegate is optional.
 * This includes UIScrollViewDelegate as well as most methods from UICollectionViewDelegate, like willDisplay...
 */
- (void)setDelegate:(nullable id <ASPagerDelegate>)delegate;
- (nullable id <ASPagerDelegate>)delegate AS_WARN_UNUSED_RESULT;

/**
 * The underlying ASCollectionView object.
 */
@property (readonly) ASCollectionView *view;

/**
 * Returns the current page index. Main thread only.
 */
@property (nonatomic, readonly) NSInteger currentPageIndex;

/**
 * Scroll the contents of the receiver to ensure that the page is visible
 */
- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated;

/**
 * Returns the node for the passed page index
 */
- (ASCellNode *)nodeForPageAtIndex:(NSInteger)index AS_WARN_UNUSED_RESULT;

/**
 * Returns the index of the page for the cell passed or NSNotFound
 */
- (NSInteger)indexOfPageWithNode:(ASCellNode *)node;

/**
 * Tells the pager node to allow its view controller to automatically adjust its content insets.
 *
 * @see UIViewController.automaticallyAdjustsScrollViewInsets
 *
 * @discussion ASPagerNode should usually not have its content insets automatically adjusted
 * because it scrolls horizontally, and flow layout will log errors because the pages
 * do not fit between the top & bottom insets of the collection view.
 *
 * The default value is NO, which means that ASPagerNode expects that its view controller will
 * have automaticallyAdjustsScrollViewInsets=NO.
 *
 * If this property is NO, but your view controller has automaticallyAdjustsScrollViewInsets=YES,
 * the pager node will set the property on the view controller to NO and log a warning message. In the future,
 * the pager node will just log the warning, and you'll need to configure your view controller on your own.
 */
@property (nonatomic) BOOL allowsAutomaticInsetsAdjustment;

@end

NS_ASSUME_NONNULL_END

#endif
