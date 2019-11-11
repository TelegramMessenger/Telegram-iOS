//
//  ASPageTable.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASPageTable.h>

ASPageCoordinate ASPageCoordinateMake(uint16_t x, uint16_t y)
{
  // Add 1 to the end result because 0 is not accepted by NSArray and NSMapTable.
  // To avoid overflow after adding, x and y can't be UINT16_MAX (0xFFFF) **at the same time**.
  // But for API simplification, we enforce the same restriction to both values.
  ASDisplayNodeCAssert(x < UINT16_MAX, @"x coordinate must be less than 65,535");
  ASDisplayNodeCAssert(y < UINT16_MAX, @"y coordinate must be less than 65,535");
  return (x << 16) + y + 1;
}

ASPageCoordinate ASPageCoordinateForPageThatContainsPoint(CGPoint point, CGSize pageSize)
{
  return ASPageCoordinateMake((MAX(0.0, point.x) / pageSize.width), (MAX(0.0, point.y) / pageSize.height));
}

uint16_t ASPageCoordinateGetX(ASPageCoordinate pageCoordinate)
{
  return (pageCoordinate - 1) >> 16;
}

uint16_t ASPageCoordinateGetY(ASPageCoordinate pageCoordinate)
{
  return (pageCoordinate - 1) & ~(0xFFFF<<16);
}

CGRect ASPageCoordinateGetPageRect(ASPageCoordinate pageCoordinate, CGSize pageSize)
{
  CGFloat pageWidth = pageSize.width;
  CGFloat pageHeight = pageSize.height;
  return CGRectMake(ASPageCoordinateGetX(pageCoordinate) * pageWidth, ASPageCoordinateGetY(pageCoordinate) * pageHeight, pageWidth, pageHeight);
}

NSPointerArray *ASPageCoordinatesForPagesThatIntersectRect(CGRect rect, CGSize contentSize, CGSize pageSize)
{
  CGRect contentRect = CGRectMake(0.0, 0.0, contentSize.width, contentSize.height);
  // Make sure the specified rect is within contentRect
  rect = CGRectIntersection(rect, contentRect);
  if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) {
    return nil;
  }
  
  NSPointerArray *result = [NSPointerArray pointerArrayWithOptions:(NSPointerFunctionsIntegerPersonality | NSPointerFunctionsOpaqueMemory)];
  
  ASPageCoordinate minPage = ASPageCoordinateForPageThatContainsPoint(CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)), pageSize);
  ASPageCoordinate maxPage = ASPageCoordinateForPageThatContainsPoint(CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)), pageSize);
  if (minPage == maxPage) {
    [result addPointer:(void *)minPage];
    return result;
  }
  
  NSUInteger minX = ASPageCoordinateGetX(minPage);
  NSUInteger minY = ASPageCoordinateGetY(minPage);
  NSUInteger maxX = ASPageCoordinateGetX(maxPage);
  NSUInteger maxY = ASPageCoordinateGetY(maxPage);
  
  for (NSUInteger x = minX; x <= maxX; x++) {
    for (NSUInteger y = minY; y <= maxY; y++) {
      ASPageCoordinate page = ASPageCoordinateMake(x, y);
      [result addPointer:(void *)page];
    }
  }
  
  return result;
}

@implementation NSMapTable (ASPageTableMethods)

+ (instancetype)pageTableWithValuePointerFunctions:(NSPointerFunctions *)valueFuncs NS_RETURNS_RETAINED
{
  static NSPointerFunctions *pageCoordinatesFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    pageCoordinatesFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsIntegerPersonality | NSPointerFunctionsOpaqueMemory];
  });
  
  return [[NSMapTable alloc] initWithKeyPointerFunctions:pageCoordinatesFuncs valuePointerFunctions:valueFuncs capacity:0];
}

+ (ASPageTable *)pageTableForStrongObjectPointers NS_RETURNS_RETAINED
{
  static NSPointerFunctions *strongObjectPointerFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    strongObjectPointerFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStrongMemory];
  });
  return [self pageTableWithValuePointerFunctions:strongObjectPointerFuncs];
}

+ (ASPageTable *)pageTableForWeakObjectPointers NS_RETURNS_RETAINED
{
  static NSPointerFunctions *weakObjectPointerFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    weakObjectPointerFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsWeakMemory];
  });
  return [self pageTableWithValuePointerFunctions:weakObjectPointerFuncs];
}

+ (ASPageToLayoutAttributesTable *)pageTableWithLayoutAttributes:(id<NSFastEnumeration>)layoutAttributesEnumerator contentSize:(CGSize)contentSize pageSize:(CGSize)pageSize NS_RETURNS_RETAINED
{
  ASPageToLayoutAttributesTable *result = [ASPageTable pageTableForStrongObjectPointers];
  for (UICollectionViewLayoutAttributes *attrs in layoutAttributesEnumerator) {
    // This attrs may span multiple pages. Make sure it's registered to all of them
    NSPointerArray *pages = ASPageCoordinatesForPagesThatIntersectRect(attrs.frame, contentSize, pageSize);
    
    for (id pagePtr in pages) {
      ASPageCoordinate page = (ASPageCoordinate)pagePtr;
      NSMutableArray<UICollectionViewLayoutAttributes *> *attrsInPage = [result objectForPage:page];
      if (attrsInPage == nil) {
        attrsInPage = [[NSMutableArray alloc] init];
        [result setObject:attrsInPage forPage:page];
      }
      [attrsInPage addObject:attrs];
    }
  }  
  return result;
}

- (id)objectForPage:(ASPageCoordinate)page
{
  __unsafe_unretained id key = (__bridge id)(void *)page;
  return [self objectForKey:key];
}

- (void)setObject:(id)object forPage:(ASPageCoordinate)page
{
  __unsafe_unretained id key = (__bridge id)(void *)page;
  [self setObject:object forKey:key];
}

- (void)removeObjectForPage:(ASPageCoordinate)page
{
  __unsafe_unretained id key = (__bridge id)(void *)page;
  [self removeObjectForKey:key];
}

@end

#endif
