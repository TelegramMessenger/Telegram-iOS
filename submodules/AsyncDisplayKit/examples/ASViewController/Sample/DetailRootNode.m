//
//  DetailRootNode.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "DetailRootNode.h"
#import "DetailCellNode.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

static const NSInteger kImageHeight = 200;


@interface DetailRootNode () <ASCollectionDataSource, ASCollectionDelegate>

@property (nonatomic, copy) NSString *imageCategory;
@property (nonatomic, strong) ASCollectionNode *collectionNode;

@end


@implementation DetailRootNode

#pragma mark - Lifecycle

- (instancetype)initWithImageCategory:(NSString *)imageCategory
{
    self = [super init];
    if (self) {
        // Enable automaticallyManagesSubnodes so the first time the layout pass of the node is happening all nodes that are referenced
        // in the laaout specification within layoutSpecThatFits: will be added automatically
        self.automaticallyManagesSubnodes = YES;
        
        _imageCategory = imageCategory;

        // Create ASCollectionView. We don't have to add it explicitly as subnode as we will set usesImplicitHierarchyManagement to YES
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
        _collectionNode.delegate = self;
        _collectionNode.dataSource = self;
        _collectionNode.backgroundColor = [UIColor whiteColor];
    }
    
    return self;
}

- (void)dealloc
{
    _collectionNode.delegate = nil;
    _collectionNode.dataSource = nil;
}

#pragma mark - ASDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    return [ASWrapperLayoutSpec wrapperWithLayoutElement:self.collectionNode];
}

#pragma mark - ASCollectionDataSource

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
    return 10;
}

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *imageCategory = self.imageCategory;
    return ^{
        DetailCellNode *node = [[DetailCellNode alloc] init];
        node.row = indexPath.row;
        node.imageCategory = imageCategory;
        return node;
    };
}

- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode constrainedSizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize imageSize = CGSizeMake(CGRectGetWidth(collectionNode.view.frame), kImageHeight);
    return ASSizeRangeMake(imageSize, imageSize);
}

@end
