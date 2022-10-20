#import "SBlockDisposable.h"

#import <os/lock.h>
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

@interface SBlockDisposable ()
{
    void *_block;
}

@end

@implementation SBlockDisposable

- (instancetype)initWithBlock:(void (^)())block
{
    self = [super init];
    if (self != nil)
    {
        _block = (__bridge_retained void *)[block copy];
    }
    return self;
}

- (void)dealloc
{
    void *block = _block;
    if (block != NULL)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (OSAtomicCompareAndSwapPtr(block, 0, &_block))
        {
            if (block != nil)
            {
                __unused __strong id strongBlock = (__bridge_transfer id)block;
                strongBlock = nil;
            }
        }
#pragma clang diagnostic pop
    }
}

- (void)dispose
{
    void *block = _block;
    if (block != NULL)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (OSAtomicCompareAndSwapPtr(block, 0, &_block))
        {
            if (block != nil)
            {
                __strong id strongBlock = (__bridge_transfer id)block;
                ((dispatch_block_t)strongBlock)();
                strongBlock = nil;
            }
        }
#pragma clang diagnostic pop
    }
}

@end
