//
//  STPCardValidationState.h
//  Stripe
//
//  Created by Jack Flintermann on 8/7/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  These fields indicate whether a card field represents a valid value, invalid value, or incomplete value.
 */
typedef NS_ENUM(NSInteger, STPCardValidationState) {
    STPCardValidationStateValid, // The field's contents are valid. For example, a valid, 16-digit card number.
    STPCardValidationStateInvalid, // The field's contents are invalid. For example, an expiration date of "13/42".
    STPCardValidationStateIncomplete, // The field's contents are not yet valid, but could be by typing additional characters. For example, a CVC of "1".
};
