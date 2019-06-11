//
//  NSInvocation+ASTestHelpers.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSInvocation (ASTestHelpers)

/**
 * Formats the argument at the given index as an object and returns it.
 *
 * Currently only supports arguments that are themselves objects, but handles
 * getting the argument into ARC safely.
 */
- (nullable id)as_argumentAtIndexAsObject:(NSInteger)index;

/**
 * Sets the return value, simulating ARC behavior.
 *
 * Currently only supports invocations whose return values are already object types.
 */
- (void)as_setReturnValueWithObject:(nullable id)object;

@end

NS_ASSUME_NONNULL_END
