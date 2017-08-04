//
//  ASNodeController+Beta.m
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

#import "ASNodeController+Beta.h"
#import "ASDisplayNode+FrameworkPrivate.h"

#if INVERT_NODE_CONTROLLER_OWNERSHIP

@interface ASDisplayNode (ASNodeController)
@property (nonatomic, strong) ASNodeController *asdkNodeController;
@end

@implementation ASDisplayNode (ASNodeController)

- (ASNodeController *)asdkNodeController
{
  return objc_getAssociatedObject(self, @selector(asdkNodeController));
}

- (void)setAsdkNodeController:(ASNodeController *)asdkNodeController
{
  objc_setAssociatedObject(self, @selector(asdkNodeController), asdkNodeController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#endif

@implementation ASNodeController

@synthesize node = _node;

- (instancetype)init
{
  self = [super init];
  if (self) {
    
  }
  return self;
}

- (void)loadNode
{
  self.node = [[ASDisplayNode alloc] init];
}

- (ASDisplayNode *)node
{
  if (_node == nil) {
    [self loadNode];
  }
  return _node;
}

-(void)setNode:(ASDisplayNode *)node
{
  _node = node;
  _node.interfaceStateDelegate = self;
#if INVERT_NODE_CONTROLLER_OWNERSHIP
  _node.asdkNodeController = self;
#endif
}

// subclass overrides
- (void)didEnterVisibleState {}
- (void)didExitVisibleState  {}

- (void)didEnterDisplayState {}
- (void)didExitDisplayState  {}

- (void)didEnterPreloadState {}
- (void)didExitPreloadState  {}

- (void)interfaceStateDidChange:(ASInterfaceState)newState
                      fromState:(ASInterfaceState)oldState {}

@end
