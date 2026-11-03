//
//  ASDisplayNodeExtras.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import "ASDisplayNodeInternal.h"
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Ancestry.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

#import <queue>
#import <AsyncDisplayKit/ASRunLoopQueue.h>

void ASPerformMainThreadDeallocation(id _Nullable __strong * _Nonnull objectPtr) {
  /**
   * UIKit components must be deallocated on the main thread. We use this shared
   * run loop queue to gradually deallocate them across many turns of the main run loop.
   */
  static ASRunLoopQueue *queue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queue = [[ASRunLoopQueue alloc] initWithRunLoop:CFRunLoopGetMain() retainObjects:YES handler:nil];
    queue.batchSize = 10;
  });

  if (objectPtr != NULL && *objectPtr != nil) {
    // TODO: If ASRunLoopQueue supported an "unsafe_unretained" mode, we could
    // transfer the caller's +1 into it and save the retain/release pair.
    
    // Lock queue while enqueuing and releasing, so that there's no risk
    // that the queue will release before we get a chance to release.
    [queue lock];
    [queue enqueue:*objectPtr];   // Retain, +1
    *objectPtr = nil;             // Release, +0
    [queue unlock];               // (After queue drains), release, -1
  }
}

void _ASSetDebugNames(Class _Nonnull owningClass, NSString * _Nonnull names, ASDisplayNode * _Nullable object, ...)
{
  NSString *owningClassName = NSStringFromClass(owningClass);
  NSArray *nameArray = [names componentsSeparatedByString:@", "];
  va_list args;
  va_start(args, object);
  NSInteger i = 0;
  for (ASDisplayNode *node = object; node != nil; node = va_arg(args, id), i++) {
    NSMutableString *symbolName = [nameArray[i] mutableCopy];
    // Remove any `self.` or `_` prefix
    [symbolName replaceOccurrencesOfString:@"self." withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, symbolName.length)];
    [symbolName replaceOccurrencesOfString:@"_" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, symbolName.length)];
    node.debugName = [NSString stringWithFormat:@"%@.%@", owningClassName, symbolName];
  }
  ASDisplayNodeCAssert(nameArray.count == i, @"Malformed call to ASSetDebugNames: %@", names);
  va_end(args);
}

ASInterfaceState ASInterfaceStateForDisplayNode(ASDisplayNode *displayNode, UIWindow *window)
{
    ASDisplayNodeCAssert(![displayNode isLayerBacked], @"displayNode must not be layer backed as it may have a nil window");
    if (displayNode && [displayNode supportsRangeManagedInterfaceState]) {
        // Directly clear the visible bit if we are not in a window. This means that the interface state is,
        // if not already, about to be set to invisible as it is not possible for an element to be visible
        // while outside of a window.
        ASInterfaceState interfaceState = displayNode.pendingInterfaceState;
        return (window == nil ? (interfaceState &= (~ASInterfaceStateVisible)) : interfaceState);
    } else {
        // For not range managed nodes we might be on our own to try to guess if we're visible.
        return (window == nil ? ASInterfaceStateNone : (ASInterfaceStateVisible | ASInterfaceStateDisplay));
    }
}

ASDisplayNode *ASLayerToDisplayNode(CALayer *layer)
{
  return layer.asyncdisplaykit_node;
}

ASDisplayNode *ASViewToDisplayNode(UIView *view)
{
  return view.asyncdisplaykit_node;
}

void ASDisplayNodePerformBlockOnEveryNode(CALayer * _Nullable layer, ASDisplayNode * _Nullable node, BOOL traverseSublayers, void(^block)(ASDisplayNode *node))
{
  if (!node) {
    ASDisplayNodeCAssertNotNil(layer, @"Cannot recursively perform with nil node and nil layer");
    ASDisplayNodeCAssertMainThread();
    node = ASLayerToDisplayNode(layer);
  }
  
  if (node) {
    block(node);
  }
  if (traverseSublayers && !layer && [node isNodeLoaded] && ASDisplayNodeThreadIsMain()) {
    layer = node.layer;
  }
  
  if (traverseSublayers && layer && node.rasterizesSubtree == NO) {
    /// NOTE: The docs say `sublayers` returns a copy, but it does not.
    /// See: http://stackoverflow.com/questions/14854480/collection-calayerarray-0x1ed8faa0-was-mutated-while-being-enumerated
    for (CALayer *sublayer in [[layer sublayers] copy]) {
      ASDisplayNodePerformBlockOnEveryNode(sublayer, nil, traverseSublayers, block);
    }
  } else if (node) {
    for (ASDisplayNode *subnode in [node subnodes]) {
      ASDisplayNodePerformBlockOnEveryNode(nil, subnode, traverseSublayers, block);
    }
  }
}

void ASDisplayNodePerformBlockOnEveryNodeBFS(ASDisplayNode *node, void(^block)(ASDisplayNode *node))
{
  // Queue used to keep track of subnodes while traversing this layout in a BFS fashion.
  std::queue<ASDisplayNode *> queue;
  queue.push(node);
  
  while (!queue.empty()) {
    node = queue.front();
    queue.pop();
    
    block(node);

    // Add all subnodes to process in next step
    for (ASDisplayNode *subnode in node.subnodes) {
      queue.push(subnode);
    }
  }
}

void ASDisplayNodePerformBlockOnEverySubnode(ASDisplayNode *node, BOOL traverseSublayers, void(^block)(ASDisplayNode *node))
{
  for (ASDisplayNode *subnode in node.subnodes) {
    ASDisplayNodePerformBlockOnEveryNode(nil, subnode, YES, block);
  }
}

ASDisplayNode *ASDisplayNodeFindFirstSupernode(ASDisplayNode *node, BOOL (^block)(ASDisplayNode *node))
{
  // This function has historically started with `self` but the name suggests
  // that it wouldn't. Perhaps we should change the behavior.
  for (ASDisplayNode *ancestor in node.supernodesIncludingSelf) {
    if (block(ancestor)) {
      return ancestor;
    }
  }
  return nil;
}

__kindof ASDisplayNode *ASDisplayNodeFindFirstSupernodeOfClass(ASDisplayNode *start, Class c)
{
  // This function has historically started with `self` but the name suggests
  // that it wouldn't. Perhaps we should change the behavior.
  return [start supernodeOfClass:c includingSelf:YES];
}

static void _ASCollectDisplayNodes(NSMutableArray *array, CALayer *layer)
{
  ASDisplayNode *node = ASLayerToDisplayNode(layer);

  if (nil != node) {
    [array addObject:node];
  }

  for (CALayer *sublayer in layer.sublayers)
    _ASCollectDisplayNodes(array, sublayer);
}

NSArray<ASDisplayNode *> *ASCollectDisplayNodes(ASDisplayNode *node)
{
  NSMutableArray *list = [[NSMutableArray alloc] init];
  for (CALayer *sublayer in node.layer.sublayers) {
    _ASCollectDisplayNodes(list, sublayer);
  }
  return list;
}

#pragma mark - Find all subnodes

static void _ASDisplayNodeFindAllSubnodes(NSMutableArray *array, ASDisplayNode *node, BOOL (^block)(ASDisplayNode *node))
{
  if (!node)
    return;

  for (ASDisplayNode *subnode in node.subnodes) {
    if (block(subnode)) {
      [array addObject:subnode];
    }

    _ASDisplayNodeFindAllSubnodes(array, subnode, block);
  }
}

NSArray<ASDisplayNode *> *ASDisplayNodeFindAllSubnodes(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node))
{
  NSMutableArray *list = [[NSMutableArray alloc] init];
  _ASDisplayNodeFindAllSubnodes(list, start, block);
  return list;
}

NSArray<__kindof ASDisplayNode *> *ASDisplayNodeFindAllSubnodesOfClass(ASDisplayNode *start, Class c)
{
  return ASDisplayNodeFindAllSubnodes(start, ^(ASDisplayNode *n) {
    return [n isKindOfClass:c];
  });
}

#pragma mark - Find first subnode

static ASDisplayNode *_ASDisplayNodeFindFirstNode(ASDisplayNode *startNode, BOOL includeStartNode, BOOL (^block)(ASDisplayNode *node))
{
  for (ASDisplayNode *subnode in startNode.subnodes) {
    ASDisplayNode *foundNode = _ASDisplayNodeFindFirstNode(subnode, YES, block);
    if (foundNode) {
      return foundNode;
    }
  }

  if (includeStartNode && block(startNode))
    return startNode;

  return nil;
}

__kindof ASDisplayNode *ASDisplayNodeFindFirstNode(ASDisplayNode *startNode, BOOL (^block)(ASDisplayNode *node))
{
  return _ASDisplayNodeFindFirstNode(startNode, YES, block);
}

__kindof ASDisplayNode *ASDisplayNodeFindFirstSubnode(ASDisplayNode *startNode, BOOL (^block)(ASDisplayNode *node))
{
  return _ASDisplayNodeFindFirstNode(startNode, NO, block);
}

__kindof ASDisplayNode *ASDisplayNodeFindFirstSubnodeOfClass(ASDisplayNode *start, Class c)
{
  return ASDisplayNodeFindFirstSubnode(start, ^(ASDisplayNode *n) {
    return [n isKindOfClass:c];
  });
}

static inline BOOL _ASDisplayNodeIsAncestorOfDisplayNode(ASDisplayNode *possibleAncestor, ASDisplayNode *possibleDescendant)
{
  ASDisplayNode *supernode = possibleDescendant;
  while (supernode) {
    if (supernode == possibleAncestor) {
      return YES;
    }
    supernode = supernode.supernode;
  }
  
  return NO;
}

UIWindow * _Nullable ASFindWindowOfLayer(CALayer *layer)
{
  UIView *view = ASFindClosestViewOfLayer(layer);
  if (UIWindow *window = ASDynamicCast(view, UIWindow)) {
    return window;
  } else {
    return view.window;
  }
}

UIView * _Nullable ASFindClosestViewOfLayer(CALayer *layer)
{
  while (layer != nil) {
    if (UIView *view = ASDynamicCast(layer.delegate, UIView)) {
      return view;
    }
    layer = layer.superlayer;
  }
  return nil;
}

ASDisplayNode *ASDisplayNodeFindClosestCommonAncestor(ASDisplayNode *node1, ASDisplayNode *node2)
{
  ASDisplayNode *possibleAncestor = node1;
  while (possibleAncestor) {
    if (_ASDisplayNodeIsAncestorOfDisplayNode(possibleAncestor, node2)) {
      break;
    }
    possibleAncestor = possibleAncestor.supernode;
  }
  
  ASDisplayNodeCAssertNotNil(possibleAncestor, @"Could not find a common ancestor between node1: %@ and node2: %@", node1, node2);
  return possibleAncestor;
}

ASDisplayNode *ASDisplayNodeUltimateParentOfNode(ASDisplayNode *node)
{
  // node <- supernode on each loop
  // previous <- node on each loop where node is not nil
  // previous is the final non-nil value of supernode, i.e. the root node
  ASDisplayNode *previousNode = node;
  while ((node = [node supernode])) {
    previousNode = node;
  }
  return previousNode;
}

#pragma mark - Placeholders

UIColor *ASDisplayNodeDefaultPlaceholderColor()
{
  static UIColor *defaultPlaceholderColor;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultPlaceholderColor = [UIColor colorWithWhite:0.95 alpha:1.0];
  });
  return defaultPlaceholderColor;
}

UIColor *ASDisplayNodeDefaultTintColor()
{
  static UIColor *defaultTintColor;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultTintColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
  });
  return defaultTintColor;
}

#pragma mark - Hierarchy Notifications

void ASDisplayNodeDisableHierarchyNotifications(ASDisplayNode *node)
{
  [node __incrementVisibilityNotificationsDisabled];
}

void ASDisplayNodeEnableHierarchyNotifications(ASDisplayNode *node)
{
  [node __decrementVisibilityNotificationsDisabled];
}
