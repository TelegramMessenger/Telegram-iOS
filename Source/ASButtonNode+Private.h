//
//  ASButtonNode+Private.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASButtonNode.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASImageNode.h>
#import <AsyncDisplayKit/ASStackLayoutDefines.h>

@interface ASButtonNode() {
  NSAttributedString *_normalAttributedTitle;
  NSAttributedString *_highlightedAttributedTitle;
  NSAttributedString *_selectedAttributedTitle;
  NSAttributedString *_selectedHighlightedAttributedTitle;
  NSAttributedString *_disabledAttributedTitle;

  UIImage *_normalImage;
  UIImage *_highlightedImage;
  UIImage *_selectedImage;
  UIImage *_selectedHighlightedImage;
  UIImage *_disabledImage;

  UIImage *_normalBackgroundImage;
  UIImage *_highlightedBackgroundImage;
  UIImage *_selectedBackgroundImage;
  UIImage *_selectedHighlightedBackgroundImage;
  UIImage *_disabledBackgroundImage;
  
  CGFloat _contentSpacing;
  BOOL  _laysOutHorizontally;
  ASVerticalAlignment _contentVerticalAlignment;
  ASHorizontalAlignment _contentHorizontalAlignment;
  UIEdgeInsets _contentEdgeInsets;
  ASButtonNodeImageAlignment _imageAlignment;
  ASTextNode *_titleNode;
  ASImageNode *_imageNode;
  ASImageNode *_backgroundImageNode;
}

@end
