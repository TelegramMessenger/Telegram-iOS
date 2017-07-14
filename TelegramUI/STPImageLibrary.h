//
//  STPImages.h
//  Stripe
//
//  Created by Jack Flintermann on 6/30/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "STPCardBrand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  This class lets you access card icons used by the Stripe SDK. All icons are 32 x 20 points.
 */
@interface STPImageLibrary : NSObject

/**
 *  An icon representing Apple Pay.
 */
+ (UIImage *)applePayCardImage;

/**
 *  An icon representing American Express.
 */
+ (UIImage *)amexCardImage;

/**
 *  An icon representing Diners Club.
 */
+ (UIImage *)dinersClubCardImage;

/**
 *  An icon representing Discover.
 */
+ (UIImage *)discoverCardImage;

/**
 *  An icon representing JCB.
 */
+ (UIImage *)jcbCardImage;

/**
 *  An icon representing MasterCard.
 */
+ (UIImage *)masterCardCardImage;

/**
 *  An icon representing Visa.
 */
+ (UIImage *)visaCardImage;

/**
 *  An icon to use when the type of the card is unknown.
 */
+ (UIImage *)unknownCardCardImage;

/**
 *  This returns the appropriate icon for the specified card brand.
 */
+ (UIImage *)brandImageForCardBrand:(STPCardBrand)brand;

/**
 *  This returns the appropriate icon for the specified card brand as a 
 *  single color template that can be tinted
 */
+ (UIImage *)templatedBrandImageForCardBrand:(STPCardBrand)brand;

/**
 *  This returns a small icon indicating the CVC location for the given card brand.
 */
+ (UIImage *)cvcImageForCardBrand:(STPCardBrand)brand;


@end

NS_ASSUME_NONNULL_END
