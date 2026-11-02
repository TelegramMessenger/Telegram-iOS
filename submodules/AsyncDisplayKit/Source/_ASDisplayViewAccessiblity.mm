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

#import <objc/runtime.h>
#import <algorithm>
#import <queue>
#import <vector>

// How a node's view answers `accessibilityElements` (the order UIKit asks in):
//
// 1. An array set explicitly on the view (`setAccessibilityElements:`) is returned as is.
// 2. If the node or any ancestor view's node sets `accessibilityUsesViewElements`, UIKit's own behaviour
//    (`[super accessibilityElements]`, i.e. UIKit's subview traversal).
// 3. Otherwise the node's `accessibilityElements`: a subclass override is used as is (unsorted; nil falls back to
//    UIKit's behaviour), the default implementation is the collector below, sorted by frame.
//
// The answer is cached on the node for one main run loop turn (`ASAccessibilityGeneration`, bumped before the main
// run loop waits), so UIKit's `accessibilityElementCount` / `accessibilityElementAtIndex:` /
// `indexOfAccessibilityElement:` share one collection. Each collection is one level deep (child containers are
// listed, not walked), so a client walking the whole tree costs one pass over it. Nothing runs until UIKit (an
// accessibility client) asks: the run loop observer is installed on first use.
//
// The collector exposes only what can be seen: it skips hidden, alpha < 0.01 and `accessibilityElementsHidden`
// subtrees, and elements (and clipping containers) that are zero-size or do not intersect the visible rect, which is
// the window intersected with every clipping ancestor (`clipsToBounds` or a scroll view). ListView is the one
// exception: the rows inside its bounds plus the nearest already-loaded row beyond each edge (`AddListViewEdgeRows`),
// so VoiceOver's swipe reaches the next row and focusing it scrolls it in; three-finger scroll goes through ListView's
// own `accessibilityScroll:`.

NS_INLINE UIAccessibilityTraits InteractiveAccessibilityTraitsMask() {
  return UIAccessibilityTraitLink | UIAccessibilityTraitKeyboardKey | UIAccessibilityTraitButton;
}

#pragma mark - Run loop generation

static NSUInteger ASAccessibilityGeneration = 1;

static NSUInteger ASAccessibilityCurrentGeneration(void)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
      ASAccessibilityGeneration += 1;
    });
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);
  });
  return ASAccessibilityGeneration;
}

#pragma mark - Sorting

/// Sort accessibility elements first by y and then by x origin (stable; each frame is computed once).
static void SortAccessibilityElements(NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");
  NSUInteger count = elements.count;
  if (count < 2) {
    return;
  }
  struct Key {
    CGPoint origin;
    NSUInteger index;
  };
  std::vector<Key> keys;
  keys.reserve(count);
  for (NSUInteger i = 0; i < count; i++) {
    id element = elements[i];
    CGRect frame;
    if ([element isKindOfClass:[UIView class]]) {
      // From the geometry, unclipped: UIKit's `accessibilityFrame` (and UIAccessibilityConvertFrameToScreenCoordinates)
      // of a view outside the window (ListView's edge rows) is null, which would sort it last.
      UIView *view = (UIView *)element;
      UIScreen *screen = view.window.screen;
      frame = (screen != nil) ? [view convertRect:view.bounds toCoordinateSpace:screen.coordinateSpace] : [view convertRect:view.bounds toView:nil];
    } else {
      frame = [(NSObject *)element accessibilityFrame];
    }
    keys.push_back({ frame.origin, i });
  }
  std::stable_sort(keys.begin(), keys.end(), [](const Key &a, const Key &b) {
    if (a.origin.y != b.origin.y) {
      return a.origin.y < b.origin.y;
    }
    return a.origin.x < b.origin.x;
  });
  NSMutableArray *sorted = [[NSMutableArray alloc] initWithCapacity:count];
  for (const Key &key : keys) {
    [sorted addObject:elements[key.index]];
  }
  [elements setArray:sorted];
}

#pragma mark - UIAccessibilityElement

@interface ASAccessibilityElement : UIAccessibilityElement

// Weak: the node keeps its reusable element (`ASAccessibilityElementForNode`), and the tree owns the nodes.
@property (nonatomic, weak) ASDisplayNode *node;
@property (nonatomic, weak) ASDisplayNode *containerNode;

+ (ASAccessibilityElement *)accessibilityElementWithContainer:(UIView *)container node:(ASDisplayNode *)node containerNode:(ASDisplayNode *)containerNode;

@end

@implementation ASAccessibilityElement

+ (ASAccessibilityElement *)accessibilityElementWithContainer:(UIView *)container node:(ASDisplayNode *)node containerNode:(ASDisplayNode *)containerNode
{
  ASAccessibilityElement *accessibilityElement = [[ASAccessibilityElement alloc] initWithAccessibilityContainer:container];
  accessibilityElement.node = node;
  accessibilityElement.containerNode = containerNode;
  [accessibilityElement updateFromNode];
  return accessibilityElement;
}

- (void)updateFromNode
{
  ASDisplayNode *node = self.node;
  self.accessibilityIdentifier = node.accessibilityIdentifier;
  self.accessibilityLabel = node.accessibilityLabel;
  self.accessibilityHint = node.accessibilityHint;
  self.accessibilityValue = node.accessibilityValue;
  self.accessibilityTraits = node.accessibilityTraits;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0
  if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
    self.accessibilityAttributedLabel = node.accessibilityAttributedLabel;
    self.accessibilityAttributedHint = node.accessibilityAttributedHint;
    self.accessibilityAttributedValue = node.accessibilityAttributedValue;
  }
#endif
}

- (CGRect)accessibilityFrame
{
  CGRect accessibilityFrame = [self.containerNode convertRect:self.node.bounds fromNode:self.node];
  accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(accessibilityFrame, self.accessibilityContainer);
  return accessibilityFrame;
}

- (BOOL)accessibilityActivate
{
  return [self.node accessibilityActivate];
}

- (void)accessibilityIncrement
{
  [self.node accessibilityIncrement];
}

- (void)accessibilityDecrement
{
  [self.node accessibilityDecrement];
}

@end

static const void *ASAccessibilityElementProxyKey = &ASAccessibilityElementProxyKey;

/// The element standing in for a layer-backed (or rasterized) accessible node. Kept on the node and reused while the
/// container stays the same, so VoiceOver sees the same object across queries and keeps its focus on it.
static ASAccessibilityElement *ASAccessibilityElementForNode(ASDisplayNode *node, ASDisplayNode *containerNode, UIView *container)
{
  ASAccessibilityElement *element = objc_getAssociatedObject(node, ASAccessibilityElementProxyKey);
  if (element != nil && element.accessibilityContainer == container && element.containerNode == containerNode) {
    [element updateFromNode];
    return element;
  }
  element = [ASAccessibilityElement accessibilityElementWithContainer:container node:node containerNode:containerNode];
  objc_setAssociatedObject(node, ASAccessibilityElementProxyKey, element, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  return element;
}

#pragma mark - _ASDisplayView / UIAccessibilityContainer

@interface ASAccessibilityCustomAction : UIAccessibilityCustomAction

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

#pragma mark - Visibility

/// Whether a rect (in the container's coordinates) has a visible area inside `visibleRect`.
NS_INLINE BOOL ASAccessibilityRectIsVisible(CGRect rect, CGRect visibleRect)
{
  if (rect.size.width <= 0.0 || rect.size.height <= 0.0) {
    return NO;
  }
  return !CGRectIsEmpty(CGRectIntersection(rect, visibleRect));
}

/// The part of `view` (in its own coordinates) that can be on screen: the window intersected with every clipping
/// ancestor (`clipsToBounds` views, including `view` itself, and scroll views). CGRectInfinite when nothing clips.
static CGRect ASAccessibilityVisibleRectInView(UIView *view)
{
  CGRect rect = CGRectInfinite;
  UIWindow *window = view.window;
  for (UIView *ancestor = view; ancestor != nil; ancestor = ancestor.superview) {
    if (ancestor == window || ancestor.clipsToBounds || [ancestor isKindOfClass:[UIScrollView class]]) {
      CGRect ancestorBounds = (ancestor == view) ? view.bounds : [ancestor convertRect:ancestor.bounds toView:view];
      rect = CGRectIntersection(rect, ancestorBounds);
      if (CGRectIsEmpty(rect)) {
        return CGRectNull;
      }
    }
  }
  return rect;
}

NS_INLINE BOOL ASAccessibilityViewIsShown(UIView *view)
{
  return !view.hidden && view.alpha >= 0.01 && !view.accessibilityElementsHidden;
}

NS_INLINE BOOL ASAccessibilityNodeIsShown(ASDisplayNode *node)
{
  return !node.isHidden && node.alpha >= 0.01 && !node.accessibilityElementsHidden;
}

#pragma mark - Opt-out

static BOOL ASAccessibilityViewUsesViewElements(UIView *view)
{
  for (UIView *current = view; current != nil; current = current.superview) {
    ASDisplayNode *node = current.asyncdisplaykit_node;
    if (node != nil && node->_accessibilityUsesViewElements) {
      return YES;
    }
  }
  return NO;
}

#pragma mark - Cache

/// Cached in place of nil ("UIKit's own behaviour"); compared by identity.
static NSArray *ASAccessibilityUsesViewElementsMarker(void)
{
  static NSArray *marker = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    marker = [[NSMutableArray alloc] init];
  });
  return marker;
}

/// What the node's view answers, or nil for UIKit's own behaviour. Cached for the current main run loop turn.
NSArray *ASDisplayNodeCachedAccessibilityElements(ASDisplayNode *node)
{
  ASDisplayNodeCAssertMainThread();
  if (node == nil || !node.isNodeLoaded) {
    return nil;
  }
  NSUInteger generation = ASAccessibilityCurrentGeneration();
  if (node->_accessibilityElementsCacheGeneration == generation) {
    NSArray *cached = node->_accessibilityElementsCache;
    return (cached == ASAccessibilityUsesViewElementsMarker()) ? nil : cached;
  }
  NSArray *elements = nil;
  if (!ASAccessibilityViewUsesViewElements(node.view)) {
    elements = [node accessibilityElements];
  }
  node->_accessibilityElementsCache = elements ?: ASAccessibilityUsesViewElementsMarker();
  node->_accessibilityElementsCacheGeneration = generation;
  return elements;
}

#pragma mark - Collection

/// Collect the accessible nodes of a layer-backed (or rasterized) subtree rooted at `root`, as elements of
/// `container` (the view of `containerNode`). `visibleRect` is in the container's coordinates.
static void CollectLayerBackedAccessibilityElements(ASDisplayNode *root, ASDisplayNode *containerNode, UIView *container, CGRect visibleRect, NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");

  std::queue<std::pair<ASDisplayNode *, CGRect>> queue;
  queue.push({ root, visibleRect });
  while (!queue.empty()) {
    ASDisplayNode *node = queue.front().first;
    CGRect rect = queue.front().second;
    queue.pop();

    if (node != containerNode) {
      if (!ASAccessibilityNodeIsShown(node)) {
        continue;
      }
      CGRect frame = [containerNode convertRect:node.bounds fromNode:node];
      if (node.isAccessibilityElement) {
        if (ASAccessibilityRectIsVisible(frame, rect)) {
          [elements addObject:ASAccessibilityElementForNode(node, containerNode, container)];
        }
        continue;
      }
      if (node.clipsToBounds) {
        rect = CGRectIntersection(rect, frame);
        if (CGRectIsEmpty(rect)) {
          continue;
        }
      }
    }
    for (ASDisplayNode *subnode in node.subnodes) {
      queue.push({ subnode, rect });
    }
  }
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

    if (node != container && !ASAccessibilityNodeIsShown(node)) {
      continue;
    }

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

static BOOL ASAccessibilityNodeIsListView(ASDisplayNode *node)
{
  static Class displayListViewClass = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // `Display.ListView` is a protocol now; the node class is `ListViewImpl`.
    displayListViewClass = NSClassFromString(@"Display.ListViewImpl");
  });
  return displayListViewClass != nil && [node isKindOfClass:displayListViewClass];
}

static void AddPlainSubview(UIView *subview, UIView *view, CGRect visibleRect, NSMutableArray *elements);

/// A view-backed subnode's view goes in the list when it is a visible element, or a container that is shown.
static void AddViewBackedSubnode(ASDisplayNode *subnode, UIView *subview, UIView *view, CGRect visibleRect, NSMutableArray *elements)
{
  if (![subview isKindOfClass:[_ASDisplayView class]]) {
    // A node with a custom view (a UIKit control, ListView's backing view): UIKit asks that view itself, and it
    // answers with its own behaviour, so it is kept like a plain view.
    AddPlainSubview(subview, view, visibleRect, elements);
    return;
  }
  if (!ASAccessibilityViewIsShown(subview)) {
    return;
  }
  CGRect frame = [subview convertRect:subview.bounds toView:view];
  if (subnode.isAccessibilityElement) {
    if (ASAccessibilityRectIsVisible(frame, visibleRect)) {
      [elements addObject:subview];
    }
    return;
  }
  // A container that does not clip can show children outside its own frame, so only clipping containers are
  // culled by their frame; the others are culled by having no visible elements.
  if (subview.clipsToBounds && !ASAccessibilityRectIsVisible(frame, visibleRect)) {
    return;
  }
  // A container is added without asking for its own elements: each view's collection stays one level deep, so a
  // client walking the tree over many run loop turns (the cache lasts one) costs one pass, not a re-walk of every
  // subtree per level. An empty container contributes nothing to the tree.
  [elements addObject:subview];
}

static void AddPlainSubview(UIView *subview, UIView *view, CGRect visibleRect, NSMutableArray *elements)
{
  if (!ASAccessibilityViewIsShown(subview)) {
    return;
  }
  CGRect frame = [subview convertRect:subview.bounds toView:view];
  if (subview.isAccessibilityElement) {
    if (ASAccessibilityRectIsVisible(frame, visibleRect)) {
      [elements addObject:subview];
    }
    return;
  }
  if (subview.clipsToBounds && !ASAccessibilityRectIsVisible(frame, visibleRect)) {
    return;
  }
  // A plain container (ComponentFlow views among them): UIKit walks it when it reaches it.
  if (subview.subviews.count > 0 || [subview accessibilityElementCount] > 0) {
    [elements addObject:subview];
  }
}

/// ListView's exception to the visibility rule, as UITableView does: besides the rows inside its bounds, the nearest
/// already-loaded row beyond each edge, so VoiceOver's swipe reaches it and focusing it scrolls it into view
/// (`ListViewItemNode.accessibilityElementDidBecomeFocused` → `ensureItemNodeVisible`). Only rows ListView already has
/// nodes for; nothing is loaded for this.
static void AddListViewEdgeRows(UIView *view, CGRect visibleRect, NSMutableArray *elements)
{
  static Class itemNodeClass = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    itemNodeClass = NSClassFromString(@"Display.ListViewItemNode");
  });
  if (itemNodeClass == nil) {
    return;
  }
  UIView *above = nil;
  CGFloat aboveMaxY = -CGFLOAT_MAX;
  UIView *below = nil;
  CGFloat belowMinY = CGFLOAT_MAX;
  for (UIView *subview in view.subviews) {
    ASDisplayNode *subnode = subview.asyncdisplaykit_node;
    if (subnode == nil || ![subnode isKindOfClass:itemNodeClass] || ![subview isKindOfClass:[_ASDisplayView class]]) {
      continue;
    }
    if (!ASAccessibilityViewIsShown(subview)) {
      continue;
    }
    CGRect frame = [subview convertRect:subview.bounds toView:view];
    if (frame.size.width <= 0.0 || frame.size.height <= 0.0 || ASAccessibilityRectIsVisible(frame, visibleRect)) {
      continue;
    }
    if (CGRectGetMaxY(frame) <= CGRectGetMinY(visibleRect)) {
      if (CGRectGetMaxY(frame) > aboveMaxY) {
        aboveMaxY = CGRectGetMaxY(frame);
        above = subview;
      }
    } else if (CGRectGetMinY(frame) >= CGRectGetMaxY(visibleRect)) {
      if (CGRectGetMinY(frame) < belowMinY) {
        belowMinY = CGRectGetMinY(frame);
        below = subview;
      }
    }
  }
  // In reading order even before the frame sort (which needs a frame from each element).
  if (above != nil) {
    [elements insertObject:above atIndex:0];
  }
  if (below != nil) {
    [elements addObject:below];
  }
}

/// Collect all accessibility elements for a given view and view node
static void CollectAccessibilityElementsForView(UIView *view, NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");

  ASDisplayNode *node = view.asyncdisplaykit_node;

  if (node.isAccessibilityContainer && !ASAccessibilityNodeIsListView(node)) {
    BOOL containsListView = (nil != ASDisplayNodeFindFirstSubnode(node, ^BOOL(ASDisplayNode *nodeToCheck) {
      return ASAccessibilityNodeIsListView(nodeToCheck);
    }));
    if (!containsListView) {
      CollectAccessibilityElementsForContainer(node, view, elements);
      return;
    }
  }

  CGRect visibleRect = ASAccessibilityVisibleRectInView(view);
  if (CGRectIsNull(visibleRect)) {
    return;
  }

  // Handle rasterize case
  if (node.rasterizesSubtree) {
    CollectLayerBackedAccessibilityElements(node, node, view, visibleRect, elements);
    return;
  }

  for (UIView *subview in view.subviews) {
    ASDisplayNode *subnode = subview.asyncdisplaykit_node;
    if (subnode != nil) {
      AddViewBackedSubnode(subnode, subview, view, visibleRect, elements);
    } else {
      AddPlainSubview(subview, view, visibleRect, elements);
    }
  }

  if (ASAccessibilityNodeIsListView(node)) {
    AddListViewEdgeRows(view, visibleRect, elements);
  }

  // Layer-backed subnodes have no view, so they are not among the subviews above.
  for (ASDisplayNode *subnode in node.subnodes) {
    if (subnode.isLayerBacked) {
      CollectLayerBackedAccessibilityElements(subnode, node, view, visibleRect, elements);
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

#pragma mark - UIAccessibility

- (void)setAccessibilityElements:(NSArray *)accessibilityElements
{
  ASDisplayNodeAssertMainThread();
  _accessibilityElements = [accessibilityElements copy];
}

/// The forwarded elements, or nil when UIKit's own behaviour applies.
- (NSArray *)_asdk_forwardedAccessibilityElements
{
  if (_accessibilityElements != nil) {
    return _accessibilityElements;
  }
  return ASDisplayNodeCachedAccessibilityElements(self.asyncdisplaykit_node);
}

- (NSArray *)accessibilityElements
{
  ASDisplayNodeAssertMainThread();
  NSArray *elements = [self _asdk_forwardedAccessibilityElements];
  if (elements != nil) {
    return elements;
  }
  return [super accessibilityElements];
}

- (NSInteger)accessibilityElementCount
{
  NSArray *elements = [self _asdk_forwardedAccessibilityElements];
  if (elements != nil) {
    return (NSInteger)elements.count;
  }
  return [super accessibilityElementCount];
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  NSArray *elements = [self _asdk_forwardedAccessibilityElements];
  if (elements != nil) {
    return (index >= 0 && (NSUInteger)index < elements.count) ? elements[(NSUInteger)index] : nil;
  }
  return [super accessibilityElementAtIndex:index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  NSArray *elements = [self _asdk_forwardedAccessibilityElements];
  if (elements != nil) {
    NSUInteger index = [elements indexOfObjectIdenticalTo:element];
    return (index == NSNotFound) ? NSNotFound : (NSInteger)index;
  }
  return [super indexOfAccessibilityElement:element];
}

@end

@implementation ASDisplayNode (AccessibilityCollection)

- (BOOL)accessibilityUsesViewElements
{
  ASDisplayNodeAssertMainThread();
  return _accessibilityUsesViewElements;
}

- (void)setAccessibilityUsesViewElements:(BOOL)accessibilityUsesViewElements
{
  ASDisplayNodeAssertMainThread();
  _accessibilityUsesViewElements = accessibilityUsesViewElements;
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
