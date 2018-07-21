//
//  ASTextLine.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) through the present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <AsyncDisplayKit/ASTextAttribute.h>

@class ASTextRunGlyphRange;

NS_ASSUME_NONNULL_BEGIN

/**
 A text line object wrapped `CTLineRef`, see `ASTextLayout` for more.
 */
@interface ASTextLine : NSObject

+ (instancetype)lineWithCTLine:(CTLineRef)CTLine position:(CGPoint)position vertical:(BOOL)isVertical NS_RETURNS_RETAINED;

@property (nonatomic) NSUInteger index;     ///< line index
@property (nonatomic) NSUInteger row;       ///< line row
@property (nullable, nonatomic) NSArray<NSArray<ASTextRunGlyphRange *> *> *verticalRotateRange; ///< Run rotate range

@property (nonatomic, readonly) CTLineRef CTLine;   ///< CoreText line
@property (nonatomic, readonly) NSRange range;      ///< string range
@property (nonatomic, readonly) BOOL vertical;      ///< vertical form

@property (nonatomic, readonly) CGRect bounds;      ///< bounds (ascent + descent)
@property (nonatomic, readonly) CGSize size;        ///< bounds.size
@property (nonatomic, readonly) CGFloat width;      ///< bounds.size.width
@property (nonatomic, readonly) CGFloat height;     ///< bounds.size.height
@property (nonatomic, readonly) CGFloat top;        ///< bounds.origin.y
@property (nonatomic, readonly) CGFloat bottom;     ///< bounds.origin.y + bounds.size.height
@property (nonatomic, readonly) CGFloat left;       ///< bounds.origin.x
@property (nonatomic, readonly) CGFloat right;      ///< bounds.origin.x + bounds.size.width

@property (nonatomic)   CGPoint position;   ///< baseline position
@property (nonatomic, readonly) CGFloat ascent;     ///< line ascent
@property (nonatomic, readonly) CGFloat descent;    ///< line descent
@property (nonatomic, readonly) CGFloat leading;    ///< line leading
@property (nonatomic, readonly) CGFloat lineWidth;  ///< line width
@property (nonatomic, readonly) CGFloat trailingWhitespaceWidth;

@property (nullable, nonatomic, readonly) NSArray<ASTextAttachment *> *attachments; ///< ASTextAttachment
@property (nullable, nonatomic, readonly) NSArray<NSValue *> *attachmentRanges;     ///< NSRange(NSValue)
@property (nullable, nonatomic, readonly) NSArray<NSValue *> *attachmentRects;      ///< CGRect(NSValue)

@end


typedef NS_ENUM(NSUInteger, ASTextRunGlyphDrawMode) {
  /// No rotate.
  ASTextRunGlyphDrawModeHorizontal = 0,
  
  /// Rotate vertical for single glyph.
  ASTextRunGlyphDrawModeVerticalRotate = 1,
  
  /// Rotate vertical for single glyph, and move the glyph to a better position,
  /// such as fullwidth punctuation.
  ASTextRunGlyphDrawModeVerticalRotateMove = 2,
};

/**
 A range in CTRun, used for vertical form.
 */
@interface ASTextRunGlyphRange : NSObject
@property (nonatomic) NSRange glyphRangeInRun;
@property (nonatomic) ASTextRunGlyphDrawMode drawMode;
+ (instancetype)rangeWithRange:(NSRange)range drawMode:(ASTextRunGlyphDrawMode)mode NS_RETURNS_RETAINED;
@end

NS_ASSUME_NONNULL_END
