#import <Foundation/Foundation.h>

@class MTSignal;

@interface MTHttpRequestOperation : NSObject

+ (MTSignal *)dataForHttpUrl:(NSURL *)url;
+ (MTSignal *)dataForHttpUrl:(NSURL *)url headers:(NSDictionary *)headers;

@end
