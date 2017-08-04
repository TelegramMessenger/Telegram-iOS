//
//  ASLayout.mm
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

#import <AsyncDisplayKit/ASLayout.h>

#import <queue>

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASRectTable.h>

CGPoint const ASPointNull = {NAN, NAN};

extern BOOL ASPointIsNull(CGPoint point)
{
  return isnan(point.x) && isnan(point.y);
}

/**
 * Creates an defined number of "    |" indent blocks for the recursive description.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT NSString * descriptionIndents(NSUInteger indents)
{
  NSMutableString *description = [NSMutableString string];
  for (NSUInteger i = 0; i < indents; i++) {
    [description appendString:@"    |"];
  }
  if (indents > 0) {
    [description appendString:@" "];
  }
  return description;
}

ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT BOOL ASLayoutIsDisplayNodeType(ASLayout *layout)
{
  return layout.type == ASLayoutElementTypeDisplayNode;
}

ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT BOOL ASLayoutIsFlattened(ASLayout *layout)
{
  // A layout is flattened if its position is null, and all of its sublayouts are of type displaynode with no sublayouts.
  if (! ASPointIsNull(layout.position)) {
    return NO;
  }
  
  for (ASLayout *sublayout in layout.sublayouts) {
    if (ASLayoutIsDisplayNodeType(sublayout) == NO || sublayout.sublayouts.count > 0) {
      return NO;
    }
  }
  
  return YES;
}

@interface ASLayout () <ASDescriptionProvider>
{
  ASLayoutElementType _layoutElementType;
}

/*
 * Caches all sublayouts if set to YES or destroys the sublayout cache if set to NO. Defaults to NO
 */
@property (nonatomic, assign) BOOL retainSublayoutLayoutElements;

/**
 * Array for explicitly retain sublayout layout elements in case they are created and references in layoutSpecThatFits: and no one else will hold a strong reference on it
 */
@property (nonatomic, strong) NSMutableArray<id<ASLayoutElement>> *sublayoutLayoutElements;

@property (nonatomic, strong, readonly) ASRectTable<id<ASLayoutElement>, id> *elementToRectTable;

@end

@implementation ASLayout

@dynamic frame, type;

static std::atomic_bool static_retainsSublayoutLayoutElements = ATOMIC_VAR_INIT(NO);

+ (void)setShouldRetainSublayoutLayoutElements:(BOOL)shouldRetain
{
  static_retainsSublayoutLayoutElements.store(shouldRetain);
}

+ (BOOL)shouldRetainSublayoutLayoutElements
{
  return static_retainsSublayoutLayoutElements.load();
}

- (instancetype)initWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                 size:(CGSize)size
                             position:(CGPoint)position
                           sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  NSParameterAssert(layoutElement);
  
  self = [super init];
  if (self) {
#if DEBUG
    for (ASLayout *sublayout in sublayouts) {
      ASDisplayNodeAssert(ASPointIsNull(sublayout.position) == NO, @"Invalid position is not allowed in sublayout.");
    }
#endif
    
    _layoutElement = layoutElement;
    
    // Read this now to avoid @c weak overhead later.
    _layoutElementType = layoutElement.layoutElementType;
    
    if (!ASIsCGSizeValidForSize(size)) {
      ASDisplayNodeAssert(NO, @"layoutSize is invalid and unsafe to provide to Core Animation! Release configurations will force to 0, 0.  Size = %@, node = %@", NSStringFromCGSize(size), layoutElement);
      size = CGSizeZero;
    } else {
      size = CGSizeMake(ASCeilPixelValue(size.width), ASCeilPixelValue(size.height));
    }
    _size = size;
    
    if (ASPointIsNull(position) == NO) {
      _position = ASCeilPointValues(position);
    } else {
      _position = position;
    }

    _sublayouts = sublayouts != nil ? [sublayouts copy] : @[];

    if (_sublayouts.count > 0) {
      _elementToRectTable = [ASRectTable rectTableForWeakObjectPointers];
      for (ASLayout *layout in sublayouts) {
        [_elementToRectTable setRect:layout.frame forKey:layout.layoutElement];
      }
    }
    
    self.retainSublayoutLayoutElements = [ASLayout shouldRetainSublayoutLayoutElements];
  }
  
  return self;
}

- (instancetype)init
{
  ASDisplayNodeAssert(NO, @"Use the designated initializer");
  return [self init];
}

#pragma mark - Class Constructors

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                               position:(CGPoint)position
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [[self alloc] initWithLayoutElement:layoutElement
                                        size:size
                                    position:position
                                  sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [self layoutWithLayoutElement:layoutElement
                                  size:size
                              position:ASPointNull
                            sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement size:(CGSize)size
{
  return [self layoutWithLayoutElement:layoutElement
                                  size:size
                              position:ASPointNull
                            sublayouts:nil];
}

#pragma mark - Sublayout Elements Caching

- (void)setRetainSublayoutLayoutElements:(BOOL)retainSublayoutLayoutElements
{
  if (_retainSublayoutLayoutElements != retainSublayoutLayoutElements) {
    _retainSublayoutLayoutElements = retainSublayoutLayoutElements;
    
    if (retainSublayoutLayoutElements == NO) {
      _sublayoutLayoutElements = nil;
    } else {
      // Add sublayouts layout elements to an internal array to retain it while the layout lives
      NSUInteger sublayoutCount = _sublayouts.count;
      if (sublayoutCount > 0) {
        _sublayoutLayoutElements = [NSMutableArray arrayWithCapacity:sublayoutCount];
        for (ASLayout *sublayout in _sublayouts) {
          [_sublayoutLayoutElements addObject:sublayout.layoutElement];
        }
      }
    }
  }
}

#pragma mark - Layout Flattening

- (ASLayout *)filteredNodeLayoutTree
{
  if (ASLayoutIsFlattened(self)) {
    // All flattened layouts must have this flag enabled
    // to ensure sublayout elements are retained until the layouts are applied.
    self.retainSublayoutLayoutElements = YES;
    return self;
  }
  
  struct Context {
    ASLayout *layout;
    CGPoint absolutePosition;
  };
  
  // Queue used to keep track of sublayouts while traversing this layout in a DFS fashion.
  std::deque<Context> queue;
  for (ASLayout *sublayout in self.sublayouts) {
    queue.push_back({sublayout, sublayout.position});
  }
  
  NSMutableArray *flattenedSublayouts = [NSMutableArray array];
  
  while (!queue.empty()) {
    const Context context = queue.front();
    queue.pop_front();
    
    ASLayout *layout = context.layout;
    const NSArray<ASLayout *> *sublayouts = layout.sublayouts;
    const NSUInteger sublayoutsCount = sublayouts.count;
    const CGPoint absolutePosition = context.absolutePosition;
    
    if (ASLayoutIsDisplayNodeType(layout)) {
      if (sublayoutsCount > 0 || CGPointEqualToPoint(ASCeilPointValues(absolutePosition), layout.position) == NO) {
        // Only create a new layout if the existing one can't be reused, which means it has either some sublayouts or an invalid absolute position.
        layout = [ASLayout layoutWithLayoutElement:layout.layoutElement
                                              size:layout.size
                                          position:absolutePosition
                                        sublayouts:@[]];
      }
      [flattenedSublayouts addObject:layout];
    } else if (sublayoutsCount > 0){
      std::vector<Context> sublayoutContexts;
      for (ASLayout *sublayout in sublayouts) {
        sublayoutContexts.push_back({sublayout, context.absolutePosition + sublayout.position});
      }
      queue.insert(queue.cbegin(), sublayoutContexts.begin(), sublayoutContexts.end());
    }
  }
  
  ASLayout *layout = [ASLayout layoutWithLayoutElement:_layoutElement size:_size sublayouts:flattenedSublayouts];
  // All flattened layouts must have this flag enabled
  // to ensure sublayout elements are retained until the layouts are applied.
  layout.retainSublayoutLayoutElements = YES;
  return layout;
}

#pragma mark - Accessors

- (ASLayoutElementType)type
{
  return _layoutElementType;
}

- (CGRect)frameForElement:(id<ASLayoutElement>)layoutElement
{
  return _elementToRectTable ? [_elementToRectTable rectForKey:layoutElement] : CGRectNull;
}

- (CGRect)frame
{
  CGRect subnodeFrame = CGRectZero;
  CGPoint adjustedOrigin = _position;
  if (isfinite(adjustedOrigin.x) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedOrigin.x = 0;
  }
  if (isfinite(adjustedOrigin.y) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedOrigin.y = 0;
  }
  subnodeFrame.origin = adjustedOrigin;
  
  CGSize adjustedSize = _size;
  if (isfinite(adjustedSize.width) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid size");
    adjustedSize.width = 0;
  }
  if (isfinite(adjustedSize.height) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedSize.height = 0;
  }
  subnodeFrame.size = adjustedSize;
  
  return subnodeFrame;
}

#pragma mark - Description

- (NSMutableArray <NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *result = [NSMutableArray array];
  [result addObject:@{ @"size" : [NSValue valueWithCGSize:self.size] }];

  if (auto layoutElement = self.layoutElement) {
    [result addObject:@{ @"layoutElement" : layoutElement }];
  }

  auto pos = self.position;
  if (!ASPointIsNull(pos)) {
    [result addObject:@{ @"position" : [NSValue valueWithCGPoint:pos] }];
  }
  return result;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSString *)recursiveDescription
{
  return [self _recursiveDescriptionForLayout:self level:0];
}

- (NSString *)_recursiveDescriptionForLayout:(ASLayout *)layout level:(NSUInteger)level
{
  NSMutableString *description = [NSMutableString string];
  [description appendString:descriptionIndents(level)];
  [description appendString:[layout description]];
  for (ASLayout *sublayout in layout.sublayouts) {
    [description appendString:@"\n"];
    [description appendString:[self _recursiveDescriptionForLayout:sublayout level:level + 1]];
  }
  return description;
}

@end

@implementation ASLayout (Deprecation)

- (id <ASLayoutElement>)layoutableObject
{
  return self.layoutElement;
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutElement>)layoutElement
                      constrainedSizeRange:(ASSizeRange)constrainedSizeRange
                                      size:(CGSize)size
{
  return [self layoutWithLayoutElement:layoutElement size:size];
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutElement>)layoutElement
                      constrainedSizeRange:(ASSizeRange)constrainedSizeRange
                                      size:(CGSize)size
                                sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [self layoutWithLayoutElement:layoutElement size:size sublayouts:sublayouts];
}

@end

ASLayout *ASCalculateLayout(id<ASLayoutElement> layoutElement, const ASSizeRange sizeRange, const CGSize parentSize)
{
  ASDisplayNodeCAssertNotNil(layoutElement, @"Not valid layoutElement passed in.");
  
  return [layoutElement layoutThatFits:sizeRange parentSize:parentSize];
}

ASLayout *ASCalculateRootLayout(id<ASLayoutElement> rootLayoutElement, const ASSizeRange sizeRange)
{
  ASLayout *layout = ASCalculateLayout(rootLayoutElement, sizeRange, sizeRange.max);
  // Here could specific verfication happen
  return layout;
}
