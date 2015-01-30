#import "SCompositeDisposable.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface SCompositeDisposable ()
{
    //volatile OSSpinLock _lock;
    pthread_mutex_t _mutex;
    NSMutableArray *_disposables;
}

@end

@implementation SCompositeDisposable

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, NULL);
    }
    return self;
}

- (void)add:(id<SDisposable>)disposable
{
    if (disposable != nil)
    {
        //OSSpinLockLock(&_lock);
        pthread_mutex_lock(&_mutex);
        if (_disposables == nil)
            _disposables = [[NSMutableArray alloc] init];
        [_disposables addObject:disposable];
        //OSSpinLockUnlock(&_lock);
        pthread_mutex_unlock(&_mutex);
    }
}

- (void)dispose
{
    NSArray *disposables = nil;
    //OSSpinLockLock(&_lock);
    pthread_mutex_lock(&_mutex);
    disposables = _disposables;
    _disposables = nil;
    //OSSpinLockUnlock(&_lock);
    pthread_mutex_unlock(&_mutex);
    
    if (disposables != nil)
    {
        for (id<SDisposable> disposable in disposables)
        {
            [disposable dispose];
        }
    }
}

@end
