//
//  ASButtonNode+Yoga.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>
#import "ASButtonNode+Yoga.h"
#import <AsyncDisplayKit/ASButtonNode+Private.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASStackLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASThread.h>

#if YOGA
static void ASButtonNodeResolveHorizontalAlignmentForStyle(ASLayoutElementStyle *style, ASStackLayoutDirection _direction, ASHorizontalAlignment _horizontalAlignment, ASStackLayoutJustifyContent _justifyContent, ASStackLayoutAlignItems _alignItems) {
  if (_direction == ASStackLayoutDirectionHorizontal) {
    style.justifyContent = justifyContent(_horizontalAlignment, _justifyContent);
  } else {
    style.alignItems = alignment(_horizontalAlignment, _alignItems);
  }
}

static void ASButtonNodeResolveVerticalAlignmentForStyle(ASLayoutElementStyle *style, ASStackLayoutDirection _direction, ASVerticalAlignment _verticalAlignment, ASStackLayoutJustifyContent _justifyContent, ASStackLayoutAlignItems _alignItems) {
  if (_direction == ASStackLayoutDirectionHorizontal) {
    style.alignItems = alignment(_verticalAlignment, _alignItems);
  } else {
    style.justifyContent = justifyContent(_verticalAlignment, _justifyContent);
  }
}

@implementation ASButtonNode (Yoga)

- (void)updateYogaLayoutIfNeeded
{
  NSMutableArray<ASDisplayNode *> *children = [[NSMutableArray alloc] initWithCapacity:2];
  {
    ASLockScopeSelf();

    // Build up yoga children for button node  again
    unowned ASLayoutElementStyle *style = [self _locked_style];
    [style yogaNodeCreateIfNeeded];

    // Setup stack layout values
    style.flexDirection = _laysOutHorizontally ? ASStackLayoutDirectionHorizontal : ASStackLayoutDirectionVertical;

    // Resolve horizontal and vertical alignment
    ASButtonNodeResolveHorizontalAlignmentForStyle(style, style.flexDirection, _contentHorizontalAlignment, style.justifyContent, style.alignItems);
    ASButtonNodeResolveVerticalAlignmentForStyle(style, style.flexDirection, _contentVerticalAlignment, style.justifyContent, style.alignItems);

    // Setup new yoga children
    if (_imageNode.image != nil) {
      [_imageNode.style yogaNodeCreateIfNeeded];
      [children addObject:_imageNode];
    }

    if (_titleNode.attributedText.length > 0) {
      [_titleNode.style yogaNodeCreateIfNeeded];
      if (_imageAlignment == ASButtonNodeImageAlignmentBeginning) {
        [children addObject:_titleNode];
      } else {
        [children insertObject:_titleNode atIndex:0];
      }
    }

    // Add spacing between title and button
    if (children.count == 2) {
      unowned ASLayoutElementStyle *firstChildStyle = children.firstObject.style;
      if (_laysOutHorizontally) {
        firstChildStyle.margin = ASEdgeInsetsMake(UIEdgeInsetsMake(0, 0, 0, _contentSpacing));
      } else {
        firstChildStyle.margin = ASEdgeInsetsMake(UIEdgeInsetsMake(0, 0, _contentSpacing, 0));
      }
    }

    // Add padding to button
    if (UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsetsZero, _contentEdgeInsets) == NO) {
      style.padding = ASEdgeInsetsMake(_contentEdgeInsets);
    }

    // Add background node
    if (_backgroundImageNode.image) {
      [_backgroundImageNode.style yogaNodeCreateIfNeeded];
      [children insertObject:_backgroundImageNode atIndex:0];

      _backgroundImageNode.style.positionType = YGPositionTypeAbsolute;
      _backgroundImageNode.style.position = ASEdgeInsetsMake(UIEdgeInsetsZero);
    }
  }

  // Update new children
  [self setYogaChildren:children];
}

@end

#else

@implementation ASButtonNode (Yoga)

- (void)updateYogaLayoutIfNeeded {}

@end

#endif
