//
//  ASListTestSupplementarySource.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASListTestSupplementarySource.h"
#import "ASListTestSupplementaryNode.h"

@implementation ASListTestSupplementarySource

- (__kindof UICollectionReusableView *)viewForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index
{
  return [ASIGListSupplementaryViewSourceMethods viewForSupplementaryElementOfKind:elementKind atIndex:index sectionController:self.sectionController];
}

- (CGSize)sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index
{
  return [ASIGListSupplementaryViewSourceMethods sizeForSupplementaryViewOfKind:elementKind atIndex:index];
}

- (ASCellNodeBlock)nodeBlockForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index
{
  return ^{
    ASListTestSupplementaryNode *node = [[ASListTestSupplementaryNode alloc] init];
    node.style.preferredSize = CGSizeMake(100, 10);
    return node;
  };
}

@end
