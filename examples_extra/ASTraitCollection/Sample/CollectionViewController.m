//
//  CollectionViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "CollectionViewController.h"
#import "KittenNode.h"
#import <AsyncDisplayKit/ASTraitCollection.h>

@interface CollectionViewController () <ASCollectionDelegate, ASCollectionDataSource>
@property (nonatomic, strong) ASCollectionNode *collectionNode;
@end

@implementation CollectionViewController

- (instancetype)init
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.minimumLineSpacing = 10;
  layout.minimumInteritemSpacing = 10;
  
  ASCollectionNode *collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
  
  if (!(self = [super initWithNode:collectionNode]))
    return nil;
  
  self.title = @"Collection Node";
  _collectionNode = collectionNode;
  collectionNode.dataSource = self;
  collectionNode.delegate = self;
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.collectionNode.view.contentInset = UIEdgeInsetsMake(20, 10, CGRectGetHeight(self.tabBarController.tabBar.frame), 10);
}

#pragma mark - ASCollectionDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return 50;
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  KittenNode *cell = [[KittenNode alloc] init];
  cell.textNode.maximumNumberOfLines = 3;
  cell.imageTappedBlock = ^{
    [KittenNode defaultImageTappedAction:self];
  };
  return cell;
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASTraitCollection *traitCollection = [self.collectionNode asyncTraitCollection];
  
  if (traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
    return ASSizeRangeMake(CGSizeMake(200, 120), CGSizeMake(200, 120));
  }
  return ASSizeRangeMake(CGSizeMake(132, 180), CGSizeMake(132, 180));
}

@end
