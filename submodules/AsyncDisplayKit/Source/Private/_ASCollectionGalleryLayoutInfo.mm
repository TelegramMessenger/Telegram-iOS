//
//  _ASCollectionGalleryLayoutInfo.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/_ASCollectionGalleryLayoutInfo.h>
#import <AsyncDisplayKit/ASHashing.h>

@implementation _ASCollectionGalleryLayoutInfo

- (instancetype)initWithItemSize:(CGSize)itemSize
              minimumLineSpacing:(CGFloat)minimumLineSpacing
         minimumInteritemSpacing:(CGFloat)minimumInteritemSpacing
                    sectionInset:(UIEdgeInsets)sectionInset
{
  self = [super init];
  if (self) {
    _itemSize = itemSize;
    _minimumLineSpacing = minimumLineSpacing;
    _minimumInteritemSpacing = minimumInteritemSpacing;
    _sectionInset = sectionInset;
  }
  return self;
}

- (BOOL)isEqualToInfo:(_ASCollectionGalleryLayoutInfo *)info
{
  if (info == nil) {
    return NO;
  }

  return CGSizeEqualToSize(_itemSize, info.itemSize)
  && _minimumLineSpacing == info.minimumLineSpacing
  && _minimumInteritemSpacing == info.minimumInteritemSpacing
  && UIEdgeInsetsEqualToEdgeInsets(_sectionInset, info.sectionInset);
}

- (BOOL)isEqual:(id)other
{
  if (self == other) {
    return YES;
  }
  if (! [other isKindOfClass:[_ASCollectionGalleryLayoutInfo class]]) {
    return NO;
  }
  return [self isEqualToInfo:other];
}

- (NSUInteger)hash
{
  struct {
    CGSize itemSize;
    CGFloat minimumLineSpacing;
    CGFloat minimumInteritemSpacing;
    UIEdgeInsets sectionInset;
  } data = {
    _itemSize,
    _minimumLineSpacing,
    _minimumInteritemSpacing,
    _sectionInset,
  };
  return ASHashBytes(&data, sizeof(data));
}

@end
