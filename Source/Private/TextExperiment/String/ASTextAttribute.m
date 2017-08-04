//
//  ASTextAttribute.m
//  Modified from YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 14/10/26.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "ASTextAttribute.h"
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <AsyncDisplayKit/NSAttributedString+ASText.h>

NSString *const ASTextBackedStringAttributeName = @"ASTextBackedString";
NSString *const ASTextBindingAttributeName = @"ASTextBinding";
NSString *const ASTextShadowAttributeName = @"ASTextShadow";
NSString *const ASTextInnerShadowAttributeName = @"ASTextInnerShadow";
NSString *const ASTextUnderlineAttributeName = @"ASTextUnderline";
NSString *const ASTextStrikethroughAttributeName = @"ASTextStrikethrough";
NSString *const ASTextBorderAttributeName = @"ASTextBorder";
NSString *const ASTextBackgroundBorderAttributeName = @"ASTextBackgroundBorder";
NSString *const ASTextBlockBorderAttributeName = @"ASTextBlockBorder";
NSString *const ASTextAttachmentAttributeName = @"ASTextAttachment";
NSString *const ASTextHighlightAttributeName = @"ASTextHighlight";
NSString *const ASTextGlyphTransformAttributeName = @"ASTextGlyphTransform";

NSString *const ASTextAttachmentToken = @"\uFFFC";
NSString *const ASTextTruncationToken = @"\u2026";


ASTextAttributeType ASTextAttributeGetType(NSString *name){
  if (name.length == 0) return ASTextAttributeTypeNone;
  
  static NSMutableDictionary *dic;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dic = [NSMutableDictionary new];
    NSNumber *All = @(ASTextAttributeTypeUIKit | ASTextAttributeTypeCoreText | ASTextAttributeTypeASText);
    NSNumber *CoreText_ASText = @(ASTextAttributeTypeCoreText | ASTextAttributeTypeASText);
    NSNumber *UIKit_ASText = @(ASTextAttributeTypeUIKit | ASTextAttributeTypeASText);
    NSNumber *UIKit_CoreText = @(ASTextAttributeTypeUIKit | ASTextAttributeTypeCoreText);
    NSNumber *UIKit = @(ASTextAttributeTypeUIKit);
    NSNumber *CoreText = @(ASTextAttributeTypeCoreText);
    NSNumber *ASText = @(ASTextAttributeTypeASText);
    
    dic[NSFontAttributeName] = All;
    dic[NSKernAttributeName] = All;
    dic[NSForegroundColorAttributeName] = UIKit;
    dic[(id)kCTForegroundColorAttributeName] = CoreText;
    dic[(id)kCTForegroundColorFromContextAttributeName] = CoreText;
    dic[NSBackgroundColorAttributeName] = UIKit;
    dic[NSStrokeWidthAttributeName] = All;
    dic[NSStrokeColorAttributeName] = UIKit;
    dic[(id)kCTStrokeColorAttributeName] = CoreText_ASText;
    dic[NSShadowAttributeName] = UIKit_ASText;
    dic[NSStrikethroughStyleAttributeName] = UIKit;
    dic[NSUnderlineStyleAttributeName] = UIKit_CoreText;
    dic[(id)kCTUnderlineColorAttributeName] = CoreText;
    dic[NSLigatureAttributeName] = All;
    dic[(id)kCTSuperscriptAttributeName] = UIKit; //it's a CoreText attrubite, but only supported by UIKit...
    dic[NSVerticalGlyphFormAttributeName] = All;
    dic[(id)kCTGlyphInfoAttributeName] = CoreText_ASText;
    dic[(id)kCTCharacterShapeAttributeName] = CoreText_ASText;
    dic[(id)kCTRunDelegateAttributeName] = CoreText_ASText;
    dic[(id)kCTBaselineClassAttributeName] = CoreText_ASText;
    dic[(id)kCTBaselineInfoAttributeName] = CoreText_ASText;
    dic[(id)kCTBaselineReferenceInfoAttributeName] = CoreText_ASText;
    dic[(id)kCTWritingDirectionAttributeName] = CoreText_ASText;
    dic[NSParagraphStyleAttributeName] = All;
    
    dic[NSStrikethroughColorAttributeName] = UIKit;
    dic[NSUnderlineColorAttributeName] = UIKit;
    dic[NSTextEffectAttributeName] = UIKit;
    dic[NSObliquenessAttributeName] = UIKit;
    dic[NSExpansionAttributeName] = UIKit;
    dic[(id)kCTLanguageAttributeName] = CoreText_ASText;
    dic[NSBaselineOffsetAttributeName] = UIKit;
    dic[NSWritingDirectionAttributeName] = All;
    dic[NSAttachmentAttributeName] = UIKit;
    dic[NSLinkAttributeName] = UIKit;
    dic[(id)kCTRubyAnnotationAttributeName] = CoreText;
    
    dic[ASTextBackedStringAttributeName] = ASText;
    dic[ASTextBindingAttributeName] = ASText;
    dic[ASTextShadowAttributeName] = ASText;
    dic[ASTextInnerShadowAttributeName] = ASText;
    dic[ASTextUnderlineAttributeName] = ASText;
    dic[ASTextStrikethroughAttributeName] = ASText;
    dic[ASTextBorderAttributeName] = ASText;
    dic[ASTextBackgroundBorderAttributeName] = ASText;
    dic[ASTextBlockBorderAttributeName] = ASText;
    dic[ASTextAttachmentAttributeName] = ASText;
    dic[ASTextHighlightAttributeName] = ASText;
    dic[ASTextGlyphTransformAttributeName] = ASText;
  });
  NSNumber *num = dic[name];
  if (num) return num.integerValue;
  return ASTextAttributeTypeNone;
}


@implementation ASTextBackedString

+ (instancetype)stringWithString:(NSString *)string {
  ASTextBackedString *one = [self new];
  one.string = string;
  return one;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.string forKey:@"string"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  _string = [aDecoder decodeObjectForKey:@"string"];
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  __typeof__(self) one = [self.class new];
  one.string = self.string;
  return one;
}

@end


@implementation ASTextBinding

+ (instancetype)bindingWithDeleteConfirm:(BOOL)deleteConfirm {
  ASTextBinding *one = [self new];
  one.deleteConfirm = deleteConfirm;
  return one;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:@(self.deleteConfirm) forKey:@"deleteConfirm"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  _deleteConfirm = ((NSNumber *)[aDecoder decodeObjectForKey:@"deleteConfirm"]).boolValue;
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  __typeof__(self) one = [self.class new];
  one.deleteConfirm = self.deleteConfirm;
  return one;
}

@end


@implementation ASTextShadow

+ (instancetype)shadowWithColor:(UIColor *)color offset:(CGSize)offset radius:(CGFloat)radius {
  ASTextShadow *one = [self new];
  one.color = color;
  one.offset = offset;
  one.radius = radius;
  return one;
}

+ (instancetype)shadowWithNSShadow:(NSShadow *)nsShadow {
  if (!nsShadow) return nil;
  ASTextShadow *shadow = [self new];
  shadow.offset = nsShadow.shadowOffset;
  shadow.radius = nsShadow.shadowBlurRadius;
  id color = nsShadow.shadowColor;
  if (color) {
    if (CGColorGetTypeID() == CFGetTypeID((__bridge CFTypeRef)(color))) {
      color = [UIColor colorWithCGColor:(__bridge CGColorRef)(color)];
    }
    if ([color isKindOfClass:[UIColor class]]) {
      shadow.color = color;
    }
  }
  return shadow;
}

- (NSShadow *)nsShadow {
  NSShadow *shadow = [NSShadow new];
  shadow.shadowOffset = self.offset;
  shadow.shadowBlurRadius = self.radius;
  shadow.shadowColor = self.color;
  return shadow;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.color forKey:@"color"];
  [aCoder encodeObject:@(self.radius) forKey:@"radius"];
  [aCoder encodeObject:[NSValue valueWithCGSize:self.offset] forKey:@"offset"];
  [aCoder encodeObject:self.subShadow forKey:@"subShadow"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  _color = [aDecoder decodeObjectForKey:@"color"];
  _radius = ((NSNumber *)[aDecoder decodeObjectForKey:@"radius"]).floatValue;
  _offset = ((NSValue *)[aDecoder decodeObjectForKey:@"offset"]).CGSizeValue;
  _subShadow = [aDecoder decodeObjectForKey:@"subShadow"];
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  __typeof__(self) one = [self.class new];
  one.color = self.color;
  one.radius = self.radius;
  one.offset = self.offset;
  one.subShadow = self.subShadow.copy;
  return one;
}

@end


@implementation ASTextDecoration

- (instancetype)init {
  self = [super init];
  _style = ASTextLineStyleSingle;
  return self;
}

+ (instancetype)decorationWithStyle:(ASTextLineStyle)style {
  ASTextDecoration *one = [self new];
  one.style = style;
  return one;
}
+ (instancetype)decorationWithStyle:(ASTextLineStyle)style width:(NSNumber *)width color:(UIColor *)color {
  ASTextDecoration *one = [self new];
  one.style = style;
  one.width = width;
  one.color = color;
  return one;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:@(self.style) forKey:@"style"];
  [aCoder encodeObject:self.width forKey:@"width"];
  [aCoder encodeObject:self.color forKey:@"color"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  self.style = ((NSNumber *)[aDecoder decodeObjectForKey:@"style"]).unsignedIntegerValue;
  self.width = [aDecoder decodeObjectForKey:@"width"];
  self.color = [aDecoder decodeObjectForKey:@"color"];
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  __typeof__(self) one = [self.class new];
  one.style = self.style;
  one.width = self.width;
  one.color = self.color;
  return one;
}

@end


@implementation ASTextBorder

+ (instancetype)borderWithLineStyle:(ASTextLineStyle)lineStyle lineWidth:(CGFloat)width strokeColor:(UIColor *)color {
  ASTextBorder *one = [self new];
  one.lineStyle = lineStyle;
  one.strokeWidth = width;
  one.strokeColor = color;
  return one;
}

+ (instancetype)borderWithFillColor:(UIColor *)color cornerRadius:(CGFloat)cornerRadius {
  ASTextBorder *one = [self new];
  one.fillColor = color;
  one.cornerRadius = cornerRadius;
  one.insets = UIEdgeInsetsMake(-2, 0, 0, -2);
  return one;
}

- (instancetype)init {
  self = [super init];
  self.lineStyle = ASTextLineStyleSingle;
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:@(self.lineStyle) forKey:@"lineStyle"];
  [aCoder encodeObject:@(self.strokeWidth) forKey:@"strokeWidth"];
  [aCoder encodeObject:self.strokeColor forKey:@"strokeColor"];
  [aCoder encodeObject:@(self.lineJoin) forKey:@"lineJoin"];
  [aCoder encodeObject:[NSValue valueWithUIEdgeInsets:self.insets] forKey:@"insets"];
  [aCoder encodeObject:@(self.cornerRadius) forKey:@"cornerRadius"];
  [aCoder encodeObject:self.shadow forKey:@"shadow"];
  [aCoder encodeObject:self.fillColor forKey:@"fillColor"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  _lineStyle = ((NSNumber *)[aDecoder decodeObjectForKey:@"lineStyle"]).unsignedIntegerValue;
  _strokeWidth = ((NSNumber *)[aDecoder decodeObjectForKey:@"strokeWidth"]).doubleValue;
  _strokeColor = [aDecoder decodeObjectForKey:@"strokeColor"];
  _lineJoin = (CGLineJoin)((NSNumber *)[aDecoder decodeObjectForKey:@"join"]).unsignedIntegerValue;
  _insets = ((NSValue *)[aDecoder decodeObjectForKey:@"insets"]).UIEdgeInsetsValue;
  _cornerRadius = ((NSNumber *)[aDecoder decodeObjectForKey:@"cornerRadius"]).doubleValue;
  _shadow = [aDecoder decodeObjectForKey:@"shadow"];
  _fillColor = [aDecoder decodeObjectForKey:@"fillColor"];
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  __typeof__(self) one = [self.class new];
  one.lineStyle = self.lineStyle;
  one.strokeWidth = self.strokeWidth;
  one.strokeColor = self.strokeColor;
  one.lineJoin = self.lineJoin;
  one.insets = self.insets;
  one.cornerRadius = self.cornerRadius;
  one.shadow = self.shadow.copy;
  one.fillColor = self.fillColor;
  return one;
}

@end


@implementation ASTextAttachment

+ (instancetype)attachmentWithContent:(id)content {
  ASTextAttachment *one = [self new];
  one.content = content;
  return one;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.content forKey:@"content"];
  [aCoder encodeObject:[NSValue valueWithUIEdgeInsets:self.contentInsets] forKey:@"contentInsets"];
  [aCoder encodeObject:self.userInfo forKey:@"userInfo"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  _content = [aDecoder decodeObjectForKey:@"content"];
  _contentInsets = ((NSValue *)[aDecoder decodeObjectForKey:@"contentInsets"]).UIEdgeInsetsValue;
  _userInfo = [aDecoder decodeObjectForKey:@"userInfo"];
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  __typeof__(self) one = [self.class new];
  if ([self.content respondsToSelector:@selector(copy)]) {
    one.content = [self.content copy];
  } else {
    one.content = self.content;
  }
  one.contentInsets = self.contentInsets;
  one.userInfo = self.userInfo.copy;
  return one;
}

@end


@implementation ASTextHighlight

+ (instancetype)highlightWithAttributes:(NSDictionary *)attributes {
  ASTextHighlight *one = [self new];
  one.attributes = attributes;
  return one;
}

+ (instancetype)highlightWithBackgroundColor:(UIColor *)color {
  ASTextBorder *highlightBorder = [ASTextBorder new];
  highlightBorder.insets = UIEdgeInsetsMake(-2, -1, -2, -1);
  highlightBorder.cornerRadius = 3;
  highlightBorder.fillColor = color;
  
  ASTextHighlight *one = [self new];
  [one setBackgroundBorder:highlightBorder];
  return one;
}

- (void)setAttributes:(NSDictionary *)attributes {
  _attributes = attributes.mutableCopy;
}

- (id)copyWithZone:(NSZone *)zone {
  __typeof__(self) one = [self.class new];
  one.attributes = self.attributes.mutableCopy;
  return one;
}

- (void)_makeMutableAttributes {
  if (!_attributes) {
    _attributes = [NSMutableDictionary new];
  } else if (![_attributes isKindOfClass:[NSMutableDictionary class]]) {
    _attributes = _attributes.mutableCopy;
  }
}

- (void)setFont:(UIFont *)font {
  [self _makeMutableAttributes];
  if (font == (id)[NSNull null] || font == nil) {
    ((NSMutableDictionary *)_attributes)[(id)kCTFontAttributeName] = [NSNull null];
  } else {
    CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
    if (ctFont) {
      ((NSMutableDictionary *)_attributes)[(id)kCTFontAttributeName] = (__bridge id)(ctFont);
      CFRelease(ctFont);
    }
  }
}

- (void)setColor:(UIColor *)color {
  [self _makeMutableAttributes];
  if (color == (id)[NSNull null] || color == nil) {
    ((NSMutableDictionary *)_attributes)[(id)kCTForegroundColorAttributeName] = [NSNull null];
    ((NSMutableDictionary *)_attributes)[NSForegroundColorAttributeName] = [NSNull null];
  } else {
    ((NSMutableDictionary *)_attributes)[(id)kCTForegroundColorAttributeName] = (__bridge id)(color.CGColor);
    ((NSMutableDictionary *)_attributes)[NSForegroundColorAttributeName] = color;
  }
}

- (void)setStrokeWidth:(NSNumber *)width {
  [self _makeMutableAttributes];
  if (width == (id)[NSNull null] || width == nil) {
    ((NSMutableDictionary *)_attributes)[(id)kCTStrokeWidthAttributeName] = [NSNull null];
  } else {
    ((NSMutableDictionary *)_attributes)[(id)kCTStrokeWidthAttributeName] = width;
  }
}

- (void)setStrokeColor:(UIColor *)color {
  [self _makeMutableAttributes];
  if (color == (id)[NSNull null] || color == nil) {
    ((NSMutableDictionary *)_attributes)[(id)kCTStrokeColorAttributeName] = [NSNull null];
    ((NSMutableDictionary *)_attributes)[NSStrokeColorAttributeName] = [NSNull null];
  } else {
    ((NSMutableDictionary *)_attributes)[(id)kCTStrokeColorAttributeName] = (__bridge id)(color.CGColor);
    ((NSMutableDictionary *)_attributes)[NSStrokeColorAttributeName] = color;
  }
}

- (void)setTextAttribute:(NSString *)attribute value:(id)value {
  [self _makeMutableAttributes];
  if (value == nil) value = [NSNull null];
  ((NSMutableDictionary *)_attributes)[attribute] = value;
}

- (void)setShadow:(ASTextShadow *)shadow {
  [self setTextAttribute:ASTextShadowAttributeName value:shadow];
}

- (void)setInnerShadow:(ASTextShadow *)shadow {
  [self setTextAttribute:ASTextInnerShadowAttributeName value:shadow];
}

- (void)setUnderline:(ASTextDecoration *)underline {
  [self setTextAttribute:ASTextUnderlineAttributeName value:underline];
}

- (void)setStrikethrough:(ASTextDecoration *)strikethrough {
  [self setTextAttribute:ASTextStrikethroughAttributeName value:strikethrough];
}

- (void)setBackgroundBorder:(ASTextBorder *)border {
  [self setTextAttribute:ASTextBackgroundBorderAttributeName value:border];
}

- (void)setBorder:(ASTextBorder *)border {
  [self setTextAttribute:ASTextBorderAttributeName value:border];
}

- (void)setAttachment:(ASTextAttachment *)attachment {
  [self setTextAttribute:ASTextAttachmentAttributeName value:attachment];
}

@end

