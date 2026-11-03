#import <SSignalKit/SSignal.h>

#import <SSignalKit/SQueue.h>

@interface SSignal (Timing)

- (SSignal * _Nonnull)delay:(NSTimeInterval)seconds onQueue:(SQueue * _Nonnull)queue;
- (SSignal * _Nonnull)timeout:(NSTimeInterval)seconds onQueue:(SQueue * _Nonnull)queue orSignal:(SSignal * _Nonnull)signal;
- (SSignal * _Nonnull)wait:(NSTimeInterval)seconds;

@end
