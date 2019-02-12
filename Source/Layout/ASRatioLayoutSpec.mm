//
//  ASRatioLayoutSpec.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASRatioLayoutSpec.h>

#import <algorithm>
#import <tgmath.h>
#import <vector>

#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

#pragma mark - ASRatioLayoutSpec

@implementation ASRatioLayoutSpec
{
  CGFloat _ratio;
}

#pragma mark - Lifecycle

+ (instancetype)ratioLayoutSpecWithRatio:(CGFloat)ratio child:(id<ASLayoutElement>)child NS_RETURNS_RETAINED
{
  return [[self alloc] initWithRatio:ratio child:child];
}

- (instancetype)initWithRatio:(CGFloat)ratio child:(id<ASLayoutElement>)child;
{
  if (!(self = [super init])) {
    return nil;
  }

  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  ASDisplayNodeAssert(ratio > 0, @"Ratio should be strictly positive, but received %f", ratio);
  _ratio = ratio;
  self.child = child;

  return self;
}

#pragma mark - Setter / Getter

- (void)setRatio:(CGFloat)ratio
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _ratio = ratio;
}

#pragma mark - ASLayoutElement

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  std::vector<CGSize> sizeOptions;
  
  if (ASPointsValidForSize(constrainedSize.max.width)) {
    sizeOptions.push_back(ASSizeRangeClamp(constrainedSize, {
      constrainedSize.max.width,
      ASFloorPixelValue(_ratio * constrainedSize.max.width)
    }));
  }
  
  if (ASPointsValidForSize(constrainedSize.max.height)) {
    sizeOptions.push_back(ASSizeRangeClamp(constrainedSize, {
      ASFloorPixelValue(constrainedSize.max.height / _ratio),
      constrainedSize.max.height
    }));
  }

  // Choose the size closest to the desired ratio.
  const auto &bestSize = std::max_element(sizeOptions.begin(), sizeOptions.end(), [&](const CGSize &a, const CGSize &b){
    return std::fabs((a.height / a.width) - _ratio) > std::fabs((b.height / b.width) - _ratio);
  });

  // If there is no max size in *either* dimension, we can't apply the ratio, so just pass our size range through.
  const ASSizeRange childRange = (bestSize == sizeOptions.end()) ? constrainedSize : ASSizeRangeIntersect(constrainedSize, ASSizeRangeMake(*bestSize, *bestSize));
  const CGSize parentSize = (bestSize == sizeOptions.end()) ? ASLayoutElementParentSizeUndefined : *bestSize;
  ASLayout *sublayout = [self.child layoutThatFits:childRange parentSize:parentSize];
  sublayout.position = CGPointZero;
  return [ASLayout layoutWithLayoutElement:self size:sublayout.size sublayouts:@[sublayout]];
}

@end

#pragma mark - ASRatioLayoutSpec (Debugging)

@implementation ASRatioLayoutSpec (Debugging)

#pragma mark - ASLayoutElementAsciiArtProtocol

- (NSString *)asciiArtName
{
  return [NSString stringWithFormat:@"%@ (%.1f)", NSStringFromClass([self class]), self.ratio];
}

@end
