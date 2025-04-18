#import <SSignalKit/SSignal.h>

@interface SSignal (Accumulate)

- (SSignal *)reduceLeft:(id)value with:(id (^)(id, id))f;
- (SSignal *)reduceLeftWithPassthrough:(id)value with:(id (^)(id, id, void (^)(id)))f;

@end
