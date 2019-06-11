//
//  ASListTestSection.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASListTestSection.h"
#import "ASListTestCellNode.h"

@implementation ASListTestSection

- (instancetype)init
{
  if (self = [super init])
{
    _selectedItemIndex = NSNotFound;
  }
  return self;
}

- (NSInteger)numberOfItems
{
  return self.itemCount;
}

- (CGSize)sizeForItemAtIndex:(NSInteger)index
{
  return [ASIGListSectionControllerMethods sizeForItemAtIndex:index];
}

- (__kindof UICollectionViewCell *)cellForItemAtIndex:(NSInteger)index
{
  return [ASIGListSectionControllerMethods cellForItemAtIndex:index sectionController:self];
}

- (void)didUpdateToObject:(id)object
{
  if ([object isKindOfClass:[NSNumber class]])
{
    self.itemCount = [object integerValue];
  }
}

- (void)didSelectItemAtIndex:(NSInteger)index
{
  self.selectedItemIndex = index;
}

- (ASCellNodeBlock)nodeBlockForItemAtIndex:(NSInteger)index
{
  return ^{
    ASListTestCellNode *node = [[ASListTestCellNode alloc] init];
    node.style.preferredSize = CGSizeMake(100, 10);
    return node;
  };
}

@end
