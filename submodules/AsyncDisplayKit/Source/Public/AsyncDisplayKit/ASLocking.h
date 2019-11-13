//
//  ASLocking.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <pthread/sched.h>

#import <AsyncDisplayKit/ASAssert.h>

NS_ASSUME_NONNULL_BEGIN

#define kLockSetCapacity 32

/**
 * An extension of NSLocking that supports -tryLock.
 */
@protocol ASLocking <NSLocking>

/// Try to take lock without blocking. Returns whether the lock was taken.
- (BOOL)tryLock;

@end

/**
 * A set of locks acquired during ASLockSequence.
 */
typedef struct {
  unsigned count;
  CFTypeRef _Nullable locks[kLockSetCapacity];
} ASLockSet;

/**
 * Declare a lock set that is automatically unlocked at the end of scope.
 *
 * We use this instead of a scope-locking macro because we want to be able
 * to step through the lock sequence block in the debugger.
 */
#define ASScopedLockSet __unused ASLockSet __attribute__((cleanup(ASUnlockSet)))

/**
 * A block that attempts to add a lock to a lock sequence.
 * Such a block is provided to the caller of ASLockSequence.
 *
 * Returns whether the lock was added. You should return
 * NO from your lock sequence body if it returns NO.
 *
 * For instance, you might write `return addLock(l1) && addLock(l2)`.
 *
 * @param lock The lock to attempt to add.
 * @return YES if the lock was added, NO otherwise.
 */
typedef BOOL(^ASAddLockBlock)(id<ASLocking> lock);

/**
 * A block that attempts to lock multiple locks in sequence.
 * Such a block is provided by the caller of ASLockSequence.
 *
 * The block may be run multiple times, if not all locks are immediately
 * available. Therefore the block should be idempotent.
 *
 * The block should attempt to invoke addLock multiple times with
 * different locks. It should return NO as soon as any addLock
 * operation fails.
 *
 * For instance, you might write `return addLock(l1) && addLock(l2)`.
 *
 * @param addLock A block you can call to attempt to add a lock.
 * @return YES if all locks were added, NO otherwise.
 */
typedef BOOL(^ASLockSequenceBlock)(NS_NOESCAPE ASAddLockBlock addLock);

/**
 * Unlock and release all of the locks in this lock set.
 */
NS_INLINE void ASUnlockSet(ASLockSet *lockSet) {
  for (unsigned i = 0; i < lockSet->count; i++) {
    CFTypeRef lock = lockSet->locks[i];
    [(__bridge id<ASLocking>)lock unlock];
    CFRelease(lock);
  }
}

/**
 * Take multiple locks "simultaneously," avoiding deadlocks
 * caused by lock ordering.
 *
 * The block you provide should attempt to take a series of locks,
 * using the provided `addLock` block. As soon as any addLock fails,
 * you should return NO.
 *
 * For example:
 * ASLockSequence(^(ASAddLockBlock addLock) ^{
 *   return addLock(l0) && addLock(l1);
 * });
 *
 * Note: This function doesn't protect from lock ordering deadlocks if
 * one of the locks is already locked (recursive.) Only locks taken
 * inside this function are guaranteed not to cause a deadlock.
 */
NS_INLINE ASLockSet ASLockSequence(NS_NOESCAPE ASLockSequenceBlock body)
{
  __block ASLockSet locks = (ASLockSet){0, {}};
  BOOL (^addLock)(id<ASLocking>) = ^(id<ASLocking> obj) {
    
    // nil lock = ignore.
    if (!obj) {
      return YES;
    }
    
    // If they go over capacity, assert and return YES.
    // If we return NO, they will enter an infinite loop.
    if (locks.count == kLockSetCapacity) {
      ASDisplayNodeCFailAssert(@"Locking more than %d locks at once is not supported.", kLockSetCapacity);
      return YES;
    }
    
    if ([obj tryLock]) {
      locks.locks[locks.count++] = (__bridge_retained CFTypeRef)obj;
      return YES;
    }
    return NO;
  };
  
  /**
   * Repeatedly try running their block, passing in our `addLock`
   * until it succeeds. If it fails, unlock all and yield the thread
   * to reduce spinning.
   */
  while (true) {
    if (body(addLock)) {
      // Success
      return locks;
    } else {
      ASUnlockSet(&locks);
      locks.count = 0;
      sched_yield();
    }
  }
}

/**
 * These Foundation classes already implement -tryLock.
 */

@interface NSLock (ASLocking) <ASLocking>
@end

@interface NSRecursiveLock (ASLocking) <ASLocking>
@end

@interface NSConditionLock (ASLocking) <ASLocking>
@end

NS_ASSUME_NONNULL_END
