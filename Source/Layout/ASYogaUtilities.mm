//
//  ASYogaUtilities.mm
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASYogaUtilities.h>

#if YOGA /* YOGA */

@implementation ASDisplayNode (YogaHelpers)

+ (ASDisplayNode *)yogaNode
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  [node.style yogaNodeCreateIfNeeded];
  return node;
}

+ (ASDisplayNode *)yogaSpacerNode
{
  ASDisplayNode *node = [ASDisplayNode yogaNode];
  node.style.flexGrow = 1.0f;
  return node;
}

+ (ASDisplayNode *)yogaVerticalStack
{
  ASDisplayNode *node = [self yogaNode];
  node.style.flexDirection = ASStackLayoutDirectionVertical;
  return node;
}

+ (ASDisplayNode *)yogaHorizontalStack
{
  ASDisplayNode *node = [self yogaNode];
  node.style.flexDirection = ASStackLayoutDirectionHorizontal;
  return node;
}

@end

extern void ASDisplayNodePerformBlockOnEveryYogaChild(ASDisplayNode *node, void(^block)(ASDisplayNode *node))
{
  if (node == nil) {
    return;
  }
  block(node);
  for (ASDisplayNode *child in [node yogaChildren]) {
    ASDisplayNodePerformBlockOnEveryYogaChild(child, block);
  }
}

#pragma mark - Yoga Type Conversion Helpers

YGAlign yogaAlignItems(ASStackLayoutAlignItems alignItems)
{
  switch (alignItems) {
    case ASStackLayoutAlignItemsNotSet:         return YGAlignAuto;
    case ASStackLayoutAlignItemsStart:          return YGAlignFlexStart;
    case ASStackLayoutAlignItemsEnd:            return YGAlignFlexEnd;
    case ASStackLayoutAlignItemsCenter:         return YGAlignCenter;
    case ASStackLayoutAlignItemsStretch:        return YGAlignStretch;
    case ASStackLayoutAlignItemsBaselineFirst:  return YGAlignBaseline;
      // FIXME: WARNING, Yoga does not currently support last-baseline item alignment.
    case ASStackLayoutAlignItemsBaselineLast:   return YGAlignBaseline;
  }
}

YGJustify yogaJustifyContent(ASStackLayoutJustifyContent justifyContent)
{
  switch (justifyContent) {
    case ASStackLayoutJustifyContentStart:        return YGJustifyFlexStart;
    case ASStackLayoutJustifyContentCenter:       return YGJustifyCenter;
    case ASStackLayoutJustifyContentEnd:          return YGJustifyFlexEnd;
    case ASStackLayoutJustifyContentSpaceBetween: return YGJustifySpaceBetween;
    case ASStackLayoutJustifyContentSpaceAround:  return YGJustifySpaceAround;
  }
}

YGAlign yogaAlignSelf(ASStackLayoutAlignSelf alignSelf)
{
  switch (alignSelf) {
    case ASStackLayoutAlignSelfStart:   return YGAlignFlexStart;
    case ASStackLayoutAlignSelfCenter:  return YGAlignCenter;
    case ASStackLayoutAlignSelfEnd:     return YGAlignFlexEnd;
    case ASStackLayoutAlignSelfStretch: return YGAlignStretch;
    case ASStackLayoutAlignSelfAuto:    return YGAlignAuto;
  }
}

YGFlexDirection yogaFlexDirection(ASStackLayoutDirection direction)
{
  return direction == ASStackLayoutDirectionVertical ? YGFlexDirectionColumn : YGFlexDirectionRow;
}

float yogaFloatForCGFloat(CGFloat value)
{
  if (value < CGFLOAT_MAX / 2) {
    return value;
  } else {
    return YGUndefined;
  }
}

float yogaDimensionToPoints(ASDimension dimension)
{
  ASDisplayNodeCAssert(dimension.unit == ASDimensionUnitPoints,
                       @"Dimensions should not be type Fraction for this method: %f", dimension.value);
  return yogaFloatForCGFloat(dimension.value);
}

float yogaDimensionToPercent(ASDimension dimension)
{
  ASDisplayNodeCAssert(dimension.unit == ASDimensionUnitFraction,
                       @"Dimensions should not be type Points for this method: %f", dimension.value);
  return 100.0 * yogaFloatForCGFloat(dimension.value);

}

ASDimension dimensionForEdgeWithEdgeInsets(YGEdge edge, ASEdgeInsets insets)
{
  switch (edge) {
    case YGEdgeLeft:          return insets.left;
    case YGEdgeTop:           return insets.top;
    case YGEdgeRight:         return insets.right;
    case YGEdgeBottom:        return insets.bottom;
    case YGEdgeStart:         return insets.start;
    case YGEdgeEnd:           return insets.end;
    case YGEdgeHorizontal:    return insets.horizontal;
    case YGEdgeVertical:      return insets.vertical;
    case YGEdgeAll:           return insets.all;
    default: ASDisplayNodeCAssert(NO, @"YGEdge other than ASEdgeInsets is not supported.");
      return ASDimensionAuto;
  }
}

void ASLayoutElementYogaUpdateMeasureFunc(YGNodeRef yogaNode, id <ASLayoutElement> layoutElement)
{
  if (yogaNode == NULL) {
    return;
  }
  BOOL hasMeasureFunc = (YGNodeGetMeasureFunc(yogaNode) != NULL);

  if (layoutElement != nil && [layoutElement implementsLayoutMethod]) {
    if (hasMeasureFunc == NO) {
      // Retain the Context object. This must be explicitly released with a
      // __bridge_transfer - YGNodeFree() is not sufficient.
      YGNodeSetContext(yogaNode, (__bridge_retained void *)layoutElement);
      YGNodeSetMeasureFunc(yogaNode, &ASLayoutElementYogaMeasureFunc);
    }
    ASDisplayNodeCAssert(YGNodeGetContext(yogaNode) == (__bridge void *)layoutElement,
                         @"Yoga node context should contain layoutElement: %@", layoutElement);
  } else if (hasMeasureFunc == YES) {
    // If we lack any of the conditions above, and currently have a measure func, get rid of it.
    // Release the __bridge_retained Context object.
    __unused id <ASLayoutElement> element = (__bridge_transfer id)YGNodeGetContext(yogaNode);
    YGNodeSetContext(yogaNode, NULL);
    YGNodeSetMeasureFunc(yogaNode, NULL);
  }
}

YGSize ASLayoutElementYogaMeasureFunc(YGNodeRef yogaNode, float width, YGMeasureMode widthMode,
                                      float height, YGMeasureMode heightMode)
{
  id <ASLayoutElement> layoutElement = (__bridge id <ASLayoutElement>)YGNodeGetContext(yogaNode);
  ASDisplayNodeCAssert([layoutElement conformsToProtocol:@protocol(ASLayoutElement)], @"Yoga context must be <ASLayoutElement>");

  ASSizeRange sizeRange;
  sizeRange.min = CGSizeZero;
  sizeRange.max = CGSizeMake(width, height);
  if (widthMode == YGMeasureModeExactly) {
    sizeRange.min.width = sizeRange.max.width;
  } else {
    // Mode is (YGMeasureModeAtMost | YGMeasureModeUndefined)
    ASDimension minWidth = layoutElement.style.minWidth;
    sizeRange.min.width = (minWidth.unit == ASDimensionUnitPoints ? yogaDimensionToPoints(minWidth) : 0.0);
  }
  if (heightMode == YGMeasureModeExactly) {
    sizeRange.min.height = sizeRange.max.height;
  } else {
    // Mode is (YGMeasureModeAtMost | YGMeasureModeUndefined)
    ASDimension minHeight = layoutElement.style.minHeight;
    sizeRange.min.height = (minHeight.unit == ASDimensionUnitPoints ? yogaDimensionToPoints(minHeight) : 0.0);
  }

  ASDisplayNodeCAssert(isnan(sizeRange.min.width) == NO && isnan(sizeRange.min.height) == NO, @"Yoga size range for measurement should not have NaN in minimum");
  if (isnan(sizeRange.max.width)) {
    sizeRange.max.width = CGFLOAT_MAX;
  }
  if (isnan(sizeRange.max.height)) {
    sizeRange.max.height = CGFLOAT_MAX;
  }

  CGSize size = [[layoutElement layoutThatFits:sizeRange] size];
  return (YGSize){ .width = (float)size.width, .height = (float)size.height };
}

#endif /* YOGA */
