//
//  PhotoFeedViewController.m
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) through the present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "PhotoFeedViewController.h"
#import "Utilities.h"
#import "PhotoTableViewCell.h"
#import "PhotoFeedModel.h"

#define AUTO_TAIL_LOADING_NUM_SCREENFULS  2.5

@interface PhotoFeedViewController () <UITableViewDelegate, UITableViewDataSource>
@end

@implementation PhotoFeedViewController
{
  UITableView *_tableView;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super initWithNibName:nil bundle:nil];
  
  if (self) {
    self.navigationItem.title = @"UIKit";
    [self.navigationController setNavigationBarHidden:YES];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _tableView.delegate = self;
    _tableView.dataSource = self;
  }
  
  return self;
}

// anything involving the view should go here, not init
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.view addSubview:_tableView];
  _tableView.frame = self.view.bounds;
  [_tableView registerClass:[PhotoTableViewCell class] forCellReuseIdentifier:@"photoCell"];
}

#pragma mark - Subclassing

- (UITableView *)tableView
{
  return _tableView;
}

- (void)loadPage
{
  [self.photoFeed requestPageWithCompletionBlock:^(NSArray *newPhotos){
    [self insertNewRows:newPhotos];
  } numResultsToReturn:20];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [self.photoFeed numberOfItemsInFeed];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  PhotoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoCell" forIndexPath:indexPath];
  [cell updateCellWithPhotoObject:[self.photoFeed objectAtIndex:indexPath.row]];
  
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  PhotoModel *photo = [self.photoFeed objectAtIndex:indexPath.row];
  return [PhotoTableViewCell heightForPhotoModel:photo withWidth:self.view.bounds.size.width];
}

#pragma mark - UITableViewDelegate methods

// table automatic tail loading
-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  CGFloat currentOffSetY = scrollView.contentOffset.y;
  CGFloat contentHeight  = scrollView.contentSize.height;
  CGFloat screenHeight   = [UIScreen mainScreen].bounds.size.height;

  CGFloat screenfullsBeforeBottom = (contentHeight - currentOffSetY) / screenHeight;
  if (screenfullsBeforeBottom < AUTO_TAIL_LOADING_NUM_SCREENFULS) {
    [self loadPage];
  }
}

@end
