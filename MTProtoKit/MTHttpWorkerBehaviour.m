/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTHttpWorkerBehaviour.h>

#import <MTProtoKit/MTQueue.h>
#import <MTProtoKit/MTTimer.h>

@interface MTHttpWorkerBehaviour ()
{
    MTQueue *_queue;
    MTTimer *_backoffTimer;
    NSInteger _backoffCount;
    
    bool _workersNeeded;
}

@end

@implementation MTHttpWorkerBehaviour

- (instancetype)initWithQueue:(MTQueue *)queue
{
    self = [super init];
    if (self != nil)
    {
        _queue = queue;
    }
    return self;
}

- (void)dealloc
{
    [self invalidateTimer];
}

- (void)clearBackoff
{
    [_queue dispatchOnQueue:^
    {
        _backoffCount = 0;
    }];
}

- (void)setWorkersNeeded
{
    [_queue dispatchOnQueue:^
    {
        _workersNeeded = true;
        
        if (_backoffCount <= 1)
            [self timerEvent];
        else
        {
            NSTimeInterval delay = 1.0;
            
            if (_backoffCount <= 5)
                delay = 1.0;
            else if (_backoffCount <= 20)
                delay = 4.0;
            else
                delay = 8.0;
            
            [self startTimer:delay];
        }
    }];
}

- (void)workerConnected
{
    [_queue dispatchOnQueue:^
    {
        _backoffCount = 0;
        
        if (_workersNeeded)
            [self timerEvent];
    }];
}

- (void)workerReceivedValidData
{
}

- (void)workerDisconnectedWithError
{
    [_queue dispatchOnQueue:^
    {
        _backoffCount++;
    }];
}

- (void)invalidateTimer
{
    MTTimer *backoffTimer = _backoffTimer;
    _backoffTimer = nil;
    
    [_queue dispatchOnQueue:^
    {
        [backoffTimer invalidate];
    }];
}

- (void)startTimer:(NSTimeInterval)timeout
{
    [self invalidateTimer];
    
    [_queue dispatchOnQueue:^
    {
        __weak MTHttpWorkerBehaviour *weakSelf = self;
        _backoffTimer = [[MTTimer alloc] initWithTimeout:timeout repeat:false completion:^
        {
            __strong MTHttpWorkerBehaviour *strongSelf = weakSelf;
            [strongSelf timerEvent];
        } queue:[_queue nativeQueue]];
        [_backoffTimer start];
    }];
}

- (void)timerEvent
{
    [self invalidateTimer];
    
    [_queue dispatchOnQueue:^
    {
        _workersNeeded = false;
        
        id<MTHttpWorkerBehaviourDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(httpWorkerBehaviourAllowsNewWorkerCreation:)])
            [delegate httpWorkerBehaviourAllowsNewWorkerCreation:self];
    }];
}

@end
