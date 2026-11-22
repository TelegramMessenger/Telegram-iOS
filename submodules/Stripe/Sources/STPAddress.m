//
//  STPAddress.m
//  Stripe
//
//  Created by Ben Guo on 4/13/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPAddress.h"
#import "STPCardValidator.h"
#import "STPPostalCodeValidator.h"

@implementation STPAddress

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

- (instancetype)initWithABRecord:(ABRecordRef)record {
    self = [super init];
    if (self) {
        NSString *firstName = (__bridge_transfer NSString*)ABRecordCopyValue(record, kABPersonFirstNameProperty);
        NSString *lastName = (__bridge_transfer NSString*)ABRecordCopyValue(record, kABPersonLastNameProperty);
        NSString *first = firstName ?: @"";
        NSString *last = lastName ?: @"";
        _name = [@[first, last] componentsJoinedByString:@" "];
        
        ABMultiValueRef emailValues = ABRecordCopyValue(record, kABPersonEmailProperty);
        _email = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(emailValues, 0));
        CFRelease(emailValues);
        
        ABMultiValueRef phoneValues = ABRecordCopyValue(record, kABPersonPhoneProperty);
        NSString *phone = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(phoneValues, 0));
        CFRelease(phoneValues);
        
        _phone = [STPCardValidator sanitizedNumericStringForString:phone];

        ABMultiValueRef addressValues = ABRecordCopyValue(record, kABPersonAddressProperty);
        if (addressValues != NULL) {
            if (ABMultiValueGetCount(addressValues) > 0) {
                CFDictionaryRef dict = ABMultiValueCopyValueAtIndex(addressValues, 0);
                NSString *street = CFDictionaryGetValue(dict, kABPersonAddressStreetKey);
                if (street) {
                    _line1 = street;
                }
                NSString *city = CFDictionaryGetValue(dict, kABPersonAddressCityKey);
                if (city) {
                    _city = city;
                }
                NSString *state = CFDictionaryGetValue(dict, kABPersonAddressStateKey);
                if (state) {
                    _state = state;
                }
                NSString *zip = CFDictionaryGetValue(dict, kABPersonAddressZIPKey);
                if (zip) {
                    _postalCode = zip;
                }
                NSString *country = CFDictionaryGetValue(dict, kABPersonAddressCountryCodeKey);
                if (country) {
                    _country = country;
                }
                CFRelease(dict);
            }
            CFRelease(addressValues);
        }
    }
    return self;
}

#pragma clang diagnostic pop

- (BOOL)containsRequiredFields:(STPBillingAddressFields)requiredFields {
    BOOL containsFields = YES;
    switch (requiredFields) {
        case STPBillingAddressFieldsNone:
            return YES;
        case STPBillingAddressFieldsZip:
            return [STPPostalCodeValidator stringIsValidPostalCode:self.postalCode 
                                                       countryCode:self.country];
        case STPBillingAddressFieldsFull:
            return [self hasValidPostalAddress];
    }
    return containsFields;
}

- (BOOL)hasValidPostalAddress {
    return (self.line1.length > 0 
            && self.city.length > 0 
            && self.country.length > 0 
            && (self.state.length > 0 || ![self.country isEqualToString:@"US"])  
            && [STPPostalCodeValidator stringIsValidPostalCode:self.postalCode 
                                                   countryCode:self.country]);
}

/*+ (PKAddressField)applePayAddressFieldsFromBillingAddressFields:(STPBillingAddressFields)billingAddressFields {
    FAUXPAS_IGNORED_IN_METHOD(APIAvailability);
    switch (billingAddressFields) {
        case STPBillingAddressFieldsNone:
            return PKAddressFieldNone;
        case STPBillingAddressFieldsZip:
        case STPBillingAddressFieldsFull:
            return PKAddressFieldPostalAddress;
    }
}*/

@end

