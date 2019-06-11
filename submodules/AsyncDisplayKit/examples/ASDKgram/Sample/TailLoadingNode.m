//
//  TailLoadingNode.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "TailLoadingNode.h"

#import "Availability.h"

@interface TailLoadingNode ()
@property (nonatomic, strong) ASDisplayNode *activityIndicatorNode;
@end

@implementation TailLoadingNode

- (instancetype)init
{
  if (self = [super init]) {
    self.automaticallyManagesSubnodes = YES;

    _activityIndicatorNode = [[ASDisplayNode alloc] initWithViewBlock:^{
      UIActivityIndicatorView *v = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
      [v startAnimating];
      return v;
    }];
    self.style.height = ASDimensionMake(100);

    [self setupYogaLayoutIfNeeded];
  }
  return self;
}
#if !YOGA_LAYOUT
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY child:self.activityIndicatorNode];
}
#endif

- (void)setupYogaLayoutIfNeeded
{
#if YOGA_LAYOUT
  [self.style yogaNodeCreateIfNeeded];
  [self.activityIndicatorNode.style yogaNodeCreateIfNeeded];
  [self addYogaChild:self.activityIndicatorNode];

  self.style.justifyContent = ASStackLayoutJustifyContentCenter;
  self.style.alignItems = ASStackLayoutAlignItemsCenter;
#endif
}

@end
