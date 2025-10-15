//
//  _ASDisplayViewAccessiblity.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef ASDK_ACCESSIBILITY_DISABLE

#import <AsyncDisplayKit/_ASDisplayView.h>
#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import "ASDisplayNodeInternal.h"

#import <queue>

NS_INLINE UIAccessibilityTraits InteractiveAccessibilityTraitsMask() {
  return UIAccessibilityTraitLink | UIAccessibilityTraitKeyboardKey | UIAccessibilityTraitButton;
}

#pragma mark - UIAccessibilityElement

@protocol ASAccessibilityElementPositioning

@property (nonatomic, readonly) CGRect accessibilityFrame;

@end

typedef NSComparisonResult (^SortAccessibilityElementsComparator)(id<ASAccessibilityElementPositioning>, id<ASAccessibilityElementPositioning>);

/// Sort accessiblity elements first by y and than by x origin.
static void SortAccessibilityElements(NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");
  
  static SortAccessibilityElementsComparator comparator = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      comparator = ^NSComparisonResult(id<ASAccessibilityElementPositioning> a, id<ASAccessibilityElementPositioning> b) {
        CGPoint originA = a.accessibilityFrame.origin;
        CGPoint originB = b.accessibilityFrame.origin;
        if (originA.y == originB.y) {
          if (originA.x == originB.x) {
            return NSOrderedSame;
          }
          return (originA.x < originB.x) ? NSOrderedAscending : NSOrderedDescending;
        }
        return (originA.y < originB.y) ? NSOrderedAscending : NSOrderedDescending;
      };
  });
  [elements sortUsingComparator:comparator];
}

@interface ASAccessibilityElement : UIAccessibilityElement<ASAccessibilityElementPositioning>

@property (nonatomic) ASDisplayNode *node;
@property (nonatomic) ASDisplayNode *containerNode;

+ (ASAccessibilityElement *)accessibilityElementWithContainer:(UIView *)container node:(ASDisplayNode *)node containerNode:(ASDisplayNode *)containerNode;

@end

@implementation ASAccessibilityElement

+ (ASAccessibilityElement *)accessibilityElementWithContainer:(UIView *)container node:(ASDisplayNode *)node containerNode:(ASDisplayNode *)containerNode
{
  ASAccessibilityElement *accessibilityElement = [[ASAccessibilityElement alloc] initWithAccessibilityContainer:container];
  accessibilityElement.node = node;
  accessibilityElement.containerNode = containerNode;
  accessibilityElement.accessibilityIdentifier = node.accessibilityIdentifier;
  accessibilityElement.accessibilityLabel = node.accessibilityLabel;
  accessibilityElement.accessibilityHint = node.accessibilityHint;
  accessibilityElement.accessibilityValue = node.accessibilityValue;
  accessibilityElement.accessibilityTraits = node.accessibilityTraits;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0
  if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
    accessibilityElement.accessibilityAttributedLabel = node.accessibilityAttributedLabel;
    accessibilityElement.accessibilityAttributedHint = node.accessibilityAttributedHint;
    accessibilityElement.accessibilityAttributedValue = node.accessibilityAttributedValue;
  }
#endif
  return accessibilityElement;
}

- (CGRect)accessibilityFrame
{
  CGRect accessibilityFrame = [self.containerNode convertRect:self.node.bounds fromNode:self.node];
  accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(accessibilityFrame, self.accessibilityContainer);
  return accessibilityFrame;
}

@end

#pragma mark - _ASDisplayView / UIAccessibilityContainer

@interface ASAccessibilityCustomAction : UIAccessibilityCustomAction<ASAccessibilityElementPositioning>

@property (nonatomic) UIView *container;
@property (nonatomic) ASDisplayNode *node;
@property (nonatomic) ASDisplayNode *containerNode;

@end

@implementation ASAccessibilityCustomAction

- (CGRect)accessibilityFrame
{
  CGRect accessibilityFrame = [self.containerNode convertRect:self.node.bounds fromNode:self.node];
  accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(accessibilityFrame, self.container);
  return accessibilityFrame;
}

@end

/// Collect all subnodes for the given node by walking down the subnode tree and calculates the screen coordinates based on the containerNode and container
static void CollectUIAccessibilityElementsForNode(ASDisplayNode *node, ASDisplayNode *containerNode, id container, NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");
  
  ASDisplayNodePerformBlockOnEveryNodeBFS(node, ^(ASDisplayNode * _Nonnull currentNode) {
    // For every subnode that is layer backed or it's supernode has subtree rasterization enabled
    // we have to create a UIAccessibilityElement as no view for this node exists
    if (currentNode != containerNode && currentNode.isAccessibilityElement) {
      UIAccessibilityElement *accessibilityElement = [ASAccessibilityElement accessibilityElementWithContainer:container node:currentNode containerNode:containerNode];
      [elements addObject:accessibilityElement];
    }
  });
}

static void CollectAccessibilityElementsForContainer(ASDisplayNode *container, UIView *view, NSMutableArray *elements) {
  UIAccessibilityElement *accessiblityElement = [ASAccessibilityElement accessibilityElementWithContainer:view node:container containerNode:container];

  NSMutableArray<ASAccessibilityElement *> *labeledNodes = [[NSMutableArray alloc] init];
  NSMutableArray<ASAccessibilityCustomAction *> *actions = [[NSMutableArray alloc] init];
  std::queue<ASDisplayNode *> queue;
  queue.push(container);

  // If the container does not have an accessibility label set, or if the label is meant for custom
  // actions only, then aggregate its subnodes' labels. Otherwise, treat the label as an overriden
  // value and do not perform the aggregation.
  BOOL shouldAggregateSubnodeLabels =
      (container.accessibilityLabel.length == 0) ||
      (container.accessibilityTraits & InteractiveAccessibilityTraitsMask());

  ASDisplayNode *node = nil;
  while (!queue.empty()) {
    node = queue.front();
    queue.pop();

    if (node != container && node.isAccessibilityContainer) {
      CollectAccessibilityElementsForContainer(node, view, elements);
      continue;
    }

    if (node.accessibilityLabel.length > 0) {
      if (node.accessibilityTraits & InteractiveAccessibilityTraitsMask()) {
        ASAccessibilityCustomAction *action = [[ASAccessibilityCustomAction alloc] initWithName:node.accessibilityLabel target:node selector:@selector(performAccessibilityCustomAction:)];
        action.node = node;
        action.containerNode = node.supernode;
        action.container = node.supernode.view;
        [actions addObject:action];
      } else if (node == container || shouldAggregateSubnodeLabels) {
        // Even though not surfaced to UIKit, create a non-interactive element for purposes of building sorted aggregated label.
        ASAccessibilityElement *nonInteractiveElement = [ASAccessibilityElement accessibilityElementWithContainer:view node:node containerNode:container];
        [labeledNodes addObject:nonInteractiveElement];
      }
    }

    for (ASDisplayNode *subnode in node.subnodes) {
      queue.push(subnode);
    }
  }

  SortAccessibilityElements(labeledNodes);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0
  if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
    NSArray *attributedLabels = [labeledNodes valueForKey:@"accessibilityAttributedLabel"];
    NSMutableAttributedString *attributedLabel = [NSMutableAttributedString new];
    [attributedLabels enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      if (idx != 0) {
        [attributedLabel appendAttributedString:[[NSAttributedString alloc] initWithString:@", "]];
      }
      [attributedLabel appendAttributedString:(NSAttributedString *)obj];
    }];
    accessiblityElement.accessibilityAttributedLabel = attributedLabel;
  } else
#endif
  {
    NSArray *labels = [labeledNodes valueForKey:@"accessibilityLabel"];
    accessiblityElement.accessibilityLabel = [labels componentsJoinedByString:@", "];
  }

  SortAccessibilityElements(actions);
  accessiblityElement.accessibilityCustomActions = actions;

  [elements addObject:accessiblityElement];
}

/// Collect all accessibliity elements for a given view and view node
static void CollectAccessibilityElementsForView(UIView *view, NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");
  
  ASDisplayNode *node = view.asyncdisplaykit_node;

  static Class displayListViewClass = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    displayListViewClass = NSClassFromString(@"Display.ListView");
  });
  BOOL anySubNodeIsCollection = (nil != ASDisplayNodeFindFirstNode(node,
      ^BOOL(ASDisplayNode *nodeToCheck) {
        if (displayListViewClass != nil && [nodeToCheck isKindOfClass:displayListViewClass]) {
          return true;
        }
    return false;
    /*return ASDynamicCast(nodeToCheck, ASCollectionNode) != nil ||
           ASDynamicCast(nodeToCheck, ASTableNode) != nil;*/
  }));

  if (node.isAccessibilityContainer && !anySubNodeIsCollection) {
    CollectAccessibilityElementsForContainer(node, view, elements);
    return;
  }
  
  // Handle rasterize case
  if (node.rasterizesSubtree) {
    CollectUIAccessibilityElementsForNode(node, node, view, elements);
    return;
  }
  
  for (ASDisplayNode *subnode in node.subnodes) {
    if (subnode.isAccessibilityElement) {
      
      // An accessiblityElement can either be a UIView or a UIAccessibilityElement
      if (subnode.isLayerBacked) {
        // No view for layer backed nodes exist. It's necessary to create a UIAccessibilityElement that represents this node
        UIAccessibilityElement *accessiblityElement = [ASAccessibilityElement accessibilityElementWithContainer:view node:subnode containerNode:node];
        [elements addObject:accessiblityElement];
      } else {
        // Accessiblity element is not layer backed just add the view as accessibility element
        [elements addObject:subnode.view];
      }
    } else if (subnode.isLayerBacked) {
      // Go down the hierarchy of the layer backed subnode and collect all of the UIAccessibilityElement
      CollectUIAccessibilityElementsForNode(subnode, node, view, elements);
    } else if ([subnode accessibilityElementCount] > 0) {
      // UIView is itself a UIAccessibilityContainer just add it
      [elements addObject:subnode.view];
    }
  }
}

@interface _ASDisplayView () {
  NSArray *_accessibilityElements;
}

@end

@implementation _ASDisplayView (UIAccessibilityContainer)

- (void)accessibilityElementDidBecomeFocused {
  ASDisplayNode *viewNode = self.asyncdisplaykit_node;
  if ([viewNode respondsToSelector:@selector(accessibilityElementDidBecomeFocused)]) {
    [viewNode accessibilityElementDidBecomeFocused];
  }
}

/*- (bool)accessibilityActivate {
  ASDisplayNode *viewNode = self.asyncdisplaykit_node;
  if ([viewNode respondsToSelector:@selector(accessibilityActivate)]) {
    return [viewNode accessibilityActivate];
  }
  return false;
}*/

#pragma mark - UIAccessibility

- (void)setAccessibilityElements:(NSArray *)accessibilityElements
{
  ASDisplayNodeAssertMainThread();
  _accessibilityElements = nil;
}

- (NSArray *)accessibilityElements
{
  ASDisplayNodeAssertMainThread();
  
  ASDisplayNode *viewNode = self.asyncdisplaykit_node;
  if (viewNode == nil) {
    return @[];
  }
  _accessibilityElements = [viewNode accessibilityElements];
  return _accessibilityElements;
}

@end

@implementation ASDisplayNode (AccessibilityInternal)

- (NSArray *)accessibilityElements
{
  if (!self.isNodeLoaded) {
    ASDisplayNodeFailAssert(@"Cannot access accessibilityElements since node is not loaded");
    return @[];
  }
  NSMutableArray *accessibilityElements = [[NSMutableArray alloc] init];
  CollectAccessibilityElementsForView(self.view, accessibilityElements);
  SortAccessibilityElements(accessibilityElements);
  return accessibilityElements;
}

@end

@implementation _ASDisplayView (UIAccessibilityAction)

- (BOOL)accessibilityActivate {
  return [self.asyncdisplaykit_node accessibilityActivate];
}

- (void)accessibilityIncrement {
  [self.asyncdisplaykit_node accessibilityIncrement];
}

- (void)accessibilityDecrement {
  [self.asyncdisplaykit_node accessibilityDecrement];
}

- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction {
  return [self.asyncdisplaykit_node accessibilityScroll:direction];
}

- (BOOL)accessibilityPerformEscape {
  return [self.asyncdisplaykit_node accessibilityPerformEscape];
}

- (BOOL)accessibilityPerformMagicTap {
  return [self.asyncdisplaykit_node accessibilityPerformMagicTap];
}

@end

#endif
