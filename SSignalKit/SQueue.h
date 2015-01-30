#import <Foundation/Foundation.h>

@interface SQueue : NSObject

- (void)dispatch:(dispatch_block_t)block;

- (dispatch_queue_t)_dispatch_queue;

@end
