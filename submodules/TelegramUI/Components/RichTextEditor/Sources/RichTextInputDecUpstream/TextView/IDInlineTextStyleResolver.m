#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDInlineTextStyleResolver.h"

NSAttributedStringKey const IDInlineTextBoldAttributeName =
    @"IDInlineTextBold";
NSAttributedStringKey const IDInlineTextItalicAttributeName =
    @"IDInlineTextItalic";
NSAttributedStringKey const IDInlineTextUnderlineAttributeName =
    @"IDInlineTextUnderline";
NSAttributedStringKey const IDInlineTextStrikethroughAttributeName =
    @"IDInlineTextStrikethrough";

NSAttributedStringKey const IDInlineTextBaseFontAttributeName =
    @"IDInlineTextBaseFont";

@interface IDInlineTextStyleResolver ()
@property(nonatomic, strong) UIFont *defaultFont;
@end

@implementation IDInlineTextStyleResolver

- (instancetype)initWithDefaultFont:(UIFont *)font {
    NSParameterAssert(font != nil);
    self = [super init];
    if (self != nil) {
        _defaultFont = font;
    }
    return self;
}

- (IDInlineTextTraits)traitsInAttributes:
    (NSDictionary<NSAttributedStringKey, id> *)attributes {
    IDInlineTextTraits traits = 0;
    if ([attributes[IDInlineTextBoldAttributeName] boolValue]) {
        traits |= IDInlineTextTraitBold;
    }
    if ([attributes[IDInlineTextItalicAttributeName] boolValue]) {
        traits |= IDInlineTextTraitItalic;
    }
    if ([attributes[IDInlineTextUnderlineAttributeName] boolValue]) {
        traits |= IDInlineTextTraitUnderline;
    }
    if ([attributes[IDInlineTextStrikethroughAttributeName] boolValue]) {
        traits |= IDInlineTextTraitStrikethrough;
    }
    return traits;
}

- (UIFont *)baseFontForAttributes:
    (NSDictionary<NSAttributedStringKey, id> *)attributes {
    UIFont *storedBase = attributes[IDInlineTextBaseFontAttributeName];
    if ([storedBase isKindOfClass:UIFont.class]) {
        return storedBase;
    }
    UIFont *source = attributes[NSFontAttributeName];
    if (![source isKindOfClass:UIFont.class]) {
        source = self.defaultFont;
    }
    UIFontDescriptorSymbolicTraits traits =
        source.fontDescriptor.symbolicTraits;
    traits &= ~(UIFontDescriptorTraitBold |
                UIFontDescriptorTraitItalic);
    UIFontDescriptor *descriptor =
        [source.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    return descriptor == nil
        ? source
        : [UIFont fontWithDescriptor:descriptor size:source.pointSize];
}

- (NSDictionary<NSAttributedStringKey, id> *)
    attributesByApplyingTraits:(IDInlineTextTraits)traits
                  toAttributes:
                      (NSDictionary<NSAttributedStringKey, id> *)attributes {
    NSMutableDictionary<NSAttributedStringKey, id> *result =
        attributes.mutableCopy;
    UIFont *baseFont = [self baseFontForAttributes:attributes];
    result[IDInlineTextBaseFontAttributeName] = baseFont;

    [result removeObjectForKey:IDInlineTextBoldAttributeName];
    [result removeObjectForKey:IDInlineTextItalicAttributeName];
    [result removeObjectForKey:IDInlineTextUnderlineAttributeName];
    [result removeObjectForKey:IDInlineTextStrikethroughAttributeName];

    if ((traits & IDInlineTextTraitBold) != 0) {
        result[IDInlineTextBoldAttributeName] = @YES;
    }
    if ((traits & IDInlineTextTraitItalic) != 0) {
        result[IDInlineTextItalicAttributeName] = @YES;
    }
    if ((traits & IDInlineTextTraitUnderline) != 0) {
        result[IDInlineTextUnderlineAttributeName] = @YES;
    }
    if ((traits & IDInlineTextTraitStrikethrough) != 0) {
        result[IDInlineTextStrikethroughAttributeName] = @YES;
    }

    UIFontDescriptorSymbolicTraits fontTraits =
        baseFont.fontDescriptor.symbolicTraits;
    if ((traits & IDInlineTextTraitBold) != 0) {
        fontTraits |= UIFontDescriptorTraitBold;
    }
    if ((traits & IDInlineTextTraitItalic) != 0) {
        fontTraits |= UIFontDescriptorTraitItalic;
    }
    UIFontDescriptor *descriptor =
        [baseFont.fontDescriptor
            fontDescriptorWithSymbolicTraits:fontTraits];
    result[NSFontAttributeName] = descriptor == nil
        ? baseFont
        : [UIFont fontWithDescriptor:descriptor size:baseFont.pointSize];

    if ((traits & IDInlineTextTraitUnderline) != 0) {
        result[NSUnderlineStyleAttributeName] =
            @(NSUnderlineStyleSingle);
    } else {
        [result removeObjectForKey:NSUnderlineStyleAttributeName];
    }
    if ((traits & IDInlineTextTraitStrikethrough) != 0) {
        result[NSStrikethroughStyleAttributeName] =
            @(NSUnderlineStyleSingle);
    } else {
        [result removeObjectForKey:NSStrikethroughStyleAttributeName];
    }
    // NO contributor pass here. This function is EDIT-time — it is reached from import and from
    // trait toggles — so running contributors here both missed every other edit path and baked
    // display styling into the document. They run on the render read instead; see
    // `IDCanonicalTextStorageAdapter.attributesAtIndex:effectiveRange:`.
    return result.copy;
}

- (NSDictionary<NSAttributedStringKey, id> *)
    attributesByApplyingDefaultFont:(UIFont *)font
                          textColor:(UIColor *)textColor
                       toAttributes:
                           (NSDictionary<NSAttributedStringKey, id> *)
                               attributes {
    NSMutableDictionary<NSAttributedStringKey, id> *updated =
        attributes.mutableCopy;
    updated[IDInlineTextBaseFontAttributeName] = font;
    updated[NSForegroundColorAttributeName] = textColor;
    return [self
        attributesByApplyingTraits:[self traitsInAttributes:attributes]
                      toAttributes:updated];
}

- (IDInlineTextTraits)importedTraitsInAttributes:
    (NSDictionary<NSAttributedStringKey, id> *)attributes {
    if ([attributes[IDInlineTextBaseFontAttributeName]
            isKindOfClass:UIFont.class]) {
        return [self traitsInAttributes:attributes];
    }
    IDInlineTextTraits semantic = 0;
    UIFont *font = attributes[NSFontAttributeName];
    UIFontDescriptorSymbolicTraits fontTraits =
        [font isKindOfClass:UIFont.class]
            ? font.fontDescriptor.symbolicTraits : 0;
    BOOL bold = attributes[IDInlineTextBoldAttributeName] != nil
        ? [attributes[IDInlineTextBoldAttributeName] boolValue]
        : (fontTraits & UIFontDescriptorTraitBold) != 0;
    BOOL italic = attributes[IDInlineTextItalicAttributeName] != nil
        ? [attributes[IDInlineTextItalicAttributeName] boolValue]
        : (fontTraits & UIFontDescriptorTraitItalic) != 0;
    BOOL underline = attributes[IDInlineTextUnderlineAttributeName] != nil
        ? [attributes[IDInlineTextUnderlineAttributeName] boolValue]
        : [attributes[NSUnderlineStyleAttributeName] integerValue] != 0;
    BOOL strikethrough =
        attributes[IDInlineTextStrikethroughAttributeName] != nil
            ? [attributes[IDInlineTextStrikethroughAttributeName] boolValue]
            : [attributes[NSStrikethroughStyleAttributeName] integerValue] != 0;
    if (bold) {
        semantic |= IDInlineTextTraitBold;
    }
    if (italic) {
        semantic |= IDInlineTextTraitItalic;
    }
    if (underline) {
        semantic |= IDInlineTextTraitUnderline;
    }
    if (strikethrough) {
        semantic |= IDInlineTextTraitStrikethrough;
    }
    return semantic;
}

- (NSAttributedString *)importAttributedString:
    (NSAttributedString *)attributedString {
    NSMutableAttributedString *result =
        [attributedString mutableCopy];
    [attributedString enumerateAttributesInRange:
        NSMakeRange(0, attributedString.length)
                                          options:0
                                       usingBlock:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSRange range,
          BOOL *stop) {
        IDInlineTextTraits traits =
            [self importedTraitsInAttributes:attributes];
        [result setAttributes:
            [self attributesByApplyingTraits:traits
                                toAttributes:attributes]
                      range:range];
    }];
    return result.copy;
}

@end

#endif
