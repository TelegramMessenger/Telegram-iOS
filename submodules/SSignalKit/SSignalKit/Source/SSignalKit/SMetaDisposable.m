#import "SMetaDisposable.h"

#import <os/lock.h>

@interface SMetaDisposable ()
{
    os_unfair_lock _lock;
    bool _disposed;
    id<SDisposable> _disposable;
}

@end

@implementation SMetaDisposable

- (void)setDisposable:(id<SDisposable>)disposable
{
    id<SDisposable> previousDisposable = nil;
    bool dispose = false;
    
    os_unfair_lock_lock(&_lock);
    dispose = _disposed;
    if (!dispose)
    {
        previousDisposable = _disposable;
        _disposable = disposable;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (previousDisposable != nil)
        [previousDisposable dispose];
    
    if (dispose)
        [disposable dispose];
}

- (void)dispose
{
    id<SDisposable> disposable = nil;
    
    os_unfair_lock_lock(&_lock);
    if (!_disposed)
    {
        disposable = _disposable;
        _disposed = true;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (disposable != nil)
        [disposable dispose];
}

@end
