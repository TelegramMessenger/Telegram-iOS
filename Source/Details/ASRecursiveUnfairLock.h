//
//  ASRecursiveUnfairLock.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <pthread/pthread.h>
#import <os/lock.h>

// Note: We don't use ATOMIC_VAR_INIT here because C++ compilers don't like it,
// and it literally does absolutely nothing.
#define AS_RECURSIVE_UNFAIR_LOCK_INIT ((ASRecursiveUnfairLock){ OS_UNFAIR_LOCK_INIT, NULL, 0})

NS_ASSUME_NONNULL_BEGIN

OS_UNFAIR_LOCK_AVAILABILITY
typedef struct {
  os_unfair_lock _lock OS_UNFAIR_LOCK_AVAILABILITY;
  _Atomic(pthread_t) _thread;  // Write-protected by lock
  int _count;                  // Protected by lock
} ASRecursiveUnfairLock;

/**
 * Lock, blocking if needed.
 */
AS_EXTERN OS_UNFAIR_LOCK_AVAILABILITY
void ASRecursiveUnfairLockLock(ASRecursiveUnfairLock *l);

/**
 * Try to lock without blocking. Returns whether we took the lock.
 */
AS_EXTERN OS_UNFAIR_LOCK_AVAILABILITY
BOOL ASRecursiveUnfairLockTryLock(ASRecursiveUnfairLock *l);

/**
 * Unlock. Calling this on a thread that does not own
 * the lock will result in an assertion failure, and undefined
 * behavior if foundation assertions are disabled.
 */
AS_EXTERN OS_UNFAIR_LOCK_AVAILABILITY
void ASRecursiveUnfairLockUnlock(ASRecursiveUnfairLock *l);

NS_ASSUME_NONNULL_END
