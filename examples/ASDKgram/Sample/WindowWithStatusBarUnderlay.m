//
//  WindowWithStatusBarUnderlay.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "WindowWithStatusBarUnderlay.h"
#import "Utilities.h"

@implementation WindowWithStatusBarUnderlay
{
  UIView *_statusBarOpaqueUnderlayView;
}

-(instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    _statusBarOpaqueUnderlayView                 = [[UIView alloc] init];
    _statusBarOpaqueUnderlayView.backgroundColor = [UIColor darkBlueColor];
    [self addSubview:_statusBarOpaqueUnderlayView];
  }
  return self;
}

-(void)layoutSubviews
{
  [super layoutSubviews];
  
  [self bringSubviewToFront:_statusBarOpaqueUnderlayView];
  
  CGRect statusBarFrame              = CGRectZero;
  statusBarFrame.size.width          = [[UIScreen mainScreen] bounds].size.width;
  statusBarFrame.size.height         = [[UIApplication sharedApplication] statusBarFrame].size.height;
  _statusBarOpaqueUnderlayView.frame = statusBarFrame;
}

@end
