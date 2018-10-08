//
//  LayoutExampleViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "LayoutExampleViewController.h"
#import "LayoutExampleNodes.h"

@interface LayoutExampleViewController ()
@property (nonatomic, strong) LayoutExampleNode *customNode;
@end

@implementation LayoutExampleViewController

- (instancetype)initWithLayoutExampleClass:(Class)layoutExampleClass
{
  NSAssert([layoutExampleClass isSubclassOfClass:[LayoutExampleNode class]], @"Must pass a subclass of LayoutExampleNode.");
  
  self = [super initWithNode:[ASDisplayNode new]];
  
  if (self) {
    self.title = @"Layout Example";
    
    _customNode = [layoutExampleClass new];
    [self.node addSubnode:_customNode];
    
    BOOL needsOnlyYCentering = [layoutExampleClass isEqual:[HeaderWithRightAndLeftItems class]] ||
                               [layoutExampleClass isEqual:[FlexibleSeparatorSurroundingContent class]];
                               
    self.node.backgroundColor = needsOnlyYCentering ? [UIColor lightGrayColor] : [UIColor whiteColor];
    
    __weak __typeof(self) weakself = self;
    self.node.layoutSpecBlock = ^ASLayoutSpec*(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
      return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:needsOnlyYCentering ? ASCenterLayoutSpecCenteringY : ASCenterLayoutSpecCenteringXY
                                                        sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY
                                                                child:weakself.customNode];
      };
  }
  
  return self;
}

@end
