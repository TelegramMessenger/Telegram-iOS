//
//  ASRecursiveUnfairLockTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASTestCase.h"
#import <AsyncDisplayKit/ASRecursiveUnfairLock.h>
#import <stdatomic.h>
#import <os/lock.h>

@interface ASRecursiveUnfairLockTests : ASTestCase

@end

@implementation ASRecursiveUnfairLockTests {
  ASRecursiveUnfairLock lock;
}

- (void)setUp
{
  [super setUp];
  lock = AS_RECURSIVE_UNFAIR_LOCK_INIT;
}

- (void)testTheAtomicIsLockFree
{
  XCTAssertTrue(atomic_is_lock_free(&lock._thread));
}

- (void)testRelockingFromSameThread
{
  ASRecursiveUnfairLockLock(&lock);
  ASRecursiveUnfairLockLock(&lock);
  ASRecursiveUnfairLockUnlock(&lock);
  // Now try locking from another thread.
  XCTestExpectation *e1 = [self expectationWithDescription:@"Other thread tried lock."];
  [NSThread detachNewThreadWithBlock:^{
    XCTAssertFalse(ASRecursiveUnfairLockTryLock(&self->lock));
    [e1 fulfill];
  }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
  ASRecursiveUnfairLockUnlock(&lock);
  
  XCTestExpectation *e2 = [self expectationWithDescription:@"Other thread tried lock again"];
  [NSThread detachNewThreadWithBlock:^{
    XCTAssertTrue(ASRecursiveUnfairLockTryLock(&self->lock));
    ASRecursiveUnfairLockUnlock(&self->lock);
    [e2 fulfill];
  }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testThatUnlockingWithoutHoldingMakesAssertion
{
#ifdef NS_BLOCK_ASSERTIONS
#warning Assertions should be on for `testThatUnlockingWithoutHoldingMakesAssertion`
  NSLog(@"Passing because assertions are off.");
#else
  ASRecursiveUnfairLockLock(&lock);
  XCTestExpectation *e1 = [self expectationWithDescription:@"Other thread tried lock."];
  [NSThread detachNewThreadWithBlock:^{
    XCTAssertThrows(ASRecursiveUnfairLockUnlock(&lock));
    [e1 fulfill];
  }];
  [self waitForExpectationsWithTimeout:10 handler:nil];
  ASRecursiveUnfairLockUnlock(&lock);
#endif
}

#define CHAOS_TEST_BODY(contested, prefix, infix, postfix) \
dispatch_group_t g = dispatch_group_create(); \
for (int i = 0; i < (contested ? 16 : 2); i++) {\
dispatch_group_enter(g);\
[NSThread detachNewThreadWithBlock:^{\
  for (int i = 0; i < 20000; i++) {\
    prefix;\
    value += 150;\
    infix;\
    value -= 150;\
    postfix;\
  }\
  dispatch_group_leave(g);\
}];\
}\
dispatch_group_wait(g, DISPATCH_TIME_FOREVER);

#pragma mark - Correctness Tests

- (void)testRecursiveUnfairLockContested
{
  __block int value = 0;
  [self measureBlock:^{
    CHAOS_TEST_BODY(YES, ASRecursiveUnfairLockLock(&lock), {}, ASRecursiveUnfairLockUnlock(&lock));
  }];
  XCTAssertEqual(value, 0);
}

- (void)testRecursiveUnfairLockUncontested
{
  __block int value = 0;
  [self measureBlock:^{
    CHAOS_TEST_BODY(NO, ASRecursiveUnfairLockLock(&lock), {}, ASRecursiveUnfairLockUnlock(&lock));
  }];
  XCTAssertEqual(value, 0);
}

#pragma mark - Lock performance tests

#if RUN_LOCK_PERF_TESTS
- (void)testNoLockContested
{
  __block int value = 0;
  [self measureBlock:^{
    CHAOS_TEST_BODY(YES, {}, {}, {});
  }];
  XCTAssertNotEqual(value, 0);
}

- (void)testPlainUnfairLockContested
{
  __block int value = 0;
  __block os_unfair_lock unfairLock = OS_UNFAIR_LOCK_INIT;
  [self measureBlock:^{
    CHAOS_TEST_BODY(YES, os_unfair_lock_lock(&unfairLock), {}, os_unfair_lock_unlock(&unfairLock));
  }];
  XCTAssertEqual(value, 0);
}

- (void)testRecursiveMutexContested
{
  __block int value = 0;
  pthread_mutexattr_t attr;
  pthread_mutexattr_init (&attr);
  pthread_mutexattr_settype (&attr, PTHREAD_MUTEX_RECURSIVE);
  __block pthread_mutex_t m;
  pthread_mutex_init (&m, &attr);
  pthread_mutexattr_destroy (&attr);
  
  [self measureBlock:^{
    CHAOS_TEST_BODY(YES, pthread_mutex_lock(&m), {}, pthread_mutex_unlock(&m));
  }];
  pthread_mutex_destroy(&m);
}

- (void)testNoLockUncontested
{
  __block int value = 0;
  [self measureBlock:^{
    CHAOS_TEST_BODY(NO, {}, {}, {});
  }];
  XCTAssertNotEqual(value, 0);
}

- (void)testPlainUnfairLockUncontested
{
  __block int value = 0;
  __block os_unfair_lock unfairLock = OS_UNFAIR_LOCK_INIT;
  [self measureBlock:^{
    CHAOS_TEST_BODY(NO, os_unfair_lock_lock(&unfairLock), {}, os_unfair_lock_unlock(&unfairLock));
  }];
  XCTAssertEqual(value, 0);
}

- (void)testRecursiveMutexUncontested
{
  __block int value = 0;
  pthread_mutexattr_t attr;
  pthread_mutexattr_init (&attr);
  pthread_mutexattr_settype (&attr, PTHREAD_MUTEX_RECURSIVE);
  __block pthread_mutex_t m;
  pthread_mutex_init (&m, &attr);
  pthread_mutexattr_destroy (&attr);
  
  [self measureBlock:^{
    CHAOS_TEST_BODY(NO, pthread_mutex_lock(&m), {}, pthread_mutex_unlock(&m));
  }];
  pthread_mutex_destroy(&m);
}

#endif // RUN_LOCK_PERF_TESTS
@end
