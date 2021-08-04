#import <SSignalKit/SSignalKit.h>

@interface SSignal (Take)

- (SSignal * _Nonnull)take:(NSUInteger)count;
- (SSignal * _Nonnull)takeLast;
- (SSignal * _Nonnull)takeUntilReplacement:(SSignal * _Nonnull)replacement;

@end
