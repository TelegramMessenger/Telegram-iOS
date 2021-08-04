#import <SSignalKit/SDisposable.h>

@class SSignal;

@interface SDisposableSet : NSObject <SDisposable>

- (void)add:(id<SDisposable> _Nonnull)disposable;
- (void)remove:(id<SDisposable> _Nonnull)disposable;

@end
