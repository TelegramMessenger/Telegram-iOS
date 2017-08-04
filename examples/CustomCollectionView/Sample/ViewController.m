//
//  ViewController.m
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASCollectionNode+Beta.h>
#import "MosaicCollectionLayoutDelegate.h"
#import "ImageCellNode.h"
#import "ImageCollectionViewCell.h"

// This option demonstrates that raw UIKit cells can still be used alongside native ASCellNodes.
static BOOL kShowUICollectionViewCells = YES;
static NSString *kReuseIdentifier = @"ImageCollectionViewCell";
static NSUInteger kNumberOfImages = 14;

@interface ViewController () <ASCollectionDataSourceInterop, ASCollectionDelegate, ASCollectionViewLayoutInspecting>
{
  NSMutableArray *_sections;
  ASCollectionNode *_collectionNode;
}

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController

- (instancetype)init
{
  MosaicCollectionLayoutDelegate *layoutDelegate = [[MosaicCollectionLayoutDelegate alloc] initWithNumberOfColumns:2 headerHeight:44.0];
  _collectionNode = [[ASCollectionNode alloc] initWithLayoutDelegate:layoutDelegate layoutFacilitator:nil];
  _collectionNode.dataSource = self;
  _collectionNode.delegate = self;
  _collectionNode.layoutInspector = self;
  
  if (!(self = [super initWithNode:_collectionNode]))
    return nil;
  
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
  
  [_collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [_collectionNode.view registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:kReuseIdentifier];
}

- (void)reloadTapped
{
  [_collectionNode reloadData];
}

#pragma mark - ASCollectionNode data source.

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (kShowUICollectionViewCells && indexPath.item % 3 == 1) {
    // When enabled, return nil for every third cell and then cellForItemAtIndexPath: will be called.
    return nil;
  }
  
  UIImage *image = _sections[indexPath.section][indexPath.item];
  return ^{
    return [[ImageCellNode alloc] initWithImage:image];
  };
}

// The below 2 methods are required by ASCollectionViewLayoutInspecting, but ASCollectionLayout and its layout delegate are the ones that really determine the size ranges and directions
// TODO Remove these methods once a layout inspector is no longer required under ASCollectionLayout mode
- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return ASSizeRangeZero;
}

- (ASScrollDirection)scrollableDirections
{
  return ASScrollDirectionVerticalDirections;
}

/**
 * Asks the inspector for the number of supplementary views for the given kind in the specified section.
 */
- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  return [kind isEqualToString:UICollectionElementKindSectionHeader] ? 1 : 0;
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSDictionary *textAttributes = @{
      NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
      NSForegroundColorAttributeName: [UIColor grayColor]
  };
  UIEdgeInsets textInsets = UIEdgeInsetsMake(11.0, 0, 11.0, 0);
  ASTextCellNode *textCellNode = [[ASTextCellNode alloc] initWithAttributes:textAttributes insets:textInsets];
  textCellNode.text = [NSString stringWithFormat:@"Section %zd", indexPath.section + 1];
  return textCellNode;
}

- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode
{
  return _sections.count;
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return [_sections[section] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_collectionNode.view dequeueReusableCellWithReuseIdentifier:kReuseIdentifier forIndexPath:indexPath];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  return nil;
}

@end
