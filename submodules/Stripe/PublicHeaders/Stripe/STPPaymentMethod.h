//
//  STPPaymentMethod.h
//  Stripe
//
//  Created by Ben Guo on 4/19/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 *  This represents all of the payment methods available to your user (in addition to card payments, which are always enabled) when configuring an `STPPaymentContext`.
 */
typedef NS_OPTIONS(NSUInteger, STPPaymentMethodType) {
    
    /**
     *  Don't use any payment methods except for cards.
     */
    STPPaymentMethodTypeNone = 0,
    
    /**
     *  The user is allowed to pay with Apple Pay (if it's configured and available on their device).
     */
    STPPaymentMethodTypeApplePay = 1 << 0,
    /**
     *  The user can use any available payment method to pay.
     */
    STPPaymentMethodTypeAll = STPPaymentMethodTypeApplePay
};

/**
 *  This protocol represents a payment method that a user can select and use to pay. Currently the only classes that conform to it are `STPCard` (which represents that the user wants to pay with a specific card) and `STPApplePayPaymentMethod` (which represents that the user wants to pay with Apple Pay).
 */
@protocol STPPaymentMethod <NSObject>

/**
 *  A small (32 x 20 points) logo image representing the payment method. For example, the Visa logo for a Visa card, or the Apple Pay logo.
 */
@property (nonatomic, readonly) UIImage *image;

/**
 *  A small (32 x 20 points) logo image representing the payment method that can be used as template for tinted icons. 
 */
@property (nonatomic, readonly) UIImage *templateImage;

/**
 *  A string describing the payment method, such as "Apple Pay" or "Visa 4242".
 */
@property (nonatomic, readonly) NSString *label;

@end
