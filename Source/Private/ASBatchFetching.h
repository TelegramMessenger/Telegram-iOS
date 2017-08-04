//
//  ASBatchFetching.h
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

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASScrollDirection.h>

ASDISPLAYNODE_EXTERN_C_BEGIN

NS_ASSUME_NONNULL_BEGIN

@class ASBatchContext;
@protocol ASBatchFetchingDelegate;

@protocol ASBatchFetchingScrollView <NSObject>

- (BOOL)canBatchFetch;
- (ASBatchContext *)batchContext;
- (CGFloat)leadingScreensForBatching;
- (nullable id<ASBatchFetchingDelegate>)batchFetchingDelegate;

@end

/**
 @abstract Determine if batch fetching should begin based on the state of the parameters.
 @discussion This method is broken into a category for unit testing purposes and should be used with the ASTableView and
 * ASCollectionView batch fetching API.
 @param scrollView The scroll view that in-flight fetches are happening.
 @param scrollDirection The current scrolling direction of the scroll view.
 @param scrollableDirections The possible scrolling directions of the scroll view.
 @param contentOffset The offset that the scrollview will scroll to.
 @param velocity The velocity of the scroll view (in points) at the moment the touch was released.
 @return Whether or not the current state should proceed with batch fetching.
 */
BOOL ASDisplayShouldFetchBatchForScrollView(UIScrollView<ASBatchFetchingScrollView> *scrollView,
                                            ASScrollDirection scrollDirection,
                                            ASScrollDirection scrollableDirections,
                                            CGPoint contentOffset,
                                            CGPoint velocity);


/**
 @abstract Determine if batch fetching should begin based on the state of the parameters.
 @param context The batch fetching context that contains knowledge about in-flight fetches.
 @param scrollDirection The current scrolling direction of the scroll view.
 @param scrollableDirections The possible scrolling directions of the scroll view.
 @param bounds The bounds of the scrollview.
 @param contentSize The content size of the scrollview.
 @param targetOffset The offset that the scrollview will scroll to.
 @param leadingScreens How many screens in the remaining distance will trigger batch fetching.
 @param visible Whether the view is visible or not.
 @param velocity The velocity of the scroll view (in points) at the moment the touch was released.
 @param delegate The delegate to be consulted if needed.
 @return Whether or not the current state should proceed with batch fetching.
 @discussion This method is broken into a category for unit testing purposes and should be used with the ASTableView and
 * ASCollectionView batch fetching API.
 */
extern BOOL ASDisplayShouldFetchBatchForContext(ASBatchContext *context,
                                                ASScrollDirection scrollDirection,
                                                ASScrollDirection scrollableDirections,
                                                CGRect bounds,
                                                CGSize contentSize,
                                                CGPoint targetOffset,
                                                CGFloat leadingScreens,
                                                BOOL visible,
                                                CGPoint velocity,
                                                _Nullable id<ASBatchFetchingDelegate> delegate);

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

#endif
