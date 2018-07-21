//
//  PhotoFeedBaseController.m
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

#import "PhotoFeedBaseController.h"
#import "PhotoFeedModel.h"

@implementation PhotoFeedBaseController
{
  UIActivityIndicatorView *_activityIndicatorView;
}

// -loadView is guaranteed to be called on the main thread and is the appropriate place to
// set up an UIKit objects you may be using.
- (void)loadView
{
  [super loadView];
  
  _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  
  _photoFeed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular imageSize:[self imageSizeForScreenWidth]];
  [self refreshFeed];
  
  CGSize boundSize = self.view.bounds.size;
  [_activityIndicatorView sizeToFit];
  CGRect refreshRect = _activityIndicatorView.frame;
  refreshRect.origin = CGPointMake((boundSize.width - _activityIndicatorView.frame.size.width) / 2.0,
                                   (boundSize.height - _activityIndicatorView.frame.size.height) / 2.0);
  _activityIndicatorView.frame = refreshRect;
  [self.view addSubview:_activityIndicatorView];
  
  self.tableView.allowsSelection = NO;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  self.view.backgroundColor = [UIColor whiteColor];
}

- (void)refreshFeed
{
  [_activityIndicatorView startAnimating];
  // small first batch
  [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos){
    
    [_activityIndicatorView stopAnimating];
    
    [self.tableView reloadData];
    
    // immediately start second larger fetch
    [self loadPage];
    
  } numResultsToReturn:4];
}

- (void)insertNewRows:(NSArray *)newPhotos
{
  NSInteger section = 0;
  NSMutableArray *indexPaths = [NSMutableArray array];
  
  NSInteger newTotalNumberOfPhotos = [_photoFeed numberOfItemsInFeed];
  NSInteger existingNumberOfPhotos = newTotalNumberOfPhotos - newPhotos.count;
  for (NSInteger row = existingNumberOfPhotos; row < newTotalNumberOfPhotos; row++) {
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
    [indexPaths addObject:path];
  }
  [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
  return UIStatusBarStyleLightContent;
}

- (CGSize)imageSizeForScreenWidth
{
  CGRect screenRect   = [[UIScreen mainScreen] bounds];
  CGFloat screenScale = [[UIScreen mainScreen] scale];
  return CGSizeMake(screenRect.size.width * screenScale, screenRect.size.width * screenScale);
}

#pragma mark - PhotoFeedViewControllerProtocol

- (void)resetAllData
{
  [_photoFeed clearFeed];
  [self.tableView reloadData];
  [self refreshFeed];
}

#pragma mark - Subclassing

- (UITableView *)tableView
{
  NSAssert(NO, @"Subclasses must override this method");
  return nil;
}

- (void)loadPage
{
  NSAssert(NO, @"Subclasses must override this method");
}

@end
