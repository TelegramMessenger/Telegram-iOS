//
//  CollectionViewController.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "CollectionViewController.h"
#import "TextCellNode.h"

@interface CollectionViewController() <ASCollectionDataSource, ASCollectionDelegate>
{
  ASCollectionNode *_collectionNode;
  NSArray<NSString *> *_labels;
  TextCellNode *_cellNode;
}

@end

@implementation CollectionViewController

- (instancetype)init
{
  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
  CGRect rect = [[UIApplication sharedApplication] statusBarFrame];
  _collectionNode.contentInset = UIEdgeInsetsMake(rect.size.height, 0, 0, 0);
  self = [super initWithNode:_collectionNode];
  if (self) {
    _collectionNode.delegate = self;
    _collectionNode.dataSource = self;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  _collectionNode.backgroundColor = [UIColor whiteColor];
  _labels = @[@"Fight of the Living Dead: Experiment Fight of the Living Dead: Experiment", @"S1 • E1"];
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return 1;
}

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{
    _cellNode = [[TextCellNode alloc] initWithText1:_labels[0] text2:_labels[1]];
    return _cellNode;
  };
}

- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode constrainedSizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  CGFloat width = collectionNode.view.bounds.size.width;
  return ASSizeRangeMake(CGSizeMake(width, 0.0f), CGSizeMake(width, CGFLOAT_MAX));
}

@end
