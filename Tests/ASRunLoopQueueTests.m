//
//  ASRunLoopQueueTests.m
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASRunLoopQueue.h>

static NSTimeInterval const kRunLoopRunTime = 0.001; // Allow the RunLoop to run for one millisecond each time.

@interface ASRunLoopQueueTests : XCTestCase

@end

@implementation ASRunLoopQueueTests

#pragma mark enqueue tests

- (void)testEnqueueNilObjectsToQueue
{
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:nil];
  id object = nil;
  [queue enqueue:object];
  XCTAssertTrue(queue.isEmpty);
}

- (void)testEnqueueSameObjectTwiceToDefaultQueue
{
  id object = [[NSObject alloc] init];
  __unsafe_unretained id weakObject = object;
  __block NSUInteger dequeuedCount = 0;
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:^(id  _Nonnull dequeuedItem, BOOL isQueueDrained) {
    if (dequeuedItem == weakObject) {
      dequeuedCount++;
    }
  }];
  [queue enqueue:object];
  [queue enqueue:object];
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssert(dequeuedCount == 1);
}

- (void)testEnqueueSameObjectTwiceToNonExclusiveMembershipQueue
{
  id object = [[NSObject alloc] init];
  __unsafe_unretained id weakObject = object;
  __block NSUInteger dequeuedCount = 0;
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:^(id  _Nonnull dequeuedItem, BOOL isQueueDrained) {
    if (dequeuedItem == weakObject) {
      dequeuedCount++;
    }
  }];
  queue.ensureExclusiveMembership = NO;
  [queue enqueue:object];
  [queue enqueue:object];
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssert(dequeuedCount == 2);
}

#pragma mark processQueue tests

- (void)testDefaultQueueProcessObjectsOneAtATime
{
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:^(id  _Nonnull dequeuedItem, BOOL isQueueDrained) {
    [NSThread sleepForTimeInterval:kRunLoopRunTime * 2]; // So each element takes more time than the available
  }];
  [queue enqueue:[[NSObject alloc] init]];
  [queue enqueue:[[NSObject alloc] init]];
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssertFalse(queue.isEmpty);
}

- (void)testQueueProcessObjectsInBatchesOfSpecifiedSize
{
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:^(id  _Nonnull dequeuedItem, BOOL isQueueDrained) {
    [NSThread sleepForTimeInterval:kRunLoopRunTime * 2]; // So each element takes more time than the available
  }];
  queue.batchSize = 2;
  [queue enqueue:[[NSObject alloc] init]];
  [queue enqueue:[[NSObject alloc] init]];
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssertTrue(queue.isEmpty);
}

- (void)testQueueOnlySendsIsDrainedForLastObjectInBatch
{
  id objectA = [[NSObject alloc] init];
  id objectB = [[NSObject alloc] init];
  __unsafe_unretained id weakObjectA = objectA;
  __unsafe_unretained id weakObjectB = objectB;
  __block BOOL isQueueDrainedWhenProcessingA = NO;
  __block BOOL isQueueDrainedWhenProcessingB = NO;
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:^(id  _Nonnull dequeuedItem, BOOL isQueueDrained) {
    if (dequeuedItem == weakObjectA) {
      isQueueDrainedWhenProcessingA = isQueueDrained;
    } else if (dequeuedItem == weakObjectB) {
      isQueueDrainedWhenProcessingB = isQueueDrained;
    }
  }];
  queue.batchSize = 2;
  [queue enqueue:objectA];
  [queue enqueue:objectB];
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssertFalse(isQueueDrainedWhenProcessingA);
  XCTAssertTrue(isQueueDrainedWhenProcessingB);
}

#pragma mark strong/weak tests

- (void)testStrongQueueRetainsObjects
{
  id object = [[NSObject alloc] init];
  __unsafe_unretained id weakObject = object;
  __block BOOL didProcessObject = NO;
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:^(id  _Nonnull dequeuedItem, BOOL isQueueDrained) {
    if (dequeuedItem == weakObject) {
      didProcessObject = YES;
    }
  }];
  [queue enqueue:object];
  object = nil;
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssertTrue(didProcessObject);
}

- (void)testWeakQueueDoesNotRetainsObjects
{
  id object = [[NSObject alloc] init];
  __unsafe_unretained id weakObject = object;
  __block BOOL didProcessObject = NO;
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:NO handler:^(id  _Nonnull dequeuedItem, BOOL isQueueDrained) {
    if (dequeuedItem == weakObject) {
      didProcessObject = YES;
    }
  }];
  [queue enqueue:object];
  object = nil;
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssertFalse(didProcessObject);
}

- (void)testWeakQueueWithAllDeallocatedObjectsIsDrained
{
  ASRunLoopQueue *queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:NO handler:nil];
  id object = [[NSObject alloc] init];
  [queue enqueue:object];
  object = nil;
  XCTAssertFalse(queue.isEmpty);
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunLoopRunTime]];
  XCTAssertTrue(queue.isEmpty);
}

@end
