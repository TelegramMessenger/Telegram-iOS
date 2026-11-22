#import <UIKit/UIKit.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGOverlayController;

@interface TGOverlayWindowViewController : UIViewController

@property (nonatomic, assign) bool forceStatusBarHidden;
@property (nonatomic) bool isImportant;

@end

@interface TGOverlayControllerWindow : UIWindow

@property (nonatomic) bool keepKeyboard;
@property (nonatomic) bool dismissByMenuSheet;


- (instancetype)initWithManager:(id<LegacyComponentsOverlayWindowManager>)manager parentController:(TGViewController *)parentController contentController:(TGOverlayController *)contentController;
- (instancetype)initWithManager:(id<LegacyComponentsOverlayWindowManager>)manager parentController:(TGViewController *)parentController contentController:(TGOverlayController *)contentController keepKeyboard:(bool)keepKeyboard;

- (void)dismiss;

@end
