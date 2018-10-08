//
//  ImageViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//


#import "ImageViewController.h"

@interface ImageViewController ()
@property (nonatomic) UIImageView *imageView;
@end

@implementation ImageViewController

- (instancetype)initWithImage:(UIImage *)image {
  if (!(self = [super init])) { return nil; }
  
  self.imageView = [[UIImageView alloc] initWithImage:image];
  
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self.view addSubview:self.imageView];
  
  UIGestureRecognizer *tap = [[UIGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
  [self.view addGestureRecognizer:tap];

  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
}

- (void)tapped;
{
  NSLog(@"tapped!");
}

- (void)viewWillLayoutSubviews
{
  self.imageView.frame = self.view.bounds;
}

@end
