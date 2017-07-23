#import <Foundation/Foundation.h>

@interface ASQueue : NSObject

- (instancetype)initWithName:(const char *)name;

+ (ASQueue *)mainQueue;

- (dispatch_queue_t)nativeQueue;

- (bool)isCurrentQueue;
- (void)dispatchOnQueue:(dispatch_block_t)block;
- (void)dispatchOnQueue:(dispatch_block_t)block synchronous:(bool)synchronous;

@end
