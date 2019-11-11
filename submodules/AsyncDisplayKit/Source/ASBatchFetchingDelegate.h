//
//  ASBatchFetchingDelegate.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

@protocol ASBatchFetchingDelegate <NSObject>

/**
 * @abstract Determine if batch fetching should begin based on the remaining time.
 * If the delegate doesn't have enough information to confidently decide, it can take the given hint.
 *
 * @param remainingTime The amount of time left for user to reach the end of the scroll view's content.
 *
 * @param hint A hint for the delegate to fallback to.
 */
- (BOOL)shouldFetchBatchWithRemainingTime:(NSTimeInterval)remainingTime hint:(BOOL)hint;

@end
