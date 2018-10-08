//
//  ASMainSerialQueue.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASMainSerialQueue.h>

#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

@interface ASMainSerialQueue ()
{
  ASDN::Mutex _serialQueueLock;
  NSMutableArray *_blocks;
}

@end

@implementation ASMainSerialQueue

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _blocks = [[NSMutableArray alloc] init];
  return self;
}

- (NSUInteger)numberOfScheduledBlocks
{
  ASDN::MutexLocker l(_serialQueueLock);
  return _blocks.count;
}

- (void)performBlockOnMainThread:(dispatch_block_t)block
{
  ASDN::MutexLocker l(_serialQueueLock);
  [_blocks addObject:block];
  {
    ASDN::MutexUnlocker u(_serialQueueLock);
    [self runBlocks];
  }
}

- (void)runBlocks
{
  dispatch_block_t mainThread = ^{
    do {
      ASDN::MutexLocker l(_serialQueueLock);
      dispatch_block_t block;
      if (_blocks.count > 0) {
        block = _blocks[0];
        [_blocks removeObjectAtIndex:0];
      } else {
        break;
      }
      {
        ASDN::MutexUnlocker u(_serialQueueLock);
        block();
      }
    } while (true);
  };
  
  ASPerformBlockOnMainThread(mainThread);
}

- (NSString *)description
{
  return [[super description] stringByAppendingFormat:@" Blocks: %@", _blocks];
}

@end
