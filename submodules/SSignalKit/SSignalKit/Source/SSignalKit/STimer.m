#import "STimer.h"

#import "SQueue.h"

@interface STimer ()
{
    dispatch_source_t _timer;
    NSTimeInterval _timeout;
    NSTimeInterval _timeoutDate;
    bool _repeat;
    dispatch_block_t _completion;
    dispatch_queue_t _nativeQueue;
}

@end

@implementation STimer

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion queue:(SQueue *)queue {
    return [self initWithTimeout:timeout repeat:repeat completion:completion nativeQueue:queue._dispatch_queue];
}

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion nativeQueue:(dispatch_queue_t)nativeQueue
{
    self = [super init];
    if (self != nil)
    {
        _timeoutDate = INT_MAX;
        
        _timeout = timeout;
        _repeat = repeat;
        _completion = [completion copy];
        _nativeQueue = nativeQueue;
    }
    return self;
}

- (void)dealloc
{
    if (_timer != nil)
    {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (void)start
{
    _timeoutDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + _timeout;
    
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _nativeQueue);
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * NSEC_PER_SEC)), _repeat ? (int64_t)(_timeout * NSEC_PER_SEC) : DISPATCH_TIME_FOREVER, 0);
    
    dispatch_source_set_event_handler(_timer, ^
    {
        if (_completion)
            _completion();
        if (!_repeat)
            [self invalidate];
    });
    dispatch_resume(_timer);
}

- (void)fireAndInvalidate
{
    if (_completion)
        _completion();
    
    [self invalidate];
}

- (void)invalidate
{
    _timeoutDate = 0;
    
    if (_timer != nil)
    {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

@end
