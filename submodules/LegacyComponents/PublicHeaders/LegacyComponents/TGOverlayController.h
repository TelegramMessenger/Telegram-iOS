#import <LegacyComponents/TGViewController.h>

@class TGOverlayControllerWindow;

@interface TGOverlayController : TGViewController

@property (nonatomic, weak) TGOverlayControllerWindow *overlayWindow;
@property (nonatomic, assign) bool isImportant;
@property (nonatomic, copy) void (^customDismissBlock)();

- (void)dismiss;

@end
