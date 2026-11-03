//
//  ASCollections.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASCollections.h>

/**
 * A private allocator that signals to our retain callback to skip the retain.
 * It behaves the same as the default allocator, but acts as a signal that we
 * are creating a transfer array so we should skip the retain.
 */
static CFAllocatorRef gTransferAllocator;

static const void *ASTransferRetain(CFAllocatorRef allocator, const void *val) {
  if (allocator == gTransferAllocator) {
    // Transfer allocator. Ignore retain and pass through.
    return val;
  } else {
    // Other allocator. Retain like normal.
    // This happens when they make a mutable copy.
    return (&kCFTypeArrayCallBacks)->retain(allocator, val);
  }
}

@implementation NSArray (ASCollections)

+ (NSArray *)arrayByTransferring:(__strong id *)pointers count:(NSUInteger)count NS_RETURNS_RETAINED
{
  // Custom callbacks that point to our ASTransferRetain callback.
  static CFArrayCallBacks callbacks;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    callbacks = kCFTypeArrayCallBacks;
    callbacks.retain = ASTransferRetain;
    CFAllocatorContext ctx;
    CFAllocatorGetContext(NULL, &ctx);
    gTransferAllocator = CFAllocatorCreate(NULL, &ctx);
  });
  
  // NSZeroArray fast path.
  if (count == 0) {
    return @[]; // Does not actually call +array when optimized.
  }
  
  // NSSingleObjectArray fast path. Retain/release here is worth it.
  if (count == 1) {
    NSArray *result = [[NSArray alloc] initWithObjects:pointers count:1];
    pointers[0] = nil;
    return result;
  }
  
  NSArray *result = (__bridge_transfer NSArray *)CFArrayCreate(gTransferAllocator, (const void **)(void *)pointers, count, &callbacks);
  memset(pointers, 0, count * sizeof(id));
  return result;
}

@end
