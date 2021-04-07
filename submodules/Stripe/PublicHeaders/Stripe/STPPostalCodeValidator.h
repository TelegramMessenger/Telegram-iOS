//
//  STPPostalCodeValidator.h
//  Stripe
//
//  Created by Ben Guo on 4/14/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, STPPostalCodeType) {
    STPCountryPostalCodeTypeNumericOnly,
    STPCountryPostalCodeTypeAlphanumeric,
    STPCountryPostalCodeTypeNotRequired,
};

@interface STPPostalCodeValidator : NSObject

+ (BOOL)stringIsValidPostalCode:(nullable NSString *)string
                           type:(STPPostalCodeType)postalCodeType;
+ (BOOL)stringIsValidPostalCode:(nullable NSString *)string
                    countryCode:(nullable NSString *)countryCode;

+ (STPPostalCodeType)postalCodeTypeForCountryCode:(nullable NSString *)countryCode;

@end
