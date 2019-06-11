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

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  ASNetworkImageNode *imageNode = [[ASNetworkImageNode alloc] init];
  imageNode.URL = [NSURL URLWithString:@"https://i.pinimg.com/originals/07/44/38/074438e7c75034df2dcf37ba1057803e.gif"];
  // Uncomment to see animated webp support
  //  imageNode.URL = [NSURL URLWithString:@"https://storage.googleapis.com/downloads.webmproject.org/webp/images/dancing_banana2.lossless.webp"];
  imageNode.frame = self.view.bounds;
  imageNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  imageNode.contentMode = UIViewContentModeScaleAspectFit;
  
  [self.view addSubnode:imageNode];
}

@end
