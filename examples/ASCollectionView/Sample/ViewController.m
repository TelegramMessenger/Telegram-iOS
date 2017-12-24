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
#import "AppDelegate.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "SupplementaryNode.h"
#import "ItemNode.h"

#define ASYNC_COLLECTION_LAYOUT 0

@interface ViewController () <ASCollectionDataSource, ASCollectionDelegateFlowLayout, ASCollectionGalleryLayoutPropertiesProviding>

@property (nonatomic, strong) ASCollectionNode *collectionNode;
@property (nonatomic, strong) NSArray *data;

@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)dealloc
{
  self.collectionNode.dataSource = nil;
  self.collectionNode.delegate = nil;
  
  NSLog(@"ViewController is deallocing");
}

- (void)viewDidLoad
{
  [super viewDidLoad];

#if ASYNC_COLLECTION_LAYOUT
  ASCollectionGalleryLayoutDelegate *layoutDelegate = [[ASCollectionGalleryLayoutDelegate alloc] initWithScrollableDirections:ASScrollDirectionVerticalDirections];
  layoutDelegate.propertiesProvider = self;
  self.collectionNode = [[ASCollectionNode alloc] initWithLayoutDelegate:layoutDelegate layoutFacilitator:nil];
#else
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.headerReferenceSize = CGSizeMake(50.0, 50.0);
  layout.footerReferenceSize = CGSizeMake(50.0, 50.0);
  self.collectionNode = [[ASCollectionNode alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
  [self.collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  [self.collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionFooter];
#endif
  
  self.collectionNode.dataSource = self;
  self.collectionNode.delegate = self;
  
  self.collectionNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.collectionNode.backgroundColor = [UIColor whiteColor];
  
  [self.view addSubnode:self.collectionNode];
  self.collectionNode.frame = self.view.bounds;
  
#if !SIMULATE_WEB_RESPONSE
  self.navigationItem.leftItemsSupplementBackButton = YES;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                        target:self
                                                                                        action:@selector(reloadTapped)];
#endif

#if SIMULATE_WEB_RESPONSE
  __weak typeof(self) weakSelf = self;
  void(^mockWebService)() = ^{
    NSLog(@"ViewController \"got data from a web service\"");
    ViewController *strongSelf = weakSelf;
    if (strongSelf != nil)
    {
      NSLog(@"ViewController is not nil");
      strongSelf->_data = [[NSArray alloc] init];
      [strongSelf->_collectionNode performBatchUpdates:^{
        [strongSelf->_collectionNode insertSections:[[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, 100)]];
      } completion:nil];
      NSLog(@"ViewController finished updating collectionNode");
    }
    else {
      NSLog(@"ViewController is nil - won't update collectionNode");
    }
  };
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), mockWebService);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self.navigationController popViewControllerAnimated:YES];
  });
#endif
}

#pragma mark - Button Actions

- (void)reloadTapped
{
  // This method is deprecated because we reccommend using ASCollectionNode instead of ASCollectionView.
  // This functionality & example project remains for users who insist on using ASCollectionView.
  [self.collectionNode reloadData];
}

#pragma mark - ASCollectionGalleryLayoutPropertiesProviding

- (CGSize)galleryLayoutDelegate:(ASCollectionGalleryLayoutDelegate *)delegate sizeForElements:(ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();
  return CGSizeMake(180, 90);
}

#pragma mark - ASCollectionView Data Source

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath;
{
  NSString *text = [NSString stringWithFormat:@"[%zd.%zd] says hi", indexPath.section, indexPath.item];
  return ^{
    return [[ItemNode alloc] initWithString:text];
  };
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [kind isEqualToString:UICollectionElementKindSectionHeader] ? @"Header" : @"Footer";
  SupplementaryNode *node = [[SupplementaryNode alloc] initWithText:text];
  BOOL isHeaderSection = [kind isEqualToString:UICollectionElementKindSectionHeader];
  node.backgroundColor = isHeaderSection ? [UIColor blueColor] : [UIColor redColor];
  return node;
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return 10;
}

- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode
{
#if SIMULATE_WEB_RESPONSE
  return _data == nil ? 0 : 100;
#else
  return 100;
#endif
}

- (void)collectionNode:(ASCollectionNode *)collectionNode willBeginBatchFetchWithContext:(ASBatchContext *)context
{
  NSLog(@"fetch additional content");
  [context completeBatchFetching:YES];
}

@end
