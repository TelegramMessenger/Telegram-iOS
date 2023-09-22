#import "SDisposableSet.h"

#import "SSignal.h"

#import <pthread/pthread.h>

@interface SDisposableSet ()
{
    pthread_mutex_t _lock;
    bool _disposed;
    NSMutableArray<id<SDisposable>> *_disposables;
}

@end

@implementation SDisposableSet

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        pthread_mutex_init(&_lock, nil);
        _disposables = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    NSArray<id<SDisposable>> *disposables = nil;
    pthread_mutex_lock(&_lock);
    disposables = _disposables;
    _disposables = nil;
    pthread_mutex_unlock(&_lock);
    
    if (disposables) {
    }
    pthread_mutex_destroy(&_lock);
}

- (void)add:(id<SDisposable>)disposable {
    bool disposeImmediately = false;
    
    pthread_mutex_lock(&_lock);
    if (_disposed) {
        disposeImmediately = true;
    } else {
        [_disposables addObject:disposable];
    }
    pthread_mutex_unlock(&_lock);
    
    if (disposeImmediately) {
        [disposable dispose];
    }
}

- (void)remove:(id<SDisposable>)disposable {
    pthread_mutex_lock(&_lock);
    for (NSInteger i = 0; i < _disposables.count; i++) {
        if (_disposables[i] == disposable) {
            [_disposables removeObjectAtIndex:i];
            break;
        }
    }
    pthread_mutex_unlock(&_lock);
}

- (void)dispose {
    NSArray<id<SDisposable>> *disposables = nil;
    pthread_mutex_lock(&_lock);
    if (!_disposed) {
        _disposed = true;
        disposables = _disposables;
        _disposables = nil;
    }
    pthread_mutex_unlock(&_lock);
    
    if (disposables) {
        for (id<SDisposable> disposable in disposables) {
            [disposable dispose];
        }
    }
}

@end
