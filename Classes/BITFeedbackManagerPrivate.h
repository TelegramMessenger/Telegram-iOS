/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
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

#if HOCKEYSDK_FEATURE_FEEDBACK

extern NSString *const kBITFeedbackUpdateAttachmentThumbnail;

#import "BITFeedbackMessage.h"

@interface BITFeedbackManager () <UIAlertViewDelegate> {
}


///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the `BITFeedbackManagerDelegate` delegate.
 
 Can be set to be notified when new feedback is received from the server.
 
 The delegate is automatically set by using `[BITHockeyManager setDelegate:]`. You
 should not need to set this delegate individually.
 
 @see `[BITHockeyManager setDelegate:]`
 */
@property (nonatomic, weak) id<BITFeedbackManagerDelegate> delegate;


@property (nonatomic, strong) NSMutableArray *feedbackList;
@property (nonatomic, strong) NSString *token;


// used by BITHockeyManager if disable status is changed
@property (nonatomic, getter = isFeedbackManagerDisabled) BOOL disableFeedbackManager;

@property (nonatomic, strong) BITFeedbackListViewController *currentFeedbackListViewController;
@property (nonatomic, strong) BITFeedbackComposeViewController *currentFeedbackComposeViewController;
@property (nonatomic) BOOL didAskUserData;

@property (nonatomic, strong) NSDate *lastCheck;

@property (nonatomic, strong) NSNumber *lastMessageID;

@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *userEmail;


// Fetch user meta data
- (BOOL)updateUserIDUsingKeychainAndDelegate;
- (BOOL)updateUserNameUsingKeychainAndDelegate;
- (BOOL)updateUserEmailUsingKeychainAndDelegate;

// load new messages from the server
- (void)updateMessagesList;

// load new messages from the server if the last request is too long ago
- (void)updateMessagesListIfRequired;

- (NSUInteger)numberOfMessages;
- (BITFeedbackMessage *)messageAtIndex:(NSUInteger)index;

- (void)submitMessageWithText:(NSString *)text andAttachments:(NSArray *)photos;
- (void)submitPendingMessages;

// Returns YES if manual user data can be entered, required or optional
- (BOOL)askManualUserDataAvailable;

// Returns YES if required user data is missing?
- (BOOL)requireManualUserDataMissing;

// Returns YES if user data is available and can be edited
- (BOOL)isManualUserDataAvailable;

// used in the user data screen
- (void)updateDidAskUserData;


- (BITFeedbackMessage *)messageWithID:(NSNumber *)messageID;

- (NSArray *)messagesWithStatus:(BITFeedbackMessageStatus)status;

- (void)saveMessages;

- (void)fetchMessageUpdates;
- (void)updateMessageListFromResponse:(NSDictionary *)jsonDictionary;

- (BOOL)deleteMessageAtIndex:(NSUInteger)index;
- (void)deleteAllMessages;

@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
