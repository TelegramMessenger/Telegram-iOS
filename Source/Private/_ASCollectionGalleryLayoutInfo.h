//
//  _ASCollectionGalleryLayoutInfo.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

@interface _ASCollectionGalleryLayoutInfo : NSObject

// Read-only properties
@property (nonatomic, assign, readonly) CGSize itemSize;
@property (nonatomic, assign, readonly) CGFloat minimumLineSpacing;
@property (nonatomic, assign, readonly) CGFloat minimumInteritemSpacing;
@property (nonatomic, assign, readonly) UIEdgeInsets sectionInset;

- (instancetype)initWithItemSize:(CGSize)itemSize
              minimumLineSpacing:(CGFloat)minimumLineSpacing
         minimumInteritemSpacing:(CGFloat)minimumInteritemSpacing
                    sectionInset:(UIEdgeInsets)sectionInset NS_DESIGNATED_INITIALIZER;

- (instancetype)init __unavailable;

@end
