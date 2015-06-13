#import "SSubscriber.h"

#import <libkern/OSAtomic.h>

@interface SSubscriber ()
{
    @protected
    OSSpinLock _lock;
    bool _terminated;
    id<SDisposable> _disposable;
}

@end

@implementation SSubscriber

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super init];
    if (self != nil)
    {
        _next = [next copy];
        _error = [error copy];
        _completed = [completed copy];
    }
    return self;
}

- (void)_assignDisposable:(id<SDisposable>)disposable
{
    if (_terminated)
        [disposable dispose];
    else
        _disposable = disposable;
}

- (void)_markTerminatedWithoutDisposal
{
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        _terminated = true;
        _next = nil;
        _error = nil;
        _completed = nil;
    }
    OSSpinLockUnlock(&_lock);
}

- (void)putNext:(id)next
{
    void (^fnext)(id) = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
        fnext = self->_next;
    OSSpinLockUnlock(&_lock);
    
    if (fnext)
        fnext(next);
}

- (void)putError:(id)error
{
    bool shouldDispose = false;
    void (^ferror)(id) = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        ferror = self->_error;
        shouldDispose = true;
        self->_next = nil;
        self->_error = nil;
        self->_completed = nil;
        _terminated = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (ferror)
        ferror(error);
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)putCompletion
{
    bool shouldDispose = false;
    void (^completed)() = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        completed = self->_completed;
        shouldDispose = true;
        self->_next = nil;
        self->_error = nil;
        self->_completed = nil;
        _terminated = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (completed)
        completed();
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)dispose
{
    [self->_disposable dispose];
}

@end

@interface STracingSubscriber ()
{
    NSString *_name;
}

@end

@implementation STracingSubscriber

- (instancetype)initWithName:(NSString *)name next:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super init];
    if (self != nil)
    {
        _name = name;
        _next = [next copy];
        _error = [error copy];
        _completed = [completed copy];
    }
    return self;
}

- (void)_assignDisposable:(id<SDisposable>)disposable
{
    if (_terminated)
        [disposable dispose];
    else
        _disposable = disposable;
}

- (void)_markTerminatedWithoutDisposal
{
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        NSLog(@"trace(%@ terminated)", _name);
        _terminated = true;
        _next = nil;
        _error = nil;
        _completed = nil;
    }
    OSSpinLockUnlock(&_lock);
}

- (void)putNext:(id)next
{
    void (^fnext)(id) = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
        fnext = self->_next;
    OSSpinLockUnlock(&_lock);
    
    if (fnext)
    {
        NSLog(@"trace(%@ next: %@)", _name, next);
        fnext(next);
    }
    else
        NSLog(@"trace(%@ next: %@, not accepted)", _name, next);
}

- (void)putError:(id)error
{
    bool shouldDispose = false;
    void (^ferror)(id) = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        ferror = self->_error;
        shouldDispose = true;
        self->_next = nil;
        self->_error = nil;
        self->_completed = nil;
        _terminated = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (ferror)
    {
        NSLog(@"trace(%@ error: %@)", _name, error);
        ferror(error);
    }
    else
        NSLog(@"trace(%@ error: %@, not accepted)", _name, error);
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)putCompletion
{
    bool shouldDispose = false;
    void (^completed)() = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        completed = self->_completed;
        shouldDispose = true;
        self->_next = nil;
        self->_error = nil;
        self->_completed = nil;
        _terminated = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (completed)
    {
        NSLog(@"trace(%@ completed)", _name);
        completed();
    }
    else
        NSLog(@"trace(%@ completed, not accepted)", _name);
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)dispose
{
    NSLog(@"trace(%@ dispose)", _name);
    [self->_disposable dispose];
}

@end
