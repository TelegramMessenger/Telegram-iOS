//
//  ASButtonNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASButtonNode.h>
#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASBackgroundLayoutSpec.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASAbsoluteLayoutSpec.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASImageNode.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

@interface ASButtonNode ()
{
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
}

@end

@implementation ASButtonNode

@synthesize contentSpacing = _contentSpacing;
@synthesize laysOutHorizontally = _laysOutHorizontally;
@synthesize contentVerticalAlignment = _contentVerticalAlignment;
@synthesize contentHorizontalAlignment = _contentHorizontalAlignment;
@synthesize contentEdgeInsets = _contentEdgeInsets;
@synthesize imageAlignment = _imageAlignment;
@synthesize titleNode = _titleNode;
@synthesize imageNode = _imageNode;
@synthesize backgroundImageNode = _backgroundImageNode;

- (instancetype)init
{
  if (self = [super init]) {
    self.automaticallyManagesSubnodes = YES;
    
    _contentSpacing = 8.0;
    _laysOutHorizontally = YES;
    _contentHorizontalAlignment = ASHorizontalAlignmentMiddle;
    _contentVerticalAlignment = ASVerticalAlignmentCenter;
    _contentEdgeInsets = UIEdgeInsetsZero;
    _imageAlignment = ASButtonNodeImageAlignmentBeginning;
    self.accessibilityTraits = self.defaultAccessibilityTraits;
  }
  return self;
}

- (ASTextNode *)titleNode
{
  ASLockScopeSelf();
  if (!_titleNode) {
    _titleNode = [[ASTextNode alloc] init];
#if TARGET_OS_IOS 
      // tvOS needs access to the underlying view
      // of the button node to add a touch handler.
    [_titleNode setLayerBacked:YES];
#endif
    _titleNode.style.flexShrink = 1.0;
  }
  return _titleNode;
}

- (ASImageNode *)imageNode
{
  ASLockScopeSelf();
  if (!_imageNode) {
    _imageNode = [[ASImageNode alloc] init];
    [_imageNode setLayerBacked:YES];
  }
  return _imageNode;
}

- (ASImageNode *)backgroundImageNode
{
  ASLockScopeSelf();
  if (!_backgroundImageNode) {
    _backgroundImageNode = [[ASImageNode alloc] init];
    [_backgroundImageNode setLayerBacked:YES];
    [_backgroundImageNode setContentMode:UIViewContentModeScaleToFill];
  }
  return _backgroundImageNode;
}

- (void)setLayerBacked:(BOOL)layerBacked
{
  ASDisplayNodeAssert(!layerBacked, @"ASButtonNode must not be layer backed!");
  [super setLayerBacked:layerBacked];
}

- (void)setEnabled:(BOOL)enabled
{
  if (self.enabled != enabled) {
    [super setEnabled:enabled];
    self.accessibilityTraits = self.defaultAccessibilityTraits;
    [self updateButtonContent];
  }
}

- (void)setHighlighted:(BOOL)highlighted
{
  if (self.highlighted != highlighted) {
    [super setHighlighted:highlighted];
    [self updateButtonContent];
  }
}

- (void)setSelected:(BOOL)selected
{
  if (self.selected != selected) {
    [super setSelected:selected];
    [self updateButtonContent];
  }
}

- (void)updateButtonContent
{
  [self updateBackgroundImage];
  [self updateImage];
  [self updateTitle];
}

- (void)setDisplaysAsynchronously:(BOOL)displaysAsynchronously
{
  [super setDisplaysAsynchronously:displaysAsynchronously];
  [self.backgroundImageNode setDisplaysAsynchronously:displaysAsynchronously];
  [self.imageNode setDisplaysAsynchronously:displaysAsynchronously];
  [self.titleNode setDisplaysAsynchronously:displaysAsynchronously];
}

- (void)updateImage
{
  [self lock];
  
  UIImage *newImage;
  if (self.enabled == NO && _disabledImage) {
    newImage = _disabledImage;
  } else if (self.highlighted && self.selected && _selectedHighlightedImage) {
    newImage = _selectedHighlightedImage;
  } else if (self.highlighted && _highlightedImage) {
    newImage = _highlightedImage;
  } else if (self.selected && _selectedImage) {
    newImage = _selectedImage;
  } else {
    newImage = _normalImage;
  }
  
  if ((_imageNode != nil || newImage != nil) && newImage != self.imageNode.image) {
    _imageNode.image = newImage;
    [self unlock];

    [self setNeedsLayout];
    return;
  }
  
  [self unlock];
}

- (void)updateTitle
{
  [self lock];

  NSAttributedString *newTitle;
  if (self.enabled == NO && _disabledAttributedTitle) {
    newTitle = _disabledAttributedTitle;
  } else if (self.highlighted && self.selected && _selectedHighlightedAttributedTitle) {
    newTitle = _selectedHighlightedAttributedTitle;
  } else if (self.highlighted && _highlightedAttributedTitle) {
    newTitle = _highlightedAttributedTitle;
  } else if (self.selected && _selectedAttributedTitle) {
    newTitle = _selectedAttributedTitle;
  } else {
    newTitle = _normalAttributedTitle;
  }

  // Calling self.titleNode is essential here because _titleNode is lazily created by the getter.
  if ((_titleNode != nil || newTitle.length > 0) && [self.titleNode.attributedText isEqualToAttributedString:newTitle] == NO) {
    _titleNode.attributedText = newTitle;
    [self unlock];
    
    self.accessibilityLabel = self.defaultAccessibilityLabel;
    [self setNeedsLayout];
    return;
  }
  
  [self unlock];
}

- (void)updateBackgroundImage
{
  [self lock];
  
  UIImage *newImage;
  if (self.enabled == NO && _disabledBackgroundImage) {
    newImage = _disabledBackgroundImage;
  } else if (self.highlighted && self.selected && _selectedHighlightedBackgroundImage) {
    newImage = _selectedHighlightedBackgroundImage;
  } else if (self.highlighted && _highlightedBackgroundImage) {
    newImage = _highlightedBackgroundImage;
  } else if (self.selected && _selectedBackgroundImage) {
    newImage = _selectedBackgroundImage;
  } else {
    newImage = _normalBackgroundImage;
  }
  
  if ((_backgroundImageNode != nil || newImage != nil) && newImage != self.backgroundImageNode.image) {
    _backgroundImageNode.image = newImage;
    [self unlock];
    
    [self setNeedsLayout];
    return;
  }
  
  [self unlock];
}

- (CGFloat)contentSpacing
{
  ASLockScopeSelf();
  return _contentSpacing;
}

- (void)setContentSpacing:(CGFloat)contentSpacing
{
  if (ASLockedSelfCompareAssign(_contentSpacing, contentSpacing)) {
    [self setNeedsLayout];
  }
}

- (BOOL)laysOutHorizontally
{
  ASLockScopeSelf();
  return _laysOutHorizontally;
}

- (void)setLaysOutHorizontally:(BOOL)laysOutHorizontally
{
  if (ASLockedSelfCompareAssign(_laysOutHorizontally, laysOutHorizontally)) {
    [self setNeedsLayout];
  }
}

- (ASVerticalAlignment)contentVerticalAlignment
{
  ASLockScopeSelf();
  return _contentVerticalAlignment;
}

- (void)setContentVerticalAlignment:(ASVerticalAlignment)contentVerticalAlignment
{
  ASLockScopeSelf();
  _contentVerticalAlignment = contentVerticalAlignment;
}

- (ASHorizontalAlignment)contentHorizontalAlignment
{
  ASLockScopeSelf();
  return _contentHorizontalAlignment;
}

- (void)setContentHorizontalAlignment:(ASHorizontalAlignment)contentHorizontalAlignment
{
  ASLockScopeSelf();
  _contentHorizontalAlignment = contentHorizontalAlignment;
}

- (UIEdgeInsets)contentEdgeInsets
{
  ASLockScopeSelf();
  return _contentEdgeInsets;
}

- (void)setContentEdgeInsets:(UIEdgeInsets)contentEdgeInsets
{
  ASLockScopeSelf();
  _contentEdgeInsets = contentEdgeInsets;
}

- (ASButtonNodeImageAlignment)imageAlignment
{
  ASLockScopeSelf();
  return _imageAlignment;
}

- (void)setImageAlignment:(ASButtonNodeImageAlignment)imageAlignment
{
  ASLockScopeSelf();
  _imageAlignment = imageAlignment;
}


#if TARGET_OS_IOS
- (void)setTitle:(NSString *)title withFont:(UIFont *)font withColor:(UIColor *)color forState:(UIControlState)state
{
  NSDictionary *attributes = @{
    NSFontAttributeName: font ? : [UIFont systemFontOfSize:[UIFont buttonFontSize]],
    NSForegroundColorAttributeName : color ? : [UIColor blackColor]
  };
    
  NSAttributedString *string = [[NSAttributedString alloc] initWithString:title attributes:attributes];
  [self setAttributedTitle:string forState:state];
}
#endif

- (NSAttributedString *)attributedTitleForState:(UIControlState)state
{
  ASLockScopeSelf();
  switch (state) {
    case UIControlStateNormal:
      return _normalAttributedTitle;
      
    case UIControlStateHighlighted:
      return _highlightedAttributedTitle;
      
    case UIControlStateSelected:
      return _selectedAttributedTitle;
        
    case UIControlStateSelected | UIControlStateHighlighted:
      return _selectedHighlightedAttributedTitle;
      
    case UIControlStateDisabled:
      return _disabledAttributedTitle;
          
    default:
      return _normalAttributedTitle;
  }
}

- (void)setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state
{
  {
    ASLockScopeSelf();
    switch (state) {
      case UIControlStateNormal:
        _normalAttributedTitle = [title copy];
        break;
        
      case UIControlStateHighlighted:
        _highlightedAttributedTitle = [title copy];
        break;
        
      case UIControlStateSelected:
        _selectedAttributedTitle = [title copy];
        break;
            
      case UIControlStateSelected | UIControlStateHighlighted:
        _selectedHighlightedAttributedTitle = [title copy];
        break;
        
      case UIControlStateDisabled:
        _disabledAttributedTitle = [title copy];
        break;
        
      default:
        break;
    }
  }

  [self updateTitle];
}

- (UIImage *)imageForState:(UIControlState)state
{
  ASLockScopeSelf();
  switch (state) {
    case UIControlStateNormal:
      return _normalImage;
      
    case UIControlStateHighlighted:
      return _highlightedImage;
      
    case UIControlStateSelected:
      return _selectedImage;
      
    case UIControlStateSelected | UIControlStateHighlighted:
      return _selectedHighlightedImage;
          
    case UIControlStateDisabled:
      return _disabledImage;
      
    default:
      return _normalImage;
  }
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state
{
  {
    ASLockScopeSelf();
    switch (state) {
      case UIControlStateNormal:
        _normalImage = image;
        break;
        
      case UIControlStateHighlighted:
        _highlightedImage = image;
        break;
        
      case UIControlStateSelected:
        _selectedImage = image;
        break;
      
      case UIControlStateSelected | UIControlStateHighlighted:
        _selectedHighlightedImage = image;
        break;
            
      case UIControlStateDisabled:
        _disabledImage = image;
        break;
        
      default:
        break;
    }
  }

  [self updateImage];
}

- (UIImage *)backgroundImageForState:(UIControlState)state
{
  ASLockScopeSelf();
  switch (state) {
    case UIControlStateNormal:
      return _normalBackgroundImage;
    
    case UIControlStateHighlighted:
      return _highlightedBackgroundImage;
    
    case UIControlStateSelected:
      return _selectedBackgroundImage;
    
    case UIControlStateSelected | UIControlStateHighlighted:
      return _selectedHighlightedBackgroundImage;
    
    case UIControlStateDisabled:
      return _disabledBackgroundImage;
    
    default:
      return _normalBackgroundImage;
  }
}

- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state
{
  {
    ASLockScopeSelf();
    switch (state) {
      case UIControlStateNormal:
        _normalBackgroundImage = image;
        break;
        
      case UIControlStateHighlighted:
        _highlightedBackgroundImage = image;
        break;
        
      case UIControlStateSelected:
        _selectedBackgroundImage = image;
        break;
            
      case UIControlStateSelected | UIControlStateHighlighted:
        _selectedHighlightedBackgroundImage = image;
        break;
        
      case UIControlStateDisabled:
        _disabledBackgroundImage = image;
        break;
        
      default:
        break;
    }
  }

  [self updateBackgroundImage];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  UIEdgeInsets contentEdgeInsets;
  ASButtonNodeImageAlignment imageAlignment;
  ASLayoutSpec *spec;
  ASStackLayoutSpec *stack = [[ASStackLayoutSpec alloc] init];
  {
    ASLockScopeSelf();
    stack.direction = _laysOutHorizontally ? ASStackLayoutDirectionHorizontal : ASStackLayoutDirectionVertical;
    stack.spacing = _contentSpacing;
    stack.horizontalAlignment = _contentHorizontalAlignment;
    stack.verticalAlignment = _contentVerticalAlignment;
    
    contentEdgeInsets = _contentEdgeInsets;
    imageAlignment = _imageAlignment;
  }
  
  NSMutableArray *children = [[NSMutableArray alloc] initWithCapacity:2];
  if (_imageNode.image) {
    [children addObject:_imageNode];
  }
  
  if (_titleNode.attributedText.length > 0) {
    if (imageAlignment == ASButtonNodeImageAlignmentBeginning) {
      [children addObject:_titleNode];
    } else {
      [children insertObject:_titleNode atIndex:0];
    }
  }
  
  stack.children = children;
  
  spec = stack;
  
  if (UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsetsZero, contentEdgeInsets) == NO) {
    spec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:contentEdgeInsets child:spec];
  }

  if (_backgroundImageNode.image) {
    spec = [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:spec background:_backgroundImageNode];
  }
  
  return spec;
}

- (NSString *)defaultAccessibilityLabel
{
  ASLockScopeSelf();
  return _titleNode.defaultAccessibilityLabel;
}

- (UIAccessibilityTraits)defaultAccessibilityTraits
{
  return self.enabled ? UIAccessibilityTraitButton
                      : (UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled);
}

- (void)layout
{
  [super layout];

  _backgroundImageNode.hidden = (_backgroundImageNode.image == nil);
  _imageNode.hidden = (_imageNode.image == nil);
  _titleNode.hidden = (_titleNode.attributedText.length == 0);
}

@end
