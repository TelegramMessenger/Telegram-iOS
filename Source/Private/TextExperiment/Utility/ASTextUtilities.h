//
//  ASTextUtilities.h
//  Modified from YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/4/6.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import <tgmath.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>


#ifndef ASTEXT_CLAMP // return the clamped value
#define ASTEXT_CLAMP(_x_, _low_, _high_)  (((_x_) > (_high_)) ? (_high_) : (((_x_) < (_low_)) ? (_low_) : (_x_)))
#endif

#ifndef ASTEXT_SWAP // swap two value
#define ASTEXT_SWAP(_a_, _b_)  do { __typeof__(_a_) _tmp_ = (_a_); (_a_) = (_b_); (_b_) = _tmp_; } while (0)
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 Whether the character is 'line break char':
 U+000D (\\r or CR)
 U+2028 (Unicode line separator)
 U+000A (\\n or LF)
 U+2029 (Unicode paragraph separator)
 
 @param c  A character
 @return YES or NO.
 */
static inline BOOL ASTextIsLinebreakChar(unichar c) {
  switch (c) {
    case 0x000D:
    case 0x2028:
    case 0x000A:
    case 0x2029:
      return YES;
    default:
      return NO;
  }
}

/**
 Whether the string is a 'line break':
 U+000D (\\r or CR)
 U+2028 (Unicode line separator)
 U+000A (\\n or LF)
 U+2029 (Unicode paragraph separator)
 \\r\\n, in that order (also known as CRLF)
 
 @param str A string
 @return YES or NO.
 */
static inline BOOL ASTextIsLinebreakString(NSString * _Nullable str) {
  if (str.length > 2 || str.length == 0) return NO;
  if (str.length == 1) {
    unichar c = [str characterAtIndex:0];
    return ASTextIsLinebreakChar(c);
  } else {
    return ([str characterAtIndex:0] == '\r') && ([str characterAtIndex:1] == '\n');
  }
}

/**
 If the string has a 'line break' suffix, return the 'line break' length.
 
 @param str  A string.
 @return The length of the tail line break: 0, 1 or 2.
 */
static inline NSUInteger ASTextLinebreakTailLength(NSString * _Nullable str) {
  if (str.length >= 2) {
    unichar c2 = [str characterAtIndex:str.length - 1];
    if (ASTextIsLinebreakChar(c2)) {
      unichar c1 = [str characterAtIndex:str.length - 2];
      if (c1 == '\r' && c2 == '\n') return 2;
      else return 1;
    } else {
      return 0;
    }
  } else if (str.length == 1) {
    return ASTextIsLinebreakChar([str characterAtIndex:0]) ? 1 : 0;
  } else {
    return 0;
  }
}

/**
 Whether the font contains color bitmap glyphs.
 
 @discussion Only `AppleColorEmoji` contains color bitmap glyphs in iOS system fonts.
 @param font  A font.
 @return YES: the font contains color bitmap glyphs, NO: the font has no color bitmap glyph.
 */
static inline BOOL ASTextCTFontContainsColorBitmapGlyphs(CTFontRef font) {
  return  (CTFontGetSymbolicTraits(font) & kCTFontTraitColorGlyphs) != 0;
}

/**
 Get the `AppleColorEmoji` font's ascent with a specified font size.
 It may used to create custom emoji.
 
 @param fontSize  The specified font size.
 @return The font ascent.
 */
static inline CGFloat ASTextEmojiGetAscentWithFontSize(CGFloat fontSize) {
  if (fontSize < 16) {
    return 1.25 * fontSize;
  } else if (16 <= fontSize && fontSize <= 24) {
    return 0.5 * fontSize + 12;
  } else {
    return fontSize;
  }
}

/**
 Get the `AppleColorEmoji` font's descent with a specified font size.
 It may used to create custom emoji.
 
 @param fontSize  The specified font size.
 @return The font descent.
 */
static inline CGFloat ASTextEmojiGetDescentWithFontSize(CGFloat fontSize) {
  if (fontSize < 16) {
    return 0.390625 * fontSize;
  } else if (16 <= fontSize && fontSize <= 24) {
    return 0.15625 * fontSize + 3.75;
  } else {
    return 0.3125 * fontSize;
  }
  return 0;
}

/**
 Get the `AppleColorEmoji` font's glyph bounding rect with a specified font size.
 It may used to create custom emoji.
 
 @param fontSize  The specified font size.
 @return The font glyph bounding rect.
 */
static inline CGRect ASTextEmojiGetGlyphBoundingRectWithFontSize(CGFloat fontSize) {
  CGRect rect;
  rect.origin.x = 0.75;
  rect.size.width = rect.size.height = ASTextEmojiGetAscentWithFontSize(fontSize);
  if (fontSize < 16) {
    rect.origin.y = -0.2525 * fontSize;
  } else if (16 <= fontSize && fontSize <= 24) {
    rect.origin.y = 0.1225 * fontSize -6;
  } else {
    rect.origin.y = -0.1275 * fontSize;
  }
  return rect;
}


/**
 Get the character set which should rotate in vertical form.
 @return The shared character set.
 */
NSCharacterSet *ASTextVerticalFormRotateCharacterSet(void);

/**
 Get the character set which should rotate and move in vertical form.
 @return The shared character set.
 */
NSCharacterSet *ASTextVerticalFormRotateAndMoveCharacterSet(void);


/// Get the transform rotation.
/// @return the rotation in radians [-PI,PI] ([-180°,180°])
static inline CGFloat ASTextCGAffineTransformGetRotation(CGAffineTransform transform) {
  return atan2(transform.b, transform.a);
}

/// Negates/inverts a UIEdgeInsets.
static inline UIEdgeInsets ASTextUIEdgeInsetsInvert(UIEdgeInsets insets) {
  return UIEdgeInsetsMake(-insets.top, -insets.left, -insets.bottom, -insets.right);
}

/**
 Returns a rectangle to fit `rect` with specified content mode.
 
 @param rect The constraint rect
 @param size The content size
 @param mode The content mode
 @return A rectangle for the given content mode.
 @discussion UIViewContentModeRedraw is same as UIViewContentModeScaleToFill.
 */
CGRect ASTextCGRectFitWithContentMode(CGRect rect, CGSize size, UIViewContentMode mode);

/// Returns the center for the rectangle.
static inline CGPoint ASTextCGRectGetCenter(CGRect rect) {
  return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

/// Returns the area of the rectangle.
static inline CGFloat ASTextCGRectGetArea(CGRect rect) {
  if (CGRectIsNull(rect)) return 0;
  rect = CGRectStandardize(rect);
  return rect.size.width * rect.size.height;
}

/// Returns the minmium distance between a point to a rectangle.
static inline CGFloat ASTextCGPointGetDistanceToRect(CGPoint p, CGRect r) {
  r = CGRectStandardize(r);
  if (CGRectContainsPoint(r, p)) return 0;
  CGFloat distV, distH;
  if (CGRectGetMinY(r) <= p.y && p.y <= CGRectGetMaxY(r)) {
    distV = 0;
  } else {
    distV = p.y < CGRectGetMinY(r) ? CGRectGetMinY(r) - p.y : p.y - CGRectGetMaxY(r);
  }
  if (CGRectGetMinX(r) <= p.x && p.x <= CGRectGetMaxX(r)) {
    distH = 0;
  } else {
    distH = p.x < CGRectGetMinX(r) ? CGRectGetMinX(r) - p.x : p.x - CGRectGetMaxX(r);
  }
  return MAX(distV, distH);
}

/// Convert point to pixel.
static inline CGFloat ASTextCGFloatToPixel(CGFloat value) {
  return value * ASScreenScale();
}

/// Convert pixel to point.
static inline CGFloat ASTextCGFloatFromPixel(CGFloat value) {
  return value / ASScreenScale();
}

/// round point value to .5 pixel for path stroke (odd pixel line width pixel-aligned)
static inline CGFloat ASTextCGFloatPixelHalf(CGFloat value) {
  CGFloat scale = ASScreenScale();
  return (floor(value * scale) + 0.5) / scale;
}

/// floor point value for pixel-aligned
static inline CGPoint ASTextCGPointPixelFloor(CGPoint point) {
  CGFloat scale = ASScreenScale();
  return CGPointMake(floor(point.x * scale) / scale,
                     floor(point.y * scale) / scale);
}

/// round point value for pixel-aligned
static inline CGPoint ASTextCGPointPixelRound(CGPoint point) {
  CGFloat scale = ASScreenScale();
  return CGPointMake(round(point.x * scale) / scale,
                     round(point.y * scale) / scale);
}

/// ceil point value for pixel-aligned
static inline CGPoint ASTextCGPointPixelCeil(CGPoint point) {
  CGFloat scale = ASScreenScale();
  return CGPointMake(ceil(point.x * scale) / scale,
                     ceil(point.y * scale) / scale);
}

/// round point value to .5 pixel for path stroke (odd pixel line width pixel-aligned)
static inline CGPoint ASTextCGPointPixelHalf(CGPoint point) {
  CGFloat scale = ASScreenScale();
  return CGPointMake((floor(point.x * scale) + 0.5) / scale,
                     (floor(point.y * scale) + 0.5) / scale);
}

/// round point value for pixel-aligned
static inline CGRect ASTextCGRectPixelRound(CGRect rect) {
  CGPoint origin = ASTextCGPointPixelRound(rect.origin);
  CGPoint corner = ASTextCGPointPixelRound(CGPointMake(rect.origin.x + rect.size.width,
                                                       rect.origin.y + rect.size.height));
  return CGRectMake(origin.x, origin.y, corner.x - origin.x, corner.y - origin.y);
}

/// round point value to .5 pixel for path stroke (odd pixel line width pixel-aligned)
static inline CGRect ASTextCGRectPixelHalf(CGRect rect) {
  CGPoint origin = ASTextCGPointPixelHalf(rect.origin);
  CGPoint corner = ASTextCGPointPixelHalf(CGPointMake(rect.origin.x + rect.size.width,
                                                      rect.origin.y + rect.size.height));
  return CGRectMake(origin.x, origin.y, corner.x - origin.x, corner.y - origin.y);
}


static inline UIFont * _Nullable ASTextFontWithBold(UIFont *font) {
  return [UIFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:font.pointSize];
}

static inline UIFont * _Nullable ASTextFontWithItalic(UIFont *font) {
  return [UIFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic] size:font.pointSize];
}

static inline UIFont * _Nullable ASTextFontWithBoldItalic(UIFont *font) {
  return [UIFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold | UIFontDescriptorTraitItalic] size:font.pointSize];
}



/**
 Convert CFRange to NSRange
 @param range CFRange @return NSRange
 */
static inline NSRange ASTextNSRangeFromCFRange(CFRange range) {
  return NSMakeRange(range.location, range.length);
}

/**
 Convert NSRange to CFRange
 @param range NSRange @return CFRange
 */
static inline CFRange ASTextCFRangeFromNSRange(NSRange range) {
  return CFRangeMake(range.location, range.length);
}

NS_ASSUME_NONNULL_END
