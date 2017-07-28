#import <UIKit/UIKit.h>

#import <LegacyComponents/TGOverlayControllerWindow.h>

@interface TGProgressWindowController : TGOverlayWindowViewController

- (instancetype)init:(bool)light;
- (void)show:(bool)animated;
- (void)dismiss:(bool)animated completion:(void (^)())completion;

@end

@interface TGProgressWindow : UIWindow

@property (nonatomic, assign) bool skipMakeKeyWindowOnDismiss;

- (void)show:(bool)animated;
- (void)showWithDelay:(NSTimeInterval)delay;

- (void)showAnimated;
- (void)dismiss:(bool)animated;
- (void)dismissWithSuccess;

+ (void)changeStyle;

@end

