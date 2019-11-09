//
//  _ASCollectionViewCell.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/_ASCollectionViewCell.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import "Private/ASInternalHelpers.h"

@implementation _ASCollectionViewCell

- (ASCellNode *)node
{
  return self.element.node;
}

- (void)setElement:(ASCollectionElement *)element
{
  ASDisplayNodeAssertMainThread();
  ASCellNode *node = element.node;
  node.layoutAttributes = _layoutAttributes;
  _element = element;
  
  [node __setSelectedFromUIKit:self.selected];
  [node __setHighlightedFromUIKit:self.highlighted];
}

- (BOOL)consumesCellNodeVisibilityEvents
{
  ASCellNode *node = self.node;
  if (node == nil) {
    return NO;
  }
  return ASSubclassOverridesSelector([ASCellNode class], [node class], @selector(cellNodeVisibilityEvent:inScrollView:withCellFrame:));
}

- (void)cellNodeVisibilityEvent:(ASCellNodeVisibilityEvent)event inScrollView:(UIScrollView *)scrollView
{
  [self.node cellNodeVisibilityEvent:event inScrollView:scrollView withCellFrame:self.frame];
}

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  [self.node __setSelectedFromUIKit:selected];
}

- (void)setHighlighted:(BOOL)highlighted
{
  [super setHighlighted:highlighted];
  [self.node __setHighlightedFromUIKit:highlighted];
}

- (void)setLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  _layoutAttributes = layoutAttributes;
  self.node.layoutAttributes = layoutAttributes;
}

- (void)prepareForReuse
{
  self.layoutAttributes = nil;

  // Need to clear element before UIKit calls setSelected:NO / setHighlighted:NO on its cells
  self.element = nil;
  [super prepareForReuse];
}

/**
 * In the initial case, this is called by UICollectionView during cell dequeueing, before
 *   we get a chance to assign a node to it, so we must be sure to set these layout attributes
 *   on our node when one is next assigned to us in @c setNode: . Since there may be cases when we _do_ already
 *   have our node assigned e.g. during a layout update for existing cells, we also attempt
 *   to update it now.
 */
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  [super applyLayoutAttributes:layoutAttributes];
  self.layoutAttributes = layoutAttributes;
}

/**
 * Keep our node filling our content view.
 */
- (void)layoutSubviews
{
  [super layoutSubviews];
  self.node.frame = self.contentView.bounds;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  /**
   * The documentation for hitTest:withEvent: on an UIView explicitly states the fact that:
   * it ignores view objects that are hidden, that have disabled user interactions, or have an
   * alpha level less than 0.01.
   * To be able to determine if the collection view cell should skip going further down the tree
   * based on the states above we use a valid point within the cells bounds and check the
   * superclass hitTest:withEvent: implementation. If this returns a valid value we can go on with
   * checking the node as it's expected to not be in one of these states.
   */
  if (![super hitTest:self.bounds.origin withEvent:event]) {
    return nil;
  }

  CGPoint pointOnNode = [self.node.view convertPoint:point fromView:self];
  return [self.node hitTest:pointOnNode withEvent:event];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(nullable UIEvent *)event
{
  CGPoint pointOnNode = [self.node.view convertPoint:point fromView:self];
  return [self.node pointInside:pointOnNode withEvent:event];
}

@end

/**
 * A category that makes _ASCollectionViewCell conform to IGListBindable.
 *
 * We don't need to do anything to bind the view model – the cell node
 * serves the same purpose.
 */
#if __has_include(<IGListKit/IGListBindable.h>)

#import <IGListKit/IGListBindable.h>

@interface _ASCollectionViewCell (IGListBindable) <IGListBindable>
@end

@implementation _ASCollectionViewCell (IGListBindable)

- (void)bindViewModel:(id)viewModel
{
  // nop
}

@end

#endif
#endif
