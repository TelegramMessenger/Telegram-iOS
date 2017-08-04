//
//  ASCollectionViewLayoutController.m
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

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASCollectionViewLayoutController.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCollectionView+Undeprecated.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#import <AsyncDisplayKit/UICollectionViewLayout+ASConvenience.h>

struct ASRangeGeometry {
  CGRect rangeBounds;
  CGRect updateBounds;
};
typedef struct ASRangeGeometry ASRangeGeometry;


#pragma mark -
#pragma mark ASCollectionViewLayoutController

@interface ASCollectionViewLayoutController ()
{
  @package
  ASCollectionView * __weak _collectionView;
  UICollectionViewLayout * __strong _collectionViewLayout;
}
@end

@implementation ASCollectionViewLayoutController

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _collectionView = collectionView;
  _collectionViewLayout = [collectionView collectionViewLayout];
  return self;
}

- (NSHashTable<ASCollectionElement *> *)elementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType map:(ASElementMap *)map
{
  ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeMode:rangeMode rangeType:rangeType];
  CGRect rangeBounds = [self rangeBoundsWithScrollDirection:scrollDirection rangeTuningParameters:tuningParameters];
  return [self elementsWithinRangeBounds:rangeBounds map:map];
}

- (void)allElementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode displaySet:(NSHashTable<ASCollectionElement *> *__autoreleasing  _Nullable *)displaySet preloadSet:(NSHashTable<ASCollectionElement *> *__autoreleasing  _Nullable *)preloadSet map:(ASElementMap *)map
{
  if (displaySet == NULL || preloadSet == NULL) {
    return;
  }
  
  ASRangeTuningParameters displayParams = [self tuningParametersForRangeMode:rangeMode rangeType:ASLayoutRangeTypeDisplay];
  ASRangeTuningParameters preloadParams = [self tuningParametersForRangeMode:rangeMode rangeType:ASLayoutRangeTypePreload];
  CGRect displayBounds = [self rangeBoundsWithScrollDirection:scrollDirection rangeTuningParameters:displayParams];
  CGRect preloadBounds = [self rangeBoundsWithScrollDirection:scrollDirection rangeTuningParameters:preloadParams];
  
  CGRect unionBounds = CGRectUnion(displayBounds, preloadBounds);
  NSArray *layoutAttributes = [_collectionViewLayout layoutAttributesForElementsInRect:unionBounds];
  NSInteger count = layoutAttributes.count;

  __auto_type display = [[NSHashTable<ASCollectionElement *> alloc] initWithOptions:NSHashTableObjectPointerPersonality capacity:count];
  __auto_type preload = [[NSHashTable<ASCollectionElement *> alloc] initWithOptions:NSHashTableObjectPointerPersonality capacity:count];

  for (UICollectionViewLayoutAttributes *la in layoutAttributes) {
    // Manually filter out elements that don't intersect the range bounds.
    // See comment in elementsForItemsWithinRangeBounds:
    // This is re-implemented here so that the iteration over layoutAttributes can be done once to check both ranges.
    CGRect frame = la.frame;
    BOOL intersectsDisplay = CGRectIntersectsRect(displayBounds, frame);
    BOOL intersectsPreload = CGRectIntersectsRect(preloadBounds, frame);
    if (intersectsDisplay == NO && intersectsPreload == NO && CATransform3DIsIdentity(la.transform3D) == YES) {
      // Questionable why the element would be included here, but it doesn't belong.
      continue;
    }
    
    // Avoid excessive retains and releases, as well as property calls. We know the element is kept alive by map.
    __unsafe_unretained ASCollectionElement *e = [map elementForLayoutAttributes:la];
    if (e != nil && intersectsDisplay) {
      [display addObject:e];
    }
    if (e != nil && intersectsPreload) {
      [preload addObject:e];
    }
  }

  *displaySet = display;
  *preloadSet = preload;
  return;
}

- (NSHashTable<ASCollectionElement *> *)elementsWithinRangeBounds:(CGRect)rangeBounds map:(ASElementMap *)map
{
  NSArray *layoutAttributes = [_collectionViewLayout layoutAttributesForElementsInRect:rangeBounds];
  NSHashTable<ASCollectionElement *> *elementSet = [[NSHashTable alloc] initWithOptions:NSHashTableObjectPointerPersonality capacity:layoutAttributes.count];
  
  for (UICollectionViewLayoutAttributes *la in layoutAttributes) {
    // Manually filter out elements that don't intersect the range bounds.
    // If a layout returns elements outside the requested rect this can be a huge problem.
    // For instance in a paging flow, you may only want to preload 3 pages (one center, one on each side)
    // but if flow layout includes the 4th page (which it does! as of iOS 9&10), you will preload a 4th
    // page as well.
    if (CATransform3DIsIdentity(la.transform3D) && CGRectIntersectsRect(la.frame, rangeBounds) == NO) {
      continue;
    }
    [elementSet addObject:[map elementForLayoutAttributes:la]];
  }

  return elementSet;
}

- (CGRect)rangeBoundsWithScrollDirection:(ASScrollDirection)scrollDirection
                   rangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  CGRect rect = _collectionView.bounds;
  
  return CGRectExpandToRangeWithScrollableDirections(rect, tuningParameters, [_collectionView scrollableDirections], scrollDirection);
}

@end
#endif
