//
//  STPAddress.h
//  Stripe
//
//  Created by Ben Guo on 4/13/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
#import <AddressBook/AddressBook.h>
#pragma clang diagnostic pop

#define FAUXPAS_IGNORED_IN_METHOD(...)
#define FAUXPAS_IGNORED_ON_LINE(...)

#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>

/**
 *  What set of billing address information you need to collect from your user.
 *
 *  @note If the user is from a country that does not use zip/postal codes,
 *  the user may not be asked for one regardless of this setting.
 */
typedef NS_ENUM(NSUInteger, STPBillingAddressFields) {
    /**
     *  No billing address information
     */
    STPBillingAddressFieldsNone,
    /**
     *  Just request the user's billing ZIP code
     */
    STPBillingAddressFieldsZip,
    /**
     *  Request the user's full billing address
     */
    STPBillingAddressFieldsFull,
};

/**
 *  STPAddress Contains an address as represented by the Stripe API.
 */
@interface STPAddress : NSObject

/**
 *  The user's full name (e.g. "Jane Doe")
 */
@property (nonatomic, copy) NSString *name;

/**
 *  The first line of the user's street address (e.g. "123 Fake St")
 */
@property (nonatomic, copy) NSString *line1;

/**
 *  The apartment, floor number, etc of the user's street address (e.g. "Apartment 1A")
 */
@property (nonatomic, copy) NSString *line2;

/**
 *  The city in which the user resides (e.g. "San Francisco")
 */
@property (nonatomic, copy) NSString *city;

/**
 *  The state in which the user resides (e.g. "CA")
 */
@property (nonatomic, copy) NSString *state;

/**
 *  The postal code in which the user resides (e.g. "90210")
 */
@property (nonatomic, copy) NSString *postalCode;

/**
 *  The ISO country code of the address (e.g. "US")
 */
@property (nonatomic, copy) NSString *country;

/**
 *  The phone number of the address (e.g. "8885551212")
 */
@property (nonatomic, copy) NSString *phone;

/**
 *  The email of the address (e.g. "jane@doe.com")
 */
@property (nonatomic, copy) NSString *email;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
- (instancetype)initWithABRecord:(ABRecordRef)record;
#pragma clang diagnostic pop

- (BOOL)containsRequiredFields:(STPBillingAddressFields)requiredFields;

+ (PKAddressField)applePayAddressFieldsFromBillingAddressFields:(STPBillingAddressFields)billingAddressFields; FAUXPAS_IGNORED_ON_LINE(APIAvailability);

@end
