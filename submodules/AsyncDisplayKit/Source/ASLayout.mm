//
//  ASLayout.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayout.h>

#import <atomic>
#import <queue>

#import <AsyncDisplayKit/ASCollections.h>
#import <AsyncDisplayKit/ASDimension.h>
#import "ASLayoutSpecUtilities.h"
#import "ASLayoutSpec+Subclasses.h"

#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

NSString *const ASThreadDictMaxConstraintSizeKey = @"kASThreadDictMaxConstraintSizeKey";

CGPoint const ASPointNull = {NAN, NAN};

BOOL ASPointIsNull(CGPoint point)
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

@interface ASLayout () <ASDescriptionProvider>
{
  ASLayoutElementType _layoutElementType;
  std::atomic_bool _retainSublayoutElements;
}
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
#if ASDISPLAYNODE_ASSERTIONS_ENABLED
    for (ASLayout *sublayout in sublayouts) {
      ASDisplayNodeAssert(ASPointIsNull(sublayout.position) == NO, @"Invalid position is not allowed in sublayout.");
    }
#endif
    
    _layoutElement = layoutElement;
    
    // Read this now to avoid @c weak overhead later.
    _layoutElementType = layoutElement.layoutElementType;
    
    if (!ASIsCGSizeValidForSize(size)) {
      //ASDisplayNodeFailAssert(@"layoutSize is invalid and unsafe to provide to Core Animation! Release configurations will force to 0, 0.  Size = %@, node = %@", NSStringFromCGSize(size), layoutElement);
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

    _sublayouts = [sublayouts copy] ?: @[];
    
    if ([ASLayout shouldRetainSublayoutLayoutElements]) {
      [self retainSublayoutElements];
    }
  }
  
  return self;
}

#pragma mark - Class Constructors

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                               position:(CGPoint)position
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts NS_RETURNS_RETAINED
{
  return [[self alloc] initWithLayoutElement:layoutElement
                                        size:size
                                    position:position
                                  sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement
                                   size:(CGSize)size
                             sublayouts:(nullable NSArray<ASLayout *> *)sublayouts NS_RETURNS_RETAINED
{
  return [self layoutWithLayoutElement:layoutElement
                                  size:size
                              position:ASPointNull
                            sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<ASLayoutElement>)layoutElement size:(CGSize)size NS_RETURNS_RETAINED
{
  return [self layoutWithLayoutElement:layoutElement
                                  size:size
                              position:ASPointNull
                            sublayouts:nil];
}

- (void)dealloc
{
  if (_retainSublayoutElements.load()) {
    for (ASLayout *sublayout in _sublayouts) {
      // We retained this, so there's no risk of it deallocating on us.
      if (CFTypeRef cfElement = (__bridge CFTypeRef)sublayout->_layoutElement) {
        CFRelease(cfElement);
      }
    }
  }
}

#pragma mark - Sublayout Elements Caching

- (void)retainSublayoutElements
{
  if (_retainSublayoutElements.exchange(true)) {
    return;
  }
  
  for (ASLayout *sublayout in _sublayouts) {
    // CFBridgingRetain atomically casts and retains. We need the atomicity.
    CFBridgingRetain(sublayout->_layoutElement);
  }
}

#pragma mark - Layout Flattening

- (BOOL)isFlattened
{
  // A layout is flattened if its position is null, and all of its sublayouts are of type displaynode with no sublayouts.
  if (!ASPointIsNull(_position)) {
    return NO;
  }
  
  for (ASLayout *sublayout in _sublayouts) {
    if (ASLayoutIsDisplayNodeType(sublayout) == NO || sublayout->_sublayouts.count > 0) {
      return NO;
    }
  }
  
  return YES;
}

- (ASLayout *)filteredNodeLayoutTree NS_RETURNS_RETAINED
{
  if ([self isFlattened]) {
    // All flattened layouts must retain sublayout elements until they are applied.
    [self retainSublayoutElements];
    return self;
  }
  
  struct Context {
    unowned ASLayout *layout;
    CGPoint absolutePosition;
  };
  
  // Queue used to keep track of sublayouts while traversing this layout in a DFS fashion.
  std::deque<Context> queue;
  for (ASLayout *sublayout in _sublayouts) {
    queue.push_back({sublayout, sublayout.position});
  }
  
  std::vector<ASLayout *> flattenedSublayouts;
  
  while (!queue.empty()) {
    const Context context = std::move(queue.front());
    queue.pop_front();
    
    unowned ASLayout *layout = context.layout;
    // Direct ivar access to avoid retain/release, use existing +1.
    const NSUInteger sublayoutsCount = layout->_sublayouts.count;
    const CGPoint absolutePosition = context.absolutePosition;
    
    if (ASLayoutIsDisplayNodeType(layout)) {
      if (sublayoutsCount > 0 || CGPointEqualToPoint(ASCeilPointValues(absolutePosition), layout.position) == NO) {
        // Only create a new layout if the existing one can't be reused, which means it has either some sublayouts or an invalid absolute position.
        const auto newLayout = [ASLayout layoutWithLayoutElement:layout->_layoutElement
                                                     size:layout.size
                                                 position:absolutePosition
                                               sublayouts:@[]];
        flattenedSublayouts.push_back(newLayout);
      } else {
        flattenedSublayouts.push_back(layout);
      }
    } else if (sublayoutsCount > 0) {
      // Fast-reverse-enumerate the sublayouts array by copying it into a C-array and push_front'ing each into the queue.
      unowned ASLayout *rawSublayouts[sublayoutsCount];
      [layout->_sublayouts getObjects:rawSublayouts range:NSMakeRange(0, sublayoutsCount)];
      for (NSInteger i = sublayoutsCount - 1; i >= 0; i--) {
        queue.push_front({rawSublayouts[i], absolutePosition + rawSublayouts[i].position});
      }
    }
  }
  
  NSArray *array = [NSArray arrayByTransferring:flattenedSublayouts.data() count:flattenedSublayouts.size()];
  // flattenedSublayouts is now all nils.
  
  ASLayout *layout = [ASLayout layoutWithLayoutElement:_layoutElement size:_size sublayouts:array];
  // All flattened layouts must retain sublayout elements until they are applied.
  [layout retainSublayoutElements];
  return layout;
}

#pragma mark - Equality Checking

- (BOOL)isEqual:(id)object
{
  if (self == object) return YES;

  ASLayout *layout = ASDynamicCast(object, ASLayout);
  if (layout == nil) {
    return NO;
  }

  if (!CGSizeEqualToSize(_size, layout.size)) return NO;

  if (!((ASPointIsNull(self.position) && ASPointIsNull(layout.position))
        || CGPointEqualToPoint(self.position, layout.position))) return NO;
  if (_layoutElement != layout.layoutElement) return NO;

  if (!ASObjectIsEqual(_sublayouts, layout.sublayouts)) {
    return NO;
  }

  return YES;
}

#pragma mark - Accessors

- (ASLayoutElementType)type
{
  return _layoutElementType;
}

- (CGRect)frameForElement:(id<ASLayoutElement>)layoutElement
{
  for (ASLayout *l in _sublayouts) {
    if (l->_layoutElement == layoutElement) {
      return l.frame;
    }
  }
  return CGRectNull;
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

  if (id<ASLayoutElement> layoutElement = self.layoutElement) {
    [result addObject:@{ @"layoutElement" : layoutElement }];
  }

  const auto pos = self.position;
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

ASLayout *ASCalculateLayout(id<ASLayoutElement> layoutElement, const ASSizeRange sizeRange, const CGSize parentSize)
{
  NSCParameterAssert(layoutElement != nil);
  
  return [layoutElement layoutThatFits:sizeRange parentSize:parentSize];
}

ASLayout *ASCalculateRootLayout(id<ASLayoutElement> rootLayoutElement, const ASSizeRange sizeRange)
{
  ASLayout *layout = ASCalculateLayout(rootLayoutElement, sizeRange, sizeRange.max);
  // Here could specific verfication happen
  return layout;
}
