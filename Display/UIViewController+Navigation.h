#import <UIKit/UIKit.h>

@interface UIViewController (Navigation)

- (void)setIgnoreAppearanceMethodInvocations:(BOOL)ignoreAppearanceMethodInvocations;
- (BOOL)ignoreAppearanceMethodInvocations;
- (void)navigation_setNavigationController:(UINavigationController * _Nullable)navigationControlller;
- (void)navigation_setPresentingViewController:(UIViewController * _Nullable)presentingViewController;
- (void)navigation_setDismiss:(void (^_Nullable)())dismiss rootController:( UIViewController * _Nullable )rootController;
- (void)state_setNeedsStatusBarAppearanceUpdate:(void (^_Nullable)())block;

@end

@interface UIView (Navigation)

@property (nonatomic) bool disablesInteractiveTransitionGestureRecognizer;
@property (nonatomic) bool disablesAutomaticKeyboardHandling;

- (void)input_setInputAccessoryHeightProvider:(CGFloat (^_Nullable)())block;
- (CGFloat)input_getInputAccessoryHeight;

@end

void applyKeyboardAutocorrection();
