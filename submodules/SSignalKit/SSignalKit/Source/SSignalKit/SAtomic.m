#import "SAtomic.h"

#import <pthread.h>

@interface SAtomic ()
{
    pthread_mutex_t _lock;
    pthread_mutexattr_t _attr;
    bool _isRecursive;
    id _value;
}

@end

@implementation SAtomic

- (instancetype)initWithValue:(id)value
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _value = value;
    }
    return self;
}

- (instancetype)initWithValue:(id)value recursive:(bool)recursive {
    self = [super init];
    if (self != nil)
    {
        _isRecursive = recursive;
        
        if (recursive) {
            pthread_mutexattr_init(&_attr);
            pthread_mutexattr_settype(&_attr, PTHREAD_MUTEX_RECURSIVE);
            pthread_mutex_init(&_lock, &_attr);
        } else {
            pthread_mutex_init(&_lock, NULL);
        }
        
        _value = value;
    }
    return self;
}

- (void)dealloc {
    if (_isRecursive) {
        pthread_mutexattr_destroy(&_attr);
    }
    pthread_mutex_destroy(&_lock);
}

- (id)swap:(id)newValue
{
    id previousValue = nil;
    pthread_mutex_lock(&_lock);
    previousValue = _value;
    _value = newValue;
    pthread_mutex_unlock(&_lock);
    return previousValue;
}

- (id)value
{
    id previousValue = nil;
    pthread_mutex_lock(&_lock);
    previousValue = _value;
    pthread_mutex_unlock(&_lock);
    
    return previousValue;
}

- (id)modify:(id (^)(id))f
{
    id newValue = nil;
    pthread_mutex_lock(&_lock);
    newValue = f(_value);
    _value = newValue;
    pthread_mutex_unlock(&_lock);
    return newValue;
}

- (id)with:(id (^)(id))f
{
    id result = nil;
    pthread_mutex_lock(&_lock);
    result = f(_value);
    pthread_mutex_unlock(&_lock);
    return result;
}

@end
