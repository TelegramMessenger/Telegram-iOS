#import "SSignal.h"

@interface SSignal (Mapping)

- (SSignal *)map:(id (^)(id))f;
- (SSignal *)_mapInplace:(id (^)(id))f;
- (SSignal *)filter:(bool (^)(id))f;

@end
