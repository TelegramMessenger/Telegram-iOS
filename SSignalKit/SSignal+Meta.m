#import "SSignal+Meta.h"

#import "SDisposableSet.h"
#import "SMetaDisposable.h"
#import "SSignal+Mapping.h"
#import "SAtomic.h"

#import <libkern/OSAtomic.h>

@interface SSignalSwitchToLatestState : NSObject <SDisposable>
{
    OSSpinLock _lock;
    bool _didSwitch;
    bool _terminated;
    
    id<SDisposable> _disposable;
    SMetaDisposable *_currentDisposable;
    SSubscriber *_subscriber;
}

@end

@implementation SSignalSwitchToLatestState

- (instancetype)initWithSubscriber:(SSubscriber *)subscriber
{
    self = [super init];
    if (self != nil)
    {
        _subscriber = subscriber;
        _currentDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)beginWithDisposable:(id<SDisposable>)disposable
{
    _disposable = disposable;
}

- (void)switchToSignal:(SSignal *)signal
{
    OSSpinLockLock(&_lock);
    _didSwitch = true;
    OSSpinLockUnlock(&_lock);
    
    id<SDisposable> disposable = [signal startWithNext:^(id next)
    {
        [_subscriber putNext:next];
    } error:^(id error)
    {
        [_subscriber putError:error];
    } completed:^
    {
        OSSpinLockLock(&_lock);
        _didSwitch = false;
        OSSpinLockUnlock(&_lock);
        
        [self maybeComplete];
    }];
    
    [_currentDisposable setDisposable:disposable];
}

- (void)maybeComplete
{
    bool terminated = false;
    OSSpinLockLock(&_lock);
    terminated = _terminated;
    OSSpinLockUnlock(&_lock);
    
    if (terminated)
        [_subscriber putCompletion];
}

- (void)beginCompletion
{
    bool didSwitch = false;
    OSSpinLockLock(&_lock);
    didSwitch = _didSwitch;
    _terminated = true;
    OSSpinLockUnlock(&_lock);
    
    if (!didSwitch)
        [_subscriber putCompletion];
}

- (void)dispose
{
    [_disposable dispose];
    [_currentDisposable dispose];
}

@end

@implementation SSignal (Meta)

- (SSignal *)switchToLatest
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SSignalSwitchToLatestState *state = [[SSignalSwitchToLatestState alloc] initWithSubscriber:subscriber];
        
        [state beginWithDisposable:[self startWithNext:^(id next)
        {
            [state switchToSignal:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [state beginCompletion];
        }]];
        
        return state;
    }];
}

- (SSignal *)mapToSignal:(SSignal *(^)(id))f
{
    return [[self map:f] switchToLatest];
}

- (SSignal *)then:(SSignal *)signal
{
    SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];
    
    SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
    [compositeDisposable add:currentDisposable];
    
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [currentDisposable setDisposable:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [compositeDisposable add:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        }]];
        
        return compositeDisposable;
    }];
}

@end
