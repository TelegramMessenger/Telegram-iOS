//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ViewController.h"
#import "ScreenNode.h"

@interface ViewController()
{
  ScreenNode *_screenNode;
}

@end

@implementation ViewController

- (instancetype)init
{
  ScreenNode *node = [[ScreenNode alloc] init];
  if (!(self = [super initWithNode:node]))
    return nil;

  _screenNode = node;

  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  // This should be done before calling super's viewWillAppear which triggers data fetching on the node.
  [_screenNode start];
  [super viewWillAppear:animated];
}

@end
