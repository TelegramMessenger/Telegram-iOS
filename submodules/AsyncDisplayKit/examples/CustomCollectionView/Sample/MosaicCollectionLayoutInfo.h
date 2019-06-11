//
//  MosaicCollectionLayoutInfo.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
