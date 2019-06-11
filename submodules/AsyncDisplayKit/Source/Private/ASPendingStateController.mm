//
//  ASPendingStateController.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASPendingStateController.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASWeakSet.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h> // Required for -applyPendingViewState; consider moving this to +FrameworkPrivate

@interface ASPendingStateController()
{
  AS::Mutex _lock;

  struct ASPendingStateControllerFlags {
    unsigned pendingFlush:1;
  } _flags;
}

@property (nonatomic, readonly) ASWeakSet<ASDisplayNode *> *dirtyNodes;
@end

@implementation ASPendingStateController

#pragma mark Lifecycle & Singleton

- (instancetype)init
{
  self = [super init];
  if (self) {
    _dirtyNodes = [[ASWeakSet alloc] init];
  }
  return self;
}

+ (ASPendingStateController *)sharedInstance
{
  static dispatch_once_t onceToken;
  static ASPendingStateController *controller = nil;
  dispatch_once(&onceToken, ^{
    controller = [[ASPendingStateController alloc] init];
  });
  return controller;
}

#pragma mark External API

- (void)registerNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssert(node.nodeLoaded, @"Expected display node to be loaded before it was registered with ASPendingStateController. Node: %@", node);
  AS::MutexLocker l(_lock);
  [_dirtyNodes addObject:node];

  [self scheduleFlushIfNeeded];
}

- (void)flush
{
  ASDisplayNodeAssertMainThread();
  _lock.lock();
    ASWeakSet *dirtyNodes = _dirtyNodes;
    _dirtyNodes = [[ASWeakSet alloc] init];
    _flags.pendingFlush = NO;
  _lock.unlock();

  for (ASDisplayNode *node in dirtyNodes) {
    [node applyPendingViewState];
  }
}


#pragma mark Private Methods

/**
 This method is assumed to be called with the lock held.
 */
- (void)scheduleFlushIfNeeded
{
  if (_flags.pendingFlush) {
    return;
  }

  _flags.pendingFlush = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self flush];
  });
}

@end

@implementation ASPendingStateController (Testing)

- (BOOL)test_isFlushScheduled
{
  return _flags.pendingFlush;
}

@end
