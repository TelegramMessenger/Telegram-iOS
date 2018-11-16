//
//  ASDispatchTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASDispatch.h>

@interface ASDispatchTests : XCTestCase

@end

@implementation ASDispatchTests

- (void)testDispatchApply
{
  dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  NSInteger expectedThreadCount = [NSProcessInfo processInfo].activeProcessorCount * 2;
  NSLock *lock = [NSLock new];
  NSMutableSet *threads = [NSMutableSet set];
  NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
  
  size_t const iterations = 1E5;
  ASDispatchApply(iterations, q, 0, ^(size_t i) {
    [lock lock];
    [threads addObject:[NSThread currentThread]];
    XCTAssertFalse([indices containsIndex:i]);
    [indices addIndex:i];
    [lock unlock];
  });
  XCTAssertLessThanOrEqual(threads.count, expectedThreadCount);
  XCTAssertEqualObjects(indices, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, iterations)]);
}

- (void)testDispatchAsync
{
  dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  NSInteger expectedThreadCount = [NSProcessInfo processInfo].activeProcessorCount * 2;
  NSLock *lock = [NSLock new];
  NSMutableSet *threads = [NSMutableSet set];
  NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
  XCTestExpectation *expectation = [self expectationWithDescription:@"Executed all blocks"];

  size_t const iterations = 1E5;
  ASDispatchAsync(iterations, q, 0, ^(size_t i) {
    [lock lock];
    [threads addObject:[NSThread currentThread]];
    XCTAssertFalse([indices containsIndex:i]);
    [indices addIndex:i];
    if (indices.count == iterations) {
      [expectation fulfill];
    }
    [lock unlock];
  });
  [self waitForExpectationsWithTimeout:10 handler:nil];
  XCTAssertLessThanOrEqual(threads.count, expectedThreadCount);
  XCTAssertEqualObjects(indices, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, iterations)]);
}

@end
