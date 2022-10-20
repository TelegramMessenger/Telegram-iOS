#import <SSignalKit/SSignal.h>

@interface SSignal (SideEffects)

- (SSignal * _Nonnull)onStart:(void (^ _Nonnull)())f;
- (SSignal * _Nonnull)onNext:(void (^ _Nonnull)(id _Nullable next))f;
- (SSignal * _Nonnull)afterNext:(void (^ _Nonnull)(id _Nullable next))f;
- (SSignal * _Nonnull)onError:(void (^ _Nonnull)(id _Nullable error))f;
- (SSignal * _Nonnull)onCompletion:(void (^ _Nonnull)())f;
- (SSignal * _Nonnull)afterCompletion:(void (^ _Nonnull)())f;
- (SSignal * _Nonnull)onDispose:(void (^ _Nonnull)())f;

@end
