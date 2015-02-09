#import "SSubscriber.h"

#import <pthread.h>

#import "SEvent.h"

#define lockSelf(x) pthread_mutex_lock(&x->_mutex)
#define unlockSelf(x) pthread_mutex_unlock(&x->_mutex)

@interface SSubscriber ()
{
    pthread_mutex_t _mutex;
    
    id<SDisposable> _disposable;
}

@end

@implementation SSubscriber

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, NULL);
        _next = [next copy];
        _error = [error copy];
        _completed = [completed copy];
    }
    return self;
}

- (void)_assignDisposable:(id<SDisposable>)disposable
{
    _disposable = disposable;
}

- (void)putEvent:(SEvent *)event
{
    bool shouldDispose = false;
    void (^next)(id) = nil;
    void (^error)(id) = nil;
    void (^completed)(id) = nil;
    
    lockSelf(self);
    next = self->_next;
    error = self->_error;
    completed = self->_completed;
    if (event.type != SEventTypeNext)
    {
        shouldDispose = true;
        self->_next = nil;
        self->_error = nil;
        self->_completed = nil;
    }
    unlockSelf(self);
    
    switch (event.type)
    {
        case SEventTypeNext:
            if (next)
                next(event.data);
            break;
        case SEventTypeError:
            if (error)
                error(event.data);
            break;
        case SEventTypeCompleted:
            if (completed)
                completed(event.data);
            break;
    }
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)putNext:(id)next
{
    void (^fnext)(id) = nil;
    
    lockSelf(self);
    fnext = self->_next;
    unlockSelf(self);
    
    if (fnext)
        fnext(next);
}

- (void)putError:(id)error
{
    bool shouldDispose = false;
    void (^ferror)(id) = nil;
    
    lockSelf(self);
    ferror = self->_error;
    shouldDispose = true;
    self->_next = nil;
    self->_error = nil;
    self->_completed = nil;
    unlockSelf(self);
    
    if (ferror)
        ferror(error);
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)putCompletion
{
    bool shouldDispose = false;
    void (^completed)() = nil;
    
    lockSelf(self);
    completed = self->_completed;
    shouldDispose = true;
    self->_next = nil;
    self->_error = nil;
    self->_completed = nil;
    unlockSelf(self);
    
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
