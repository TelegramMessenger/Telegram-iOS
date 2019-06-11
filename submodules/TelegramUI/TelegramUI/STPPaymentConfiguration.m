//
//  STPPaymentConfiguration.m
//  Stripe
//
//  Created by Jack Flintermann on 5/18/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPPaymentConfiguration.h"
#import "STPPaymentConfiguration+Private.h"
#import "STPAPIClient.h"
#import "STPAPIClient+ApplePay.h"

@implementation STPPaymentConfiguration

+ (instancetype)sharedConfiguration {
    static STPPaymentConfiguration *sharedConfiguration;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedConfiguration = [self new];
    });
    return sharedConfiguration;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _additionalPaymentMethods = STPPaymentMethodTypeAll;
        _requiredBillingAddressFields = STPBillingAddressFieldsNone;
        _companyName = @"Telegram";
        _smsAutofillDisabled = NO;
    }
    return self;
}

- (id)copyWithZone:(__unused NSZone *)zone {
    STPPaymentConfiguration *copy = [self.class new];
    copy.publishableKey = self.publishableKey;
    copy.additionalPaymentMethods = self.additionalPaymentMethods;
    copy.requiredBillingAddressFields = self.requiredBillingAddressFields;
    copy.companyName = self.companyName;
    copy.appleMerchantIdentifier = self.appleMerchantIdentifier;
    copy.smsAutofillDisabled = self.smsAutofillDisabled;
    return copy;
}

@end

@implementation STPPaymentConfiguration (Private)

- (BOOL)applePayEnabled {
    return self.appleMerchantIdentifier &&
    (self.additionalPaymentMethods & STPPaymentMethodTypeApplePay) &&
    [Stripe deviceSupportsApplePay];
}

@end

