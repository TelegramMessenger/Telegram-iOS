//
//  ASRunLoopQueueTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASTestCase.h"

#import <AsyncDisplayKit/ASRunLoopQueue.h>

#import "ASDisplayNodeTestsHelper.h"

static NSTimeInterval const kRunLoopRunTime = 0.001; // Allow the RunLoop to run for one millisecond each time.

@interface QueueObject : NSObject <ASCATransactionQueueObserving>
@property (nonatomic) BOOL queueObjectProcessed;
@end

@implementation QueueObject
- (void)prepareForCATransactionCommit
{
  self.queueObjectProcessed = YES;
}
@end

@interface ASRunLoopQueueTests : ASTestCase

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

- (void)testASCATransactionQueueDisable
{
  // Disable coalescing.
  ASConfiguration *config = [[ASConfiguration alloc] init];
  config.experimentalFeatures = kNilOptions;
  [ASConfigurationManager test_resetWithConfiguration:config];
  
  ASCATransactionQueue *queue = [[ASCATransactionQueue alloc] init];
  QueueObject *object = [[QueueObject alloc] init];
  XCTAssertFalse(object.queueObjectProcessed);
  [queue enqueue:object];
  XCTAssertTrue(object.queueObjectProcessed);
  XCTAssertTrue([queue isEmpty]);
  XCTAssertFalse(queue.enabled);
}

- (void)testASCATransactionQueueProcess
{
  ASConfiguration *config = [[ASConfiguration alloc] initWithDictionary:nil];
  config.experimentalFeatures = ASExperimentalInterfaceStateCoalescing;
  [ASConfigurationManager test_resetWithConfiguration:config];

  ASCATransactionQueue *queue = [[ASCATransactionQueue alloc] init];
  QueueObject *object = [[QueueObject alloc] init];
  [queue enqueue:object];
  XCTAssertFalse(object.queueObjectProcessed);
  ASCATransactionQueueWait(queue);
  XCTAssertTrue(object.queueObjectProcessed);
  XCTAssertTrue(queue.enabled);
}

@end
