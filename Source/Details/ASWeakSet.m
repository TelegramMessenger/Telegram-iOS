//
//  ASWeakSet.m
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

#import <AsyncDisplayKit/ASWeakSet.h>

@interface ASWeakSet<__covariant ObjectType> ()
@property (nonatomic, readonly) NSHashTable<ObjectType> *hashTable;
@end

@implementation ASWeakSet

- (instancetype)init
{
  self = [super init];
  if (self) {
    _hashTable = [NSHashTable hashTableWithOptions:NSHashTableWeakMemory | NSHashTableObjectPointerPersonality];
  }
  return self;
}

- (void)addObject:(id)object
{
  [_hashTable addObject:object];
}

- (void)removeObject:(id)object
{
  [_hashTable removeObject:object];
}

- (void)removeAllObjects
{
  [_hashTable removeAllObjects];
}

- (NSArray *)allObjects
{
  return _hashTable.allObjects;
}

- (BOOL)containsObject:(id)object
{
  return [_hashTable containsObject:object];
}

- (BOOL)isEmpty
{
  return [_hashTable anyObject] == nil;
}

/**
 Note: The `count` property of NSHashTable is unreliable
 in the case of weak-memory hash tables because entries
 that have been deallocated are not removed immediately.
 
 In order to get the true count we have to fall back to using
 fast enumeration.
 */
- (NSUInteger)count
{
  NSUInteger count = 0;
  for (__unused id object in _hashTable) {
    count += 1;
  }
  return count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id  _Nonnull *)buffer count:(NSUInteger)len
{
  return [_hashTable countByEnumeratingWithState:state objects:buffer count:len];
}

- (NSString *)description
{
  return [[super description] stringByAppendingFormat:@" count: %tu, contents: %@", self.count, _hashTable];
}

@end
