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


typedef enum {
  BITFeedbackUserDataElementDontShow = 0, // don't ask for this user data element at all
  BITFeedbackUserDataElementOptional = 1, // the user may provide it, but does not have to
  BITFeedbackUserDataElementRequired = 2 // the user has to provide this to continue
} BITFeedbackUserDataElement;


@class BITFeedbackMessage;
@protocol BITFeedbackManagerDelegate;


@interface BITFeedbackManager : BITHockeyBaseManager <UIAlertViewDelegate>

@property (nonatomic, retain) BITFeedbackListViewController *currentFeedbackListViewController;
@property (nonatomic, retain) BITFeedbackComposeViewController *currentFeedbackComposeViewController;
@property (nonatomic) BOOL didAskUserData;

@property (nonatomic, retain) NSDate *lastCheck;

@property (nonatomic, readwrite) BITFeedbackUserDataElement requireUserName; // default is BITFeedbackUserDataRequired
@property (nonatomic, readwrite) BITFeedbackUserDataElement requireUserEmail; // default is BITFeedbackUserDataRequired
@property (nonatomic, readwrite) BOOL showAlertOnIncomingMessages; // default is YES

@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *userEmail;


// convenience methode to create feedback view controller
- (BITFeedbackListViewController *)feedbackListViewController:(BOOL)modal;

// load new messages from the server
- (void)updateMessagesList;

// open feedback list view
- (void)showFeedbackListView;

// open feedback compose view
- (void)showFeedbackComposeView;

- (NSUInteger)numberOfMessages;
- (BITFeedbackMessage *)messageAtIndex:(NSUInteger)index;

- (void)submitMessageWithText:(NSString *)text;
- (void)submitPendingMessages;

// Returns YES if manual user data can be entered, required or optional
- (BOOL)askManualUserDataAvailable;

// Returns YES if required user data is missing?
- (BOOL)requireManualUserDataMissing;

// Returns YES if user data is available and can be edited
- (BOOL)isManualUserDataAvailable;

// used in the user data screen
- (void)updateDidAskUserData;

@end
