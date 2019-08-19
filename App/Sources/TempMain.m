#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
//#import <MtProtoKit/MTProto.h>

@interface AppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    _window.rootViewController = [[UIViewController alloc] init];
    _window.rootViewController.view.backgroundColor = [UIColor blueColor];
    [_window makeKeyAndVisible];
    return true;
}

@end

int main(int argc, const char **argv) {
	//MTProto *mtProto = [[MTProto alloc] init];
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

