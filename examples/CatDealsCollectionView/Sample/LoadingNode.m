//
//  LoadingNode.m
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

#import "LoadingNode.h"

#import <AsyncDisplayKit/ASCenterLayoutSpec.h>

@implementation LoadingNode {
  ASDisplayNode *_loadingSpinner;
}

#pragma mark - ASCellNode

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  _loadingSpinner = [[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull{
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    return spinner;
  }];
  _loadingSpinner.style.preferredSize = CGSizeMake(50, 50);
    
  // add it as a subnode, and we're done
  [self addSubnode:_loadingSpinner];
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASCenterLayoutSpec *centerSpec = [[ASCenterLayoutSpec alloc] init];
  centerSpec.centeringOptions = ASCenterLayoutSpecCenteringXY;
  centerSpec.sizingOptions = ASCenterLayoutSpecSizingOptionDefault;
  centerSpec.child = _loadingSpinner;
  return centerSpec;
}

@end
