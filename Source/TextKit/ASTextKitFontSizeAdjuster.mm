//
//  ASTextKitFontSizeAdjuster.mm
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


#import <AsyncDisplayKit/ASTextKitFontSizeAdjuster.h>

#import <tgmath.h>
#import <mutex>

#import <AsyncDisplayKit/ASLayoutManager.h>
#import <AsyncDisplayKit/ASTextKitContext.h>
#import <AsyncDisplayKit/ASThread.h>

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

@interface ASTextKitFontSizeAdjuster()
@property (nonatomic, readonly) NSLayoutManager *sizingLayoutManager;
@property (nonatomic, readonly) NSTextContainer *sizingTextContainer;
@end

@implementation ASTextKitFontSizeAdjuster
{
  __weak ASTextKitContext *_context;
  ASTextKitAttributes _attributes;
  BOOL _measured;
  CGFloat _scaleFactor;
  ASDN::Mutex __instanceLock__;
}

@synthesize sizingLayoutManager = _sizingLayoutManager;
@synthesize sizingTextContainer = _sizingTextContainer;

- (instancetype)initWithContext:(ASTextKitContext *)context
                constrainedSize:(CGSize)constrainedSize
              textKitAttributes:(const ASTextKitAttributes &)textComponentAttributes;
{
  if (self = [super init]) {
    _context = context;
    _constrainedSize = constrainedSize;
    _attributes = textComponentAttributes;
  }
  return self;
}

+ (void)adjustFontSizeForAttributeString:(NSMutableAttributedString *)attrString withScaleFactor:(CGFloat)scaleFactor
{
  if (scaleFactor == 1.0) return;
  
  [attrString beginEditing];

  // scale all the attributes that will change the bounding box
  [attrString enumerateAttributesInRange:NSMakeRange(0, attrString.length) options:0 usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
    if (attrs[NSFontAttributeName] != nil) {
      UIFont *font = attrs[NSFontAttributeName];
      font = [font fontWithSize:std::round(font.pointSize * scaleFactor)];
      [attrString removeAttribute:NSFontAttributeName range:range];
      [attrString addAttribute:NSFontAttributeName value:font range:range];
    }
    
    if (attrs[NSKernAttributeName] != nil) {
      NSNumber *kerning = attrs[NSKernAttributeName];
      [attrString removeAttribute:NSKernAttributeName range:range];
      [attrString addAttribute:NSKernAttributeName value:@([kerning floatValue] * scaleFactor) range:range];
    }
    
    if (attrs[NSParagraphStyleAttributeName] != nil) {
      NSMutableParagraphStyle *paragraphStyle = [attrs[NSParagraphStyleAttributeName] mutableCopy];
      paragraphStyle.lineSpacing = (paragraphStyle.lineSpacing * scaleFactor);
      paragraphStyle.paragraphSpacing = (paragraphStyle.paragraphSpacing * scaleFactor);
      paragraphStyle.firstLineHeadIndent = (paragraphStyle.firstLineHeadIndent * scaleFactor);
      paragraphStyle.headIndent = (paragraphStyle.headIndent * scaleFactor);
      paragraphStyle.tailIndent = (paragraphStyle.tailIndent * scaleFactor);
      paragraphStyle.minimumLineHeight = (paragraphStyle.minimumLineHeight * scaleFactor);
      paragraphStyle.maximumLineHeight = (paragraphStyle.maximumLineHeight * scaleFactor);
      paragraphStyle.lineHeightMultiple = (paragraphStyle.lineHeightMultiple * scaleFactor);
      paragraphStyle.paragraphSpacing = (paragraphStyle.paragraphSpacing * scaleFactor);
      
      [attrString removeAttribute:NSParagraphStyleAttributeName range:range];
      [attrString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
    }
    
  }];

  [attrString endEditing];
}

- (NSUInteger)lineCountForString:(NSAttributedString *)attributedString
{
  NSUInteger lineCount = 0;
  
  NSLayoutManager *sizingLayoutManager = [self sizingLayoutManager];
  NSTextContainer *sizingTextContainer = [self sizingTextContainer];
  
  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedString];
  [textStorage addLayoutManager:sizingLayoutManager];
  
  [sizingLayoutManager ensureLayoutForTextContainer:sizingTextContainer];
  for (NSRange lineRange = { 0, 0 }; NSMaxRange(lineRange) < [sizingLayoutManager numberOfGlyphs] && lineCount <= _attributes.maximumNumberOfLines; lineCount++) {
    [sizingLayoutManager lineFragmentRectForGlyphAtIndex:NSMaxRange(lineRange) effectiveRange:&lineRange];
  }
  
  [textStorage removeLayoutManager:sizingLayoutManager];
  return lineCount;
}

- (CGSize)boundingBoxForString:(NSAttributedString *)attributedString
{
  NSLayoutManager *sizingLayoutManager = [self sizingLayoutManager];
  NSTextContainer *sizingTextContainer = [self sizingTextContainer];
  
  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedString];
  [textStorage addLayoutManager:sizingLayoutManager];
  
  [sizingLayoutManager ensureLayoutForTextContainer:sizingTextContainer];
  CGRect textRect = [sizingLayoutManager boundingRectForGlyphRange:NSMakeRange(0, [textStorage length])
                                                   inTextContainer:sizingTextContainer];
  [textStorage removeLayoutManager:sizingLayoutManager];
  return textRect.size;
}

- (NSLayoutManager *)sizingLayoutManager
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_sizingLayoutManager == nil) {
    _sizingLayoutManager = [[ASLayoutManager alloc] init];
    _sizingLayoutManager.usesFontLeading = NO;
    
    if (_sizingTextContainer == nil) {
      // make this text container unbounded in height so that the layout manager will compute the total
      // number of lines and not stop counting when height runs out.
      _sizingTextContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(_constrainedSize.width, CGFLOAT_MAX)];
      _sizingTextContainer.lineFragmentPadding = 0;
      
      // use 0 regardless of what is in the attributes so that we get an accurate line count
      _sizingTextContainer.maximumNumberOfLines = 0;
      
      _sizingTextContainer.lineBreakMode = _attributes.lineBreakMode;
      _sizingTextContainer.exclusionPaths = _attributes.exclusionPaths;
    }
    [_sizingLayoutManager addTextContainer:_sizingTextContainer];
  }
  
  return _sizingLayoutManager;
}

- (CGFloat)scaleFactor
{
  if (_measured) {
    return _scaleFactor;
  }
  
  if ([_attributes.pointSizeScaleFactors count] == 0 || isinf(_constrainedSize.width)) {
    _measured = YES;
    _scaleFactor = 1.0;
    return _scaleFactor;
  }
  
  __block CGFloat adjustedScale = 1.0;
  
  // We add the scale factor of 1 to our scaleFactors array so that in the first iteration of the loop below, we are
  // actually determining if we need to scale at all. If something doesn't fit, we will continue to iterate our scale factors.
  NSArray *scaleFactors = [@[@(1)] arrayByAddingObjectsFromArray:_attributes.pointSizeScaleFactors];
  
  [_context performBlockWithLockedTextKitComponents:^(NSLayoutManager *layoutManager, NSTextStorage *textStorage, NSTextContainer *textContainer) {
    
    // Check for two different situations (and correct for both)
    // 1. The longest word in the string fits without being wrapped
    // 2. The entire text fits in the given constrained size.
    
    NSString *str = textStorage.string;
    NSArray *words = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *longestWordNeedingResize = @"";
    for (NSString *word in words) {
      if ([word length] > [longestWordNeedingResize length]) {
        longestWordNeedingResize = word;
      }
    }
    
    // check to see if we may need to shrink for any of these things
    BOOL longestWordFits = [longestWordNeedingResize length] ? NO : YES;
    BOOL maxLinesFits = _attributes.maximumNumberOfLines > 0 ? NO : YES;
    BOOL heightFits = isinf(_constrainedSize.height) ? YES : NO;

    CGSize longestWordSize = CGSizeZero;
    if (longestWordFits == NO) {
        NSRange longestWordRange = [str rangeOfString:longestWordNeedingResize];
        NSAttributedString *attrString = [textStorage attributedSubstringFromRange:longestWordRange];
        longestWordSize = [attrString boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
    }
    
    // we may need to shrink for some reason, so let's iterate through our scale factors to see if we actually need to shrink
    // Note: the first scale factor in the array is 1.0 so will make sure that things don't fit without shrinking
    for (NSNumber *adjustedScaleObj in scaleFactors) {
      if (longestWordFits && maxLinesFits && heightFits) {
        break;
      }
      
      adjustedScale = [adjustedScaleObj floatValue];
      
      if (longestWordFits == NO) {
        // we need to check the longest word to make sure it fits
        longestWordFits = std::ceil((longestWordSize.width * adjustedScale)  <= _constrainedSize.width);
      }
      
      // if the longest word fits, go ahead and check max line and height. If it didn't fit continue to the next scale factor
      if (longestWordFits == YES) {
        
        // scale our string by the current scale factor
        NSMutableAttributedString *scaledString = [[NSMutableAttributedString alloc] initWithAttributedString:textStorage];
        [[self class] adjustFontSizeForAttributeString:scaledString withScaleFactor:adjustedScale];
        
        // check to see if this scaled string fit in the max lines
        if (maxLinesFits == NO) {
          maxLinesFits = ([self lineCountForString:scaledString] <= _attributes.maximumNumberOfLines);
        }
        
        // if max lines still doesn't fit, continue without checking that we fit in the constrained height
        if (maxLinesFits == YES && heightFits == NO) {
          // max lines fit so make sure that we fit in the constrained height.
          CGSize stringSize = [self boundingBoxForString:scaledString];
          heightFits = (stringSize.height <= _constrainedSize.height);
        }
      }
    }
   
  }];
  _measured = YES;
  _scaleFactor = adjustedScale;
  return _scaleFactor;
}

@end
