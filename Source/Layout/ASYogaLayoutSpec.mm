//
//  ASYogaLayoutSpec.mm
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>

#if YOGA /* YOGA */

#import <AsyncDisplayKit/ASYogaLayoutSpec.h>
#import <AsyncDisplayKit/ASYogaUtilities.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

#define YOGA_LAYOUT_LOGGING 0

@implementation ASYogaLayoutSpec

- (ASLayout *)layoutForYogaNode:(YGNodeRef)yogaNode
{
  BOOL isRootNode = (YGNodeGetParent(yogaNode) == NULL);
  uint32_t childCount = YGNodeGetChildCount(yogaNode);

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:childCount];
  for (uint32_t i = 0; i < childCount; i++) {
    [sublayouts addObject:[self layoutForYogaNode:YGNodeGetChild(yogaNode, i)]];
  }

  id <ASLayoutElement> layoutElement = (__bridge id <ASLayoutElement>)YGNodeGetContext(yogaNode);
  CGSize size = CGSizeMake(YGNodeLayoutGetWidth(yogaNode), YGNodeLayoutGetHeight(yogaNode));

  if (isRootNode) {
    // The layout for root should have position CGPointNull, but include the calculated size.
    return [ASLayout layoutWithLayoutElement:layoutElement size:size sublayouts:sublayouts];
  } else {
    CGPoint position = CGPointMake(YGNodeLayoutGetLeft(yogaNode), YGNodeLayoutGetTop(yogaNode));
    return [ASLayout layoutWithLayoutElement:layoutElement size:size position:position sublayouts:nil];
  }
}

- (void)destroyYogaNode:(YGNodeRef)yogaNode
{
  // Release the __bridge_retained Context object.
  __unused id <ASLayoutElement> element = (__bridge_transfer id)YGNodeGetContext(yogaNode);
  YGNodeFree(yogaNode);
}

- (void)setupYogaNode:(YGNodeRef)yogaNode forElement:(id <ASLayoutElement>)element withParentYogaNode:(YGNodeRef)parentYogaNode
{
  ASLayoutElementStyle *style = element.style;

  // Retain the Context object. This must be explicitly released with a __bridge_transfer; YGNodeFree() is not sufficient.
  YGNodeSetContext(yogaNode, (__bridge_retained void *)element);

  YGNodeStyleSetDirection     (yogaNode, style.direction);

  YGNodeStyleSetFlexWrap      (yogaNode, style.flexWrap);
  YGNodeStyleSetFlexGrow      (yogaNode, style.flexGrow);
  YGNodeStyleSetFlexShrink    (yogaNode, style.flexShrink);
  YGNODE_STYLE_SET_DIMENSION  (yogaNode, FlexBasis, style.flexBasis);

  YGNodeStyleSetFlexDirection (yogaNode, yogaFlexDirection(style.flexDirection));
  YGNodeStyleSetJustifyContent(yogaNode, yogaJustifyContent(style.justifyContent));
  YGNodeStyleSetAlignSelf     (yogaNode, yogaAlignSelf(style.alignSelf));
  ASStackLayoutAlignItems alignItems = style.alignItems;
  if (alignItems != ASStackLayoutAlignItemsNotSet) {
    YGNodeStyleSetAlignItems(yogaNode, yogaAlignItems(alignItems));
  }

  YGNodeStyleSetPositionType  (yogaNode, style.positionType);
  ASEdgeInsets position = style.position;
  ASEdgeInsets margin   = style.margin;
  ASEdgeInsets padding  = style.padding;
  ASEdgeInsets border   = style.border;

  YGEdge edge = YGEdgeLeft;
  for (int i = 0; i < YGEdgeAll + 1; ++i) {
    YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(yogaNode, Position, dimensionForEdgeWithEdgeInsets(edge, position), edge);
    YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(yogaNode, Margin, dimensionForEdgeWithEdgeInsets(edge, margin), edge);
    YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(yogaNode, Padding, dimensionForEdgeWithEdgeInsets(edge, padding), edge);
    YGNODE_STYLE_SET_FLOAT_WITH_EDGE(yogaNode, Border, dimensionForEdgeWithEdgeInsets(edge, border), edge);
    edge = (YGEdge)(edge + 1);
  }

  CGFloat aspectRatio = style.aspectRatio;
  if (aspectRatio > FLT_EPSILON && aspectRatio < CGFLOAT_MAX / 2.0) {
    YGNodeStyleSetAspectRatio(yogaNode, aspectRatio);
  }

  // For the root node, we use rootConstrainedSize above. For children, consult the style for their size.
  if (parentYogaNode != NULL) {
    YGNodeInsertChild(parentYogaNode, yogaNode, YGNodeGetChildCount(parentYogaNode));

    YGNODE_STYLE_SET_DIMENSION(yogaNode, Width, style.width);
    YGNODE_STYLE_SET_DIMENSION(yogaNode, Height, style.height);

    YGNODE_STYLE_SET_DIMENSION(yogaNode, MinWidth, style.minWidth);
    YGNODE_STYLE_SET_DIMENSION(yogaNode, MinHeight, style.minHeight);

    YGNODE_STYLE_SET_DIMENSION(yogaNode, MaxWidth, style.maxWidth);
    YGNODE_STYLE_SET_DIMENSION(yogaNode, MaxHeight, style.maxHeight);

    YGNodeSetMeasureFunc(yogaNode, &ASLayoutElementYogaMeasureFunc);
  }

  // TODO(appleguy): STYLE SETTER METHODS LEFT TO IMPLEMENT: YGNodeStyleSetOverflow, YGNodeStyleSetFlex
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)layoutElementSize
                 relativeToParentSize:(CGSize)parentSize
{
  ASSizeRange styleAndParentSize = ASLayoutElementSizeResolve(layoutElementSize, parentSize);
  const ASSizeRange rootConstrainedSize = ASSizeRangeIntersect(constrainedSize, styleAndParentSize);

  YGNodeRef rootYogaNode = YGNodeNew();

  // YGNodeCalculateLayout currently doesn't offer the ability to pass a minimum size (max is passed there).
  // Apply the constrainedSize.min directly to the root node so that layout accounts for it.
  YGNodeStyleSetMinWidth (rootYogaNode, yogaFloatForCGFloat(rootConstrainedSize.min.width));
  YGNodeStyleSetMinHeight(rootYogaNode, yogaFloatForCGFloat(rootConstrainedSize.min.height));

  // It's crucial to set these values. YGNodeCalculateLayout has unusual behavior for its width and height parameters:
  // 1. If no maximum size set, infer this means YGMeasureModeExactly. Even if a small minWidth & minHeight are set,
  //    these will never be used because the output size of the root will always exactly match this value.
  // 2. If a maximum size is set, infer that this means YGMeasureModeAtMost, and allow down to the min* values in output.
  YGNodeStyleSetMaxWidthPercent(rootYogaNode, 100.0);
  YGNodeStyleSetMaxHeightPercent(rootYogaNode, 100.0);

  [self setupYogaNode:rootYogaNode forElement:self.rootNode withParentYogaNode:NULL];
  for (id <ASLayoutElement> child in self.children) {
    YGNodeRef yogaNode = YGNodeNew();
    [self setupYogaNode:yogaNode forElement:child withParentYogaNode:rootYogaNode];
  }

  // It is crucial to use yogaFloat... to convert CGFLOAT_MAX into YGUndefined here.
  YGNodeCalculateLayout(rootYogaNode,
                        yogaFloatForCGFloat(rootConstrainedSize.max.width),
                        yogaFloatForCGFloat(rootConstrainedSize.max.height),
                        YGDirectionInherit);

  ASLayout *layout = [self layoutForYogaNode:rootYogaNode];

#if YOGA_LAYOUT_LOGGING
  // Concurrent layouts will interleave the NSLog messages unless we serialize.
  // Use @synchornize rather than trampolining to the main thread so the tree state isn't changed.
  @synchronized ([ASDisplayNode class]) {
    NSLog(@"****************************************************************************");
    NSLog(@"******************** STARTING YOGA -> ASLAYOUT CREATION ********************");
    NSLog(@"****************************************************************************");
      NSLog(@"node = %@", self.rootNode);
      NSLog(@"style = %@", self.rootNode.style);
      YGNodePrint(rootYogaNode, (YGPrintOptions)(YGPrintOptionsStyle | YGPrintOptionsLayout));
  }
  NSLog(@"rootConstraint = (%@, %@), layout = %@, sublayouts = %@", NSStringFromCGSize(rootConstrainedSize.min), NSStringFromCGSize(rootConstrainedSize.max), layout, layout.sublayouts);
#endif

  while(YGNodeGetChildCount(rootYogaNode) > 0) {
    YGNodeRef yogaNode = YGNodeGetChild(rootYogaNode, 0);
    [self destroyYogaNode:yogaNode];
  }
  [self destroyYogaNode:rootYogaNode];

  return layout;
}

@end

#endif /* YOGA */
