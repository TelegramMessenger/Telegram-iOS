#import "SSubscriber.h"

#import <os/lock.h>

@interface SSubscriberBlocks : NSObject {
    @public
    void (^_next)(id);
    void (^_error)(id);
    void (^_completed)();
}

@end

@implementation SSubscriberBlocks

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed {
    self = [super init];
    if (self != nil) {
        _next = [next copy];
        _error = [error copy];
        _completed = [completed copy];
    }
    return self;
}

@end

@interface SSubscriber ()
{
    @protected
    os_unfair_lock _lock;
    bool _terminated;
    id<SDisposable> _disposable;
    SSubscriberBlocks *_blocks;
}

@end

@implementation SSubscriber

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super init];
    if (self != nil)
    {
        _blocks = [[SSubscriberBlocks alloc] initWithNext:next error:error completed:completed];
    }
    return self;
}

- (void)_assignDisposable:(id<SDisposable>)disposable
{
    bool dispose = false;
    os_unfair_lock_lock(&_lock);
    if (_terminated) {
        dispose = true;
    } else {
        _disposable = disposable;
    }
    os_unfair_lock_unlock(&_lock);
    if (dispose) {
        [disposable dispose];
    }
}

- (void)_markTerminatedWithoutDisposal
{
    os_unfair_lock_lock(&_lock);
    SSubscriberBlocks *blocks = nil;
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        _terminated = true;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (blocks) {
        blocks = nil;
    }
}

- (void)putNext:(id)next
{
    SSubscriberBlocks *blocks = nil;
    
    os_unfair_lock_lock(&_lock);
    if (!_terminated) {
        blocks = _blocks;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (blocks && blocks->_next) {
        blocks->_next(next);
    }
}

- (void)putError:(id)error
{
    bool shouldDispose = false;
    SSubscriberBlocks *blocks = nil;
    
    os_unfair_lock_lock(&_lock);
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        shouldDispose = true;
        _terminated = true;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (blocks && blocks->_error) {
        blocks->_error(error);
    }
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)putCompletion
{
    bool shouldDispose = false;
    SSubscriberBlocks *blocks = nil;
    
    os_unfair_lock_lock(&_lock);
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        shouldDispose = true;
        _terminated = true;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (blocks && blocks->_completed)
        blocks->_completed();
    
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
    self = [super initWithNext:next error:error completed:completed];
    if (self != nil)
    {
        _name = name;
    }
    return self;
}

/*- (void)_assignDisposable:(id<SDisposable>)disposable
{
    if (_terminated)
        [disposable dispose];
    else
        _disposable = disposable;
}

- (void)_markTerminatedWithoutDisposal
{
    os_unfair_lock_lock(&_lock);
    if (!_terminated)
    {
        NSLog(@"trace(%@ terminated)", _name);
        _terminated = true;
        _next = nil;
        _error = nil;
        _completed = nil;
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)putNext:(id)next
{
    void (^fnext)(id) = nil;
    
    os_unfair_lock_lock(&_lock);
    if (!_terminated)
        fnext = self->_next;
    os_unfair_lock_unlock(&_lock);
    
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
    
    os_unfair_lock_lock(&_lock);
    if (!_terminated)
    {
        ferror = self->_error;
        shouldDispose = true;
        self->_next = nil;
        self->_error = nil;
        self->_completed = nil;
        _terminated = true;
    }
    os_unfair_lock_unlock(&_lock);
    
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
    
    os_unfair_lock_lock(&_lock);
    if (!_terminated)
    {
        completed = self->_completed;
        shouldDispose = true;
        self->_next = nil;
        self->_error = nil;
        self->_completed = nil;
        _terminated = true;
    }
    os_unfair_lock_unlock(&_lock);
    
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
}*/

@end
