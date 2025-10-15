#import <LegacyComponents/TGOverlayController.h>

#import <LegacyComponents/TGOverlayControllerWindow.h>

@interface TGOverlayController ()

@end

@implementation TGOverlayController

- (id)init
{
    self = [super init];
    if (self != nil)
    {
    }
    return self;
}

- (void)dismiss
{
    TGOverlayControllerWindow *overlayWindow = _overlayWindow;
    [overlayWindow dismiss];
    
    if (_customDismissBlock) {
        _customDismissBlock();
    }
}

@end
