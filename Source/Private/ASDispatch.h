//
//  ASDispatch.h
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

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 * Like dispatch_apply, but you can set the thread count. 0 means 2*active CPUs.
 *
 * Note: The actual number of threads may be lower than threadCount, if libdispatch
 * decides the system can't handle it. In reality this rarely happens.
 */
void ASDispatchApply(size_t iterationCount, dispatch_queue_t queue, NSUInteger threadCount, NS_NOESCAPE void(^work)(size_t i));

/**
 * Like dispatch_async, but you can set the thread count. 0 means 2*active CPUs.
 *
 * Note: The actual number of threads may be lower than threadCount, if libdispatch
 * decides the system can't handle it. In reality this rarely happens.
 */
void ASDispatchAsync(size_t iterationCount, dispatch_queue_t queue, NSUInteger threadCount, NS_NOESCAPE void(^work)(size_t i));

ASDISPLAYNODE_EXTERN_C_END
