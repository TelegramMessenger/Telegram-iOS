//
//  STPToken.h
//  Stripe
//
//  Created by Saikat Chakrabarti on 11/5/12.
//
//

#import <Foundation/Foundation.h>
#import <Stripe/STPAPIResponseDecodable.h>
#import <Stripe/STPSource.h>

@class STPCard;
@class STPBankAccount;

/**
 *  A token returned from submitting payment details to the Stripe API. You should not have to instantiate one of these directly.
 */
@interface STPToken : NSObject<STPAPIResponseDecodable, STPSource>

/**
 *  You cannot directly instantiate an `STPToken`. You should only use one that has been returned from an `STPAPIClient` callback.
 */
- (nonnull instancetype) init;

/**
 *  The value of the token. You can store this value on your server and use it to make charges and customers. @see
 * https://stripe.com/docs/mobile/ios#sending-tokens
 */
@property (nonatomic, readonly, nonnull) NSString *tokenId;

/**
 *  Whether or not this token was created in livemode. Will be YES if you used your Live Publishable Key, and NO if you used your Test Publishable Key.
 */
@property (nonatomic, readonly) BOOL livemode;

/**
 *  The credit card details that were used to create the token. Will only be set if the token was created via a credit card or Apple Pay, otherwise it will be
 * nil.
 */
@property (nonatomic, readonly, nullable) STPCard *card;

/**
 *  The bank account details that were used to create the token. Will only be set if the token was created with a bank account, otherwise it will be nil.
 */
@property (nonatomic, readonly, nullable) STPBankAccount *bankAccount;

/**
 *  When the token was created.
 */
@property (nonatomic, readonly, nullable) NSDate *created;

@end
