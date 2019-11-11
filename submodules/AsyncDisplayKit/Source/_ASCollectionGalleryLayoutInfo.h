//
//  _ASCollectionGalleryLayoutInfo.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

@interface _ASCollectionGalleryLayoutInfo : NSObject

// Read-only properties
@property (nonatomic, readonly) CGSize itemSize;
@property (nonatomic, readonly) CGFloat minimumLineSpacing;
@property (nonatomic, readonly) CGFloat minimumInteritemSpacing;
@property (nonatomic, readonly) UIEdgeInsets sectionInset;

- (instancetype)initWithItemSize:(CGSize)itemSize
              minimumLineSpacing:(CGFloat)minimumLineSpacing
         minimumInteritemSpacing:(CGFloat)minimumInteritemSpacing
                    sectionInset:(UIEdgeInsets)sectionInset NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
