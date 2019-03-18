//
//  ASDisplayNode+Yoga.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>

#if YOGA /* YOGA */

#import <AsyncDisplayKit/_ASDisplayViewAccessiblity.h>
#import <AsyncDisplayKit/ASYogaUtilities.h>
#import <AsyncDisplayKit/ASCollections.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutElementStylePrivate.h>
#import <AsyncDisplayKit/ASNodeController+Beta.h>

#import <AsyncDisplayKit/ASDisplayNode+LayoutSpec.h>

#define YOGA_LAYOUT_LOGGING 0

#pragma mark - ASDisplayNode+Yoga

@interface ASDisplayNode (YogaPrivate)
@property (nonatomic, weak) ASDisplayNode *yogaParent;
- (ASSizeRange)_locked_constrainedSizeForLayoutPass;
@end

@implementation ASDisplayNode (Yoga)

- (ASDisplayNode *)yogaRoot
{
  ASDisplayNode *yogaRoot = self;
  ASDisplayNode *yogaParent = nil;
  while ((yogaParent = yogaRoot.yogaParent)) {
    yogaRoot = yogaParent;
  }
  return yogaRoot;
}

- (void)setYogaChildren:(NSArray *)yogaChildren
{
  ASScopedLockSelfOrToRoot();
  for (ASDisplayNode *child in [_yogaChildren copy]) {
    // Make sure to un-associate the YGNodeRef tree before replacing _yogaChildren
    // If this becomes a performance bottleneck, it can be optimized by not doing the NSArray removals here.
    [self _locked_removeYogaChild:child];
  }
  _yogaChildren = nil;
  for (ASDisplayNode *child in yogaChildren) {
    [self _locked_addYogaChild:child];
  }
}

- (NSArray *)yogaChildren
{
  ASLockScope(self.yogaRoot);
  return [_yogaChildren copy] ?: @[];
}

- (void)addYogaChild:(ASDisplayNode *)child
{
  ASScopedLockSelfOrToRoot();
  [self _locked_addYogaChild:child];
}

- (void)_locked_addYogaChild:(ASDisplayNode *)child
{
  [self insertYogaChild:child atIndex:_yogaChildren.count];
}

- (void)removeYogaChild:(ASDisplayNode *)child
{
  ASScopedLockSelfOrToRoot();
  [self _locked_removeYogaChild:child];
}

- (void)_locked_removeYogaChild:(ASDisplayNode *)child
{
  if (child == nil) {
    return;
  }

  [_yogaChildren removeObjectIdenticalTo:child];

  // YGNodeRef removal is done in setParent:
  child.yogaParent = nil;
}

- (void)insertYogaChild:(ASDisplayNode *)child atIndex:(NSUInteger)index
{
  ASScopedLockSelfOrToRoot();
  [self _locked_insertYogaChild:child atIndex:index];
}

- (void)_locked_insertYogaChild:(ASDisplayNode *)child atIndex:(NSUInteger)index
{
  if (child == nil) {
    return;
  }
  if (_yogaChildren == nil) {
    _yogaChildren = [[NSMutableArray alloc] init];
  }

  // Clean up state in case this child had another parent.
  [self _locked_removeYogaChild:child];

  [_yogaChildren insertObject:child atIndex:index];

  // YGNodeRef insertion is done in setParent:
  child.yogaParent = self;
}

#pragma mark - Subclass Hooks

- (void)semanticContentAttributeDidChange:(UISemanticContentAttribute)attribute
{
  UIUserInterfaceLayoutDirection layoutDirection =
  [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:attribute];
  self.style.direction = (layoutDirection == UIUserInterfaceLayoutDirectionLeftToRight
                          ? YGDirectionLTR : YGDirectionRTL);
}

- (void)setYogaParent:(ASDisplayNode *)yogaParent
{
  ASLockScopeSelf();
  if (_yogaParent == yogaParent) {
    return;
  }

  YGNodeRef yogaNode = [self.style yogaNodeCreateIfNeeded];
  YGNodeRef oldParentRef = YGNodeGetParent(yogaNode);
  if (oldParentRef != NULL) {
    YGNodeRemoveChild(oldParentRef, yogaNode);
  }

  _yogaParent = yogaParent;
  if (yogaParent) {
    YGNodeRef newParentRef = [yogaParent.style yogaNodeCreateIfNeeded];
    YGNodeInsertChild(newParentRef, yogaNode, YGNodeGetChildCount(newParentRef));
  }
}

- (ASDisplayNode *)yogaParent
{
  return _yogaParent;
}

- (void)setYogaCalculatedLayout:(ASLayout *)yogaCalculatedLayout
{
  _yogaCalculatedLayout = yogaCalculatedLayout;
}

- (ASLayout *)yogaCalculatedLayout
{
  return _yogaCalculatedLayout;
}

- (void)setYogaLayoutInProgress:(BOOL)yogaLayoutInProgress
{
  setFlag(YogaLayoutInProgress, yogaLayoutInProgress);
  [self updateYogaMeasureFuncIfNeeded];
}

- (BOOL)yogaLayoutInProgress
{
  return checkFlag(YogaLayoutInProgress);
}

- (ASLayout *)layoutForYogaNode
{
  YGNodeRef yogaNode = self.style.yogaNode;

  CGSize  size     = CGSizeMake(YGNodeLayoutGetWidth(yogaNode), YGNodeLayoutGetHeight(yogaNode));
  CGPoint position = CGPointMake(YGNodeLayoutGetLeft(yogaNode), YGNodeLayoutGetTop(yogaNode));

  if (!ASIsCGSizeValidForSize(size)) {
    size = CGSizeZero;
  }

  if (!ASIsCGPositionValidForLayout(position)) {
    position = CGPointZero;
  }
  return [ASLayout layoutWithLayoutElement:self size:size position:position sublayouts:nil];
}

- (void)setupYogaCalculatedLayout
{
  ASScopedLockSelfOrToRoot();

  YGNodeRef yogaNode = self.style.yogaNode;
  uint32_t childCount = YGNodeGetChildCount(yogaNode);
  ASDisplayNodeAssert(childCount == _yogaChildren.count,
                      @"Yoga tree should always be in sync with .yogaNodes array! %@",
                      _yogaChildren);

  ASLayout *rawSublayouts[childCount];
  int i = 0;
  for (ASDisplayNode *subnode in _yogaChildren) {
    rawSublayouts[i++] = [subnode layoutForYogaNode];
  }
  const auto sublayouts = [NSArray<ASLayout *> arrayByTransferring:rawSublayouts count:childCount];

  // The layout for self should have position CGPointNull, but include the calculated size.
  CGSize size = CGSizeMake(YGNodeLayoutGetWidth(yogaNode), YGNodeLayoutGetHeight(yogaNode));
  if (!ASIsCGSizeValidForSize(size)) {
    size = CGSizeZero;
  }
  ASLayout *layout = [ASLayout layoutWithLayoutElement:self size:size sublayouts:sublayouts];

#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  // Assert that the sublayout is already flattened.
  for (ASLayout *sublayout in layout.sublayouts) {
    if (sublayout.sublayouts.count > 0 || ASDynamicCast(sublayout.layoutElement, ASDisplayNode) == nil) {
      ASDisplayNodeAssert(NO, @"Yoga sublayout is not flattened! %@, %@", self, sublayout);
    }
  }
#endif

  // Because this layout won't go through the rest of the logic in calculateLayoutThatFits:, flatten it now.
  layout = [layout filteredNodeLayoutTree];

  if ([self.yogaCalculatedLayout isEqual:layout] == NO) {
    self.yogaCalculatedLayout = layout;
  } else {
    layout = self.yogaCalculatedLayout;
    ASYogaLog("-setupYogaCalculatedLayout: applying identical ASLayout: %@", layout);
  }

  // Setup _pendingDisplayNodeLayout to reference the Yoga-calculated ASLayout, *unless* we are a leaf node.
  // Leaf yoga nodes may have their own .sublayouts, if they use a layout spec (such as ASButtonNode).
  // Their _pending variable is set after passing the Yoga checks at the start of -calculateLayoutThatFits:

  // For other Yoga nodes, there is no code that will set _pending unless we do it here. Why does it need to be set?
  // When CALayer triggers the -[ASDisplayNode __layout] call, we will check if our current _pending layout
  // has a size which matches our current bounds size. If it does, that layout will be used without recomputing it.

  // NOTE: Yoga does not make the constrainedSize available to intermediate nodes in the tree (e.g. not root or leaves).
  // Although the size range provided here is not accurate, this will only affect caching of calls to layoutThatFits:
  // These calls will behave as if they are not cached, starting a new Yoga layout pass, but this will tap into Yoga's
  // own internal cache.

  if ([self shouldHaveYogaMeasureFunc] == NO) {
    YGNodeRef parentNode = YGNodeGetParent(yogaNode);
    CGSize parentSize = CGSizeZero;
    if (parentNode) {
      parentSize.width = YGNodeLayoutGetWidth(parentNode);
      parentSize.height = YGNodeLayoutGetHeight(parentNode);
    }
    // For the root node in a Yoga tree, make sure to preserve the constrainedSize originally provided.
    // This will be used for all relayouts triggered by children, since they escalate to root.
    ASSizeRange range = parentNode ? ASSizeRangeUnconstrained : self.constrainedSizeForCalculatedLayout;
    _pendingDisplayNodeLayout = ASDisplayNodeLayout(layout, range, parentSize, _layoutVersion);
  }
}

- (BOOL)shouldHaveYogaMeasureFunc
{
  ASLockScopeSelf();
  // Size calculation via calculateSizeThatFits: or layoutSpecThatFits:
  // For these nodes, we assume they may need custom Baseline calculation too.
  // This will be used for ASTextNode, as well as any other node that has no Yoga children
  BOOL isLeafNode = (_yogaChildren.count == 0);
  BOOL definesCustomLayout = [self implementsLayoutMethod];
  return (isLeafNode && definesCustomLayout);
}

- (void)updateYogaMeasureFuncIfNeeded
{
  // We set the measure func only during layout. Otherwise, a cycle is created:
  // The YGNodeRef Context will retain the ASDisplayNode, which retains the style, which owns the YGNodeRef.
  BOOL shouldHaveMeasureFunc = ([self shouldHaveYogaMeasureFunc] && checkFlag(YogaLayoutInProgress));

  ASLayoutElementYogaUpdateMeasureFunc(self.style.yogaNode, shouldHaveMeasureFunc ? self : nil);
}

- (void)invalidateCalculatedYogaLayout
{
  ASLockScopeSelf();
  YGNodeRef yogaNode = self.style.yogaNode;
  if (yogaNode && [self shouldHaveYogaMeasureFunc]) {
    // Yoga internally asserts that MarkDirty() may only be called on nodes with a measurement function.
    BOOL needsTemporaryMeasureFunc = (YGNodeGetMeasureFunc(yogaNode) == NULL);
    if (needsTemporaryMeasureFunc) {
      ASDisplayNodeAssert(self.yogaLayoutInProgress == NO,
                          @"shouldHaveYogaMeasureFunc == YES, and inside a layout pass, but no measure func pointer! %@", self);
      YGNodeSetMeasureFunc(yogaNode, &ASLayoutElementYogaMeasureFunc);
    }
    YGNodeMarkDirty(yogaNode);
    if (needsTemporaryMeasureFunc) {
      YGNodeSetMeasureFunc(yogaNode, NULL);
    }
  }
  self.yogaCalculatedLayout = nil;
}

- (ASLayout *)calculateLayoutYoga:(ASSizeRange)constrainedSize
{
  AS::UniqueLock l(__instanceLock__);

  // There are several cases where Yoga could arrive here:
  // - This node is not in a Yoga tree: it has neither a yogaParent nor yogaChildren.
  // - This node is a Yoga tree root: it has no yogaParent, but has yogaChildren.
  // - This node is a Yoga tree node: it has both a yogaParent and yogaChildren.
  // - This node is a Yoga tree leaf: it has a yogaParent, but no yogaChidlren.
  if ([self locked_shouldLayoutFromYogaRoot]) {
    // If we're a yoga root, tree node, or leaf with no measure func (e.g. spacer), then
    // initiate a new Yoga calculation pass from root.
    as_activity_create_for_scope("Yoga layout calculation");
    if (self.yogaLayoutInProgress == NO) {
      ASYogaLog("Calculating yoga layout from root %@, %@", self,
              NSStringFromASSizeRange(constrainedSize));
      [self calculateLayoutFromYogaRoot:constrainedSize];
    } else {
      ASYogaLog("Reusing existing yoga layout %@", _yogaCalculatedLayout);
    }
    ASDisplayNodeAssert(_yogaCalculatedLayout,
            @"Yoga node should have a non-nil layout at this stage: %@", self);
    return _yogaCalculatedLayout;
  } else {
    // If we're a yoga leaf node with custom measurement function, proceed with normal layout so
    // layoutSpecs can run (e.g. ASButtonNode).
    ASYogaLog("PROCEEDING past Yoga check to calculate ASLayout for: %@", self);
  }

  // Delegate to layout spec layout for nodes that do not support Yoga
  return [self calculateLayoutLayoutSpec:constrainedSize];
}

- (void)calculateLayoutFromYogaRoot:(ASSizeRange)rootConstrainedSize
{
  ASScopedLockSet lockSet = [self lockToRootIfNeededForLayout];
  ASDisplayNode *yogaRoot = self.yogaRoot;

  if (self != yogaRoot) {
    ASYogaLog("ESCALATING to Yoga root: %@", self);
    // TODO(appleguy): Consider how to get the constrainedSize for the yogaRoot when escalating manually.
    [yogaRoot calculateLayoutFromYogaRoot:ASSizeRangeUnconstrained];
    return;
  }

  if (ASSizeRangeEqualToSizeRange(rootConstrainedSize, ASSizeRangeUnconstrained)) {
    rootConstrainedSize = [self _locked_constrainedSizeForLayoutPass];
  }

  [self willCalculateLayout:rootConstrainedSize];
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate>  _Nonnull delegate) {
    if ([delegate respondsToSelector:@selector(nodeWillCalculateLayout:)]) {
      [delegate nodeWillCalculateLayout:rootConstrainedSize];
    }
  }];

  // Prepare all children for the layout pass with the current Yoga tree configuration.
  ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode *_Nonnull node) {
    node.yogaLayoutInProgress = YES;
    ASDisplayNode *yogaParent = node.yogaParent; 
    if (yogaParent) {
      node.style.parentAlignStyle = yogaParent.style.alignItems;
    } else {
      node.style.parentAlignStyle = ASStackLayoutAlignItemsNotSet;
    };
  });

  ASYogaLog("CALCULATING at Yoga root with constraint = {%@, %@}: %@",
            NSStringFromCGSize(rootConstrainedSize.min), NSStringFromCGSize(rootConstrainedSize.max), self);

  YGNodeRef rootYogaNode = self.style.yogaNode;

  // Apply the constrainedSize as a base, known frame of reference.
  // If the root node also has style.*Size set, these will be overridden below.
  // YGNodeCalculateLayout currently doesn't offer the ability to pass a minimum size (max is passed there).

  // TODO(appleguy): Reconcile the self.style.*Size properties with rootConstrainedSize
  YGNodeStyleSetMinWidth (rootYogaNode, yogaFloatForCGFloat(rootConstrainedSize.min.width));
  YGNodeStyleSetMinHeight(rootYogaNode, yogaFloatForCGFloat(rootConstrainedSize.min.height));

  // It is crucial to use yogaFloat... to convert CGFLOAT_MAX into YGUndefined here.
  YGNodeCalculateLayout(rootYogaNode,
                        yogaFloatForCGFloat(rootConstrainedSize.max.width),
                        yogaFloatForCGFloat(rootConstrainedSize.max.height),
                        YGDirectionInherit);

  // Reset accessible elements, since layout may have changed.
  ASPerformBlockOnMainThread(^{
    if (self.nodeLoaded && !self.isSynchronous) {
      [(_ASDisplayView *)self.view setAccessibilityElements:nil];
    }
  });

  ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode * _Nonnull node) {
    [node setupYogaCalculatedLayout];
    node.yogaLayoutInProgress = NO;
  });

#if YOGA_LAYOUT_LOGGING /* YOGA_LAYOUT_LOGGING */
  // Concurrent layouts will interleave the NSLog messages unless we serialize.
  // Use @synchornize rather than trampolining to the main thread so the tree state isn't changed.
  @synchronized ([ASDisplayNode class]) {
    NSLog(@"****************************************************************************");
    NSLog(@"******************** STARTING YOGA -> ASLAYOUT CREATION ********************");
    NSLog(@"****************************************************************************");
    ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode * _Nonnull node) {
      NSLog(@"node = %@", node);
      YGNodePrint(node.style.yogaNode, (YGPrintOptions)(YGPrintOptionsStyle | YGPrintOptionsLayout));
      NSCAssert(ASIsCGSizeValidForSize(node.yogaCalculatedLayout.size), @"Yoga layout returned an invalid size");
      NSLog(@" "); // Newline
    });
  }
#endif /* YOGA_LAYOUT_LOGGING */
}

@end

#pragma mark - ASDisplayNode (YogaLocking)

@implementation ASDisplayNode (YogaLocking)

- (ASLockSet)lockToRootIfNeededForLayout {
  ASLockSet lockSet = ASLockSequence(^BOOL(ASAddLockBlock addLock) {
    if (!addLock(self)) {
      return NO;
    }
#if YOGA
    if (![self locked_shouldLayoutFromYogaRoot]) {
      return YES;
    }
    if (self.nodeController && !addLock(self.nodeController)) {
      return NO;
    }
    ASDisplayNode *parent = _supernode;
    while (parent) {
      if (!addLock(parent)) {
        return NO;
      }
      if (parent.nodeController && !addLock(parent.nodeController)) {
        return NO;
      }
      parent = parent->_supernode;
    }
#endif
    return true;
  });
  return lockSet;
}

@end

@implementation ASDisplayNode (YogaDebugging)

- (NSString *)yogaTreeDescription {
  return [self _yogaTreeDescription:@""];
}

- (NSString *)_yogaTreeDescription:(NSString *)indent {
  auto subtree = [NSMutableString stringWithFormat:@"%@%@\n", indent, self.description];
  for (ASDisplayNode *n in self.yogaChildren) {
    [subtree appendString:[n _yogaTreeDescription:[indent stringByAppendingString:@"| "]]];
  }
  return subtree;
}

@end

#endif /* YOGA */
