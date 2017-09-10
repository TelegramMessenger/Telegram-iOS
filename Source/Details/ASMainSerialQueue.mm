//
//  ASMainSerialQueue.mm
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
