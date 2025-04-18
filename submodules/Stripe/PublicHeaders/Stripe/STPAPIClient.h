//
//  STPAPIClient.h
//  StripeExample
//
//  Created by Jack Flintermann on 12/18/14.
//  Copyright (c) 2014 Stripe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <Stripe/STPBlocks.h>
#import <Stripe/STPCardBrand.h>

NS_ASSUME_NONNULL_BEGIN

#define FAUXPAS_IGNORED_ON_LINE(...)
#define FAUXPAS_IGNORED_IN_FILE(...)
FAUXPAS_IGNORED_IN_FILE(APIAvailability)

static NSString *const STPSDKVersion = @"9.1.0";

@class STPBankAccount, STPBankAccountParams, STPCard, STPCardParams, STPToken, STPPaymentConfiguration;

/**
 A top-level class that imports the rest of the Stripe SDK. This class used to contain several methods to create Stripe tokens, but those are now deprecated in
 favor of STPAPIClient.
 */
@interface Stripe : NSObject FAUXPAS_IGNORED_ON_LINE(UnprefixedClass);

/**
 *  Set your Stripe API key with this method. New instances of STPAPIClient will be initialized with this value. You should call this method as early as
 *  possible in your application's lifecycle, preferably in your AppDelegate.
 *
 *  @param   publishableKey Your publishable key, obtained from https://stripe.com/account/apikeys
 *  @warning Make sure not to ship your test API keys to the App Store! This will log a warning if you use your test key in a release build.
 */
+ (void)setDefaultPublishableKey:(NSString *)publishableKey;

/// The current default publishable key.
+ (nullable NSString *)defaultPublishableKey;

/**
 *  By default, Stripe collects some basic information about SDK usage.
 *  You can call this method to turn off analytics collection.
 */
+ (void)disableAnalytics;

@end

/// A client for making connections to the Stripe API.
@interface STPAPIClient : NSObject

+ (NSString *)stringWithCardBrand:(STPCardBrand)brand;

/**
 *  A shared singleton API client. Its API key will be initially equal to [Stripe defaultPublishableKey].
 */
+ (instancetype)sharedClient;
- (instancetype)initWithConfiguration:(STPPaymentConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithPublishableKey:(NSString *)publishableKey;

/**
 *  @see [Stripe setDefaultPublishableKey:]
 */
@property (nonatomic, copy, nullable) NSString *publishableKey;

/**
 *  @see -initWithConfiguration
 */
@property (nonatomic, copy) STPPaymentConfiguration *configuration;

- (void)createTokenWithCard:(STPCardParams *)card completion:(nullable STPTokenCompletionBlock)completion;

@end

#pragma mark Bank Accounts

/**
 *  STPAPIClient extensions to create Stripe tokens from bank accounts.
 */
@interface STPAPIClient (BankAccounts)

/**
 *  Converts an STPBankAccount object into a Stripe token using the Stripe API.
 *
 *  @param bankAccount The user's bank account details. Cannot be nil. @see https://stripe.com/docs/api#create_bank_account_token
 *  @param completion  The callback to run with the returned Stripe token (and any errors that may have occurred).
 */
- (void)createTokenWithBankAccount:(STPBankAccountParams *)bankAccount completion:(__nullable STPTokenCompletionBlock)completion;

@end

#pragma mark Credit Cards

/**
 *  STPAPIClient extensions to create Stripe tokens from credit or debit cards.
 */
@interface STPAPIClient (CreditCards)

/**
 *  Converts an STPCardParams object into a Stripe token using the Stripe API.
 *
 *  @param card        The user's card details. Cannot be nil. @see https://stripe.com/docs/api#create_card_token
 *  @param completion  The callback to run with the returned Stripe token (and any errors that may have occurred).
 */


@end

/**
 *  Convenience methods for working with Apple Pay.
 */
@interface Stripe(ApplePay)

/**
 *  Whether or not this device is capable of using Apple Pay. This checks both whether the user is running an iPhone 6/6+ or later, iPad Air 2 or later, or iPad
 *mini 3 or later, as well as whether or not they have stored any cards in Apple Pay on their device.
 *
 *  @param paymentRequest The return value of this method depends on the `supportedNetworks` property of this payment request, which by default should be
 *`@[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa, PKPaymentNetworkDiscover]`.
 *
 *  @return whether or not the user is currently able to pay with Apple Pay.
 */
+ (BOOL)canSubmitPaymentRequest:(PKPaymentRequest *)paymentRequest NS_AVAILABLE_IOS(8_0);

+ (BOOL)deviceSupportsApplePay;

/**
 *  A convenience method to return a `PKPaymentRequest` with sane default values. You will still need to configure the `paymentSummaryItems` property to indicate
 *what the user is purchasing, as well as the optional `requiredShippingAddressFields`, `requiredBillingAddressFields`, and `shippingMethods` properties to indicate
 *what contact information your application requires.
 *
 *  @param merchantIdentifier Your Apple Merchant ID, as obtained at https://developer.apple.com/account/ios/identifiers/merchant/merchantCreate.action
 *
 *  @return a `PKPaymentRequest` with proper default values. Returns nil if running on < iOS8.
 */
+ (PKPaymentRequest *)paymentRequestWithMerchantIdentifier:(NSString *)merchantIdentifier NS_AVAILABLE_IOS(8_0);

+ (void)createTokenWithPayment:(PKPayment *)payment
                    completion:(STPTokenCompletionBlock)handler __attribute__((deprecated("Use STPAPIClient instead.")));

@end

#pragma mark - Deprecated Methods

/**
 *  A callback to be run with a token response from the Stripe API.
 *
 *  @param token The Stripe token from the response. Will be nil if an error occurs. @see STPToken
 *  @param error The error returned from the response, or nil in one occurs. @see StripeError.h for possible values.
 *  @deprecated This has been renamed to STPTokenCompletionBlock.
 */
typedef void (^STPCompletionBlock)(STPToken * __nullable token, NSError * __nullable error) __attribute__((deprecated("STPCompletionBlock has been renamed to STPTokenCompletionBlock.")));

// These methods are deprecated. You should instead use STPAPIClient to create tokens.
// Example: [Stripe createTokenWithCard:card completion:completion];
// becomes [[STPAPIClient sharedClient] createTokenWithCard:card completion:completion];
@interface Stripe (Deprecated)

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param card    The user's card details. @see STPCard
 *  @param handler Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated    Use STPAPIClient instead.
 */
+ (void)createTokenWithCard:(STPCard *)card completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue.
 *
 *  @param card           The user's card details. @see STPCard
 *  @param publishableKey The API key to use to authenticate with Stripe. Get this at https://stripe.com/account/apikeys .
 *  @param handler        Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated           Use STPAPIClient instead.
 */
+ (void)createTokenWithCard:(STPCard *)card publishableKey:(NSString *)publishableKey completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param bankAccount The user's bank account details. @see STPBankAccount
 *  @param handler     Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated        Use STPAPIClient instead.
 */
+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param bankAccount    The user's bank account details. @see STPBankAccount
 *  @param publishableKey The API key to use to authenticate with Stripe. Get this at https://stripe.com/account/apikeys .
 *  @param handler        Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated           Use STPAPIClient instead.
 */
+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount
                    publishableKey:(NSString *)publishableKey
                        completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

+ (BOOL)deviceSupportsApplePay;

@end

NS_ASSUME_NONNULL_END
