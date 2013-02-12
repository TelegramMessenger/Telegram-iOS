/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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


#import <Foundation/Foundation.h>

#import "BITHockeyBaseManager.h"
#import "BITFeedbackListViewController.h"
#import "BITFeedbackComposeViewController.h"


// Notification message which tells that loading messages finished
#define BITHockeyFeedbackMessagesLoadingStarted @"BITHockeyFeedbackMessagesLoadingStarted"

// Notification message which tells that loading messages finished
#define BITHockeyFeedbackMessagesLoadingFinished @"BITHockeyFeedbackMessagesLoadingFinished"


typedef enum {
  BITFeedbackUserDataElementDontShow = 0, // don't ask for this user data element at all
  BITFeedbackUserDataElementOptional = 1, // the user may provide it, but does not have to
  BITFeedbackUserDataElementRequired = 2 // the user has to provide this to continue
} BITFeedbackUserDataElement;


@class BITFeedbackMessage;


/**
 The feedback module.
 
 This is the HockeySDK module for letting your users to communicate directly with you via
 the app and an integrated user interface. It provides to have a single threaded
 discussion with a user running your app.

 The user interface provides a list view than can be presented modally using
 `[BITFeedbackManager showFeedbackListView]` modally or adding
 `[BITFeedbackManager feedbackListViewController:]` to push onto a navigation stack.
 This list integrates all features to load new messages, write new messages, view message
 and ask the user for additional (optional) data like name and email.
 
 If the user provides the email address, all responses from the server will also be send
 to the user via email and the user is also able to respond directly via email too.
 
 The message list interface also contains options to locally delete single messages
 by swiping over them, or deleting all messages. This will not delete the messages
 on the server though!
 
 It is also integrates actions to invoke the user interface to compose a new messages,
 reload the list content from the server and changing the users name or email if these
 are allowed to be set.
 
 It is also possible to invoke the user interface to compose a new message anywhere in your
 own code, by calling `[BITFeedbackManager showFeedbackComposeView]` modally or adding
 `[BITFeedackManager feedbackComposeViewController]` to push onto a navigation stack.
 
 If new messages are written while the device is offline, the SDK automatically retries to
 send them once the app starts again or gets active again, or if the notification
 `BITHockeyNetworkDidBecomeReachableNotification` is fired.
 
 A third option is to include the `BITFeedbackActivity` into an UIActivityViewController.
 This can be useful if you present some data that users can not only share but also
 report back to the developer because they have some problems, e.g. webcams not working
 any more. The activity provide a default title and image that can be also be customized.

 New message are automatically loaded on startup, when the app becomes active again
 or when the notification `BITHockeyNetworkDidBecomeReachableNotification` is fired. This
 only happens if the user ever did initiate a conversation by writing the first
 feedback message.
 */

@interface BITFeedbackManager : BITHockeyBaseManager <UIAlertViewDelegate>

///-----------------------------------------------------------------------------
/// @name General settings
///-----------------------------------------------------------------------------


/**
 Define if a name has to be provided by the user when providing feedback

 - `BITFeedbackUserDataElementDontShow`: Don't ask for this user data element at all
 - `BITFeedbackUserDataElementOptional`: The user may provide it, but does not have to
 - `BITFeedbackUserDataElementRequired`: The user has to provide this to continue

 The default value is `BITFeedbackUserDataElementOptional`.

 @warning If you provide a non nil value for the `BITFeedbackManager` class via
 `[BITHockeyManagerDelegate userNameForHockeyManager:componentManager:]` then this
 property will automatically be set to `BITFeedbackUserDataElementDontShow`

 @see requireUserEmail
 @see `[BITHockeyManagerDelegate userNameForHockeyManager:componentManager:]`
 */
@property (nonatomic, readwrite) BITFeedbackUserDataElement requireUserName;


/**
 Define if an email address has to be provided by the user when providing feedback
 
 If the user provides the email address, all responses from the server will also be send
 to the user via email and the user is also able to respond directly via email too.

 - `BITFeedbackUserDataElementDontShow`: Don't ask for this user data element at all
 - `BITFeedbackUserDataElementOptional`: The user may provide it, but does not have to
 - `BITFeedbackUserDataElementRequired`: The user has to provide this to continue
 
 The default value is `BITFeedbackUserDataElementOptional`.

 @warning If you provide a non nil value for the `BITFeedbackManager` class via
 `[BITHockeyManagerDelegate userEmailForHockeyManager:componentManager:]` then this
 property will automatically be set to `BITFeedbackUserDataElementDontShow`
 
 @see requireUserName
 @see `[BITHockeyManagerDelegate userEmailForHockeyManager:componentManager:]`
 */
@property (nonatomic, readwrite) BITFeedbackUserDataElement requireUserEmail;


/**
 Indicates if an alert should be shown when new messages arrived
 
 This lets the user to view the new feedback by choosing the appropriate option
 in the alert sheet, and the `BITFeedbackListViewController` will be shown.
 
 The alert is only shown, if the newest message is not originated from the current user.
 This requires the users email address to be present! The optional userid property
 cannot be used, because users could also answer via email and then this information
 is not available.
 
 Default is `YES`
 @see feedbackListViewController:
 @see requireUserEmail
 @see `[BITHockeyManagerDelegate userEmailForHockeyManager:componentManager:]`
 */
@property (nonatomic, readwrite) BOOL showAlertOnIncomingMessages;


///-----------------------------------------------------------------------------
/// @name User Interface
///-----------------------------------------------------------------------------


/**
 Present the modal feedback list user interface.
 */
- (void)showFeedbackListView;


/**
 Create an feedback list view
 
 @param modal Return a view ready for modal presentation with integrated navigation bar
 @return `BITFeedbackListViewController` The feedback list view controller,
 e.g. to push it onto a navigation stack.
 */
- (BITFeedbackListViewController *)feedbackListViewController:(BOOL)modal;


/**
 Present the modal feedback compose message user interface.
 */
- (void)showFeedbackComposeView;


/**
 Create an feedback compose view

 Example to show a modal feedback compose UI with prefilled text
     
     BITFeedbackComposeViewController *feedbackCompose = [[BITHockeyManager sharedHockeyManager].feedbackManager feedbackComposeViewController];
     
     [feedbackCompose prepareWithItems:
         @[@"Adding some example default text and also adding a link.",
         [NSURL URLWithString:@"http://hockeayyp.net/"]]];
 
     UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:feedbackCompose];
     navController.modalPresentationStyle = UIModalPresentationFormSheet;
     [self presentViewController:navController animated:YES completion:nil];

 @return `BITFeedbackComposeViewController` The compose feedback view controller,
 e.g. to push it onto a navigation stack.
 */
- (BITFeedbackComposeViewController *)feedbackComposeViewController;


@end
