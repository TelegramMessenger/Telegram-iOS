#import "SDisposableSet.h"

#import "SSignal.h"

#import <libkern/OSAtomic.h>

@interface SDisposableSet ()
{
    OSSpinLock _lock;
    bool _disposed;
    id<SDisposable> _singleDisposable;
    NSArray *_multipleDisposables;
}

@end

@implementation SDisposableSet

- (void)add:(id<SDisposable>)disposable
{
    if (disposable == nil)
        return;
    
    bool dispose = false;
    
    OSSpinLockLock(&_lock);
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
    OSSpinLockUnlock(&_lock);
    
    if (dispose)
        [disposable dispose];
}

- (void)remove:(id<SDisposable>)disposable {
    OSSpinLockLock(&_lock);
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
    OSSpinLockUnlock(&_lock);
}

- (void)dispose
{
    id<SDisposable> singleDisposable = nil;
    NSArray *multipleDisposables = nil;
    
    OSSpinLockLock(&_lock);
    if (!_disposed)
    {
        _disposed = true;
        singleDisposable = _singleDisposable;
        multipleDisposables = _multipleDisposables;
        _singleDisposable = nil;
        _multipleDisposables = nil;
    }
    OSSpinLockUnlock(&_lock);
    
    if (singleDisposable != nil)
        [singleDisposable dispose];
    if (multipleDisposables != nil)
    {
        for (id<SDisposable> disposable in multipleDisposables)
        {
            [disposable dispose];
        }
    }
}

@end
