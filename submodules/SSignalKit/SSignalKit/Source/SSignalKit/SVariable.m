#import "SVariable.h"

#import <os/lock.h>

#import "SSignal.h"
#import "SBag.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"

@interface SVariable ()
{
    os_unfair_lock _lock;
    id _value;
    bool _hasValue;
    SBag *_subscribers;
    SMetaDisposable *_disposable;
}

@end

@implementation SVariable

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _subscribers = [[SBag alloc] init];
        _disposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        os_unfair_lock_lock(&self->_lock);
        id currentValue = _value;
        bool hasValue = _hasValue;
        NSInteger index = [self->_subscribers addItem:[^(id value)
        {
            [subscriber putNext:value];
        } copy]];
        os_unfair_lock_unlock(&self->_lock);
        
        if (hasValue)
        {
            [subscriber putNext:currentValue];
        }
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            os_unfair_lock_lock(&self->_lock);
            [self->_subscribers removeItem:index];
            os_unfair_lock_unlock(&self->_lock);
        }];
    }];
}

- (void)set:(SSignal *)signal
{
    os_unfair_lock_lock(&_lock);
    _hasValue = false;
    os_unfair_lock_unlock(&_lock);
    
    __weak SVariable *weakSelf = self;
    [_disposable setDisposable:[signal startWithNext:^(id next)
    {
        __strong SVariable *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            NSArray *subscribers = nil;
            os_unfair_lock_lock(&strongSelf->_lock);
            strongSelf->_value = next;
            strongSelf->_hasValue = true;
            subscribers = [strongSelf->_subscribers copyItems];
            os_unfair_lock_unlock(&strongSelf->_lock);
            
            for (void (^subscriber)(id) in subscribers)
            {
                subscriber(next);
            }
        }
    }]];
}

@end
