#import "SAtomic.h"

#import <libkern/OSAtomic.h>

@interface SAtomic ()
{
    volatile OSSpinLock _lock;
    id _value;
}

@end

@implementation SAtomic

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
    OSSpinLockLock(&_lock);
    previousValue = _value;
    _value = newValue;
    OSSpinLockUnlock(&_lock);
    return previousValue;
}

- (id)value
{
    id previousValue = nil;
    OSSpinLockLock(&_lock);
    previousValue = _value;
    OSSpinLockUnlock(&_lock);
    
    return previousValue;
}

- (id)modify:(id (^)(id))f
{
    id newValue = nil;
    OSSpinLockLock(&_lock);
    newValue = f(_value);
    _value = newValue;
    OSSpinLockUnlock(&_lock);
    return newValue;
}

- (id)with:(id (^)(id))f
{
    id result = nil;
    OSSpinLockLock(&_lock);
    result = f(_value);
    OSSpinLockUnlock(&_lock);
    return result;
}

@end
