/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTimer.h>

#if TARGET_OS_IPHONE

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
#define NEEDS_DISPATCH_RETAIN_RELEASE 0
#else                                         // iOS 5.X or earlier
#define NEEDS_DISPATCH_RETAIN_RELEASE 1
#endif

#else

#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
#define NEEDS_DISPATCH_RETAIN_RELEASE 0
#else
#define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
#endif

#endif

@interface MTTimer ()

@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic) bool repeat;
@property (nonatomic, copy) dispatch_block_t completion;
@property (nonatomic, strong) dispatch_queue_t queue;

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
        self.queue = queue;
    }
    return self;
}

- (void)dealloc
{
    if (_timer != nil)
    {
        dispatch_source_cancel(_timer);
#if NEEDS_DISPATCH_RETAIN_RELEASE
        dispatch_release(_timer);
#endif
        _timer = nil;
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
#if NEEDS_DISPATCH_RETAIN_RELEASE
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
