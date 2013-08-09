//
//  BITAuthenticationViewController.h
//  HockeySDK
//
//  Created by Stephan Diederich on 08.08.13.
//
//

#import <UIKit/UIKit.h>
@protocol BITAuthenticationViewControllerDelegate;

@interface BITAuthenticationViewController : UIViewController

@end

@protocol BITAuthenticationViewControllerDelegate<NSObject>

- (void) authenticationViewControllerDidCancel:(UIViewController*) viewController;
- (void) authenticationViewController:(UIViewController*) viewController authenticatedWithToken:(NSString*) token;

@end
