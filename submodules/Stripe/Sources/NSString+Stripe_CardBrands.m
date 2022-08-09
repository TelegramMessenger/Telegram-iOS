//
//  NSString+Stripe_CardBrands.m
//  Stripe
//
//  Created by Jack Flintermann on 1/15/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "NSString+Stripe_CardBrands.h"

@implementation NSString (Stripe_CardBrands)

+ (nonnull instancetype)stp_stringWithCardBrand:(STPCardBrand)brand {
    switch (brand) {
        case STPCardBrandAmex: return @"American Express";
        case STPCardBrandDinersClub: return @"Diners Club";
        case STPCardBrandDiscover: return @"Discover";
        case STPCardBrandJCB: return @"JCB";
        case STPCardBrandMasterCard: return @"MasterCard";
        case STPCardBrandUnknown: return @"Unknown";
        case STPCardBrandVisa: return @"Visa";
        case STPCardBrandOther: return @"Other";
    }
}

@end

void linkNSStringCardBrandsCategory(void){}
