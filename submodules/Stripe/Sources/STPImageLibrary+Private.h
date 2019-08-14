//
//  STPImageLibrary+Private.h
//  Stripe
//
//  Created by Jack Flintermann on 6/30/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPImageLibrary.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface STPImageLibrary (Private)

+ (UIImage *)addIcon;
+ (UIImage *)leftChevronIcon;
+ (UIImage *)smallRightChevronIcon;
+ (UIImage *)checkmarkIcon;
+ (UIImage *)largeCardFrontImage;
+ (UIImage *)largeCardBackImage;
+ (UIImage *)largeCardApplePayImage;

+ (UIImage *)safeImageNamed:(NSString *)imageName
        templateIfAvailable:(BOOL)templateIfAvailable;
+ (UIImage *)brandImageForCardBrand:(STPCardBrand)brand 
                           template:(BOOL)isTemplate;
+ (UIImage *)imageWithTintColor:(UIColor *)color
                       forImage:(UIImage *)image;
+ (UIImage *)paddedImageWithInsets:(UIEdgeInsets)insets
                          forImage:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
