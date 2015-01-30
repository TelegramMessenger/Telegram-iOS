#import "SSignal.h"

@interface SSignal (Accumulate)

- (SSignal *)reduceLeft:(id)value with:(id (^)(id, id))f;

@end
