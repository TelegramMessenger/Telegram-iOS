//
//  ASScrollNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

NS_ASSUME_NONNULL_BEGIN

@class UIScrollView;

/**
 * Simple node that wraps UIScrollView.
 */
@interface ASScrollNode : ASDisplayNode

/**
 * @abstract The node's UIScrollView.
 */
@property (readonly) UIScrollView *view;

/**
 * @abstract When enabled, the size calculated by the node's layout spec is used as
 * the .contentSize of the scroll view, instead of the bounds size.  The bounds is instead
 * allowed to match the parent's size (whenever it is finite - otherwise, the bounds size
 * also grows to the full contentSize).  It also works with .layoutSpecBlock().
 * NOTE: Most users of ASScrollNode will want to use this, and may be enabled by default later.
 */
@property BOOL automaticallyManagesContentSize;

/**
 * @abstract This property controls how the constrainedSize is interpreted when sizing the content.
 * if you are using automaticallyManagesContentSize, it can be crucial to ensure that the sizing is
 * done how you expect.
 * Vertical: The constrainedSize is interpreted as having unbounded .height (CGFLOAT_MAX), allowing
 * stacks and other content in the layout spec to expand and result in scrollable content.
 * Horizontal: The constrainedSize is interpreted as having unbounded .width (CGFLOAT_MAX), ...
 * Vertical & Horizontal: the constrainedSize is interpreted as unbounded in both directions.
 * @default ASScrollDirectionVerticalDirections
 */
@property ASScrollDirection scrollableDirections;

@end

NS_ASSUME_NONNULL_END
