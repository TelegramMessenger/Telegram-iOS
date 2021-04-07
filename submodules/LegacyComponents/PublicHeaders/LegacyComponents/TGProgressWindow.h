#import <UIKit/UIKit.h>

#import <LegacyComponents/TGOverlayControllerWindow.h>

@interface TGProgressWindowController : TGOverlayWindowViewController

@property (nonatomic, copy) void (^cancelled)(void);

- (instancetype)init;
- (instancetype)initWithLight:(bool)light;

- (void)show:(bool)animated;
- (void)dismiss:(bool)animated completion:(void (^)(void))completion;
- (void)dismissWithSuccess:(void (^)(void))completion;

- (void)updateLayout;

@end

@interface TGProgressWindow : UIWindow

@property (nonatomic, assign) bool skipMakeKeyWindowOnDismiss;

- (void)show:(bool)animated;
- (void)showWithDelay:(NSTimeInterval)delay;

- (void)showAnimated;
- (void)dismiss:(bool)animated;
- (void)dismissWithSuccess;

+ (void)setDarkStyle:(bool)dark;

@end

