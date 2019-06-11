//
//  OverviewCellNode.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "OverviewCellNode.h"
#import "LayoutExampleNodes.h"
#import "Utilities.h"

@interface OverviewCellNode ()
@property (nonatomic, strong) ASTextNode *titleNode;
@property (nonatomic, strong) ASTextNode *descriptionNode;
@end

@implementation OverviewCellNode

- (instancetype)initWithLayoutExampleClass:(Class)layoutExampleClass
{
    self = [super init];
    if (self) {
      self.automaticallyManagesSubnodes = YES;
      
      _layoutExampleClass = layoutExampleClass;
      
      _titleNode = [[ASTextNode alloc] init];
      _titleNode.attributedText = [NSAttributedString attributedStringWithString:[layoutExampleClass title]
                                                                  fontSize:16
                                                                     color:[UIColor blackColor]];
  
      _descriptionNode = [[ASTextNode alloc] init];
      _descriptionNode.attributedText = [NSAttributedString attributedStringWithString:[layoutExampleClass descriptionTitle]
                                                                              fontSize:12
                                                                                 color:[UIColor lightGrayColor]];
   }
    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
    verticalStackSpec.alignItems = ASStackLayoutAlignItemsStart;
    verticalStackSpec.spacing = 5.0;
    verticalStackSpec.children = @[self.titleNode, self.descriptionNode];
    
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 16, 10, 10) child:verticalStackSpec];
}

@end
