#import "SMetaDisposable.h"

#import <libkern/OSAtomic.h>

@interface SMetaDisposable ()
{
    void *_disposable;
}

@end

@implementation SMetaDisposable

- (void)dealloc
{
    while (true)
    {
        void *previousDisposable = _disposable;
        if (OSAtomicCompareAndSwapPtr(previousDisposable, NULL, &_disposable))
        {
            if (previousDisposable != NULL)
            {
                __strong id<SDisposable> strongPreviousDisposable = (__bridge_transfer id<SDisposable>)previousDisposable;
                strongPreviousDisposable = nil;
            }
            
            break;
        }
    }
}

- (void)setDisposable:(id<SDisposable>)disposable
{
    void *newDisposable = (__bridge_retained void *)disposable;
    while (true)
    {
        void *previousDisposable = _disposable;
        if (OSAtomicCompareAndSwapPtr(previousDisposable, newDisposable, &_disposable))
        {
            if (previousDisposable != NULL)
            {
                __strong id<SDisposable> strongPreviousDisposable = (__bridge_transfer id<SDisposable>)previousDisposable;
                [strongPreviousDisposable dispose];
                strongPreviousDisposable = nil;
            }
            
            break;
        }
    }
}

- (void)dispose
{
    [self setDisposable:nil];
}

@end
