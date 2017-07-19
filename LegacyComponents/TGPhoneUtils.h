/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface TGPhoneUtils : NSObject

+ (NSString *)formatPhone:(NSString *)phone forceInternational:(bool)forceInternational;
+ (NSString *)formatPhoneUrl:(NSString *)phone;

+ (NSString *)cleanPhone:(NSString *)phone;
+ (NSString *)cleanInternationalPhone:(NSString *)phone forceInternational:(bool)forceInternational;

+ (bool)maybePhone:(NSString *)phone;

@end
