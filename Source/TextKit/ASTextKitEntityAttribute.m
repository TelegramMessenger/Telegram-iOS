//
//  ASTextKitEntityAttribute.m
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

#import <AsyncDisplayKit/ASTextKitEntityAttribute.h>

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
