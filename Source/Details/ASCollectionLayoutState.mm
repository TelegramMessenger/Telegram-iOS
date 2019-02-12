//
//  ASCollectionLayoutState.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASPageTable.h>
#import <AsyncDisplayKit/ASThread.h>

#import <queue>

@implementation NSMapTable (ASCollectionLayoutConvenience)

+ (NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *)elementToLayoutAttributesTable
{
  return [NSMapTable mapTableWithKeyOptions:(NSMapTableWeakMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableStrongMemory];
}

@end

@implementation ASCollectionLayoutState {
  ASDN::Mutex __instanceLock__;
  CGSize _contentSize;
  ASCollectionLayoutContext *_context;
  NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *_elementToLayoutAttributesTable;
  ASPageToLayoutAttributesTable *_pageToLayoutAttributesTable;
  ASPageToLayoutAttributesTable *_unmeasuredPageToLayoutAttributesTable;
}

- (instancetype)initWithContext:(ASCollectionLayoutContext *)context
{
  return [self initWithContext:context
                   contentSize:CGSizeZero
elementToLayoutAttributesTable:[NSMapTable elementToLayoutAttributesTable]];
}

- (instancetype)initWithContext:(ASCollectionLayoutContext *)context
                         layout:(ASLayout *)layout
                getElementBlock:(ASCollectionLayoutStateGetElementBlock)getElementBlock
{
  ASElementMap *elements = context.elements;
  NSMapTable *table = [NSMapTable elementToLayoutAttributesTable];

  // Traverse the given layout tree in breadth first fashion. Generate layout attributes for all included elements along the way. 
  struct Context {
    ASLayout *layout;
    CGPoint absolutePosition;
  };

  std::queue<Context> queue;
  queue.push({layout, CGPointZero});

  while (!queue.empty()) {
    Context context = queue.front();
    queue.pop();

    ASLayout *layout = context.layout;
    const CGPoint absolutePosition = context.absolutePosition;

    ASCollectionElement *element = getElementBlock(layout);
    if (element != nil) {
      NSIndexPath *indexPath = [elements indexPathForElement:element];
      NSString *supplementaryElementKind = element.supplementaryElementKind;

      UICollectionViewLayoutAttributes *attrs;
      if (supplementaryElementKind == nil) {
        attrs = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
      } else {
        attrs = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:supplementaryElementKind withIndexPath:indexPath];
      }

      CGRect frame = layout.frame;
      frame.origin = absolutePosition;
      attrs.frame = frame;
      [table setObject:attrs forKey:element];
    }

    // Add all sublayouts to process in next step
    for (ASLayout *sublayout in layout.sublayouts) {
      queue.push({sublayout, absolutePosition + sublayout.position});
    }
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

- (ASCollectionLayoutContext *)context
{
  return _context;
}

- (CGSize)contentSize
{
  return _contentSize;
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
  const auto result = [[NSMutableSet<UICollectionViewLayoutAttributes *> alloc] init];
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
{
  CGSize pageSize = _context.viewportSize;
  CGSize contentSize = _contentSize;

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
            intersectingAttrsInPage = [[NSMutableArray alloc] init];
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
  NSMutableArray<UICollectionViewLayoutAttributes *> *unmeasuredAttrs = [[NSMutableArray alloc] init];
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
