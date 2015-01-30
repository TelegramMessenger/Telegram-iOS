#import "SMetaDisposable.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface SMetaDisposable ()
{
    //volatile OSSpinLock _lock;
    pthread_mutex_t _mutex;
    id<SDisposable> _disposable;
}

@end

@implementation SMetaDisposable

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, NULL);
    }
    return self;
}

- (void)setDisposable:(id<SDisposable>)disposable
{
    id<SDisposable> currentDisposable = nil;
    //OSSpinLockLock(&_lock);
    pthread_mutex_lock(&_mutex);
    currentDisposable = _disposable;
    _disposable = disposable;
    //OSSpinLockUnlock(&lock);
    pthread_mutex_unlock(&_mutex);
    
    [currentDisposable dispose];
}

- (void)dispose
{
    id<SDisposable> disposable = nil;
    pthread_mutex_lock(&_mutex);
    disposable = _disposable;
    _disposable = nil;
    pthread_mutex_unlock(&_mutex);
    
    [disposable dispose];
}

@end
