#import <LegacyComponents/TGPhotoPaintEntity.h>

@class TGPaintSwatch;
@class TGPhotoPaintFont;

typedef enum {
    TGPhotoPaintTextEntityStyleOutlined,
    TGPhotoPaintTextEntityStyleRegular,
    TGPhotoPaintTextEntityStyleFramed
} TGPhotoPaintTextEntityStyle;

@interface TGPhotoPaintTextEntity : TGPhotoPaintEntity

@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) TGPhotoPaintFont *font;
@property (nonatomic, strong) TGPaintSwatch *swatch;
@property (nonatomic, assign) CGFloat baseFontSize;
@property (nonatomic, assign) CGFloat maxWidth;
@property (nonatomic, assign) TGPhotoPaintTextEntityStyle style;

@property (nonatomic, strong) UIImage *renderImage;

- (instancetype)initWithText:(NSString *)text font:(TGPhotoPaintFont *)font swatch:(TGPaintSwatch *)swatch baseFontSize:(CGFloat)baseFontSize maxWidth:(CGFloat)maxWidth style:(TGPhotoPaintTextEntityStyle)style;

@end
