#import <SSignalKit/SSignal.h>

@interface SSignal (SideEffects)

- (SSignal *)onStart:(void (^)())f;
- (SSignal *)onNext:(void (^)(id next))f;
- (SSignal *)afterNext:(void (^)(id next))f;
- (SSignal *)onError:(void (^)(id error))f;
- (SSignal *)onCompletion:(void (^)())f;
- (SSignal *)afterCompletion:(void (^)())f;
- (SSignal *)onDispose:(void (^)())f;

@end
