#import <Foundation/Foundation.h>

@interface SQueue : NSObject

+ (SQueue *)mainQueue;
+ (SQueue *)concurrentDefaultQueue;
+ (SQueue *)concurrentBackgroundQueue;

+ (SQueue *)wrapConcurrentNativeQueue:(dispatch_queue_t)nativeQueue;

- (void)dispatch:(dispatch_block_t)block;
- (void)dispatchSync:(dispatch_block_t)block;
- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous;

- (dispatch_queue_t)_dispatch_queue;

- (bool)isCurrentQueue;

@end
