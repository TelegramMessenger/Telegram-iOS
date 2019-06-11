//
//  OverrideViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "OverrideViewController.h"
#import <AsyncDisplayKit/ASTraitCollection.h>

static NSString *kLinkAttributeName = @"PlaceKittenNodeLinkAttributeName";

@interface OverrideNode()
@property (nonatomic, strong) ASTextNode *textNode;
@property (nonatomic, strong) ASButtonNode *buttonNode;
@end

@implementation OverrideNode

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  _textNode = [[ASTextNode alloc] init];
  _textNode.style.flexGrow = 1.0;
  _textNode.style.flexShrink = 1.0;
  _textNode.maximumNumberOfLines = 3;
  [self addSubnode:_textNode];
  
  _buttonNode = [[ASButtonNode alloc] init];
  [_buttonNode setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Close"] forState:UIControlStateNormal];
  [self addSubnode:_buttonNode];
  
  self.backgroundColor = [UIColor lightGrayColor];
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGFloat pointSize = 16.f;
  ASTraitCollection *traitCollection = [self asyncTraitCollection];
  if (traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
    // This should never happen because we override the VC's display traits to always be compact.
    pointSize = 100;
  }
  
  NSString *blurb = @"kittens courtesy placekitten.com";
  NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:blurb];
  [string addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:pointSize] range:NSMakeRange(0, blurb.length)];
  [string addAttributes:@{
                          kLinkAttributeName: [NSURL URLWithString:@"http://placekitten.com/"],
                          NSForegroundColorAttributeName: [UIColor grayColor],
                          NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle | NSUnderlinePatternDot),
                          }
                  range:[blurb rangeOfString:@"placekitten.com"]];
  
  _textNode.attributedText = string;
  
  ASStackLayoutSpec *stackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  stackSpec.children = @[_textNode, _buttonNode];
  stackSpec.spacing = 10;
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(40, 20, 20, 20) child:stackSpec];
}

@end

@interface OverrideViewController ()

@end

@implementation OverrideViewController

- (instancetype)init
{
  OverrideNode *overrideNode = [[OverrideNode alloc] init];
  
  if (!(self = [super initWithNode:overrideNode]))
    return nil;
  
  [overrideNode.buttonNode addTarget:self action:@selector(closeTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  return self;
}

- (void)closeTapped:(id)sender
{
  if (self.closeBlock) {
    self.closeBlock();
  }
}

@end
