//
//  ASTextKitEntityAttribute.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextKitEntityAttribute.h>

#if AS_ENABLE_TEXTNODE

@implementation ASTextKitEntityAttribute

- (instancetype)initWithEntity:(id<NSObject>)entity
{
  if (self = [super init]) {
    _entity = entity;
  }
  return self;
}

- (NSUInteger)hash
{
  return [_entity hash];
}

- (BOOL)isEqual:(id)object
{
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[self class]]) {
    return NO;
  }
  ASTextKitEntityAttribute *other = (ASTextKitEntityAttribute *)object;
  return _entity == other.entity || [_entity isEqual:other.entity];
}

@end

#endif
