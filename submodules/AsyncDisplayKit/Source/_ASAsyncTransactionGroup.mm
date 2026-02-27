//
//  _ASAsyncTransactionGroup.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAssert.h>

#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import <AsyncDisplayKit/_ASAsyncTransactionGroup.h>
#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import "_ASAsyncTransactionContainer+Private.h"

@implementation _ASAsyncTransactionGroup {
  NSHashTable<id<ASAsyncTransactionContainer>> *_containers;
}

+ (_ASAsyncTransactionGroup *)mainTransactionGroup
{
  ASDisplayNodeAssertMainThread();
  static _ASAsyncTransactionGroup *mainTransactionGroup;

  if (mainTransactionGroup == nil) {
    mainTransactionGroup = [[_ASAsyncTransactionGroup alloc] _init];
    [mainTransactionGroup registerAsMainRunloopObserver];
  }
  return mainTransactionGroup;
}

- (void)registerAsMainRunloopObserver
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
                                                  [self commit];
                                                });
  CFRunLoopAddObserver(runLoop, observer, kCFRunLoopCommonModes);
  CFRelease(observer);
}

- (instancetype)_init
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

@end
