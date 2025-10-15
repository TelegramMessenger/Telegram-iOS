#import <MtProtoKit/MTAtomic.h>

#import <os/lock.h>

@interface MTAtomic ()
{
    os_unfair_lock _lock;
    id _value;
}

@end

@implementation MTAtomic

- (instancetype)initWithValue:(id)value
{
    self = [super init];
    if (self != nil)
    {
        _value = value;
    }
    return self;
}

- (id)swap:(id)newValue
{
    id previousValue = nil;
    os_unfair_lock_lock(&_lock);
    previousValue = _value;
    _value = newValue;
    os_unfair_lock_unlock(&_lock);
    return previousValue;
}

- (id)value
{
    id previousValue = nil;
    os_unfair_lock_lock(&_lock);
    previousValue = _value;
    os_unfair_lock_unlock(&_lock);
    
    return previousValue;
}

- (id)modify:(id (^)(id))f
{
    id newValue = nil;
    os_unfair_lock_lock(&_lock);
    newValue = f(_value);
    _value = newValue;
    os_unfair_lock_unlock(&_lock);
    return newValue;
}

- (id)with:(id (^)(id))f
{
    id result = nil;
    os_unfair_lock_lock(&_lock);
    result = f(_value);
    os_unfair_lock_unlock(&_lock);
    return result;
}

@end
