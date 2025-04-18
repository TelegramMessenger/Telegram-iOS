#import "NSObject+TGLock.h"

#import <objc/runtime.h>

static const char *lockPropertyKey = "TGObjectLock::lock";

@interface TGObjectLockImpl : NSObject
{
    TG_SYNCHRONIZED_DEFINE(objectLock);
}

- (void)tgTakeLock;
- (void)tgFreeLock;

@end

@implementation TGObjectLockImpl

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        TG_SYNCHRONIZED_INIT(objectLock);
    }
    return self;
}

- (void)tgTakeLock
{
    TG_SYNCHRONIZED_BEGIN(objectLock);
}

- (void)tgFreeLock
{
    TG_SYNCHRONIZED_END(objectLock);
}

@end

@implementation NSObject (TGLock)

- (void)tgLockObject
{
    TGObjectLockImpl *lock = (TGObjectLockImpl *)objc_getAssociatedObject(self, lockPropertyKey);
    if (lock == nil)
    {
        @synchronized(self)
        {
            lock = [[TGObjectLockImpl alloc] init];
            objc_setAssociatedObject(self, lockPropertyKey, lock, OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    [lock tgTakeLock];
}

- (void)tgUnlockObject
{
    TGObjectLockImpl *lock = (TGObjectLockImpl *)objc_getAssociatedObject(self, lockPropertyKey);
    if (lock == nil)
    {
        @synchronized(self)
        {
            lock = [[TGObjectLockImpl alloc] init];
            objc_setAssociatedObject(self, lockPropertyKey, lock, OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    [lock tgFreeLock];
}

@end
