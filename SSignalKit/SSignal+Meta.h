#import "SSignal.h"

@interface SSignal (Meta)

- (SSignal *)switchToLatest;
- (SSignal *)mapToSignal:(SSignal *(^)(id))f;
- (SSignal *)then:(SSignal *)signal;

@end
