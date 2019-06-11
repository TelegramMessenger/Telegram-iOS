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

@interface ViewController ()

@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGSize screenSize = self.view.bounds.size;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ASTextNode *node = [[ASTextNode alloc] init];
        node.attributedText = [[NSAttributedString alloc] initWithString:@"hello world"];
        [node layoutThatFits:ASSizeRangeMake(CGSizeZero, (CGSize){.width = screenSize.width, .height = CGFLOAT_MAX})];
        node.frame = (CGRect) {.origin = (CGPoint){.x = 100, .y = 100}, .size = node.calculatedSize };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view addSubview:node.view];
        });
    });
}

@end
