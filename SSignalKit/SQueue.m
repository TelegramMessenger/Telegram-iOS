#import "SQueue.h"

@interface SQueue ()
{
    dispatch_queue_t _queue;
}

@end

@implementation SQueue

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _queue = dispatch_queue_create(NULL, NULL);
    }
    return self;
}

- (dispatch_queue_t)_dispatch_queue
{
    return _queue;
}

- (void)dispatch:(dispatch_block_t)block
{
    dispatch_async(_queue, block);
}

@end
