#import <MtProtoKit/MTDisposable.h>

#import <os/lock.h>
#import <libkern/OSAtomic.h>
#import <stdatomic.h>
#import <objc/runtime.h>

@interface MTBlockDisposable ()
{
    void *_block;
}

@end

@implementation MTBlockDisposable

- (instancetype)initWithBlock:(void (^)())block
{
    self = [super init];
    if (self != nil)
    {
        _block = (__bridge_retained void *)[block copy];
    }
    return self;
}

- (void)dealloc
{
    void *block = _block;
    if (block != NULL)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (OSAtomicCompareAndSwapPtr(block, 0, &_block))
        {
            if (block != nil)
            {
                __unused __strong id strongBlock = (__bridge_transfer id)block;
                strongBlock = nil;
            }
        }
#pragma clang diagnostic pop
    }
}

- (void)dispose
{
    void *block = _block;
    if (block != NULL)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (OSAtomicCompareAndSwapPtr(block, 0, &_block))
        {
            if (block != nil)
            {
                __strong id strongBlock = (__bridge_transfer id)block;
                ((dispatch_block_t)strongBlock)();
                strongBlock = nil;
            }
        }
#pragma clang diagnostic pop
    }
}

@end

@interface MTMetaDisposable ()
{
    os_unfair_lock _lock;
    bool _disposed;
    id<MTDisposable> _disposable;
}

@end

@implementation MTMetaDisposable

- (void)setDisposable:(id<MTDisposable>)disposable
{
    id<MTDisposable> previousDisposable = nil;
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
    id<MTDisposable> disposable = nil;
    
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

@interface MTDisposableSet ()
{
    os_unfair_lock _lock;
    bool _disposed;
    id<MTDisposable> _singleDisposable;
    NSArray *_multipleDisposables;
}

@end

@implementation MTDisposableSet

- (void)add:(id<MTDisposable>)disposable
{
    if (disposable == nil)
        return;
    
    bool dispose = false;
    
    os_unfair_lock_lock(&_lock);
    dispose = _disposed;
    if (!dispose)
    {
        if (_multipleDisposables != nil)
        {
            NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithArray:_multipleDisposables];
            [multipleDisposables addObject:disposable];
            _multipleDisposables = multipleDisposables;
        }
        else if (_singleDisposable != nil)
        {
            NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithObjects:_singleDisposable, disposable, nil];
            _multipleDisposables = multipleDisposables;
            _singleDisposable = nil;
        }
        else
        {
            _singleDisposable = disposable;
        }
    }
    os_unfair_lock_unlock(&_lock);
    
    if (dispose)
        [disposable dispose];
}

- (void)remove:(id<MTDisposable>)disposable {
    os_unfair_lock_lock(&_lock);
    if (_multipleDisposables != nil)
    {
        NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithArray:_multipleDisposables];
        [multipleDisposables removeObject:disposable];
        _multipleDisposables = multipleDisposables;
    }
    else if (_singleDisposable == disposable)
    {
        _singleDisposable = nil;
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)dispose
{
    id<MTDisposable> singleDisposable = nil;
    NSArray *multipleDisposables = nil;
    
    os_unfair_lock_lock(&_lock);
    if (!_disposed)
    {
        _disposed = true;
        singleDisposable = _singleDisposable;
        multipleDisposables = _multipleDisposables;
        _singleDisposable = nil;
        _multipleDisposables = nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (singleDisposable != nil)
        [singleDisposable dispose];
    if (multipleDisposables != nil)
    {
        for (id<MTDisposable> disposable in multipleDisposables)
        {
            [disposable dispose];
        }
    }
}

@end
