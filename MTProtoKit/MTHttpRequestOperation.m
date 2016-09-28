#import "MTHttpRequestOperation.h"

#import "../thirdparty/AFNetworking/AFHTTPRequestOperation.h"

//#import "MTSignal.h"

@implementation MTHttpRequestOperation

+ (MTSignal *)dataForHttpUrl:(NSURL *)url {
    return nil;
    /*return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        AFHttpRequestOperation *operation = [[AFHttpRequestOperation alloc] initWithRequest:request];
        
        [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        [operation setFailureCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        
        [operation setCompletionBlockWithSuccess:^(__unused MTHttpRequestOperation *operation, __unused id responseObject)
        {
            [subscriber putNext:[operation responseData]];
            [subscriber putCompletion];
        } failure:^(__unused MTHttpRequestOperation *operation, __unused NSError *error)
        {
            [subscriber putError:nil];
        }];
        
        [operation start];
        
        __weak AFHttpRequestOperation *weakOperation = operation;
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            __strong AFHttpRequestOperation *strongOperation = weakOperation;
            [strongOperation cancel];
        }];
    }];*/
}
@end
