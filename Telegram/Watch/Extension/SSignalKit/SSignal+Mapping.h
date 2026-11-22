#import <SSignalKit/SSignal.h>

@interface SSignal (Mapping)

- (SSignal *)map:(id (^)(id))f;
- (SSignal *)filter:(bool (^)(id))f;
- (SSignal *)ignoreRepeated;

@end
