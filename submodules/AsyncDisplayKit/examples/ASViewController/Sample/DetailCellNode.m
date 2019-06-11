//
//  DetailCellNode.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "DetailCellNode.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@implementation DetailCellNode

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    self.automaticallyManagesSubnodes = YES;
    
    _imageNode = [[ASNetworkImageNode alloc] init];
    _imageNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
    
    return self;
}

#pragma mark - ASDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    return [ASRatioLayoutSpec ratioLayoutSpecWithRatio:1.0 child:self.imageNode];
}

- (void)layoutDidFinish
{
    [super layoutDidFinish];
    
    // In general set URL of ASNetworkImageNode as soon as possible. Ideally in init or a
    // view model setter method.
    // In this case as we need to know the size of the node the url is set in layoutDidFinish so
    // we have the calculatedSize available
    self.imageNode.URL = [self imageURL];
}

#pragma mark  - Image

- (NSURL *)imageURL
{
    CGSize imageSize = self.calculatedSize;
    NSString *imageURLString = [NSString stringWithFormat:@"http://lorempixel.com/%ld/%ld/%@/%ld", (NSInteger)imageSize.width, (NSInteger)imageSize.height, self.imageCategory, self.row];
    return [NSURL URLWithString:imageURLString];
}

@end
