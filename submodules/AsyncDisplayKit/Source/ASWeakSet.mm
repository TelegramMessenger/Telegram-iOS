//
//  ASWeakSet.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
