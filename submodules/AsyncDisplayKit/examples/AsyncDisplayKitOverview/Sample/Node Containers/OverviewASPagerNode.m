//
//  OverviewASPagerNode.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "OverviewASPagerNode.h"

#pragma mark - Helper

static UIColor *OverViewASPagerNodeRandomColor() {
    CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
    CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
    CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}


#pragma mark - OverviewASPageNode

@interface OverviewASPageNode : ASCellNode @end

@implementation OverviewASPageNode

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
    return [ASLayout layoutWithLayoutElement:self size:constrainedSize.max];
}

@end


#pragma mark - OverviewASPagerNode

@interface OverviewASPagerNode () <ASPagerDataSource, ASPagerDelegate>
@property (nonatomic, strong) ASPagerNode *node;
@property (nonatomic, copy) NSArray *data;
@end

@implementation OverviewASPagerNode

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    _node = [ASPagerNode new];
    _node.dataSource = self;
    _node.delegate = self;
    [self addSubnode:_node];
    
    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    // 100% of container
    _node.style.width = ASDimensionMakeWithFraction(1.0);
    _node.style.height = ASDimensionMakeWithFraction(1.0);
    return [ASWrapperLayoutSpec wrapperWithLayoutElement:_node];
}

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
    return 4;
}

- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index
{
    return ^{
        ASCellNode *cellNode = [OverviewASPageNode new];
        cellNode.backgroundColor = OverViewASPagerNodeRandomColor();
        return cellNode;
    };
}


@end
