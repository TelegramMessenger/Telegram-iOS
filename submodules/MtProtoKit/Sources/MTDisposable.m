#import <MtProtoKit/MTDisposable.h>

#import <pthread/pthread.h>
#import <objc/runtime.h>

@interface MTBlockDisposable () {
    void (^_action)();
    pthread_mutex_t _lock;
}

@end

@implementation MTBlockDisposable

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

@interface MTMetaDisposable ()
{
    pthread_mutex_t _lock;
    bool _disposed;
    id<MTDisposable> _disposable;
}

@end

@implementation MTMetaDisposable

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (void)dealloc {
    id<MTDisposable> freeDisposable = nil;
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

- (void)setDisposable:(id<MTDisposable>)disposable {
    id<MTDisposable> previousDisposable = nil;
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
    id<MTDisposable> disposable = nil;
    
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

@interface MTDisposableSet ()
{
    pthread_mutex_t _lock;
    bool _disposed;
    NSMutableArray<id<MTDisposable>> *_disposables;
}

@end

@implementation MTDisposableSet

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        pthread_mutex_init(&_lock, nil);
        _disposables = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    NSArray<id<MTDisposable>> *disposables = nil;
    pthread_mutex_lock(&_lock);
    disposables = _disposables;
    _disposables = nil;
    pthread_mutex_unlock(&_lock);
    
    if (disposables) {
    }
    pthread_mutex_destroy(&_lock);
}

- (void)add:(id<MTDisposable>)disposable {
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

- (void)remove:(id<MTDisposable>)disposable {
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
    NSArray<id<MTDisposable>> *disposables = nil;
    pthread_mutex_lock(&_lock);
    if (!_disposed) {
        _disposed = true;
        disposables = _disposables;
        _disposables = nil;
    }
    pthread_mutex_unlock(&_lock);
    
    if (disposables) {
        for (id<MTDisposable> disposable in disposables) {
            [disposable dispose];
        }
    }
}

@end
