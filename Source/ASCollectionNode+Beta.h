//
//  ASCollectionNode+Beta.h
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
#import <AsyncDisplayKit/ASCollectionNode.h>

@protocol ASCollectionViewLayoutFacilitatorProtocol, ASCollectionLayoutDelegate, ASBatchFetchingDelegate;
@class ASElementMap;

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionNode (Beta)

/**
 * Allows providing a custom subclass of ASCollectionView to be managed by ASCollectionNode.
 *
 * @default [ASCollectionView class] is used whenever this property is unset or nil.
 */
@property (strong, nonatomic, nullable) Class collectionViewClass;

/**
 * The elements that are currently displayed. The "UIKit index space". Must be accessed on main thread.
 */
@property (strong, nonatomic, readonly) ASElementMap *visibleElements;

@property (strong, readonly, nullable) id<ASCollectionLayoutDelegate> layoutDelegate;

@property (nonatomic, weak) id<ASBatchFetchingDelegate> batchFetchingDelegate;

/**
 * When this mode is enabled, ASCollectionView matches the timing of UICollectionView as closely as possible, 
 * ensuring that all reload and edit operations are performed on the main thread as blocking calls. 
 *
 * This mode is useful for applications that are debugging issues with their collection view implementation. 
 * In particular, some applications do not properly conform to the API requirement of UICollectionView, and these 
 * applications may experience difficulties with ASCollectionView. Providing this mode allows for developers to 
 * work towards resolving technical debt in their collection view data source, while ramping up asynchronous 
 * collection layout.
 *
 * NOTE: Because this mode results in expensive operations like cell layout being performed on the main thread, 
 * it should be used as a tool to resolve data source conformance issues with Apple collection view API.
 *
 * @default defaults to NO.
 */
@property (nonatomic, assign) BOOL usesSynchronousDataLoading;

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(nullable id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator;

- (instancetype)initWithLayoutDelegate:(id<ASCollectionLayoutDelegate>)layoutDelegate layoutFacilitator:(nullable id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator;

- (void)beginUpdates ASDISPLAYNODE_DEPRECATED_MSG("Use -performBatchUpdates:completion: instead.");

- (void)endUpdatesAnimated:(BOOL)animated ASDISPLAYNODE_DEPRECATED_MSG("Use -performBatchUpdates:completion: instead.");

- (void)endUpdatesAnimated:(BOOL)animated completion:(nullable void (^)(BOOL))completion ASDISPLAYNODE_DEPRECATED_MSG("Use -performBatchUpdates:completion: instead.");

- (void)invalidateFlowLayoutDelegateMetrics;

@end

NS_ASSUME_NONNULL_END

#endif
