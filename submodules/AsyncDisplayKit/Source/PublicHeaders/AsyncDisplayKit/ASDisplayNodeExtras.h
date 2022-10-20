//
//  ASDisplayNodeExtras.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

/**
 * Sets the debugName field for these nodes to the given symbol names, within the domain of "self.class"
 * For instance, in `MYButtonNode` if you call `ASSetDebugNames(self.titleNode, _countNode)` the debug names
 * for the nodes will be set to `MYButtonNode.titleNode` and `MYButtonNode.countNode`.
 */
#if DEBUG
  #define ASSetDebugName(node, format, ...) node.debugName = [NSString stringWithFormat:format, __VA_ARGS__]
  #define ASSetDebugNames(...) _ASSetDebugNames(self.class, @"" # __VA_ARGS__, __VA_ARGS__, nil)
#else
  #define ASSetDebugName(node, format, ...)
  #define ASSetDebugNames(...)
#endif

NS_ASSUME_NONNULL_BEGIN

/// For deallocation of objects on the main thread across multiple run loops.
AS_EXTERN void ASPerformMainThreadDeallocation(id _Nullable __strong * _Nonnull objectPtr);

// Because inline methods can't be extern'd and need to be part of the translation unit of code
// that compiles with them to actually inline, we both declare and define these in the header.
ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesVisible(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateVisible) == ASInterfaceStateVisible);
}

ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesDisplay(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateDisplay) == ASInterfaceStateDisplay);
}

ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesPreload(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStatePreload) == ASInterfaceStatePreload);
}

ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesMeasureLayout(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateMeasureLayout) == ASInterfaceStateMeasureLayout);
}

__unused static NSString * NSStringFromASInterfaceState(ASInterfaceState interfaceState)
{
  NSMutableArray *states = [NSMutableArray array];
  if (interfaceState == ASInterfaceStateNone) {
    [states addObject:@"No state"];
  }
  if (ASInterfaceStateIncludesMeasureLayout(interfaceState)) {
    [states addObject:@"MeasureLayout"];
  }
  if (ASInterfaceStateIncludesPreload(interfaceState)) {
    [states addObject:@"Preload"];
  }
  if (ASInterfaceStateIncludesDisplay(interfaceState)) {
    [states addObject:@"Display"];
  }
  if (ASInterfaceStateIncludesVisible(interfaceState)) {
    [states addObject:@"Visible"];
  }
  return [NSString stringWithFormat:@"{ %@ }", [states componentsJoinedByString:@" | "]];
}

#define INTERFACE_STATE_DELTA(Name) ({ \
  if ((oldState & ASInterfaceState##Name) != (newState & ASInterfaceState##Name)) { \
    [changes appendFormat:@"%c%s ", (newState & ASInterfaceState##Name ? '+' : '-'), #Name]; \
  } \
})

/// e.g. { +Visible, -Preload } (although that should never actually happen.)
/// NOTE: Changes to MeasureLayout state don't really mean anything so we omit them for now.
__unused static NSString *NSStringFromASInterfaceStateChange(ASInterfaceState oldState, ASInterfaceState newState)
{
  if (oldState == newState) {
    return @"{ }";
  }

  NSMutableString *changes = [NSMutableString stringWithString:@"{ "];
  INTERFACE_STATE_DELTA(Preload);
  INTERFACE_STATE_DELTA(Display);
  INTERFACE_STATE_DELTA(Visible);
  [changes appendString:@"}"];
  return changes;
}

#undef INTERFACE_STATE_DELTA

/**
 Returns the appropriate interface state for a given ASDisplayNode and window
 */
AS_EXTERN ASInterfaceState ASInterfaceStateForDisplayNode(ASDisplayNode *displayNode, UIWindow *window) AS_WARN_UNUSED_RESULT;

/**
 Given a layer, returns the associated display node, if any.
 */
AS_EXTERN ASDisplayNode * _Nullable ASLayerToDisplayNode(CALayer * _Nullable layer) AS_WARN_UNUSED_RESULT;

/**
 Given a view, returns the associated display node, if any.
 */
AS_EXTERN ASDisplayNode * _Nullable ASViewToDisplayNode(UIView * _Nullable view) AS_WARN_UNUSED_RESULT;

/**
 Given a node, returns the root of the node hierarchy (where supernode == nil)
 */
AS_EXTERN ASDisplayNode *ASDisplayNodeUltimateParentOfNode(ASDisplayNode *node) AS_WARN_UNUSED_RESULT;

/**
 If traverseSublayers == YES, this function will walk the layer hierarchy, spanning discontinuous sections of the node hierarchy\
 (e.g. the layers of UIKit intermediate views in UIViewControllers, UITableView, UICollectionView).
 In the event that a node's backing layer is not created yet, the function will only walk the direct subnodes instead
 of forcing the layer hierarchy to be created.
 */
AS_EXTERN void ASDisplayNodePerformBlockOnEveryNode(CALayer * _Nullable layer, ASDisplayNode * _Nullable node, BOOL traverseSublayers, void(^block)(ASDisplayNode *node));

/**
 This function will walk the node hierarchy in a breadth first fashion. It does run the block on the node provided
 directly to the function call.  It does NOT traverse sublayers.
 */
AS_EXTERN void ASDisplayNodePerformBlockOnEveryNodeBFS(ASDisplayNode *node, void(^block)(ASDisplayNode *node));

/**
 Identical to ASDisplayNodePerformBlockOnEveryNode, except it does not run the block on the
 node provided directly to the function call - only on all descendants.
 */
AS_EXTERN void ASDisplayNodePerformBlockOnEverySubnode(ASDisplayNode *node, BOOL traverseSublayers, void(^block)(ASDisplayNode *node));

/**
 Given a display node, traverses up the layer tree hierarchy, returning the first display node that passes block.
 */
AS_EXTERN ASDisplayNode * _Nullable ASDisplayNodeFindFirstSupernode(ASDisplayNode * _Nullable node, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use the `supernodes` property instead.");

/**
 Given a display node, traverses up the layer tree hierarchy, returning the first display node of kind class.
 */
AS_EXTERN __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstSupernodeOfClass(ASDisplayNode *start, Class c) AS_WARN_UNUSED_RESULT  ASDISPLAYNODE_DEPRECATED_MSG("Use the `supernodeOfClass:includingSelf:` method instead.");

/**
 * Given a layer, find the window it lives in, if any.
 */
AS_EXTERN UIWindow * _Nullable ASFindWindowOfLayer(CALayer *layer) AS_WARN_UNUSED_RESULT;

/**
 * Given a layer, find the closest view it lives in, if any.
 */
AS_EXTERN UIView * _Nullable ASFindClosestViewOfLayer(CALayer *layer) AS_WARN_UNUSED_RESULT;

/**
 * Given two nodes, finds their most immediate common parent.  Used for geometry conversion methods.
 * NOTE: It is an error to try to convert between nodes which do not share a common ancestor. This behavior is
 * disallowed in UIKit documentation and the behavior is left undefined. The output does not have a rigorously defined
 * failure mode (i.e. returning CGPointZero or returning the point exactly as passed in). Rather than track the internal
 * undefined and undocumented behavior of UIKit in ASDisplayNode, this operation is defined to be incorrect in all
 * circumstances and must be fixed wherever encountered.
 */
AS_EXTERN ASDisplayNode * _Nullable ASDisplayNodeFindClosestCommonAncestor(ASDisplayNode *node1, ASDisplayNode *node2) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, collects all descendants. This is a specialization of ASCollectContainer() that walks the Core Animation layer tree as opposed to the display node tree, thus supporting non-continues display node hierarchies.
 */
AS_EXTERN NSArray<ASDisplayNode *> *ASCollectDisplayNodes(ASDisplayNode *node) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning all the display nodes that pass the block.
 */
AS_EXTERN NSArray<ASDisplayNode *> *ASDisplayNodeFindAllSubnodes(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning all the display nodes of kind class.
 */
AS_EXTERN NSArray<__kindof ASDisplayNode *> *ASDisplayNodeFindAllSubnodesOfClass(ASDisplayNode *start, Class c) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node, including the start node that pass the block.
 */
AS_EXTERN __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstNode(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node, excluding the start node, that pass the block
 */
AS_EXTERN __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstSubnode(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node of kind class.
 */
AS_EXTERN __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstSubnodeOfClass(ASDisplayNode *start, Class c) AS_WARN_UNUSED_RESULT;

AS_EXTERN UIColor *ASDisplayNodeDefaultPlaceholderColor(void) AS_WARN_UNUSED_RESULT;
AS_EXTERN UIColor *ASDisplayNodeDefaultTintColor(void) AS_WARN_UNUSED_RESULT;

/**
 Disable willAppear / didAppear / didDisappear notifications for a sub-hierarchy, then re-enable when done. Nested calls are supported.
 */
AS_EXTERN void ASDisplayNodeDisableHierarchyNotifications(ASDisplayNode *node);
AS_EXTERN void ASDisplayNodeEnableHierarchyNotifications(ASDisplayNode *node);

// Not to be called directly.
AS_EXTERN void _ASSetDebugNames(Class owningClass, NSString *names, ASDisplayNode * _Nullable object, ...);

NS_ASSUME_NONNULL_END
