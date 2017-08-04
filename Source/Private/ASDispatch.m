//
//  ASDispatch.m
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDispatch.h>
#import <stdatomic.h>

/**
 * Like dispatch_apply, but you can set the thread count. 0 means 2*active CPUs.
 *
 * Note: The actual number of threads may be lower than threadCount, if libdispatch
 * decides the system can't handle it. In reality this rarely happens.
 */
void ASDispatchApply(size_t iterationCount, dispatch_queue_t queue, NSUInteger threadCount, NS_NOESCAPE void(^work)(size_t i)) {
  if (threadCount == 0) {
    threadCount = NSProcessInfo.processInfo.activeProcessorCount * 2;
  }
  dispatch_group_t group = dispatch_group_create();
  __block atomic_size_t counter = ATOMIC_VAR_INIT(0);
  for (NSUInteger t = 0; t < threadCount; t++) {
    dispatch_group_async(group, queue, ^{
      size_t i;
      while ((i = atomic_fetch_add(&counter, 1)) < iterationCount) {
        work(i);
      }
    });
  }
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
};

/**
 * Like dispatch_async, but you can set the thread count. 0 means 2*active CPUs.
 *
 * Note: The actual number of threads may be lower than threadCount, if libdispatch
 * decides the system can't handle it. In reality this rarely happens.
 */
void ASDispatchAsync(size_t iterationCount, dispatch_queue_t queue, NSUInteger threadCount, NS_NOESCAPE void(^work)(size_t i)) {
  if (threadCount == 0) {
    threadCount = NSProcessInfo.processInfo.activeProcessorCount * 2;
  }
  __block atomic_size_t counter = ATOMIC_VAR_INIT(0);
  for (NSUInteger t = 0; t < threadCount; t++) {
    dispatch_async(queue, ^{
      size_t i;
      while ((i = atomic_fetch_add(&counter, 1)) < iterationCount) {
        work(i);
      }
    });
  }
};

