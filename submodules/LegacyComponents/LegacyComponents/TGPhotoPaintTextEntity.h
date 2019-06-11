#import <LegacyComponents/TGPhotoPaintEntity.h>
#import "TGPaintSwatch.h"
#import "TGPhotoPaintFont.h"

@interface TGPhotoPaintTextEntity : TGPhotoPaintEntity

@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) TGPhotoPaintFont *font;
@property (nonatomic, strong) TGPaintSwatch *swatch;
@property (nonatomic, assign) CGFloat baseFontSize;
@property (nonatomic, assign) CGFloat maxWidth;
@property (nonatomic, assign) bool stroke;

- (instancetype)initWithText:(NSString *)text font:(TGPhotoPaintFont *)font swatch:(TGPaintSwatch *)swatch baseFontSize:(CGFloat)baseFontSize maxWidth:(CGFloat)maxWidth stroke:(bool)stroke;

@end
