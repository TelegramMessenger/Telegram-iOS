#import <UIKit/UIKit.h>

@interface ProxyWindowController : UIViewController

- (instancetype)initWithLight:(bool)light text:(NSString *)text icon:(UIImage *)icon isShield:(bool)isShield showCheck:(bool)showCheck;

- (void)dismissWithSuccess:(void (^)(void))completion increasedDelay:(bool)increasedDelay;
- (void)updateLayout;

+ (UIImage *)generateShieldImage:(bool)isLight;

@end
