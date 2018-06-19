

#import "ASQueue.h"

@interface ASQueue ()
{
    bool _isMainQueue;
    dispatch_queue_t _queue;
    
    const char *_name;
}

@end

@implementation ASQueue

- (instancetype)initWithName:(const char *)name
{
    self = [super init];
    if (self != nil)
    {
        _name = name;
        
        _queue = dispatch_queue_create(_name, 0);
        dispatch_queue_set_specific(_queue, _name, (void *)_name, NULL);
    }
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_HAVE_OBJC_SUPPORT
    dispatch_release(_queue);
#endif
    _queue = nil;
}

+ (ASQueue *)mainQueue
{
    static ASQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ASQueue alloc] init];
        queue->_queue = dispatch_get_main_queue();
        queue->_isMainQueue = true;
    });
    return queue;
}

- (dispatch_queue_t)nativeQueue
{
    return _queue;
}

- (bool)isCurrentQueue
{
    if (_queue == nil)
        return false;
    
    if (_isMainQueue)
        return [NSThread isMainThread];
    else
        return dispatch_get_specific(_name) == _name;
}

- (void)dispatchOnQueue:(dispatch_block_t)block
{
    [self dispatchOnQueue:block synchronous:false];
}

- (void)dispatchOnQueue:(dispatch_block_t)block synchronous:(bool)synchronous
{
    if (block == nil)
        return;
    
    if (_queue != nil)
    {
        if (_isMainQueue)
        {
            if ([NSThread isMainThread])
                block();
            else if (synchronous)
                dispatch_sync(_queue, block);
            else
                dispatch_async(_queue, block);
        }
        else
        {
            if (dispatch_get_specific(_name) == _name)
                block();
            else if (synchronous)
                dispatch_sync(_queue, block);
            else
                dispatch_async(_queue, block);
        }
    }
}

@end
