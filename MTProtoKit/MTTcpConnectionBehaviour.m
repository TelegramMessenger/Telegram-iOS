/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import "MTTcpConnectionBehaviour.h"

#import "MTTimer.h"
#import "MTQueue.h"

@interface MTTcpConnectionBehaviour ()
{
    MTTimer *_backoffTimer;
    NSInteger _backoffCount;
}

@end

@implementation MTTcpConnectionBehaviour

- (instancetype)initWithQueue:(MTQueue *)queue
{
    self = [super init];
    if (self != nil)
    {
        _queue = queue;
        
        _needsReconnection = true;
    }
    return self;
}

- (void)dealloc
{
    [self invalidateTimer];
}

- (void)requestConnection
{
    if (_backoffTimer == nil)
    {
        [self timerEvent];
    }
}

- (void)connectionOpened
{
    //_backoffCount = 0;
    
    //[self invalidateTimer];
}

- (void)connectionValidDataReceived
{
    _backoffCount = 0;
    
    [self invalidateTimer];
}

- (void)connectionClosed
{
    if (_needsReconnection)
    {
        _backoffCount++;
        
        if (_backoffCount == 1)
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
    }
}

- (void)clearBackoff
{
    _backoffCount = 0;
}

- (void)invalidateTimer
{
    MTTimer *reconnectionTimer = _backoffTimer;
    _backoffTimer = nil;
    
    [_queue dispatchOnQueue:^
    {
        [reconnectionTimer invalidate];
    }];
}

- (void)startTimer:(NSTimeInterval)timeout
{
    [self invalidateTimer];
    
    [_queue dispatchOnQueue:^
    {
        __weak MTTcpConnectionBehaviour *weakSelf = self;
        _backoffTimer = [[MTTimer alloc] initWithTimeout:timeout repeat:false completion:^
        {
            __strong MTTcpConnectionBehaviour *strongSelf = weakSelf;
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
        id<MTTcpConnectionBehaviourDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionBehaviourRequestsReconnection:)])
            [delegate tcpConnectionBehaviourRequestsReconnection:self];
    }];
}

@end
