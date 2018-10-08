//
//  ASLayoutSpec+Subclasses.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

#import <AsyncDisplayKit/ASLayoutSpec.h>
#import <AsyncDisplayKit/ASLayoutSpecPrivate.h>

#pragma mark - ASNullLayoutSpec

@interface ASNullLayoutSpec : ASLayoutSpec
- (instancetype)init NS_UNAVAILABLE;
+ (ASNullLayoutSpec *)null;
@end

@implementation ASNullLayoutSpec : ASLayoutSpec

+ (ASNullLayoutSpec *)null
{
  static ASNullLayoutSpec *sharedNullLayoutSpec = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedNullLayoutSpec = [[self alloc] init];
  });
  return sharedNullLayoutSpec;
}

- (BOOL)isMutable
{
  return NO;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutElement:self size:CGSizeZero];
}

@end


#pragma mark - ASLayoutSpec (Subclassing)

@implementation ASLayoutSpec (Subclassing)

#pragma mark - Child with index

- (void)setChild:(id<ASLayoutElement>)child atIndex:(NSUInteger)index
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  id<ASLayoutElement> layoutElement = child ?: [ASNullLayoutSpec null];
  
  if (child) {
    if (_childrenArray.count < index) {
      // Fill up the array with null objects until the index
      NSInteger i = _childrenArray.count;
      while (i < index) {
        _childrenArray[i] = [ASNullLayoutSpec null];
        i++;
      }
    }
  }
  
  // Replace object at the given index with the layoutElement
  _childrenArray[index] = layoutElement;
}

- (id<ASLayoutElement>)childAtIndex:(NSUInteger)index
{
  id<ASLayoutElement> layoutElement = nil;
  if (index < _childrenArray.count) {
    layoutElement = _childrenArray[index];
  }
  
  // Null layoutElement should not be accessed
  ASDisplayNodeAssert(layoutElement != [ASNullLayoutSpec null], @"Access child at index without set a child at that index");

  return layoutElement;
}

@end
