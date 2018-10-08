//
//  HorizontalScrollCellNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "HorizontalScrollCellNode.h"
#import "RandomCoreGraphicsNode.h"
#import "AppDelegate.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>

static const CGFloat kOuterPadding = 16.0f;
static const CGFloat kInnerPadding = 10.0f;

@interface HorizontalScrollCellNode ()
{
  ASCollectionNode *_collectionNode;
  CGSize _elementSize;
  ASDisplayNode *_divider;
}

@end


@implementation HorizontalScrollCellNode

#pragma mark - Lifecycle

- (instancetype)initWithElementSize:(CGSize)size
{
  if (!(self = [super init]))
    return nil;

  _elementSize = size;

  // the containing table uses -nodeForRowAtIndexPath (rather than -nodeBlockForRowAtIndexPath),
  // so this init method will always be run on the main thread (thus it is safe to do UIKit things).
  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.itemSize = _elementSize;
  flowLayout.minimumInteritemSpacing = kInnerPadding;
  
  _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
  _collectionNode.delegate = self;
  _collectionNode.dataSource = self;
  [self addSubnode:_collectionNode];
  
  // hairline cell separator
  _divider = [[ASDisplayNode alloc] init];
  _divider.backgroundColor = [UIColor lightGrayColor];
  [self addSubnode:_divider];

  return self;
}

// With box model, you don't need to override this method, unless you want to add custom logic.
- (void)layout
{
  [super layout];
  
  _collectionNode.view.contentInset = UIEdgeInsetsMake(0.0, kOuterPadding, 0.0, kOuterPadding);
  
  // Manually layout the divider.
  CGFloat pixelHeight = 1.0f / [[UIScreen mainScreen] scale];
  _divider.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, pixelHeight);
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGSize collectionNodeSize = CGSizeMake(constrainedSize.max.width, _elementSize.height);
  _collectionNode.style.preferredSize = collectionNodeSize;
  
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
  insetSpec.insets = UIEdgeInsetsMake(kOuterPadding, 0.0, kOuterPadding, 0.0);
  insetSpec.child = _collectionNode;
  
  return insetSpec;
}

#pragma mark - ASCollectionNode

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return 5;
}

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  CGSize elementSize = _elementSize;
  
  return ^{
    RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
    elementNode.style.preferredSize = elementSize;
    return elementNode;
  };
}

@end
