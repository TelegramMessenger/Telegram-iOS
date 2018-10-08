//
//  ASDimensionInternal.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDimension.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASLayoutElementSize

/**
 * A struct specifying a ASLayoutElement's size. Example:
 *
 *  ASLayoutElementSize size = (ASLayoutElementSize){
 *    .width = ASDimensionMakeWithFraction(0.25),
 *    .maxWidth = ASDimensionMakeWithPoints(200),
 *    .minHeight = ASDimensionMakeWithFraction(0.50)
 *  };
 *
 *  Description: <ASLayoutElementSize: exact={25%, Auto}, min={Auto, 50%}, max={200pt, Auto}>
 *
 */
typedef struct {
  ASDimension width;
  ASDimension height;
  ASDimension minWidth;
  ASDimension maxWidth;
  ASDimension minHeight;
  ASDimension maxHeight;
} ASLayoutElementSize;

/**
 * Returns an ASLayoutElementSize with default values.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASLayoutElementSize ASLayoutElementSizeMake()
{
  return (ASLayoutElementSize){
    .width = ASDimensionAuto,
    .height = ASDimensionAuto,
    .minWidth = ASDimensionAuto,
    .maxWidth = ASDimensionAuto,
    .minHeight = ASDimensionAuto,
    .maxHeight = ASDimensionAuto
  };
}

/**
 * Returns an ASLayoutElementSize with the specified CGSize values as width and height.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASLayoutElementSize ASLayoutElementSizeMakeFromCGSize(CGSize size)
{
  ASLayoutElementSize s = ASLayoutElementSizeMake();
  s.width = ASDimensionMakeWithPoints(size.width);
  s.height = ASDimensionMakeWithPoints(size.height);
  return s;
}

/**
 * Returns whether two sizes are equal.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT BOOL ASLayoutElementSizeEqualToLayoutElementSize(ASLayoutElementSize lhs, ASLayoutElementSize rhs)
{
  return (ASDimensionEqualToDimension(lhs.width, rhs.width)
  && ASDimensionEqualToDimension(lhs.height, rhs.height)
  && ASDimensionEqualToDimension(lhs.minWidth, rhs.minWidth)
  && ASDimensionEqualToDimension(lhs.maxWidth, rhs.maxWidth)
  && ASDimensionEqualToDimension(lhs.minHeight, rhs.minHeight)
  && ASDimensionEqualToDimension(lhs.maxHeight, rhs.maxHeight));
}

/**
 * Returns a string formatted to contain the data from an ASLayoutElementSize.
 */
AS_EXTERN AS_WARN_UNUSED_RESULT NSString *NSStringFromASLayoutElementSize(ASLayoutElementSize size);

/**
 * Resolve the given size relative to a parent size and an auto size.
 * From the given size uses width, height to resolve the exact size constraint, uses the minHeight and minWidth to
 * resolve the min size constraint and the maxHeight and maxWidth to resolve the max size constraint. For every
 * dimension with unit ASDimensionUnitAuto the given autoASSizeRange value will be used.
 * Based on the calculated exact, min and max size constraints the final size range will be calculated.
 */
AS_EXTERN AS_WARN_UNUSED_RESULT ASSizeRange ASLayoutElementSizeResolveAutoSize(ASLayoutElementSize size, const CGSize parentSize, ASSizeRange autoASSizeRange);

/**
 * Resolve the given size to a parent size. Uses internally ASLayoutElementSizeResolveAutoSize with {INFINITY, INFINITY} as
 * as autoASSizeRange. For more information look at ASLayoutElementSizeResolveAutoSize.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASSizeRange ASLayoutElementSizeResolve(ASLayoutElementSize size, const CGSize parentSize)
{
  return ASLayoutElementSizeResolveAutoSize(size, parentSize, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
}


NS_ASSUME_NONNULL_END
