#import "StatusBarUtils.h"

@implementation StatusBarUtils

+ (UIView *)statusBarWindow {
    UIWindow *window = [[UIApplication sharedApplication] valueForKey:@"statusBarWindow"];
    return window;
    //UIView *view = window.subviews.firstObject;
    //return view;
}

+ (UIView *)statusBar {
    UIWindow *window = [[UIApplication sharedApplication] valueForKey:@"statusBarWindow"];
    UIView *view = window.subviews.firstObject;
    
    static Class foregroundClass = nil;
    static Class batteryClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        foregroundClass = NSClassFromString(@"UIStatusBarForegroundView");
        batteryClass = NSClassFromString(@"UIStatusBarBatteryItemView");
    });
    
    for (UIView *foreground in view.subviews) {
        if ([foreground isKindOfClass:foregroundClass]) {
            return foreground;
        }
    }
    
    return nil;
}

@end
