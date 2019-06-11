//
//  ASListTestObject.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASListTestObject.h"

@implementation ASListTestObject

- (instancetype)initWithKey:(id)key value:(id)value
{
  if (self = [super init]) {
    _key = [key copy];
    _value = value;
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
  return [[ASListTestObject alloc] initWithKey:self.key value:self.value];
}

#pragma mark - IGListDiffable

- (id<NSObject>)diffIdentifier
{
  return self.key;
}

- (BOOL)isEqualToDiffableObject:(id)object
{
  if (object == self) {
    return YES;
  }
  if ([object isKindOfClass:[ASListTestObject class]]) {
    id k1 = self.key;
    id k2 = [object key];
    id v1 = self.value;
    id v2 = [(ASListTestObject *)object value];
    return (v1 == v2 || [v1 isEqual:v2]) && (k1 == k2 || [k1 isEqual:k2]);
  }
  return NO;
}

@end
