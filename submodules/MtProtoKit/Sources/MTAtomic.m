#import <MtProtoKit/MTAtomic.h>

#import <libkern/OSAtomic.h>

@interface MTAtomic ()
{
    volatile OSSpinLock _lock;
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
