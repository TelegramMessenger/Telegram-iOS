//
//  ViewController.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
