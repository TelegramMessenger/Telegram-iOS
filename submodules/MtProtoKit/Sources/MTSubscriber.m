#import <MtProtoKit/MTSubscriber.h>

#import <os/lock.h>

@interface MTSubscriberBlocks : NSObject {
@public
    void (^_next)(id);
    void (^_error)(id);
    void (^_completed)();
}

@end

@implementation MTSubscriberBlocks

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

@interface MTSubscriber ()
{
@protected
    os_unfair_lock _lock;
    bool _terminated;
    id<MTDisposable> _disposable;
    MTSubscriberBlocks *_blocks;
}

@end

@implementation MTSubscriber

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super init];
    if (self != nil)
    {
        _blocks = [[MTSubscriberBlocks alloc] initWithNext:next error:error completed:completed];
    }
    return self;
}

- (void)_assignDisposable:(id<MTDisposable>)disposable
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
    MTSubscriberBlocks *blocks = nil;
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
    MTSubscriberBlocks *blocks = nil;
    
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
    MTSubscriberBlocks *blocks = nil;
    
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
    MTSubscriberBlocks *blocks = nil;
    
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
