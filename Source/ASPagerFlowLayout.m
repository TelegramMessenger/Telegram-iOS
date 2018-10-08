//
//  ASPagerFlowLayout.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//
#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASPagerFlowLayout.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionView.h>

@interface ASPagerFlowLayout () {
  __weak ASCellNode *_currentCellNode;
}

@end

//TODO make this an ASCollectionViewLayout
@implementation ASPagerFlowLayout

- (ASCollectionView *)asCollectionView
{
  // Dynamic cast is too slow and not worth it.
  return (ASCollectionView *)self.collectionView;
}

- (void)prepareLayout
{
  [super prepareLayout];
  if (_currentCellNode == nil) {
    [self _updateCurrentNode];
  }
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
  // Don't mess around if the user is interacting with the page node. Although if just a rotation happened we should
  // try to use the current index path to not end up setting the target content offset to something in between pages
  if (!self.collectionView.decelerating && !self.collectionView.tracking) {
    NSIndexPath *indexPath = [self.asCollectionView indexPathForNode:_currentCellNode];
    if (indexPath) {
      return [self _targetContentOffsetForItemAtIndexPath:indexPath proposedContentOffset:proposedContentOffset];
    }
  }

  return [super targetContentOffsetForProposedContentOffset:proposedContentOffset];
}

- (CGPoint)_targetContentOffsetForItemAtIndexPath:(NSIndexPath *)indexPath proposedContentOffset:(CGPoint)proposedContentOffset
{
  if ([self _dataSourceIsEmpty]) {
    return proposedContentOffset;
  }
  
  UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
  if (attributes == nil) {
    return proposedContentOffset;
  }

  CGFloat xOffset = (CGRectGetWidth(self.collectionView.bounds) - CGRectGetWidth(attributes.frame)) / 2.0;
  return CGPointMake(attributes.frame.origin.x - xOffset, proposedContentOffset.y);
}

- (BOOL)_dataSourceIsEmpty
{
  return ([self.collectionView numberOfSections] == 0 ||
          [self.collectionView numberOfItemsInSection:0] == 0);
}

- (void)_updateCurrentNode
{
  // Never change node during an animated bounds change (rotation)
  // NOTE! Listening for -prepareForAnimatedBoundsChange and -finalizeAnimatedBoundsChange
  // isn't sufficient here! It's broken!
  NSArray *animKeys = self.collectionView.layer.animationKeys;
  for (NSString *key in animKeys) {
    if ([key hasPrefix:@"bounds"]) {
      return;
    }
  }
  
  CGRect bounds = self.collectionView.bounds;
  CGRect rect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1, 1);

  NSIndexPath *indexPath = [self layoutAttributesForElementsInRect:rect].firstObject.indexPath;
  if (indexPath) {
    ASCellNode *node = [self.asCollectionView nodeForItemAtIndexPath:indexPath];
    if (node) {
      _currentCellNode = node;
    }
  }
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
  [self _updateCurrentNode];
  return [super shouldInvalidateLayoutForBoundsChange:newBounds];
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds
{
  UICollectionViewFlowLayoutInvalidationContext *ctx = (UICollectionViewFlowLayoutInvalidationContext *)[super invalidationContextForBoundsChange:newBounds];
  ctx.invalidateFlowLayoutDelegateMetrics = YES;
  ctx.invalidateFlowLayoutAttributes = YES;
  return ctx;
}

@end

#endif
