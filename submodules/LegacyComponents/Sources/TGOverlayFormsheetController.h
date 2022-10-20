#import <UIKit/UIKit.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGOverlayFormsheetWindow;

@interface TGOverlayFormsheetController : UIViewController

@property (nonatomic, weak) TGOverlayFormsheetWindow *formSheetWindow;
@property (nonatomic, readonly) UIViewController *viewController;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context contentController:(UIViewController *)viewController;
- (void)setContentController:(UIViewController *)viewController;

- (void)animateInWithCompletion:(void (^)(void))completion;
- (void)animateOutWithCompletion:(void (^)(void))completion;

@end
