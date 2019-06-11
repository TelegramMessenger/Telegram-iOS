//
//  MosaicCollectionLayoutDelegate.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "MosaicCollectionLayoutDelegate.h"
#import "MosaicCollectionLayoutInfo.h"
#import "ImageCellNode.h"

#import <AsyncDisplayKit/ASCollectionElement.h>

@implementation MosaicCollectionLayoutDelegate {
  // Read-only properties
  MosaicCollectionLayoutInfo *_info;
}

- (instancetype)initWithNumberOfColumns:(NSInteger)numberOfColumns headerHeight:(CGFloat)headerHeight
{
  self = [super init];
  if (self != nil) {
    _info = [[MosaicCollectionLayoutInfo alloc] initWithNumberOfColumns:numberOfColumns
                                                           headerHeight:headerHeight
                                                          columnSpacing:10.0
                                                          sectionInsets:UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0)
                                                       interItemSpacing:UIEdgeInsetsMake(10.0, 0, 10.0, 0)];
  }
  return self;
}

- (ASScrollDirection)scrollableDirections
{
  ASDisplayNodeAssertMainThread();
  return ASScrollDirectionVerticalDirections;
}

- (id)additionalInfoForLayoutWithElements:(ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();
  return _info;
}

+ (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context
{
  CGFloat layoutWidth = context.viewportSize.width;
  ASElementMap *elements = context.elements;
  CGFloat top = 0;
  MosaicCollectionLayoutInfo *info = (MosaicCollectionLayoutInfo *)context.additionalInfo;
  
  NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *attrsMap = [NSMapTable elementToLayoutAttributesTable];
  NSMutableArray *columnHeights = [NSMutableArray array];
  
  NSInteger numberOfSections = [elements numberOfSections];
  for (NSUInteger section = 0; section < numberOfSections; section++) {
    NSInteger numberOfItems = [elements numberOfItemsInSection:section];
    
    top += info.sectionInsets.top;
    
    if (info.headerHeight > 0) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:section];
      ASCollectionElement *element = [elements supplementaryElementOfKind:UICollectionElementKindSectionHeader
                                                              atIndexPath:indexPath];
      UICollectionViewLayoutAttributes *attrs = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                                                                               withIndexPath:indexPath];
      
      ASSizeRange sizeRange = [self _sizeRangeForHeaderOfSection:section withLayoutWidth:layoutWidth info:info];
      CGSize size = [element.node layoutThatFits:sizeRange].size;
      CGRect frame = CGRectMake(info.sectionInsets.left, top, size.width, size.height);
      
      attrs.frame = frame;
      [attrsMap setObject:attrs forKey:element];
      top = CGRectGetMaxY(frame);
    }
    
    [columnHeights addObject:[NSMutableArray array]];
    for (NSUInteger idx = 0; idx < info.numberOfColumns; idx++) {
      [columnHeights[section] addObject:@(top)];
    }
    
    CGFloat columnWidth = [self _columnWidthForSection:section withLayoutWidth:layoutWidth info:info];
    for (NSUInteger idx = 0; idx < numberOfItems; idx++) {
      NSUInteger columnIndex = [self _shortestColumnIndexInSection:section withColumnHeights:columnHeights];
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:section];
      ASCollectionElement *element = [elements elementForItemAtIndexPath:indexPath];
      UICollectionViewLayoutAttributes *attrs = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
      
      ASSizeRange sizeRange = [self _sizeRangeForItem:element.node atIndexPath:indexPath withLayoutWidth:layoutWidth info:info];
      CGSize size = [element.node layoutThatFits:sizeRange].size;
      CGPoint position = CGPointMake(info.sectionInsets.left + (columnWidth + info.columnSpacing) * columnIndex,
                                     [columnHeights[section][columnIndex] floatValue]);
      CGRect frame = CGRectMake(position.x, position.y, size.width, size.height);
      
      attrs.frame = frame;
      [attrsMap setObject:attrs forKey:element];
      // TODO Profile and avoid boxing if there are significant retain/release overheads
      columnHeights[section][columnIndex] = @(CGRectGetMaxY(frame) + info.interItemSpacing.bottom);
    }
    
    NSUInteger columnIndex = [self _tallestColumnIndexInSection:section withColumnHeights:columnHeights];
    top = [columnHeights[section][columnIndex] floatValue] - info.interItemSpacing.bottom + info.sectionInsets.bottom;
    
    for (NSUInteger idx = 0; idx < [columnHeights[section] count]; idx++) {
      columnHeights[section][idx] = @(top);
    }
  }
  
  CGFloat contentHeight = [[[columnHeights lastObject] firstObject] floatValue];
  CGSize contentSize = CGSizeMake(layoutWidth, contentHeight);
  return [[ASCollectionLayoutState alloc] initWithContext:context
                                              contentSize:contentSize
                           elementToLayoutAttributesTable:attrsMap];
}

+ (CGFloat)_columnWidthForSection:(NSUInteger)section withLayoutWidth:(CGFloat)layoutWidth info:(MosaicCollectionLayoutInfo *)info
{
  return ([self _widthForSection:section withLayoutWidth:layoutWidth info:info] - ((info.numberOfColumns - 1) * info.columnSpacing)) / info.numberOfColumns;
}

+ (CGFloat)_widthForSection:(NSUInteger)section withLayoutWidth:(CGFloat)layoutWidth info:(MosaicCollectionLayoutInfo *)info
{
  return layoutWidth - info.sectionInsets.left - info.sectionInsets.right;
}

+ (ASSizeRange)_sizeRangeForItem:(ASCellNode *)item atIndexPath:(NSIndexPath *)indexPath withLayoutWidth:(CGFloat)layoutWidth info:(MosaicCollectionLayoutInfo *)info
{
  CGFloat itemWidth = [self _columnWidthForSection:indexPath.section withLayoutWidth:layoutWidth info:info];
  if ([item isKindOfClass:[ImageCellNode class]]) {
    return ASSizeRangeMake(CGSizeMake(itemWidth, 0), CGSizeMake(itemWidth, CGFLOAT_MAX));
  } else {
    return ASSizeRangeMake(CGSizeMake(itemWidth, itemWidth)); // In kShowUICollectionViewCells = YES mode, make those cells itemWidth x itemWidth.
  }
}

+ (ASSizeRange)_sizeRangeForHeaderOfSection:(NSInteger)section withLayoutWidth:(CGFloat)layoutWidth info:(MosaicCollectionLayoutInfo *)info
{
  return ASSizeRangeMake(CGSizeMake(0, info.headerHeight), CGSizeMake([self _widthForSection:section withLayoutWidth:layoutWidth info:info], info.headerHeight));
}

+ (NSUInteger)_tallestColumnIndexInSection:(NSUInteger)section withColumnHeights:(NSArray *)columnHeights
{
  __block NSUInteger index = 0;
  __block CGFloat tallestHeight = 0;
  [columnHeights[section] enumerateObjectsUsingBlock:^(NSNumber *height, NSUInteger idx, BOOL *stop) {
    if (height.floatValue > tallestHeight) {
      index = idx;
      tallestHeight = height.floatValue;
    }
  }];
  return index;
}

+ (NSUInteger)_shortestColumnIndexInSection:(NSUInteger)section withColumnHeights:(NSArray *)columnHeights
{
  __block NSUInteger index = 0;
  __block CGFloat shortestHeight = CGFLOAT_MAX;
  [columnHeights[section] enumerateObjectsUsingBlock:^(NSNumber *height, NSUInteger idx, BOOL *stop) {
    if (height.floatValue < shortestHeight) {
      index = idx;
      shortestHeight = height.floatValue;
    }
  }];
  return index;
}

@end
