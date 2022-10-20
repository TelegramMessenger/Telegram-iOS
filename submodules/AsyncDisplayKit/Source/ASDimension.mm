//
//  ASDimension.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDimension.h>

#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>

#import <AsyncDisplayKit/ASAssert.h>

#pragma mark - ASDimension

ASDimension const ASDimensionAuto = {ASDimensionUnitAuto, 0};

ASOVERLOADABLE ASDimension ASDimensionMake(NSString *dimension)
{
  if (dimension.length > 0) {
    
    // Handle points
    if ([dimension hasSuffix:@"pt"]) {
      return ASDimensionMake(ASDimensionUnitPoints, ASCGFloatFromString(dimension));
    }
    
    // Handle auto
    if ([dimension isEqualToString:@"auto"]) {
      return ASDimensionAuto;
    }
  
    // Handle percent
    if ([dimension hasSuffix:@"%"]) {
      return ASDimensionMake(ASDimensionUnitFraction, (ASCGFloatFromString(dimension) / 100.0));
    }
  }
  
  return ASDimensionAuto;
}

NSString *NSStringFromASDimension(ASDimension dimension)
{
  switch (dimension.unit) {
    case ASDimensionUnitPoints:
      return [NSString stringWithFormat:@"%.0fpt", dimension.value];
    case ASDimensionUnitFraction:
      return [NSString stringWithFormat:@"%.0f%%", dimension.value * 100.0];
    case ASDimensionUnitAuto:
      return @"Auto";
  }
}

#pragma mark - ASLayoutSize

ASLayoutSize const ASLayoutSizeAuto = {ASDimensionAuto, ASDimensionAuto};

#pragma mark - ASSizeRange

ASSizeRange const ASSizeRangeZero = {};

ASSizeRange const ASSizeRangeUnconstrained = { {0, 0}, { INFINITY, INFINITY }};

struct _Range {
  CGFloat min;
  CGFloat max;
  
  /**
   Intersects another dimension range. If the other range does not overlap, this size range "wins" by returning a
   single point within its own range that is closest to the non-overlapping range.
   */
  _Range intersect(const _Range &other) const
  {
  CGFloat newMin = MAX(min, other.min);
  CGFloat newMax = MIN(max, other.max);
  if (newMin <= newMax) {
    return {newMin, newMax};
  } else {
    // No intersection. If we're before the other range, return our max; otherwise our min.
    if (min < other.min) {
      return {max, max};
    } else {
      return {min, min};
    }
  }
  }
};

ASSizeRange ASSizeRangeIntersect(ASSizeRange sizeRange, ASSizeRange otherSizeRange)
{
  const auto w = _Range({sizeRange.min.width, sizeRange.max.width}).intersect({otherSizeRange.min.width, otherSizeRange.max.width});
  const auto h = _Range({sizeRange.min.height, sizeRange.max.height}).intersect({otherSizeRange.min.height, otherSizeRange.max.height});
  return {{w.min, h.min}, {w.max, h.max}};
}

NSString *NSStringFromASSizeRange(ASSizeRange sizeRange)
{
  // 17 field length copied from iOS 10.3 impl of NSStringFromCGSize.
  if (CGSizeEqualToSize(sizeRange.min, sizeRange.max)) {
    return [NSString stringWithFormat:@"{{%.*g, %.*g}}",
            17, sizeRange.min.width,
            17, sizeRange.min.height];
  }
  return [NSString stringWithFormat:@"{{%.*g, %.*g}, {%.*g, %.*g}}",
          17, sizeRange.min.width,
          17, sizeRange.min.height,
          17, sizeRange.max.width,
          17, sizeRange.max.height];
}

#if YOGA
#pragma mark - Yoga - ASEdgeInsets
ASEdgeInsets const ASEdgeInsetsZero = {};

ASEdgeInsets ASEdgeInsetsMake(UIEdgeInsets edgeInsets)
{
  ASEdgeInsets asEdgeInsets = ASEdgeInsetsZero;
  asEdgeInsets.top = ASDimensionMake(edgeInsets.top);
  asEdgeInsets.left = ASDimensionMake(edgeInsets.left);
  asEdgeInsets.bottom = ASDimensionMake(edgeInsets.bottom);
  asEdgeInsets.right = ASDimensionMake(edgeInsets.right);
  return asEdgeInsets;
}
#endif
