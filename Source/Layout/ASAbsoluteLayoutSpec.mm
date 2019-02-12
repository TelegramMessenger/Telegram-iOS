//
//  ASAbsoluteLayoutSpec.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAbsoluteLayoutSpec.h>

#import <AsyncDisplayKit/ASCollections.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>
#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASLayoutElementStylePrivate.h>

#pragma mark - ASAbsoluteLayoutSpec

@implementation ASAbsoluteLayoutSpec

#pragma mark - Class

+ (instancetype)absoluteLayoutSpecWithChildren:(NSArray *)children NS_RETURNS_RETAINED
{
  return [[self alloc] initWithChildren:children];
}

+ (instancetype)absoluteLayoutSpecWithSizing:(ASAbsoluteLayoutSpecSizing)sizing children:(NSArray<id<ASLayoutElement>> *)children NS_RETURNS_RETAINED
{
  return [[self alloc] initWithSizing:sizing children:children];
}

#pragma mark - Lifecycle

- (instancetype)init
{
  return [self initWithChildren:nil];
}

- (instancetype)initWithChildren:(NSArray *)children
{
  return [self initWithSizing:ASAbsoluteLayoutSpecSizingDefault children:children];
}

- (instancetype)initWithSizing:(ASAbsoluteLayoutSpecSizing)sizing children:(NSArray<id<ASLayoutElement>> *)children
{
  if (!(self = [super init])) {
    return nil;
  }

  _sizing = sizing;
  self.children = children;

  return self;
}

#pragma mark - ASLayoutSpec

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  CGSize size = {
    ASPointsValidForSize(constrainedSize.max.width) == NO ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.width,
    ASPointsValidForSize(constrainedSize.max.height) == NO ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.height
  };
  
  NSArray *children = self.children;
  ASLayout *rawSublayouts[children.count];
  int i = 0;

  for (id<ASLayoutElement> child in children) {
    CGPoint layoutPosition = child.style.layoutPosition;
    CGSize autoMaxSize = {
      constrainedSize.max.width  - layoutPosition.x,
      constrainedSize.max.height - layoutPosition.y
    };

    const ASSizeRange childConstraint = ASLayoutElementSizeResolveAutoSize(child.style.size, size, {{0,0}, autoMaxSize});
    
    ASLayout *sublayout = [child layoutThatFits:childConstraint parentSize:size];
    sublayout.position = layoutPosition;
    rawSublayouts[i++] = sublayout;
  }
  const auto sublayouts = [NSArray<ASLayout *> arrayByTransferring:rawSublayouts count:i];

  if (_sizing == ASAbsoluteLayoutSpecSizingSizeToFit || isnan(size.width)) {
    size.width = constrainedSize.min.width;
    for (ASLayout *sublayout in sublayouts) {
      size.width = MAX(size.width,  sublayout.position.x + sublayout.size.width);
    }
  }
  
  if (_sizing == ASAbsoluteLayoutSpecSizingSizeToFit || isnan(size.height)) {
    size.height = constrainedSize.min.height;
    for (ASLayout *sublayout in sublayouts) {
      size.height = MAX(size.height, sublayout.position.y + sublayout.size.height);
    }
  }
  
  return [ASLayout layoutWithLayoutElement:self size:ASSizeRangeClamp(constrainedSize, size) sublayouts:sublayouts];
}

@end

