//
//  ASListKitTestAdapterDataSource.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASListKitTestAdapterDataSource.h"
#import "ASListTestSection.h"

@implementation ASListKitTestAdapterDataSource

- (NSArray *)objectsForListAdapter:(IGListAdapter *)listAdapter
{
  return self.objects;
}

- (IGListSectionController *)listAdapter:(IGListAdapter *)listAdapter sectionControllerForObject:(id)object
{
  ASListTestSection *section = [[ASListTestSection alloc] init];
  return section;
}

- (nullable UIView *)emptyViewForListAdapter:(IGListAdapter *)listAdapter
{
  return nil;
}

@end
