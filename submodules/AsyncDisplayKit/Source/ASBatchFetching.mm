//
//  ASBatchFetching.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASBatchFetching.h>
#import <AsyncDisplayKit/ASBatchContext.h>
#import <AsyncDisplayKit/ASBatchFetchingDelegate.h>

BOOL ASDisplayShouldFetchBatchForScrollView(UIScrollView<ASBatchFetchingScrollView> *scrollView,
                                            ASScrollDirection scrollDirection,
                                            ASScrollDirection scrollableDirections,
                                            CGPoint contentOffset,
                                            CGPoint velocity)
{
  // Don't fetch if the scroll view does not allow
  if (![scrollView canBatchFetch]) {
    return NO;
  }
  
  // Check if we should batch fetch
  ASBatchContext *context = scrollView.batchContext;
  CGRect bounds = scrollView.bounds;
  CGSize contentSize = scrollView.contentSize;
  CGFloat leadingScreens = scrollView.leadingScreensForBatching;
  id<ASBatchFetchingDelegate> delegate = scrollView.batchFetchingDelegate;
  BOOL visible = (scrollView.window != nil);
  return ASDisplayShouldFetchBatchForContext(context, scrollDirection, scrollableDirections, bounds, contentSize, contentOffset, leadingScreens, visible, velocity, delegate);
}

BOOL ASDisplayShouldFetchBatchForContext(ASBatchContext *context,
                                         ASScrollDirection scrollDirection,
                                         ASScrollDirection scrollableDirections,
                                         CGRect bounds,
                                         CGSize contentSize,
                                         CGPoint targetOffset,
                                         CGFloat leadingScreens,
                                         BOOL visible,
                                         CGPoint velocity,
                                         id<ASBatchFetchingDelegate> delegate)
{
  // Do not allow fetching if a batch is already in-flight and hasn't been completed or cancelled
  if ([context isFetching]) {
    return NO;
  }

  // No fetching for null states
  if (leadingScreens <= 0.0 || CGRectIsEmpty(bounds)) {
    return NO;
  }


  CGFloat viewLength, offset, contentLength, velocityLength;
  if (ASScrollDirectionContainsVerticalDirection(scrollableDirections)) {
    viewLength = bounds.size.height;
    offset = targetOffset.y;
    contentLength = contentSize.height;
    velocityLength = velocity.y;
  } else { // horizontal / right
    viewLength = bounds.size.width;
    offset = targetOffset.x;
    contentLength = contentSize.width;
    velocityLength = velocity.x;
  }

  BOOL hasSmallContent = contentLength < viewLength;
  if (hasSmallContent) {
    return YES;
  }

  // If we are not visible, but we do have enough content to fill visible area,
  // don't batch fetch.
  if (visible == NO) {
    return NO;
  }

  // If they are scrolling toward the head of content, don't batch fetch.
  BOOL isScrollingTowardHead = (ASScrollDirectionContainsUp(scrollDirection) || ASScrollDirectionContainsLeft(scrollDirection));
  if (isScrollingTowardHead) {
    return NO;
  }

  CGFloat triggerDistance = viewLength * leadingScreens;
  CGFloat remainingDistance = contentLength - viewLength - offset;
  BOOL result = remainingDistance <= triggerDistance;

  if (delegate != nil && velocityLength > 0.0) {
    // Don't need to get absolute value of remaining time
    // because both remainingDistance and velocityLength are positive when scrolling toward tail
    NSTimeInterval remainingTime = remainingDistance / (velocityLength * 1000);
    result = [delegate shouldFetchBatchWithRemainingTime:remainingTime hint:result];
  }
  
  return result;
}

#endif
