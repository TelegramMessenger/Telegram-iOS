//
//  ASCollectionLayoutState.mm
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASCollectionLayoutState+Private.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollectionLayoutContext.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASPageTable.h>
#import <AsyncDisplayKit/ASThread.h>

@implementation NSMapTable (ASCollectionLayoutConvenience)

+ (NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *)elementToLayoutAttributesTable
{
  return [NSMapTable mapTableWithKeyOptions:(NSMapTableWeakMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableStrongMemory];
}

@end

@implementation ASCollectionLayoutState {
  ASDN::Mutex __instanceLock__;
  NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *_elementToLayoutAttributesTable;
  ASPageToLayoutAttributesTable *_pageToLayoutAttributesTable;
  ASPageToLayoutAttributesTable *_unmeasuredPageToLayoutAttributesTable;
}

- (instancetype)initWithContext:(ASCollectionLayoutContext *)context
                         layout:(ASLayout *)layout
                getElementBlock:(ASCollectionElement *(^)(ASLayout *))getElementBlock
{
  ASElementMap *elements = context.elements;
  NSMapTable *table = [NSMapTable elementToLayoutAttributesTable];
  
  for (ASLayout *sublayout in layout.sublayouts) {
    ASCollectionElement *element = getElementBlock(sublayout);
    if (element == nil) {
      ASDisplayNodeFailAssert(@"Element not found!");
      continue;
    }
    
    NSIndexPath *indexPath = [elements indexPathForElement:element];
    NSString *supplementaryElementKind = element.supplementaryElementKind;
    
    UICollectionViewLayoutAttributes *attrs;
    if (supplementaryElementKind == nil) {
      attrs = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    } else {
      attrs = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:supplementaryElementKind withIndexPath:indexPath];
    }
    
    attrs.frame = sublayout.frame;
    [table setObject:attrs forKey:element];
  }

  return [self initWithContext:context contentSize:layout.size elementToLayoutAttributesTable:table];
}

- (instancetype)initWithContext:(ASCollectionLayoutContext *)context
                    contentSize:(CGSize)contentSize
 elementToLayoutAttributesTable:(NSMapTable *)table
{
  self = [super init];
  if (self) {
    _context = context;
    _contentSize = contentSize;
    _elementToLayoutAttributesTable = [table copy]; // Copy the given table to make sure clients can't mutate it after this point.
    CGSize pageSize = context.viewportSize;
    _pageToLayoutAttributesTable = [ASPageTable pageTableWithLayoutAttributes:table.objectEnumerator contentSize:contentSize pageSize:pageSize];
    _unmeasuredPageToLayoutAttributesTable = [ASCollectionLayoutState _unmeasuredLayoutAttributesTableFromTable:table contentSize:contentSize pageSize:pageSize];
  }
  return self;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)allLayoutAttributes
{
  return [_elementToLayoutAttributesTable.objectEnumerator allObjects];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionElement *element = [_context.elements elementForItemAtIndexPath:indexPath];
  return [_elementToLayoutAttributesTable objectForKey:element];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)elementKind
                                                                        atIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionElement *element = [_context.elements supplementaryElementOfKind:elementKind atIndexPath:indexPath];
  return [_elementToLayoutAttributesTable objectForKey:element];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForElement:(ASCollectionElement *)element
{
  return [_elementToLayoutAttributesTable objectForKey:element];
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
  CGSize pageSize = _context.viewportSize;
  NSPointerArray *pages = ASPageCoordinatesForPagesThatIntersectRect(rect, _contentSize, pageSize);
  if (pages.count == 0) {
    return @[];
  }

  // Use a set here because some items may span multiple pages
  NSMutableSet<UICollectionViewLayoutAttributes *> *result = [NSMutableSet set];
  for (id pagePtr in pages) {
    ASPageCoordinate page = (ASPageCoordinate)pagePtr;
    NSArray<UICollectionViewLayoutAttributes *> *allAttrs = [_pageToLayoutAttributesTable objectForPage:page];
    if (allAttrs.count > 0) {
      CGRect pageRect = ASPageCoordinateGetPageRect(page, pageSize);

      if (CGRectContainsRect(rect, pageRect)) {
        [result addObjectsFromArray:allAttrs];
      } else {
        for (UICollectionViewLayoutAttributes *attrs in allAttrs) {
          if (CGRectIntersectsRect(rect, attrs.frame)) {
            [result addObject:attrs];
          }
        }
      }
    }
  }

  return [result allObjects];
}

- (ASPageToLayoutAttributesTable *)getAndRemoveUnmeasuredLayoutAttributesPageTableInRect:(CGRect)rect
                                                                             contentSize:(CGSize)contentSize
                                                                                pageSize:(CGSize)pageSize
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_unmeasuredPageToLayoutAttributesTable.count == 0 || CGRectIsNull(rect) || CGRectIsEmpty(rect) || CGSizeEqualToSize(CGSizeZero, contentSize) || CGSizeEqualToSize(CGSizeZero, pageSize)) {
    return nil;
  }

  // Step 1: Determine all the pages that intersect the specified rect
  NSPointerArray *pagesInRect = ASPageCoordinatesForPagesThatIntersectRect(rect, contentSize, pageSize);
  if (pagesInRect.count == 0) {
    return nil;
  }

  // Step 2: Filter out attributes in these pages that intersect the specified rect.
  ASPageToLayoutAttributesTable *result = nil;
  for (id pagePtr in pagesInRect) {
    ASPageCoordinate page = (ASPageCoordinate)pagePtr;
    NSMutableArray *attrsInPage = [_unmeasuredPageToLayoutAttributesTable objectForPage:page];
    if (attrsInPage.count == 0) {
      continue;
    }

    NSMutableArray *intersectingAttrsInPage = nil;
    CGRect pageRect = ASPageCoordinateGetPageRect(page, pageSize);
    if (CGRectContainsRect(rect, pageRect)) {
      // This page fits well within the specified rect. Simply return all of its attributes.
      intersectingAttrsInPage = attrsInPage;
    } else {
      // The page intersects the specified rect. Some attributes in this page are returned, some are not.
      for (UICollectionViewLayoutAttributes *attrs in attrsInPage) {
        if (CGRectIntersectsRect(rect, attrs.frame)) {
          if (intersectingAttrsInPage == nil) {
            intersectingAttrsInPage = [NSMutableArray array];
          }
          [intersectingAttrsInPage addObject:attrs];
        }
      }
    }

    if (intersectingAttrsInPage.count > 0) {
      if (attrsInPage.count == intersectingAttrsInPage.count) {
        [_unmeasuredPageToLayoutAttributesTable removeObjectForPage:page];
      } else {
        [attrsInPage removeObjectsInArray:intersectingAttrsInPage];
      }
      if (result == nil) {
        result = [ASPageTable pageTableForStrongObjectPointers];
      }
      [result setObject:intersectingAttrsInPage forPage:page];
    }
  }

  return result;
}

#pragma mark - Private methods

+ (ASPageToLayoutAttributesTable *)_unmeasuredLayoutAttributesTableFromTable:(NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *)table
                                                                 contentSize:(CGSize)contentSize
                                                                    pageSize:(CGSize)pageSize
{
  NSMutableArray<UICollectionViewLayoutAttributes *> *unmeasuredAttrs = [NSMutableArray array];
  for (ASCollectionElement *element in table) {
    UICollectionViewLayoutAttributes *attrs = [table objectForKey:element];
    if (element.nodeIfAllocated == nil || CGSizeEqualToSize(element.nodeIfAllocated.calculatedSize, attrs.frame.size) == NO) {
      [unmeasuredAttrs addObject:attrs];
    }
  }

  return [ASPageTable pageTableWithLayoutAttributes:unmeasuredAttrs contentSize:contentSize pageSize:pageSize];
}

@end

#endif
