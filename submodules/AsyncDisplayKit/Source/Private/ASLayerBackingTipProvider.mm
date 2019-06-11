//
//  ASLayerBackingTipProvider.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
