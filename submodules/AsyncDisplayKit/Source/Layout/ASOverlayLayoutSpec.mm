//
//  ASOverlayLayoutSpec.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASOverlayLayoutSpec.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCollections.h>

static NSUInteger const kUnderlayChildIndex = 0;
static NSUInteger const kOverlayChildIndex = 1;

@implementation ASOverlayLayoutSpec

#pragma mark - Class

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutElement>)child overlay:(id<ASLayoutElement>)overlay NS_RETURNS_RETAINED
{
  return [[self alloc] initWithChild:child overlay:overlay];
}

#pragma mark - Lifecycle

- (instancetype)initWithChild:(id<ASLayoutElement>)child overlay:(id<ASLayoutElement>)overlay
{
  if (!(self = [super init])) {
    return nil;
  }
  self.child = child;
  self.overlay = overlay;
  return self;
}

#pragma mark - Setter / Getter

- (void)setChild:(id<ASLayoutElement>)child
{
  ASDisplayNodeAssertNotNil(child, @"Child that will be overlayed on shouldn't be nil");
  [super setChild:child atIndex:kUnderlayChildIndex];
}

- (id<ASLayoutElement>)child
{
  return [super childAtIndex:kUnderlayChildIndex];
}

- (void)setOverlay:(id<ASLayoutElement>)overlay
{
  ASDisplayNodeAssertNotNil(overlay, @"Overlay cannot be nil");
  [super setChild:overlay atIndex:kOverlayChildIndex];
}

- (id<ASLayoutElement>)overlay
{
  return [super childAtIndex:kOverlayChildIndex];
}

#pragma mark - ASLayoutSpec

/**
 First layout the contents, then fit the overlay on top of it.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  ASLayout *contentsLayout = [self.child layoutThatFits:constrainedSize parentSize:parentSize];
  contentsLayout.position = CGPointZero;
  ASLayout *rawSublayouts[2];
  int i = 0;
  rawSublayouts[i++] = contentsLayout;
  if (self.overlay) {
    ASLayout *overlayLayout = [self.overlay layoutThatFits:ASSizeRangeMake(contentsLayout.size)
                                                parentSize:contentsLayout.size];
    overlayLayout.position = CGPointZero;
    rawSublayouts[i++] = overlayLayout;
  }
  
  const auto sublayouts = [NSArray<ASLayout *> arrayByTransferring:rawSublayouts count:i];
  return [ASLayout layoutWithLayoutElement:self size:contentsLayout.size sublayouts:sublayouts];
}

@end
