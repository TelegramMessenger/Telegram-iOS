//
//  NSInvocation+ASTestHelpers.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "NSInvocation+ASTestHelpers.h"

@implementation NSInvocation (ASTestHelpers)

- (id)as_argumentAtIndexAsObject:(NSInteger)index
{
  void *buf;
  [self getArgument:&buf atIndex:index];
  return (__bridge id)buf;
}

- (void)as_setReturnValueWithObject:(id)object
{
  if (object == nil) {
    const void *fixedBuf = NULL;
    [self setReturnValue:&fixedBuf];
  } else {
    // Retain, then autorelease.
    const void *fixedBuf = CFAutorelease((__bridge_retained void *)object);
    [self setReturnValue:&fixedBuf];
  }
}

@end
