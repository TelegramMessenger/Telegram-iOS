//
//  ASDisplayNode+Yoga.mm
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

#import <AsyncDisplayKit/ASAvailability.h>

#if YOGA /* YOGA */

#import <AsyncDisplayKit/_ASDisplayViewAccessiblity.h>
#import <AsyncDisplayKit/ASYogaLayoutSpec.h>
#import <AsyncDisplayKit/ASYogaUtilities.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkSubclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASLayout.h>

#define YOGA_LAYOUT_LOGGING 0

#pragma mark - ASDisplayNode+Yoga

@interface ASDisplayNode (YogaInternal)
@property (nonatomic, weak) ASDisplayNode *yogaParent;
- (ASSizeRange)_locked_constrainedSizeForLayoutPass;
@end

@implementation ASDisplayNode (Yoga)

- (void)setYogaChildren:(NSArray *)yogaChildren
{
  for (ASDisplayNode *child in [_yogaChildren copy]) {
    // Make sure to un-associate the YGNodeRef tree before replacing _yogaChildren
    // If this becomes a performance bottleneck, it can be optimized by not doing the NSArray removals here.
    [self removeYogaChild:child];
  }
  _yogaChildren = nil;
  for (ASDisplayNode *child in yogaChildren) {
    [self addYogaChild:child];
  }
}

- (NSArray *)yogaChildren
{
  return _yogaChildren;
}

- (void)addYogaChild:(ASDisplayNode *)child
{
  [self insertYogaChild:child atIndex:_yogaChildren.count];
}

- (void)removeYogaChild:(ASDisplayNode *)child
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
  if (child == nil) {
    return;
  }
  if (_yogaChildren == nil) {
    _yogaChildren = [NSMutableArray array];
  }

  // Clean up state in case this child had another parent.
  [self removeYogaChild:child];

  [_yogaChildren insertObject:child atIndex:index];

  // YGNodeRef insertion is done in setParent:
  child.yogaParent = self;
}

- (void)semanticContentAttributeDidChange:(UISemanticContentAttribute)attribute
{
  if (AS_AT_LEAST_IOS9) {
    UIUserInterfaceLayoutDirection layoutDirection =
    [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:attribute];
    self.style.direction = (layoutDirection == UIUserInterfaceLayoutDirectionLeftToRight
                            ? YGDirectionLTR : YGDirectionRTL);
  }
}

- (void)setYogaParent:(ASDisplayNode *)yogaParent
{
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

  return [ASLayout layoutWithLayoutElement:self size:size position:position sublayouts:nil];
}

- (void)setupYogaCalculatedLayout
{
  YGNodeRef yogaNode = self.style.yogaNode;
  uint32_t childCount = YGNodeGetChildCount(yogaNode);
  ASDisplayNodeAssert(childCount == self.yogaChildren.count,
                      @"Yoga tree should always be in sync with .yogaNodes array! %@", self.yogaChildren);

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:childCount];
  for (ASDisplayNode *subnode in self.yogaChildren) {
    [sublayouts addObject:[subnode layoutForYogaNode]];
  }

  // The layout for self should have position CGPointNull, but include the calculated size.
  CGSize size = CGSizeMake(YGNodeLayoutGetWidth(yogaNode), YGNodeLayoutGetHeight(yogaNode));
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
    _pendingDisplayNodeLayout = std::make_shared<ASDisplayNodeLayout>(layout, ASSizeRangeUnconstrained, parentSize, 0);
  }
}

- (BOOL)shouldHaveYogaMeasureFunc
{
  // Size calculation via calculateSizeThatFits: or layoutSpecThatFits:
  // This will be used for ASTextNode, as well as any other node that has no Yoga children
  BOOL isLeafNode = (self.yogaChildren.count == 0);
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
  YGNodeRef yogaNode = self.style.yogaNode;
  if (yogaNode && YGNodeGetMeasureFunc(yogaNode)) {
    // Yoga internally asserts that MarkDirty() may only be called on nodes with a measurement function.
    YGNodeMarkDirty(yogaNode);
  }
  self.yogaCalculatedLayout = nil;
}

- (void)calculateLayoutFromYogaRoot:(ASSizeRange)rootConstrainedSize
{
  ASDisplayNode *yogaParent = self.yogaParent;

  if (yogaParent) {
    ASYogaLog("ESCALATING to Yoga root: %@", self);
    // TODO(appleguy): Consider how to get the constrainedSize for the yogaRoot when escalating manually.
    [yogaParent calculateLayoutFromYogaRoot:ASSizeRangeUnconstrained];
    return;
  }

  ASDN::MutexLocker l(__instanceLock__);

  // Prepare all children for the layout pass with the current Yoga tree configuration.
  ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode * _Nonnull node) {
    node.yogaLayoutInProgress = YES;
  });

  if (ASSizeRangeEqualToSizeRange(rootConstrainedSize, ASSizeRangeUnconstrained)) {
    rootConstrainedSize = [self _locked_constrainedSizeForLayoutPass];
  }

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
    [(_ASDisplayView *)self.view setAccessibleElements:nil];
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
      NSLog(@" "); // Newline
      NSLog(@"node = %@", node);
      NSLog(@"style = %@", node.style);
      NSLog(@"layout = %@", node.yogaCalculatedLayout);
      YGNodePrint(node.style.yogaNode, (YGPrintOptions)(YGPrintOptionsStyle | YGPrintOptionsLayout));
    });
  }
#endif /* YOGA_LAYOUT_LOGGING */
}

@end

#endif /* YOGA */
