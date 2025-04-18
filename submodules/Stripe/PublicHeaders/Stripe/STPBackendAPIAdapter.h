//
//  STPBackendAPIAdapter.h
//  Stripe
//
//  Created by Jack Flintermann on 1/12/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Stripe/STPAddress.h>
#import <Stripe/STPBlocks.h>
#import <Stripe/STPSource.h>
#import <Stripe/STPCustomer.h>

NS_ASSUME_NONNULL_BEGIN

@class STPCard, STPToken;

/**
 *  Call this block after you're done fetching a customer on your server. You can use the `STPCustomerDeserializer` class to convert a JSON response into an `STPCustomer` object.
 *
 *  @param customer     a deserialized `STPCustomer` object obtained from your backend API, or nil if an error occurred.
 *  @param error        any error that occurred while communicating with your server, or nil if your call succeeded
 */
typedef void (^STPCustomerCompletionBlock)(STPCustomer * __nullable customer, NSError * __nullable error);

/**
 *  You should make your application's API client conform to this interface in order to use it with an `STPPaymentContext`. It provides a "bridge" from the prebuilt UI we expose (such as `STPPaymentMethodsViewController`) to your backend to fetch the information it needs to power those views. To read about how to implement this protocol, see https://stripe.com/docs/mobile/ios#prepare-your-api . To see examples of implementing these APIs, see MyAPIClient.swift in our example project and https://github.com/stripe/example-ios-backend .
 */
@protocol STPBackendAPIAdapter<NSObject>

/**
 *  Retrieve the cards to be displayed inside a payment context. On your backend, retrieve the Stripe customer associated with your currently logged-in user (see https://stripe.com/docs/api#retrieve_customer ), and return the raw JSON response from the Stripe API. (For an example Ruby implementation of this API, see https://github.com/stripe/example-ios-backend/blob/master/web.rb#L40 ). Back in your iOS app, after you've called this API, deserialize your API response into an `STPCustomer` object (you can use the `STPCustomerDeserializer` class to do this). See MyAPIClient.swift in our example project to see this in action.
 *
 *  @see STPCard
 *  @param completion call this callback when you're done fetching and parsing the above information from your backend. For example, `completion(customer, nil)` (if your call succeeds) or `completion(nil, error)` if an error is returned.
 *
 *  @note If you are on Swift 3, you must declare the completion block as `@escaping` or Xcode will give you a protocol conformance error. https://bugs.swift.org/browse/SR-2597
 */
- (void)retrieveCustomer:(STPCustomerCompletionBlock)completion;

/**
 *  Adds a payment source to a customer. On your backend, retrieve the Stripe customer associated with your logged-in user. Then, call the Update Customer method on that customer as described at https://stripe.com/docs/api#update_customer (for an example Ruby implementation of this API, see https://github.com/stripe/example-ios-backend/blob/master/web.rb#L60 ). If this API call succeeds, call `completion(nil)`. Otherwise, call `completion(error)` with the error that occurred.
 *
 *  @param source     a valid payment source, such as a card token.
 *  @param completion call this callback when you're done adding the token to the customer on your backend. For example, `completion(nil)` (if your call succeeds) or `completion(error)` if an error is returned.
 *
 *  @note If you are on Swift 3, you must declare the completion block as `@escaping` or Xcode will give you a protocol conformance error. https://bugs.swift.org/browse/SR-2597
 */
- (void)attachSourceToCustomer:(id<STPSource>)source completion:(STPErrorBlock)completion;

/**
 *  Change a customer's `default_source` to be the provided card. On your backend, retrieve the Stripe customer associated with your logged-in user. Then, call the Customer Update method as described at https://stripe.com/docs/api#update_customer , specifying default_source to be the value of source.stripeID (for an example Ruby implementation of this API, see https://github.com/stripe/example-ios-backend/blob/master/web.rb#L82 ). If this API call succeeds, call `completion(nil)`. Otherwise, call `completion(error)` with the error that occurred.
 *
 *  @param source     The newly-selected default source for the user.
 *  @param completion call this callback when you're done selecting the new default source for the customer on your backend. For example, `completion(nil)` (if your call succeeds) or `completion(error)` if an error is returned.
 *
 *  @note If you are on Swift 3, you must declare the completion block as `@escaping` or Xcode will give you a protocol conformance error. https://bugs.swift.org/browse/SR-2597
 */
- (void)selectDefaultCustomerSource:(id<STPSource>)source completion:(STPErrorBlock)completion;

@end

NS_ASSUME_NONNULL_END
