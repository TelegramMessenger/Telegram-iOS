//
//  NSAttributedString+ASText.m
//  Modified from YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 14/10/7.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <AsyncDisplayKit/NSAttributedString+ASText.h>
#import <AsyncDisplayKit/NSParagraphStyle+ASText.h>
#import <AsyncDisplayKit/ASTextRunDelegate.h>
#import <AsyncDisplayKit/ASTextUtilities.h>
#import <CoreFoundation/CoreFoundation.h>


// Dummy class for category
@interface NSAttributedString_ASText : NSObject @end
@implementation NSAttributedString_ASText @end


@implementation NSAttributedString (ASText)

- (NSDictionary *)as_attributesAtIndex:(NSUInteger)index {
  if (index > self.length || self.length == 0) return nil;
  if (self.length > 0 && index == self.length) index--;
  return [self attributesAtIndex:index effectiveRange:NULL];
}

- (id)as_attribute:(NSString *)attributeName atIndex:(NSUInteger)index {
  if (!attributeName) return nil;
  if (index > self.length || self.length == 0) return nil;
  if (self.length > 0 && index == self.length) index--;
  return [self attribute:attributeName atIndex:index effectiveRange:NULL];
}

- (NSDictionary *)as_attributes {
  return [self as_attributesAtIndex:0];
}

- (UIFont *)as_font {
  return [self as_fontAtIndex:0];
}

- (UIFont *)as_fontAtIndex:(NSUInteger)index {
  return [self as_attribute:NSFontAttributeName atIndex:index];
}

- (NSNumber *)as_kern {
  return [self as_kernAtIndex:0];
}

- (NSNumber *)as_kernAtIndex:(NSUInteger)index {
  return [self as_attribute:NSKernAttributeName atIndex:index];
}

- (UIColor *)as_color {
  return [self as_colorAtIndex:0];
}

- (UIColor *)as_colorAtIndex:(NSUInteger)index {
  UIColor *color = [self as_attribute:NSForegroundColorAttributeName atIndex:index];
  if (!color) {
    CGColorRef ref = (__bridge CGColorRef)([self as_attribute:(NSString *)kCTForegroundColorAttributeName atIndex:index]);
    color = [UIColor colorWithCGColor:ref];
  }
  if (color && ![color isKindOfClass:[UIColor class]]) {
    if (CFGetTypeID((__bridge CFTypeRef)(color)) == CGColorGetTypeID()) {
      color = [UIColor colorWithCGColor:(__bridge CGColorRef)(color)];
    } else {
      color = nil;
    }
  }
  return color;
}

- (UIColor *)as_backgroundColor {
  return [self as_backgroundColorAtIndex:0];
}

- (UIColor *)as_backgroundColorAtIndex:(NSUInteger)index {
  return [self as_attribute:NSBackgroundColorAttributeName atIndex:index];
}

- (NSNumber *)as_strokeWidth {
  return [self as_strokeWidthAtIndex:0];
}

- (NSNumber *)as_strokeWidthAtIndex:(NSUInteger)index {
  return [self as_attribute:NSStrokeWidthAttributeName atIndex:index];
}

- (UIColor *)as_strokeColor {
  return [self as_strokeColorAtIndex:0];
}

- (UIColor *)as_strokeColorAtIndex:(NSUInteger)index {
  UIColor *color = [self as_attribute:NSStrokeColorAttributeName atIndex:index];
  if (!color) {
    CGColorRef ref = (__bridge CGColorRef)([self as_attribute:(NSString *)kCTStrokeColorAttributeName atIndex:index]);
    color = [UIColor colorWithCGColor:ref];
  }
  return color;
}

- (NSShadow *)as_shadow {
  return [self as_shadowAtIndex:0];
}

- (NSShadow *)as_shadowAtIndex:(NSUInteger)index {
  return [self as_attribute:NSShadowAttributeName atIndex:index];
}

- (NSUnderlineStyle)as_strikethroughStyle {
  return [self as_strikethroughStyleAtIndex:0];
}

- (NSUnderlineStyle)as_strikethroughStyleAtIndex:(NSUInteger)index {
  NSNumber *style = [self as_attribute:NSStrikethroughStyleAttributeName atIndex:index];
  return (NSUnderlineStyle)style.integerValue;
}

- (UIColor *)as_strikethroughColor {
  return [self as_strikethroughColorAtIndex:0];
}

- (UIColor *)as_strikethroughColorAtIndex:(NSUInteger)index {
  return [self as_attribute:NSStrikethroughColorAttributeName atIndex:index];
}

- (NSUnderlineStyle)as_underlineStyle {
  return [self as_underlineStyleAtIndex:0];
}

- (NSUnderlineStyle)as_underlineStyleAtIndex:(NSUInteger)index {
  NSNumber *style = [self as_attribute:NSUnderlineStyleAttributeName atIndex:index];
  return (NSUnderlineStyle)style.integerValue;
}

- (UIColor *)as_underlineColor {
  return [self as_underlineColorAtIndex:0];
}

- (UIColor *)as_underlineColorAtIndex:(NSUInteger)index {
  UIColor *color = [self as_attribute:NSUnderlineColorAttributeName atIndex:index];
  if (!color) {
    CGColorRef ref = (__bridge CGColorRef)([self as_attribute:(NSString *)kCTUnderlineColorAttributeName atIndex:index]);
    color = [UIColor colorWithCGColor:ref];
  }
  return color;
}

- (NSNumber *)as_ligature {
  return [self as_ligatureAtIndex:0];
}

- (NSNumber *)as_ligatureAtIndex:(NSUInteger)index {
  return [self as_attribute:NSLigatureAttributeName atIndex:index];
}

- (NSString *)as_textEffect {
  return [self as_textEffectAtIndex:0];
}

- (NSString *)as_textEffectAtIndex:(NSUInteger)index {
  return [self as_attribute:NSTextEffectAttributeName atIndex:index];
}

- (NSNumber *)as_obliqueness {
  return [self as_obliquenessAtIndex:0];
}

- (NSNumber *)as_obliquenessAtIndex:(NSUInteger)index {
  return [self as_attribute:NSObliquenessAttributeName atIndex:index];
}

- (NSNumber *)as_expansion {
  return [self as_expansionAtIndex:0];
}

- (NSNumber *)as_expansionAtIndex:(NSUInteger)index {
  return [self as_attribute:NSExpansionAttributeName atIndex:index];
}

- (NSNumber *)as_baselineOffset {
  return [self as_baselineOffsetAtIndex:0];
}

- (NSNumber *)as_baselineOffsetAtIndex:(NSUInteger)index {
  return [self as_attribute:NSBaselineOffsetAttributeName atIndex:index];
}

- (BOOL)as_verticalGlyphForm {
  return [self as_verticalGlyphFormAtIndex:0];
}

- (BOOL)as_verticalGlyphFormAtIndex:(NSUInteger)index {
  NSNumber *num = [self as_attribute:NSVerticalGlyphFormAttributeName atIndex:index];
  return num.boolValue;
}

- (NSString *)as_language {
  return [self as_languageAtIndex:0];
}

- (NSString *)as_languageAtIndex:(NSUInteger)index {
  return [self as_attribute:(id)kCTLanguageAttributeName atIndex:index];
}

- (NSArray *)as_writingDirection {
  return [self as_writingDirectionAtIndex:0];
}

- (NSArray *)as_writingDirectionAtIndex:(NSUInteger)index {
  return [self as_attribute:(id)kCTWritingDirectionAttributeName atIndex:index];
}

- (NSParagraphStyle *)as_paragraphStyle {
  return [self as_paragraphStyleAtIndex:0];
}

- (NSParagraphStyle *)as_paragraphStyleAtIndex:(NSUInteger)index {
  /*
   NSParagraphStyle is NOT toll-free bridged to CTParagraphStyleRef.
   
   CoreText can use both NSParagraphStyle and CTParagraphStyleRef,
   but UILabel/UITextView can only use NSParagraphStyle.
   
   We use NSParagraphStyle in both CoreText and UIKit.
   */
  NSParagraphStyle *style = [self as_attribute:NSParagraphStyleAttributeName atIndex:index];
  if (style) {
    if (CFGetTypeID((__bridge CFTypeRef)(style)) == CTParagraphStyleGetTypeID()) { \
      style = [NSParagraphStyle as_styleWithCTStyle:(__bridge CTParagraphStyleRef)(style)];
    }
  }
  return style;
}

#define ParagraphAttribute(_attr_) \
NSParagraphStyle *style = self.as_paragraphStyle; \
if (!style) style = [NSParagraphStyle defaultParagraphStyle]; \
return style. _attr_;

#define ParagraphAttributeAtIndex(_attr_) \
NSParagraphStyle *style = [self as_paragraphStyleAtIndex:index]; \
if (!style) style = [NSParagraphStyle defaultParagraphStyle]; \
return style. _attr_;

- (NSTextAlignment)as_alignment {
  ParagraphAttribute(alignment);
}

- (NSLineBreakMode)as_lineBreakMode {
  ParagraphAttribute(lineBreakMode);
}

- (CGFloat)as_lineSpacing {
  ParagraphAttribute(lineSpacing);
}

- (CGFloat)as_paragraphSpacing {
  ParagraphAttribute(paragraphSpacing);
}

- (CGFloat)as_paragraphSpacingBefore {
  ParagraphAttribute(paragraphSpacingBefore);
}

- (CGFloat)as_firstLineHeadIndent {
  ParagraphAttribute(firstLineHeadIndent);
}

- (CGFloat)as_headIndent {
  ParagraphAttribute(headIndent);
}

- (CGFloat)as_tailIndent {
  ParagraphAttribute(tailIndent);
}

- (CGFloat)as_minimumLineHeight {
  ParagraphAttribute(minimumLineHeight);
}

- (CGFloat)as_maximumLineHeight {
  ParagraphAttribute(maximumLineHeight);
}

- (CGFloat)as_lineHeightMultiple {
  ParagraphAttribute(lineHeightMultiple);
}

- (NSWritingDirection)as_baseWritingDirection {
  ParagraphAttribute(baseWritingDirection);
}

- (float)as_hyphenationFactor {
  ParagraphAttribute(hyphenationFactor);
}

- (CGFloat)as_defaultTabInterval {
  ParagraphAttribute(defaultTabInterval);
}

- (NSArray *)as_tabStops {
  ParagraphAttribute(tabStops);
}

- (NSTextAlignment)as_alignmentAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(alignment);
}

- (NSLineBreakMode)as_lineBreakModeAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(lineBreakMode);
}

- (CGFloat)as_lineSpacingAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(lineSpacing);
}

- (CGFloat)as_paragraphSpacingAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(paragraphSpacing);
}

- (CGFloat)as_paragraphSpacingBeforeAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(paragraphSpacingBefore);
}

- (CGFloat)as_firstLineHeadIndentAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(firstLineHeadIndent);
}

- (CGFloat)as_headIndentAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(headIndent);
}

- (CGFloat)as_tailIndentAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(tailIndent);
}

- (CGFloat)as_minimumLineHeightAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(minimumLineHeight);
}

- (CGFloat)as_maximumLineHeightAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(maximumLineHeight);
}

- (CGFloat)as_lineHeightMultipleAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(lineHeightMultiple);
}

- (NSWritingDirection)as_baseWritingDirectionAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(baseWritingDirection);
}

- (float)as_hyphenationFactorAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(hyphenationFactor);
}

- (CGFloat)as_defaultTabIntervalAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(defaultTabInterval);
}

- (NSArray *)as_tabStopsAtIndex:(NSUInteger)index {
  ParagraphAttributeAtIndex(tabStops);
}

#undef ParagraphAttribute
#undef ParagraphAttributeAtIndex

- (ASTextShadow *)as_textShadow {
  return [self as_textShadowAtIndex:0];
}

- (ASTextShadow *)as_textShadowAtIndex:(NSUInteger)index {
  return [self as_attribute:ASTextShadowAttributeName atIndex:index];
}

- (ASTextShadow *)as_textInnerShadow {
  return [self as_textInnerShadowAtIndex:0];
}

- (ASTextShadow *)as_textInnerShadowAtIndex:(NSUInteger)index {
  return [self as_attribute:ASTextInnerShadowAttributeName atIndex:index];
}

- (ASTextDecoration *)as_textUnderline {
  return [self as_textUnderlineAtIndex:0];
}

- (ASTextDecoration *)as_textUnderlineAtIndex:(NSUInteger)index {
  return [self as_attribute:ASTextUnderlineAttributeName atIndex:index];
}

- (ASTextDecoration *)as_textStrikethrough {
  return [self as_textStrikethroughAtIndex:0];
}

- (ASTextDecoration *)as_textStrikethroughAtIndex:(NSUInteger)index {
  return [self as_attribute:ASTextStrikethroughAttributeName atIndex:index];
}

- (ASTextBorder *)as_textBorder {
  return [self as_textBorderAtIndex:0];
}

- (ASTextBorder *)as_textBorderAtIndex:(NSUInteger)index {
  return [self as_attribute:ASTextBorderAttributeName atIndex:index];
}

- (ASTextBorder *)as_textBackgroundBorder {
  return [self as_textBackgroundBorderAtIndex:0];
}

- (ASTextBorder *)as_textBackgroundBorderAtIndex:(NSUInteger)index {
  return [self as_attribute:ASTextBackedStringAttributeName atIndex:index];
}

- (CGAffineTransform)as_textGlyphTransform {
  return [self as_textGlyphTransformAtIndex:0];
}

- (CGAffineTransform)as_textGlyphTransformAtIndex:(NSUInteger)index {
  NSValue *value = [self as_attribute:ASTextGlyphTransformAttributeName atIndex:index];
  if (!value) return CGAffineTransformIdentity;
  return [value CGAffineTransformValue];
}

- (NSString *)as_plainTextForRange:(NSRange)range {
  if (range.location == NSNotFound ||range.length == NSNotFound) return nil;
  NSMutableString *result = [NSMutableString string];
  if (range.length == 0) return result;
  NSString *string = self.string;
  [self enumerateAttribute:ASTextBackedStringAttributeName inRange:range options:kNilOptions usingBlock:^(id value, NSRange range, BOOL *stop) {
    ASTextBackedString *backed = value;
    if (backed && backed.string) {
      [result appendString:backed.string];
    } else {
      [result appendString:[string substringWithRange:range]];
    }
  }];
  return result;
}

+ (NSMutableAttributedString *)as_attachmentStringWithContent:(id)content
                                                  contentMode:(UIViewContentMode)contentMode
                                                        width:(CGFloat)width
                                                       ascent:(CGFloat)ascent
                                                      descent:(CGFloat)descent {
  NSMutableAttributedString *atr = [[NSMutableAttributedString alloc] initWithString:ASTextAttachmentToken];
  
  ASTextAttachment *attach = [ASTextAttachment new];
  attach.content = content;
  attach.contentMode = contentMode;
  [atr as_setTextAttachment:attach range:NSMakeRange(0, atr.length)];
  
  ASTextRunDelegate *delegate = [ASTextRunDelegate new];
  delegate.width = width;
  delegate.ascent = ascent;
  delegate.descent = descent;
  CTRunDelegateRef delegateRef = delegate.CTRunDelegate;
  [atr as_setRunDelegate:delegateRef range:NSMakeRange(0, atr.length)];
  if (delegate) CFRelease(delegateRef);
  
  return atr;
}

+ (NSMutableAttributedString *)as_attachmentStringWithContent:(id)content
                                                  contentMode:(UIViewContentMode)contentMode
                                               attachmentSize:(CGSize)attachmentSize
                                                  alignToFont:(UIFont *)font
                                                    alignment:(ASTextVerticalAlignment)alignment {
  NSMutableAttributedString *atr = [[NSMutableAttributedString alloc] initWithString:ASTextAttachmentToken];
  
  ASTextAttachment *attach = [ASTextAttachment new];
  attach.content = content;
  attach.contentMode = contentMode;
  [atr as_setTextAttachment:attach range:NSMakeRange(0, atr.length)];
  
  ASTextRunDelegate *delegate = [ASTextRunDelegate new];
  delegate.width = attachmentSize.width;
  switch (alignment) {
    case ASTextVerticalAlignmentTop: {
      delegate.ascent = font.ascender;
      delegate.descent = attachmentSize.height - font.ascender;
      if (delegate.descent < 0) {
        delegate.descent = 0;
        delegate.ascent = attachmentSize.height;
      }
    } break;
    case ASTextVerticalAlignmentCenter: {
      CGFloat fontHeight = font.ascender - font.descender;
      CGFloat yOffset = font.ascender - fontHeight * 0.5;
      delegate.ascent = attachmentSize.height * 0.5 + yOffset;
      delegate.descent = attachmentSize.height - delegate.ascent;
      if (delegate.descent < 0) {
        delegate.descent = 0;
        delegate.ascent = attachmentSize.height;
      }
    } break;
    case ASTextVerticalAlignmentBottom: {
      delegate.ascent = attachmentSize.height + font.descender;
      delegate.descent = -font.descender;
      if (delegate.ascent < 0) {
        delegate.ascent = 0;
        delegate.descent = attachmentSize.height;
      }
    } break;
    default: {
      delegate.ascent = attachmentSize.height;
      delegate.descent = 0;
    } break;
  }
  
  CTRunDelegateRef delegateRef = delegate.CTRunDelegate;
  [atr as_setRunDelegate:delegateRef range:NSMakeRange(0, atr.length)];
  if (delegate) CFRelease(delegateRef);
  
  return atr;
}

+ (NSMutableAttributedString *)as_attachmentStringWithEmojiImage:(UIImage *)image
                                                        fontSize:(CGFloat)fontSize {
  if (!image || fontSize <= 0) return nil;
  
  BOOL hasAnim = NO;
  if (image.images.count > 1) {
    hasAnim = YES;
  } else if (NSProtocolFromString(@"ASAnimatedImage") &&
             [image conformsToProtocol:NSProtocolFromString(@"ASAnimatedImage")]) {
    NSNumber *frameCount = [image valueForKey:@"animatedImageFrameCount"];
    if (frameCount.intValue > 1) hasAnim = YES;
  }
  
  CGFloat ascent = ASTextEmojiGetAscentWithFontSize(fontSize);
  CGFloat descent = ASTextEmojiGetDescentWithFontSize(fontSize);
  CGRect bounding = ASTextEmojiGetGlyphBoundingRectWithFontSize(fontSize);
  
  ASTextRunDelegate *delegate = [ASTextRunDelegate new];
  delegate.ascent = ascent;
  delegate.descent = descent;
  delegate.width = bounding.size.width + 2 * bounding.origin.x;
  
  ASTextAttachment *attachment = [ASTextAttachment new];
  attachment.contentMode = UIViewContentModeScaleAspectFit;
  attachment.contentInsets = UIEdgeInsetsMake(ascent - (bounding.size.height + bounding.origin.y), bounding.origin.x, descent + bounding.origin.y, bounding.origin.x);
  if (hasAnim) {
    Class imageClass = NSClassFromString(@"ASAnimatedImageView");
    if (!imageClass) imageClass = [UIImageView class];
    UIImageView *view = (id)[imageClass new];
    view.frame = bounding;
    view.image = image;
    view.contentMode = UIViewContentModeScaleAspectFit;
    attachment.content = view;
  } else {
    attachment.content = image;
  }
  
  NSMutableAttributedString *atr = [[NSMutableAttributedString alloc] initWithString:ASTextAttachmentToken];
  [atr as_setTextAttachment:attachment range:NSMakeRange(0, atr.length)];
  CTRunDelegateRef ctDelegate = delegate.CTRunDelegate;
  [atr as_setRunDelegate:ctDelegate range:NSMakeRange(0, atr.length)];
  if (ctDelegate) CFRelease(ctDelegate);
  
  return atr;
}

- (NSRange)as_rangeOfAll {
  return NSMakeRange(0, self.length);
}

- (BOOL)as_isSharedAttributesInAllRange {
  __block BOOL shared = YES;
  __block NSDictionary *firstAttrs = nil;
  [self enumerateAttributesInRange:self.as_rangeOfAll options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
    if (range.location == 0) {
      firstAttrs = attrs;
    } else {
      if (firstAttrs.count != attrs.count) {
        shared = NO;
        *stop = YES;
      } else if (firstAttrs) {
        if (![firstAttrs isEqualToDictionary:attrs]) {
          shared = NO;
          *stop = YES;
        }
      }
    }
  }];
  return shared;
}

- (BOOL)as_canDrawWithUIKit {
  static NSMutableSet *failSet;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    failSet = [NSMutableSet new];
    [failSet addObject:(id)kCTGlyphInfoAttributeName];
#if TARGET_OS_IOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [failSet addObject:(id)kCTCharacterShapeAttributeName];
#pragma clang diagnostic pop
#endif
    [failSet addObject:(id)kCTLanguageAttributeName];
    [failSet addObject:(id)kCTRunDelegateAttributeName];
    [failSet addObject:(id)kCTBaselineClassAttributeName];
    [failSet addObject:(id)kCTBaselineInfoAttributeName];
    [failSet addObject:(id)kCTBaselineReferenceInfoAttributeName];
    [failSet addObject:(id)kCTRubyAnnotationAttributeName];
    [failSet addObject:ASTextShadowAttributeName];
    [failSet addObject:ASTextInnerShadowAttributeName];
    [failSet addObject:ASTextUnderlineAttributeName];
    [failSet addObject:ASTextStrikethroughAttributeName];
    [failSet addObject:ASTextBorderAttributeName];
    [failSet addObject:ASTextBackgroundBorderAttributeName];
    [failSet addObject:ASTextBlockBorderAttributeName];
    [failSet addObject:ASTextAttachmentAttributeName];
    [failSet addObject:ASTextHighlightAttributeName];
    [failSet addObject:ASTextGlyphTransformAttributeName];
  });
  
#define Fail { result = NO; *stop = YES; return; }
  __block BOOL result = YES;
  [self enumerateAttributesInRange:self.as_rangeOfAll options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
    if (attrs.count == 0) return;
    for (NSString *str in attrs.allKeys) {
      if ([failSet containsObject:str]) Fail;
    }
    if (attrs[(id)kCTForegroundColorAttributeName] && !attrs[NSForegroundColorAttributeName]) Fail;
    if (attrs[(id)kCTStrokeColorAttributeName] && !attrs[NSStrokeColorAttributeName]) Fail;
    if (attrs[(id)kCTUnderlineColorAttributeName]) {
      if (!attrs[NSUnderlineColorAttributeName]) Fail;
    }
    NSParagraphStyle *style = attrs[NSParagraphStyleAttributeName];
    if (style && CFGetTypeID((__bridge CFTypeRef)(style)) == CTParagraphStyleGetTypeID()) Fail;
  }];
  return result;
#undef Fail
}

@end

@implementation NSMutableAttributedString (ASText)

- (void)as_setAttributes:(NSDictionary *)attributes {
  [self setAs_attributes:attributes];
}

- (void)setAs_attributes:(NSDictionary *)attributes {
  if (attributes == (id)[NSNull null]) attributes = nil;
  [self setAttributes:@{} range:NSMakeRange(0, self.length)];
  [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [self as_setAttribute:key value:obj];
  }];
}

- (void)as_setAttribute:(NSString *)name value:(id)value {
  [self as_setAttribute:name value:value range:NSMakeRange(0, self.length)];
}

- (void)as_setAttribute:(NSString *)name value:(id)value range:(NSRange)range {
  if (!name || [NSNull isEqual:name]) return;
  if (value && ![NSNull isEqual:value]) [self addAttribute:name value:value range:range];
  else [self removeAttribute:name range:range];
}

- (void)as_removeAttributesInRange:(NSRange)range {
  [self setAttributes:nil range:range];
}

#pragma mark - Property Setter

- (void)setAs_font:(UIFont *)font {
  /*
   In iOS7 and later, UIFont is toll-free bridged to CTFontRef,
   although Apple does not mention it in documentation.
   
   In iOS6, UIFont is a wrapper for CTFontRef, so CoreText can alse use UIfont,
   but UILabel/UITextView cannot use CTFontRef.
   
   We use UIFont for both CoreText and UIKit.
   */
  [self as_setFont:font range:NSMakeRange(0, self.length)];
}

- (void)setAs_kern:(NSNumber *)kern {
  [self as_setKern:kern range:NSMakeRange(0, self.length)];
}

- (void)setAs_color:(UIColor *)color {
  [self as_setColor:color range:NSMakeRange(0, self.length)];
}

- (void)setAs_backgroundColor:(UIColor *)backgroundColor {
  [self as_setBackgroundColor:backgroundColor range:NSMakeRange(0, self.length)];
}

- (void)setAs_strokeWidth:(NSNumber *)strokeWidth {
  [self as_setStrokeWidth:strokeWidth range:NSMakeRange(0, self.length)];
}

- (void)setAs_strokeColor:(UIColor *)strokeColor {
  [self as_setStrokeColor:strokeColor range:NSMakeRange(0, self.length)];
}

- (void)setAs_shadow:(NSShadow *)shadow {
  [self as_setShadow:shadow range:NSMakeRange(0, self.length)];
}

- (void)setAs_strikethroughStyle:(NSUnderlineStyle)strikethroughStyle {
  [self as_setStrikethroughStyle:strikethroughStyle range:NSMakeRange(0, self.length)];
}

- (void)setAs_strikethroughColor:(UIColor *)strikethroughColor {
  [self as_setStrikethroughColor:strikethroughColor range:NSMakeRange(0, self.length)];
}

- (void)setAs_underlineStyle:(NSUnderlineStyle)underlineStyle {
  [self as_setUnderlineStyle:underlineStyle range:NSMakeRange(0, self.length)];
}

- (void)setAs_underlineColor:(UIColor *)underlineColor {
  [self as_setUnderlineColor:underlineColor range:NSMakeRange(0, self.length)];
}

- (void)setAs_ligature:(NSNumber *)ligature {
  [self as_setLigature:ligature range:NSMakeRange(0, self.length)];
}

- (void)setAs_textEffect:(NSString *)textEffect {
  [self as_setTextEffect:textEffect range:NSMakeRange(0, self.length)];
}

- (void)setAs_obliqueness:(NSNumber *)obliqueness {
  [self as_setObliqueness:obliqueness range:NSMakeRange(0, self.length)];
}

- (void)setAs_expansion:(NSNumber *)expansion {
  [self as_setExpansion:expansion range:NSMakeRange(0, self.length)];
}

- (void)setAs_baselineOffset:(NSNumber *)baselineOffset {
  [self as_setBaselineOffset:baselineOffset range:NSMakeRange(0, self.length)];
}

- (void)setAs_verticalGlyphForm:(BOOL)verticalGlyphForm {
  [self as_setVerticalGlyphForm:verticalGlyphForm range:NSMakeRange(0, self.length)];
}

- (void)setAs_language:(NSString *)language {
  [self as_setLanguage:language range:NSMakeRange(0, self.length)];
}

- (void)setAs_writingDirection:(NSArray *)writingDirection {
  [self as_setWritingDirection:writingDirection range:NSMakeRange(0, self.length)];
}

- (void)setAs_paragraphStyle:(NSParagraphStyle *)paragraphStyle {
  /*
   NSParagraphStyle is NOT toll-free bridged to CTParagraphStyleRef.
   
   CoreText can use both NSParagraphStyle and CTParagraphStyleRef,
   but UILabel/UITextView can only use NSParagraphStyle.
   
   We use NSParagraphStyle in both CoreText and UIKit.
   */
  [self as_setParagraphStyle:paragraphStyle range:NSMakeRange(0, self.length)];
}

- (void)setAs_alignment:(NSTextAlignment)alignment {
  [self as_setAlignment:alignment range:NSMakeRange(0, self.length)];
}

- (void)setAs_baseWritingDirection:(NSWritingDirection)baseWritingDirection {
  [self as_setBaseWritingDirection:baseWritingDirection range:NSMakeRange(0, self.length)];
}

- (void)setAs_lineSpacing:(CGFloat)lineSpacing {
  [self as_setLineSpacing:lineSpacing range:NSMakeRange(0, self.length)];
}

- (void)setAs_paragraphSpacing:(CGFloat)paragraphSpacing {
  [self as_setParagraphSpacing:paragraphSpacing range:NSMakeRange(0, self.length)];
}

- (void)setAs_paragraphSpacingBefore:(CGFloat)paragraphSpacingBefore {
  [self as_setParagraphSpacing:paragraphSpacingBefore range:NSMakeRange(0, self.length)];
}

- (void)setAs_firstLineHeadIndent:(CGFloat)firstLineHeadIndent {
  [self as_setFirstLineHeadIndent:firstLineHeadIndent range:NSMakeRange(0, self.length)];
}

- (void)setAs_headIndent:(CGFloat)headIndent {
  [self as_setHeadIndent:headIndent range:NSMakeRange(0, self.length)];
}

- (void)setAs_tailIndent:(CGFloat)tailIndent {
  [self as_setTailIndent:tailIndent range:NSMakeRange(0, self.length)];
}

- (void)setAs_lineBreakMode:(NSLineBreakMode)lineBreakMode {
  [self as_setLineBreakMode:lineBreakMode range:NSMakeRange(0, self.length)];
}

- (void)setAs_minimumLineHeight:(CGFloat)minimumLineHeight {
  [self as_setMinimumLineHeight:minimumLineHeight range:NSMakeRange(0, self.length)];
}

- (void)setAs_maximumLineHeight:(CGFloat)maximumLineHeight {
  [self as_setMaximumLineHeight:maximumLineHeight range:NSMakeRange(0, self.length)];
}

- (void)setAs_lineHeightMultiple:(CGFloat)lineHeightMultiple {
  [self as_setLineHeightMultiple:lineHeightMultiple range:NSMakeRange(0, self.length)];
}

- (void)setAs_hyphenationFactor:(float)hyphenationFactor {
  [self as_setHyphenationFactor:hyphenationFactor range:NSMakeRange(0, self.length)];
}

- (void)setAs_defaultTabInterval:(CGFloat)defaultTabInterval {
  [self as_setDefaultTabInterval:defaultTabInterval range:NSMakeRange(0, self.length)];
}

- (void)setAs_tabStops:(NSArray *)tabStops {
  [self as_setTabStops:tabStops range:NSMakeRange(0, self.length)];
}

- (void)setAs_textShadow:(ASTextShadow *)textShadow {
  [self as_setTextShadow:textShadow range:NSMakeRange(0, self.length)];
}

- (void)setAs_textInnerShadow:(ASTextShadow *)textInnerShadow {
  [self as_setTextInnerShadow:textInnerShadow range:NSMakeRange(0, self.length)];
}

- (void)setAs_textUnderline:(ASTextDecoration *)textUnderline {
  [self as_setTextUnderline:textUnderline range:NSMakeRange(0, self.length)];
}

- (void)setAs_textStrikethrough:(ASTextDecoration *)textStrikethrough {
  [self as_setTextStrikethrough:textStrikethrough range:NSMakeRange(0, self.length)];
}

- (void)setAs_textBorder:(ASTextBorder *)textBorder {
  [self as_setTextBorder:textBorder range:NSMakeRange(0, self.length)];
}

- (void)setAs_textBackgroundBorder:(ASTextBorder *)textBackgroundBorder {
  [self as_setTextBackgroundBorder:textBackgroundBorder range:NSMakeRange(0, self.length)];
}

- (void)setAs_textGlyphTransform:(CGAffineTransform)textGlyphTransform {
  [self as_setTextGlyphTransform:textGlyphTransform range:NSMakeRange(0, self.length)];
}

#pragma mark - Range Setter

- (void)as_setFont:(UIFont *)font range:(NSRange)range {
  [self as_setAttribute:NSFontAttributeName value:font range:range];
}

- (void)as_setKern:(NSNumber *)kern range:(NSRange)range {
  [self as_setAttribute:NSKernAttributeName value:kern range:range];
}

- (void)as_setColor:(UIColor *)color range:(NSRange)range {
  [self as_setAttribute:(id)kCTForegroundColorAttributeName value:(id)color.CGColor range:range];
  [self as_setAttribute:NSForegroundColorAttributeName value:color range:range];
}

- (void)as_setBackgroundColor:(UIColor *)backgroundColor range:(NSRange)range {
  [self as_setAttribute:NSBackgroundColorAttributeName value:backgroundColor range:range];
}

- (void)as_setStrokeWidth:(NSNumber *)strokeWidth range:(NSRange)range {
  [self as_setAttribute:NSStrokeWidthAttributeName value:strokeWidth range:range];
}

- (void)as_setStrokeColor:(UIColor *)strokeColor range:(NSRange)range {
  [self as_setAttribute:(id)kCTStrokeColorAttributeName value:(id)strokeColor.CGColor range:range];
  [self as_setAttribute:NSStrokeColorAttributeName value:strokeColor range:range];
}

- (void)as_setShadow:(NSShadow *)shadow range:(NSRange)range {
  [self as_setAttribute:NSShadowAttributeName value:shadow range:range];
}

- (void)as_setStrikethroughStyle:(NSUnderlineStyle)strikethroughStyle range:(NSRange)range {
  NSNumber *style = strikethroughStyle == 0 ? nil : @(strikethroughStyle);
  [self as_setAttribute:NSStrikethroughStyleAttributeName value:style range:range];
}

- (void)as_setStrikethroughColor:(UIColor *)strikethroughColor range:(NSRange)range {
  [self as_setAttribute:NSStrikethroughColorAttributeName value:strikethroughColor range:range];
}

- (void)as_setUnderlineStyle:(NSUnderlineStyle)underlineStyle range:(NSRange)range {
  NSNumber *style = underlineStyle == 0 ? nil : @(underlineStyle);
  [self as_setAttribute:NSUnderlineStyleAttributeName value:style range:range];
}

- (void)as_setUnderlineColor:(UIColor *)underlineColor range:(NSRange)range {
  [self as_setAttribute:(id)kCTUnderlineColorAttributeName value:(id)underlineColor.CGColor range:range];
  [self as_setAttribute:NSUnderlineColorAttributeName value:underlineColor range:range];
}

- (void)as_setLigature:(NSNumber *)ligature range:(NSRange)range {
  [self as_setAttribute:NSLigatureAttributeName value:ligature range:range];
}

- (void)as_setTextEffect:(NSString *)textEffect range:(NSRange)range {
  [self as_setAttribute:NSTextEffectAttributeName value:textEffect range:range];
}

- (void)as_setObliqueness:(NSNumber *)obliqueness range:(NSRange)range {
  [self as_setAttribute:NSObliquenessAttributeName value:obliqueness range:range];
}

- (void)as_setExpansion:(NSNumber *)expansion range:(NSRange)range {
  [self as_setAttribute:NSExpansionAttributeName value:expansion range:range];
}

- (void)as_setBaselineOffset:(NSNumber *)baselineOffset range:(NSRange)range {
  [self as_setAttribute:NSBaselineOffsetAttributeName value:baselineOffset range:range];
}

- (void)as_setVerticalGlyphForm:(BOOL)verticalGlyphForm range:(NSRange)range {
  NSNumber *v = verticalGlyphForm ? @(YES) : nil;
  [self as_setAttribute:NSVerticalGlyphFormAttributeName value:v range:range];
}

- (void)as_setLanguage:(NSString *)language range:(NSRange)range {
  [self as_setAttribute:(id)kCTLanguageAttributeName value:language range:range];
}

- (void)as_setWritingDirection:(NSArray *)writingDirection range:(NSRange)range {
  [self as_setAttribute:(id)kCTWritingDirectionAttributeName value:writingDirection range:range];
}

- (void)as_setParagraphStyle:(NSParagraphStyle *)paragraphStyle range:(NSRange)range {
  /*
   NSParagraphStyle is NOT toll-free bridged to CTParagraphStyleRef.
   
   CoreText can use both NSParagraphStyle and CTParagraphStyleRef,
   but UILabel/UITextView can only use NSParagraphStyle.
   
   We use NSParagraphStyle in both CoreText and UIKit.
   */
  [self as_setAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
}

#define ParagraphStyleSet(_attr_) \
[self enumerateAttribute:NSParagraphStyleAttributeName \
inRange:range \
options:kNilOptions \
usingBlock: ^(NSParagraphStyle *value, NSRange subRange, BOOL *stop) { \
NSMutableParagraphStyle *style = nil; \
if (value) { \
if (CFGetTypeID((__bridge CFTypeRef)(value)) == CTParagraphStyleGetTypeID()) { \
value = [NSParagraphStyle as_styleWithCTStyle:(__bridge CTParagraphStyleRef)(value)]; \
} \
if (value. _attr_ == _attr_) return; \
if ([value isKindOfClass:[NSMutableParagraphStyle class]]) { \
style = (id)value; \
} else { \
style = value.mutableCopy; \
} \
} else { \
if ([NSParagraphStyle defaultParagraphStyle]. _attr_ == _attr_) return; \
style = [NSParagraphStyle defaultParagraphStyle].mutableCopy; \
} \
style. _attr_ = _attr_; \
[self as_setParagraphStyle:style range:subRange]; \
}];

- (void)as_setAlignment:(NSTextAlignment)alignment range:(NSRange)range {
  ParagraphStyleSet(alignment);
}

- (void)as_setBaseWritingDirection:(NSWritingDirection)baseWritingDirection range:(NSRange)range {
  ParagraphStyleSet(baseWritingDirection);
}

- (void)as_setLineSpacing:(CGFloat)lineSpacing range:(NSRange)range {
  ParagraphStyleSet(lineSpacing);
}

- (void)as_setParagraphSpacing:(CGFloat)paragraphSpacing range:(NSRange)range {
  ParagraphStyleSet(paragraphSpacing);
}

- (void)as_setParagraphSpacingBefore:(CGFloat)paragraphSpacingBefore range:(NSRange)range {
  ParagraphStyleSet(paragraphSpacingBefore);
}

- (void)as_setFirstLineHeadIndent:(CGFloat)firstLineHeadIndent range:(NSRange)range {
  ParagraphStyleSet(firstLineHeadIndent);
}

- (void)as_setHeadIndent:(CGFloat)headIndent range:(NSRange)range {
  ParagraphStyleSet(headIndent);
}

- (void)as_setTailIndent:(CGFloat)tailIndent range:(NSRange)range {
  ParagraphStyleSet(tailIndent);
}

- (void)as_setLineBreakMode:(NSLineBreakMode)lineBreakMode range:(NSRange)range {
  ParagraphStyleSet(lineBreakMode);
}

- (void)as_setMinimumLineHeight:(CGFloat)minimumLineHeight range:(NSRange)range {
  ParagraphStyleSet(minimumLineHeight);
}

- (void)as_setMaximumLineHeight:(CGFloat)maximumLineHeight range:(NSRange)range {
  ParagraphStyleSet(maximumLineHeight);
}

- (void)as_setLineHeightMultiple:(CGFloat)lineHeightMultiple range:(NSRange)range {
  ParagraphStyleSet(lineHeightMultiple);
}

- (void)as_setHyphenationFactor:(float)hyphenationFactor range:(NSRange)range {
  ParagraphStyleSet(hyphenationFactor);
}

- (void)as_setDefaultTabInterval:(CGFloat)defaultTabInterval range:(NSRange)range {
  ParagraphStyleSet(defaultTabInterval);
}

- (void)as_setTabStops:(NSArray *)tabStops range:(NSRange)range {
  ParagraphStyleSet(tabStops);
}

#undef ParagraphStyleSet

- (void)as_setSuperscript:(NSNumber *)superscript range:(NSRange)range {
  if ([superscript isEqualToNumber:@(0)]) {
    superscript = nil;
  }
  [self as_setAttribute:(id)kCTSuperscriptAttributeName value:superscript range:range];
}

- (void)as_setGlyphInfo:(CTGlyphInfoRef)glyphInfo range:(NSRange)range {
  [self as_setAttribute:(id)kCTGlyphInfoAttributeName value:(__bridge id)glyphInfo range:range];
}

- (void)as_setCharacterShape:(NSNumber *)characterShape range:(NSRange)range {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [self as_setAttribute:(id)kCTCharacterShapeAttributeName value:characterShape range:range];
#pragma clang diagnostic pop
}

- (void)as_setRunDelegate:(CTRunDelegateRef)runDelegate range:(NSRange)range {
  [self as_setAttribute:(id)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:range];
}

- (void)as_setBaselineClass:(CFStringRef)baselineClass range:(NSRange)range {
  [self as_setAttribute:(id)kCTBaselineClassAttributeName value:(__bridge id)baselineClass range:range];
}

- (void)as_setBaselineInfo:(CFDictionaryRef)baselineInfo range:(NSRange)range {
  [self as_setAttribute:(id)kCTBaselineInfoAttributeName value:(__bridge id)baselineInfo range:range];
}

- (void)as_setBaselineReferenceInfo:(CFDictionaryRef)referenceInfo range:(NSRange)range {
  [self as_setAttribute:(id)kCTBaselineReferenceInfoAttributeName value:(__bridge id)referenceInfo range:range];
}

- (void)as_setRubyAnnotation:(CTRubyAnnotationRef)ruby range:(NSRange)range {
  [self as_setAttribute:(id)kCTRubyAnnotationAttributeName value:(__bridge id)ruby range:range];
}

- (void)as_setAttachment:(NSTextAttachment *)attachment range:(NSRange)range {
  [self as_setAttribute:NSAttachmentAttributeName value:attachment range:range];
}

- (void)as_setLink:(id)link range:(NSRange)range {
  [self as_setAttribute:NSLinkAttributeName value:link range:range];
}

- (void)as_setTextBackedString:(ASTextBackedString *)textBackedString range:(NSRange)range {
  [self as_setAttribute:ASTextBackedStringAttributeName value:textBackedString range:range];
}

- (void)as_setTextBinding:(ASTextBinding *)textBinding range:(NSRange)range {
  [self as_setAttribute:ASTextBindingAttributeName value:textBinding range:range];
}

- (void)as_setTextShadow:(ASTextShadow *)textShadow range:(NSRange)range {
  [self as_setAttribute:ASTextShadowAttributeName value:textShadow range:range];
}

- (void)as_setTextInnerShadow:(ASTextShadow *)textInnerShadow range:(NSRange)range {
  [self as_setAttribute:ASTextInnerShadowAttributeName value:textInnerShadow range:range];
}

- (void)as_setTextUnderline:(ASTextDecoration *)textUnderline range:(NSRange)range {
  [self as_setAttribute:ASTextUnderlineAttributeName value:textUnderline range:range];
}

- (void)as_setTextStrikethrough:(ASTextDecoration *)textStrikethrough range:(NSRange)range {
  [self as_setAttribute:ASTextStrikethroughAttributeName value:textStrikethrough range:range];
}

- (void)as_setTextBorder:(ASTextBorder *)textBorder range:(NSRange)range {
  [self as_setAttribute:ASTextBorderAttributeName value:textBorder range:range];
}

- (void)as_setTextBackgroundBorder:(ASTextBorder *)textBackgroundBorder range:(NSRange)range {
  [self as_setAttribute:ASTextBackgroundBorderAttributeName value:textBackgroundBorder range:range];
}

- (void)as_setTextAttachment:(ASTextAttachment *)textAttachment range:(NSRange)range {
  [self as_setAttribute:ASTextAttachmentAttributeName value:textAttachment range:range];
}

- (void)as_setTextHighlight:(ASTextHighlight *)textHighlight range:(NSRange)range {
  [self as_setAttribute:ASTextHighlightAttributeName value:textHighlight range:range];
}

- (void)as_setTextBlockBorder:(ASTextBorder *)textBlockBorder range:(NSRange)range {
  [self as_setAttribute:ASTextBlockBorderAttributeName value:textBlockBorder range:range];
}

- (void)as_setTextGlyphTransform:(CGAffineTransform)textGlyphTransform range:(NSRange)range {
  NSValue *value = CGAffineTransformIsIdentity(textGlyphTransform) ? nil : [NSValue valueWithCGAffineTransform:textGlyphTransform];
  [self as_setAttribute:ASTextGlyphTransformAttributeName value:value range:range];
}

- (void)as_setTextHighlightRange:(NSRange)range
                           color:(UIColor *)color
                 backgroundColor:(UIColor *)backgroundColor
                        userInfo:(NSDictionary *)userInfo
                       tapAction:(ASTextAction)tapAction
                 longPressAction:(ASTextAction)longPressAction {
  ASTextHighlight *highlight = [ASTextHighlight highlightWithBackgroundColor:backgroundColor];
  highlight.userInfo = userInfo;
  highlight.tapAction = tapAction;
  highlight.longPressAction = longPressAction;
  if (color) [self as_setColor:color range:range];
  [self as_setTextHighlight:highlight range:range];
}

- (void)as_setTextHighlightRange:(NSRange)range
                           color:(UIColor *)color
                 backgroundColor:(UIColor *)backgroundColor
                       tapAction:(ASTextAction)tapAction {
  [self as_setTextHighlightRange:range
                           color:color
                 backgroundColor:backgroundColor
                        userInfo:nil
                       tapAction:tapAction
                 longPressAction:nil];
}

- (void)as_setTextHighlightRange:(NSRange)range
                           color:(UIColor *)color
                 backgroundColor:(UIColor *)backgroundColor
                        userInfo:(NSDictionary *)userInfo {
  [self as_setTextHighlightRange:range
                           color:color
                 backgroundColor:backgroundColor
                        userInfo:userInfo
                       tapAction:nil
                 longPressAction:nil];
}

- (void)as_insertString:(NSString *)string atIndex:(NSUInteger)location {
  [self replaceCharactersInRange:NSMakeRange(location, 0) withString:string];
  [self as_removeDiscontinuousAttributesInRange:NSMakeRange(location, string.length)];
}

- (void)as_appendString:(NSString *)string {
  NSUInteger length = self.length;
  [self replaceCharactersInRange:NSMakeRange(length, 0) withString:string];
  [self as_removeDiscontinuousAttributesInRange:NSMakeRange(length, string.length)];
}

- (void)as_removeDiscontinuousAttributesInRange:(NSRange)range {
  NSArray *keys = [NSMutableAttributedString as_allDiscontinuousAttributeKeys];
  for (NSString *key in keys) {
    [self removeAttribute:key range:range];
  }
}

+ (NSArray *)as_allDiscontinuousAttributeKeys {
  static NSArray *keys;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    keys = @[(id)kCTSuperscriptAttributeName,
             (id)kCTRunDelegateAttributeName,
             ASTextBackedStringAttributeName,
             ASTextBindingAttributeName,
             ASTextAttachmentAttributeName,
             (id)kCTRubyAnnotationAttributeName,
             NSAttachmentAttributeName];
  });
  return keys;
}

@end
