//
//  STPCustomer.h
//  Stripe
//
//  Created by Jack Flintermann on 6/9/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STPSource.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  An `STPCustomer` represents a deserialized Customer object from the Stripe API. You can use `STPCustomerDeserializer` to convert a JSON response from the Stripe API into an `STPCustomer`.
 */
@interface STPCustomer : NSObject

/**
 *  Initialize a customer object with the provided values.
 *
 *  @param stripeID      The ID of the customer, e.g. `cus_abc`
 *  @param defaultSource The default source of the customer, such as an `STPCard` object. Can be nil.
 *  @param sources       All of the customer's payment sources. This might be an empty array.
 *
 *  @return an instance of STPCustomer
 */
+ (instancetype)customerWithStripeID:(NSString *)stripeID
                       defaultSource:(nullable id<STPSource>)defaultSource
                             sources:(NSArray<id<STPSource>> *)sources;

/**
 *  The Stripe ID of the customer, e.g. `cus_1234`
 */
@property(nonatomic, readonly, copy)NSString *stripeID;

/**
 *  The default source used to charge the customer.
 */
@property(nonatomic, readonly, nullable) id<STPSource> defaultSource;

/**
 *  The available payment sources the customer has (this may be an empty array).
 */
@property(nonatomic, readonly) NSArray<id<STPSource>> *sources;

@end

/**
 Use `STPCustomerDeserializer` to convert a response from the Stripe API into an `STPCustomer` object. `STPCustomerDeserializer` expects the JSON response to be in the exact same format as the Stripe API.
 */
@interface STPCustomerDeserializer : NSObject

/**
 *  Initialize a customer deserializer. The `data`, `urlResponse`, and `error` parameters are intended to be passed from an `NSURLSessionDataTask` callback. After it has been initialized, you can inspect the `error` and `customer` properties to see if the deserialization was successful. If `error` is nil, `customer` will be non-nil (and vice versa).
 *
 *  @param data        An `NSData` object representing encoded JSON for a Customer object
 *  @param urlResponse The URL response obtained from the `NSURLSessionTask`
 *  @param error       Any error that occurred from the URL session task (if this is non-nil, the `error` property will be set to this value after initialization).
 *
 */
- (instancetype)initWithData:(nullable NSData *)data
                 urlResponse:(nullable NSURLResponse *)urlResponse
                       error:(nullable NSError *)error;

/**
 *  Initializes a customer deserializer with a JSON dictionary. This JSON should be in the exact same format as what the Stripe API returns. If it's successfully parsed, the `customer` parameter will be present after initialization; otherwise `error` will be present.
 *
 *  @param json a JSON dictionary.
 *
 */
- (instancetype)initWithJSONResponse:(id)json;

/**
 *  If a customer was successfully parsed from the response, it will be set here. Otherwise, this value wil be nil (and the `error` property will explain what went wrong).
 */
@property(nonatomic, readonly, nullable)STPCustomer *customer;

/**
 *  If the deserializer failed to parse a customer, this property will explain why (and the `customer` property will be nil).
 */
@property(nonatomic, readonly, nullable)NSError *error;

@end

NS_ASSUME_NONNULL_END
