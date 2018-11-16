//
//  ASDisplayNodeTestsHelper.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASDisplayNodeTestsHelper.h"
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASRunLoopQueue.h>

#import <QuartzCore/QuartzCore.h>

#import <libkern/OSAtomic.h>

// Poll the condition 1000 times a second.
static CFTimeInterval kSingleRunLoopTimeout = 0.001;

// Time out after 30 seconds.
static CFTimeInterval kTimeoutInterval = 30.0f;

BOOL ASDisplayNodeRunRunLoopUntilBlockIsTrue(as_condition_block_t block)
{
  CFTimeInterval timeoutDate = CACurrentMediaTime() + kTimeoutInterval;
  BOOL passed = NO;
  while (true) {
    OSMemoryBarrier();
    passed = block();
    OSMemoryBarrier();
    if (passed) {
      break;
    }
    CFTimeInterval now = CACurrentMediaTime();
    if (now > timeoutDate) {
      break;
    }
    // Run until the poll timeout or until timeoutDate, whichever is first.
    CFTimeInterval runLoopTimeout = MIN(kSingleRunLoopTimeout, timeoutDate - now);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, runLoopTimeout, true);
  }
  return passed;
}

void ASDisplayNodeSizeToFitSize(ASDisplayNode *node, CGSize size)
{
  CGSize sizeThatFits = [node layoutThatFits:ASSizeRangeMake(size)].size;
  node.bounds = (CGRect){.origin = CGPointZero, .size = sizeThatFits};
}

void ASDisplayNodeSizeToFitSizeRange(ASDisplayNode *node, ASSizeRange sizeRange)
{
  CGSize sizeThatFits = [node layoutThatFits:sizeRange].size;
  node.bounds = (CGRect){.origin = CGPointZero, .size = sizeThatFits};
}

void ASCATransactionQueueWait(ASCATransactionQueue *q)
{
  if (!q) { q = ASCATransactionQueue.sharedQueue; }
  NSDate *date = [NSDate dateWithTimeIntervalSinceNow:1];
  BOOL whileResult = YES;
  while ([date timeIntervalSinceNow] > 0 &&
         (whileResult = ![q isEmpty])) {
    [[NSRunLoop currentRunLoop] runUntilDate:
     [NSDate dateWithTimeIntervalSinceNow:0.01]];
  }
}
