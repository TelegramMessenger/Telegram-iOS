#import <Foundation/Foundation.h>

@interface SQueue : NSObject

+ (SQueue *)mainQueue;
+ (SQueue *)concurrentDefaultQueue;
+ (SQueue *)concurrentBackgroundQueue;

- (void)dispatch:(dispatch_block_t)block;

- (dispatch_queue_t)_dispatch_queue;

@end
