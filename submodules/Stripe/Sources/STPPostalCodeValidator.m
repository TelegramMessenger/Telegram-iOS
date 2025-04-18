//
//  STPPostalCodeValidator.m
//  Stripe
//
//  Created by Ben Guo on 4/14/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPPostalCodeValidator.h"
#import "STPCardValidator.h"
#import "STPPhoneNumberValidator.h"

@implementation STPPostalCodeValidator

+ (BOOL)stringIsValidPostalCode:(nullable NSString *)string
                           type:(STPPostalCodeType)postalCodeType {
    switch (postalCodeType) {
        case STPCountryPostalCodeTypeNumericOnly:
            return [STPCardValidator sanitizedNumericStringForString:string].length > 0;
        case STPCountryPostalCodeTypeAlphanumeric:
            return string.length > 0;
        case STPCountryPostalCodeTypeNotRequired:
            return YES;
    }
}

+ (BOOL)stringIsValidPostalCode:(nullable NSString *)string
                    countryCode:(nullable NSString *)countryCode {
    return [self stringIsValidPostalCode:string
                                    type:[self postalCodeTypeForCountryCode:countryCode]];
}

+ (STPPostalCodeType)postalCodeTypeForCountryCode:(NSString *)countryCode {
    if ([countryCode isEqualToString:@"US"]) {
        return STPCountryPostalCodeTypeNumericOnly;
    }
    else if ([[self countriesWithNoPostalCodes] containsObject:countryCode]) {
        return STPCountryPostalCodeTypeNotRequired;
    }
    else {
        return STPCountryPostalCodeTypeAlphanumeric;
    }
}

+ (NSArray *)countriesWithNoPostalCodes {
    return @[ @"AE",
              @"AG",
              @"AN",
              @"AO",
              @"AW",
              @"BF",
              @"BI",
              @"BJ",
              @"BO",
              @"BS",
              @"BW",
              @"BZ",
              @"CD",
              @"CF",
              @"CG",
              @"CI",
              @"CK",
              @"CM",
              @"DJ",
              @"DM",
              @"ER",
              @"FJ",
              @"GD",
              @"GH",
              @"GM",
              @"GN",
              @"GQ",
              @"GY",
              @"HK",
              @"IE",
              @"JM",
              @"KE",
              @"KI",
              @"KM",
              @"KN",
              @"KP",
              @"LC",
              @"ML",
              @"MO",
              @"MR",
              @"MS",
              @"MU",
              @"MW",
              @"NR",
              @"NU",
              @"PA",
              @"QA",
              @"RW",
              @"SA",
              @"SB",
              @"SC",
              @"SL",
              @"SO",
              @"SR",
              @"ST",
              @"SY",
              @"TF",
              @"TK",
              @"TL",
              @"TO",
              @"TT",
              @"TV",
              @"TZ",
              @"UG",
              @"VU",
              @"YE",
              @"ZA",
              @"ZW"
              ];
}

@end
