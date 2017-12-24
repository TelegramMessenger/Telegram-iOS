//
//  OverviewViewController.m
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

#import "OverviewViewController.h"
#import "LayoutExampleNodes.h"
#import "LayoutExampleViewController.h"
#import "OverviewCellNode.h"

@interface OverviewViewController () <ASTableDelegate, ASTableDataSource>
@property (nonatomic, strong) NSArray *layoutExamples;
@property (nonatomic, strong) ASTableNode *tableNode;
@end

@implementation OverviewViewController

#pragma mark - Lifecycle Methods

- (instancetype)init
{
  _tableNode = [ASTableNode new];
  self = [super initWithNode:_tableNode];
  
  if (self) {
    self.title = @"Layout Examples";
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    _tableNode.delegate = self;
    _tableNode.dataSource = self;
    
    _layoutExamples = @[[HeaderWithRightAndLeftItems class],
                        [PhotoWithInsetTextOverlay class],
                        [PhotoWithOutsetIconOverlay class],
                        [FlexibleSeparatorSurroundingContent class],
                        [CornerLayoutExample class],
                        [UserProfileSample class]
                        ];
  }
  
  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  NSIndexPath *indexPath = _tableNode.indexPathForSelectedRow;
  if (indexPath != nil) {
    [_tableNode deselectRowAtIndexPath:indexPath animated:YES];
  }
}

#pragma mark - ASTableDelegate, ASTableDataSource

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  return [_layoutExamples count];
}

- (ASCellNode *)tableNode:(ASTableNode *)tableNode nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [[OverviewCellNode alloc] initWithLayoutExampleClass:_layoutExamples[indexPath.row]];
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  Class layoutExampleClass = [[tableNode nodeForRowAtIndexPath:indexPath] layoutExampleClass];
  LayoutExampleViewController *detail = [[LayoutExampleViewController alloc] initWithLayoutExampleClass:layoutExampleClass];
  [self.navigationController pushViewController:detail animated:YES];
}

@end
