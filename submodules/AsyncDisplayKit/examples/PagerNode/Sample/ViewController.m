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

#import "PageNode.h"

static UIColor *randomColor() {
  CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
  CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
  CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
  return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}

@interface ViewController () <ASPagerNodeDataSource>

@end

@implementation ViewController

- (instancetype)init
{
  self = [super initWithNode:[[ASPagerNode alloc] init]];
  if (self == nil) {
    return self;
  }

  self.title = @"Pages";
  self.node.dataSource = self;
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStylePlain target:self action:@selector(scrollToNextPage:)];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Previous" style:UIBarButtonItemStylePlain target:self action:@selector(scrollToPreviousPage:)];
  self.automaticallyAdjustsScrollViewInsets = NO;
  return self;
}

#pragma mark - Actions

- (void)scrollToNextPage:(id)sender
{
  [self.node scrollToPageAtIndex:self.node.currentPageIndex+1 animated:YES];
}

- (void)scrollToPreviousPage:(id)sender
{
  [self.node scrollToPageAtIndex:self.node.currentPageIndex-1 animated:YES];
}

#pragma mark - ASPagerNodeDataSource

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
  return 5;
}

- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index
{
  return ^{
    PageNode *page = [[PageNode alloc] init];
    page.backgroundColor = randomColor();
    return page;
  };
}

@end
