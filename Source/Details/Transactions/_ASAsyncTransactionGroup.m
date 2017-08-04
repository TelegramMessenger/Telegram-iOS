//
//  _ASAsyncTransactionGroup.m
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

#import <AsyncDisplayKit/ASAssert.h>

#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import <AsyncDisplayKit/_ASAsyncTransactionGroup.h>
#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import <AsyncDisplayKit/_ASAsyncTransactionContainer+Private.h>

@interface _ASAsyncTransactionGroup ()
+ (void)registerTransactionGroupAsMainRunloopObserver:(_ASAsyncTransactionGroup *)transactionGroup;
- (void)commit;
@end

@implementation _ASAsyncTransactionGroup {
  NSHashTable<id<ASAsyncTransactionContainer>> *_containers;
}

+ (_ASAsyncTransactionGroup *)mainTransactionGroup
{
  ASDisplayNodeAssertMainThread();
  static _ASAsyncTransactionGroup *mainTransactionGroup;

  if (mainTransactionGroup == nil) {
    mainTransactionGroup = [[_ASAsyncTransactionGroup alloc] init];
    [self registerTransactionGroupAsMainRunloopObserver:mainTransactionGroup];
  }
  return mainTransactionGroup;
}

+ (void)registerTransactionGroupAsMainRunloopObserver:(_ASAsyncTransactionGroup *)transactionGroup
{
  ASDisplayNodeAssertMainThread();
  static CFRunLoopObserverRef observer;
  ASDisplayNodeAssert(observer == NULL, @"A _ASAsyncTransactionGroup should not be registered on the main runloop twice");
  // defer the commit of the transaction so we can add more during the current runloop iteration
  CFRunLoopRef runLoop = CFRunLoopGetCurrent();
  CFOptionFlags activities = (kCFRunLoopBeforeWaiting | // before the run loop starts sleeping
                              kCFRunLoopExit);          // before exiting a runloop run

  observer = CFRunLoopObserverCreateWithHandler(NULL,        // allocator
                                                activities,  // activities
                                                YES,         // repeats
                                                INT_MAX,     // order after CA transaction commits
                                                ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
                                                  ASDisplayNodeCAssertMainThread();
                                                  [transactionGroup commit];
                                                });
  CFRunLoopAddObserver(runLoop, observer, kCFRunLoopCommonModes);
  CFRelease(observer);
}

- (instancetype)init
{
  if ((self = [super init])) {
    _containers = [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
  }
  return self;
}

- (void)addTransactionContainer:(id<ASAsyncTransactionContainer>)container
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(container != nil, @"No container");
  [_containers addObject:container];
}

- (void)commit
{
  ASDisplayNodeAssertMainThread();

  if ([_containers count]) {
    NSHashTable *containersToCommit = _containers;
    _containers = [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];

    for (id<ASAsyncTransactionContainer> container in containersToCommit) {
      // Note that the act of committing a transaction may open a new transaction,
      // so we must nil out the transaction we're committing first.
      _ASAsyncTransaction *transaction = container.asyncdisplaykit_currentAsyncTransaction;
      container.asyncdisplaykit_currentAsyncTransaction = nil;
      [transaction commit];
    }
  }
}

+ (void)commit
{
  [[_ASAsyncTransactionGroup mainTransactionGroup] commit];
}

@end
