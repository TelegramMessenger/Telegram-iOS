//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "ViewController.h"
#import "GradientTableNode.h"

@interface ViewController () <ASPagerDataSource, ASPagerDelegate>
{
  ASPagerNode *_pagerNode;
}

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  _pagerNode = [[ASPagerNode alloc] init];
  _pagerNode.dataSource = self;
  _pagerNode.delegate = self;
  ASDisplayNode.shouldShowRangeDebugOverlay = YES;
  
  // Could implement ASCollectionDelegate if we wanted extra callbacks, like from UIScrollView.
  //_pagerNode.delegate = self;
  
  self.title = @"Paging Table Nodes";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo
                                                                                         target:self
                                                                                         action:@selector(reloadEverything)];

  return self;
}

- (void)reloadEverything
{
  [_pagerNode reloadData];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubnode:_pagerNode];
}

- (void)viewWillLayoutSubviews
{
  _pagerNode.frame = self.view.bounds;
}

#pragma mark -
#pragma mark ASPagerNode.

- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index
{
  CGSize boundsSize = pagerNode.bounds.size;
  CGSize gradientRowSize = CGSizeMake(boundsSize.width, 100);
  GradientTableNode *node = [[GradientTableNode alloc] initWithElementSize:gradientRowSize];
  node.pageNumber = index;
  return node;
}

- (ASSizeRange)pagerNode:(ASPagerNode *)pagerNode constrainedSizeForNodeAtIndex:(NSInteger)index;
{
  return ASSizeRangeMake(pagerNode.bounds.size);
}

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
  return 10;
}

@end
