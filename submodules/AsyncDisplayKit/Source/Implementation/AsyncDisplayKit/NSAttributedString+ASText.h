//
//  NSAttributedString+ASText.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

#import <AsyncDisplayKit/ASTextAttribute.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Get pre-defined attributes from attributed string.
 All properties defined in UIKit, CoreText and ASText are included.
 */
@interface NSAttributedString (ASText)

#pragma mark - Retrieving character attribute information
///=============================================================================
/// @name Retrieving character attribute information
///=============================================================================

/**
 Returns the attributes at first charactor.
 */
@property (nullable, nonatomic, copy, readonly) NSDictionary<NSString *, id> *as_attributes;

/**
 Returns the attributes for the character at a given index.
 
 @discussion Raises an `NSRangeException` if index lies beyond the end of the
 receiver's characters.
 
 @param index  The index for which to return attributes.
 This value must lie within the bounds of the receiver.
 
 @return The attributes for the character at index.
 */
- (nullable NSDictionary<NSString *, id> *)as_attributesAtIndex:(NSUInteger)index;

/**
 Returns the value for an attribute with a given name of the character at a given index.
 
 @discussion Raises an `NSRangeException` if index lies beyond the end of the
 receiver's characters.
 
 @param attributeName  The name of an attribute.
 @param index          The index for which to return attributes.
 This value must not exceed the bounds of the receiver.
 
 @return The value for the attribute named `attributeName` of the character at
 index `index`, or nil if there is no such attribute.
 */
- (nullable id)as_attribute:(NSString *)attributeName atIndex:(NSUInteger)index;


#pragma mark - Get character attribute as property
///=============================================================================
/// @name Get character attribute as property
///=============================================================================

/**
 The font of the text. (read-only)
 
 @discussion Default is Helvetica (Neue) 12.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic, readonly) UIFont *as_font;
- (nullable UIFont *)as_fontAtIndex:(NSUInteger)index;

/**
 A kerning adjustment. (read-only)
 
 @discussion Default is standard kerning. The kerning attribute indicate how many
 points the following character should be shifted from its default offset as
 defined by the current character's font in points; a positive kern indicates a
 shift farther along and a negative kern indicates a shift closer to the current
 character. If this attribute is not present, standard kerning will be used.
 If this attribute is set to 0.0, no kerning will be done at all.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic, readonly) NSNumber *as_kern;
- (nullable NSNumber *)as_kernAtIndex:(NSUInteger)index;

/**
 The foreground color. (read-only)
 
 @discussion Default is Black.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic, readonly) UIColor *as_color;
- (nullable UIColor *)as_colorAtIndex:(NSUInteger)index;

/**
 The background color. (read-only)
 
 @discussion Default is nil (or no background).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nullable, nonatomic, readonly) UIColor *as_backgroundColor;
- (nullable UIColor *)as_backgroundColorAtIndex:(NSUInteger)index;

/**
 The stroke width. (read-only)
 
 @discussion Default value is 0.0 (no stroke). This attribute, interpreted as
 a percentage of font point size, controls the text drawing mode: positive
 values effect drawing with stroke only; negative values are for stroke and fill.
 A typical value for outlined text is 3.0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nullable, nonatomic, readonly) NSNumber *as_strokeWidth;
- (nullable NSNumber *)as_strokeWidthAtIndex:(NSUInteger)index;

/**
 The stroke color. (read-only)
 
 @discussion Default value is nil (same as foreground color).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nullable, nonatomic, readonly) UIColor *as_strokeColor;
- (nullable UIColor *)as_strokeColorAtIndex:(NSUInteger)index;

/**
 The text shadow. (read-only)
 
 @discussion Default value is nil (no shadow).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic, readonly) NSShadow *as_shadow;
- (nullable NSShadow *)as_shadowAtIndex:(NSUInteger)index;

/**
 The strikethrough style. (read-only)
 
 @discussion Default value is NSUnderlineStyleNone (no strikethrough).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic, readonly) NSUnderlineStyle as_strikethroughStyle;
- (NSUnderlineStyle)as_strikethroughStyleAtIndex:(NSUInteger)index;

/**
 The strikethrough color. (read-only)
 
 @discussion Default value is nil (same as foreground color).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, readonly) UIColor *as_strikethroughColor;
- (nullable UIColor *)as_strikethroughColorAtIndex:(NSUInteger)index;

/**
 The underline style. (read-only)
 
 @discussion Default value is NSUnderlineStyleNone (no underline).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nonatomic, readonly) NSUnderlineStyle as_underlineStyle;
- (NSUnderlineStyle)as_underlineStyleAtIndex:(NSUInteger)index;

/**
 The underline color. (read-only)
 
 @discussion Default value is nil (same as foreground color).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:7.0
 */
@property (nullable, nonatomic, readonly) UIColor *as_underlineColor;
- (nullable UIColor *)as_underlineColorAtIndex:(NSUInteger)index;

/**
 Ligature formation control. (read-only)
 
 @discussion Default is int value 1. The ligature attribute determines what kinds
 of ligatures should be used when displaying the string. A value of 0 indicates
 that only ligatures essential for proper rendering of text should be used,
 1 indicates that standard ligatures should be used, and 2 indicates that all
 available ligatures should be used. Which ligatures are standard depends on the
 script and possibly the font.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic, readonly) NSNumber *as_ligature;
- (nullable NSNumber *)as_ligatureAtIndex:(NSUInteger)index;

/**
 The text effect. (read-only)
 
 @discussion Default is nil (no effect). The only currently supported value
 is NSTextEffectLetterpressStyle.
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, readonly) NSString *as_textEffect;
- (nullable NSString *)as_textEffectAtIndex:(NSUInteger)index;

/**
 The skew to be applied to glyphs. (read-only)
 
 @discussion Default is 0 (no skew).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, readonly) NSNumber *as_obliqueness;
- (nullable NSNumber *)as_obliquenessAtIndex:(NSUInteger)index;

/**
 The log of the expansion factor to be applied to glyphs. (read-only)
 
 @discussion Default is 0 (no expansion).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, readonly) NSNumber *as_expansion;
- (nullable NSNumber *)as_expansionAtIndex:(NSUInteger)index;

/**
 The character's offset from the baseline, in points. (read-only)
 
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, readonly) NSNumber *as_baselineOffset;
- (nullable NSNumber *)as_baselineOffsetAtIndex:(NSUInteger)index;

/**
 Glyph orientation control. (read-only)
 
 @discussion Default is NO. A value of NO indicates that horizontal glyph forms
 are to be used, YES indicates that vertical glyph forms are to be used.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:4.3  ASText:6.0
 */
@property (nonatomic, readonly) BOOL as_verticalGlyphForm;
- (BOOL)as_verticalGlyphFormAtIndex:(NSUInteger)index;

/**
 Specifies text language. (read-only)
 
 @discussion Value must be a NSString containing a locale identifier. Default is
 unset. When this attribute is set to a valid identifier, it will be used to select
 localized glyphs (if supported by the font) and locale-specific line breaking rules.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:7.0  ASText:7.0
 */
@property (nullable, nonatomic, readonly) NSString *as_language;
- (nullable NSString *)as_languageAtIndex:(NSUInteger)index;

/**
 Specifies a bidirectional override or embedding. (read-only)
 
 @discussion See alse NSWritingDirection and NSWritingDirectionAttributeName.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:7.0  ASText:6.0
 */
@property (nullable, nonatomic, readonly) NSArray<NSNumber *> *as_writingDirection;
- (nullable NSArray<NSNumber *> *)as_writingDirectionAtIndex:(NSUInteger)index;

/**
 An NSParagraphStyle object which is used to specify things like
 line alignment, tab rulers, writing direction, etc. (read-only)
 
 @discussion Default is nil ([NSParagraphStyle defaultParagraphStyle]).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic, readonly) NSParagraphStyle *as_paragraphStyle;
- (nullable NSParagraphStyle *)as_paragraphStyleAtIndex:(NSUInteger)index;

#pragma mark - Get paragraph attribute as property
///=============================================================================
/// @name Get paragraph attribute as property
///=============================================================================

/**
 The text alignment (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion Natural text alignment is realized as left or right alignment
 depending on the line sweep direction of the first script contained in the paragraph.
 @discussion Default is NSTextAlignmentNatural.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) NSTextAlignment as_alignment;
- (NSTextAlignment)as_alignmentAtIndex:(NSUInteger)index;

/**
 The mode that should be used to break lines (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is NSLineBreakByWordWrapping.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) NSLineBreakMode as_lineBreakMode;
- (NSLineBreakMode)as_lineBreakModeAtIndex:(NSUInteger)index;

/**
 The distance in points between the bottom of one line fragment and the top of the next.
 (A wrapper for NSParagraphStyle) (read-only)
 
 @discussion This value is always nonnegative. This value is included in the line
 fragment heights in the layout manager.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_lineSpacing;
- (CGFloat)as_lineSpacingAtIndex:(NSUInteger)index;

/**
 The space after the end of the paragraph (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the space (measured in points) added at the
 end of the paragraph to separate it from the following paragraph. This value must
 be nonnegative. The space between paragraphs is determined by adding the previous
 paragraph's paragraphSpacing and the current paragraph's paragraphSpacingBefore.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_paragraphSpacing;
- (CGFloat)as_paragraphSpacingAtIndex:(NSUInteger)index;

/**
 The distance between the paragraph's top and the beginning of its text content.
 (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the space (measured in points) between the
 paragraph's top and the beginning of its text content.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_paragraphSpacingBefore;
- (CGFloat)as_paragraphSpacingBeforeAtIndex:(NSUInteger)index;

/**
 The indentation of the first line (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the distance (in points) from the leading margin
 of a text container to the beginning of the paragraph's first line. This value
 is always nonnegative.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_firstLineHeadIndent;
- (CGFloat)as_firstLineHeadIndentAtIndex:(NSUInteger)index;

/**
 The indentation of the receiver's lines other than the first. (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the distance (in points) from the leading margin
 of a text container to the beginning of lines other than the first. This value is
 always nonnegative.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_headIndent;
- (CGFloat)as_headIndentAtIndex:(NSUInteger)index;

/**
 The trailing indentation (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion If positive, this value is the distance from the leading margin
 (for example, the left margin in left-to-right text). If 0 or negative, it's the
 distance from the trailing margin.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_tailIndent;
- (CGFloat)as_tailIndentAtIndex:(NSUInteger)index;

/**
 The receiver's minimum height (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the minimum height in points that any line in
 the receiver will occupy, regardless of the font size or size of any attached graphic.
 This value must be nonnegative.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_minimumLineHeight;
- (CGFloat)as_minimumLineHeightAtIndex:(NSUInteger)index;

/**
 The receiver's maximum line height (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the maximum height in points that any line in
 the receiver will occupy, regardless of the font size or size of any attached graphic.
 This value is always nonnegative. Glyphs and graphics exceeding this height will
 overlap neighboring lines; however, a maximum height of 0 implies no line height limit.
 Although this limit applies to the line itself, line spacing adds extra space between adjacent lines.
 @discussion Default is 0 (no limit).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_maximumLineHeight;
- (CGFloat)as_maximumLineHeightAtIndex:(NSUInteger)index;

/**
 The line height multiple (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is 0 (no multiple).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) CGFloat as_lineHeightMultiple;
- (CGFloat)as_lineHeightMultipleAtIndex:(NSUInteger)index;

/**
 The base writing direction (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion If you specify NSWritingDirectionNaturalDirection, the receiver resolves
 the writing direction to either NSWritingDirectionLeftToRight or NSWritingDirectionRightToLeft,
 depending on the direction for the user's `language` preference setting.
 @discussion Default is NSWritingDirectionNatural.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic, readonly) NSWritingDirection as_baseWritingDirection;
- (NSWritingDirection)as_baseWritingDirectionAtIndex:(NSUInteger)index;

/**
 The paragraph's threshold for hyphenation. (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion Valid values lie between 0.0 and 1.0 inclusive. Hyphenation is attempted
 when the ratio of the text width (as broken without hyphenation) to the width of the
 line fragment is less than the hyphenation factor. When the paragraph's hyphenation
 factor is 0.0, the layout manager's hyphenation factor is used instead. When both
 are 0.0, hyphenation is disabled.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic, readonly) float as_hyphenationFactor;
- (float)as_hyphenationFactorAtIndex:(NSUInteger)index;

/**
 The document-wide default tab interval (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property represents the default tab interval in points. Tabs after the
 last specified in tabStops are placed at integer multiples of this distance (if positive).
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  ASText:7.0
 */
@property (nonatomic, readonly) CGFloat as_defaultTabInterval;
- (CGFloat)as_defaultTabIntervalAtIndex:(NSUInteger)index;

/**
 An array of NSTextTab objects representing the receiver's tab stops.
 (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion The NSTextTab objects, sorted by location, define the tab stops for
 the paragraph style.
 @discussion Default is 12 TabStops with 28.0 tab interval.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  ASText:7.0
 */
@property (nullable, nonatomic, copy, readonly) NSArray<NSTextTab *> *as_tabStops;
- (nullable NSArray<NSTextTab *> *)as_tabStopsAtIndex:(NSUInteger)index;

#pragma mark - Get ASText attribute as property
///=============================================================================
/// @name Get ASText attribute as property
///=============================================================================

/**
 The text shadow. (read-only)
 
 @discussion Default value is nil (no shadow).
 @discussion Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic, readonly) ASTextShadow *as_textShadow;
- (nullable ASTextShadow *)as_textShadowAtIndex:(NSUInteger)index;

/**
 The text inner shadow. (read-only)
 
 @discussion Default value is nil (no shadow).
 @discussion Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic, readonly) ASTextShadow *as_textInnerShadow;
- (nullable ASTextShadow *)as_textInnerShadowAtIndex:(NSUInteger)index;

/**
 The text underline. (read-only)
 
 @discussion Default value is nil (no underline).
 @discussion Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic, readonly) ASTextDecoration *as_textUnderline;
- (nullable ASTextDecoration *)as_textUnderlineAtIndex:(NSUInteger)index;

/**
 The text strikethrough. (read-only)
 
 @discussion Default value is nil (no strikethrough).
 @discussion Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic, readonly) ASTextDecoration *as_textStrikethrough;
- (nullable ASTextDecoration *)as_textStrikethroughAtIndex:(NSUInteger)index;

/**
 The text border. (read-only)
 
 @discussion Default value is nil (no border).
 @discussion Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic, readonly) ASTextBorder *as_textBorder;
- (nullable ASTextBorder *)as_textBorderAtIndex:(NSUInteger)index;

/**
 The text background border. (read-only)
 
 @discussion Default value is nil (no background border).
 @discussion Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic, readonly) ASTextBorder *as_textBackgroundBorder;
- (nullable ASTextBorder *)as_textBackgroundBorderAtIndex:(NSUInteger)index;

/**
 The glyph transform. (read-only)
 
 @discussion Default value is CGAffineTransformIdentity (no transform).
 @discussion Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nonatomic, readonly) CGAffineTransform as_textGlyphTransform;
- (CGAffineTransform)as_textGlyphTransformAtIndex:(NSUInteger)index;


#pragma mark - Query for ASText
///=============================================================================
/// @name Query for ASText
///=============================================================================

/**
 Returns the plain text from a range.
 If there's `ASTextBackedStringAttributeName` attribute, the backed string will
 replace the attributed string range.
 
 @param range A range in receiver.
 @return The plain text.
 */
- (nullable NSString *)as_plainTextForRange:(NSRange)range;


#pragma mark - Create attachment string for ASText
///=============================================================================
/// @name Create attachment string for ASText
///=============================================================================

/**
 Creates and returns an attachment.
 
 @param content      The attachment (UIImage/UIView/CALayer).
 @param contentMode  The attachment's content mode.
 @param width        The attachment's container width in layout.
 @param ascent       The attachment's container ascent in layout.
 @param descent      The attachment's container descent in layout.
 
 @return An attributed string, or nil if an error occurs.
 @since ASText:6.0
 */
+ (NSMutableAttributedString *)as_attachmentStringWithContent:(nullable id)content
                                                  contentMode:(UIViewContentMode)contentMode
                                                        width:(CGFloat)width
                                                       ascent:(CGFloat)ascent
                                                      descent:(CGFloat)descent;

/**
 Creates and returns an attachment.
 
 
 Example: ContentMode:bottom Alignment:Top.
 
 The text      The attachment holder
 ↓                ↓
 ─────────┌──────────────────────┐───────
 / \   │                      │ / ___|
 / _ \  │                      │| |
 / ___ \ │                      │| |___     ←── The text line
 /_/   \_\│    ██████████████    │ \____|
 ─────────│    ██████████████    │───────
 │    ██████████████    │
 │    ██████████████ ←───────────────── The attachment content
 │    ██████████████    │
 └──────────────────────┘
 
 @param content        The attachment (UIImage/UIView/CALayer).
 @param contentMode    The attachment's content mode in attachment holder
 @param attachmentSize The attachment holder's size in text layout.
 @param font           The attachment will align to this font.
 @param alignment      The attachment holder's alignment to text line.
 
 @return An attributed string, or nil if an error occurs.
 @since ASText:6.0
 */
+ (NSMutableAttributedString *)as_attachmentStringWithContent:(nullable id)content
                                                  contentMode:(UIViewContentMode)contentMode
                                               attachmentSize:(CGSize)attachmentSize
                                                  alignToFont:(UIFont *)font
                                                    alignment:(ASTextVerticalAlignment)alignment;

/**
 Creates and returns an attahment from a fourquare image as if it was an emoji.
 
 @param image     A fourquare image.
 @param fontSize  The font size.
 
 @return An attributed string, or nil if an error occurs.
 @since ASText:6.0
 */
+ (nullable NSMutableAttributedString *)as_attachmentStringWithEmojiImage:(UIImage *)image
                                                                 fontSize:(CGFloat)fontSize;

#pragma mark - Utility
///=============================================================================
/// @name Utility
///=============================================================================

/**
 Returns NSMakeRange(0, self.length).
 */
- (NSRange)as_rangeOfAll;

/**
 If YES, it share the same attribute in entire text range.
 */
- (BOOL)as_isSharedAttributesInAllRange;

/**
 If YES, it can be drawn with the [drawWithRect:options:context:] method or displayed with UIKit.
 If NO, it should be drawn with CoreText or ASText.
 
 @discussion If the method returns NO, it means that there's at least one attribute
 which is not supported by UIKit (such as CTParagraphStyleRef). If display this string
 in UIKit, it may lose some attribute, or even crash the app.
 */
- (BOOL)as_canDrawWithUIKit;

@end




/**
 Set pre-defined attributes to attributed string.
 All properties defined in UIKit, CoreText and ASText are included.
 */
@interface NSMutableAttributedString (ASText)

#pragma mark - Set character attribute
///=============================================================================
/// @name Set character attribute
///=============================================================================

/**
 Sets the attributes to the entire text string.
 
 @discussion The old attributes will be removed.
 
 @param attributes  A dictionary containing the attributes to set, or nil to remove all attributes.
 */
- (void)as_setAttributes:(nullable NSDictionary<NSString *, id> *)attributes;
- (void)setAs_attributes:(nullable NSDictionary<NSString *, id> *)attributes;

/**
 Sets an attribute with the given name and value to the entire text string.
 
 @param name   A string specifying the attribute name.
 @param value  The attribute value associated with name. Pass `nil` or `NSNull` to
 remove the attribute.
 */
- (void)as_setAttribute:(NSString *)name value:(nullable id)value;

/**
 Sets an attribute with the given name and value to the characters in the specified range.
 
 @param name   A string specifying the attribute name.
 @param value  The attribute value associated with name. Pass `nil` or `NSNull` to
 remove the attribute.
 @param range  The range of characters to which the specified attribute/value pair applies.
 */
- (void)as_setAttribute:(NSString *)name value:(nullable id)value range:(NSRange)range;

/**
 Removes all attributes in the specified range.
 
 @param range  The range of characters.
 */
- (void)as_removeAttributesInRange:(NSRange)range;


#pragma mark - Set character attribute as property
///=============================================================================
/// @name Set character attribute as property
///=============================================================================

/**
 The font of the text.
 
 @discussion Default is Helvetica (Neue) 12.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) UIFont *as_font;
- (void)as_setFont:(nullable UIFont *)font range:(NSRange)range;

/**
 A kerning adjustment.
 
 @discussion Default is standard kerning. The kerning attribute indicate how many
 points the following character should be shifted from its default offset as
 defined by the current character's font in points; a positive kern indicates a
 shift farther along and a negative kern indicates a shift closer to the current
 character. If this attribute is not present, standard kerning will be used.
 If this attribute is set to 0.0, no kerning will be done at all.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) NSNumber *as_kern;
- (void)as_setKern:(nullable NSNumber *)kern range:(NSRange)range;

/**
 The foreground color.
 
 @discussion Default is Black.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) UIColor *as_color;
- (void)as_setColor:(nullable UIColor *)color range:(NSRange)range;

/**
 The background color.
 
 @discussion Default is nil (or no background).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nullable, nonatomic) UIColor *as_backgroundColor;
- (void)as_setBackgroundColor:(nullable UIColor *)backgroundColor range:(NSRange)range;

/**
 The stroke width.
 
 @discussion Default value is 0.0 (no stroke). This attribute, interpreted as
 a percentage of font point size, controls the text drawing mode: positive
 values effect drawing with stroke only; negative values are for stroke and fill.
 A typical value for outlined text is 3.0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) NSNumber *as_strokeWidth;
- (void)as_setStrokeWidth:(nullable NSNumber *)strokeWidth range:(NSRange)range;

/**
 The stroke color.
 
 @discussion Default value is nil (same as foreground color).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) UIColor *as_strokeColor;
- (void)as_setStrokeColor:(nullable UIColor *)strokeColor range:(NSRange)range;

/**
 The text shadow.
 
 @discussion Default value is nil (no shadow).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) NSShadow *as_shadow;
- (void)as_setShadow:(nullable NSShadow *)shadow range:(NSRange)range;

/**
 The strikethrough style.
 
 @discussion Default value is NSUnderlineStyleNone (no strikethrough).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic) NSUnderlineStyle as_strikethroughStyle;
- (void)as_setStrikethroughStyle:(NSUnderlineStyle)strikethroughStyle range:(NSRange)range;

/**
 The strikethrough color.
 
 @discussion Default value is nil (same as foreground color).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic) UIColor *as_strikethroughColor;
- (void)as_setStrikethroughColor:(nullable UIColor *)strikethroughColor range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 The underline style.
 
 @discussion Default value is NSUnderlineStyleNone (no underline).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nonatomic) NSUnderlineStyle as_underlineStyle;
- (void)as_setUnderlineStyle:(NSUnderlineStyle)underlineStyle range:(NSRange)range;

/**
 The underline color.
 
 @discussion Default value is nil (same as foreground color).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:7.0
 */
@property (nullable, nonatomic) UIColor *as_underlineColor;
- (void)as_setUnderlineColor:(nullable UIColor *)underlineColor range:(NSRange)range;

/**
 Ligature formation control.
 
 @discussion Default is int value 1. The ligature attribute determines what kinds
 of ligatures should be used when displaying the string. A value of 0 indicates
 that only ligatures essential for proper rendering of text should be used,
 1 indicates that standard ligatures should be used, and 2 indicates that all
 available ligatures should be used. Which ligatures are standard depends on the
 script and possibly the font.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) NSNumber *as_ligature;
- (void)as_setLigature:(nullable NSNumber *)ligature range:(NSRange)range;

/**
 The text effect.
 
 @discussion Default is nil (no effect). The only currently supported value
 is NSTextEffectLetterpressStyle.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic) NSString *as_textEffect;
- (void)as_setTextEffect:(nullable NSString *)textEffect range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 The skew to be applied to glyphs.
 
 @discussion Default is 0 (no skew).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic) NSNumber *as_obliqueness;
- (void)as_setObliqueness:(nullable NSNumber *)obliqueness range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 The log of the expansion factor to be applied to glyphs.
 
 @discussion Default is 0 (no expansion).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic) NSNumber *as_expansion;
- (void)as_setExpansion:(nullable NSNumber *)expansion range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 The character's offset from the baseline, in points.
 
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic) NSNumber *as_baselineOffset;
- (void)as_setBaselineOffset:(nullable NSNumber *)baselineOffset range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 Glyph orientation control.
 
 @discussion Default is NO. A value of NO indicates that horizontal glyph forms
 are to be used, YES indicates that vertical glyph forms are to be used.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:4.3  ASText:6.0
 */
@property (nonatomic) BOOL as_verticalGlyphForm;
- (void)as_setVerticalGlyphForm:(BOOL)verticalGlyphForm range:(NSRange)range;

/**
 Specifies text language.
 
 @discussion Value must be a NSString containing a locale identifier. Default is
 unset. When this attribute is set to a valid identifier, it will be used to select
 localized glyphs (if supported by the font) and locale-specific line breaking rules.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:7.0  ASText:7.0
 */
@property (nullable, nonatomic) NSString *as_language;
- (void)as_setLanguage:(nullable NSString *)language range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 Specifies a bidirectional override or embedding.
 
 @discussion See alse NSWritingDirection and NSWritingDirectionAttributeName.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:7.0  ASText:6.0
 */
@property (nullable, nonatomic) NSArray<NSNumber *> *as_writingDirection;
- (void)as_setWritingDirection:(nullable NSArray<NSNumber *> *)writingDirection range:(NSRange)range;

/**
 An NSParagraphStyle object which is used to specify things like
 line alignment, tab rulers, writing direction, etc.
 
 @discussion Default is nil ([NSParagraphStyle defaultParagraphStyle]).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nullable, nonatomic) NSParagraphStyle *as_paragraphStyle;
- (void)as_setParagraphStyle:(nullable NSParagraphStyle *)paragraphStyle range:(NSRange)range;


#pragma mark - Set paragraph attribute as property
///=============================================================================
/// @name Set paragraph attribute as property
///=============================================================================

/**
 The text alignment (A wrapper for NSParagraphStyle).
 
 @discussion Natural text alignment is realized as left or right alignment
 depending on the line sweep direction of the first script contained in the paragraph.
 @discussion Default is NSTextAlignmentNatural.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) NSTextAlignment as_alignment;
- (void)as_setAlignment:(NSTextAlignment)alignment range:(NSRange)range;

/**
 The mode that should be used to break lines (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is NSLineBreakByWordWrapping.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) NSLineBreakMode as_lineBreakMode;
- (void)as_setLineBreakMode:(NSLineBreakMode)lineBreakMode range:(NSRange)range;

/**
 The distance in points between the bottom of one line fragment and the top of the next.
 (A wrapper for NSParagraphStyle)
 
 @discussion This value is always nonnegative. This value is included in the line
 fragment heights in the layout manager.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_lineSpacing;
- (void)as_setLineSpacing:(CGFloat)lineSpacing range:(NSRange)range;

/**
 The space after the end of the paragraph (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the space (measured in points) added at the
 end of the paragraph to separate it from the following paragraph. This value must
 be nonnegative. The space between paragraphs is determined by adding the previous
 paragraph's paragraphSpacing and the current paragraph's paragraphSpacingBefore.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_paragraphSpacing;
- (void)as_setParagraphSpacing:(CGFloat)paragraphSpacing range:(NSRange)range;

/**
 The distance between the paragraph's top and the beginning of its text content.
 (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the space (measured in points) between the
 paragraph's top and the beginning of its text content.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_paragraphSpacingBefore;
- (void)as_setParagraphSpacingBefore:(CGFloat)paragraphSpacingBefore range:(NSRange)range;

/**
 The indentation of the first line (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the distance (in points) from the leading margin
 of a text container to the beginning of the paragraph's first line. This value
 is always nonnegative.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_firstLineHeadIndent;
- (void)as_setFirstLineHeadIndent:(CGFloat)firstLineHeadIndent range:(NSRange)range;

/**
 The indentation of the receiver's lines other than the first. (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the distance (in points) from the leading margin
 of a text container to the beginning of lines other than the first. This value is
 always nonnegative.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_headIndent;
- (void)as_setHeadIndent:(CGFloat)headIndent range:(NSRange)range;

/**
 The trailing indentation (A wrapper for NSParagraphStyle).
 
 @discussion If positive, this value is the distance from the leading margin
 (for example, the left margin in left-to-right text). If 0 or negative, it's the
 distance from the trailing margin.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_tailIndent;
- (void)as_setTailIndent:(CGFloat)tailIndent range:(NSRange)range;

/**
 The receiver's minimum height (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the minimum height in points that any line in
 the receiver will occupy, regardless of the font size or size of any attached graphic.
 This value must be nonnegative.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_minimumLineHeight;
- (void)as_setMinimumLineHeight:(CGFloat)minimumLineHeight range:(NSRange)range;

/**
 The receiver's maximum line height (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the maximum height in points that any line in
 the receiver will occupy, regardless of the font size or size of any attached graphic.
 This value is always nonnegative. Glyphs and graphics exceeding this height will
 overlap neighboring lines; however, a maximum height of 0 implies no line height limit.
 Although this limit applies to the line itself, line spacing adds extra space between adjacent lines.
 @discussion Default is 0 (no limit).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_maximumLineHeight;
- (void)as_setMaximumLineHeight:(CGFloat)maximumLineHeight range:(NSRange)range;

/**
 The line height multiple (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is 0 (no multiple).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) CGFloat as_lineHeightMultiple;
- (void)as_setLineHeightMultiple:(CGFloat)lineHeightMultiple range:(NSRange)range;

/**
 The base writing direction (A wrapper for NSParagraphStyle).
 
 @discussion If you specify NSWritingDirectionNaturalDirection, the receiver resolves
 the writing direction to either NSWritingDirectionLeftToRight or NSWritingDirectionRightToLeft,
 depending on the direction for the user's `language` preference setting.
 @discussion Default is NSWritingDirectionNatural.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  ASText:6.0
 */
@property (nonatomic) NSWritingDirection as_baseWritingDirection;
- (void)as_setBaseWritingDirection:(NSWritingDirection)baseWritingDirection range:(NSRange)range;

/**
 The paragraph's threshold for hyphenation. (A wrapper for NSParagraphStyle).
 
 @discussion Valid values lie between 0.0 and 1.0 inclusive. Hyphenation is attempted
 when the ratio of the text width (as broken without hyphenation) to the width of the
 line fragment is less than the hyphenation factor. When the paragraph's hyphenation
 factor is 0.0, the layout manager's hyphenation factor is used instead. When both
 are 0.0, hyphenation is disabled.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic) float as_hyphenationFactor;
- (void)as_setHyphenationFactor:(float)hyphenationFactor range:(NSRange)range;

/**
 The document-wide default tab interval (A wrapper for NSParagraphStyle).
 
 @discussion This property represents the default tab interval in points. Tabs after the
 last specified in tabStops are placed at integer multiples of this distance (if positive).
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  ASText:7.0
 */
@property (nonatomic) CGFloat as_defaultTabInterval;
- (void)as_setDefaultTabInterval:(CGFloat)defaultTabInterval range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 An array of NSTextTab objects representing the receiver's tab stops.
 (A wrapper for NSParagraphStyle).
 
 @discussion The NSTextTab objects, sorted by location, define the tab stops for
 the paragraph style.
 @discussion Default is 12 TabStops with 28.0 tab interval.
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  ASText:7.0
 */
@property (nullable, nonatomic, copy) NSArray<NSTextTab *> *as_tabStops;
- (void)as_setTabStops:(nullable NSArray<NSTextTab *> *)tabStops range:(NSRange)range NS_AVAILABLE_IOS(7_0);

#pragma mark - Set ASText attribute as property
///=============================================================================
/// @name Set ASText attribute as property
///=============================================================================

/**
 The text shadow.
 
 @discussion Default value is nil (no shadow).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic) ASTextShadow *as_textShadow;
- (void)as_setTextShadow:(nullable ASTextShadow *)textShadow range:(NSRange)range;

/**
 The text inner shadow.
 
 @discussion Default value is nil (no shadow).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic) ASTextShadow *as_textInnerShadow;
- (void)as_setTextInnerShadow:(nullable ASTextShadow *)textInnerShadow range:(NSRange)range;

/**
 The text underline.
 
 @discussion Default value is nil (no underline).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic) ASTextDecoration *as_textUnderline;
- (void)as_setTextUnderline:(nullable ASTextDecoration *)textUnderline range:(NSRange)range;

/**
 The text strikethrough.
 
 @discussion Default value is nil (no strikethrough).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic) ASTextDecoration *as_textStrikethrough;
- (void)as_setTextStrikethrough:(nullable ASTextDecoration *)textStrikethrough range:(NSRange)range;

/**
 The text border.
 
 @discussion Default value is nil (no border).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic) ASTextBorder *as_textBorder;
- (void)as_setTextBorder:(nullable ASTextBorder *)textBorder range:(NSRange)range;

/**
 The text background border.
 
 @discussion Default value is nil (no background border).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nullable, nonatomic) ASTextBorder *as_textBackgroundBorder;
- (void)as_setTextBackgroundBorder:(nullable ASTextBorder *)textBackgroundBorder range:(NSRange)range;

/**
 The glyph transform.
 
 @discussion Default value is CGAffineTransformIdentity (no transform).
 @discussion Set this property applies to the entire text string.
 Get this property returns the first character's attribute.
 @since ASText:6.0
 */
@property (nonatomic) CGAffineTransform as_textGlyphTransform;
- (void)as_setTextGlyphTransform:(CGAffineTransform)textGlyphTransform range:(NSRange)range;


#pragma mark - Set discontinuous attribute for range
///=============================================================================
/// @name Set discontinuous attribute for range
///=============================================================================

- (void)as_setSuperscript:(nullable NSNumber *)superscript range:(NSRange)range;
- (void)as_setGlyphInfo:(nullable CTGlyphInfoRef)glyphInfo range:(NSRange)range;
- (void)as_setCharacterShape:(nullable NSNumber *)characterShape range:(NSRange)range __TVOS_PROHIBITED;
- (void)as_setRunDelegate:(nullable CTRunDelegateRef)runDelegate range:(NSRange)range;
- (void)as_setBaselineClass:(nullable CFStringRef)baselineClass range:(NSRange)range;
- (void)as_setBaselineInfo:(nullable CFDictionaryRef)baselineInfo range:(NSRange)range;
- (void)as_setBaselineReferenceInfo:(nullable CFDictionaryRef)referenceInfo range:(NSRange)range;
- (void)as_setRubyAnnotation:(nullable CTRubyAnnotationRef)ruby range:(NSRange)range NS_AVAILABLE_IOS(8_0);
- (void)as_setAttachment:(nullable NSTextAttachment *)attachment range:(NSRange)range NS_AVAILABLE_IOS(7_0);
- (void)as_setLink:(nullable id)link range:(NSRange)range NS_AVAILABLE_IOS(7_0);
- (void)as_setTextBackedString:(nullable ASTextBackedString *)textBackedString range:(NSRange)range;
- (void)as_setTextBinding:(nullable ASTextBinding *)textBinding range:(NSRange)range;
- (void)as_setTextAttachment:(nullable ASTextAttachment *)textAttachment range:(NSRange)range;
- (void)as_setTextHighlight:(nullable ASTextHighlight *)textHighlight range:(NSRange)range;
- (void)as_setTextBlockBorder:(nullable ASTextBorder *)textBlockBorder range:(NSRange)range;


#pragma mark - Convenience methods for text highlight
///=============================================================================
/// @name Convenience methods for text highlight
///=============================================================================

/**
 Convenience method to set text highlight
 
 @param range           text range
 @param color           text color (pass nil to ignore)
 @param backgroundColor text background color when highlight
 @param userInfo        user information dictionary (pass nil to ignore)
 @param tapAction       tap action when user tap the highlight (pass nil to ignore)
 @param longPressAction long press action when user long press the highlight (pass nil to ignore)
 */
- (void)as_setTextHighlightRange:(NSRange)range
                           color:(nullable UIColor *)color
                 backgroundColor:(nullable UIColor *)backgroundColor
                        userInfo:(nullable NSDictionary *)userInfo
                       tapAction:(nullable ASTextAction)tapAction
                 longPressAction:(nullable ASTextAction)longPressAction;

/**
 Convenience method to set text highlight
 
 @param range           text range
 @param color           text color (pass nil to ignore)
 @param backgroundColor text background color when highlight
 @param tapAction       tap action when user tap the highlight (pass nil to ignore)
 */
- (void)as_setTextHighlightRange:(NSRange)range
                           color:(nullable UIColor *)color
                 backgroundColor:(nullable UIColor *)backgroundColor
                       tapAction:(nullable ASTextAction)tapAction;

/**
 Convenience method to set text highlight
 
 @param range           text range
 @param color           text color (pass nil to ignore)
 @param backgroundColor text background color when highlight
 @param userInfo        tap action when user tap the highlight (pass nil to ignore)
 */
- (void)as_setTextHighlightRange:(NSRange)range
                           color:(nullable UIColor *)color
                 backgroundColor:(nullable UIColor *)backgroundColor
                        userInfo:(nullable NSDictionary *)userInfo;

#pragma mark - Utilities
///=============================================================================
/// @name Utilities
///=============================================================================

/**
 Inserts into the receiver the characters of a given string at a given location.
 The new string inherit the attributes of the first replaced character from location.
 
 @param string  The string to insert into the receiver, must not be nil.
 @param location The location at which string is inserted. The location must not
 exceed the bounds of the receiver.
 @throw Raises an NSRangeException if the location out of bounds.
 */
- (void)as_insertString:(NSString *)string atIndex:(NSUInteger)location;

/**
 Adds to the end of the receiver the characters of a given string.
 The new string inherit the attributes of the receiver's tail.
 
 @param string  The string to append to the receiver, must not be nil.
 */
- (void)as_appendString:(NSString *)string;

/**
 Removes all discontinuous attributes in a specified range.
 See `allDiscontinuousAttributeKeys`.
 
 @param range A text range.
 */
- (void)as_removeDiscontinuousAttributesInRange:(NSRange)range;

/**
 Returns all discontinuous attribute keys, such as RunDelegate/Attachment/Ruby.
 
 @discussion These attributes can only set to a specified range of text, and
 should not extend to other range when editing text.
 */
+ (NSArray<NSString *> *)as_allDiscontinuousAttributeKeys;

@end

NS_ASSUME_NONNULL_END
