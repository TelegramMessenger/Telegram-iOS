#import <MtProtoKit/MTSubscriber.h>

#import <libkern/OSAtomic.h>

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
    OSSpinLock _lock;
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
    OSSpinLockLock(&_lock);
    if (_terminated) {
        dispose = true;
    } else {
        _disposable = disposable;
    }
    OSSpinLockUnlock(&_lock);
    
    if (dispose) {
        [disposable dispose];
    }
}

- (void)_markTerminatedWithoutDisposal
{
    id<MTDisposable> disposable = nil;
    
    OSSpinLockLock(&_lock);
    MTSubscriberBlocks *blocks = nil;
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        disposable = _disposable;
        _disposable = nil;
        
        _terminated = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (blocks) {
        blocks = nil;
    }
    
    if (disposable) {
        disposable = nil;
    }
}

- (void)putNext:(id)next
{
    MTSubscriberBlocks *blocks = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated) {
        blocks = _blocks;
    }
    OSSpinLockUnlock(&_lock);
    
    if (blocks && blocks->_next) {
        blocks->_next(next);
    }
}

- (void)putError:(id)error
{
    id<MTDisposable> disposable = nil;
    MTSubscriberBlocks *blocks = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        disposable = _disposable;
        _disposable = nil;
        
        _terminated = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (blocks && blocks->_error) {
        blocks->_error(error);
    }
    
    [disposable dispose];
}

- (void)putCompletion
{
    id<MTDisposable> disposable = nil;
    MTSubscriberBlocks *blocks = nil;
    
    OSSpinLockLock(&_lock);
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        disposable = _disposable;
        _disposable = nil;
        
        _terminated = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (blocks && blocks->_completed)
        blocks->_completed();
    
    [disposable dispose];
}

@end
