#import <SSignalKit/SSignal.h>

@interface SSignal (Catch)

- (SSignal * _Nonnull)catch:(SSignal * _Nonnull (^ _Nonnull )(id _Nullable error))f;
- (SSignal * _Nonnull)restart;
- (SSignal * _Nonnull)retryIf:(bool (^ _Nonnull)(id _Nullable error))predicate;

@end
