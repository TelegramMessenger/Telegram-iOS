//
//  STPCard.h
//  Stripe
//
//  Created by Saikat Chakrabarti on 11/2/12.
//
//

#import <Foundation/Foundation.h>

#import "STPCardBrand.h"
#import "STPCardParams.h"
#import "STPAPIResponseDecodable.h"
#import "STPPaymentMethod.h"
#import "STPSource.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The various funding sources for a payment card.
 */
typedef NS_ENUM(NSInteger, STPCardFundingType) {
    STPCardFundingTypeDebit,
    STPCardFundingTypeCredit,
    STPCardFundingTypePrepaid,
    STPCardFundingTypeOther,
};

/**
 *  Representation of a user's credit card details that have been tokenized with the Stripe API. @see https://stripe.com/docs/api#cards
 */
@interface STPCard : STPCardParams<STPAPIResponseDecodable, STPPaymentMethod, STPSource>

/**
 *  Create an STPCard from a Stripe API response.
 *
 *  @param cardID   The Stripe ID of the card, e.g. `card_185iQx4JYtv6MPZKfcuXwkOx`
 *  @param brand    The brand of the card (e.g. "Visa". To obtain this enum value from a string, use `[STPCardBrand brandFromString:string]`;
 *  @param last4    The last 4 digits of the card, e.g. 4242
 *  @param expMonth The card's expiration month, 1-indexed (i.e. 1 = January)
 *  @param expYear  The card's expiration year
 *  @param funding  The card's funding type (credit, debit, or prepaid). To obtain this enum value from a string, use `[STPCardBrand fundingFromString:string]`.
 *
 *  @return an STPCard instance populated with the provided values.
 */
- (instancetype)initWithID:(NSString *)cardID
                     brand:(STPCardBrand)brand
                     last4:(NSString *)last4
                  expMonth:(NSUInteger)expMonth
                   expYear:(NSUInteger)expYear
                   funding:(STPCardFundingType)funding;

/**
 *  This parses a string representing a card's brand into the appropriate STPCardBrand enum value, i.e. `[STPCard brandFromString:@"American Express"] == STPCardBrandAmex`
 *
 *  @param string a string representing the card's brand as returned from the Stripe API
 *
 *  @return an enum value mapped to that string. If the string is unrecognized, returns STPCardBrandUnknown.
 */
+ (STPCardBrand)brandFromString:(NSString *)string;

/**
 *  This parses a string representing a card's funding type into the appropriate `STPCardFundingType` enum value, i.e. `[STPCard fundingFromString:@"prepaid"] == STPCardFundingTypePrepaid`.
 *
 *  @param string a string representing the card's funding type as returned from the Stripe API
 *
 *  @return an enum value mapped to that string. If the string is unrecognized, returns `STPCardFundingTypeOther`.
 */
+ (STPCardFundingType)fundingFromString:(NSString *)string;

/**
 *  The last 4 digits of the card.
 */
@property (nonatomic, readonly) NSString *last4;

/**
 *  For cards made with Apple Pay, this refers to the last 4 digits of the "Device Account Number" for the tokenized card. For regular cards, it will be nil.
 */
@property (nonatomic, readonly, nullable) NSString *dynamicLast4;

/**
 *  Whether or not the card originated from Apple Pay.
 */
@property (nonatomic, readonly) BOOL isApplePayCard;

/**
 *  The card's expiration month. 1-indexed (i.e. 1 == January)
 */
@property (nonatomic) NSUInteger expMonth;

/**
 *  The card's expiration year.
 */
@property (nonatomic) NSUInteger expYear;

/**
 *  The cardholder's name.
 */
@property (nonatomic, copy, nullable) NSString *name;

/**
 *  The cardholder's address.
 */
@property (nonatomic, copy, nullable) NSString *addressLine1;
@property (nonatomic, copy, nullable) NSString *addressLine2;
@property (nonatomic, copy, nullable) NSString *addressCity;
@property (nonatomic, copy, nullable) NSString *addressState;
@property (nonatomic, copy, nullable) NSString *addressZip;
@property (nonatomic, copy, nullable) NSString *addressCountry;

/**
 *  The Stripe ID for the card.
 */
@property (nonatomic, readonly, nullable) NSString *cardId;

/**
 *  The issuer of the card.
 */
@property (nonatomic, readonly) STPCardBrand brand;

/**
 *  The issuer of the card.
 *  Can be one of "Visa", "American Express", "MasterCard", "Discover", "JCB", "Diners Club", or "Unknown"
 *  @deprecated use `brand` instead.
 */
@property (nonatomic, readonly) NSString *type __attribute__((deprecated));

/**
 *  The funding source for the card (credit, debit, prepaid, or other)
 */
@property (nonatomic, readonly) STPCardFundingType funding;

/**
 *  A proxy for the card's number, this uniquely identifies the credit card and can be used to compare different cards.
 *  @deprecated This field will no longer be present in responses when using your publishable key. If you want to access the value of this field, you can look it up on your backend using your secret key.
 */
@property (nonatomic, readonly, nullable) NSString *fingerprint __attribute__((deprecated("This field will no longer be present in responses when using your publishable key. If you want to access the value of this field, you can look it up on your backend using your secret key.")));

/**
 *  Two-letter ISO code representing the issuing country of the card.
 */
@property (nonatomic, readonly, nullable) NSString *country;

/**
 *  This is only applicable when tokenizing debit cards to issue payouts to managed accounts. You should not set it otherwise. The card can then be used as a transfer destination for funds in this currency.
 */
@property (nonatomic, copy, nullable) NSString *currency;

#pragma mark - deprecated properties

#define DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS __attribute__((deprecated("For collecting your users' credit card details, you should use an STPCardParams object instead of an STPCard.")))

@property (nonatomic, copy, nullable) NSString *number DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
@property (nonatomic, copy, nullable) NSString *cvc DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setExpMonth:(NSUInteger)expMonth DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setExpYear:(NSUInteger)expYear DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setName:(nullable NSString *)name DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setAddressLine1:(nullable NSString *)addressLine1 DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setAddressLine2:(nullable NSString *)addressLine2 DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setAddressCity:(nullable NSString *)addressCity DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setAddressState:(nullable NSString *)addressState DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setAddressZip:(nullable NSString *)addressZip DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;
- (void)setAddressCountry:(nullable NSString *)addressCountry DEPRECATED_IN_FAVOR_OF_STPCARDPARAMS;


@end

NS_ASSUME_NONNULL_END
