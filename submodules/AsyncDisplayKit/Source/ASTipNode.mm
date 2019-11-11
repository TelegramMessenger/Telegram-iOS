//
//  ASTipNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASTipNode.h"

#if AS_ENABLE_TIPS

@implementation ASTipNode

- (instancetype)initWithTip:(ASTip *)tip
{
  if (self = [super init]) {
    self.backgroundColor = [UIColor colorWithRed:0 green:0.7 blue:0.2 alpha:0.3];
    _tip = tip;
    [self addTarget:nil action:@selector(didTapTipNode:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  return self;
}

@end

#endif // AS_ENABLE_TIPS
