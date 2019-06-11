//
//  STPBankAccountParams.h
//  Stripe
//
//  Created by Jack Flintermann on 10/4/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STPFormEncodable.h"

typedef NS_ENUM(NSInteger, STPBankAccountHolderType) {
    STPBankAccountHolderTypeIndividual,
    STPBankAccountHolderTypeCompany,
};

/**
 *  Representation of a user's bank account details. You can assemble these with information that your user enters and
 *  then create Stripe tokens with them using an STPAPIClient. @see https://stripe.com/docs/api#create_bank_account_token
 */
@interface STPBankAccountParams : NSObject<STPFormEncodable>

/**
 *  The account number for the bank account. Currently must be a checking account.
 */
@property (nonatomic, copy, nullable) NSString *accountNumber;

/**
 *  The last 4 digits of the bank account's account number, if it's been set, otherwise nil.
 */
- (nullable NSString *)last4;

/**
 *  The routing number for the bank account. This should be the ACH routing number, not the wire routing number.
 */
@property (nonatomic, copy, nullable) NSString *routingNumber;

/**
 *  Two-letter ISO code representing the country the bank account is located in.
 */
@property (nonatomic, copy, nullable) NSString *country;

/**
 *  The default currency for the bank account.
 */
@property (nonatomic, copy, nullable) NSString *currency;

/**
 *  The name of the person or business that owns the bank account.
 */
@property(nonatomic, copy, nullable) NSString *accountHolderName;

/**
 *  The type of entity that holds the account. Defaults to STPBankAccountHolderTypeIndividual.
 */
@property(nonatomic) STPBankAccountHolderType accountHolderType;

@end
