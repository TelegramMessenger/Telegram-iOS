//
//  ASBatchContext.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASBatchContext.h>

#import <AsyncDisplayKit/ASLog.h>
#import <stdatomic.h>

typedef NS_ENUM(NSInteger, ASBatchContextState) {
  ASBatchContextStateFetching,
  ASBatchContextStateCancelled,
  ASBatchContextStateCompleted
};

@implementation ASBatchContext {
  atomic_int _state;
}

- (instancetype)init
{
  if (self = [super init]) {
    _state = ATOMIC_VAR_INIT(ASBatchContextStateCompleted);
  }
  return self;
}

- (BOOL)isFetching
{
  return atomic_load(&_state) == ASBatchContextStateFetching;
}

- (BOOL)batchFetchingWasCancelled
{
  return atomic_load(&_state) == ASBatchContextStateCancelled;
}

- (void)beginBatchFetching
{
  atomic_store(&_state, ASBatchContextStateFetching);
}

- (void)completeBatchFetching:(BOOL)didComplete
{
  if (didComplete) {
    as_log_debug(ASCollectionLog(), "Completed batch fetch with context %@", self);
    atomic_store(&_state, ASBatchContextStateCompleted);
  }
}

- (void)cancelBatchFetching
{
  atomic_store(&_state, ASBatchContextStateCancelled);
}

@end

#endif
