//
//  NSString+Stripe_CardBrands.h
//  Stripe
//
//  Created by Jack Flintermann on 1/15/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STPCardBrand.h"

@interface NSString (Stripe_CardBrands)

+ (nonnull instancetype)stp_stringWithCardBrand:(STPCardBrand)brand;

@end

void linkNSStringCardBrandsCategory(void);
