//
//  BITFeedbackComposeViewControllerDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 15.10.12.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BITFeedbackComposeResult) {
  BITFeedbackComposeResultCancelled, //user hit cancel
  BITFeedbackComposeResultSubmitted, //user hit submit
};

@class BITFeedbackComposeViewController;

/**
 The `BITFeedbackComposeViewControllerDelegate` formal protocol defines methods further configuring
 the behaviour of `BITFeedbackComposeViewController`.
 */

@protocol BITFeedbackComposeViewControllerDelegate <NSObject>

@optional

///-----------------------------------------------------------------------------
/// @name View Controller Management
///-----------------------------------------------------------------------------

/**
 Invoked once the compose screen is finished via send or cancel
 
 If this is implemented, it's the responsibility of this method to dismiss the presented
 `BITFeedbackComposeViewController`
 
 @param composeViewController The `BITFeedbackComposeViewController` instance invoking this delegate
 */
- (void)feedbackComposeViewController:(BITFeedbackComposeViewController *)composeViewController
                  didFinishWithResult:(BITFeedbackComposeResult) composeResult;

#pragma mark - Deprecated methods

/** this method is deprecated. If feedbackComposeViewController:didFinishWithResult: is implemented, this will not be called */
- (void)feedbackComposeViewControllerDidFinish:(BITFeedbackComposeViewController *)composeViewController __attribute__((deprecated("Use feedbackComposeViewController:didFinishWithResult: instead")));
@end
