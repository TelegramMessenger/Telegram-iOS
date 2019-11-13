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
  AS::RecursiveMutex __instanceLock__;
}

- (void)loadNode
{
  ASLockScopeSelf();
  self.node = [[ASDisplayNode alloc] init];
}

- (ASDisplayNode *)node
{
  ASLockScopeSelf();
  if (_node == nil) {
    [self loadNode];
  }
  return _node;
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
}

- (void)setNode:(ASDisplayNode *)node
{
  ASLockScopeSelf();
  if (node == _node) {
    return;
  }
  [self setupReferencesWithNode:node];
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

- (ASLockSet)lockPair {
  ASLockSet lockSet = ASLockSequence(^BOOL(ASAddLockBlock addLock) {
    if (!addLock(_node)) {
      return NO;
    }
    if (!addLock(self)) {
      return NO;
    }
    return YES;
  });

  return lockSet;
}

#pragma mark NSLocking

- (void)lock
{
  __instanceLock__.lock();
}

- (void)unlock
{
  __instanceLock__.unlock();
}

- (BOOL)tryLock
{
  return __instanceLock__.try_lock();
}

@end

@implementation ASDisplayNode (ASNodeController)

- (ASNodeController *)nodeController
{
  return _weakNodeController ?: _strongNodeController;
}

@end
