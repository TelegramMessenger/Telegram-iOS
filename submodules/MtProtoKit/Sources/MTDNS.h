#import <Foundation/Foundation.h>

@class MTSignal;

@interface MTDNS : NSObject

+ (MTSignal *)resolveHostnameNative:(NSString *)hostname port:(int32_t)port;
+ (MTSignal *)resolveHostnameUniversal:(NSString *)hostname port:(int32_t)port;

@end
