

#import <Foundation/Foundation.h>

@interface TGPhoneUtils : NSObject

+ (NSString *)formatPhone:(NSString *)phone forceInternational:(bool)forceInternational;
+ (NSString *)formatPhoneUrl:(NSString *)phone;

+ (NSString *)cleanPhone:(NSString *)phone;
+ (NSString *)cleanInternationalPhone:(NSString *)phone forceInternational:(bool)forceInternational;

+ (bool)maybePhone:(NSString *)phone;

@end
