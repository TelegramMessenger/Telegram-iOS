

#import <Foundation/Foundation.h>

@interface MTQueue : NSObject

- (instancetype)initWithName:(const char *)name;

+ (MTQueue *)mainQueue;
+ (MTQueue *)concurrentDefaultQueue;
+ (MTQueue *)concurrentLowQueue;

- (dispatch_queue_t)nativeQueue;

- (bool)isCurrentQueue;
- (void)dispatchOnQueue:(dispatch_block_t)block;
- (void)dispatchOnQueue:(dispatch_block_t)block synchronous:(bool)synchronous;

@end
