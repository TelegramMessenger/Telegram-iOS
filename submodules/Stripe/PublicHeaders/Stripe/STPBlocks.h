//
//  STPBlocks.h
//  Stripe
//
//  Created by Jack Flintermann on 3/23/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STPToken;

/**
 *  An enum representing the status of a payment requested from the user.
 */
typedef NS_ENUM(NSUInteger, STPPaymentStatus) {
    /**
     *  The payment succeeded.
     */
    STPPaymentStatusSuccess,
    /**
     *  The payment failed due to an unforeseen error, such as the user's Internet connection being offline.
     */
    STPPaymentStatusError,
    /**
     *  The user cancelled the payment (for example, by hitting "cancel" in the Apple Pay dialog).
     */
    STPPaymentStatusUserCancellation,
};

/**
 *  An empty block, called with no arguments, returning nothing.
 */
typedef void (^STPVoidBlock)();

/**
 *  A block that may optionally be called with an error.
 *
 *  @param error The error that occurred, if any.
 */
typedef void (^STPErrorBlock)(NSError * __nullable error);

/**
 *  A callback to be run with a token response from the Stripe API.
 *
 *  @param token The Stripe token from the response. Will be nil if an error occurs. @see STPToken
 *  @param error The error returned from the response, or nil in one occurs. @see StripeError.h for possible values.
 */
typedef void (^STPTokenCompletionBlock)(STPToken * __nullable token, NSError * __nullable error);
