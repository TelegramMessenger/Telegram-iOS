#import <Foundation/Foundation.h>

@class SQueue;

@interface STimer : NSObject

- (instancetype _Nonnull)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t _Nonnull)completion queue:(SQueue * _Nonnull)queue;
- (instancetype _Nonnull)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t _Nonnull)completion nativeQueue:(dispatch_queue_t _Nonnull)nativeQueue;

- (void)start;
- (void)invalidate;
- (void)fireAndInvalidate;

@end
