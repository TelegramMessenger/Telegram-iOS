//
//  STPPaymentCardTextFieldViewModel.m
//  Stripe
//
//  Created by Jack Flintermann on 7/21/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPPaymentCardTextFieldViewModel.h"
#import "NSString+Stripe.h"

#define FAUXPAS_IGNORED_IN_METHOD(...)

@implementation STPPaymentCardTextFieldViewModel

- (void)setCardNumber:(NSString *)cardNumber {
    NSString *sanitizedNumber = [STPCardValidator sanitizedNumericStringForString:cardNumber];
    STPCardBrand brand = [STPCardValidator brandForNumber:sanitizedNumber];
    NSInteger maxLength = [STPCardValidator maxLengthForCardBrand:brand];
    _cardNumber = [sanitizedNumber stp_safeSubstringToIndex:maxLength];
}

// This might contain slashes.
- (void)setRawExpiration:(NSString *)expiration {
    NSString *sanitizedExpiration = [STPCardValidator sanitizedNumericStringForString:expiration];
    self.expirationMonth = [sanitizedExpiration stp_safeSubstringToIndex:2];
    self.expirationYear = [[sanitizedExpiration stp_safeSubstringFromIndex:2] stp_safeSubstringToIndex:2];
}

- (NSString *)rawExpiration {
    NSMutableArray *array = [@[] mutableCopy];
    if (self.expirationMonth && ![self.expirationMonth isEqualToString:@""]) {
        [array addObject:self.expirationMonth];
    }
    
    if ([STPCardValidator validationStateForExpirationMonth:self.expirationMonth] == STPCardValidationStateValid) {
        [array addObject:self.expirationYear];
    }
    return [array componentsJoinedByString:@"/"];
}

- (void)setExpirationMonth:(NSString *)expirationMonth {
    NSString *sanitizedExpiration = [STPCardValidator sanitizedNumericStringForString:expirationMonth];
    if (sanitizedExpiration.length == 1 && ![sanitizedExpiration isEqualToString:@"0"] && ![sanitizedExpiration isEqualToString:@"1"]) {
        sanitizedExpiration = [@"0" stringByAppendingString:sanitizedExpiration];
    }
    _expirationMonth = [sanitizedExpiration stp_safeSubstringToIndex:2];
}

- (void)setExpirationYear:(NSString *)expirationYear {
    _expirationYear = [[STPCardValidator sanitizedNumericStringForString:expirationYear] stp_safeSubstringToIndex:2];
}

- (void)setCvc:(NSString *)cvc {
    NSInteger maxLength = [STPCardValidator maxCVCLengthForCardBrand:self.brand];
    _cvc = [[STPCardValidator sanitizedNumericStringForString:cvc] stp_safeSubstringToIndex:maxLength];
}

- (STPCardBrand)brand {
    return [STPCardValidator brandForNumber:self.cardNumber];
}

- (STPCardValidationState)validationStateForField:(STPCardFieldType)fieldType {
    switch (fieldType) {
        case STPCardFieldTypeNumber:
            return [STPCardValidator validationStateForNumber:self.cardNumber validatingCardBrand:YES];
            break;
        case STPCardFieldTypeExpiration: {
            STPCardValidationState monthState = [STPCardValidator validationStateForExpirationMonth:self.expirationMonth];
            STPCardValidationState yearState = [STPCardValidator validationStateForExpirationYear:self.expirationYear inMonth:self.expirationMonth];
            if (monthState == STPCardValidationStateValid && yearState == STPCardValidationStateValid) {
                return STPCardValidationStateValid;
            } else if (monthState == STPCardValidationStateInvalid || yearState == STPCardValidationStateInvalid) {
                return STPCardValidationStateInvalid;
            } else {
                return STPCardValidationStateIncomplete;
            }
            break;
        }
        case STPCardFieldTypeCVC:
            return [STPCardValidator validationStateForCVC:self.cvc cardBrand:self.brand];
    }
}

- (BOOL)isValid {
    return ([self validationStateForField:STPCardFieldTypeNumber] == STPCardValidationStateValid &&
            [self validationStateForField:STPCardFieldTypeExpiration] == STPCardValidationStateValid &&
            [self validationStateForField:STPCardFieldTypeCVC] == STPCardValidationStateValid);
}

- (NSString *)defaultPlaceholder {
    return @"1234567812345678";
}

- (NSString *)numberWithoutLastDigits {
    NSUInteger length = [STPCardValidator fragmentLengthForCardBrand:[STPCardValidator brandForNumber:self.cardNumber]];
    NSUInteger toIndex = self.cardNumber.length - length;
    
    return (toIndex < self.cardNumber.length) ?
        [self.cardNumber substringToIndex:toIndex] :
        [self.defaultPlaceholder stp_safeSubstringToIndex:[self defaultPlaceholder].length - length];

}

@end
