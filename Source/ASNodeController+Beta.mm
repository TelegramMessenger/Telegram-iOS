//
//  ASNodeController+Beta.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASNodeController+Beta.h>
#import <AsyncDisplayKit/ASThread.h>

#define _node (_shouldInvertStrongReference ? _weakNode : _strongNode)

@implementation ASNodeController
{
  ASDisplayNode *_strongNode;
  __weak ASDisplayNode *_weakNode;
  ASDN::Mutex _nodeLock;
}

- (ASDisplayNode *)createNode
{
  return [[ASDisplayNode alloc] init];
}

- (ASDisplayNode *)node
{
  ASDN::MutexLocker l(_nodeLock);
  ASDisplayNode *node = _node;
  if (!node) {
    node = [self createNode];
    if (!node) {
      ASDisplayNodeCFailAssert(@"Returned nil from -createNode.");
      node = [[ASDisplayNode alloc] init];
    }
    [self setupReferencesWithNode:node];
  }
  return node;
}

- (void)setupReferencesWithNode:(ASDisplayNode *)node
{
  ASLockScopeSelf();
  if (_shouldInvertStrongReference) {
    // The node should own the controller; weak reference from controller to node.
    _weakNode = node;
    _strongNode = nil;
  } else {
    // The controller should own the node; weak reference from node to controller.
    _strongNode = node;
    _weakNode = nil;
  }

  [node __setNodeController:self];
  [node addInterfaceStateDelegate:self];
}

- (void)setShouldInvertStrongReference:(BOOL)shouldInvertStrongReference
{
  ASLockScopeSelf();
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
- (void)nodeWillCalculateLayout:(ASSizeRange)constrainedSize {}

- (void)didEnterVisibleState {}
- (void)didExitVisibleState  {}

- (void)didEnterDisplayState {}
- (void)didExitDisplayState  {}

- (void)didEnterPreloadState {}
- (void)didExitPreloadState  {}

- (void)interfaceStateDidChange:(ASInterfaceState)newState
                      fromState:(ASInterfaceState)oldState {}

- (void)hierarchyDisplayDidFinish {}

#pragma mark NSLocking

- (void)lock
{
  [self.node lock];
}

- (void)unlock
{
  // Since the node was already locked on this thread, we don't need to call our accessor or take our lock.
  ASDisplayNodeAssertNotNil(_node, @"Node deallocated while locked.");
  [_node unlock];
}

- (BOOL)tryLock
{
  return [self.node tryLock];
}

@end

@implementation ASDisplayNode (ASNodeController)

- (ASNodeController *)nodeController
{
  return _weakNodeController ?: _strongNodeController;
}

@end
