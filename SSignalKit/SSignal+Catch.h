#import "SSignal.h"

@interface SSignal (Catch)

- (SSignal *)catch:(SSignal *(^)(id error))f;
- (SSignal *)restart;

@end
