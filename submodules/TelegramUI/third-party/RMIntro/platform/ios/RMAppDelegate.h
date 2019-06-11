//
//  RMAppDelegate.h
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 19/01/14.
//
//

#import <UIKit/UIKit.h>
#import "RMIntroViewController.h"
#import "RMRootViewController.h"

@interface RMAppDelegate : UIResponder <UIApplicationDelegate>
{
    RMRootViewController *_rootVC;
}
@property (strong, nonatomic) UIWindow *window;
//@property (nonatomic) RMTestView *iconView;
@end
