//
//  ASObjectDescriptionHelpers.m
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

#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

#import <UIKit/UIGeometry.h>

#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

NSString *ASGetDescriptionValueString(id object)
{
  if ([object isKindOfClass:[NSValue class]]) {
    // Use shortened NSValue descriptions
    NSValue *value = object;
    const char *type = value.objCType;
    
    if (strcmp(type, @encode(CGRect)) == 0) {
      CGRect rect = [value CGRectValue];
      return [NSString stringWithFormat:@"(%g %g; %g %g)", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
    } else if (strcmp(type, @encode(CGSize)) == 0) {
      return NSStringFromCGSize(value.CGSizeValue);
    } else if (strcmp(type, @encode(CGPoint)) == 0) {
      return NSStringFromCGPoint(value.CGPointValue);
    }
    
  } else if ([object isKindOfClass:[NSIndexSet class]]) {
    return [object as_smallDescription];
  } else if ([object isKindOfClass:[NSIndexPath class]]) {
    // index paths like (0, 7)
    NSIndexPath *indexPath = object;
    NSMutableArray *strings = [NSMutableArray array];
    for (NSUInteger i = 0; i < indexPath.length; i++) {
      [strings addObject:[NSString stringWithFormat:@"%lu", (unsigned long)[indexPath indexAtPosition:i]]];
    }
    return [NSString stringWithFormat:@"(%@)", [strings componentsJoinedByString:@", "]];
  } else if ([object respondsToSelector:@selector(componentsJoinedByString:)]) {
    // e.g. "[ <MYObject: 0x00000000> <MYObject: 0xFFFFFFFF> ]"
    return [NSString stringWithFormat:@"[ %@ ]", [object componentsJoinedByString:@" "]];
  }
  return [object description];
}

NSString *_ASObjectDescriptionMakePropertyList(NSArray<NSDictionary *> * _Nullable propertyGroups)
{
  NSMutableArray *components = [NSMutableArray array];
  for (NSDictionary *properties in propertyGroups) {
    [properties enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
      NSString *str;
      if (key == (id)kCFNull) {
        str = ASGetDescriptionValueString(obj);
      } else {
        str = [NSString stringWithFormat:@"%@ = %@", key, ASGetDescriptionValueString(obj)];
      }
      [components addObject:str];
    }];
  }
  return [components componentsJoinedByString:@"; "];
}

NSString *ASObjectDescriptionMakeWithoutObject(NSArray<NSDictionary *> * _Nullable propertyGroups)
{
  return [NSString stringWithFormat:@"{ %@ }", _ASObjectDescriptionMakePropertyList(propertyGroups)];
}

NSString *ASObjectDescriptionMake(__autoreleasing id object, NSArray<NSDictionary *> *propertyGroups)
{
  if (object == nil) {
    return @"(null)";
  }

  NSMutableString *str = [NSMutableString stringWithFormat:@"<%s: %p", object_getClassName(object), object];

  NSString *propList = _ASObjectDescriptionMakePropertyList(propertyGroups);
  if (propList.length > 0) {
    [str appendFormat:@"; %@", propList];
  }
  [str appendString:@">"];
  return str;
}

NSString *ASObjectDescriptionMakeTiny(__autoreleasing id object) {
  return ASObjectDescriptionMake(object, nil);
}

NSString *ASStringWithQuotesIfMultiword(NSString *string) {
  if (string == nil) {
    return nil;
  }
  
  if ([string rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) {
    return [NSString stringWithFormat:@"\"%@\"", string];
  } else {
    return string;
  }
}
