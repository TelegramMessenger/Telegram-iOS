//
//  ASSectionController.h
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
#import <AsyncDisplayKit/ASBlockTypes.h>
#import <AsyncDisplayKit/ASDimension.h>

NS_ASSUME_NONNULL_BEGIN

@class ASBatchContext;

/**
 * A protocol that your section controllers should conform to,
 * in order to be used with AsyncDisplayKit.
 *
 * @note Your supplementary view source should conform to @c ASSupplementaryNodeSource.
 */
@protocol ASSectionController <NSObject>

/**
 * A method to provide the node block for the item at the given index.
 * The node block you return will be run asynchronously off the main thread,
 * so it's important to retrieve any objects from your section _outside_ the block
 * because by the time the block is run, the array may have changed.
 *
 * @param index The index of the item.
 * @return A block to be run concurrently to build the node for this item.
 * @see collectionNode:nodeBlockForItemAtIndexPath:
 */
- (ASCellNodeBlock)nodeBlockForItemAtIndex:(NSInteger)index;

@optional

/**
 * Asks the section controller whether it should batch fetch because the user is
 * near the end of the current data set.
 *
 * @discussion Use this method to conditionally fetch batches. Example use cases are: limiting the total number of
 * objects that can be fetched or no network connection.
 *
 * If not implemented, the assumed return value is @c YES.
 */
- (BOOL)shouldBatchFetch;

/**
 * Asks the section controller to begin fetching more content (tail loading) because
 * the user is near the end of the current data set.
 *
 * @param context A context object that must be notified when the batch fetch is completed.
 *
 * @discussion You must eventually call -completeBatchFetching: with an argument of YES in order to receive future
 * notifications to do batch fetches. This method is called on a background queue.
 */
- (void)beginBatchFetchWithContext:(ASBatchContext *)context;

/**
 * A method to provide the size range used for measuring the item
 * at the given index.
 *
 * @param index The index of the item.
 * @return A size range used for asynchronously measuring the node at this index.
 * @see collectionNode:constrainedSizeForItemAtIndexPath:
 */
- (ASSizeRange)sizeRangeForItemAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
#endif
