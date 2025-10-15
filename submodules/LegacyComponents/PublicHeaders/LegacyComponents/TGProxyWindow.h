#import <UIKit/UIKit.h>

#import <LegacyComponents/TGOverlayControllerWindow.h>

@interface TGProxyWindowController : TGOverlayWindowViewController

- (instancetype)initWithLight:(bool)light text:(NSString *)text shield:(bool)shield star:(bool)star;

- (void)dismissWithSuccess:(void (^)(void))completion increasedDelay:(bool)increasedDelay;
- (void)updateLayout;

@end

@interface TGProxyWindow : UIWindow

- (void)dismissWithSuccess;
+ (void)setDarkStyle:(bool)dark;

@end


