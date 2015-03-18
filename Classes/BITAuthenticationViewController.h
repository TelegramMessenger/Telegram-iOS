/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <UIKit/UIKit.h>
@protocol BITAuthenticationViewControllerDelegate;
@class BITAuthenticator;
@class BITHockeyAppClient;

/**
 *  View controller handling user interaction for `BITAuthenticator`
 */
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
 *  Description shown on top of view. Should tell why this view 
 *  was presented and what's next.
 */
@property (nonatomic, copy) NSString* tableViewTitle;

/**
 *	can be set to YES to also require the users password
 *
 *  defaults to NO
 */
@property (nonatomic, assign) BOOL requirePassword;

@property (nonatomic, weak) id<BITAuthenticationViewControllerDelegate> delegate;

/**
 *  allows to pre-fill the email-addy
 */
@property (nonatomic, copy) NSString* email;
@end

/**
 *  BITAuthenticationViewController protocol
 */
@protocol BITAuthenticationViewControllerDelegate<NSObject>

- (void) authenticationViewControllerDidTapWebButton:(UIViewController*) viewController;

/**
 *	called when the user wants to login
 *
 *	@param	viewController	the delegating view controller
 *	@param	email	the content of the email-field
 *	@param	password	the content of the password-field (if existent)
 *  @param  completion Must be called by the delegate once the auth-task completed
 *                     This view controller shows an activity-indicator in between and blocks
 *                     the UI. if succeeded is NO, it shows an alertView presenting the error
 *                     given by the completion block
 */
- (void) authenticationViewController:(UIViewController*) viewController
        handleAuthenticationWithEmail:(NSString*) email
                             password:(NSString*) password
                           completion:(void(^)(BOOL succeeded, NSError *error)) completion;

@end
