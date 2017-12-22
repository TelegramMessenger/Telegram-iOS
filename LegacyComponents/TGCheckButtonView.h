#import <UIKit/UIKit.h>

typedef enum
{
    TGCheckButtonStyleDefault,
    TGCheckButtonStyleDefaultBlue,
    TGCheckButtonStyleBar,
    TGCheckButtonStyleMedia,
    TGCheckButtonStyleGallery,
    TGCheckButtonStyleShare
} TGCheckButtonStyle;

@interface TGCheckButtonPallete : NSObject

@property (nonatomic, readonly) UIImage *defaultBackgroundColor;
@property (nonatomic, readonly) UIColor *accentBackgroundColor;
@property (nonatomic, readonly) UIColor *defaultBorderColor;
@property (nonatomic, readonly) UIColor *mediaBorderColor;
@property (nonatomic, readonly) UIColor *checkColor;

+ (instancetype)palleteWithDefaultBackgroundColor:(UIColor *)defaultBackgroundColor accentBackgroundColor:(UIColor *)accentBackgroundColor defaultBorderColor:(UIColor *)defaultBorderColor mediaBorderColor:(UIColor *)mediaBorderColor checkColor:(UIColor *)checkColor;

@end

@interface TGCheckButtonView : UIButton

- (instancetype)initWithStyle:(TGCheckButtonStyle)style;

- (void)setSelected:(bool)selected animated:(bool)animated;
- (void)setSelected:(bool)selected animated:(bool)animated bump:(bool)bump;

- (void)setNumber:(NSUInteger)number;
- (void)setPallete:(TGCheckButtonPallete *)pallete;

@end
