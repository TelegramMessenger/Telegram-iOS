//
//  STPFormEncodable.h
//  Stripe
//
//  Created by Jack Flintermann on 10/14/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Objects conforming to STPFormEncodable can be automatically converted to a form-encoded string, which can then be used when making requests to the Stripe API.
 */
@protocol STPFormEncodable <NSObject>

/**
 * The root object name to be used when converting this object to a form-encoded string. For example, if this returns @"card", then the form-encoded output will resemble @"card[foo]=bar" (where 'foo' and 'bar' are specified by `propertyNamesToFormFieldNamesMapping` below.
 */
+ (nonnull NSString *)rootObjectName;

/**
 * This maps properties on an object that is being form-encoded into parameter names in the Stripe API. For example, STPCardParams has a field called `expMonth`, but the Stripe API expects a field called `exp_month`. This dictionary represents a mapping from the former to the latter (in other words, [STPCardParams propertyNamesToFormFieldNamesMapping][@"expMonth"] == @"exp_month".)
 */
+ (nonnull NSDictionary *)propertyNamesToFormFieldNamesMapping;

/**
 * You can use this property to add additional fields to an API request that are not explicitly defined by the object's interface. This can be useful when using beta features that haven't been added to the Stripe SDK yet. For example, if the /v1/tokens API began to accept a beta field called "test_field", you might do the following:
    STPCardParams *cardParams = [STPCardParams new];
    // add card values
    cardParams.additionalAPIParameters = @{@"test_field": @"example_value"};
    [[STPAPIClient sharedClient] createTokenWithCard:cardParams completion:...];
 */
@property(nonatomic, readwrite, nonnull, copy)NSDictionary *additionalAPIParameters;

@end
