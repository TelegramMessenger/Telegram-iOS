//
//  ASBatchContext.m
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
