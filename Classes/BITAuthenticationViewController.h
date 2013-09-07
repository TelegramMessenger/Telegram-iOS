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
@class BITHockeyAppClient;

@interface BITAuthenticationViewController : UITableViewController

- (instancetype) initWithDelegate:(id<BITAuthenticationViewControllerDelegate>) delegate;

/**
 *  can be set to YES to show an additional button + description text
 *  and allowing to login via external website/UDID.
 *  if this is set to yes, no further email/password options are shown
 *
 *  defaults to NO
 */
@property (nonatomic, assign) BOOL showsLoginViaWebButton;

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

@property (nonatomic, weak) id<BITAuthenticationViewControllerDelegate> delegate;

@end

@protocol BITAuthenticationViewControllerDelegate<NSObject>

/**
 *	called then the user cancelled
 *
 *	@param	viewController the delegating viewcontroller
 */
- (void) authenticationViewControllerDidCancel:(UIViewController*) viewController;

- (void) authenticationViewControllerDidTapWebButton:(UIViewController*) viewController;

/**
 *	called when the user wants to login
 *
 *	@param	viewController	the delegating viewcontroller
 *	@param	email	the content of the email-field
 *	@param	password	the content of the password-field (if existent)
 *  @param  completion Must be called by the delegate once the auth-task completed
 *                     This viewcontroller shows an activity-indicator in between and blocks
 *                     the UI. if succeeded is NO, it shows an alertView presenting the error
 *                     given by the completion block
 */
- (void) authenticationViewController:(UIViewController*) viewController
        handleAuthenticationWithEmail:(NSString*) email
                             password:(NSString*) password
                           completion:(void(^)(BOOL succeeded, NSError *error)) completion;

@end
