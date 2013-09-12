//
//  BITFeedbackComposeViewControllerDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 15.10.12.
//
//

#import <Foundation/Foundation.h>

/**
 *  The users action when composing a message
 */
typedef NS_ENUM(NSUInteger, BITFeedbackComposeResult) {
  /**
   *  user hit cancel
   */
  BITFeedbackComposeResultCancelled,
  /**
   *  user hit submit
   */
  BITFeedbackComposeResultSubmitted,
};

@class BITFeedbackComposeViewController;

/**
 * The `BITFeedbackComposeViewControllerDelegate` formal protocol defines methods further configuring
 * the behaviour of `BITFeedbackComposeViewController`.
 */

@protocol BITFeedbackComposeViewControllerDelegate <NSObject>

@optional

///-----------------------------------------------------------------------------
/// @name View Controller Management
///-----------------------------------------------------------------------------

/**
 * Invoked once the compose screen is finished via send or cancel
 *
 * If this is implemented, it's the responsibility of this method to dismiss the presented
 * `BITFeedbackComposeViewController`
 *
 * @param composeViewController The `BITFeedbackComposeViewController` instance invoking this delegate
 * @param composeResult The user action the lead to closing the compose view
 */
- (void)feedbackComposeViewController:(BITFeedbackComposeViewController *)composeViewController
                  didFinishWithResult:(BITFeedbackComposeResult) composeResult;

#pragma mark - Deprecated methods

/** 
 * This method is deprecated. If feedbackComposeViewController:didFinishWithResult: is implemented, this will not be called
 *
 * @param composeViewController The `BITFeedbackComposeViewController` instance invoking this delegate
 */
- (void)feedbackComposeViewControllerDidFinish:(BITFeedbackComposeViewController *)composeViewController __attribute__((deprecated("Use feedbackComposeViewController:didFinishWithResult: instead")));
@end
