//
//  AsyncDisplayKit+Tips.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit+Tips.h>
#import <AsyncDisplayKit/ASDisplayNode+Ancestry.h>

@implementation ASDisplayNode (Tips)

static char ASDisplayNodeEnableTipsKey;
static ASTipDisplayBlock _Nullable __tipDisplayBlock;

/**
 * Use associated objects with NSNumbers. This is a debug property - simplicity is king.
 */
+ (void)setEnableTips:(BOOL)enableTips
{
  objc_setAssociatedObject(self, &ASDisplayNodeEnableTipsKey, @(enableTips), OBJC_ASSOCIATION_COPY);
}

+ (BOOL)enableTips
{
  NSNumber *result = objc_getAssociatedObject(self, &ASDisplayNodeEnableTipsKey);
  if (result == nil) {
    return YES;
  }
  return result.boolValue;
}


+ (void)setTipDisplayBlock:(ASTipDisplayBlock)tipDisplayBlock
{
  __tipDisplayBlock = tipDisplayBlock;
}

+ (ASTipDisplayBlock)tipDisplayBlock
{
  return __tipDisplayBlock ?: ^(ASDisplayNode *node, NSString *string) {
    NSLog(@"%@. Node ancestry: %@", string, node.ancestryDescription);
  };
}

@end
