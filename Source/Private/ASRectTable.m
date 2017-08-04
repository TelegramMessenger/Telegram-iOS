//
//  ASRectTable.m
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

#import "ASRectTable.h"

__attribute__((const))
static NSUInteger ASRectSize(const void *ptr)
{
  return sizeof(CGRect);
}

@implementation NSMapTable (ASRectTableMethods)

+ (NSMapTable *)rectTableWithKeyPointerFunctions:(NSPointerFunctions *)keyFuncs
{
  static NSPointerFunctions *cgRectFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cgRectFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStructPersonality | NSPointerFunctionsCopyIn | NSPointerFunctionsMallocMemory];
    cgRectFuncs.sizeFunction = &ASRectSize;
  });

  return [[NSMapTable alloc] initWithKeyPointerFunctions:keyFuncs valuePointerFunctions:cgRectFuncs capacity:0];
}

+ (NSMapTable *)rectTableForStrongObjectPointers
{
  static NSPointerFunctions *strongObjectPointerFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    strongObjectPointerFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
  });
  return [self rectTableWithKeyPointerFunctions:strongObjectPointerFuncs];
}

+ (NSMapTable *)rectTableForWeakObjectPointers
{
  static NSPointerFunctions *weakObjectPointerFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    weakObjectPointerFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
  });
  return [self rectTableWithKeyPointerFunctions:weakObjectPointerFuncs];
}

- (CGRect)rectForKey:(id)key
{
  CGRect *ptr = (__bridge CGRect *)[self objectForKey:key];
  if (ptr == NULL) {
    return CGRectNull;
  }
  return *ptr;
}

- (void)setRect:(CGRect)rect forKey:(id)key
{
  __unsafe_unretained id obj = (__bridge id)&rect;
  [self setObject:obj forKey:key];
}

- (void)removeRectForKey:(id)key
{
  [self removeObjectForKey:key];
}

@end
