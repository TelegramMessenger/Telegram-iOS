#import <MtProtoKit/MTHttpRequestOperation.h>

#import <MtProtoKit/MTDisposable.h>
#import <MtProtoKit/MTSignal.h>

@implementation MTHttpResponse

- (instancetype)initWithHeaders:(NSDictionary *)headers data:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _headers = headers;
        _data = data;
    }
    return self;
}

@end

@implementation MTHttpRequestOperation

+ (MTSignal *)dataForHttpUrl:(NSURL *)url {
    return [self dataForHttpUrl:url headers:nil];
}

+ (MTSignal *)dataForHttpUrl:(NSURL *)url headers:(NSDictionary *)headers {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, __unused BOOL *stop) {
            [request setValue:value forHTTPHeaderField:key];
        }];
        
        NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse * response, NSError *error) {
            if (error) {
                [subscriber putError:error];
            } else {
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                    MTHttpResponse *result = [[MTHttpResponse alloc] initWithHeaders:httpResponse.allHeaderFields data:data];
                    [subscriber putNext:result];
                    [subscriber putCompletion];
                } else {
                    [subscriber putError:nil];
                }
            }
        }];
        [dataTask resume];
        
        __weak NSURLSessionDataTask *weakDataTask = dataTask;
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            __strong NSURLSessionDataTask *strongDataTask = weakDataTask;
            if (strongDataTask) {
                [strongDataTask cancel];
            }
        }];
    }];
}
@end
