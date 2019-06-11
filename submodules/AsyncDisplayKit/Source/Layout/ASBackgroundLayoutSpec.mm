//
//  ASBackgroundLayoutSpec.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASBackgroundLayoutSpec.h>

#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCollections.h>

static NSUInteger const kForegroundChildIndex = 0;
static NSUInteger const kBackgroundChildIndex = 1;

@implementation ASBackgroundLayoutSpec

#pragma mark - Class

+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutElement>)child background:(id<ASLayoutElement>)background NS_RETURNS_RETAINED
{
  return [[self alloc] initWithChild:child background:background];
}

#pragma mark - Lifecycle

- (instancetype)initWithChild:(id<ASLayoutElement>)child background:(id<ASLayoutElement>)background
{
  if (!(self = [super init])) {
    return nil;
  }
  self.child = child;
  self.background = background;
  return self;
}

#pragma mark - ASLayoutSpec

/**
 * First layout the contents, then fit the background image.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  ASLayout *contentsLayout = [self.child layoutThatFits:constrainedSize parentSize:parentSize];

  ASLayout *rawSublayouts[2];
  int i = 0;
  if (self.background) {
    // Size background to exactly the same size.
    ASLayout *backgroundLayout = [self.background layoutThatFits:ASSizeRangeMake(contentsLayout.size)
                                                      parentSize:parentSize];
    backgroundLayout.position = CGPointZero;
    rawSublayouts[i++] = backgroundLayout;
  }
  contentsLayout.position = CGPointZero;
  rawSublayouts[i++] = contentsLayout;

  const auto sublayouts = [NSArray<ASLayout *> arrayByTransferring:rawSublayouts count:i];
  return [ASLayout layoutWithLayoutElement:self size:contentsLayout.size sublayouts:sublayouts];
}

#pragma mark - Background

- (void)setChild:(id<ASLayoutElement>)child
{
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  [super setChild:child atIndex:kForegroundChildIndex];
}

- (id<ASLayoutElement>)child
{
  return [super childAtIndex:kForegroundChildIndex];
}

- (void)setBackground:(id<ASLayoutElement>)background
{
  ASDisplayNodeAssertNotNil(background, @"Background cannot be nil");
  [super setChild:background atIndex:kBackgroundChildIndex];
}

- (id<ASLayoutElement>)background
{
  return [super childAtIndex:kBackgroundChildIndex];
}

@end
