#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;

@interface TGOverlayFormsheetWindow : UIWindow

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController contentController:(UIViewController *)contentController;

- (void)showAnimated:(bool)animated;
- (void)dismissAnimated:(bool)animated;

@end
