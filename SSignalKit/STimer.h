#import <Foundation/Foundation.h>

@class SQueue;

@interface STimer : NSObject

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion queue:(SQueue *)queue;

- (void)start;
- (void)invalidate;

@end
