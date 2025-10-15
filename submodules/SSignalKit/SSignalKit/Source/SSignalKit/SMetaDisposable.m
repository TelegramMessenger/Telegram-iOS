#import "SMetaDisposable.h"

#import <pthread/pthread.h>

@interface SMetaDisposable ()
{
    pthread_mutex_t _lock;
    bool _disposed;
    id<SDisposable> _disposable;
}

@end

@implementation SMetaDisposable

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (void)dealloc {
    id<SDisposable> freeDisposable = nil;
    pthread_mutex_lock(&_lock);
    if (_disposable) {
        freeDisposable = _disposable;
        _disposable = nil;
    }
    pthread_mutex_unlock(&_lock);
    
    if (freeDisposable) {
    }
    
    pthread_mutex_destroy(&_lock);
}

- (void)setDisposable:(id<SDisposable>)disposable {
    id<SDisposable> previousDisposable = nil;
    bool disposeImmediately = false;
    
    pthread_mutex_lock(&_lock);
    disposeImmediately = _disposed;
    if (!disposeImmediately) {
        previousDisposable = _disposable;
        _disposable = disposable;
    }
    pthread_mutex_unlock(&_lock);
    
    if (previousDisposable) {
        [previousDisposable dispose];
    }
    
    if (disposeImmediately) {
        [disposable dispose];
    }
}

- (void)dispose {
    id<SDisposable> disposable = nil;
    
    pthread_mutex_lock(&_lock);
    if (!_disposed) {
        _disposed = true;
        disposable = _disposable;
        _disposable = nil;
    }
    pthread_mutex_unlock(&_lock);
    
    if (disposable) {
        [disposable dispose];
    }
}

@end
