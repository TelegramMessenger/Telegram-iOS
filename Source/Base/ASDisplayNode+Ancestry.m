//
//  ASDisplayNode+Ancestry.m
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

#import "ASDisplayNode+Ancestry.h"
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>

AS_SUBCLASSING_RESTRICTED
@interface ASNodeAncestryEnumerator : NSEnumerator
@end

@implementation ASNodeAncestryEnumerator {
  ASDisplayNode *_lastNode; // This needs to be strong because enumeration will not retain the current batch of objects
  BOOL _initialState;
}

- (instancetype)initWithNode:(ASDisplayNode *)node
{
  if (self = [super init]) {
    _initialState = YES;
    _lastNode = node;
  }
  return self;
}

- (id)nextObject
{
  if (_initialState) {
    _initialState = NO;
    return _lastNode;
  }

  ASDisplayNode *nextNode = _lastNode.supernode;
  if (nextNode == nil && ASDisplayNodeThreadIsMain()) {
    CALayer *layer = _lastNode.nodeLoaded ? _lastNode.layer.superlayer : nil;
    while (layer != nil) {
      nextNode = ASLayerToDisplayNode(layer);
      if (nextNode != nil) {
        break;
      }
      layer = layer.superlayer;
    }
  }
  _lastNode = nextNode;
  return nextNode;
}

@end

@implementation ASDisplayNode (Ancestry)

- (id<NSFastEnumeration>)supernodes
{
  NSEnumerator *result = [[ASNodeAncestryEnumerator alloc] initWithNode:self];
  [result nextObject]; // discard first object (self)
  return result;
}

- (id<NSFastEnumeration>)supernodesIncludingSelf
{
  return [[ASNodeAncestryEnumerator alloc] initWithNode:self];
}

- (nullable __kindof ASDisplayNode *)supernodeOfClass:(Class)supernodeClass includingSelf:(BOOL)includeSelf
{
  id<NSFastEnumeration> chain = includeSelf ? self.supernodesIncludingSelf : self.supernodes;
  for (ASDisplayNode *ancestor in chain) {
    if ([ancestor isKindOfClass:supernodeClass]) {
      return ancestor;
    }
  }
  return nil;
}

- (NSString *)ancestryDescription
{
  NSMutableArray *strings = [NSMutableArray array];
  for (ASDisplayNode *node in self.supernodes) {
    [strings addObject:ASObjectDescriptionMakeTiny(node)];
  }
  return strings.description;
}

@end
