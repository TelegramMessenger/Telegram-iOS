//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAssert.h>

#import "ViewController.h"
#import "HorizontalScrollCellNode.h"

@interface ViewController () <ASTableDataSource, ASTableDelegate>
{
  ASTableNode *_tableNode;
}

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  _tableNode.dataSource = self;
  _tableNode.delegate = self;

  if (!(self = [super initWithNode:_tableNode]))
    return nil;

  self.title = @"Horizontal Scrolling Gradients";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo
                                                                                         target:self
                                                                                         action:@selector(reloadEverything)];

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)reloadEverything
{
  [_tableNode reloadData];
}

#pragma mark - ASTableNode

- (ASCellNode *)tableNode:(ASTableNode *)tableNode nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [[HorizontalScrollCellNode alloc] initWithElementSize:CGSizeMake(100, 100)];
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

@end
