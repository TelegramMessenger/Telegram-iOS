//
//  ASWeakMap.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASWeakMap.h"

@interface ASWeakMapEntry ()
@property (nonatomic, readonly) id key;
@property id value;
@end

@implementation ASWeakMapEntry

- (instancetype)initWithKey:(id)key value:(id)value
{
  self = [super init];
  if (self) {
    _key = key;
    _value = value;
  }
  return self;
}

@end


@interface ASWeakMap ()
@property (nonatomic, readonly) NSMapTable<id, ASWeakMapEntry *> *hashTable;
@end

/**
 * Implementation details:
 *
 * The retained size of our keys is potentially very large (for example, a UIImage is commonly part of a key).
 * Unfortunately, NSMapTable does not make guarantees about how quickly it will dispose of entries where
 * either the key or the value is weak and has been disposed.  So, a NSMapTable with "strong key to weak value" is
 * unsuitable for our purpose because the strong keys are retained longer than the value and for an indefininte period of time.
 * More details here: http://cocoamine.net/blog/2013/12/13/nsmaptable-and-zeroing-weak-references/
 *
 * Our NSMapTable is "weak key to weak value" where each key maps to an Entry.  The Entry object is responsible
 * for retaining both the key and value.  Our convention is that the caller must retain the Entry object
 * in order to keep the key and the value in the cache.
 */
@implementation ASWeakMap

- (instancetype)init
{
  self = [super init];
  if (self) {
    _hashTable = [NSMapTable weakToWeakObjectsMapTable];
  }
  return self;
}

- (ASWeakMapEntry *)entryForKey:(id)key
{
  return [self.hashTable objectForKey:key];
}

- (ASWeakMapEntry *)setObject:(id)value forKey:(id)key
{
  ASWeakMapEntry *entry = [self.hashTable objectForKey:key];
  if (entry != nil) {
    // Update the value in the existing entry.
    entry.value = value;
  } else {
    entry = [[ASWeakMapEntry alloc] initWithKey:key value:value];
    [self.hashTable setObject:entry forKey:key];
  }
  return entry;
}

@end
