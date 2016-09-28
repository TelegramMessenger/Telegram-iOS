#import "MTHttpRequestOperation.h"

#import "../thirdparty/AFNetworking/AFHTTPRequestOperation.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTDisposable.h>
#   import <MTProtoKitDynamic/MTSignal.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTDisposable.h>
#   import <MTProtoKitMac/MTSignal.h>
#else
#   import <MTProtoKit/MTDisposable.h>
#   import <MTProtoKit/MTSignal.h>
#endif

@implementation MTHttpRequestOperation

+ (MTSignal *)dataForHttpUrl:(NSURL *)url {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        
        [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        [operation setFailureCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        
        [operation setCompletionBlockWithSuccess:^(__unused AFHTTPRequestOperation *operation, __unused id responseObject)
        {
            [subscriber putNext:[operation responseData]];
            [subscriber putCompletion];
        } failure:^(__unused AFHTTPRequestOperation *operation, __unused NSError *error)
        {
            [subscriber putError:nil];
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
