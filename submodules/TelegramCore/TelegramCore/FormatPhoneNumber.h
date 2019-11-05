#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FormatPhoneNumber : NSObject

+ (NSString *)cleanInternationalPhone:(NSString *)phone forceInternational:(bool)forceInternational;
+ (NSString *)formatPhoneNumber:(NSString *)number;

@end

NS_ASSUME_NONNULL_END
