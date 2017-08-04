//
//  MosaicCollectionLayoutInfo.h
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

@interface MosaicCollectionLayoutInfo : NSObject

// Read-only properties
@property (nonatomic, assign, readonly) NSInteger numberOfColumns;
@property (nonatomic, assign, readonly) CGFloat headerHeight;
@property (nonatomic, assign, readonly) CGFloat columnSpacing;
@property (nonatomic, assign, readonly) UIEdgeInsets sectionInsets;
@property (nonatomic, assign, readonly) UIEdgeInsets interItemSpacing;

- (instancetype)initWithNumberOfColumns:(NSInteger)numberOfColumns
                           headerHeight:(CGFloat)headerHeight
                          columnSpacing:(CGFloat)columnSpacing
                          sectionInsets:(UIEdgeInsets)sectionInsets
                       interItemSpacing:(UIEdgeInsets)interItemSpacing NS_DESIGNATED_INITIALIZER;

- (instancetype)init __unavailable;

@end
