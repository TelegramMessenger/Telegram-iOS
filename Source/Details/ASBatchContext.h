//
//  ASBatchContext.h
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

NS_ASSUME_NONNULL_BEGIN

/**
 * @abstract A context object to notify when batch fetches are finished or cancelled.
 */
@interface ASBatchContext : NSObject

/**
 * Retrieve the state of the current batch process.
 *
 * @return A boolean reflecting if the owner of the context object is fetching another batch.
 */
- (BOOL)isFetching;

/**
 * Let the context object know that a batch fetch was completed.
 *
 * @param didComplete A boolean that states whether or not the batch fetch completed.
 *
 * @discussion Only by passing YES will the owner of the context know to attempt another batch update when necessary.
 * For instance, when a table has reached the end of its data, a batch fetch will be attempted unless the context
 * object thinks that it is still fetching.
 */
- (void)completeBatchFetching:(BOOL)didComplete;

/**
 * Ask the context object if the batch fetching process was cancelled by the context owner.
 *
 * @discussion If an error occurs in the context owner, the batch fetching may become out of sync and need to be
 * cancelled. For best practices, pass the return value of -batchWasCancelled to -completeBatchFetch:.
 *
 * @return A boolean reflecting if the context object owner had to cancel the batch process.
 */
- (BOOL)batchFetchingWasCancelled;

/**
 * Notify the context object that something has interrupted the batch fetching process.
 *
 * @discussion Call this method only when something has corrupted the batch fetching process. Calling this method should
 * be left to the owner of the batch process unless there is a specific purpose.
 */
- (void)cancelBatchFetching;

/**
 * Notify the context object that fetching has started.
 *
 * @discussion Call this method only when you are beginning a fetch process. This should really only be called by the 
 * context object's owner. Calling this method should be paired with -completeBatchFetching:.
 */
- (void)beginBatchFetching;

@end

NS_ASSUME_NONNULL_END

#endif
