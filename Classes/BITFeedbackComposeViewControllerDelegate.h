//
//  BITFeedbackComposeViewControllerDelegate.h
//  HockeySDK
//
//  Created by Andreas Linde on 15.10.12.
//
//

#import <Foundation/Foundation.h>

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
- (void)feedbackComposeViewControllerDidFinish:(BITFeedbackComposeViewController *)composeViewController;

@end
