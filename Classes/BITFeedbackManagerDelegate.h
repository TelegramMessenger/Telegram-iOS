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

#import <Foundation/Foundation.h>
#import "BITFeedbackComposeViewControllerDelegate.h"

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

@class BITFeedbackManager;

/**
 *	Delegate protocol which is notified about changes in the feedbackManager
 *  @TODO 
 *    * move shouldShowUpdateAlert from feedbackManager here
 */
@protocol BITFeedbackManagerDelegate <NSObject, BITFeedbackComposeViewControllerDelegate>

@optional

/**
 *  Can be implemented to control wether the feedback manager should automatically
 *  fetch for new messages on app startup or when becoming active.
 *
 *  By default the SDK fetches on app startup or when the app is becoming active again
 *  if there are already messages existing or pending on the device.
 *
 *  You could disable it e.g. depending on available mobile network/WLAN connection
 *  or let it fetch less frequently.
 *
 *	@param	feedbackManager	The feedbackManager which did detect the new messages
 */
- (BOOL)allowAutomaticFetchingForNewFeedbackForManager:(BITFeedbackManager *)feedbackManager;


/**
 *	can be implemented to know when new feedback from the server arrived
 *
 *	@param	feedbackManager	The feedbackManager which did detect the new messages
 */
- (void)feedbackManagerDidReceiveNewFeedback:(BITFeedbackManager *)feedbackManager;


/**
 *  This optional method can be implemented to provide items to prefill
 *  the FeedbackComposeMessage user interface with the given items.
 *
 *  If the user sends the feedback message, these items will be attached to that message.
 *
 *  All NSString-Content in the array will be concatenated and result in the message,
 *  while all UIImage and NSData-instances will be turned into attachments.
 *
 *  @param feedbackManager The BITFeedbackManager instance that will handle sending the feedback.
 *
 *  @return An array containing the items to be attached to the feedback message
 *  @see `[BITFeedbackComposeViewController prepareWithItems:]
 */
- (nullable NSArray *)preparedItemsForFeedbackManager:(BITFeedbackManager *)feedbackManager;

@end

NS_ASSUME_NONNULL_END
