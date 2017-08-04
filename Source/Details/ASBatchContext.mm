//
//  ASBatchContext.mm
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
#import <AsyncDisplayKit/ASThread.h>

typedef NS_ENUM(NSInteger, ASBatchContextState) {
  ASBatchContextStateFetching,
  ASBatchContextStateCancelled,
  ASBatchContextStateCompleted
};

@interface ASBatchContext ()
{
  ASBatchContextState _state;
  ASDN::RecursiveMutex __instanceLock__;
}
@end

@implementation ASBatchContext

- (instancetype)init
{
  if (self = [super init]) {
    _state = ASBatchContextStateCompleted;
  }
  return self;
}

- (BOOL)isFetching
{
  ASDN::MutexLocker l(__instanceLock__);
  return _state == ASBatchContextStateFetching;
}

- (BOOL)batchFetchingWasCancelled
{
  ASDN::MutexLocker l(__instanceLock__);
  return _state == ASBatchContextStateCancelled;
}

- (void)beginBatchFetching
{
  ASDN::MutexLocker l(__instanceLock__);
  _state = ASBatchContextStateFetching;
}

- (void)completeBatchFetching:(BOOL)didComplete
{
  if (didComplete) {
    as_log_debug(ASCollectionLog(), "Completed batch fetch with context %@", self);
    ASDN::MutexLocker l(__instanceLock__);
    _state = ASBatchContextStateCompleted;
  }
}

- (void)cancelBatchFetching
{
  ASDN::MutexLocker l(__instanceLock__);
  _state = ASBatchContextStateCancelled;
}

@end

#endif
