#import <SSignalKit/SSignal.h>

@interface SMulticastSignalManager : NSObject

- (SSignal * _Nonnull)multicastedSignalForKey:(NSString * _Nonnull)key producer:(SSignal * _Nonnull (^ _Nonnull)())producer;
- (void)startStandaloneSignalIfNotRunningForKey:(NSString * _Nonnull)key producer:(SSignal * _Nonnull (^ _Nonnull)())producer;

- (SSignal * _Nonnull)multicastedPipeForKey:(NSString * _Nonnull)key;
- (void)putNext:(id _Nullable)next toMulticastedPipeForKey:(NSString * _Nonnull)key;

@end
