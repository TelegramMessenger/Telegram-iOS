//
//  OverviewDetailViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "OverviewDetailViewController.h"

@interface OverviewDetailViewController ()
@property (nonatomic, strong) ASDisplayNode *node;
@end

@implementation OverviewDetailViewController

#pragma mark - Lifecycle

- (instancetype)initWithNode:(ASDisplayNode *)node
{
    self = [super initWithNibName:nil bundle:nil];
    if (self == nil) { return self; }
    _node = node;
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubnode:self.node];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Center node frame
    CGRect bounds = self.view.bounds;
    CGSize nodeSize = [self.node layoutThatFits:ASSizeRangeMake(CGSizeZero, bounds.size)].size;
    self.node.frame = CGRectMake(CGRectGetMidX(bounds) - (nodeSize.width / 2.0),
                                 CGRectGetMidY(bounds) - (nodeSize.height / 2.0),
                                 nodeSize.width,
                                 nodeSize.height);
}

@end
