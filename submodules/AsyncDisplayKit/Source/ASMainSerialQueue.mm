//
//  ASMainSerialQueue.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASMainSerialQueue.h"

#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

@interface ASMainSerialQueue ()
{
  AS::Mutex _serialQueueLock;
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
  AS::MutexLocker l(_serialQueueLock);
  return _blocks.count;
}

- (void)performBlockOnMainThread:(dispatch_block_t)block
{

  AS::UniqueLock l(_serialQueueLock);
  [_blocks addObject:block];
  {
    l.unlock();
    [self runBlocks];
    l.lock();
  }
}

- (void)runBlocks
{
  dispatch_block_t mainThread = ^{
    AS::UniqueLock l(self->_serialQueueLock);
    do {
      dispatch_block_t block;
      if (self->_blocks.count > 0) {
        block = _blocks[0];
        [self->_blocks removeObjectAtIndex:0];
      } else {
        break;
      }
      {
        l.unlock();
        block();
        l.lock();
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
