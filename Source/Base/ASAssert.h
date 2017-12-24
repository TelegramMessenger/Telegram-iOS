//
//  ASAssert.h
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

#pragma once

#import <Foundation/NSException.h>
#import <pthread.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#define ASDISPLAYNODE_ASSERTIONS_ENABLED (!defined(NS_BLOCK_ASSERTIONS))

/**
 * Note: In some cases it would be sufficient to do e.g.:
 *  ASDisplayNodeAssert(...) NSAssert(__VA_ARGS__)
 * but we prefer not to, because we want to match the autocomplete behavior of NSAssert.
 * The construction listed above does not show the user what arguments are required and what are optional.
 */

#define ASDisplayNodeAssert(condition, desc, ...) NSAssert(condition, desc, ##__VA_ARGS__)
#define ASDisplayNodeCAssert(condition, desc, ...) NSCAssert(condition, desc, ##__VA_ARGS__)

#define ASDisplayNodeAssertNil(condition, desc, ...) ASDisplayNodeAssert((condition) == nil, desc, ##__VA_ARGS__)
#define ASDisplayNodeCAssertNil(condition, desc, ...) ASDisplayNodeCAssert((condition) == nil, desc, ##__VA_ARGS__)

#define ASDisplayNodeAssertNotNil(condition, desc, ...) ASDisplayNodeAssert((condition) != nil, desc, ##__VA_ARGS__)
#define ASDisplayNodeCAssertNotNil(condition, desc, ...) ASDisplayNodeCAssert((condition) != nil, desc, ##__VA_ARGS__)

#define ASDisplayNodeAssertImplementedBySubclass() ASDisplayNodeAssert(NO, @"This method must be implemented by subclass %@", [self class]);
#define ASDisplayNodeAssertNotInstantiable() ASDisplayNodeAssert(NO, nil, @"This class is not instantiable.");
#define ASDisplayNodeAssertNotSupported() ASDisplayNodeAssert(NO, nil, @"This method is not supported by class %@", [self class]);

#define ASDisplayNodeAssertMainThread() ASDisplayNodeAssert(ASMainThreadAssertionsAreDisabled() || 0 != pthread_main_np(), @"This method must be called on the main thread")
#define ASDisplayNodeCAssertMainThread() ASDisplayNodeCAssert(ASMainThreadAssertionsAreDisabled() || 0 != pthread_main_np(), @"This function must be called on the main thread")

#define ASDisplayNodeAssertNotMainThread() ASDisplayNodeAssert(0 == pthread_main_np(), @"This method must be called off the main thread")
#define ASDisplayNodeCAssertNotMainThread() ASDisplayNodeCAssert(0 == pthread_main_np(), @"This function must be called off the main thread")

#define ASDisplayNodeAssertFlag(X, desc, ...) ASDisplayNodeAssert((1 == __builtin_popcount(X)), desc, ##__VA_ARGS__)
#define ASDisplayNodeCAssertFlag(X, desc, ...) ASDisplayNodeCAssert((1 == __builtin_popcount(X)), desc, ##__VA_ARGS__)

#define ASDisplayNodeAssertTrue(condition) ASDisplayNodeAssert((condition), @"Expected %s to be true.", #condition)
#define ASDisplayNodeCAssertTrue(condition) ASDisplayNodeCAssert((condition), @"Expected %s to be true.", #condition)

#define ASDisplayNodeAssertFalse(condition) ASDisplayNodeAssert(!(condition), @"Expected %s to be false.", #condition)
#define ASDisplayNodeCAssertFalse(condition) ASDisplayNodeCAssert(!(condition), @"Expected %s to be false.", #condition)

#define ASDisplayNodeFailAssert(desc, ...) ASDisplayNodeAssert(NO, desc, ##__VA_ARGS__)
#define ASDisplayNodeCFailAssert(desc, ...) ASDisplayNodeCAssert(NO, desc, ##__VA_ARGS__)

#define ASDisplayNodeConditionalAssert(shouldTestCondition, condition, desc, ...) ASDisplayNodeAssert((!(shouldTestCondition) || (condition)), desc, ##__VA_ARGS__)
#define ASDisplayNodeConditionalCAssert(shouldTestCondition, condition, desc, ...) ASDisplayNodeCAssert((!(shouldTestCondition) || (condition)), desc, ##__VA_ARGS__)

#define ASDisplayNodeCAssertPositiveReal(description, num) ASDisplayNodeCAssert(num >= 0 && num <= CGFLOAT_MAX, @"%@ must be a real positive integer: %f.", description, (CGFloat)num)
#define ASDisplayNodeCAssertInfOrPositiveReal(description, num) ASDisplayNodeCAssert(isinf(num) || (num >= 0 && num <= CGFLOAT_MAX), @"%@ must be infinite or a real positive integer: %f.", description, (CGFloat)num)

#define ASDisplayNodeErrorDomain @"ASDisplayNodeErrorDomain"
#define ASDisplayNodeNonFatalErrorCode 1

/**
 * In debug methods, it can be useful to disable main thread assertions to get valuable information,
 * even if it means violating threading requirements. These functions are used in -debugDescription and let
 * threads decide to suppress/re-enable main thread assertions.
 */
#pragma mark - Main Thread Assertions Disabling

ASDISPLAYNODE_EXTERN_C_BEGIN
BOOL ASMainThreadAssertionsAreDisabled(void);

void ASPushMainThreadAssertionsDisabled(void);

void ASPopMainThreadAssertionsDisabled(void);
ASDISPLAYNODE_EXTERN_C_END

#pragma mark - Non-Fatal Assertions

/// Returns YES if assertion passed, NO otherwise.
#define ASDisplayNodeAssertNonFatal(condition, desc, ...) ({                                                                      \
  BOOL __evaluated = condition;                                                                                                   \
  if (__evaluated == NO) {                                                                                                        \
    ASDisplayNodeFailAssert(desc, ##__VA_ARGS__);                                                                                 \
    ASDisplayNodeNonFatalErrorBlock block = [ASDisplayNode nonFatalErrorBlock];                                                   \
    if (block != nil) {                                                                                                           \
      NSDictionary *userInfo = nil;                                                                                               \
      if (desc.length > 0) {                                                                                                      \
        userInfo = @{ NSLocalizedDescriptionKey : desc };                                                                         \
      }                                                                                                                           \
      NSError *error = [NSError errorWithDomain:ASDisplayNodeErrorDomain code:ASDisplayNodeNonFatalErrorCode userInfo:userInfo];  \
      block(error);                                                                                                               \
    }                                                                                                                             \
  }                                                                                                                               \
  __evaluated;                                                                                                                    \
})                                                                                                                                \
