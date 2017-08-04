//
//  ViewController.m
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

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ViewController ()
@property (nonatomic, strong) ASTextNode *textNode;
@end

@implementation ViewController

- (void)viewDidLoad
{
  self.textNode = [[ASTextNode alloc] init];
  self.textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Testing, testing." attributes:@{ NSForegroundColorAttributeName: [UIColor redColor] }];
  [self.textNode layoutThatFits:ASSizeRangeMake(CGSizeZero, self.view.bounds.size)];
  self.textNode.frame = (CGRect){ .origin = CGPointZero, .size = self.textNode.calculatedSize };
  [self.view addSubnode:self.textNode];
}

@end
