#import "SBlockDisposable.h"

#import <os/lock.h>
#import <objc/runtime.h>
#import <pthread/pthread.h>

@interface SBlockDisposable () {
    void (^_action)();
    pthread_mutex_t _lock;
}

@end

@implementation SBlockDisposable

- (instancetype)initWithBlock:(void (^)())block
{
    self = [super init];
    if (self != nil)
    {
        _action = [block copy];
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (void)dealloc {
    void (^freeAction)() = nil;
    pthread_mutex_lock(&_lock);
    freeAction = _action;
    _action = nil;
    pthread_mutex_unlock(&_lock);
    
    if (freeAction) {
    }
    
    pthread_mutex_destroy(&_lock);
}

- (void)dispose {
    void (^disposeAction)() = nil;
    
    pthread_mutex_lock(&_lock);
    disposeAction = _action;
    _action = nil;
    pthread_mutex_unlock(&_lock);
    
    if (disposeAction) {
        disposeAction();
    }
}

@end
