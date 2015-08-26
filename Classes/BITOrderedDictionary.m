#import "BITOrderedDictionary.h"

@implementation BITOrderedDictionary

- (instancetype)init {
  if (self = [super init]) {
    dictionary = [NSMutableDictionary new];
    order = [NSMutableArray new];
  }
  return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems {
  self = [super init];
  if ( self != nil )
  {
    dictionary = [[NSMutableDictionary alloc] initWithCapacity:numItems];
    order = [NSMutableArray new];
  }
  return self;
}

- (void)setObject:(id)anObject forKey:(id)aKey {
  if(!dictionary[aKey]) {
    [order addObject:aKey];
  }
  dictionary[aKey] = anObject;
}

- (NSEnumerator *)keyEnumerator {
  return [order objectEnumerator];
}

- (id)objectForKey:(id)key {
  return dictionary[key];
}

- (NSUInteger)count {
  return [dictionary count];
}

@end
