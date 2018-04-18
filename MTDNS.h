#import <Foundation/Foundation.h>

@class MTSignal;

@interface MTDNS : NSObject

+ (MTSignal *)resolveHostname:(NSString *)hostname;

@end
