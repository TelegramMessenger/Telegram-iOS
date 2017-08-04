//
//  ASLayerBackingTipProvider.m
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

#import "ASLayerBackingTipProvider.h"

#if AS_ENABLE_TIPS

#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASTip.h>

@implementation ASLayerBackingTipProvider

- (ASTip *)tipForNode:(ASDisplayNode *)node
{
  // Already layer-backed.
  if (node.layerBacked) {
    return nil;
  }

  // TODO: Avoid revisiting nodes we already visited
  ASDisplayNode *failNode = ASDisplayNodeFindFirstNode(node, ^BOOL(ASDisplayNode * _Nonnull node) {
    return !node.supportsLayerBacking;
  });
  if (failNode != nil) {
    return nil;
  }

  ASTip *result = [[ASTip alloc] initWithNode:node
                                         kind:ASTipKindEnableLayerBacking
                                       format:@"Enable layer backing to improve performance"];
  return result;
}

@end

#endif // AS_ENABLE_TIPS
