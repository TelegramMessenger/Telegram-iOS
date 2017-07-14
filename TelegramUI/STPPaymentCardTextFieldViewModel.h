//
//  STPPaymentCardTextFieldViewModel.h
//  Stripe
//
//  Created by Jack Flintermann on 7/21/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "STPCard.h"
#import "STPCardValidator.h"

typedef NS_ENUM(NSInteger, STPCardFieldType) {
    STPCardFieldTypeNumber,
    STPCardFieldTypeExpiration,
    STPCardFieldTypeCVC,
};

@interface STPPaymentCardTextFieldViewModel : NSObject

@property(nonatomic, readwrite, copy, nullable)NSString *cardNumber;
@property(nonatomic, readwrite, copy, nullable)NSString *rawExpiration;
@property(nonatomic, readonly, nullable)NSString *expirationMonth;
@property(nonatomic, readonly, nullable)NSString *expirationYear;
@property(nonatomic, readwrite, copy, nullable)NSString *cvc;
@property(nonatomic, readonly) STPCardBrand brand;

- (nonnull NSString *)defaultPlaceholder;
- (nullable NSString *)numberWithoutLastDigits;

- (BOOL)isValid;

- (STPCardValidationState)validationStateForField:(STPCardFieldType)fieldType;

@end
