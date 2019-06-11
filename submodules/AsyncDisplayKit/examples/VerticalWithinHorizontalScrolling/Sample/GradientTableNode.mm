//
//  GradientTableNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "GradientTableNode.h"
#import "RandomCoreGraphicsNode.h"
#import "AppDelegate.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>


@interface GradientTableNode () <ASTableDelegate, ASTableDataSource>
{
  ASTableNode *_tableNode;
  CGSize _elementSize;
}

@end


@implementation GradientTableNode

- (instancetype)initWithElementSize:(CGSize)size
{
  if (!(self = [super init]))
    return nil;

  _elementSize = size;

  _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  _tableNode.delegate = self;
  _tableNode.dataSource = self;
  
  ASRangeTuningParameters rangeTuningParameters;
  rangeTuningParameters.leadingBufferScreenfuls = 1.0;
  rangeTuningParameters.trailingBufferScreenfuls = 0.5;
  [_tableNode setTuningParameters:rangeTuningParameters forRangeType:ASLayoutRangeTypeDisplay];
  
  [self addSubnode:_tableNode];
  
  return self;
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

- (ASCellNode *)tableNode:(ASTableNode *)tableNode nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
  elementNode.style.preferredSize = _elementSize;
  elementNode.indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:_pageNumber];
  
  return elementNode;
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableNode deselectRowAtIndexPath:indexPath animated:NO];
  [_tableNode reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)layout
{
  [super layout];
  
  _tableNode.frame = self.bounds;
}

@end
