#import <MtProtoKit/MTHttpRequestOperation.h>

#import <MtProtoKit/AFHTTPRequestOperation.h>
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
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        
        [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        [operation setFailureCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        
        [operation setCompletionBlockWithSuccess:^(__unused NSOperation *operation, __unused id responseObject)
        {
            AFHTTPRequestOperation *concreteOperation = (AFHTTPRequestOperation *)operation;
            MTHttpResponse *result = [[MTHttpResponse alloc] initWithHeaders:[concreteOperation response].allHeaderFields data:[concreteOperation responseData]];
            [subscriber putNext:result];
            [subscriber putCompletion];
        } failure:^(__unused NSOperation *operation, __unused NSError *error)
        {
            [subscriber putError:error];
        }];
        
        [operation start];
        
        __weak AFHTTPRequestOperation *weakOperation = operation;
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            __strong AFHTTPRequestOperation *strongOperation = weakOperation;
            [strongOperation cancel];
        }];
    }];
}
@end
