#import <SSignalKit/SSignal.h>

#import <SSignalKit/SQueue.h>
#import <SSignalKit/SThreadPool.h>

@interface SSignal (Dispatch)

- (SSignal * _Nonnull)deliverOn:(SQueue * _Nonnull)queue;
- (SSignal * _Nonnull)deliverOnThreadPool:(SThreadPool * _Nonnull)threadPool;
- (SSignal * _Nonnull)startOn:(SQueue * _Nonnull)queue;
- (SSignal * _Nonnull)startOnThreadPool:(SThreadPool * _Nonnull)threadPool;
- (SSignal * _Nonnull)throttleOn:(SQueue * _Nonnull)queue delay:(NSTimeInterval)delay;

@end
