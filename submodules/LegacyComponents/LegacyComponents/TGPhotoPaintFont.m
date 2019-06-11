#import "TGPhotoPaintFont.h"

@implementation TGPhotoPaintFont

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGPhotoPaintFont *font = (TGPhotoPaintFont *)object;
    return [font.title isEqualToString:self.title];
}

+ (instancetype)fontWithTitle:(NSString *)title titleInset:(CGFloat)titleInset fontName:(NSString *)fontName previewFontName:(NSString *)previewFontName sizeCorrection:(CGFloat)sizeCorrection
{
    TGPhotoPaintFont *font = [[TGPhotoPaintFont alloc] init];
    font->_title = title;
    font->_titleInset = titleInset;
    font->_fontName = fontName;
    font->_previewFontName = previewFontName;
    font->_sizeCorrection = sizeCorrection;
    return font;
}

+ (NSArray *)availableFonts
{
    return @
    [
        [TGPhotoPaintFont fontWithTitle:@"Main" titleInset:0 fontName:@"Helvetica-Bold" previewFontName:@"Helvetica" sizeCorrection:0]
    ];
}

@end
