//
//  MosaicCollectionViewLayout.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface MosaicCollectionViewLayout : UICollectionViewLayout

@property (assign, nonatomic) NSUInteger numberOfColumns;
@property (assign, nonatomic) CGFloat columnSpacing;
@property (assign, nonatomic) UIEdgeInsets sectionInset;
@property (assign, nonatomic) UIEdgeInsets interItemSpacing;
@property (assign, nonatomic) CGFloat headerHeight;

@end

@protocol MosaicCollectionViewLayoutDelegate <ASCollectionViewDelegate>

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(MosaicCollectionViewLayout *)layout originalItemSizeAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface MosaicCollectionViewLayoutInspector : NSObject <ASCollectionViewLayoutInspecting>

@end
