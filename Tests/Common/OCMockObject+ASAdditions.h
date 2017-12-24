//
//  OCMockObject+ASAdditions.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <OCMock/OCMock.h>

@interface OCMockObject (ASAdditions)

/**
 * NOTE: All OCMockObjects created during an ASTestCase call OCMVerifyAll during -tearDown.
 */

/**
 * A method to manually specify which optional protocol methods should return YES
 * from -respondsToSelector:.
 *
 * If you don't call this method, the default OCMock behavior is to
 * "implement" all optional protocol methods, which makes it impossible to
 * test scenarios where only a subset of optional protocol methods are implemented.
 *
 * You should only call this on protocol mocks.
 */
- (void)addImplementedOptionalProtocolMethods:(SEL)aSelector, ... NS_REQUIRES_NIL_TERMINATION;

/// An optional block to modify description text. Only used in OCClassMockObject currently.
@property (atomic) NSString *(^modifyDescriptionBlock)(OCMockObject *object, NSString *baseDescription);

@end

/**
 * Additional stub recorders useful in ASDK.
 */
@interface OCMStubRecorder (ASProperties)

/**
 * Add a debug-break side effect to this stub/expectation.
 *
 * You will usually need to jump to frame 12 "fr s 12"
 */
#define andDebugBreak() _andDebugBreak()
@property (nonatomic, readonly) OCMStubRecorder *(^ _andDebugBreak)(void);

#define ignoringNonObjectArgs() _ignoringNonObjectArgs()
@property (nonatomic, readonly) OCMStubRecorder *(^ _ignoringNonObjectArgs)(void);

#define onMainThread() _onMainThread()
@property (nonatomic, readonly) OCMStubRecorder *(^ _onMainThread)(void);

#define offMainThread() _offMainThread()
@property (nonatomic, readonly) OCMStubRecorder *(^ _offMainThread)(void);

@end
