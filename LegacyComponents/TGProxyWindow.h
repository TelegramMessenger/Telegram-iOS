#import <UIKit/UIKit.h>

#import <LegacyComponents/TGOverlayControllerWindow.h>

@interface TGProxyWindowController : TGOverlayWindowViewController

- (instancetype)initWithLight:(bool)light;

- (void)dismissWithSuccess:(void (^)(void))completion;
- (void)updateLayout;

@end

@interface TGProxyWindow : UIWindow

- (void)dismissWithSuccess;
+ (void)setDarkStyle:(bool)dark;

@end


