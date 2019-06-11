//
//  PageNode.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "PageNode.h"

@implementation PageNode

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  return constrainedSize;
}

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  NSLog(@"didEnterPreloadState for node: %@", self);
}

@end
