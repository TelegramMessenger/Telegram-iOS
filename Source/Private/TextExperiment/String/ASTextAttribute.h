//
//  ASTextAttribute.h
//  Modified from YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 14/10/26.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enum Define

/// The attribute type
typedef NS_OPTIONS(NSInteger, ASTextAttributeType) {
  ASTextAttributeTypeNone     = 0,
  ASTextAttributeTypeUIKit    = 1 << 0, ///< UIKit attributes, such as UILabel/UITextField/drawInRect.
  ASTextAttributeTypeCoreText = 1 << 1, ///< CoreText attributes, used by CoreText.
  ASTextAttributeTypeASText   = 1 << 2, ///< ASText attributes, used by ASText.
};

/// Get the attribute type from an attribute name.
extern ASTextAttributeType ASTextAttributeGetType(NSString *attributeName);

/**
 Line style in ASText (similar to NSUnderlineStyle).
 */
typedef NS_OPTIONS (NSInteger, ASTextLineStyle) {
  // basic style (bitmask:0xFF)
  ASTextLineStyleNone       = 0x00, ///< (        ) Do not draw a line (Default).
  ASTextLineStyleSingle     = 0x01, ///< (──────) Draw a single line.
  ASTextLineStyleThick      = 0x02, ///< (━━━━━━━) Draw a thick line.
  ASTextLineStyleDouble     = 0x09, ///< (══════) Draw a double line.
  
  // style pattern (bitmask:0xF00)
  ASTextLineStylePatternSolid      = 0x000, ///< (────────) Draw a solid line (Default).
  ASTextLineStylePatternDot        = 0x100, ///< (‑ ‑ ‑ ‑ ‑ ‑) Draw a line of dots.
  ASTextLineStylePatternDash       = 0x200, ///< (— — — —) Draw a line of dashes.
  ASTextLineStylePatternDashDot    = 0x300, ///< (— ‑ — ‑ — ‑) Draw a line of alternating dashes and dots.
  ASTextLineStylePatternDashDotDot = 0x400, ///< (— ‑ ‑ — ‑ ‑) Draw a line of alternating dashes and two dots.
  ASTextLineStylePatternCircleDot  = 0x900, ///< (••••••••••••) Draw a line of small circle dots.
};

/**
 Text vertical alignment.
 */
typedef NS_ENUM(NSInteger, ASTextVerticalAlignment) {
  ASTextVerticalAlignmentTop =    0, ///< Top alignment.
  ASTextVerticalAlignmentCenter = 1, ///< Center alignment.
  ASTextVerticalAlignmentBottom = 2, ///< Bottom alignment.
};

/**
 The direction define in ASText.
 */
typedef NS_OPTIONS(NSUInteger, ASTextDirection) {
  ASTextDirectionNone   = 0,
  ASTextDirectionTop    = 1 << 0,
  ASTextDirectionRight  = 1 << 1,
  ASTextDirectionBottom = 1 << 2,
  ASTextDirectionLeft   = 1 << 3,
};

/**
 The trunction type, tells the truncation engine which type of truncation is being requested.
 */
typedef NS_ENUM (NSUInteger, ASTextTruncationType) {
  /// No truncate.
  ASTextTruncationTypeNone   = 0,
  
  /// Truncate at the beginning of the line, leaving the end portion visible.
  ASTextTruncationTypeStart  = 1,
  
  /// Truncate at the end of the line, leaving the start portion visible.
  ASTextTruncationTypeEnd    = 2,
  
  /// Truncate in the middle of the line, leaving both the start and the end portions visible.
  ASTextTruncationTypeMiddle = 3,
};



#pragma mark - Attribute Name Defined in ASText

/// The value of this attribute is a `ASTextBackedString` object.
/// Use this attribute to store the original plain text if it is replaced by something else (such as attachment).
UIKIT_EXTERN NSString *const ASTextBackedStringAttributeName;

/// The value of this attribute is a `ASTextBinding` object.
/// Use this attribute to bind a range of text together, as if it was a single charactor.
UIKIT_EXTERN NSString *const ASTextBindingAttributeName;

/// The value of this attribute is a `ASTextShadow` object.
/// Use this attribute to add shadow to a range of text.
/// Shadow will be drawn below text glyphs. Use ASTextShadow.subShadow to add multi-shadow.
UIKIT_EXTERN NSString *const ASTextShadowAttributeName;

/// The value of this attribute is a `ASTextShadow` object.
/// Use this attribute to add inner shadow to a range of text.
/// Inner shadow will be drawn above text glyphs. Use ASTextShadow.subShadow to add multi-shadow.
UIKIT_EXTERN NSString *const ASTextInnerShadowAttributeName;

/// The value of this attribute is a `ASTextDecoration` object.
/// Use this attribute to add underline to a range of text.
/// The underline will be drawn below text glyphs.
UIKIT_EXTERN NSString *const ASTextUnderlineAttributeName;

/// The value of this attribute is a `ASTextDecoration` object.
/// Use this attribute to add strikethrough (delete line) to a range of text.
/// The strikethrough will be drawn above text glyphs.
UIKIT_EXTERN NSString *const ASTextStrikethroughAttributeName;

/// The value of this attribute is a `ASTextBorder` object.
/// Use this attribute to add cover border or cover color to a range of text.
/// The border will be drawn above the text glyphs.
UIKIT_EXTERN NSString *const ASTextBorderAttributeName;

/// The value of this attribute is a `ASTextBorder` object.
/// Use this attribute to add background border or background color to a range of text.
/// The border will be drawn below the text glyphs.
UIKIT_EXTERN NSString *const ASTextBackgroundBorderAttributeName;

/// The value of this attribute is a `ASTextBorder` object.
/// Use this attribute to add a code block border to one or more line of text.
/// The border will be drawn below the text glyphs.
UIKIT_EXTERN NSString *const ASTextBlockBorderAttributeName;

/// The value of this attribute is a `ASTextAttachment` object.
/// Use this attribute to add attachment to text.
/// It should be used in conjunction with a CTRunDelegate.
UIKIT_EXTERN NSString *const ASTextAttachmentAttributeName;

/// The value of this attribute is a `ASTextHighlight` object.
/// Use this attribute to add a touchable highlight state to a range of text.
UIKIT_EXTERN NSString *const ASTextHighlightAttributeName;

/// The value of this attribute is a `NSValue` object stores CGAffineTransform.
/// Use this attribute to add transform to each glyph in a range of text.
UIKIT_EXTERN NSString *const ASTextGlyphTransformAttributeName;



#pragma mark - String Token Define

UIKIT_EXTERN NSString *const ASTextAttachmentToken; ///< Object replacement character (U+FFFC), used for text attachment.
UIKIT_EXTERN NSString *const ASTextTruncationToken; ///< Horizontal ellipsis (U+2026), used for text truncation  "…".



#pragma mark - Attribute Value Define

/**
 The tap/long press action callback defined in ASText.
 
 @param containerView The text container view (such as ASLabel/ASTextView).
 @param text          The whole text.
 @param range         The text range in `text` (if no range, the range.location is NSNotFound).
 @param rect          The text frame in `containerView` (if no data, the rect is CGRectNull).
 */
typedef void(^ASTextAction)(UIView *containerView, NSAttributedString *text, NSRange range, CGRect rect);


/**
 ASTextBackedString objects are used by the NSAttributedString class cluster
 as the values for text backed string attributes (stored in the attributed
 string under the key named ASTextBackedStringAttributeName).
 
 It may used for copy/paste plain text from attributed string.
 Example: If :) is replace by a custom emoji (such as😊), the backed string can be set to @":)".
 */
@interface ASTextBackedString : NSObject <NSCoding, NSCopying>
+ (instancetype)stringWithString:(nullable NSString *)string;
@property (nullable, nonatomic, copy) NSString *string; ///< backed string
@end


/**
 ASTextBinding objects are used by the NSAttributedString class cluster
 as the values for shadow attributes (stored in the attributed string under
 the key named ASTextBindingAttributeName).
 
 Add this to a range of text will make the specified characters 'binding together'.
 ASTextView will treat the range of text as a single character during text
 selection and edit.
 */
@interface ASTextBinding : NSObject <NSCoding, NSCopying>
+ (instancetype)bindingWithDeleteConfirm:(BOOL)deleteConfirm;
@property (nonatomic) BOOL deleteConfirm; ///< confirm the range when delete in ASTextView
@end


/**
 ASTextShadow objects are used by the NSAttributedString class cluster
 as the values for shadow attributes (stored in the attributed string under
 the key named ASTextShadowAttributeName or ASTextInnerShadowAttributeName).
 
 It's similar to `NSShadow`, but offers more options.
 */
@interface ASTextShadow : NSObject <NSCoding, NSCopying>
+ (instancetype)shadowWithColor:(nullable UIColor *)color offset:(CGSize)offset radius:(CGFloat)radius;

@property (nullable, nonatomic, strong) UIColor *color; ///< shadow color
@property (nonatomic) CGSize offset;                    ///< shadow offset
@property (nonatomic) CGFloat radius;                   ///< shadow blur radius
@property (nonatomic) CGBlendMode blendMode;            ///< shadow blend mode
@property (nullable, nonatomic, strong) ASTextShadow *subShadow;  ///< a sub shadow which will be added above the parent shadow

+ (instancetype)shadowWithNSShadow:(NSShadow *)nsShadow; ///< convert NSShadow to ASTextShadow
- (NSShadow *)nsShadow; ///< convert ASTextShadow to NSShadow
@end


/**
 ASTextDecorationLine objects are used by the NSAttributedString class cluster
 as the values for decoration line attributes (stored in the attributed string under
 the key named ASTextUnderlineAttributeName or ASTextStrikethroughAttributeName).
 
 When it's used as underline, the line is drawn below text glyphs;
 when it's used as strikethrough, the line is drawn above text glyphs.
 */
@interface ASTextDecoration : NSObject <NSCoding, NSCopying>
+ (instancetype)decorationWithStyle:(ASTextLineStyle)style;
+ (instancetype)decorationWithStyle:(ASTextLineStyle)style width:(nullable NSNumber *)width color:(nullable UIColor *)color;
@property (nonatomic) ASTextLineStyle style;                   ///< line style
@property (nullable, nonatomic, strong) NSNumber *width;       ///< line width (nil means automatic width)
@property (nullable, nonatomic, strong) UIColor *color;        ///< line color (nil means automatic color)
@property (nullable, nonatomic, strong) ASTextShadow *shadow;  ///< line shadow
@end


/**
 ASTextBorder objects are used by the NSAttributedString class cluster
 as the values for border attributes (stored in the attributed string under
 the key named ASTextBorderAttributeName or ASTextBackgroundBorderAttributeName).
 
 It can be used to draw a border around a range of text, or draw a background
 to a range of text.
 
 Example:
 ╭──────╮
 │ Text │
 ╰──────╯
 */
@interface ASTextBorder : NSObject <NSCoding, NSCopying>
+ (instancetype)borderWithLineStyle:(ASTextLineStyle)lineStyle lineWidth:(CGFloat)width strokeColor:(nullable UIColor *)color;
+ (instancetype)borderWithFillColor:(nullable UIColor *)color cornerRadius:(CGFloat)cornerRadius;
@property (nonatomic) ASTextLineStyle lineStyle;              ///< border line style
@property (nonatomic) CGFloat strokeWidth;                    ///< border line width
@property (nullable, nonatomic, strong) UIColor *strokeColor; ///< border line color
@property (nonatomic) CGLineJoin lineJoin;                    ///< border line join
@property (nonatomic) UIEdgeInsets insets;                    ///< border insets for text bounds
@property (nonatomic) CGFloat cornerRadius;                   ///< border corder radius
@property (nullable, nonatomic, strong) ASTextShadow *shadow; ///< border shadow
@property (nullable, nonatomic, strong) UIColor *fillColor;   ///< inner fill color
@end


/**
 ASTextAttachment objects are used by the NSAttributedString class cluster
 as the values for attachment attributes (stored in the attributed string under
 the key named ASTextAttachmentAttributeName).
 
 When display an attributed string which contains `ASTextAttachment` object,
 the content will be placed in text metric. If the content is `UIImage`,
 then it will be drawn to CGContext; if the content is `UIView` or `CALayer`,
 then it will be added to the text container's view or layer.
 */
@interface ASTextAttachment : NSObject<NSCoding, NSCopying>
+ (instancetype)attachmentWithContent:(nullable id)content;
@property (nullable, nonatomic, strong) id content;             ///< Supported type: UIImage, UIView, CALayer
@property (nonatomic) UIViewContentMode contentMode;            ///< Content display mode.
@property (nonatomic) UIEdgeInsets contentInsets;               ///< The insets when drawing content.
@property (nullable, nonatomic, strong) NSDictionary *userInfo; ///< The user information dictionary.
@end


/**
 ASTextHighlight objects are used by the NSAttributedString class cluster
 as the values for touchable highlight attributes (stored in the attributed string
 under the key named ASTextHighlightAttributeName).
 
 When display an attributed string in `ASLabel` or `ASTextView`, the range of
 highlight text can be toucheds down by users. If a range of text is turned into
 highlighted state, the `attributes` in `ASTextHighlight` will be used to modify
 (set or remove) the original attributes in the range for display.
 */
@interface ASTextHighlight : NSObject <NSCopying>

/**
 Attributes that you can apply to text in an attributed string when highlight.
 Key:   Same as CoreText/ASText Attribute Name.
 Value: Modify attribute value when highlight (NSNull for remove attribute).
 */
@property (nullable, nonatomic, copy) NSDictionary<NSString *, id> *attributes;

/**
 Creates a highlight object with specified attributes.
 
 @param attributes The attributes which will replace original attributes when highlight,
 If the value is NSNull, it will removed when highlight.
 */
+ (instancetype)highlightWithAttributes:(nullable NSDictionary<NSString *, id> *)attributes;

/**
 Convenience methods to create a default highlight with the specifeid background color.
 
 @param color The background border color.
 */
+ (instancetype)highlightWithBackgroundColor:(nullable UIColor *)color;

// Convenience methods below to set the `attributes`.
- (void)setFont:(nullable UIFont *)font;
- (void)setColor:(nullable UIColor *)color;
- (void)setStrokeWidth:(nullable NSNumber *)width;
- (void)setStrokeColor:(nullable UIColor *)color;
- (void)setShadow:(nullable ASTextShadow *)shadow;
- (void)setInnerShadow:(nullable ASTextShadow *)shadow;
- (void)setUnderline:(nullable ASTextDecoration *)underline;
- (void)setStrikethrough:(nullable ASTextDecoration *)strikethrough;
- (void)setBackgroundBorder:(nullable ASTextBorder *)border;
- (void)setBorder:(nullable ASTextBorder *)border;
- (void)setAttachment:(nullable ASTextAttachment *)attachment;

/**
 The user information dictionary, default is nil.
 */
@property (nullable, nonatomic, copy) NSDictionary *userInfo;

/**
 Tap action when user tap the highlight, default is nil.
 If the value is nil, ASTextView or ASLabel will ask it's delegate to handle the tap action.
 */
@property (nullable, nonatomic, copy) ASTextAction tapAction;

/**
 Long press action when user long press the highlight, default is nil.
 If the value is nil, ASTextView or ASLabel will ask it's delegate to handle the long press action.
 */
@property (nullable, nonatomic, copy) ASTextAction longPressAction;

@end

NS_ASSUME_NONNULL_END
