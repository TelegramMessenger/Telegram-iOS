//
//  LikesNode.m
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

#import "LikesNode.h"
#import "TextStyles.h"

@interface LikesNode ()
@property (nonatomic, strong) ASImageNode *iconNode;
@property (nonatomic, strong) ASTextNode *countNode;
@property (nonatomic, assign) NSInteger likesCount;
@property (nonatomic, assign) BOOL liked;
@end

@implementation LikesNode

- (instancetype)initWithLikesCount:(NSInteger)likesCount
{
    self = [super init];
    if (self) {
        _likesCount = likesCount;
        _liked = (_likesCount > 0) ? [LikesNode getYesOrNo] : NO;
        
        _iconNode = [[ASImageNode alloc] init];
        _iconNode.image = (_liked) ? [UIImage imageNamed:@"icon_liked.png"] : [UIImage imageNamed:@"icon_like.png"];
        [self addSubnode:_iconNode];
        
        _countNode = [[ASTextNode alloc] init];
        if (_likesCount > 0) {
            
            NSDictionary *attributes = _liked ? [TextStyles cellControlColoredStyle] : [TextStyles cellControlStyle];
            _countNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", (long)_likesCount] attributes:attributes];
            
        }
        [self addSubnode:_countNode];
        
        // make it tappable easily
        self.hitTestSlop = UIEdgeInsetsMake(-10, -10, -10, -10);
    }
    
    return self;
    
}

+ (BOOL)getYesOrNo
{
    int tmp = (arc4random() % 30)+1;
    if (tmp % 5 == 0) {
        return YES;
    }
    return NO;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    ASStackLayoutSpec *mainStack =
    [ASStackLayoutSpec
     stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
     spacing:6.0
     justifyContent:ASStackLayoutJustifyContentStart
     alignItems:ASStackLayoutAlignItemsCenter
     children:@[_iconNode, _countNode]];

    mainStack.style.minWidth = ASDimensionMakeWithPoints(60.0);
    mainStack.style.maxHeight = ASDimensionMakeWithPoints(40.0);

    return mainStack;
}

@end
