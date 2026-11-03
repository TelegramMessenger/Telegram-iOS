#import <MtProtoKit/MTTimer.h>

@interface MTTimer ()

#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_source_t timer;
#else
@property (nonatomic) dispatch_source_t timer;
#endif

@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic) bool repeat;
@property (nonatomic, copy) dispatch_block_t completion;

#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t queue;
#else
@property (nonatomic) dispatch_queue_t queue;
#endif

@end

@implementation MTTimer

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion queue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self != nil)
    {
        _timeoutDate = INT_MAX;
        
        _timeout = timeout;
        _repeat = repeat;
        self.completion = completion;
#if !OS_OBJECT_USE_OBJC
        dispatch_retain(queue);
#endif
        _queue = queue;
    }
    return self;
}

- (void)dealloc
{
    if (_timer != nil)
    {
        dispatch_source_cancel(_timer);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_timer);
#endif
        _timer = nil;
    }
    
    if (_queue != nil)
    {
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_queue);
#endif
        _queue = nil;
    }
}

- (void)start
{
    _timeoutDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + _timeout;
    
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * NSEC_PER_SEC)), _repeat ? (int64_t)(_timeout * NSEC_PER_SEC) : DISPATCH_TIME_FOREVER, 0);
    
    dispatch_source_set_event_handler(_timer, ^
    {
        if (self.completion)
            self.completion();
        if (!_repeat)
        {
            [self invalidate];
        }
    });
    dispatch_resume(_timer);
}

- (void)fireAndInvalidate
{
    if (self.completion)
        self.completion();
    
    [self invalidate];
}

- (void)invalidate
{
    _timeoutDate = 0;
    
    if (_timer != nil)
    {
        dispatch_source_cancel(_timer);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_timer);
#endif
        _timer = nil;
    }
}

- (bool)isScheduled
{
    return _timer != nil;
}

- (void)resetTimeout:(NSTimeInterval)timeout
{
    [self invalidate];
    
    _timeout = timeout;
    [self start];
}

- (NSTimeInterval)remainingTime
{
    if (_timeoutDate < FLT_EPSILON)
        return DBL_MAX;
    else
        return _timeoutDate - (CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970);
}

@end
