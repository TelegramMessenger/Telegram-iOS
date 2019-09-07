#import <Foundation/Foundation.h>

@class SQueue;

@interface STimer : NSObject

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion queue:(SQueue *)queue;
- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion nativeQueue:(dispatch_queue_t)nativeQueue;

- (void)start;
- (void)invalidate;
- (void)fireAndInvalidate;

@end
