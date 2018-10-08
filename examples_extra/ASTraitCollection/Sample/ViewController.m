//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ViewController.h"
#import "KittenNode.h"
#import "OverrideViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

@interface ViewController ()
@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  KittenNode *displayNode = [[KittenNode alloc] init];
  if (!(self = [super initWithNode:displayNode]))
    return nil;

  self.title = @"Display Node";
  displayNode.imageTappedBlock = ^{
    [KittenNode defaultImageTappedAction:self];
  };
  return self;
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
}

@end
