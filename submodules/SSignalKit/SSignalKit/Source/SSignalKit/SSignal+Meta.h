#import <SSignalKit/SSignal.h>

@class SQueue;

@interface SSignal (Meta)

- (SSignal * _Nonnull)switchToLatest;
- (SSignal * _Nonnull)mapToSignal:(SSignal * _Nonnull (^ _Nonnull)(id _Nullable))f;
- (SSignal * _Nonnull)mapToQueue:(SSignal * _Nonnull (^ _Nonnull)(id _Nullable))f;
- (SSignal * _Nonnull)mapToThrottled:(SSignal * _Nonnull (^ _Nonnull)(id _Nullable))f;
- (SSignal * _Nonnull)then:(SSignal * _Nonnull)signal;
- (SSignal * _Nonnull)queue;
- (SSignal * _Nonnull)throttled;
+ (SSignal * _Nonnull)defer:(SSignal * _Nonnull(^ _Nonnull)())generator;

@end

@interface SSignalQueue : NSObject

- (SSignal * _Nonnull)enqueue:(SSignal * _Nonnull)signal;

@end
