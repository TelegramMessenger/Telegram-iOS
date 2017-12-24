//
//  ASTextKitComponents.mm
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextKitComponents.h>
#import <AsyncDisplayKit/ASAssert.h>

#import <tgmath.h>

@interface ASTextKitComponentsTextView ()
@property (atomic, assign) CGRect threadSafeBounds;
@end

@implementation ASTextKitComponentsTextView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
  self = [super initWithFrame:frame textContainer:textContainer];
  if (self) {
    _threadSafeBounds = self.bounds;
  }
  return self;
}

- (void)setFrame:(CGRect)frame
{
  ASDisplayNodeAssertMainThread();
  [super setFrame:frame];
  self.threadSafeBounds = self.bounds;
}

- (void)setBounds:(CGRect)bounds
{
  ASDisplayNodeAssertMainThread();
  [super setBounds:bounds];
  self.threadSafeBounds = bounds;
}

@end

@interface ASTextKitComponents ()

// read-write redeclarations
@property (nonatomic, strong, readwrite) NSTextStorage *textStorage;
@property (nonatomic, strong, readwrite) NSTextContainer *textContainer;
@property (nonatomic, strong, readwrite) NSLayoutManager *layoutManager;

@end

@implementation ASTextKitComponents

#pragma mark - Class

+ (instancetype)componentsWithAttributedSeedString:(NSAttributedString *)attributedSeedString
                                 textContainerSize:(CGSize)textContainerSize
{
  NSTextStorage *textStorage = attributedSeedString ? [[NSTextStorage alloc] initWithAttributedString:attributedSeedString] : [[NSTextStorage alloc] init];

  return [self componentsWithTextStorage:textStorage
                       textContainerSize:textContainerSize
                           layoutManager:[[NSLayoutManager alloc] init]];
}

+ (instancetype)componentsWithTextStorage:(NSTextStorage *)textStorage
                        textContainerSize:(CGSize)textContainerSize
                            layoutManager:(NSLayoutManager *)layoutManager
{
  ASTextKitComponents *components = [[self alloc] init];

  components.textStorage = textStorage;

  components.layoutManager = layoutManager;
  [components.textStorage addLayoutManager:components.layoutManager];

  components.textContainer = [[NSTextContainer alloc] initWithSize:textContainerSize];
  components.textContainer.lineFragmentPadding = 0.0; // We want the text laid out up to the very edges of the text-view.
  [components.layoutManager addTextContainer:components.textContainer];

  return components;
}

#pragma mark - Lifecycle

- (void)dealloc
{
  // Nil out all delegates to prevent crash
  if (_textView) {
    ASDisplayNodeAssertMainThread();
    _textView.delegate = nil;
  }
  _layoutManager.delegate = nil;
}

#pragma mark - Sizing

- (CGSize)sizeForConstrainedWidth:(CGFloat)constrainedWidth
{
  ASTextKitComponents *components = self;

  // If our text-view's width is already the constrained width, we can use our existing TextKit stack for this sizing calculation.
  // Otherwise, we create a temporary stack to size for `constrainedWidth`.
  if (CGRectGetWidth(components.textView.threadSafeBounds) != constrainedWidth) {
    components = [ASTextKitComponents componentsWithAttributedSeedString:components.textStorage textContainerSize:CGSizeMake(constrainedWidth, CGFLOAT_MAX)];
  }

  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by -usedRectForTextContainer:).
  [components.layoutManager ensureLayoutForTextContainer:components.textContainer];
  CGSize textSize = [components.layoutManager usedRectForTextContainer:components.textContainer].size;

  return textSize;
}

- (CGSize)sizeForConstrainedWidth:(CGFloat)constrainedWidth
              forMaxNumberOfLines:(NSInteger)maxNumberOfLines
{
  if (maxNumberOfLines == 0) {
    return [self sizeForConstrainedWidth:constrainedWidth];
  }
  
  ASTextKitComponents *components = self;
  
  // Always use temporary stack in case of threading issues
  components = [ASTextKitComponents componentsWithAttributedSeedString:components.textStorage textContainerSize:CGSizeMake(constrainedWidth, CGFLOAT_MAX)];

  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by - usedRectForTextContainer:).
  [components.layoutManager ensureLayoutForTextContainer:components.textContainer];
  
  CGFloat width = [components.layoutManager usedRectForTextContainer:components.textContainer].size.width;
  
  // Calculate height based on line fragments
  // Based on calculating number of lines from: http://asciiwwdc.com/2013/sessions/220
  NSRange glyphRange, lineRange = NSMakeRange(0, 0);
  CGRect rect = CGRectZero;
  CGFloat height = 0;
  CGFloat lastOriginY = -1.0;
  NSUInteger numberOfLines = 0;
  
  glyphRange = [components.layoutManager glyphRangeForTextContainer:components.textContainer];
  
  while (lineRange.location < NSMaxRange(glyphRange)) {
    rect = [components.layoutManager lineFragmentRectForGlyphAtIndex:lineRange.location
                                                      effectiveRange:&lineRange];
    
    if (CGRectGetMinY(rect) > lastOriginY) {
      ++numberOfLines;
      if (numberOfLines == maxNumberOfLines) {
        height = rect.origin.y + rect.size.height;
        break;
      }
    }
    
    lastOriginY = CGRectGetMinY(rect);
    lineRange.location = NSMaxRange(lineRange);
  }
  
  CGFloat fragmentHeight = rect.origin.y + rect.size.height;
  CGFloat finalHeight = std::ceil(std::fmax(height, fragmentHeight));
  
  CGSize size = CGSizeMake(width, finalHeight);
  
  return size;
}

@end
