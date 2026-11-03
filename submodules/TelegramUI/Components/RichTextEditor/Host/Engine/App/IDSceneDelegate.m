#import "IDSceneDelegate.h"

#import "IDDemoViewController.h"

@implementation IDSceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
             options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:UIWindowScene.class]) {
        return;
    }

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    window.rootViewController = [[UINavigationController alloc]
        initWithRootViewController:[IDDemoViewController new]];
    self.window = window;
    [window makeKeyAndVisible];
}

@end
