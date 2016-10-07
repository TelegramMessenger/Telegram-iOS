#import <Foundation/Foundation.h>

@class MTSignal;

@interface MTHttpRequestOperation : NSObject

+ (MTSignal *)dataForHttpUrl:(NSURL *)url;

@end
