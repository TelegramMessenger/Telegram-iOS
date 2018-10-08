//
//  ASDataController.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#pragma once

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBlockTypes.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASEventLog.h>
#ifdef __cplusplus
#import <vector>
#endif

NS_ASSUME_NONNULL_BEGIN

#if ASEVENTLOG_ENABLE
#define ASDataControllerLogEvent(dataController, ...) [dataController.eventLog logEventWithBacktrace:(AS_SAVE_EVENT_BACKTRACES ? [NSThread callStackSymbols] : nil) format:__VA_ARGS__]
#else
#define ASDataControllerLogEvent(dataController, ...)
#endif

@class ASCellNode;
@class ASCollectionElement;
@class ASCollectionLayoutContext;
@class ASCollectionLayoutState;
@class ASDataController;
@class ASElementMap;
@class ASLayout;
@class _ASHierarchyChangeSet;
@protocol ASRangeManagingNode;
@protocol ASTraitEnvironment;
@protocol ASSectionContext;

typedef NSUInteger ASDataControllerAnimationOptions;

AS_EXTERN NSString * const ASDataControllerRowNodeKind;
AS_EXTERN NSString * const ASCollectionInvalidUpdateException;

/**
 Data source for data controller
 It will be invoked in the same thread as the api call of ASDataController.
 */

@protocol ASDataControllerSource <NSObject>

/**
 Fetch the ASCellNode block for specific index path. This block should return the ASCellNode for the specified index path.
 */
- (ASCellNodeBlock)dataController:(ASDataController *)dataController nodeBlockAtIndexPath:(NSIndexPath *)indexPath;

/**
 Fetch the number of rows in specific section.
 */
- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section;

/**
 Fetch the number of sections.
 */
- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController;

/**
 Returns if the collection element size matches a given size.
 @precondition The element is present in the data controller's visible map.
 */
- (BOOL)dataController:(ASDataController *)dataController presentedSizeForElement:(ASCollectionElement *)element matchesSize:(CGSize)size;

- (nullable id)dataController:(ASDataController *)dataController nodeModelForItemAtIndexPath:(NSIndexPath *)indexPath;

@optional

/**
 The constrained size range for layout. Called only if collection layout delegate is not provided.
 */
- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

- (NSArray<NSString *> *)dataController:(ASDataController *)dataController supplementaryNodeKindsInSections:(NSIndexSet *)sections;

- (NSUInteger)dataController:(ASDataController *)dataController supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section;

- (ASCellNodeBlock)dataController:(ASDataController *)dataController supplementaryNodeBlockOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath shouldAsyncLayout:(BOOL *)shouldAsyncLayout;

/**
 The constrained size range for layout. Called only if no data controller layout delegate is provided.
 */
- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (nullable id<ASSectionContext>)dataController:(ASDataController *)dataController contextForSection:(NSInteger)section;

@end

/**
 Delegate for notify the data updating of data controller.
 These methods will be invoked from main thread right now, but it may be moved to background thread in the future.
 */
@protocol ASDataControllerDelegate <NSObject>

/**
 * Called for change set updates.
 *
 * @param changeSet The change set that includes all updates
 *
 * @param updates The block that performs relevant data updates.
 *
 * @discussion The updates block must always be executed or the data controller will get into a bad state.
 * It should be called at the time the backing view is ready to process the updates,
 * i.e inside the updates block of `-[UICollectionView performBatchUpdates:completion:] or after calling `-[UITableView beginUpdates]`.
 */
- (void)dataController:(ASDataController *)dataController updateWithChangeSet:(_ASHierarchyChangeSet *)changeSet updates:(dispatch_block_t)updates;

@end

@protocol ASDataControllerLayoutDelegate <NSObject>

/**
 * @abstract Returns a layout context needed for a coming layout pass with the given elements.
 * The context should contain the elements and any additional information needed.
 *
 * @discussion This method will be called on main thread.
 */
- (ASCollectionLayoutContext *)layoutContextWithElements:(ASElementMap *)elements;

/**
 * @abstract Prepares and returns a new layout for given context.
 *
 * @param context A context that was previously returned by `-layoutContextWithElements:`.
 *
 * @return The new layout calculated for the given context.
 *
 * @discussion This method is called ahead of time, i.e before the underlying collection/table view is aware of the provided elements.
 * As a result, clients must solely rely on the given context and should not reach out to other objects for information not available in the context.
 *
 * This method will be called on background theads. It must be thread-safe and should not change any internal state of the conforming object.
 * It must block the calling thread but can dispatch to other theads to reduce total blocking time.
 */
+ (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context;

@end

/**
 * Controller to layout data in background, and managed data updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the data
 * will be updated asynchronously. The dataSource must be updated to reflect the changes before these methods has been called.
 * For each data updating, the corresponding methods in delegate will be called.
 */
@interface ASDataController : NSObject

- (instancetype)initWithDataSource:(id<ASDataControllerSource>)dataSource node:(nullable id<ASRangeManagingNode>)node eventLog:(nullable ASEventLog *)eventLog NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/**
 * The node that owns this data controller, if any.
 *
 * NOTE: Soon we will drop support for using ASTableView/ASCollectionView without the node, so this will be non-null.
 */
@property (nullable, nonatomic, weak, readonly) id<ASRangeManagingNode> node;

/**
 * The map that is currently displayed. The "UIKit index space."
 *
 * This property will only be changed on the main thread.
 */
@property (copy, readonly) ASElementMap *visibleMap;

/**
 * The latest map fetched from the data source. May be more recent than @c visibleMap.
 *
 * This property will only be changed on the main thread.
 */
@property (copy, readonly) ASElementMap *pendingMap;

/**
 Data source for fetching data info.
 */
@property (nonatomic, weak, readonly) id<ASDataControllerSource> dataSource;

/**
 An object that will be included in the backtrace of any update validation exceptions that occur.
 */
@property (nonatomic, weak) id validationErrorSource;

/**
 Delegate to notify when data is updated.
 */
@property (nonatomic, weak) id<ASDataControllerDelegate> delegate;

/**
 * Delegate for preparing layouts. Main thead only.
 */
@property (nonatomic, weak) id<ASDataControllerLayoutDelegate> layoutDelegate;

#ifdef __cplusplus
/**
 * Returns the most recently gathered item counts from the data source. If the counts
 * have been invalidated, this synchronously queries the data source and saves the result.
 *
 * This must be called on the main thread.
 */
- (std::vector<NSInteger>)itemCountsFromDataSource;
#endif

/**
 * Returns YES if reloadData has been called at least once. Before this point it is
 * important to ignore/suppress some operations. For example, inserting a section
 * before the initial data load should have no effect.
 *
 * This must be called on the main thread.
 */
@property (nonatomic, readonly) BOOL initialReloadDataHasBeenCalled;

#if ASEVENTLOG_ENABLE
/*
 * @abstract The primitive event tracing object. You shouldn't directly use it to log event. Use the ASDataControllerLogEvent macro instead.
 */
@property (nonatomic, readonly) ASEventLog *eventLog;
#endif

/**
 * @see ASCollectionNode+Beta.h for full documentation.
 */
@property (nonatomic) BOOL usesSynchronousDataLoading;

/** @name Data Updating */

- (void)updateWithChangeSet:(_ASHierarchyChangeSet *)changeSet;

/**
 * Re-measures all loaded nodes in the backing store.
 * 
 * @discussion Used to respond to a change in size of the containing view
 * (e.g. ASTableView or ASCollectionView after an orientation change).
 *
 * The invalidationBlock is called after flushing the ASMainSerialQueue, which ensures that any in-progress
 * layout calculations have been applied. The block will not be called if data hasn't been loaded.
 */
- (void)relayoutAllNodesWithInvalidationBlock:(nullable void (^)(void))invalidationBlock;

/**
 * Re-measures given nodes in the backing store.
 *
 * @discussion Used to respond to setNeedsLayout calls in ASCellNode
 */
- (void)relayoutNodes:(id<NSFastEnumeration>)nodes nodesSizeChanged:(NSMutableArray<ASCellNode *> *)nodesSizesChanged;

/**
 * See ASCollectionNode.h for full documentation of these methods.
 */
@property (nonatomic, readonly) BOOL isProcessingUpdates;
- (void)onDidFinishProcessingUpdates:(void (^)(void))completion;
- (void)waitUntilAllUpdatesAreProcessed;

/**
 * See ASCollectionNode.h for full documentation of these methods.
 */
@property (nonatomic, readonly, getter=isSynchronized) BOOL synchronized;
- (void)onDidFinishSynchronizing:(void (^)(void))completion;

/**
 * Notifies the data controller object that its environment has changed. The object will request its environment delegate for new information
 * and propagate the information to all visible elements, including ones that are being prepared in background.
 *
 * @discussion If called before the initial @c reloadData, this method will do nothing and the trait collection of the initial load will be requested from the environment delegate.
 *
 * @discussion This method can be called on any threads.
 */
- (void)environmentDidChange;

/**
 * Reset visibleMap and pendingMap when asyncDataSource and asyncDelegate of collection view become nil.
 */
- (void)clearData;

@end

NS_ASSUME_NONNULL_END
#endif
