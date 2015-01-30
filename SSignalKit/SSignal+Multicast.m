#import "SSignal+Multicast.h"

#import <libkern/OSAtomic.h>
#import "SBag.h"
#import "SBlockDisposable.h"

typedef enum {
    SSignalMulticastStateReady,
    SSignalMulticastStateStarted,
    SSignalMulticastStateCompleted
} SSignalMulticastState;

@interface SSignalMulticastSubscribers : NSObject
{
    volatile OSSpinLock _lock;
    SBag *_subscribers;
    SSignalMulticastState _state;
    id<SDisposable> _disposable;
}

@end

@implementation SSignalMulticastSubscribers

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _subscribers = [[SBag alloc] init];
    }
    return self;
}

- (void)setDisposable:(id<SDisposable>)disposable
{
    [_disposable dispose];
    _disposable = disposable;
}

- (bool)addSubscriber:(SSubscriber *)subscriber
{
    bool start = false;
    
    OSSpinLockLock(&_lock);
    NSInteger index = [_subscribers addItem:subscriber];
    switch (_state) {
        case SSignalMulticastStateReady:
            start = true;
            _state = SSignalMulticastStateStarted;
            break;
        default:
            break;
    }
    OSSpinLockUnlock(&_lock);
    
    [subscriber addDisposable:[[SBlockDisposable alloc] initWithBlock:^
    {
        [self remove:index];
    }]];
    
    return start;
}

- (void)remove:(NSInteger)index
{
    id<SDisposable> currentDisposable = nil;
    
    OSSpinLockLock(&_lock);
    [_subscribers removeItem:index];
    switch (_state) {
        case SSignalMulticastStateStarted:
            if ([_subscribers isEmpty])
            {
                currentDisposable = _disposable;
                _disposable = nil;
            }
            break;
        default:
            break;
    }
    OSSpinLockUnlock(&_lock);
    
    [currentDisposable dispose];
}

- (void)notify:(SEvent *)event
{
    NSArray *currentSubscribers = nil;
    OSSpinLockLock(&_lock);
    currentSubscribers = [_subscribers copyItems];
    if (event.type != SEventTypeNext)
        _state = SSignalMulticastStateCompleted;
    OSSpinLockUnlock(&_lock);
    
    for (SSubscriber *subscriber in currentSubscribers)
    {
        SSubscriber_putEvent(subscriber, event);
    }
}

@end

@implementation SSignal (Multicast)

- (SSignal *)multicast
{
    SSignalMulticastSubscribers *subscribers = [[SSignalMulticastSubscribers alloc] init];
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        if ([subscribers addSubscriber:subscriber])
        {
            id<SDisposable> disposable = [self startWithNext:^(id next)
            {
                [subscribers notify:[[SEvent alloc] initWithNext:next]];
            } error:^(id error)
            {
                [subscribers notify:[[SEvent alloc] initWithError:error]];
            } completed:^
            {
                [subscribers notify:[[SEvent alloc] initWithCompleted]];
            }];
            [subscribers setDisposable:[[SBlockDisposable alloc] initWithBlock:^
            {
                [disposable dispose];
            }]];
        }
    }];
}

@end
