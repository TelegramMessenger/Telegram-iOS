//
//  OverviewASTableNode.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "OverviewASTableNode.h"

@interface OverviewASTableNode () <ASTableDataSource, ASTableDelegate>
@property (nonatomic, strong) ASTableNode *node;
@end

@implementation OverviewASTableNode

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    _node = [ASTableNode new];
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


#pragma mark - <ASCollectionDataSource, ASCollectionDelegate>

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
    return 100;
}

- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ^{
        ASTextCellNode *cellNode = [ASTextCellNode new];
        cellNode.text = [NSString stringWithFormat:@"Row: %ld", indexPath.row];
        return cellNode;
    };
}

@end
