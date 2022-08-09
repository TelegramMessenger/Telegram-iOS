//
//  STPCardBrand.h
//  Stripe
//
//  Created by Jack Flintermann on 7/24/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  The various card brands to which a payment card can belong.
 */
typedef NS_ENUM(NSInteger, STPCardBrand) {
    STPCardBrandVisa,
    STPCardBrandAmex,
    STPCardBrandMasterCard,
    STPCardBrandDiscover,
    STPCardBrandJCB,
    STPCardBrandDinersClub,
    STPCardBrandOther,
    STPCardBrandUnknown,
};
