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

#import <AsyncDisplayKit/ASWeakProxy.h>
#import <AsyncDisplayKit/ASNodeController+Beta.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>

#define _node (_shouldInvertStrongReference ? _weakNode : _strongNode)

@interface ASDisplayNode (ASNodeControllerOwnership)

// This property exists for debugging purposes. Don't use __nodeController in production code.
@property (nonatomic, readonly) ASNodeController *__nodeController;

// These setters are mutually exclusive. Setting one will clear the relationship of the other.
- (void)__setNodeControllerStrong:(ASNodeController *)nodeController;
- (void)__setNodeControllerWeak:(ASNodeController *)nodeController;

@end

@implementation ASNodeController
{
  ASDisplayNode *_strongNode;
  __weak ASDisplayNode *_weakNode;
}

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

- (void)setupReferencesWithNode:(ASDisplayNode *)node
{
  if (_shouldInvertStrongReference) {
    // The node should own the controller; weak reference from controller to node.
    _weakNode = node;
    [node __setNodeControllerStrong:self];
    _strongNode = nil;
  } else {
    // The controller should own the node; weak reference from node to controller.
    _strongNode = node;
    [node __setNodeControllerWeak:self];
    _weakNode = nil;
  }

  node.interfaceStateDelegate = self;
}

- (void)setNode:(ASDisplayNode *)node
{
  [self setupReferencesWithNode:node];
}

- (void)setShouldInvertStrongReference:(BOOL)shouldInvertStrongReference
{
  if (_shouldInvertStrongReference != shouldInvertStrongReference) {
    // Because the BOOL controls which ivar we access, get the node before toggling.
    ASDisplayNode *node = _node;
    _shouldInvertStrongReference = shouldInvertStrongReference;
    [self setupReferencesWithNode:node];
  }
}

// subclass overrides
- (void)nodeDidLoad {}
- (void)nodeDidLayout {}

- (void)didEnterVisibleState {}
- (void)didExitVisibleState  {}

- (void)didEnterDisplayState {}
- (void)didExitDisplayState  {}

- (void)didEnterPreloadState {}
- (void)didExitPreloadState  {}

- (void)interfaceStateDidChange:(ASInterfaceState)newState
                      fromState:(ASInterfaceState)oldState {}

@end

@implementation ASDisplayNode (ASNodeControllerOwnership)

- (ASNodeController *)__nodeController
{
  ASNodeController *nodeController = nil;
  id object = objc_getAssociatedObject(self, @selector(__nodeController));

  if ([object isKindOfClass:[ASWeakProxy class]]) {
    nodeController = (ASNodeController *)[(ASWeakProxy *)object target];
  } else {
    nodeController = (ASNodeController *)object;
  }

  return nodeController;
}

- (void)__setNodeControllerStrong:(ASNodeController *)nodeController
{
  objc_setAssociatedObject(self, @selector(__nodeController), nodeController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)__setNodeControllerWeak:(ASNodeController *)nodeController
{
  // Associated objects don't support weak references. Since assign can become a dangling pointer, use ASWeakProxy.
  ASWeakProxy *nodeControllerProxy = [ASWeakProxy weakProxyWithTarget:nodeController];
  objc_setAssociatedObject(self, @selector(__nodeController), nodeControllerProxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation ASDisplayNode (ASNodeController)

- (ASNodeController *)nodeController {
  return self.__nodeController;
}

@end
