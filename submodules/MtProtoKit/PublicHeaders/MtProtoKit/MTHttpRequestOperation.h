#import <Foundation/Foundation.h>

@class MTSignal;

@interface MTHttpResponse : NSObject

@property (nonatomic, strong, readonly) NSDictionary *headers;
@property (nonatomic, strong, readonly) NSData *data;

@end

@interface MTHttpRequestOperation : NSObject

+ (MTSignal *)dataForHttpUrl:(NSURL *)url;
+ (MTSignal *)dataForHttpUrl:(NSURL *)url headers:(NSDictionary *)headers;

@end
