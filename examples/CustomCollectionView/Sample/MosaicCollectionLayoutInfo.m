//
//  MosaicCollectionLayoutInfo.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "MosaicCollectionLayoutInfo.h"

#import <AsyncDisplayKit/ASHashing.h>

@implementation MosaicCollectionLayoutInfo

- (instancetype)initWithNumberOfColumns:(NSInteger)numberOfColumns
                           headerHeight:(CGFloat)headerHeight
                          columnSpacing:(CGFloat)columnSpacing
                          sectionInsets:(UIEdgeInsets)sectionInsets
                       interItemSpacing:(UIEdgeInsets)interItemSpacing
{
  self = [super init];
  if (self) {
    _numberOfColumns = numberOfColumns;
    _headerHeight = headerHeight;
    _columnSpacing = columnSpacing;
    _sectionInsets = sectionInsets;
    _interItemSpacing = interItemSpacing;
  }
  return self;
}

- (BOOL)isEqualToInfo:(MosaicCollectionLayoutInfo *)info
{
  if (info == nil) {
    return NO;
  }

  return _numberOfColumns == info.numberOfColumns
  && _headerHeight == info.headerHeight
  && _columnSpacing == info.columnSpacing
  && UIEdgeInsetsEqualToEdgeInsets(_sectionInsets, info.sectionInsets)
  && UIEdgeInsetsEqualToEdgeInsets(_interItemSpacing, info.interItemSpacing);
}

- (BOOL)isEqual:(id)other
{
  if (self == other) {
    return YES;
  }
  if (! [other isKindOfClass:[MosaicCollectionLayoutInfo class]]) {
    return NO;
  }
  return [self isEqualToInfo:other];
}

- (NSUInteger)hash
{
  struct {
    NSInteger numberOfColumns;
    CGFloat headerHeight;
    CGFloat columnSpacing;
    UIEdgeInsets sectionInsets;
    UIEdgeInsets interItemSpacing;
  } data = {
    _numberOfColumns,
    _headerHeight,
    _columnSpacing,
    _sectionInsets,
    _interItemSpacing,
  };
  return ASHashBytes(&data, sizeof(data));
}

@end
