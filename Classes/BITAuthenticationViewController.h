//
//  BITAuthenticationViewController.h
//  HockeySDK
//
//  Created by Stephan Diederich on 08.08.13.
//
//

#import <UIKit/UIKit.h>
@protocol BITAuthenticationViewControllerDelegate;
@class BITAuthenticator;

@interface BITAuthenticationViewController : UITableViewController

/**
 *	can be set to YES to also require the users password
 *
 *  defaults to NO
 */
@property (nonatomic, assign) BOOL requirePassword;

/** configure if user can abort authentication or not
 *
 *  defaults to YES
 */
@property (nonatomic, assign) BOOL showsCancelButton;
/**
 *	TODO: instead of passing the whole authenticator, we actually only need
 *        something to create and enqueue BITHTTPOperations
 */
@property (nonatomic, weak) BITAuthenticator *authenticator;

@property (nonatomic, weak) id<BITAuthenticationViewControllerDelegate> delegate;

@end

@protocol BITAuthenticationViewControllerDelegate<NSObject>

- (void) authenticationViewControllerDidCancel:(UIViewController*) viewController;
- (void) authenticationViewController:(UIViewController*) viewController authenticatedWithToken:(NSString*) token;

@end
