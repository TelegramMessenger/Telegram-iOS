//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "MosaicCollectionViewLayout.h"
#import "SupplementaryNode.h"
#import "ImageViewController.h"

static NSUInteger kNumberOfImages = 14;

@interface ViewController () <ASCollectionViewDataSource, MosaicCollectionViewLayoutDelegate>
{
  NSMutableArray *_sections;
  ASCollectionView *_collectionView;
  MosaicCollectionViewLayoutInspector *_layoutInspector;
}

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  self = [super init];
  if (self) {
    
    _sections = [NSMutableArray array];
    [_sections addObject:[NSMutableArray array]];
    for (NSUInteger idx = 0, section = 0; idx < kNumberOfImages; idx++) {
      NSString *name = [NSString stringWithFormat:@"image_%lu.jpg", (unsigned long)idx];
      [_sections[section] addObject:[UIImage imageNamed:name]];
      if ((idx + 1) % 5 == 0 && idx < kNumberOfImages - 1) {
        section++;
        [_sections addObject:[NSMutableArray array]];
      }
    }
    
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  MosaicCollectionViewLayout *layout = [[MosaicCollectionViewLayout alloc] init];
  layout.numberOfColumns = 2;
  layout.headerHeight = 44.0;
  
  _layoutInspector = [[MosaicCollectionViewLayoutInspector alloc] init];
  
  _collectionView = [[ASCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
  _collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  _collectionView.asyncDataSource = self;
  _collectionView.asyncDelegate = self;
  _collectionView.layoutInspector = _layoutInspector;
  _collectionView.backgroundColor = [UIColor whiteColor];
  
  [_collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  [self.view addSubview:_collectionView];
}

- (void)dealloc
{
  _collectionView.asyncDataSource = nil;
  _collectionView.asyncDelegate = nil;
}

- (void)reloadTapped
{
  [_collectionView reloadData];
}

#pragma mark -
#pragma mark ASCollectionView data source.

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UIImage *image = _sections[indexPath.section][indexPath.item];
  return ^{
    return [[ASCellNode alloc] initWithViewControllerBlock:^UIViewController *{
      return [[ImageViewController alloc] initWithImage:image];
    } didLoadBlock:^(ASDisplayNode * _Nonnull node) {
      node.layer.borderWidth = 1.0;
      node.layer.borderColor = [UIColor blackColor].CGColor;
    }];
  };
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [NSString stringWithFormat:@"Section %d", (int)indexPath.section + 1];
  return [[SupplementaryNode alloc] initWithText:text];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return _sections.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [_sections[section] count];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout originalItemSizeAtIndexPath:(NSIndexPath *)indexPath
{
  return [(UIImage *)_sections[indexPath.section][indexPath.item] size];
}

@end
