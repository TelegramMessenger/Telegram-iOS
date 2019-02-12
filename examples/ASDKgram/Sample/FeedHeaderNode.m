//
//  FeedHeaderNode.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "FeedHeaderNode.h"

#import "Availability.h"
#import "Utilities.h"

#define YOGA_LAYOUT 0

static UIEdgeInsets kFeedHeaderInset = { .top = 20, .bottom = 20, .left = 10, .right = 10 };

@interface FeedHeaderNode ()
@property (nonatomic, strong, readonly) ASTextNode *textNode;
@end

@implementation FeedHeaderNode

- (instancetype)init
{
  if (self = [super init]) {
    self.automaticallyManagesSubnodes = YES;

    _textNode = [[ASTextNode alloc] init];
    _textNode.attributedText = [NSAttributedString attributedStringWithString:@"Latest Posts" fontSize:18 color:[UIColor darkGrayColor] firstWordColor:nil];

    [self setupYogaLayoutIfNeeded];
  }
  return self;
}

#if !YOGA_LAYOUT
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:kFeedHeaderInset child:_textNode];
}
#endif

- (void)setupYogaLayoutIfNeeded
{
#if YOGA_LAYOUT
  [self.style yogaNodeCreateIfNeeded];
  [self.textNode.style yogaNodeCreateIfNeeded];
  [self addYogaChild:self.textNode];

  self.style.padding = ASEdgeInsetsMake(kFeedHeaderInset);
#endif
}

@end
