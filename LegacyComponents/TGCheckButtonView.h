#import <UIKit/UIKit.h>

typedef enum
{
    TGCheckButtonStyleDefault,
    TGCheckButtonStyleDefaultBlue,
    TGCheckButtonStyleBar,
    TGCheckButtonStyleMedia,
    TGCheckButtonStyleGallery,
    TGCheckButtonStyleShare,
    TGCheckButtonStyleChat
} TGCheckButtonStyle;

@interface TGCheckButtonPallete : NSObject

@property (nonatomic, readonly) UIColor *defaultBackgroundColor;
@property (nonatomic, readonly) UIColor *accentBackgroundColor;
@property (nonatomic, readonly) UIColor *defaultBorderColor;
@property (nonatomic, readonly) UIColor *mediaBorderColor;
@property (nonatomic, readonly) UIColor *checkColor;
@property (nonatomic, readonly) UIColor *blueColor;

+ (instancetype)palleteWithDefaultBackgroundColor:(UIColor *)defaultBackgroundColor accentBackgroundColor:(UIColor *)accentBackgroundColor defaultBorderColor:(UIColor *)defaultBorderColor mediaBorderColor:(UIColor *)mediaBorderColor checkColor:(UIColor *)checkColor blueColor:(UIColor *)blueColor;

@end

@interface TGCheckButtonView : UIButton

- (instancetype)initWithStyle:(TGCheckButtonStyle)style;

- (void)setSelected:(bool)selected animated:(bool)animated;
- (void)setSelected:(bool)selected animated:(bool)animated bump:(bool)bump;

- (void)setNumber:(NSUInteger)number;

+ (void)resetCache;

@end
