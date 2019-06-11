//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ViewController.h"

#import "MapHandlerNode.h"

@interface ViewController ()

@end

@implementation ViewController


#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super initWithNode:[[MapHandlerNode alloc] init]];
  if (self == nil) { return self; }

  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  self.navigationController.navigationBarHidden = YES;
}

@end
