//
//  AsyncTableViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

#import "AsyncTableViewController.h"
#import "RandomCoreGraphicsNode.h"

@interface AsyncTableViewController () <ASTableViewDataSource, ASTableViewDelegate>
{
  ASTableView *_tableView;
}

@end

@implementation AsyncTableViewController

#pragma mark - UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo
                                                                                         target:self
                                                                                         action:@selector(reloadEverything)];

  return self;
}

- (void)reloadEverything
{
  [_tableView reloadData];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _tableView = [[ASTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
  _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableView.asyncDataSource = self;
  _tableView.asyncDelegate = self;
  
  ASRangeTuningParameters tuningParameters;
  tuningParameters.leadingBufferScreenfuls = 0.5;
  tuningParameters.trailingBufferScreenfuls = 1.0;
  [_tableView setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypePreload];
  [_tableView setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypeDisplay];
  
  [self.view addSubview:_tableView];
}

#pragma mark - ASTableView.

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{
    RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
    elementNode.style.preferredSize = CGSizeMake(320, 100);
    return elementNode;
  };
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

@end
