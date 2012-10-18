/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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


@interface BITFeedbackManager : BITHockeyBaseManager <UIAlertViewDelegate>

@property (nonatomic, readwrite) BITFeedbackUserDataElement requireUserName; // default is BITFeedbackUserDataElementOptional
@property (nonatomic, readwrite) BITFeedbackUserDataElement requireUserEmail; // default is BITFeedbackUserDataElementOptional
@property (nonatomic, readwrite) BOOL showAlertOnIncomingMessages; // default is YES

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
 
 @return `BITFeedbackComposeViewController` The compose feedback view controller,
 e.g. to push it onto a navigation stack.
 */
- (BITFeedbackComposeViewController *)feedbackComposeViewController;

@end
