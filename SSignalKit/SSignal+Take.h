#import <SSignalKit/SSignalKit.h>

@interface SSignal (Take)

- (SSignal *)take:(NSUInteger)count;
- (SSignal *)takeLast;

@end
