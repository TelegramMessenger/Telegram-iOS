#import "SSubscriber.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>

#import "SEvent.h"

#define lockSelf(x) pthread_mutex_lock(&x->_mutex)
#define unlockSelf(x) pthread_mutex_unlock(&x->_mutex)

@interface SSubscriber ()
{
    @public
    //volatile OSSpinLock _lock;
    pthread_mutex_t _mutex;
    void (^_next)(id);
    void (^_error)(id);
    void (^_completed)();
    
    SCompositeDisposable *_disposable;
}

@end

@implementation SSubscriber

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, NULL);
        _disposable = [[SCompositeDisposable alloc] init];
        _next = [next copy];
        _error = [error copy];
        _completed = [completed copy];
    }
    return self;
}

- (id<SDisposable>)_disposable
{
    return _disposable;
}

- (void)addDisposable:(id<SDisposable>)disposable
{
    [_disposable add:disposable];
}

- (void)putEvent:(SEvent *)event
{
    SSubscriber_putEvent(self, event);
}

- (void)putNext:(id)next
{
    [self putEvent:[[SEvent alloc] initWithNext:next]];
}

- (void)putError:(id)error
{
    [self putEvent:[[SEvent alloc] initWithError:error]];
}

- (void)putCompletion
{
    [self putEvent:[[SEvent alloc] initWithCompleted]];
}

void SSubscriber_putNext(SSubscriber *subscriber, id next)
{
    void (^fnext)(id) = nil;
    
    lockSelf(subscriber);
    fnext = subscriber->_next;
    unlockSelf(subscriber);
    
    if (fnext)
        fnext(next);
}

void SSubscriber_putError(SSubscriber *subscriber, id error)
{
    bool shouldDispose = false;
    void (^ferror)(id) = nil;
    
    lockSelf(subscriber);
    ferror = subscriber->_error;
    shouldDispose = true;
    subscriber->_next = nil;
    subscriber->_error = nil;
    subscriber->_completed = nil;
    unlockSelf(subscriber);
    
    if (ferror)
        ferror(error);
    
    if (shouldDispose)
        [subscriber->_disposable dispose];
}

void SSubscriber_putCompletion(SSubscriber *subscriber)
{
    bool shouldDispose = false;
    void (^completed)() = nil;
    
    lockSelf(subscriber);
    completed = subscriber->_completed;
    shouldDispose = true;
    subscriber->_next = nil;
    subscriber->_error = nil;
    subscriber->_completed = nil;
    unlockSelf(subscriber);
    
    if (completed)
        completed();
    
    if (shouldDispose)
        [subscriber->_disposable dispose];
}

void SSubscriber_putEvent(SSubscriber *subscriber, SEvent *event)
{
    bool shouldDispose = false;
    void (^next)(id) = nil;
    void (^error)(id) = nil;
    void (^completed)(id) = nil;
    
    lockSelf(subscriber);
    next = subscriber->_next;
    error = subscriber->_error;
    completed = subscriber->_completed;
    if (event.type != SEventTypeNext)
    {
        shouldDispose = true;
        subscriber->_next = nil;
        subscriber->_error = nil;
        subscriber->_completed = nil;
    }
    unlockSelf(subscriber);
    
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
        [subscriber->_disposable dispose];
}

@end
