#import <UIKit/UIKit.h>

@interface TGGradientLabel : UIView

@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) NSString *text;
@property (nonatomic) int topColor;
@property (nonatomic) int bottomColor;
@property (nonatomic) UIColor *textColor;

@end
