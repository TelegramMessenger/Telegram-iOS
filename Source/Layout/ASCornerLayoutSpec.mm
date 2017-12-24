//
//  ASCornerLayoutSpec.mm
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASCornerLayoutSpec.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

CGPoint as_calculatedCornerOriginIn(CGRect baseFrame, CGSize cornerSize, ASCornerLayoutLocation cornerLocation, CGPoint offset)
{
  CGPoint cornerOrigin = CGPointZero;
  CGPoint baseOrigin = baseFrame.origin;
  CGSize baseSize = baseFrame.size;
  
  switch (cornerLocation) {
    case ASCornerLayoutLocationTopLeft:
      cornerOrigin.x = baseOrigin.x - cornerSize.width / 2;
      cornerOrigin.y = baseOrigin.y - cornerSize.height / 2;
      break;
    case ASCornerLayoutLocationTopRight:
      cornerOrigin.x = baseOrigin.x + baseSize.width - cornerSize.width / 2;
      cornerOrigin.y = baseOrigin.y - cornerSize.height / 2;
      break;
    case ASCornerLayoutLocationBottomLeft:
      cornerOrigin.x = baseOrigin.x - cornerSize.width / 2;
      cornerOrigin.y = baseOrigin.y + baseSize.height - cornerSize.height / 2;
      break;
    case ASCornerLayoutLocationBottomRight:
      cornerOrigin.x = baseOrigin.x + baseSize.width - cornerSize.width / 2;
      cornerOrigin.y = baseOrigin.y + baseSize.height - cornerSize.height / 2;
      break;
  }
  
  cornerOrigin.x += offset.x;
  cornerOrigin.y += offset.y;
  
  return cornerOrigin;
}

static NSUInteger const kBaseChildIndex = 0;
static NSUInteger const kCornerChildIndex = 1;

@interface ASCornerLayoutSpec()
@end

@implementation ASCornerLayoutSpec

- (instancetype)initWithChild:(id <ASLayoutElement>)child corner:(id <ASLayoutElement>)corner location:(ASCornerLayoutLocation)location
{
  self = [super init];
  if (self) {
    self.child = child;
    self.corner = corner;
    self.cornerLocation = location;
  }
  return self;
}

+ (instancetype)cornerLayoutSpecWithChild:(id <ASLayoutElement>)child corner:(id <ASLayoutElement>)corner location:(ASCornerLayoutLocation)location
{
  return [[self alloc] initWithChild:child corner:corner location:location];
}

#pragma mark - Children

- (void)setChild:(id<ASLayoutElement>)child
{
  ASDisplayNodeAssertNotNil(child, @"Child shouldn't be nil.");
  [super setChild:child atIndex:kBaseChildIndex];
}

- (id<ASLayoutElement>)child
{
  return [super childAtIndex:kBaseChildIndex];
}

- (void)setCorner:(id<ASLayoutElement>)corner
{
  ASDisplayNodeAssertNotNil(corner, @"Corner element cannot be nil.");
  [super setChild:corner atIndex:kCornerChildIndex];
}

- (id<ASLayoutElement>)corner
{
  return [super childAtIndex:kCornerChildIndex];
}

#pragma mark - Calculation

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  CGSize size = {
    ASPointsValidForSize(constrainedSize.max.width) == NO ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.width,
    ASPointsValidForSize(constrainedSize.max.height) == NO ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.height
  };
  
  id <ASLayoutElement> child = self.child;
  id <ASLayoutElement> corner = self.corner;
  
  // Element validation
  [self _validateElement:child];
  [self _validateElement:corner];
  
  CGRect childFrame = CGRectZero;
  CGRect cornerFrame = CGRectZero;
  
  // Layout child
  ASLayout *childLayout = [child layoutThatFits:constrainedSize parentSize:size];
  childFrame.size = childLayout.size;
  
  // Layout corner
  ASLayout *cornerLayout = [corner layoutThatFits:constrainedSize parentSize:size];
  cornerFrame.size = cornerLayout.size;
  
  // Calculate corner's position
  CGPoint relativePosition = as_calculatedCornerOriginIn(childFrame, cornerFrame.size, _cornerLocation, _offset);
  
  // Update corner's position
  cornerFrame.origin = relativePosition;
  
  // Calculate size
  CGRect frame = childFrame;
  if (_wrapsCorner) {
    frame = CGRectUnion(childFrame, cornerFrame);
    frame.size = ASSizeRangeClamp(constrainedSize, frame.size);
  }
  
  // Shift sublayouts' positions if they are off the bounds.
  if (frame.origin.x != 0) {
    CGFloat deltaX = frame.origin.x;
    childFrame.origin.x -= deltaX;
    cornerFrame.origin.x -= deltaX;
  }
  
  if (frame.origin.y != 0) {
    CGFloat deltaY = frame.origin.y;
    childFrame.origin.y -= deltaY;
    cornerFrame.origin.y -= deltaY;
  }
  
  childLayout.position = childFrame.origin;
  cornerLayout.position = cornerFrame.origin;
  
  return [ASLayout layoutWithLayoutElement:self size:frame.size sublayouts:@[childLayout, cornerLayout]];
}

- (void)_validateElement:(id <ASLayoutElement>)element
{
  // Validate non-nil element
  if (element == nil) {
    ASDisplayNodeAssertNotNil(element, @"[%@]: Must have a non-nil child/corner for layout calculation.", self.class);
  }
  // Validate preferredSize if needed
  CGSize size = element.style.preferredSize;
  if (!CGSizeEqualToSize(size, CGSizeZero) && !ASIsCGSizeValidForSize(size) && (size.width < 0 || (size.height < 0))) {
    ASDisplayNodeFailAssert(@"[%@]: Should give a valid preferredSize value for %@ before corner's position calculation.", self.class, element);
  }
}

@end
