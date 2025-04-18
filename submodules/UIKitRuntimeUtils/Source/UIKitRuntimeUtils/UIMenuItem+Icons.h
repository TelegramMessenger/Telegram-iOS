#import <UIKit/UIKit.h>

@interface UIMenuItem (Icons)

- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon action:(SEL)action;

@end

@interface UILabel (DateLabel)

+ (void)setDateLabelColor:(UIColor *)color;

@end
