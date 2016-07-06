#import <UIKit/UIKit.h>

@interface UIViewController (Navigation)

- (void)setIgnoreAppearanceMethodInvocations:(BOOL)ignoreAppearanceMethodInvocations;
- (void)navigation_setNavigationController:(UINavigationController * _Nullable)navigationControlller;
- (void)navigation_setPresentingViewController:(UIViewController * _Nullable)presentingViewController;
- (void)navigation_setDismiss:(void (^_Nullable)())dismiss;

@end

void applyKeyboardAutocorrection();
