#import <UIKit/UIKit.h>

typedef enum
{
    TGCheckButtonStyleDefault,
    TGCheckButtonStyleDefaultBlue,
    TGCheckButtonStyleBar,
    TGCheckButtonStyleMedia,
    TGCheckButtonStyleGallery,
    TGCheckButtonStyleShare,
    TGCheckButtonStyleChat,
    TGCheckButtonStyleCompact
} TGCheckButtonStyle;

@interface TGCheckButtonPallete : NSObject

@property (nonatomic, readonly) UIColor *defaultBackgroundColor;
@property (nonatomic, readonly) UIColor *accentBackgroundColor;
@property (nonatomic, readonly) UIColor *defaultBorderColor;
@property (nonatomic, readonly) UIColor *mediaBorderColor;
@property (nonatomic, readonly) UIColor *chatBorderColor;
@property (nonatomic, readonly) UIColor *checkColor;
@property (nonatomic, readonly) UIColor *blueColor;
@property (nonatomic, readonly) UIColor *barBackgroundColor;

+ (instancetype)palleteWithDefaultBackgroundColor:(UIColor *)defaultBackgroundColor accentBackgroundColor:(UIColor *)accentBackgroundColor defaultBorderColor:(UIColor *)defaultBorderColor mediaBorderColor:(UIColor *)mediaBorderColor chatBorderColor:(UIColor *)chatBorderColor checkColor:(UIColor *)checkColor blueColor:(UIColor *)blueColor barBackgroundColor:(UIColor *)barBackgroundColor;

@end

@interface TGCheckButtonView : UIButton

- (instancetype)initWithStyle:(TGCheckButtonStyle)style;
- (instancetype)initWithStyle:(TGCheckButtonStyle)style pallete:(TGCheckButtonPallete *)pallete;

- (void)setSelected:(bool)selected animated:(bool)animated;
- (void)setSelected:(bool)selected animated:(bool)animated bump:(bool)bump;
- (void)setSelected:(bool)selected animated:(bool)animated bump:(bool)bump completion:(void (^)())completion;

- (void)setNumber:(NSUInteger)number;

+ (void)resetCache;

@end
